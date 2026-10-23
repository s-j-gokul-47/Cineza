package com.cineza.service;

import com.cineza.dto.SeatStatusDto;
import com.cineza.dto.ShowDto;
import com.cineza.dto.ShowSeatMapDto;
import com.cineza.model.Seat;
import com.cineza.model.Show;
import com.cineza.model.enums.SeatStatus;
import com.cineza.repository.BookingRepository;
import com.cineza.repository.SeatRepository;
import com.cineza.repository.ShowRepository;
import org.springframework.stereotype.Service;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.LocalTime;
import java.util.*;
import java.util.stream.Collectors;

@Service
public class ShowService {

    private final ShowRepository showRepository;
    private final SeatRepository seatRepository;
    private final BookingRepository bookingRepository;
    private final SeatLockService seatLockService;

    public ShowService(ShowRepository showRepository,
                       SeatRepository seatRepository,
                       BookingRepository bookingRepository,
                       SeatLockService seatLockService) {
        this.showRepository = showRepository;
        this.seatRepository = seatRepository;
        this.bookingRepository = bookingRepository;
        this.seatLockService = seatLockService;
    }

    public List<ShowDto> getShows(Long movieId, Long cityId, LocalDate date) {
        List<Show> shows;
        if (movieId != null && cityId != null && date != null) {
            LocalDateTime startOfDay = date.atStartOfDay();
            LocalDateTime endOfDay = date.atTime(LocalTime.MAX);
            shows = showRepository.findShowsByMovieAndCityAndDate(movieId, cityId, startOfDay, endOfDay);
        } else if (movieId != null) {
            shows = showRepository.findByMovieId(movieId);
        } else {
            shows = showRepository.findAll();
        }

        return shows.stream().map(this::mapToShowDto).collect(Collectors.toList());
    }

    public Optional<Show> getShowById(Long id) {
        return showRepository.findById(id);
    }

    /**
     * Builds interactive seat layout map for a show with real-time seat states:
     * - BOOKED (persisted in MySQL)
     * - LOCKED (active in Redis with 10-minute TTL)
     * - AVAILABLE
     */
    public ShowSeatMapDto getShowSeatMap(Long showId, String currentLockToken) {
        Show show = showRepository.findById(showId)
                .orElseThrow(() -> new IllegalArgumentException("Show not found with ID: " + showId));

        List<Seat> seats = seatRepository.findByScreenIdOrderByRowNameAscSeatNumberAsc(show.getScreen().getId());
        List<Long> bookedSeatIds = bookingRepository.findBookedSeatIdsByShowId(showId);
        Set<Long> lockedSeatIds = seatLockService.getLockedSeatIds(showId);

        Map<String, List<SeatStatusDto>> seatsByRow = new LinkedHashMap<>();
        int availableCount = 0;

        for (Seat seat : seats) {
            SeatStatus status;
            boolean lockedByCurrentUser = false;

            if (bookedSeatIds.contains(seat.getId())) {
                status = SeatStatus.BOOKED;
            } else if (lockedSeatIds.contains(seat.getId())) {
                status = SeatStatus.LOCKED;
                lockedByCurrentUser = seatLockService.isSeatLockedByUser(showId, seat.getId(), currentLockToken);
            } else {
                status = SeatStatus.AVAILABLE;
                availableCount++;
            }

            BigDecimal dynamicPrice = seat.getBasePrice()
                    .multiply(show.getPriceMultiplier())
                    .setScale(2, RoundingMode.HALF_UP);

            SeatStatusDto seatDto = new SeatStatusDto(
                    seat.getId(),
                    seat.getRowName(),
                    seat.getSeatNumber(),
                    seat.getSeatType(),
                    dynamicPrice,
                    status,
                    lockedByCurrentUser
            );

            seatsByRow.computeIfAbsent(seat.getRowName(), k -> new ArrayList<>()).add(seatDto);
        }

        return new ShowSeatMapDto(
                show.getId(),
                show.getMovie().getTitle(),
                show.getScreen().getTheatre().getName(),
                show.getScreen().getScreenName(),
                show.getScreen().getScreenType().name(),
                show.getStartTime(),
                show.getPriceMultiplier(),
                seats.size(),
                availableCount,
                seatsByRow
        );
    }

    public ShowDto mapToShowDto(Show show) {
        BigDecimal baseStartingPrice = BigDecimal.valueOf(15.00)
                .multiply(show.getPriceMultiplier())
                .setScale(2, RoundingMode.HALF_UP);

        return new ShowDto(
                show.getId(),
                show.getMovie().getId(),
                show.getMovie().getTitle(),
                show.getScreen().getTheatre().getId(),
                show.getScreen().getTheatre().getName(),
                show.getScreen().getTheatre().getAddress(),
                show.getScreen().getId(),
                show.getScreen().getScreenName(),
                show.getScreen().getScreenType(),
                show.getStartTime(),
                show.getEndTime(),
                baseStartingPrice
        );
    }
}
