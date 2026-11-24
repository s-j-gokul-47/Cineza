package com.cineza.integration;

import com.cineza.resilience.ExternalServiceCircuitBreaker;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;

import java.math.BigDecimal;
import java.time.Duration;
import java.util.List;
import java.util.Map;

/**
 * External email notification client (M-Ticket confirmation dispatch).
 * Always bounded by timeout + circuit breaker + friendly fallback so an email
 * outage never slows down or fails a confirmed ticket booking.
 */
@Service
public class EmailNotificationClient {

    public static final String SERVICE_NAME = "email";
    private static final Logger log = LoggerFactory.getLogger(EmailNotificationClient.class);

    public record EmailDeliveryResult(
            boolean sent,
            boolean fallbackUsed,
            String friendlyMessage
    ) {
        public static EmailDeliveryResult delivered(String email) {
            return new EmailDeliveryResult(true, false, "M-Ticket emailed to " + email + ".");
        }

        public static EmailDeliveryResult deferred(String message) {
            return new EmailDeliveryResult(false, true, message);
        }
    }

    private final ExternalServiceCircuitBreaker circuitBreaker;
    private final String emailServiceUrl;
    private final String emailApiKey;
    private final Duration timeout;

    public EmailNotificationClient(
            ExternalServiceCircuitBreaker circuitBreaker,
            @Value("${cineza.integrations.email.url:}") String emailServiceUrl,
            @Value("${cineza.integrations.email.api-key:}") String emailApiKey,
            @Value("${cineza.integrations.email.timeout-ms:3000}") long timeoutMs) {
        this.circuitBreaker = circuitBreaker;
        this.emailServiceUrl = emailServiceUrl != null ? emailServiceUrl.trim() : "";
        this.emailApiKey = emailApiKey != null ? emailApiKey.trim() : "";
        this.timeout = Duration.ofMillis(Math.max(100, timeoutMs));
    }

    public EmailDeliveryResult sendBookingConfirmation(
            String toEmail,
            String bookingRef,
            String movieTitle,
            String theatreName,
            List<String> seatLabels,
            BigDecimal totalAmount) {

        if (emailServiceUrl.isEmpty()) {
            return EmailDeliveryResult.deferred(
                    "Tickets confirmed! View or screenshot your M-Ticket QR right here."
            );
        }

        Map<String, String> headers = emailApiKey.isEmpty()
                ? Map.of()
                : Map.of("Authorization", "Bearer " + emailApiKey);

        String response = circuitBreaker.postJson(
                SERVICE_NAME,
                emailServiceUrl,
                Map.of(
                        "to", toEmail,
                        "bookingReference", bookingRef,
                        "movieTitle", movieTitle,
                        "theatreName", theatreName,
                        "seats", seatLabels,
                        "totalAmount", totalAmount
                ),
                headers,
                timeout,
                ex -> {
                    log.warn("Email service fallback triggered for booking [{}]: {}", bookingRef, ex.getMessage());
                    return null;
                }
        );

        if (response == null) {
            return EmailDeliveryResult.deferred(
                    "Your tickets are confirmed, but confirmation email delivery is delayed. Keep your M-Ticket QR on screen."
            );
        }
        return EmailDeliveryResult.delivered(toEmail);
    }
}
