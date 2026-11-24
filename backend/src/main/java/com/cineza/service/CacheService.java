package com.cineza.service;

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

    private final StringRedisTemplate redisTemplate;
    private final ObjectMapper objectMapper;

    public CacheService(StringRedisTemplate redisTemplate, ObjectMapper objectMapper) {
        this.redisTemplate = redisTemplate;
        this.objectMapper = objectMapper;
    }

    public ObjectMapper getObjectMapper() {
        return objectMapper;
    }

    /**
     * Cache-Aside pattern with graceful fallback and jittered TTL.
     * If Redis throws an exception or times out, logs the error and falls back to database supplier.
     */
    public <T> T getOrCompute(String cacheKey, long baseTtlSeconds, Class<T> clazz, Supplier<T> dbSupplier) {
        // 1. Try fetching from Redis cache
        try {
            String cachedJson = redisTemplate.opsForValue().get(cacheKey);
            if (cachedJson != null && !cachedJson.trim().isEmpty()) {
                return objectMapper.readValue(cachedJson, clazz);
            }
        } catch (Exception e) {
            log.warn("Cache read failed for key [{}]. Falling back to database. Error: {}", cacheKey, e.getMessage());
        }

        // 2. Cache miss or Redis failure -> Fetch from DB
        T freshData = dbSupplier.get();
        if (freshData == null) {
            return null;
        }

        // 3. Store in Redis cache with jittered TTL (base TTL + 0 to 30 seconds random jitter)
        try {
            String jsonVal = objectMapper.writeValueAsString(freshData);
            long jitter = ThreadLocalRandom.current().nextLong(0, 31);
            long totalTtl = baseTtlSeconds + jitter;
            redisTemplate.opsForValue().set(cacheKey, jsonVal, Duration.ofSeconds(totalTtl));
        } catch (Exception e) {
            log.warn("Cache write failed for key [{}]. Continuing without caching. Error: {}", cacheKey, e.getMessage());
        }

        return freshData;
    }

    /**
     * Cache-Aside pattern for collections / lists.
     */
    public <T> T getOrComputeList(String cacheKey, long baseTtlSeconds, com.fasterxml.jackson.databind.JavaType javaType, Supplier<T> dbSupplier) {
        try {
            String cachedJson = redisTemplate.opsForValue().get(cacheKey);
            if (cachedJson != null && !cachedJson.trim().isEmpty()) {
                return objectMapper.readValue(cachedJson, javaType);
            }
        } catch (Exception e) {
            log.warn("Cache list read failed for key [{}]. Falling back to database. Error: {}", cacheKey, e.getMessage());
        }

        T freshData = dbSupplier.get();
        if (freshData == null) {
            return null;
        }

        try {
            String jsonVal = objectMapper.writeValueAsString(freshData);
            long jitter = ThreadLocalRandom.current().nextLong(0, 31);
            long totalTtl = baseTtlSeconds + jitter;
            redisTemplate.opsForValue().set(cacheKey, jsonVal, Duration.ofSeconds(totalTtl));
        } catch (Exception e) {
            log.warn("Cache list write failed for key [{}]. Continuing without caching. Error: {}", cacheKey, e.getMessage());
        }

        return freshData;
    }

    /**
     * Explicitly evict/invalidate a specific cache key.
     */
    public void evict(String cacheKey) {
        try {
            redisTemplate.delete(cacheKey);
        } catch (Exception e) {
            log.warn("Cache eviction failed for key [{}]: {}", cacheKey, e.getMessage());
        }
    }

    /**
     * Invalidate all cache keys matching a pattern (e.g., "cineza:cache:movies:*").
     */
    public void evictPattern(String pattern) {
        try {
            var keys = redisTemplate.keys(pattern);
            if (keys != null && !keys.isEmpty()) {
                redisTemplate.delete(keys);
            }
        } catch (Exception e) {
            log.warn("Cache pattern eviction failed for pattern [{}]: {}", pattern, e.getMessage());
        }
    }
}
