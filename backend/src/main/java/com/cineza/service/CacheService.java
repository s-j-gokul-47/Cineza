package com.cineza.service;

import com.cineza.resilience.ExternalServiceCircuitBreaker;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.stereotype.Service;

import java.time.Duration;
import java.util.concurrent.ThreadLocalRandom;
import java.util.function.Supplier;

@Service
public class CacheService {

    private static final Logger log = LoggerFactory.getLogger(CacheService.class);
    private static final String REDIS_CACHE_CIRCUIT = "redis-cache";
    private static final Duration REDIS_OP_TIMEOUT = Duration.ofMillis(1500);

    private final StringRedisTemplate redisTemplate;
    private final ObjectMapper objectMapper;
    private final ExternalServiceCircuitBreaker circuitBreaker;

    public CacheService(
            StringRedisTemplate redisTemplate,
            ObjectMapper objectMapper,
            ExternalServiceCircuitBreaker circuitBreaker) {
        this.redisTemplate = redisTemplate;
        this.objectMapper = objectMapper;
        this.circuitBreaker = circuitBreaker;
    }

    public ObjectMapper getObjectMapper() {
        return objectMapper;
    }

    /**
     * Cache-Aside pattern with timeout, circuit breaker, jittered TTL, and graceful DB fallback.
     * When Redis hangs or trips open, subsequent catalog lookups skip Redis immediately and query MySQL.
     */
    public <T> T getOrCompute(String cacheKey, long baseTtlSeconds, Class<T> clazz, Supplier<T> dbSupplier) {
        String cachedJson = readCachedJson(cacheKey);
        if (cachedJson != null) {
            try {
                return objectMapper.readValue(cachedJson, clazz);
            } catch (Exception e) {
                log.warn("Cache parse failed for key [{}]. Falling back to DB. Error: {}", cacheKey, e.getMessage());
            }
        }

        T freshData = dbSupplier.get();
        if (freshData == null) {
            return null;
        }

        writeCachedJson(cacheKey, baseTtlSeconds, freshData);
        return freshData;
    }

    /**
     * Cache-Aside pattern for collections / lists.
     */
    public <T> T getOrComputeList(String cacheKey, long baseTtlSeconds, com.fasterxml.jackson.databind.JavaType javaType, Supplier<T> dbSupplier) {
        String cachedJson = readCachedJson(cacheKey);
        if (cachedJson != null) {
            try {
                return objectMapper.readValue(cachedJson, javaType);
            } catch (Exception e) {
                log.warn("Cache list parse failed for key [{}]. Falling back to DB. Error: {}", cacheKey, e.getMessage());
            }
        }

        T freshData = dbSupplier.get();
        if (freshData == null) {
            return null;
        }

        writeCachedJson(cacheKey, baseTtlSeconds, freshData);
        return freshData;
    }

    private String readCachedJson(String cacheKey) {
        return circuitBreaker.execute(
                REDIS_CACHE_CIRCUIT,
                REDIS_OP_TIMEOUT,
                () -> {
                    String val = redisTemplate.opsForValue().get(cacheKey);
                    return (val != null && !val.trim().isEmpty()) ? val : null;
                },
                ex -> null
        );
    }

    private void writeCachedJson(String cacheKey, long baseTtlSeconds, Object value) {
        circuitBreaker.execute(
                REDIS_CACHE_CIRCUIT,
                REDIS_OP_TIMEOUT,
                () -> {
                    try {
                        String jsonVal = objectMapper.writeValueAsString(value);
                        long jitter = ThreadLocalRandom.current().nextLong(0, 31);
                        redisTemplate.opsForValue().set(cacheKey, jsonVal, Duration.ofSeconds(baseTtlSeconds + jitter));
                    } catch (Exception e) {
                        throw new RuntimeException(e);
                    }
                    return null;
                },
                ex -> null
        );
    }

    /**
     * Explicitly evict/invalidate a specific cache key.
     */
    public void evict(String cacheKey) {
        circuitBreaker.execute(
                REDIS_CACHE_CIRCUIT,
                REDIS_OP_TIMEOUT,
                () -> redisTemplate.delete(cacheKey),
                ex -> false
        );
    }

    /**
     * Invalidate all cache keys matching a pattern (e.g., "cineza:cache:movies:*").
     */
    public void evictPattern(String pattern) {
        circuitBreaker.execute(
                REDIS_CACHE_CIRCUIT,
                REDIS_OP_TIMEOUT,
                () -> {
                    var keys = redisTemplate.keys(pattern);
                    if (keys != null && !keys.isEmpty()) {
                        redisTemplate.delete(keys);
                    }
                    return null;
                },
                ex -> null
        );
    }
}
