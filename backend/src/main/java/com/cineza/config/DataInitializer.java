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

        // 5. Movies (Recommended Sci-Fi, Action, and Biography titles)
        Movie movie24 = movieRepository.save(new Movie(
                "24",
                "A sci-fi thriller about a genius watchmaker who invents a time-travel watch. When his vengeful twin brother Athreya resurfaces to claim it, a thrilling war across timelines begins.",
                "assets/images/movie_24.jpg",
                "assets/images/titlecard_24.png",
                "Sci-Fi", "Tamil", 164, "UA", new BigDecimal("7.9"), LocalDate.now().minusDays(30)
        ));

        Movie sooraraiPottru = movieRepository.save(new Movie(
                "Soorarai Pottru",
                "Nedumaaran Rajangam, a former air force captain, dreams of launching a low-cost airline so that every common person can fly, braving corrupt corporate aviation cartels.",
                "assets/images/movie_soorarai_pottru.jpg",
                "assets/images/titlecard_soorarai_pottru.jpg",
                "Biography", "Tamil", 153, "U", new BigDecimal("8.7"), LocalDate.now().minusDays(60)
        ));

        Movie maanaadu = movieRepository.save(new Movie(
                "Maanaadu",
                "Abdul Khaaliq and DCP Dhanushkodi find themselves stuck in a bizarre, relentless time loop on the day of a massive public conference where a political assassination is orchestrated.",
                "assets/images/movie_maanaadu.jpg",
                "assets/images/titlecard_maanaadu.png",
                "Sci-Fi", "Tamil", 147, "UA", new BigDecimal("8.3"), LocalDate.now().minusDays(365)
        ));

        Movie kgf2 = movieRepository.save(new Movie(
                "KGF: Chapter 2",
                "Having captured the gold throne of Narachi, Rocky continues his quest for absolute power while clashing with the ferocious Adheera and prime minister Ramika Sen.",
                "assets/images/movie_kgf2.jpg",
                "assets/images/titlecard_kgf2.png",
                "Action", "Kannada", 168, "UA", new BigDecimal("8.2"), LocalDate.now().minusDays(120)
        ));

        Movie vikram = movieRepository.save(new Movie(
                "Vikram",
                "A special operations black-ops commander unmasks a lethal syndicate cartel run by drug lord Sandhanam, sparking high-octane warfare across the underworld.",
                "assets/images/movie_vikram.jpg",
                "assets/images/movie_vikram.jpg",
                "Action", "Tamil", 175, "UA", new BigDecimal("8.3"), LocalDate.now().minusDays(1000)
        ));

        // 6. Shows for Today and Tomorrow
        LocalDate today = LocalDate.now();
        List<Show> createdShows = new ArrayList<>();

        // 24 shows
        Show show1 = showRepository.save(new Show(movie24, screen1, today.atTime(14, 30), today.atTime(17, 15), new BigDecimal("1.20")));
        Show show2 = showRepository.save(new Show(movie24, screen1, today.atTime(18, 45), today.atTime(21, 30), new BigDecimal("1.30")));
        Show show3 = showRepository.save(new Show(movie24, screen2, today.atTime(20, 0), today.atTime(22, 45), new BigDecimal("1.15")));
        createdShows.add(show1);

        // Soorarai Pottru shows
        showRepository.save(new Show(sooraraiPottru, screen2, today.atTime(15, 0), today.atTime(18, 0), new BigDecimal("1.25")));
        showRepository.save(new Show(sooraraiPottru, screen1, today.plusDays(1).atTime(19, 0), today.plusDays(1).atTime(22, 0), new BigDecimal("1.30")));

        // Maanaadu, KGF 2, Vikram shows
        showRepository.save(new Show(maanaadu, screen1, today.atTime(22, 0), today.plusDays(1).atTime(0, 50), new BigDecimal("1.20")));
        showRepository.save(new Show(kgf2, screen3, today.atTime(16, 30), today.atTime(18, 50), new BigDecimal("1.00")));
        showRepository.save(new Show(vikram, screenLa, today.atTime(19, 30), today.atTime(22, 0), new BigDecimal("1.25")));

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
