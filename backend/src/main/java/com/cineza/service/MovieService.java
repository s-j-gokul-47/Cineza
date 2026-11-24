package com.cineza.service;

import com.cineza.model.Movie;
import com.cineza.repository.MovieRepository;
import com.fasterxml.jackson.databind.JavaType;
import org.springframework.stereotype.Service;

import java.util.List;
import java.util.Optional;

@Service
public class MovieService {

    private final MovieRepository movieRepository;
    private final CacheService cacheService;

    public MovieService(MovieRepository movieRepository, CacheService cacheService) {
        this.movieRepository = movieRepository;
        this.cacheService = cacheService;
    }

    public List<Movie> getAllActiveMovies() {
        String key = "cineza:cache:movies:all";
        JavaType type = cacheService.getObjectMapper().getTypeFactory().constructCollectionType(List.class, Movie.class);
        return cacheService.getOrComputeList(key, 900, type, movieRepository::findByIsActiveTrue);
    }

    public List<Movie> getMoviesByCity(Long cityId) {
        if (cityId == null) {
            return getAllActiveMovies();
        }
        String key = "cineza:cache:movies:city:" + cityId;
        JavaType type = cacheService.getObjectMapper().getTypeFactory().constructCollectionType(List.class, Movie.class);
        return cacheService.getOrComputeList(key, 900, type, () -> {
            List<Movie> cityMovies = movieRepository.findMoviesByCityId(cityId);
            return cityMovies.isEmpty() ? movieRepository.findByIsActiveTrue() : cityMovies;
        });
    }

    public List<Movie> searchMovies(String keyword) {
        if (keyword == null || keyword.trim().isEmpty()) {
            return getAllActiveMovies();
        }
        String cleanKeyword = keyword.trim().toLowerCase();
        String key = "cineza:cache:movies:search:" + cleanKeyword;
        JavaType type = cacheService.getObjectMapper().getTypeFactory().constructCollectionType(List.class, Movie.class);
        return cacheService.getOrComputeList(key, 900, type, () -> movieRepository.searchMovies(cleanKeyword));
    }

    public List<Movie> getMoviesByGenre(String genre) {
        if (genre == null || genre.trim().isEmpty() || "All".equalsIgnoreCase(genre)) {
            return getAllActiveMovies();
        }
        String cleanGenre = genre.trim().toLowerCase();
        String key = "cineza:cache:movies:genre:" + cleanGenre;
        JavaType type = cacheService.getObjectMapper().getTypeFactory().constructCollectionType(List.class, Movie.class);
        return cacheService.getOrComputeList(key, 900, type, () -> movieRepository.findByGenreIgnoreCaseAndIsActiveTrue(cleanGenre));
    }

    public Optional<Movie> getMovieById(Long id) {
        if (id == null) return Optional.empty();
        String key = "cineza:cache:movie:" + id;
        Movie movie = cacheService.getOrCompute(key, 1800, Movie.class, () -> movieRepository.findById(id).orElse(null));
        return Optional.ofNullable(movie);
    }

    public Movie saveMovie(Movie movie) {
        Movie saved = movieRepository.save(movie);
        // Invalidate all movie caches on mutation
        cacheService.evictPattern("cineza:cache:movies:*");
        if (saved.getId() != null) {
            cacheService.evict("cineza:cache:movie:" + saved.getId());
        }
        return saved;
    }
}
