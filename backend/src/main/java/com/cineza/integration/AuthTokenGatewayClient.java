package com.cineza.integration;

import com.cineza.resilience.ExternalServiceCircuitBreaker;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;

import java.time.Duration;
import java.util.Map;

/**
 * Client for external authentication token (AT / OTP worker) verification,
 * protected by timeout, circuit breaker, and friendly fallback.
 */
@Service
public class AuthTokenGatewayClient {

    public static final String SERVICE_NAME = "auth-token";
    private static final Logger log = LoggerFactory.getLogger(AuthTokenGatewayClient.class);

    public record AuthGatewayResult(
            boolean authenticated,
            boolean fallbackUsed,
            String tokenOrIdentity,
            String friendlyMessage
    ) {
        public static AuthGatewayResult verified(String tokenOrIdentity) {
            return new AuthGatewayResult(true, false, tokenOrIdentity, "Authentication verified.");
        }

        public static AuthGatewayResult unconfigured() {
            return new AuthGatewayResult(true, false, null, "External auth gateway disabled; using local JWT/Firebase auth.");
        }

        public static AuthGatewayResult fallback(String message) {
            return new AuthGatewayResult(false, true, null, message);
        }
    }

    private final ExternalServiceCircuitBreaker circuitBreaker;
    private final ObjectMapper objectMapper;
    private final String authGatewayUrl;
    private final Duration timeout;

    public AuthTokenGatewayClient(
            ExternalServiceCircuitBreaker circuitBreaker,
            ObjectMapper objectMapper,
            @Value("${cineza.integrations.auth.url:}") String authGatewayUrl,
            @Value("${cineza.integrations.auth.timeout-ms:4000}") long timeoutMs) {
        this.circuitBreaker = circuitBreaker;
        this.objectMapper = objectMapper;
        this.authGatewayUrl = authGatewayUrl != null ? authGatewayUrl.trim() : "";
        this.timeout = Duration.ofMillis(Math.max(100, timeoutMs));
    }

    public AuthGatewayResult verifyExternalToken(String accessToken) {
        if (authGatewayUrl.isEmpty()) {
            return AuthGatewayResult.unconfigured();
        }
        if (accessToken == null || accessToken.isBlank()) {
            return AuthGatewayResult.fallback("Missing authentication token. Please sign in again.");
        }

        String raw = circuitBreaker.postJson(
                SERVICE_NAME,
                authGatewayUrl,
                Map.of("accessToken", accessToken),
                Map.of(),
                timeout,
                ex -> {
                    log.warn("Auth gateway fallback triggered: {}", ex.getMessage());
                    return null;
                }
        );

        if (raw == null) {
            return AuthGatewayResult.fallback(
                    "Authentication service is temporarily unavailable. Please try again shortly or sign in with Google."
            );
        }

        try {
            JsonNode node = objectMapper.readTree(raw);
            String token = node.hasNonNull("customToken")
                    ? node.get("customToken").asText()
                    : (node.hasNonNull("token") ? node.get("token").asText() : null);
            return AuthGatewayResult.verified(token);
        } catch (Exception e) {
            log.warn("Invalid response from auth gateway: {}", e.getMessage());
            return AuthGatewayResult.fallback(
                    "Could not verify authentication right now. Please try again in a moment."
            );
        }
    }
}
