package com.cineza.dto;

import jakarta.validation.constraints.NotBlank;

public class UserSyncRequest {

    private String firebaseUid;

    @NotBlank(message = "Username cannot be empty")
    private String username;

    private String email;

    private String phoneNumber;

    private String authProvider;

    private String profilePicUrl;

    public UserSyncRequest() {}

    public UserSyncRequest(String firebaseUid, String username, String email, String phoneNumber, String authProvider, String profilePicUrl) {
        this.firebaseUid = firebaseUid;
        this.username = username;
        this.email = email;
        this.phoneNumber = phoneNumber;
        this.authProvider = authProvider;
        this.profilePicUrl = profilePicUrl;
    }

    public String getFirebaseUid() { return firebaseUid; }
    public void setFirebaseUid(String firebaseUid) { this.firebaseUid = firebaseUid; }

    public String getUsername() { return username; }
    public void setUsername(String username) { this.username = username; }

    public String getEmail() { return email; }
    public void setEmail(String email) { this.email = email; }

    public String getPhoneNumber() { return phoneNumber; }
    public void setPhoneNumber(String phoneNumber) { this.phoneNumber = phoneNumber; }

    public String getAuthProvider() { return authProvider; }
    public void setAuthProvider(String authProvider) { this.authProvider = authProvider; }

    public String getProfilePicUrl() { return profilePicUrl; }
    public void setProfilePicUrl(String profilePicUrl) { this.profilePicUrl = profilePicUrl; }
}
