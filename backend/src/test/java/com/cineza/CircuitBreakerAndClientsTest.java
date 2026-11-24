package com.cineza;

import com.cineza.dto.BookingRequest;
import com.cineza.dto.BookingResponse;
import com.cineza.integration.AuthTokenGatewayClient;
import com.cineza.integration.EmailNotificationClient;
import com.cineza.integration.PaymentGatewayClient;
import com.cineza.model.*;
import com.cineza.model.enums.BookingStatus;
import com.cineza.model.enums.ScreenType;
import com.cineza.model.enums.SeatType;
import com.cineza.repository.BookingRepository;
import com.cineza.repository.BookingSeatRepository;
import com.cineza.repository.SeatRepository;
import com.cineza.repository.ShowRepository;
import com.cineza.resilience.ExternalServiceCircuitBreaker;
import com.cineza.resilience.ExternalServiceCircuitBreaker.State;
import com.cineza.service.BookingService;
import com.cineza.service.SeatLockService;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.sun.net.httpserver.HttpServer;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

import java.io.IOException;
import java.io.OutputStream;
import java.math.BigDecimal;
import java.net.InetSocketAddress;
import java.nio.charset.StandardCharsets;
import java.time.Duration;
import java.time.LocalDateTime;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.concurrent.atomic.AtomicBoolean;
import java.util.concurrent.atomic.AtomicInteger;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.*;

class CircuitBreakerAndClientsTest {

    private HttpServer server;
    private java.util.concurrent.ExecutorService serverExecutor;
    private String baseUrl;
    private final ObjectMapper objectMapper = new ObjectMapper();
    private ExternalServiceCircuitBreaker breaker;

    @BeforeEach
    void setUp() throws IOException {
        server = HttpServer.create(new InetSocketAddress("127.0.0.1", 0), 0);
        serverExecutor = java.util.concurrent.Executors.newCachedThreadPool();
        server.setExecutor(serverExecutor);
        server.start();
        baseUrl = "http://127.0.0.1:" + server.getAddress().getPort();
        breaker = new ExternalServiceCircuitBreaker(objectMapper, 2, 250, 120);
    }

    @AfterEach
    void tearDown() {
        breaker.shutdown();
        server.stop(0);
        serverExecutor.shutdownNow();
    }

    @Test
    void circuitBreakerTimesOutTripsOpenFailsFastAndRecoversHalfOpen() throws InterruptedException {
        AtomicInteger hits = new AtomicInteger(0);
        AtomicBoolean healthy = new AtomicBoolean(false);

        server.createContext("/flaky", exchange -> {
            hits.incrementAndGet();
            if (!healthy.get()) {
                try {
                    Thread.sleep(400);
                } catch (InterruptedException ignored) {
                    Thread.currentThread().interrupt();
                }
                exchange.sendResponseHeaders(503, 0);
                exchange.close();
                return;
            }
            byte[] body = "{\"ok\":true}".getBytes(StandardCharsets.UTF_8);
            exchange.sendResponseHeaders(200, body.length);
            try (OutputStream os = exchange.getResponseBody()) {
                os.write(body);
            }
        });

        String url = baseUrl + "/flaky";

        // 1st and 2nd requests time out -> threshold=2 trips circuit OPEN
        assertEquals("fallback", breaker.postJson("test-svc", url, Map.of("k", "v"), Map.of(),
                Duration.ofMillis(100), ex -> "fallback"));
        assertEquals("fallback", breaker.postJson("test-svc", url, Map.of("k", "v"), Map.of(),
                Duration.ofMillis(100), ex -> "fallback"));
        assertEquals(State.OPEN, breaker.getState("test-svc"));

        // 3rd request fails fast in <40ms without calling HTTP server
        long t0 = System.nanoTime();
        String fastFallback = breaker.postJson("test-svc", url, Map.of("k", "v"), Map.of(),
                Duration.ofMillis(100), ex -> "fallback");
        long elapsedMs = (System.nanoTime() - t0) / 1_000_000;
        assertEquals("fallback", fastFallback);
        assertEquals(2, hits.get(), "Open circuit must skip downstream HTTP call");
        assertTrue(elapsedMs < 80, "Open circuit should return fallback immediately");

        // Wait past cooldown -> HALF_OPEN probe succeeds and closes circuit
        healthy.set(true);
        Thread.sleep(300);
        String ok = breaker.postJson("test-svc", url, Map.of("k", "v"), Map.of(),
                Duration.ofMillis(500), ex -> "fallback");
        assertEquals("{\"ok\":true}", ok);
        assertEquals(State.CLOSED, breaker.getState("test-svc"));
    }

    @Test
    void authTokenGatewayClientFallsBackWithoutHangingOnSlowOrDownServer() {
        AtomicInteger hits = new AtomicInteger(0);
        server.createContext("/auth/otp", exchange -> {
            hits.incrementAndGet();
            exchange.sendResponseHeaders(503, 0);
            exchange.close();
        });

        AuthTokenGatewayClient client = new AuthTokenGatewayClient(
                breaker, objectMapper, baseUrl + "/auth/otp", 200);

        AuthTokenGatewayClient.AuthGatewayResult r1 = client.verifyExternalToken("tok_1");
        AuthTokenGatewayClient.AuthGatewayResult r2 = client.verifyExternalToken("tok_2");
        AuthTokenGatewayClient.AuthGatewayResult r3 = client.verifyExternalToken("tok_3");

        assertFalse(r1.authenticated());
        assertTrue(r1.fallbackUsed());
        assertTrue(r1.friendlyMessage().contains("temporarily unavailable"));
        assertTrue(r3.fallbackUsed());
        assertEquals(2, hits.get(), "3rd call should fast-fail after circuit opens");
    }

    @Test
    void paymentGatewayDistinguishesCardDeclineFromGatewayOutage() {
        server.createContext("/pay-decline", exchange -> {
            byte[] body = "{\"error\":\"card_declined\"}".getBytes(StandardCharsets.UTF_8);
            exchange.sendResponseHeaders(402, body.length);
            try (OutputStream os = exchange.getResponseBody()) {
                os.write(body);
            }
        });
        server.createContext("/pay-down", exchange -> {
            exchange.sendResponseHeaders(500, 0);
            exchange.close();
        });

        PaymentGatewayClient declineClient = new PaymentGatewayClient(
                breaker, objectMapper, baseUrl + "/pay-decline", "", 300);
        for (int i = 0; i < 4; i++) {
            PaymentGatewayClient.PaymentResult declined =
                    declineClient.authorizePayment("CNZ-1", "a@b.com", BigDecimal.TEN);
            assertTrue(declined.declined());
            assertEquals(State.CLOSED, breaker.getState(PaymentGatewayClient.SERVICE_NAME),
                    "402 card decline must NOT trip circuit breaker");
        }

        PaymentGatewayClient outageClient = new PaymentGatewayClient(
                breaker, objectMapper, baseUrl + "/pay-down", "", 300);
        outageClient.authorizePayment("CNZ-2", "a@b.com", BigDecimal.TEN);
        PaymentGatewayClient.PaymentResult degraded =
                outageClient.authorizePayment("CNZ-3", "a@b.com", BigDecimal.TEN);

        assertFalse(degraded.authorized());
        assertTrue(degraded.fallbackUsed());
        assertEquals(BookingStatus.PENDING, degraded.resultingStatus());
        assertEquals(State.OPEN, breaker.getState(PaymentGatewayClient.SERVICE_NAME));
    }

    @Test
    void emailClientTimeoutsDegradeGracefullyWithoutFailingBookingConfirmation() {
        server.createContext("/send-email", exchange -> {
            try {
                Thread.sleep(500);
            } catch (InterruptedException ignored) {
                Thread.currentThread().interrupt();
            }
            exchange.sendResponseHeaders(200, 0);
            exchange.close();
        });

        PaymentGatewayClient localPay = new PaymentGatewayClient(breaker, objectMapper, "", "", 200);
        EmailNotificationClient slowEmail = new EmailNotificationClient(
                breaker, baseUrl + "/send-email", "", 100);

        BookingRepository bookingRepo = mock(BookingRepository.class);
        BookingSeatRepository bookingSeatRepo = mock(BookingSeatRepository.class);
        ShowRepository showRepo = mock(ShowRepository.class);
        SeatRepository seatRepo = mock(SeatRepository.class);
        SeatLockService seatLockService = mock(SeatLockService.class);

        City city = new City("Chennai", "TN", "India");
        Theatre theatre = new Theatre("Cineza IMAX", "VR Mall", city, 2);
        Screen screen = new Screen(theatre, 1, "Screen 1", ScreenType.IMAX, 60);
        Movie movie = new Movie("24", "Sci-Fi", "p.jpg", "b.png", "Sci-Fi", "Tamil",
                164, "UA", BigDecimal.valueOf(8.0), null);
        Show show = new Show(movie, screen, LocalDateTime.now().plusHours(2),
                LocalDateTime.now().plusHours(5), BigDecimal.ONE);
        Seat seat = new Seat(screen, "A", 1, SeatType.VIP, BigDecimal.valueOf(24.00));

        when(seatLockService.verifyLocks(any(), any(), any())).thenReturn(true);
        when(showRepo.findById(1L)).thenReturn(Optional.of(show));
        when(seatRepo.findAllById(List.of(10L))).thenReturn(List.of(seat));
        when(bookingRepo.save(any(Booking.class))).thenAnswer(inv -> {
            Booking b = inv.getArgument(0);
            b.setId(42L);
            return b;
        });

        BookingService bookingService = new BookingService(
                bookingRepo, bookingSeatRepo, showRepo, seatRepo, seatLockService, localPay, slowEmail);

        BookingResponse resp = bookingService.confirmBooking(
                new BookingRequest(1L, List.of(10L), "tok", "user@cineza.com", "9999999999"));

        assertEquals(BookingStatus.CONFIRMED, resp.getStatus());
        assertNotNull(resp.getNotificationMessage());
        assertTrue(resp.getNotificationMessage().contains("delayed"));
    }
}
