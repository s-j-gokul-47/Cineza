package com.cineza;

import org.junit.jupiter.api.Test;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.test.context.ActiveProfiles;

/**
 * Smoke test: verifies the Spring application context loads cleanly
 * with the H2 + Redis test profile used in CI.
 *
 * <p>All environment-specific values (datasource URL, JWT secret, Redis host)
 * are injected via environment variables in the GitHub Actions workflow,
 * or fall back to safe defaults in {@code src/test/resources/application.yml}.
 */
@SpringBootTest
@ActiveProfiles("test")
class CinezaApplicationContextTest {

    @Test
    void contextLoads() {
        // If the Spring context fails to start, this test fails and blocks the PR merge.
    }
}
