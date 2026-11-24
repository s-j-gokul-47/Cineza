package com.cineza.controller;

import com.cineza.dto.UserResponse;
import com.cineza.dto.UserSyncRequest;
import com.cineza.model.User;
import com.cineza.service.UserService;
import jakarta.validation.Valid;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.Map;

@RestController
@RequestMapping("/api/v1/users")
public class UserController {

    private final UserService userService;

    public UserController(UserService userService) {
        this.userService = userService;
    }

    /**
     * Synchronize or store user upon Google or Mobile OTP login
     */
    @PostMapping("/sync")
    public ResponseEntity<UserResponse> syncUser(@Valid @RequestBody UserSyncRequest request) {
        User synced = userService.syncUser(request);
        return ResponseEntity.ok(new UserResponse(synced));
    }

    /**
     * Get user profile by Firebase UID
     */
    @GetMapping("/{firebaseUid}")
    public ResponseEntity<UserResponse> getUserByUid(@PathVariable String firebaseUid) {
        return userService.findByFirebaseUid(firebaseUid)
                .map(user -> ResponseEntity.ok(new UserResponse(user)))
                .orElse(ResponseEntity.notFound().build());
    }

    /**
     * Get user profile by Phone Number (handles normalized formats)
     */
    @GetMapping("/by-phone")
    public ResponseEntity<UserResponse> getUserByPhone(@RequestParam String phone) {
        return userService.findByPhoneNumber(phone)
                .map(user -> ResponseEntity.ok(new UserResponse(user)))
                .orElse(ResponseEntity.notFound().build());
    }

    /**
     * Get user profile by Username
     */
    @GetMapping("/by-username")
    public ResponseEntity<UserResponse> getUserByUsername(@RequestParam String username) {
        return userService.findByUsername(username)
                .map(user -> ResponseEntity.ok(new UserResponse(user)))
                .orElse(ResponseEntity.notFound().build());
    }

    /**
     * Check if a username is already taken
     */
    @GetMapping("/check-username")
    public ResponseEntity<Map<String, Boolean>> checkUsername(@RequestParam String username) {
        boolean exists = userService.existsByUsername(username);
        return ResponseEntity.ok(Map.of("exists", exists));
    }

    /**
     * Update username for a user
     */
    @PutMapping("/username")
    public ResponseEntity<UserResponse> updateUsername(@RequestBody Map<String, String> payload) {
        String firebaseUid = payload.get("firebaseUid");
        String username = payload.get("username");

        if (firebaseUid == null || username == null || username.isBlank()) {
            return ResponseEntity.badRequest().build();
        }

        return userService.updateUsername(firebaseUid, username)
                .map(user -> ResponseEntity.ok(new UserResponse(user)))
                .orElse(ResponseEntity.notFound().build());
    }
}
