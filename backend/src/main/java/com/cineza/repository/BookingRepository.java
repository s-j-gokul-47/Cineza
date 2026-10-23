package com.cineza.repository;

import com.cineza.model.Booking;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;

@Repository
public interface BookingRepository extends JpaRepository<Booking, Long> {
    
    Optional<Booking> findByBookingReference(String bookingReference);

    List<Booking> findByUserEmailOrderByCreatedAtDesc(String userEmail);

    @Query("SELECT bs.seat.id FROM Booking b JOIN b.bookingSeats bs WHERE b.show.id = :showId AND b.status = 'CONFIRMED'")
    List<Long> findBookedSeatIdsByShowId(@Param("showId") Long showId);
}
