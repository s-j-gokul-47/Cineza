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
     * Get user profile by Phone Number
     */
    @GetMapping("/by-phone")
    public ResponseEntity<UserResponse> getUserByPhone(@RequestParam String phone) {
        return userService.findByPhoneNumber(phone)
                .map(user -> ResponseEntity.ok(new UserResponse(user)))
                .orElse(ResponseEntity.notFound().build());
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
