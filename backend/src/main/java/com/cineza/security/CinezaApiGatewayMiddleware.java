package com.cineza.security;

import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.security.web.authentication.WebAuthenticationDetailsSource;
import org.springframework.stereotype.Component;
import org.springframework.util.StringUtils;
import org.springframework.web.filter.OncePerRequestFilter;

import java.io.IOException;
import java.time.Duration;
import java.util.Collections;

@Component
public class CinezaApiGatewayMiddleware extends OncePerRequestFilter {

    private static final Logger log = LoggerFactory.getLogger(CinezaApiGatewayMiddleware.class);
    private static final int MAX_REQUESTS_PER_MINUTE = 120;

    private final JwtTokenProvider tokenProvider;
    private final StringRedisTemplate redisTemplate;

    public CinezaApiGatewayMiddleware(JwtTokenProvider tokenProvider, StringRedisTemplate redisTemplate) {
        this.tokenProvider = tokenProvider;
        this.redisTemplate = redisTemplate;
    }

    @Override
    protected void doFilterInternal(HttpServletRequest request, HttpServletResponse response, FilterChain filterChain)
            throws ServletException, IOException {
        long startTime = System.currentTimeMillis();
        String clientIp = getClientIp(request);
        String requestUri = request.getRequestURI();
        String method = request.getMethod();

        // 1. RATE LIMITING CHECK (Redis-backed sliding/fixed window)
        if (requestUri.startsWith("/api/v1/")) {
            if (!checkRateLimit(clientIp)) {
                log.warn("Rate limit exceeded for IP: {} on URI: {}", clientIp, requestUri);
                response.setStatus(429); // 429 Too Many Requests
                response.setHeader("Retry-After", "60");
                response.setContentType("application/json");
                response.getWriter().write("{\"error\": \"Rate limit exceeded. Too many requests. Please try again later.\"}");
                return;
            }
        }

        // 2. CENTRALIZED AUTH CHECK (JWT Extraction & Verification)
        try {
            String jwt = getJwtFromRequest(request);
            if (StringUtils.hasText(jwt) && tokenProvider.validateToken(jwt)) {
                String email = tokenProvider.getEmailFromJWT(jwt);
                if (email != null && SecurityContextHolder.getContext().getAuthentication() == null) {
                    UsernamePasswordAuthenticationToken authentication = new UsernamePasswordAuthenticationToken(
                            email, null, Collections.emptyList());
                    authentication.setDetails(new WebAuthenticationDetailsSource().buildDetails(request));
                    SecurityContextHolder.getContext().setAuthentication(authentication);
                }
            }
        } catch (Exception ex) {
            log.error("Authentication verification failed in gateway middleware: {}", ex.getMessage());
        }

        // 3. PROCEED WITH CHAIN & REQUEST LOGGING
        try {
            filterChain.doFilter(request, response);
        } finally {
            long duration = System.currentTimeMillis() - startTime;
            int status = response.getStatus();
            log.info("API_GATEWAY_LOG | IP: {} | Method: {} | URI: {} | Status: {} | Duration: {}ms",
                    clientIp, method, requestUri, status, duration);
        }
    }

    private boolean checkRateLimit(String clientIp) {
        try {
            String rateKey = "cineza:ratelimit:ip:" + clientIp;
            Long count = redisTemplate.opsForValue().increment(rateKey);
            if (count != null && count == 1) {
                redisTemplate.expire(rateKey, Duration.ofMinutes(1));
            }
            return count == null || count <= MAX_REQUESTS_PER_MINUTE;
        } catch (Exception e) {
            // Graceful fallback if Redis rate limiter fails: allow request to proceed
            log.warn("Redis rate limit check failed for IP [{}]. Bypassing limit. Error: {}", clientIp, e.getMessage());
            return true;
        }
    }

    private String getJwtFromRequest(HttpServletRequest request) {
        String bearerToken = request.getHeader("Authorization");
        if (StringUtils.hasText(bearerToken) && bearerToken.startsWith("Bearer ")) {
            return bearerToken.substring(7);
        }
        return null;
    }

    private String getClientIp(HttpServletRequest request) {
        String xfHeader = request.getHeader("X-Forwarded-For");
        if (xfHeader == null || xfHeader.isEmpty()) {
            return request.getRemoteAddr();
        }
        return xfHeader.split(",")[0].trim();
    }
}
