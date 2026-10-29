package com.cineza.controller;

import com.cineza.model.Movie;
import com.cineza.service.MovieService;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/api/v1/movies")
public class MovieController {

    private final MovieService movieService;

    public MovieController(MovieService movieService) {
        this.movieService = movieService;
    }

    /**
     * Search and discovery endpoint supporting city filtering, keyword search, and genre filtering
     */
    @GetMapping
    public ResponseEntity<List<Movie>> getMovies(
            @RequestParam(required = false) Long cityId,
            @RequestParam(required = false) String search,
            @RequestParam(required = false) String genre) {

        if (search != null && !search.trim().isEmpty()) {
            return ResponseEntity.ok(movieService.searchMovies(search));
        }

        if (genre != null && !genre.trim().isEmpty()) {
            if ("All".equalsIgnoreCase(genre.trim())) {
                return ResponseEntity.ok(movieService.getAllActiveMovies());
            }
            return ResponseEntity.ok(movieService.getMoviesByGenre(genre.trim()));
        }

        if (cityId != null) {
            return ResponseEntity.ok(movieService.getMoviesByCity(cityId));
        }

        return ResponseEntity.ok(movieService.getAllActiveMovies());
    }

    @GetMapping("/{id}")
    public ResponseEntity<Movie> getMovieById(@PathVariable Long id) {
        return movieService.getMovieById(id)
                .map(ResponseEntity::ok)
                .orElse(ResponseEntity.notFound().build());
    }
}
