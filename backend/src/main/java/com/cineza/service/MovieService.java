package com.cineza.service;

import com.cineza.model.Movie;
import com.cineza.repository.MovieRepository;
import org.springframework.stereotype.Service;

import java.util.List;
import java.util.Optional;

@Service
public class MovieService {

    private final MovieRepository movieRepository;

    public MovieService(MovieRepository movieRepository) {
        this.movieRepository = movieRepository;
    }

    public List<Movie> getAllActiveMovies() {
        return movieRepository.findByIsActiveTrue();
    }

    public List<Movie> getMoviesByCity(Long cityId) {
        if (cityId == null) {
            return getAllActiveMovies();
        }
        List<Movie> cityMovies = movieRepository.findMoviesByCityId(cityId);
        return cityMovies.isEmpty() ? getAllActiveMovies() : cityMovies;
    }

    public List<Movie> searchMovies(String keyword) {
        if (keyword == null || keyword.trim().isEmpty()) {
            return getAllActiveMovies();
        }
        return movieRepository.searchMovies(keyword.trim());
    }

    public List<Movie> getMoviesByGenre(String genre) {
        if (genre == null || genre.trim().isEmpty() || "All".equalsIgnoreCase(genre)) {
            return getAllActiveMovies();
        }
        return movieRepository.findByGenreIgnoreCaseAndIsActiveTrue(genre.trim());
    }

    public Optional<Movie> getMovieById(Long id) {
        return movieRepository.findById(id);
    }

    public Movie saveMovie(Movie movie) {
        return movieRepository.save(movie);
    }
}
