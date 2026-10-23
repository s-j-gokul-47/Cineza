package com.cineza.repository;

import com.cineza.model.Movie;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.util.List;

@Repository
public interface MovieRepository extends JpaRepository<Movie, Long> {
    
    List<Movie> findByIsActiveTrue();

    @Query("SELECT DISTINCT m FROM Movie m JOIN m.shows s JOIN s.screen sc JOIN sc.theatre t " +
           "WHERE t.city.id = :cityId AND m.isActive = true")
    List<Movie> findMoviesByCityId(@Param("cityId") Long cityId);

    @Query("SELECT m FROM Movie m WHERE m.isActive = true AND " +
           "(LOWER(m.title) LIKE LOWER(CONCAT('%', :keyword, '%')) OR " +
           " LOWER(m.genre) LIKE LOWER(CONCAT('%', :keyword, '%')) OR " +
           " LOWER(m.language) LIKE LOWER(CONCAT('%', :keyword, '%')))")
    List<Movie> searchMovies(@Param("keyword") String keyword);

    List<Movie> findByGenreIgnoreCaseAndIsActiveTrue(String genre);
}
