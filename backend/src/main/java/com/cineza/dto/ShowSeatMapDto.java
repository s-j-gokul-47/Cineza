package com.cineza.dto;

import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.util.List;
import java.util.Map;

public class ShowSeatMapDto {

    private Long showId;
    private String movieTitle;
    private String theatreName;
    private String screenName;
    private String screenType;
    private LocalDateTime startTime;
    private BigDecimal priceMultiplier;
    private int totalSeats;
    private int availableSeats;
    private Map<String, List<SeatStatusDto>> seatsByRow;

    public ShowSeatMapDto() {}

    public ShowSeatMapDto(Long showId, String movieTitle, String theatreName, String screenName,
                          String screenType, LocalDateTime startTime, BigDecimal priceMultiplier,
                          int totalSeats, int availableSeats, Map<String, List<SeatStatusDto>> seatsByRow) {
        this.showId = showId;
        this.movieTitle = movieTitle;
        this.theatreName = theatreName;
        this.screenName = screenName;
        this.screenType = screenType;
        this.startTime = startTime;
        this.priceMultiplier = priceMultiplier;
        this.totalSeats = totalSeats;
        this.availableSeats = availableSeats;
        this.seatsByRow = seatsByRow;
    }

    public Long getShowId() { return showId; }
    public void setShowId(Long showId) { this.showId = showId; }

    public String getMovieTitle() { return movieTitle; }
    public void setMovieTitle(String movieTitle) { this.movieTitle = movieTitle; }

    public String getTheatreName() { return theatreName; }
    public void setTheatreName(String theatreName) { this.theatreName = theatreName; }

    public String getScreenName() { return screenName; }
    public void setScreenName(String screenName) { this.screenName = screenName; }

    public String getScreenType() { return screenType; }
    public void setScreenType(String screenType) { this.screenType = screenType; }

    public LocalDateTime getStartTime() { return startTime; }
    public void setStartTime(LocalDateTime startTime) { this.startTime = startTime; }

    public BigDecimal getPriceMultiplier() { return priceMultiplier; }
    public void setPriceMultiplier(BigDecimal priceMultiplier) { this.priceMultiplier = priceMultiplier; }

    public int getTotalSeats() { return totalSeats; }
    public void setTotalSeats(int totalSeats) { this.totalSeats = totalSeats; }

    public int getAvailableSeats() { return availableSeats; }
    public void setAvailableSeats(int availableSeats) { this.availableSeats = availableSeats; }

    public Map<String, List<SeatStatusDto>> getSeatsByRow() { return seatsByRow; }
    public void setSeatsByRow(Map<String, List<SeatStatusDto>> seatsByRow) { this.seatsByRow = seatsByRow; }
}
