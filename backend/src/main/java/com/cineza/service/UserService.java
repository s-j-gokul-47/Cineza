package com.cineza.service;

import com.cineza.dto.UserSyncRequest;
import com.cineza.model.User;
import com.cineza.repository.UserRepository;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.Optional;

@Service
public class UserService {

    private final UserRepository userRepository;

    public UserService(UserRepository userRepository) {
        this.userRepository = userRepository;
    }

    /**
     * Synchronize or create a user after Google or Mobile OTP login.
     * If user exists by Firebase UID (or phone number / email), updates profile.
     * Otherwise, creates a new User record in the database.
     */
    @Transactional
    public User syncUser(UserSyncRequest request) {
        Optional<User> existingUser = Optional.empty();

        if (request.getFirebaseUid() != null && !request.getFirebaseUid().isBlank()) {
            existingUser = userRepository.findByFirebaseUid(request.getFirebaseUid());
        }

        if (existingUser.isEmpty() && request.getPhoneNumber() != null && !request.getPhoneNumber().isBlank()) {
            existingUser = userRepository.findByPhoneNumber(request.getPhoneNumber());
        }

        if (existingUser.isEmpty() && request.getEmail() != null && !request.getEmail().isBlank()) {
            existingUser = userRepository.findByEmail(request.getEmail());
        }

        User user;
        if (existingUser.isPresent()) {
            user = existingUser.get();
            if (request.getUsername() != null && !request.getUsername().isBlank()) {
                user.setUsername(request.getUsername().trim());
            }
            if (request.getEmail() != null && !request.getEmail().isBlank()) {
                user.setEmail(request.getEmail().trim());
            }
            if (request.getPhoneNumber() != null && !request.getPhoneNumber().isBlank()) {
                user.setPhoneNumber(request.getPhoneNumber().trim());
            }
            if (request.getProfilePicUrl() != null && !request.getProfilePicUrl().isBlank()) {
                user.setProfilePicUrl(request.getProfilePicUrl().trim());
            }
            if (request.getFirebaseUid() != null && !request.getFirebaseUid().isBlank()) {
                user.setFirebaseUid(request.getFirebaseUid().trim());
            }
            if (request.getAuthProvider() != null && !request.getAuthProvider().isBlank()) {
                user.setAuthProvider(request.getAuthProvider().trim());
            }
        } else {
            user = new User(
                    request.getFirebaseUid() != null ? request.getFirebaseUid().trim() : null,
                    request.getUsername().trim(),
                    request.getEmail() != null ? request.getEmail().trim() : null,
                    request.getPhoneNumber() != null ? request.getPhoneNumber().trim() : null,
                    request.getAuthProvider() != null ? request.getAuthProvider().trim() : "GOOGLE",
                    request.getProfilePicUrl() != null ? request.getProfilePicUrl().trim() : null
            );
        }

        return userRepository.save(user);
    }

    @Transactional(readOnly = true)
    public Optional<User> findByFirebaseUid(String firebaseUid) {
        return userRepository.findByFirebaseUid(firebaseUid);
    }

    @Transactional(readOnly = true)
    public Optional<User> findByPhoneNumber(String phoneNumber) {
        if (phoneNumber == null || phoneNumber.isBlank()) {
            return Optional.empty();
        }
        String cleaned = phoneNumber.trim();

        // 1. Exact match
        Optional<User> user = userRepository.findByPhoneNumber(cleaned);
        if (user.isPresent()) {
            return user;
        }

        // 2. Normalized check across international (+91), national (91), and 10-digit formats
        String digits = cleaned.replaceAll("[^0-9]", "");
        if (digits.length() >= 10) {
            String last10 = digits.substring(digits.length() - 10);

            // Check +91 prefix
            user = userRepository.findByPhoneNumber("+91" + last10);
            if (user.isPresent()) return user;

            // Check 91 prefix
            user = userRepository.findByPhoneNumber("91" + last10);
            if (user.isPresent()) return user;

            // Check raw 10 digits
            user = userRepository.findByPhoneNumber(last10);
            if (user.isPresent()) return user;
        }

        return Optional.empty();
    }

    @Transactional(readOnly = true)
    public Optional<User> findByUsername(String username) {
        if (username == null || username.isBlank()) {
            return Optional.empty();
        }
        String clean = username.trim();
        Optional<User> user = userRepository.findByUsernameIgnoreCase(clean);
        if (user.isPresent()) {
            return user;
        }
        return userRepository.findByUsername(clean);
    }

    @Transactional(readOnly = true)
    public boolean existsByUsername(String username) {
        if (username == null || username.isBlank()) {
            return false;
        }
        String clean = username.trim();
        return userRepository.existsByUsernameIgnoreCase(clean) || userRepository.existsByUsername(clean);
    }

    @Transactional
    public Optional<User> updateUsername(String firebaseUid, String newUsername) {
        return userRepository.findByFirebaseUid(firebaseUid).map(user -> {
            user.setUsername(newUsername.trim());
            return userRepository.save(user);
        });
    }
}
