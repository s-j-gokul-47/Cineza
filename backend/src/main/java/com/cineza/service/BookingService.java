package com.cineza.service;

import com.cineza.dto.BookingRequest;
import com.cineza.dto.BookingResponse;
import com.cineza.integration.EmailNotificationClient;
import com.cineza.integration.PaymentGatewayClient;
import com.cineza.model.Booking;
import com.cineza.model.BookingSeat;
import com.cineza.model.Seat;
import com.cineza.model.Show;
import com.cineza.model.enums.BookingStatus;
import com.cineza.repository.BookingRepository;
import com.cineza.repository.BookingSeatRepository;
import com.cineza.repository.SeatRepository;
import com.cineza.repository.ShowRepository;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.util.ArrayList;
import java.util.List;
import java.util.UUID;

@Service
public class BookingService {

    private static final Logger log = LoggerFactory.getLogger(BookingService.class);

    private final BookingRepository bookingRepository;
    private final BookingSeatRepository bookingSeatRepository;
    private final ShowRepository showRepository;
    private final SeatRepository seatRepository;
    private final SeatLockService seatLockService;
    private final PaymentGatewayClient paymentGatewayClient;
    private final EmailNotificationClient emailNotificationClient;

    public BookingService(BookingRepository bookingRepository,
                          BookingSeatRepository bookingSeatRepository,
                          ShowRepository showRepository,
                          SeatRepository seatRepository,
                          SeatLockService seatLockService,
                          PaymentGatewayClient paymentGatewayClient,
                          EmailNotificationClient emailNotificationClient) {
        this.bookingRepository = bookingRepository;
        this.bookingSeatRepository = bookingSeatRepository;
        this.showRepository = showRepository;
        this.seatRepository = seatRepository;
        this.seatLockService = seatLockService;
        this.paymentGatewayClient = paymentGatewayClient;
        this.emailNotificationClient = emailNotificationClient;
    }

    /**
     * Completes checkout flow:
     * 1. Validates that the active Redis lock with 10-min TTL belongs to the requesting user/token
     * 2. Authorizes payment through circuit-breaker-protected payment gateway
     * 3. Transactionally saves Booking and BookingSeat entities into MySQL
     * 4. Releases temporary Redis locks and sends confirmation email with friendly fallback
     */
    @Transactional
    public BookingResponse confirmBooking(BookingRequest request) {
        log.info("Processing checkout for show {} and seats {}", request.getShowId(), request.getSeatIds());

        // 1. Verify Redis seat lock ownership
        boolean lockValid = seatLockService.verifyLocks(request.getShowId(), request.getSeatIds(), request.getLockToken());
        if (!lockValid) {
            throw new IllegalStateException("Seat lock has expired or is invalid. Please re-select your seats.");
        }

        // 2. Fetch Show and Seats
        Show show = showRepository.findById(request.getShowId())
                .orElseThrow(() -> new IllegalArgumentException("Show not found with ID: " + request.getShowId()));

        List<Seat> seats = seatRepository.findAllById(request.getSeatIds());
        if (seats.size() != request.getSeatIds().size()) {
            throw new IllegalArgumentException("One or more invalid seat IDs provided");
        }

        // 3. Calculate total and prepare booking seats
        BigDecimal totalAmount = BigDecimal.ZERO;
        List<String> seatLabels = new ArrayList<>();

        for (Seat seat : seats) {
            BigDecimal seatPrice = seat.getBasePrice()
                    .multiply(show.getPriceMultiplier())
                    .setScale(2, RoundingMode.HALF_UP);
            totalAmount = totalAmount.add(seatPrice);
            seatLabels.add(seat.getRowName() + seat.getSeatNumber());
        }

        // 4. Authorize payment (bounded timeout + circuit breaker + friendly fallback)
        String bookingRef = "CNZ-" + UUID.randomUUID().toString().substring(0, 8).toUpperCase();
        PaymentGatewayClient.PaymentResult paymentResult =
                paymentGatewayClient.authorizePayment(bookingRef, request.getUserEmail(), totalAmount);
        if (paymentResult.declined()) {
            throw new IllegalStateException(paymentResult.friendlyMessage());
        }

        // 5. Create and save Booking + BookingSeat records
        Booking booking = new Booking(bookingRef, show, request.getUserEmail(), request.getUserPhone(), totalAmount);
        booking.setStatus(paymentResult.resultingStatus());
        Booking savedBooking = bookingRepository.save(booking);

        for (Seat seat : seats) {
            BigDecimal seatPrice = seat.getBasePrice()
                    .multiply(show.getPriceMultiplier())
                    .setScale(2, RoundingMode.HALF_UP);
            BookingSeat bookingSeat = new BookingSeat(savedBooking, seat, seatPrice);
            bookingSeatRepository.save(bookingSeat);
        }

        // 6. Release temporary Redis locks and dispatch confirmation email (non-fatal fallback on email outage)
        seatLockService.releaseLocks(request.getShowId(), request.getSeatIds(), request.getLockToken());

        String notificationMessage = paymentResult.friendlyMessage();
        if (paymentResult.resultingStatus() == BookingStatus.CONFIRMED) {
            EmailNotificationClient.EmailDeliveryResult emailResult = emailNotificationClient.sendBookingConfirmation(
                    request.getUserEmail(),
                    bookingRef,
                    show.getMovie().getTitle(),
                    show.getScreen().getTheatre().getName(),
                    seatLabels,
                    totalAmount
            );
            notificationMessage = emailResult.friendlyMessage();
        }

        log.info("Successfully processed booking {} (status={}) for {}", bookingRef, savedBooking.getStatus(), request.getUserEmail());

        String qrData = "CINEZA:" + bookingRef + ":" + show.getMovie().getTitle() + ":" + String.join(",", seatLabels);

        BookingResponse response = new BookingResponse(
                savedBooking.getId(),
                bookingRef,
                show.getMovie().getTitle(),
                show.getMovie().getPosterUrl(),
                show.getScreen().getTheatre().getName(),
                show.getScreen().getScreenName(),
                show.getStartTime(),
                seatLabels,
                totalAmount,
                savedBooking.getStatus(),
                savedBooking.getCreatedAt(),
                qrData
        );
        response.setNotificationMessage(notificationMessage);
        return response;
    }

    public List<Booking> getUserBookings(String email) {
        return bookingRepository.findByUserEmailOrderByCreatedAtDesc(email);
    }

    public Booking getBookingByReference(String reference) {
        return bookingRepository.findByBookingReference(reference)
                .orElseThrow(() -> new IllegalArgumentException("Booking not found: " + reference));
    }
}
