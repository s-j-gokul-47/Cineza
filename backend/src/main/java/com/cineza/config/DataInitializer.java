package com.cineza.config;

import com.cineza.model.*;
import com.cineza.model.enums.BookingStatus;
import com.cineza.model.enums.ScreenType;
import com.cineza.model.enums.SeatType;
import com.cineza.repository.*;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.boot.CommandLineRunner;
import org.springframework.stereotype.Component;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.List;

@Component
public class DataInitializer implements CommandLineRunner {

    private static final Logger log = LoggerFactory.getLogger(DataInitializer.class);

    private final CityRepository cityRepository;
    private final TheatreRepository theatreRepository;
    private final ScreenRepository screenRepository;
    private final SeatRepository seatRepository;
    private final MovieRepository movieRepository;
    private final ShowRepository showRepository;
    private final BookingRepository bookingRepository;
    private final BookingSeatRepository bookingSeatRepository;

    public DataInitializer(CityRepository cityRepository,
                           TheatreRepository theatreRepository,
                           ScreenRepository screenRepository,
                           SeatRepository seatRepository,
                           MovieRepository movieRepository,
                           ShowRepository showRepository,
                           BookingRepository bookingRepository,
                           BookingSeatRepository bookingSeatRepository) {
        this.cityRepository = cityRepository;
        this.theatreRepository = theatreRepository;
        this.screenRepository = screenRepository;
        this.seatRepository = seatRepository;
        this.movieRepository = movieRepository;
        this.showRepository = showRepository;
        this.bookingRepository = bookingRepository;
        this.bookingSeatRepository = bookingSeatRepository;
    }

    @Override
    public void run(String... args) {
        if (cityRepository.count() > 0) {
            log.info("Cineza database already seeded. Skipping initial seeding.");
            return;
        }

        log.info("Seeding Cineza database with cities, theatres, screens, tiered seats, movies, and shows...");

        // 1. Cities
        City ny = cityRepository.save(new City("New York", "NY", "USA"));
        City la = cityRepository.save(new City("Los Angeles", "CA", "USA"));
        City sf = cityRepository.save(new City("San Francisco", "CA", "USA"));
        City ch = cityRepository.save(new City("Chicago", "IL", "USA"));

        // 2. Theatres
        Theatre amcNy = theatreRepository.save(new Theatre("Cineza IMAX Grand 4K", "234 W 42nd St, Times Square", ny, 3));
        Theatre regalNy = theatreRepository.save(new Theatre("Regal Battery Park Cinema", "102 North End Ave", ny, 2));
        Theatre amcLa = theatreRepository.save(new Theatre("AMC Century City 15", "10250 Santa Monica Blvd", la, 2));
        theatreRepository.save(new Theatre("Alamo Drafthouse Cinema", "2550 Mission St", sf, 2));

        // 3. Screens for Cineza IMAX Grand
        Screen screen1 = screenRepository.save(new Screen(amcNy, 1, "Auditorium 1 (IMAX Laser)", ScreenType.IMAX, 60));
        Screen screen2 = screenRepository.save(new Screen(amcNy, 2, "Auditorium 2 (Dolby Cinema)", ScreenType.DOLBY, 50));
        Screen screen3 = screenRepository.save(new Screen(regalNy, 1, "Screen 1 (Standard)", ScreenType.STANDARD, 40));
        Screen screenLa = screenRepository.save(new Screen(amcLa, 1, "Screen 1 (Dolby Atmos)", ScreenType.DOLBY, 50));

        // 4. Seats for Screen 1 (6 rows A-F, 10 seats per row = 60 seats)
        // Rows A-B: VIP Recliners ($24.00)
        // Rows C-D: Premium ($18.00)
        // Rows E-F: Standard ($14.00)
        List<Seat> screen1Seats = new ArrayList<>();
        String[] rows = {"A", "B", "C", "D", "E", "F"};
        for (String row : rows) {
            SeatType type;
            BigDecimal price;
            if (row.equals("A") || row.equals("B")) {
                type = SeatType.VIP;
                price = new BigDecimal("24.00");
            } else if (row.equals("C") || row.equals("D")) {
                type = SeatType.PREMIUM;
                price = new BigDecimal("18.00");
            } else {
                type = SeatType.STANDARD;
                price = new BigDecimal("14.00");
            }

            for (int num = 1; num <= 10; num++) {
                screen1Seats.add(new Seat(screen1, row, num, type, price));
            }
        }
        screen1Seats = seatRepository.saveAll(screen1Seats);

        // Seats for Screen 2 (5 rows A-E, 10 seats per row = 50 seats)
        List<Seat> screen2Seats = new ArrayList<>();
        for (String row : new String[]{"A", "B", "C", "D", "E"}) {
            SeatType type = row.equals("A") ? SeatType.VIP : (row.equals("B") || row.equals("C") ? SeatType.PREMIUM : SeatType.STANDARD);
            BigDecimal price = type == SeatType.VIP ? new BigDecimal("22.00") : (type == SeatType.PREMIUM ? new BigDecimal("17.00") : new BigDecimal("13.00"));
            for (int num = 1; num <= 10; num++) {
                screen2Seats.add(new Seat(screen2, row, num, type, price));
            }
        }
        seatRepository.saveAll(screen2Seats);

        // 5. Movies
        Movie dune2 = movieRepository.save(new Movie(
                "Dune: Part Two",
                "Paul Atreides unites with Chani and the Fremen while seeking revenge against the conspirators who destroyed his family.",
                "https://image.tmdb.org/t/p/w500/1pdfLvkbY9ohJlCjQH2CZjjYVvJ.jpg",
                "https://image.tmdb.org/t/p/original/xOMo8BRK7PfcJv9JCnx7s5200bm.jpg",
                "Sci-Fi", "English", 166, "PG-13", new BigDecimal("8.6"), LocalDate.now().minusDays(30)
        ));

        Movie oppenheimer = movieRepository.save(new Movie(
                "Oppenheimer",
                "The story of American scientist J. Robert Oppenheimer and his role in the development of the atomic bomb during WWII.",
                "https://image.tmdb.org/t/p/w500/8Gxv8gSFCU0XGDykEGv7zR1n2ua.jpg",
                "https://image.tmdb.org/t/p/original/rM5Y09xC99JeNEiYxZY635xUvDC.jpg",
                "Biography", "English", 180, "R", new BigDecimal("8.9"), LocalDate.now().minusDays(60)
        ));

        Movie interstellar = movieRepository.save(new Movie(
                "Interstellar",
                "When Earth becomes uninhabitable in the future, a farmer and ex-NASA pilot is tasked to pilot a spacecraft along with a team of researchers.",
                "https://image.tmdb.org/t/p/w500/gEU2QniE6E77NI6lCU6MxlNBvIx.jpg",
                "https://image.tmdb.org/t/p/original/xJHokMbljvjADYdit5fK5VQsXEG.jpg",
                "Sci-Fi", "English", 169, "PG-13", new BigDecimal("8.7"), LocalDate.now().minusDays(365)
        ));

        Movie spiderVerse = movieRepository.save(new Movie(
                "Spider-Man: Across the Spider-Verse",
                "Miles Morales catapults across the Multiverse, where he encounters a team of Spider-People charged with protecting its very existence.",
                "https://image.tmdb.org/t/p/w500/8Vt6mWEReuy4Of61Lnj5Xj704m8.jpg",
                "https://image.tmdb.org/t/p/original/4HodYYKEIsGOdinkGi2Ucz6X9i0.jpg",
                "Animation", "English", 140, "PG", new BigDecimal("8.7"), LocalDate.now().minusDays(120)
        ));

        Movie darkKnight = movieRepository.save(new Movie(
                "The Dark Knight",
                "When the menace known as the Joker wreaks havoc and chaos on the people of Gotham, Batman must accept one of the greatest psychological and physical tests.",
                "https://image.tmdb.org/t/p/w500/qJ2tW6WMUDux911r6m7haRef0WH.jpg",
                "https://image.tmdb.org/t/p/original/dqK9Hag1054tghRQSqLSfrkvQnA.jpg",
                "Action", "English", 152, "PG-13", new BigDecimal("9.0"), LocalDate.now().minusDays(1000)
        ));

        // 6. Shows for Today and Tomorrow
        LocalDate today = LocalDate.now();
        List<Show> createdShows = new ArrayList<>();

        // Dune 2 shows
        Show show1 = showRepository.save(new Show(dune2, screen1, today.atTime(14, 30), today.atTime(17, 15), new BigDecimal("1.20")));
        Show show2 = showRepository.save(new Show(dune2, screen1, today.atTime(18, 45), today.atTime(21, 30), new BigDecimal("1.30")));
        Show show3 = showRepository.save(new Show(dune2, screen2, today.atTime(20, 0), today.atTime(22, 45), new BigDecimal("1.15")));
        createdShows.add(show1);

        // Oppenheimer shows
        showRepository.save(new Show(oppenheimer, screen2, today.atTime(15, 0), today.atTime(18, 0), new BigDecimal("1.25")));
        showRepository.save(new Show(oppenheimer, screen1, today.plusDays(1).atTime(19, 0), today.plusDays(1).atTime(22, 0), new BigDecimal("1.30")));

        // Interstellar shows
        showRepository.save(new Show(interstellar, screen1, today.atTime(22, 0), today.plusDays(1).atTime(0, 50), new BigDecimal("1.20")));
        showRepository.save(new Show(spiderVerse, screen3, today.atTime(16, 30), today.atTime(18, 50), new BigDecimal("1.00")));
        showRepository.save(new Show(darkKnight, screenLa, today.atTime(19, 30), today.atTime(22, 0), new BigDecimal("1.25")));

        // 7. Seed an existing sample booking for Show 1 so some seats (e.g. C5, C6) show as BOOKED
        if (screen1Seats.size() >= 26) {
            Seat bookedSeat1 = screen1Seats.get(24); // C5
            Seat bookedSeat2 = screen1Seats.get(25); // C6

            Booking sampleBooking = new Booking("CNZ-INIT9988", show1, "alex.demo@cineza.com", "+1-555-0192", new BigDecimal("46.80"));
            sampleBooking.setStatus(BookingStatus.CONFIRMED);
            Booking savedBooking = bookingRepository.save(sampleBooking);

            bookingSeatRepository.save(new BookingSeat(savedBooking, bookedSeat1, new BigDecimal("23.40")));
            bookingSeatRepository.save(new BookingSeat(savedBooking, bookedSeat2, new BigDecimal("23.40")));
            log.info("Seeded sample booking with seats C5 & C6 as BOOKED for show {}", show1.getId());
        }

        log.info("Cineza database initialization completed successfully! Total movies: {}, Total shows: {}",
                movieRepository.count(), showRepository.count());
    }
}
