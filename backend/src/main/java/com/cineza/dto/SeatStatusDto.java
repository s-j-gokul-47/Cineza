package com.cineza.dto;

import com.cineza.model.enums.SeatStatus;
import com.cineza.model.enums.SeatType;
import java.math.BigDecimal;

public class SeatStatusDto {

    private Long id;
    private String rowName;
    private Integer seatNumber;
    private SeatType seatType;
    private BigDecimal price;
    private SeatStatus status;
    private boolean lockedByCurrentUser;

    public SeatStatusDto() {}

    public SeatStatusDto(Long id, String rowName, Integer seatNumber, SeatType seatType,
                         BigDecimal price, SeatStatus status, boolean lockedByCurrentUser) {
        this.id = id;
        this.rowName = rowName;
        this.seatNumber = seatNumber;
        this.seatType = seatType;
        this.price = price;
        this.status = status;
        this.lockedByCurrentUser = lockedByCurrentUser;
    }

    public Long getId() { return id; }
    public void setId(Long id) { this.id = id; }

    public String getRowName() { return rowName; }
    public void setRowName(String rowName) { this.rowName = rowName; }

    public Integer getSeatNumber() { return seatNumber; }
    public void setSeatNumber(Integer seatNumber) { this.seatNumber = seatNumber; }

    public SeatType getSeatType() { return seatType; }
    public void setSeatType(SeatType seatType) { this.seatType = seatType; }

    public BigDecimal getPrice() { return price; }
    public void setPrice(BigDecimal price) { this.price = price; }

    public SeatStatus getStatus() { return status; }
    public void setStatus(SeatStatus status) { this.status = status; }

    public boolean isLockedByCurrentUser() { return lockedByCurrentUser; }
    public void setLockedByCurrentUser(boolean lockedByCurrentUser) { this.lockedByCurrentUser = lockedByCurrentUser; }
}
