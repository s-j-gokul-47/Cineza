package com.cineza.controller;

import com.cineza.dto.ShowDto;
import com.cineza.dto.ShowSeatMapDto;
import com.cineza.service.ShowService;
import org.springframework.format.annotation.DateTimeFormat;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.time.LocalDate;
import java.util.List;

@RestController
@RequestMapping("/api/v1/shows")
public class ShowController {

    private final ShowService showService;

    public ShowController(ShowService showService) {
        this.showService = showService;
    }

    @GetMapping
    public ResponseEntity<List<ShowDto>> getShows(
            @RequestParam(required = false) Long movieId,
            @RequestParam(required = false) Long cityId,
            @RequestParam(required = false) String cityName,
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate date) {
        return ResponseEntity.ok(showService.getShows(movieId, cityId, cityName, date));
    }

    @GetMapping("/{showId}")
    public ResponseEntity<ShowDto> getShowById(@PathVariable Long showId) {
        return showService.getShowById(showId)
                .map(show -> ResponseEntity.ok(showService.mapToShowDto(show)))
                .orElse(ResponseEntity.notFound().build());
    }

    /**
     * Returns the full interactive screen seat layout for a show,
     * including live Redis lock statuses and MySQL booking statuses.
     */
    @GetMapping("/{showId}/seats")
    public ResponseEntity<ShowSeatMapDto> getShowSeatMap(
            @PathVariable Long showId,
            @RequestParam(required = false) String lockToken) {
        return ResponseEntity.ok(showService.getShowSeatMap(showId, lockToken));
    }
}
