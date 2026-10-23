package com.cineza.dto;

import com.cineza.model.enums.BookingStatus;
import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.util.List;

public class BookingResponse {

    private Long bookingId;
    private String bookingReference;
    private String movieTitle;
    private String posterUrl;
    private String theatreName;
    private String screenName;
    private LocalDateTime showTime;
    private List<String> seatLabels;
    private BigDecimal totalAmount;
    private BookingStatus status;
    private LocalDateTime bookedAt;
    private String qrCodeData;

    public BookingResponse() {}

    public BookingResponse(Long bookingId, String bookingReference, String movieTitle,
                           String posterUrl, String theatreName, String screenName,
                           LocalDateTime showTime, List<String> seatLabels, BigDecimal totalAmount,
                           BookingStatus status, LocalDateTime bookedAt, String qrCodeData) {
        this.bookingId = bookingId;
        this.bookingReference = bookingReference;
        this.movieTitle = movieTitle;
        this.posterUrl = posterUrl;
        this.theatreName = theatreName;
        this.screenName = screenName;
        this.showTime = showTime;
        this.seatLabels = seatLabels;
        this.totalAmount = totalAmount;
        this.status = status;
        this.bookedAt = bookedAt;
        this.qrCodeData = qrCodeData;
    }

    public Long getBookingId() { return bookingId; }
    public void setBookingId(Long bookingId) { this.bookingId = bookingId; }

    public String getBookingReference() { return bookingReference; }
    public void setBookingReference(String bookingReference) { this.bookingReference = bookingReference; }

    public String getMovieTitle() { return movieTitle; }
    public void setMovieTitle(String movieTitle) { this.movieTitle = movieTitle; }

    public String getPosterUrl() { return posterUrl; }
    public void setPosterUrl(String posterUrl) { this.posterUrl = posterUrl; }

    public String getTheatreName() { return theatreName; }
    public void setTheatreName(String theatreName) { this.theatreName = theatreName; }

    public String getScreenName() { return screenName; }
    public void setScreenName(String screenName) { this.screenName = screenName; }

    public LocalDateTime getShowTime() { return showTime; }
    public void setShowTime(LocalDateTime showTime) { this.showTime = showTime; }

    public List<String> getSeatLabels() { return seatLabels; }
    public void setSeatLabels(List<String> seatLabels) { this.seatLabels = seatLabels; }

    public BigDecimal getTotalAmount() { return totalAmount; }
    public void setTotalAmount(BigDecimal totalAmount) { this.totalAmount = totalAmount; }

    public BookingStatus getStatus() { return status; }
    public void setStatus(BookingStatus status) { this.status = status; }

    public LocalDateTime getBookedAt() { return bookedAt; }
    public void setBookedAt(LocalDateTime bookedAt) { this.bookedAt = bookedAt; }

    public String getQrCodeData() { return qrCodeData; }
    public void setQrCodeData(String qrCodeData) { this.qrCodeData = qrCodeData; }
}
