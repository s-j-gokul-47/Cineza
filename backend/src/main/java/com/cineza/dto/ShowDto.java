package com.cineza.dto;

import com.cineza.model.enums.ScreenType;
import java.math.BigDecimal;
import java.time.LocalDateTime;

public class ShowDto {

    private Long id;
    private Long movieId;
    private String movieTitle;
    private Long theatreId;
    private String theatreName;
    private String theatreAddress;
    private Long screenId;
    private String screenName;
    private ScreenType screenType;
    private LocalDateTime startTime;
    private LocalDateTime endTime;
    private BigDecimal baseStartingPrice;

    public ShowDto() {}

    public ShowDto(Long id, Long movieId, String movieTitle, Long theatreId, String theatreName,
                   String theatreAddress, Long screenId, String screenName, ScreenType screenType,
                   LocalDateTime startTime, LocalDateTime endTime, BigDecimal baseStartingPrice) {
        this.id = id;
        this.movieId = movieId;
        this.movieTitle = movieTitle;
        this.theatreId = theatreId;
        this.theatreName = theatreName;
        this.theatreAddress = theatreAddress;
        this.screenId = screenId;
        this.screenName = screenName;
        this.screenType = screenType;
        this.startTime = startTime;
        this.endTime = endTime;
        this.baseStartingPrice = baseStartingPrice;
    }

    public Long getId() { return id; }
    public void setId(Long id) { this.id = id; }

    public Long getMovieId() { return movieId; }
    public void setMovieId(Long movieId) { this.movieId = movieId; }

    public String getMovieTitle() { return movieTitle; }
    public void setMovieTitle(String movieTitle) { this.movieTitle = movieTitle; }

    public Long getTheatreId() { return theatreId; }
    public void setTheatreId(Long theatreId) { this.theatreId = theatreId; }

    public String getTheatreName() { return theatreName; }
    public void setTheatreName(String theatreName) { this.theatreName = theatreName; }

    public String getTheatreAddress() { return theatreAddress; }
    public void setTheatreAddress(String theatreAddress) { this.theatreAddress = theatreAddress; }

    public Long getScreenId() { return screenId; }
    public void setScreenId(Long screenId) { this.screenId = screenId; }

    public String getScreenName() { return screenName; }
    public void setScreenName(String screenName) { this.screenName = screenName; }

    public ScreenType getScreenType() { return screenType; }
    public void setScreenType(ScreenType screenType) { this.screenType = screenType; }

    public LocalDateTime getStartTime() { return startTime; }
    public void setStartTime(LocalDateTime startTime) { this.startTime = startTime; }

    public LocalDateTime getEndTime() { return endTime; }
    public void setEndTime(LocalDateTime endTime) { this.endTime = endTime; }

    public BigDecimal getBaseStartingPrice() { return baseStartingPrice; }
    public void setBaseStartingPrice(BigDecimal baseStartingPrice) { this.baseStartingPrice = baseStartingPrice; }
}
