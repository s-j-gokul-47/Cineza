package com.cineza.resilience;

import com.fasterxml.jackson.databind.ObjectMapper;
import jakarta.annotation.PreDestroy;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;

import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.time.Duration;
import java.util.Map;
import java.util.concurrent.*;
import java.util.concurrent.atomic.AtomicBoolean;
import java.util.concurrent.atomic.AtomicInteger;
import java.util.concurrent.atomic.AtomicLong;
import java.util.concurrent.atomic.AtomicReference;
import java.util.function.Function;
import java.util.function.Supplier;

/**
 * Shared timeout + 3-state Circuit Breaker (CLOSED -> OPEN -> HALF_OPEN) + fallback
 * executor for all external API and cache dependencies so slow or failing upstream
 * providers fail fast instead of stalling application threads.
 */
@Component
public class ExternalServiceCircuitBreaker {

    public enum State {
        CLOSED,
        OPEN,
        HALF_OPEN
    }

    public static final class CircuitOpenException extends RuntimeException {
        public CircuitOpenException(String serviceName) {
            super("Circuit breaker is OPEN for external service: " + serviceName);
        }
    }

    public static final class ExternalServiceException extends RuntimeException {
        private final int statusCode;

        public ExternalServiceException(String message, int statusCode) {
            super(message);
            this.statusCode = statusCode;
        }

        public int getStatusCode() {
            return statusCode;
        }

        /**
         * Client/business rejections (4xx other than 408 Request Timeout and 429 Too Many Requests)
         * indicate the remote gateway is healthy and should not trip the circuit breaker.
         */
        public boolean isTrippableFailure() {
            return statusCode >= 500 || statusCode == 408 || statusCode == 429;
        }
    }

    private static final Logger log = LoggerFactory.getLogger(ExternalServiceCircuitBreaker.class);

    private final int failureThreshold;
    private final long openDurationMs;
    private final Duration defaultTimeout;
    private final ObjectMapper objectMapper;
    private final HttpClient httpClient;
    private final ExecutorService executor;
    private final ConcurrentHashMap<String, CircuitBucket> circuits = new ConcurrentHashMap<>();

    @Autowired
    public ExternalServiceCircuitBreaker(
            ObjectMapper objectMapper,
            @Value("${cineza.resilience.failure-threshold:3}") int failureThreshold,
            @Value("${cineza.resilience.open-duration-ms:30000}") long openDurationMs,
            @Value("${cineza.resilience.default-timeout-ms:4000}") long defaultTimeoutMs) {
        this.objectMapper = objectMapper;
        this.failureThreshold = Math.max(1, failureThreshold);
        this.openDurationMs = Math.max(100, openDurationMs);
        this.defaultTimeout = Duration.ofMillis(Math.max(100, defaultTimeoutMs));
        this.httpClient = HttpClient.newBuilder()
                .connectTimeout(this.defaultTimeout)
                .build();
        this.executor = Executors.newCachedThreadPool(r -> {
            Thread t = new Thread(r, "cineza-resilience-worker");
            t.setDaemon(true);
            return t;
        });
    }

    /**
     * Executes an external call with strict timeout enforcement, circuit-breaker tracking,
     * and guaranteed fallback execution on failure, timeout, or open circuit.
     */
    public <T> T execute(
            String serviceName,
            Duration timeout,
            Supplier<T> action,
            Function<Throwable, T> fallback) {

        Duration effectiveTimeout = (timeout != null && !timeout.isZero() && !timeout.isNegative())
                ? timeout
                : defaultTimeout;
        CircuitBucket bucket = circuits.computeIfAbsent(serviceName, k -> new CircuitBucket());

        if (!bucket.allowRequest(openDurationMs)) {
            log.warn("Circuit OPEN for [{}]; skipping external call and using fallback.", serviceName);
            return fallback.apply(new CircuitOpenException(serviceName));
        }

        Future<T> future = null;
        try {
            future = executor.submit(action::get);
            T result = future.get(effectiveTimeout.toMillis(), TimeUnit.MILLISECONDS);
            bucket.recordSuccess();
            return result;
        } catch (TimeoutException te) {
            if (future != null) {
                future.cancel(true);
            }
            bucket.recordFailure(failureThreshold, openDurationMs, serviceName);
            log.warn("Timeout ({}ms) calling external service [{}]. Using fallback.",
                    effectiveTimeout.toMillis(), serviceName);
            return fallback.apply(te);
        } catch (InterruptedException ie) {
            if (future != null) {
                future.cancel(true);
            }
            Thread.currentThread().interrupt();
            bucket.recordFailure(failureThreshold, openDurationMs, serviceName);
            return fallback.apply(ie);
        } catch (ExecutionException ee) {
            Throwable cause = ee.getCause() != null ? ee.getCause() : ee;
            if (cause instanceof ExternalServiceException ese && !ese.isTrippableFailure()) {
                bucket.recordSuccess();
                log.info("External service [{}] returned client rejection ({}). Circuit stays healthy.",
                        serviceName, ese.getMessage());
                return fallback.apply(cause);
            }
            bucket.recordFailure(failureThreshold, openDurationMs, serviceName);
            log.warn("External service [{}] failed: {}. Using fallback.", serviceName, cause.getMessage());
            return fallback.apply(cause);
        } catch (Exception ex) {
            bucket.recordFailure(failureThreshold, openDurationMs, serviceName);
            log.warn("Unexpected error invoking [{}]: {}. Using fallback.", serviceName, ex.getMessage());
            return fallback.apply(ex);
        } finally {
            bucket.releaseProbe();
        }
    }

    /**
     * Sends a JSON HTTP POST with bounded connect & read timeouts inside the circuit breaker.
     */
    public String postJson(
            String serviceName,
            String url,
            Map<String, Object> payload,
            Map<String, String> headers,
            Duration timeout,
            Function<Throwable, String> fallback) {

        Duration effectiveTimeout = (timeout != null && !timeout.isZero() && !timeout.isNegative())
                ? timeout
                : defaultTimeout;

        return execute(serviceName, effectiveTimeout, () -> {
            try {
                String jsonBody = objectMapper.writeValueAsString(payload);
                HttpRequest.Builder req = HttpRequest.newBuilder()
                        .uri(URI.create(url))
                        .timeout(effectiveTimeout)
                        .header("Content-Type", "application/json")
                        .POST(HttpRequest.BodyPublishers.ofString(jsonBody));

                if (headers != null) {
                    headers.forEach((k, v) -> {
                        if (k != null && v != null && !v.isBlank()) {
                            req.header(k, v);
                        }
                    });
                }

                HttpResponse<String> response = httpClient.send(req.build(), HttpResponse.BodyHandlers.ofString());
                int status = response.statusCode();
                if (status >= 200 && status < 300) {
                    return response.body();
                }
                throw new ExternalServiceException(
                        "HTTP " + status + " from " + serviceName,
                        status
                );
            } catch (ExternalServiceException ese) {
                throw ese;
            } catch (InterruptedException ie) {
                Thread.currentThread().interrupt();
                throw new CompletionException(ie);
            } catch (Exception e) {
                throw new CompletionException(e);
            }
        }, fallback);
    }

    public State getState(String serviceName) {
        CircuitBucket bucket = circuits.get(serviceName);
        if (bucket == null) {
            return State.CLOSED;
        }
        return bucket.effectiveState(openDurationMs);
    }

    public void reset(String serviceName) {
        circuits.remove(serviceName);
    }

    @PreDestroy
    public void shutdown() {
        executor.shutdownNow();
    }

    private static final class CircuitBucket {
        private final AtomicReference<State> state = new AtomicReference<>(State.CLOSED);
        private final AtomicInteger consecutiveFailures = new AtomicInteger(0);
        private final AtomicLong openedUntilEpochMs = new AtomicLong(0);
        private final AtomicBoolean probeInFlight = new AtomicBoolean(false);

        boolean allowRequest(long openDurationMs) {
            State current = state.get();
            if (current == State.CLOSED) {
                return true;
            }
            if (current == State.OPEN) {
                if (System.currentTimeMillis() >= openedUntilEpochMs.get()) {
                    if (state.compareAndSet(State.OPEN, State.HALF_OPEN)) {
                        return probeInFlight.compareAndSet(false, true);
                    }
                }
                return false;
            }
            // HALF_OPEN: permit only one concurrent recovery probe
            return probeInFlight.compareAndSet(false, true);
        }

        State effectiveState(long openDurationMs) {
            State current = state.get();
            if (current == State.OPEN && System.currentTimeMillis() >= openedUntilEpochMs.get()) {
                return State.HALF_OPEN;
            }
            return current;
        }

        void recordSuccess() {
            consecutiveFailures.set(0);
            state.set(State.CLOSED);
        }

        void recordFailure(int threshold, long openDurationMs, String serviceName) {
            int failures = consecutiveFailures.incrementAndGet();
            State current = state.get();
            if (current == State.HALF_OPEN || failures >= threshold) {
                openedUntilEpochMs.set(System.currentTimeMillis() + openDurationMs);
                state.set(State.OPEN);
                log.warn("Circuit breaker OPENED for [{}] after {} consecutive failures (cooldown: {}ms).",
                        serviceName, failures, openDurationMs);
            }
        }

        void releaseProbe() {
            probeInFlight.set(false);
        }
    }
}
