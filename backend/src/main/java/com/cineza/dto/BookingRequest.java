package com.cineza.dto;

import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotEmpty;
import jakarta.validation.constraints.NotNull;
import java.util.List;

public class BookingRequest {

    @NotNull(message = "Show ID is required")
    private Long showId;

    @NotEmpty(message = "Seat IDs must not be empty")
    private List<Long> seatIds;

    @NotNull(message = "Lock token is required to verify ownership of seat lock")
    private String lockToken;

    @NotEmpty(message = "Email is required")
    @Email(message = "Invalid email format")
    private String userEmail;

    private String userPhone;

    public BookingRequest() {}

    public BookingRequest(Long showId, List<Long> seatIds, String lockToken, String userEmail, String userPhone) {
        this.showId = showId;
        this.seatIds = seatIds;
        this.lockToken = lockToken;
        this.userEmail = userEmail;
        this.userPhone = userPhone;
    }

    public Long getShowId() { return showId; }
    public void setShowId(Long showId) { this.showId = showId; }

    public List<Long> getSeatIds() { return seatIds; }
    public void setSeatIds(List<Long> seatIds) { this.seatIds = seatIds; }

    public String getLockToken() { return lockToken; }
    public void setLockToken(String lockToken) { this.lockToken = lockToken; }

    public String getUserEmail() { return userEmail; }
    public void setUserEmail(String userEmail) { this.userEmail = userEmail; }

    public String getUserPhone() { return userPhone; }
    public void setUserPhone(String userPhone) { this.userPhone = userPhone; }
}
