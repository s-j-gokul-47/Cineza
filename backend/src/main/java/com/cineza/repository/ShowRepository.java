package com.cineza.repository;

import com.cineza.model.Show;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.time.LocalDateTime;
import java.util.List;

@Repository
public interface ShowRepository extends JpaRepository<Show, Long> {

    List<Show> findByMovieId(Long movieId);

    @Query("SELECT s FROM Show s JOIN s.screen sc JOIN sc.theatre t " +
           "WHERE s.movie.id = :movieId " +
           "AND t.city.id = :cityId " +
           "AND s.startTime >= :startOfDay " +
           "AND s.startTime <= :endOfDay " +
           "ORDER BY s.startTime ASC")
    List<Show> findShowsByMovieAndCityAndDate(
            @Param("movieId") Long movieId,
            @Param("cityId") Long cityId,
            @Param("startOfDay") LocalDateTime startOfDay,
            @Param("endOfDay") LocalDateTime endOfDay);

    @Query("SELECT s FROM Show s JOIN s.screen sc WHERE sc.theatre.id = :theatreId AND s.startTime >= :now ORDER BY s.startTime ASC")
    List<Show> findUpcomingShowsByTheatre(@Param("theatreId") Long theatreId, @Param("now") LocalDateTime now);
}
