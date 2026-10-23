package com.cineza.model;

import com.cineza.model.enums.ScreenType;
import com.fasterxml.jackson.annotation.JsonIgnore;
import jakarta.persistence.*;
import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.List;

@Entity
@Table(name = "screens", uniqueConstraints = {
    @UniqueConstraint(columnNames = {"theatre_id", "screen_number"})
})
public class Screen {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(fetch = FetchType.EAGER)
    @JoinColumn(name = "theatre_id", nullable = false)
    private Theatre theatre;

    @Column(name = "screen_number", nullable = false)
    private Integer screenNumber;

    @Column(name = "screen_name", nullable = false, length = 100)
    private String screenName;

    @Enumerated(EnumType.STRING)
    @Column(name = "screen_type", length = 50)
    private ScreenType screenType = ScreenType.STANDARD;

    @Column(name = "total_seats")
    private Integer totalSeats = 0;

    @JsonIgnore
    @OneToMany(mappedBy = "screen", cascade = CascadeType.ALL, fetch = FetchType.LAZY)
    private List<Seat> seats = new ArrayList<>();

    @Column(name = "created_at", updatable = false)
    private LocalDateTime createdAt = LocalDateTime.now();

    public Screen() {}

    public Screen(Theatre theatre, Integer screenNumber, String screenName, ScreenType screenType, Integer totalSeats) {
        this.theatre = theatre;
        this.screenNumber = screenNumber;
        this.screenName = screenName;
        this.screenType = screenType;
        this.totalSeats = totalSeats;
        this.createdAt = LocalDateTime.now();
    }

    public Long getId() { return id; }
    public void setId(Long id) { this.id = id; }

    public Theatre getTheatre() { return theatre; }
    public void setTheatre(Theatre theatre) { this.theatre = theatre; }

    public Integer getScreenNumber() { return screenNumber; }
    public void setScreenNumber(Integer screenNumber) { this.screenNumber = screenNumber; }

    public String getScreenName() { return screenName; }
    public void setScreenName(String screenName) { this.screenName = screenName; }

    public ScreenType getScreenType() { return screenType; }
    public void setScreenType(ScreenType screenType) { this.screenType = screenType; }

    public Integer getTotalSeats() { return totalSeats; }
    public void setTotalSeats(Integer totalSeats) { this.totalSeats = totalSeats; }

    public List<Seat> getSeats() { return seats; }
    public void setSeats(List<Seat> seats) { this.seats = seats; }

    public LocalDateTime getCreatedAt() { return createdAt; }
    public void setCreatedAt(LocalDateTime createdAt) { this.createdAt = createdAt; }
}
