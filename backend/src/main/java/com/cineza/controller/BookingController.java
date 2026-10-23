package com.cineza.controller;

import com.cineza.dto.BookingRequest;
import com.cineza.dto.BookingResponse;
import com.cineza.model.Booking;
import com.cineza.service.BookingService;
import jakarta.validation.Valid;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.security.Principal;
import java.util.List;
import java.util.Map;

@RestController
@RequestMapping("/api/v1/bookings")
public class BookingController {

    private final BookingService bookingService;

    public BookingController(BookingService bookingService) {
        this.bookingService = bookingService;
    }

    /**
     * Completes checkout: validates 10-min Redis lock and creates booking in MySQL
     */
    @PostMapping
    public ResponseEntity<?> confirmBooking(@Valid @RequestBody BookingRequest request, Principal principal) {
        try {
            // Ensure the authenticated user matches or set email from principal if authenticated
            if (principal != null && (request.getUserEmail() == null || request.getUserEmail().isEmpty())) {
                request.setUserEmail(principal.getName());
            }

            BookingResponse response = bookingService.confirmBooking(request);
            return ResponseEntity.status(HttpStatus.CREATED).body(response);
        } catch (IllegalStateException e) {
            return ResponseEntity.status(HttpStatus.CONFLICT).body(Map.of(
                    "success", false,
                    "error", "LOCK_EXPIRED",
                    "message", e.getMessage()
            ));
        } catch (IllegalArgumentException e) {
            return ResponseEntity.badRequest().body(Map.of(
                    "success", false,
                    "error", "BAD_REQUEST",
                    "message", e.getMessage()
            ));
        } catch (Exception e) {
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR).body(Map.of(
                    "success", false,
                    "error", "INTERNAL_ERROR",
                    "message", "An unexpected error occurred during booking: " + e.getMessage()
            ));
        }
    }

    @GetMapping("/{bookingRef}")
    public ResponseEntity<?> getBookingByRef(@PathVariable String bookingRef) {
        try {
            Booking booking = bookingService.getBookingByReference(bookingRef);
            return ResponseEntity.ok(booking);
        } catch (IllegalArgumentException e) {
            return ResponseEntity.notFound().build();
        }
    }

    /**
     * Secured endpoint: Retrieves bookings strictly for the authenticated principal (prevents IDOR/BOLA)
     */
    @GetMapping("/user")
    public ResponseEntity<List<Booking>> getUserBookings(Principal principal) {
        if (principal == null) {
            return ResponseEntity.status(HttpStatus.UNAUTHORIZED).build();
        }
        return ResponseEntity.ok(bookingService.getUserBookings(principal.getName()));
    }
}
