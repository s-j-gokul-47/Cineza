package com.cineza.integration;

import com.cineza.model.enums.BookingStatus;
import com.cineza.resilience.ExternalServiceCircuitBreaker;
import com.cineza.resilience.ExternalServiceCircuitBreaker.ExternalServiceException;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;

import java.math.BigDecimal;
import java.time.Duration;
import java.util.Map;

/**
 * Payment gateway adapter (for upcoming Stripe/Razorpay integration).
 * Wraps authorization requests in strict timeouts and a shared circuit breaker
 * so payment outages never hang checkout.
 */
@Service
public class PaymentGatewayClient {

    public static final String SERVICE_NAME = "payments";
    private static final Logger log = LoggerFactory.getLogger(PaymentGatewayClient.class);

    public record PaymentResult(
            boolean authorized,
            boolean declined,
            boolean fallbackUsed,
            BookingStatus resultingStatus,
            String transactionId,
            String friendlyMessage
    ) {
        public static PaymentResult confirmed(String transactionId) {
            return new PaymentResult(true, false, false, BookingStatus.CONFIRMED, transactionId,
                    "Payment authorized.");
        }

        public static PaymentResult declined(String message) {
            return new PaymentResult(false, true, false, BookingStatus.CANCELLED, null, message);
        }

        public static PaymentResult fallbackPending(String message) {
            return new PaymentResult(false, false, true, BookingStatus.PENDING, null, message);
        }
    }

    private final ExternalServiceCircuitBreaker circuitBreaker;
    private final ObjectMapper objectMapper;
    private final String paymentGatewayUrl;
    private final String paymentApiKey;
    private final Duration timeout;

    public PaymentGatewayClient(
            ExternalServiceCircuitBreaker circuitBreaker,
            ObjectMapper objectMapper,
            @Value("${cineza.integrations.payments.url:}") String paymentGatewayUrl,
            @Value("${cineza.integrations.payments.api-key:}") String paymentApiKey,
            @Value("${cineza.integrations.payments.timeout-ms:4000}") long timeoutMs) {
        this.circuitBreaker = circuitBreaker;
        this.objectMapper = objectMapper;
        this.paymentGatewayUrl = paymentGatewayUrl != null ? paymentGatewayUrl.trim() : "";
        this.paymentApiKey = paymentApiKey != null ? paymentApiKey.trim() : "";
        this.timeout = Duration.ofMillis(Math.max(100, timeoutMs));
    }

    public PaymentResult authorizePayment(String bookingRef, String userEmail, BigDecimal amount) {
        // When no payment gateway URL is configured yet (upcoming integration / local mode),
        // confirm seamlessly without blocking bookings.
        if (paymentGatewayUrl.isEmpty()) {
            return PaymentResult.confirmed("LOCAL-" + bookingRef);
        }

        Map<String, String> headers = paymentApiKey.isEmpty()
                ? Map.of()
                : Map.of("Authorization", "Bearer " + paymentApiKey);

        final Throwable[] failureHolder = new Throwable[1];
        String raw = circuitBreaker.postJson(
                SERVICE_NAME,
                paymentGatewayUrl,
                Map.of(
                        "bookingReference", bookingRef,
                        "customerEmail", userEmail,
                        "amount", amount
                ),
                headers,
                timeout,
                ex -> {
                    failureHolder[0] = ex;
                    return null;
                }
        );

        if (raw == null) {
            Throwable err = failureHolder[0];
            if (err instanceof ExternalServiceException ese
                    && ese.getStatusCode() >= 400
                    && ese.getStatusCode() < 500
                    && ese.getStatusCode() != 408
                    && ese.getStatusCode() != 429) {
                return PaymentResult.declined(
                        "Payment was declined by the provider. Please check your payment method and try again."
                );
            }
            log.warn("Payment gateway degraded for booking [{}]: {}", bookingRef,
                    err != null ? err.getMessage() : "unknown");
            return PaymentResult.fallbackPending(
                    "Payment service is temporarily delayed. Your booking is saved as PENDING while confirmation completes."
            );
        }

        try {
            JsonNode node = objectMapper.readTree(raw);
            String txId = node.hasNonNull("transactionId") ? node.get("transactionId").asText() : ("TXN-" + bookingRef);
            return PaymentResult.confirmed(txId);
        } catch (Exception e) {
            log.warn("Unreadable response from payment gateway for [{}]: {}", bookingRef, e.getMessage());
            return PaymentResult.fallbackPending(
                    "Payment confirmation response was delayed. Your booking is queued in PENDING status."
            );
        }
    }
}
