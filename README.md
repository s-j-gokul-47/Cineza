# 🎬 Cineza - Full-Stack Movie Ticketing Platform

> A full-stack cinema ticketing system featuring a **Spring Boot 3** REST API backend, **MySQL** persistence, **Redis** distributed seat locking with 10-minute TTL, and an interactive **Flutter 3** frontend with dark cinematic aesthetics.

---

## 🌟 Key Features

- **Movie Discovery & Search**: Filter movies by city, genre, and keyword with responsive hero billboard and posters.
- **Showtimes & Theatres**: Real-time screening schedules across IMAX, Dolby Cinema, and Standard auditoriums.
- **Interactive 2D Curved Seat Matrix**: Screen visualization with curved projection beam glow, tiered seating (VIP Recliner, Premium, Standard), and status indicators (Available, Selected, Locked, Booked).
- **Concurrent Redis Seat Locking**: Distributed multi-seat locking mechanism with strict **10-minute TTL (600s)** and atomic rollback on conflicts to eliminate double-booking.
- **Stateless JWT Security**: Spring Security 6 integration with bearer token authentication, BCrypt password hashing, and role-based access.
- **IDOR / BOLA Prevention**: Booking ownership validation strictly bound to authenticated JWT user credentials.
- **Strict CORS Protection**: Whitelisted origin policies (`http://localhost:3000`, `http://localhost:8080`) protecting sensitive credentials.

---

## 🏗️ Architecture

```
Cineza/
├── backend/                  # Spring Boot 3 + Java 17 Backend
│   ├── src/main/java/com/cineza/
│   │   ├── config/           # Security, Redis, CORS, DataInitializer
│   │   ├── controller/       # Auth, Movie, City, Theatre, Show, Booking, SeatLock
│   │   ├── dto/              # Request / Response payloads & validation
│   │   ├── model/            # JPA Entities: City, Theatre, Screen, Seat, Movie, Show, Booking
│   │   ├── repository/       # Spring Data JPA repositories
│   │   ├── security/         # JwtTokenProvider, JwtAuthenticationFilter
│   │   └── service/          # Business logic, Redis SeatLockService, BookingService
│   └── pom.xml
├── frontend/                 # Flutter 3 Client (Web, Desktop, Mobile)
│   ├── lib/
│   │   ├── models/           # Data models (City, Movie, Show, Seat, Booking)
│   │   ├── screens/          # HomeScreen, MovieDetailsScreen, SeatSelectionScreen
│   │   ├── services/         # ApiService (REST client)
│   │   ├── theme/            # Obsidian & Gold cinematic dark design system
│   │   └── widgets/          # CurvedScreenPainter, SeatWidget, CountdownTimer, TicketDialog
│   └── pubspec.yaml
└── docker-compose.yml        # Orchestration for MySQL 8 & Redis 7
```

---

## 🚀 Quick Start

### 1. Start Infrastructure (Docker)
```bash
docker-compose up -d
```
Starts:
- **MySQL 8.0**: Port `3307` (`cineza_db`)
- **Redis 7 (Alpine)**: Port `6379`

### 2. Run Backend (Spring Boot)
```bash
cd backend
mvn spring-boot:run
```
Backend runs on `http://localhost:8080`.
The application automatically seeds cities, theatres, auditoriums, tiered seats, movies, and sample showtimes on first boot.

### 3. Run Frontend (Flutter Web)
```bash
cd frontend
flutter pub get
flutter run -d chrome --web-port 3000
```
Web app runs on `http://localhost:3000`.

---

## 🔒 Security Hardening

- **Stateless JWT (JJWT 0.12.5)**: Bearer tokens issued via `/api/v1/auth/login`.
- **Protected Endpoints**: Checkout confirmations and user booking queries require a valid JWT token.
- **BOLA / IDOR Defense**: User bookings endpoint `/api/v1/bookings/user` resolves email strictly from the validated JWT principal (`principal.getName()`).
- **Input Validation**: All DTOs validated using Jakarta Bean Validation (`@NotNull`, `@NotEmpty`, `@Email`, etc.).
- **Parameterized SQL**: All dynamic lookups use Spring Data JPA parameterized queries.

---

## 📄 License
MIT
