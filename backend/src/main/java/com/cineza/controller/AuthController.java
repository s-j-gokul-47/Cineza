package com.cineza.controller;

import com.cineza.dto.AuthRequest;
import com.cineza.dto.AuthResponse;
import com.cineza.security.JwtTokenProvider;
import jakarta.validation.Valid;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/v1/auth")
public class AuthController {

    private final JwtTokenProvider tokenProvider;

    public AuthController(JwtTokenProvider tokenProvider) {
        this.tokenProvider = tokenProvider;
    }

    /**
     * Issue guest / user JWT token for booking and seat locking operations
     */
    @PostMapping("/login")
    public ResponseEntity<AuthResponse> authenticateUser(@Valid @RequestBody AuthRequest request) {
        String token = tokenProvider.generateTokenFromEmail(request.getEmail());
        return ResponseEntity.ok(new AuthResponse(token, request.getEmail(), "Authentication successful"));
    }
}
