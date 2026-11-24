package com.cineza.controller;

import com.cineza.dto.AuthRequest;
import com.cineza.dto.AuthResponse;
import com.cineza.integration.AuthTokenGatewayClient;
import com.cineza.security.JwtTokenProvider;
import jakarta.validation.Valid;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.Map;

@RestController
@RequestMapping("/api/v1/auth")
public class AuthController {

    private final JwtTokenProvider tokenProvider;
    private final AuthTokenGatewayClient authTokenGatewayClient;

    public AuthController(JwtTokenProvider tokenProvider, AuthTokenGatewayClient authTokenGatewayClient) {
        this.tokenProvider = tokenProvider;
        this.authTokenGatewayClient = authTokenGatewayClient;
    }

    /**
     * Issue guest / user JWT token for booking and seat locking operations
     */
    @PostMapping("/login")
    public ResponseEntity<AuthResponse> authenticateUser(@Valid @RequestBody AuthRequest request) {
        String token = tokenProvider.generateTokenFromEmail(request.getEmail());
        return ResponseEntity.ok(new AuthResponse(token, request.getEmail(), "Authentication successful"));
    }

    /**
     * Exchange / verify an external Auth Token (AT) via circuit-breaker-protected gateway.
     */
    @PostMapping("/verify-external")
    public ResponseEntity<Map<String, Object>> verifyExternalToken(@RequestBody Map<String, String> payload) {
        String accessToken = payload != null ? payload.get("accessToken") : null;
        AuthTokenGatewayClient.AuthGatewayResult result = authTokenGatewayClient.verifyExternalToken(accessToken);

        if (result.fallbackUsed()) {
            return ResponseEntity.status(HttpStatus.SERVICE_UNAVAILABLE).body(Map.of(
                    "authenticated", false,
                    "fallbackUsed", true,
                    "message", result.friendlyMessage()
            ));
        }

        return ResponseEntity.ok(Map.of(
                "authenticated", true,
                "fallbackUsed", false,
                "token", result.tokenOrIdentity() != null ? result.tokenOrIdentity() : "",
                "message", result.friendlyMessage()
        ));
    }
}
