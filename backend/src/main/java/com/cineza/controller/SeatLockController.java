package com.cineza.controller;

import com.cineza.dto.SeatLockRequest;
import com.cineza.dto.SeatLockResponse;
import com.cineza.service.SeatLockService;
import jakarta.validation.Valid;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.Map;
import java.util.Set;

@RestController
@RequestMapping("/api/v1/shows/{showId}/seats")
public class SeatLockController {

    private final SeatLockService seatLockService;

    public SeatLockController(SeatLockService seatLockService) {
        this.seatLockService = seatLockService;
    }

    /**
     * Atomically lock selected seats with a strict 10-minute TTL in Redis.
     * Prevents concurrent double-booking during checkout flow.
     */
    @PostMapping("/lock")
    public ResponseEntity<SeatLockResponse> lockSeats(
            @PathVariable Long showId,
            @Valid @RequestBody SeatLockRequest request) {

        request.setShowId(showId);
        SeatLockResponse response = seatLockService.lockSeats(showId, request.getSeatIds(), request.getUserId());

        if (response.isSuccess()) {
            return ResponseEntity.ok(response);
        } else {
            return ResponseEntity.status(HttpStatus.CONFLICT).body(response);
        }
    }

    /**
     * Release seat locks when user cancels checkout or changes selection.
     */
    @PostMapping("/unlock")
    public ResponseEntity<Map<String, Object>> unlockSeats(
            @PathVariable Long showId,
            @RequestBody SeatLockRequest request) {

        seatLockService.releaseLocks(showId, request.getSeatIds(), request.getUserId());
        return ResponseEntity.ok(Map.of(
                "success", true,
                "message", "Seat locks successfully released"
        ));
    }

    /**
     * Get IDs of all currently locked seats for this show.
     */
    @GetMapping("/locked")
    public ResponseEntity<Set<Long>> getLockedSeatIds(@PathVariable Long showId) {
        return ResponseEntity.ok(seatLockService.getLockedSeatIds(showId));
    }
}
