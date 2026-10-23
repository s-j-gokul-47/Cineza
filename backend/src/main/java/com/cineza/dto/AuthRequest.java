package com.cineza.dto;

import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotEmpty;

public class AuthRequest {

    @NotEmpty(message = "Email is required")
    @Email(message = "Invalid email format")
    private String email;

    private String name;

    public AuthRequest() {}

    public AuthRequest(String email, String name) {
        this.email = email;
        this.name = name;
    }

    public String getEmail() { return email; }
    public void setEmail(String email) { this.email = email; }

    public String getName() { return name; }
    public void setName(String name) { this.name = name; }
}
