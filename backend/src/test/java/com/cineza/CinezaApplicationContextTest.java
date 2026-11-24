package com.cineza;

import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.web.servlet.MockMvc;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

/**
 * Smoke test: verifies the Spring application context loads cleanly
 * with the H2 + Redis test profile used in CI, and verifies the readiness
 * endpoint required by Docker Compose / Nginx load balancing.
 */
@SpringBootTest
@AutoConfigureMockMvc
@ActiveProfiles("test")
class CinezaApplicationContextTest {

    @Autowired
    private MockMvc mockMvc;

    @Test
    void contextLoads() {
        // If the Spring context fails to start, this test fails and blocks the PR merge.
    }

    @Test
    void healthEndpointPermittedAndReturnsUp() throws Exception {
        mockMvc.perform(get("/health"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.status").value("UP"));
    }
}
