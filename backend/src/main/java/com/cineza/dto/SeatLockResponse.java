package com.cineza.dto;

import java.time.Instant;
import java.util.List;

public class SeatLockResponse {

    private boolean success;
    private String message;
    private String lockToken;
    private Long showId;
    private List<Long> lockedSeatIds;
    private List<Long> conflictedSeatIds;
    private long ttlSeconds;
    private Instant expiresAt;

    public SeatLockResponse() {}

    public SeatLockResponse(boolean success, String message, String lockToken, Long showId,
                            List<Long> lockedSeatIds, List<Long> conflictedSeatIds,
                            long ttlSeconds, Instant expiresAt) {
        this.success = success;
        this.message = message;
        this.lockToken = lockToken;
        this.showId = showId;
        this.lockedSeatIds = lockedSeatIds;
        this.conflictedSeatIds = conflictedSeatIds;
        this.ttlSeconds = ttlSeconds;
        this.expiresAt = expiresAt;
    }

    public static SeatLockResponse successful(String lockToken, Long showId, List<Long> lockedSeatIds, long ttlSeconds) {
        return new SeatLockResponse(
                true,
                "Seats successfully locked for 10 minutes",
                lockToken,
                showId,
                lockedSeatIds,
                List.of(),
                ttlSeconds,
                Instant.now().plusSeconds(ttlSeconds)
        );
    }

    public static SeatLockResponse conflict(Long showId, List<Long> conflictedSeatIds) {
        return new SeatLockResponse(
                false,
                "One or more selected seats are already locked or booked by another customer",
                null,
                showId,
                List.of(),
                conflictedSeatIds,
                0,
                null
        );
    }

    public boolean isSuccess() { return success; }
    public void setSuccess(boolean success) { this.success = success; }

    public String getMessage() { return message; }
    public void setMessage(String message) { this.message = message; }

    public String getLockToken() { return lockToken; }
    public void setLockToken(String lockToken) { this.lockToken = lockToken; }

    public Long getShowId() { return showId; }
    public void setShowId(Long showId) { this.showId = showId; }

    public List<Long> getLockedSeatIds() { return lockedSeatIds; }
    public void setLockedSeatIds(List<Long> lockedSeatIds) { this.lockedSeatIds = lockedSeatIds; }

    public List<Long> getConflictedSeatIds() { return conflictedSeatIds; }
    public void setConflictedSeatIds(List<Long> conflictedSeatIds) { this.conflictedSeatIds = conflictedSeatIds; }

    public long getTtlSeconds() { return ttlSeconds; }
    public void setTtlSeconds(long ttlSeconds) { this.ttlSeconds = ttlSeconds; }

    public Instant getExpiresAt() { return expiresAt; }
    public void setExpiresAt(Instant expiresAt) { this.expiresAt = expiresAt; }
}
