package com.cineza.service;

import com.cineza.dto.SeatLockResponse;
import com.cineza.repository.BookingRepository;
import com.cineza.resilience.ExternalServiceCircuitBreaker;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.stereotype.Service;

import java.time.Duration;
import java.util.*;

@Service
public class SeatLockService {

    private static final Logger log = LoggerFactory.getLogger(SeatLockService.class);
    private static final String REDIS_LOCKS_CIRCUIT = "redis-locks";
    private static final Duration REDIS_LOCK_TIMEOUT = Duration.ofMillis(2000);

    private final StringRedisTemplate redisTemplate;
    private final BookingRepository bookingRepository;
    private final ExternalServiceCircuitBreaker circuitBreaker;

    @Value("${cineza.seat-lock.ttl-seconds:600}")
    private long lockTtlSeconds;

    @Value("${cineza.seat-lock.lock-prefix:cineza:lock:show:}")
    private String lockPrefix;

    public SeatLockService(
            StringRedisTemplate redisTemplate,
            BookingRepository bookingRepository,
            ExternalServiceCircuitBreaker circuitBreaker) {
        this.redisTemplate = redisTemplate;
        this.bookingRepository = bookingRepository;
        this.circuitBreaker = circuitBreaker;
    }

    /**
     * Atomically lock multiple seats for a given show with a 10-minute TTL (600 seconds),
     * protected by timeout, circuit breaker, and friendly fallback when Redis is unavailable.
     */
    public SeatLockResponse lockSeats(Long showId, List<Long> seatIds, String userId) {
        log.info("Attempting to lock seats {} for showId {} by user {}", seatIds, showId, userId);

        if (seatIds == null || seatIds.isEmpty()) {
            return SeatLockResponse.conflict(showId, List.of());
        }

        // 1. Check if any seat is already confirmed/booked in MySQL
        List<Long> alreadyBookedSeats = bookingRepository.findBookedSeatIdsByShowId(showId);
        List<Long> conflictingBooked = seatIds.stream().filter(alreadyBookedSeats::contains).toList();
        if (!conflictingBooked.isEmpty()) {
            log.warn("Seats {} already booked in database for show {}", conflictingBooked, showId);
            return SeatLockResponse.conflict(showId, conflictingBooked);
        }

        // 2. Attempt atomic lock in Redis under timeout + circuit breaker
        return circuitBreaker.execute(
                REDIS_LOCKS_CIRCUIT,
                REDIS_LOCK_TIMEOUT,
                () -> acquireRedisLocks(showId, seatIds, userId),
                ex -> SeatLockResponse.unavailable(
                        showId,
                        "Seat reservation cache is temporarily busy. Please try locking your seats again in a moment."
                )
        );
    }

    private SeatLockResponse acquireRedisLocks(Long showId, List<Long> seatIds, String userId) {
        String lockToken = UUID.randomUUID().toString();
        String lockValue = lockToken + ":" + userId;
        Duration ttl = Duration.ofSeconds(lockTtlSeconds);

        List<Long> successfullyAcquired = new ArrayList<>();
        List<Long> conflictingSeats = new ArrayList<>();

        for (Long seatId : seatIds) {
            String seatKey = buildSeatKey(showId, seatId);
            Boolean acquired = redisTemplate.opsForValue().setIfAbsent(seatKey, lockValue, ttl);

            if (Boolean.TRUE.equals(acquired)) {
                successfullyAcquired.add(seatId);
            } else {
                conflictingSeats.add(seatId);
                break; // Break early to initiate rollback
            }
        }

        // Rollback if not all seats could be locked
        if (!conflictingSeats.isEmpty() || successfullyAcquired.size() != seatIds.size()) {
            log.warn("Seat locking conflict detected for show {}. Rolling back {} seats", showId, successfullyAcquired.size());
            for (Long seatId : successfullyAcquired) {
                redisTemplate.delete(buildSeatKey(showId, seatId));
            }
            return SeatLockResponse.conflict(showId, conflictingSeats);
        }

        String tokenKey = "cineza:token:" + lockToken;
        redisTemplate.opsForValue().set(
                tokenKey,
                showId + ":" + String.join(",", seatIds.stream().map(String::valueOf).toList()),
                ttl
        );

        log.info("Successfully locked seats {} for show {} with token {} (TTL: {}s)",
                successfullyAcquired, showId, lockToken, lockTtlSeconds);
        return SeatLockResponse.successful(lockToken, showId, successfullyAcquired, lockTtlSeconds);
    }

    /**
     * Verify whether all requested seats are currently locked by the specified lock token.
     */
    public boolean verifyLocks(Long showId, List<Long> seatIds, String lockToken) {
        if (lockToken == null || seatIds == null || seatIds.isEmpty()) {
            return false;
        }

        return Boolean.TRUE.equals(circuitBreaker.execute(
                REDIS_LOCKS_CIRCUIT,
                REDIS_LOCK_TIMEOUT,
                () -> {
                    for (Long seatId : seatIds) {
                        String value = redisTemplate.opsForValue().get(buildSeatKey(showId, seatId));
                        if (value == null || !value.startsWith(lockToken)) {
                            log.warn("Lock verification failed for show {} seat {}: expected token {}",
                                    showId, seatId, lockToken);
                            return false;
                        }
                    }
                    return true;
                },
                ex -> false
        ));
    }

    /**
     * Release locks when user cancels, navigates away, or completes booking.
     */
    public void releaseLocks(Long showId, List<Long> seatIds, String lockToken) {
        log.info("Releasing locks for show {} seats {} with token {}", showId, seatIds, lockToken);
        circuitBreaker.execute(
                REDIS_LOCKS_CIRCUIT,
                REDIS_LOCK_TIMEOUT,
                () -> {
                    for (Long seatId : seatIds) {
                        String seatKey = buildSeatKey(showId, seatId);
                        String value = redisTemplate.opsForValue().get(seatKey);
                        if (value != null && (lockToken == null || value.startsWith(lockToken))) {
                            redisTemplate.delete(seatKey);
                        }
                    }
                    if (lockToken != null) {
                        redisTemplate.delete("cineza:token:" + lockToken);
                    }
                    return null;
                },
                ex -> null
        );
    }

    /**
     * Check if a specific seat is currently locked in Redis.
     */
    public boolean isSeatLocked(Long showId, Long seatId) {
        return Boolean.TRUE.equals(circuitBreaker.execute(
                REDIS_LOCKS_CIRCUIT,
                REDIS_LOCK_TIMEOUT,
                () -> Boolean.TRUE.equals(redisTemplate.hasKey(buildSeatKey(showId, seatId))),
                ex -> false
        ));
    }

    /**
     * Returns a set of all currently locked seat IDs for a given show.
     */
    public Set<Long> getLockedSeatIds(Long showId) {
        return circuitBreaker.execute(
                REDIS_LOCKS_CIRCUIT,
                REDIS_LOCK_TIMEOUT,
                () -> {
                    String pattern = lockPrefix + showId + ":seat:*";
                    Set<String> keys = redisTemplate.keys(pattern);
                    Set<Long> lockedIds = new HashSet<>();
                    if (keys != null) {
                        for (String key : keys) {
                            try {
                                String idStr = key.substring(key.lastIndexOf(":") + 1);
                                lockedIds.add(Long.parseLong(idStr));
                            } catch (Exception ignored) {}
                        }
                    }
                    return lockedIds;
                },
                ex -> Collections.emptySet()
        );
    }

    /**
     * Check if seat is locked by specific user session.
     */
    public boolean isSeatLockedByUser(Long showId, Long seatId, String lockToken) {
        if (lockToken == null) return false;
        return Boolean.TRUE.equals(circuitBreaker.execute(
                REDIS_LOCKS_CIRCUIT,
                REDIS_LOCK_TIMEOUT,
                () -> {
                    String val = redisTemplate.opsForValue().get(buildSeatKey(showId, seatId));
                    return val != null && val.startsWith(lockToken);
                },
                ex -> false
        ));
    }

    public long getLockTtlSeconds() {
        return lockTtlSeconds;
    }

    private String buildSeatKey(Long showId, Long seatId) {
        return lockPrefix + showId + ":seat:" + seatId;
    }
}
