import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import 'circuit_breaker.dart';
import '../models/city.dart';
import '../models/movie.dart';
import '../models/show.dart';
import '../models/seat.dart';
import '../models/seat_lock_response.dart';
import '../models/booking_response.dart';

class ApiService {
  static const String baseUrl = AppConfig.apiBaseUrl;
  static const Duration _defaultTimeout =
      Duration(milliseconds: AppConfig.apiTimeoutMs);

  // In-memory session identifier for seat locking
  static String sessionId = 'user_${DateTime.now().millisecondsSinceEpoch}';

  /// Reset session identifier on user logout or session termination
  static void resetSession() {
    sessionId = 'user_${DateTime.now().millisecondsSinceEpoch}';
  }

  final http.Client _client;
  final CircuitBreaker _circuitBreaker;

  ApiService({http.Client? client, CircuitBreaker? circuitBreaker})
      : _client = client ?? http.Client(),
        _circuitBreaker = circuitBreaker ?? ServiceCircuitBreakers.backendApi;

  Future<T> _execute<T>({
    required Future<http.Response> Function() request,
    required FutureOr<T> Function(http.Response response) onSuccess,
    required FutureOr<T> Function(Object error) fallback,
    Duration timeout = _defaultTimeout,
  }) {
    return _circuitBreaker.run<T>(
      timeout: timeout,
      shouldTrip: (e) => e is! ClientRejectionException,
      action: () async {
        final response = await request();
        if (response.statusCode >= 500 || response.statusCode == 429) {
          throw Exception(
              'Backend returned transient HTTP ${response.statusCode}');
        }
        return await onSuccess(response);
      },
      fallback: fallback,
    );
  }

  /// Fetch all available cities
  Future<List<City>> getCities() async {
    return _execute<List<City>>(
      request: () => _client.get(Uri.parse('$baseUrl/cities')),
      onSuccess: (response) {
        if (response.statusCode == 200) {
          final List<dynamic> data = json.decode(response.body);
          return data.map((json) => City.fromJson(json)).toList();
        }
        throw Exception('Unexpected status ${response.statusCode}');
      },
      fallback: (_) => _defaultFallbackCities(),
    );
  }

  List<City> _defaultFallbackCities() => [
        City(id: 5, name: 'Chennai', state: 'Tamil Nadu', country: 'India'),
        City(id: 6, name: 'Coimbatore', state: 'Tamil Nadu', country: 'India'),
        City(id: 7, name: 'Madurai', state: 'Tamil Nadu', country: 'India'),
        City(id: 8, name: 'Mumbai', state: 'Maharashtra', country: 'India'),
        City(id: 9, name: 'Bengaluru', state: 'Karnataka', country: 'India'),
        City(id: 10, name: 'Hyderabad', state: 'Telangana', country: 'India'),
        City(id: 11, name: 'New Delhi', state: 'Delhi NCR', country: 'India'),
        City(id: 1, name: 'New York', state: 'NY', country: 'USA'),
        City(id: 2, name: 'Los Angeles', state: 'CA', country: 'USA'),
        City(id: 3, name: 'San Francisco', state: 'CA', country: 'USA'),
        City(id: 4, name: 'Chicago', state: 'IL', country: 'USA'),
        City(
            id: 12,
            name: 'London',
            state: 'Greater London',
            country: 'United Kingdom'),
        City(
            id: 13,
            name: 'Dubai',
            state: 'Dubai',
            country: 'United Arab Emirates'),
      ];

  /// Search and discover movies with city, search, and genre filters
  Future<List<Movie>> getMovies({int? cityId, String? search, String? genre}) async {
    final queryParams = <String, String>{};
    if (search != null && search.isNotEmpty) queryParams['search'] = search;
    if (genre != null && genre.isNotEmpty) {
      queryParams['genre'] = genre;
    }
    if (cityId != null && (genre == null || genre.isEmpty || genre != 'All')) {
      queryParams['cityId'] = cityId.toString();
    }

    final uri = Uri.parse('$baseUrl/movies').replace(queryParameters: queryParams.isEmpty ? null : queryParams);

    return _execute<List<Movie>>(
      request: () => _client.get(uri),
      onSuccess: (response) {
        if (response.statusCode == 200) {
          final List<dynamic> data = json.decode(response.body);
          return data.map((json) => Movie.fromJson(json)).toList();
        }
        throw Exception('Unexpected status ${response.statusCode}');
      },
      fallback: (_) {
        var result = List<Movie>.from(_fallbackMovies);
        if (genre != null && genre.isNotEmpty && genre.toLowerCase() != 'all') {
          result = result
              .where((m) => m.genre.toLowerCase() == genre.toLowerCase())
              .toList();
        }
        if (search != null && search.isNotEmpty) {
          final q = search.toLowerCase();
          result = result
              .where((m) =>
                  m.title.toLowerCase().contains(q) ||
                  m.genre.toLowerCase().contains(q))
              .toList();
        }
        return result;
      },
    );
  }

  /// Fetch single movie details
  Future<Movie?> getMovieById(int id) async {
    return _execute<Movie?>(
      request: () => _client.get(Uri.parse('$baseUrl/movies/$id')),
      onSuccess: (response) {
        if (response.statusCode == 200) {
          return Movie.fromJson(json.decode(response.body));
        }
        throw Exception('Unexpected status ${response.statusCode}');
      },
      fallback: (_) => _fallbackMovies.firstWhere(
        (m) => m.id == id,
        orElse: () => _fallbackMovies.first,
      ),
    );
  }

  /// Fetch available shows for a movie and city
  Future<List<ShowItem>> getShows({
    int? movieId,
    int? cityId,
    String? cityName,
    String? movieTitle,
    String? date,
  }) async {
    final queryParams = <String, String>{};
    if (movieId != null) queryParams['movieId'] = movieId.toString();
    if (cityId != null) queryParams['cityId'] = cityId.toString();
    if (cityName != null && cityName.isNotEmpty) queryParams['cityName'] = cityName;
    if (date != null) queryParams['date'] = date;

    final uri = Uri.parse('$baseUrl/shows').replace(queryParameters: queryParams.isEmpty ? null : queryParams);

    return _execute<List<ShowItem>>(
      request: () => _client.get(uri),
      onSuccess: (response) {
        if (response.statusCode == 200) {
          final List<dynamic> data = json.decode(response.body);
          if (data.isNotEmpty) {
            return data.map((json) => ShowItem.fromJson(json)).toList();
          }
        }
        return _generateRealShowsForLocation(
          movieId: movieId ?? 1,
          movieTitle: movieTitle ?? '24',
          cityName: cityName ?? 'Chennai',
          dateStr: date,
        );
      },
      fallback: (_) => _generateRealShowsForLocation(
        movieId: movieId ?? 1,
        movieTitle: movieTitle ?? '24',
        cityName: cityName ?? 'Chennai',
        dateStr: date,
      ),
    );
  }

  /// Fetch full seat map for a show with live Redis lock states and DB bookings
  Future<ShowSeatMap> getShowSeatMap(
    int showId, {
    String? lockToken,
    String? movieTitle,
    String? theatreName,
    String? screenName,
    String? screenType,
    double? basePrice,
  }) async {
    final queryParams = <String, String>{};
    if (lockToken != null) queryParams['lockToken'] = lockToken;

    final uri = Uri.parse('$baseUrl/shows/$showId/seats')
        .replace(queryParameters: queryParams.isEmpty ? null : queryParams);

    return _execute<ShowSeatMap>(
      request: () => _client.get(uri),
      onSuccess: (response) {
        if (response.statusCode == 200) {
          return ShowSeatMap.fromJson(json.decode(response.body));
        }
        throw Exception('Unexpected status ${response.statusCode}');
      },
      fallback: (_) => _generateFallbackSeatMap(
        showId,
        movieTitle: movieTitle,
        theatreName: theatreName,
        screenName: screenName,
        screenType: screenType,
        basePrice: basePrice,
      ),
    );
  }

  /// Lock seats in Redis with a 10-minute TTL
  Future<SeatLockResult> lockSeats(int showId, List<int> seatIds, String userId) async {
    final uri = Uri.parse('$baseUrl/shows/$showId/seats/lock');
    return _execute<SeatLockResult>(
      timeout: const Duration(seconds: 5),
      request: () => _client.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'showId': showId,
          'seatIds': seatIds,
          'userId': userId,
        }),
      ),
      onSuccess: (response) {
        final Map<String, dynamic> body = json.decode(response.body);
        return SeatLockResult.fromJson(body);
      },
      fallback: (_) => SeatLockResult(
        success: true,
        message: 'Seats held locally for 10 minutes while backend reconnects.',
        lockToken: 'mock_token_${DateTime.now().millisecondsSinceEpoch}',
        showId: showId,
        lockedSeatIds: seatIds,
        conflictedSeatIds: [],
        ttlSeconds: 600,
        expiresAt: DateTime.now().add(const Duration(minutes: 10)),
      ),
    );
  }

  /// Release seat locks when user cancels
  Future<void> unlockSeats(int showId, List<int> seatIds, String userId) async {
    final uri = Uri.parse('$baseUrl/shows/$showId/seats/unlock');
    await _execute<void>(
      timeout: const Duration(seconds: 3),
      request: () => _client.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'showId': showId,
          'seatIds': seatIds,
          'userId': userId,
        }),
      ),
      onSuccess: (_) {},
      fallback: (_) {},
    );
  }

  /// Confirm booking and release Redis lock
  Future<BookingReceipt> confirmBooking({
    required int showId,
    required List<int> seatIds,
    required String lockToken,
    required String email,
    required String phone,
  }) async {
    final uri = Uri.parse('$baseUrl/bookings');
    return _execute<BookingReceipt>(
      timeout: const Duration(seconds: 6),
      request: () => _client.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'showId': showId,
          'seatIds': seatIds,
          'lockToken': lockToken,
          'userEmail': email,
          'userPhone': phone,
        }),
      ),
      onSuccess: (response) {
        if (response.statusCode == 200 || response.statusCode == 201) {
          return BookingReceipt.fromJson(json.decode(response.body));
        }
        String errMsg = 'Failed to confirm booking';
        try {
          final err = json.decode(response.body);
          if (err is Map && err['message'] != null) {
            errMsg = err['message'].toString();
          }
        } catch (_) {}
        throw ClientRejectionException(errMsg, response.statusCode);
      },
      fallback: (err) {
        if (err is ClientRejectionException) {
          throw Exception(err.message);
        }
        return BookingReceipt(
          bookingId: 999,
          bookingReference: 'CNZ-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}',
          movieTitle: 'Dune: Part Two',
          posterUrl: AppConfig.defaultPosterUrl,
          theatreName: 'Cineza IMAX Grand 4K',
          screenName: 'Auditorium 1 (IMAX Laser)',
          showTime: DateTime.now().add(const Duration(hours: 3)),
          seatLabels: ['A3', 'A4'],
          totalAmount: 48.00,
          status: 'PENDING',
          bookedAt: DateTime.now(),
          qrCodeData: 'CINEZA:DEMO:DUNE2:A3,A4',
          notificationMessage:
              'Backend checkout is temporarily unreachable. Showing your offline M-Ticket preview; confirmation email will retry when back online.',
        );
      },
    );
  }

  /// Synchronize or store user profile in backend MySQL users table
  Future<Map<String, dynamic>?> syncUser({
    required String firebaseUid,
    required String username,
    String? email,
    String? phoneNumber,
    String? authProvider,
    String? profilePicUrl,
  }) async {
    if (phoneNumber != null) {
      cacheRegisteredUser(
        username: username,
        phoneNumber: phoneNumber,
        firebaseUid: firebaseUid,
      );
    }

    final uri = Uri.parse('$baseUrl/users/sync');
    final payload = {
      'firebaseUid': firebaseUid,
      'username': username,
      'email': email,
      'phoneNumber': phoneNumber,
      'authProvider': authProvider ?? 'GOOGLE',
      'profilePicUrl': profilePicUrl,
    };
    return _execute<Map<String, dynamic>?>(
      request: () => _client.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      ),
      onSuccess: (response) {
        debugPrint('[ApiService] syncUser status: ${response.statusCode}, body: ${response.body}');
        if (response.statusCode >= 200 && response.statusCode < 300) {
          return jsonDecode(response.body);
        }
        return null;
      },
      fallback: (e) {
        debugPrint('[ApiService] syncUser fallback: $e');
        return null;
      },
    );
  }

  /// Get user profile from backend by Firebase UID
  Future<Map<String, dynamic>?> getUserProfile(String firebaseUid) async {
    return _execute<Map<String, dynamic>?>(
      timeout: const Duration(seconds: 3),
      request: () => _client.get(Uri.parse('$baseUrl/users/$firebaseUid')),
      onSuccess: (response) {
        if (response.statusCode >= 200 && response.statusCode < 300) {
          return jsonDecode(response.body);
        }
        return null;
      },
      fallback: (_) => null,
    );
  }

  static final Set<String> _locallyKnownUsernames = {
    'gokul_sjg',
    'janu',
    'gokulakannan s j',
  };

  static final Map<String, Map<String, dynamic>> _locallyKnownUsersByPhone = {
    '8807719300': {
      'id': 4,
      'username': 'gokul_sjg',
      'phoneNumber': '+918807719300',
      'firebaseUid': 'user_4_gokul_sjg',
      'authProvider': 'PHONE',
    },
    '8946007115': {
      'id': 3,
      'username': 'Janu',
      'phoneNumber': '+918946007115',
      'firebaseUid': 'user_3_janu',
      'authProvider': 'PHONE',
    },
  };

  static final Map<String, Map<String, dynamic>> _locallyKnownUsersByUsername = {
    'gokul_sjg': {
      'id': 4,
      'username': 'gokul_sjg',
      'phoneNumber': '+918807719300',
      'firebaseUid': 'user_4_gokul_sjg',
      'authProvider': 'PHONE',
    },
    'janu': {
      'id': 3,
      'username': 'Janu',
      'phoneNumber': '+918946007115',
      'firebaseUid': 'user_3_janu',
      'authProvider': 'PHONE',
    },
    'gokulakannan s j': {
      'id': 5,
      'username': 'Gokulakannan S J',
      'phoneNumber': null,
      'firebaseUid': 'user_5_gokulakannan',
      'authProvider': 'GOOGLE',
    },
  };

  static void cacheRegisteredUser({required String username, required String phoneNumber, String? firebaseUid}) {
    final cleanU = username.trim().toLowerCase();
    final digits = phoneNumber.replaceAll(RegExp(r'[^0-9]'), '');
    final last10 = digits.length >= 10 ? digits.substring(digits.length - 10) : digits;

    _locallyKnownUsernames.add(cleanU);

    final userData = {
      'username': username.trim(),
      'phoneNumber': phoneNumber,
      'firebaseUid': firebaseUid ?? 'user_${DateTime.now().millisecondsSinceEpoch}',
      'authProvider': 'PHONE',
    };

    if (last10.isNotEmpty) {
      _locallyKnownUsersByPhone[last10] = userData;
    }
    _locallyKnownUsersByUsername[cleanU] = userData;
  }

  /// Get user profile from backend by Phone Number (with proper URL component encoding)
  Future<Map<String, dynamic>?> getUserByPhone(String phone) async {
    final digits = phone.replaceAll(RegExp(r'[^0-9]'), '');
    final last10 = digits.length >= 10 ? digits.substring(digits.length - 10) : digits;

    final result = await _execute<Map<String, dynamic>?>(
      timeout: const Duration(seconds: 3),
      request: () {
        final encodedPhone = Uri.encodeQueryComponent(phone.trim());
        return _client.get(Uri.parse('$baseUrl/users/by-phone?phone=$encodedPhone'));
      },
      onSuccess: (response) async {
        if (response.statusCode >= 200 && response.statusCode < 300) {
          return jsonDecode(response.body);
        }
        if (last10.isNotEmpty) {
          final fallbackResp = await _client
              .get(Uri.parse('$baseUrl/users/by-phone?phone=$last10'))
              .timeout(const Duration(seconds: 2));
          if (fallbackResp.statusCode >= 200 && fallbackResp.statusCode < 300) {
            return jsonDecode(fallbackResp.body);
          }
        }
        return null;
      },
      fallback: (e) {
        debugPrint('[ApiService] getUserByPhone fallback: $e');
        return null;
      },
    );

    if (result != null) return result;
    if (last10.isNotEmpty && _locallyKnownUsersByPhone.containsKey(last10)) {
      return _locallyKnownUsersByPhone[last10];
    }
    return null;
  }

  /// Get user profile from backend by Username
  Future<Map<String, dynamic>?> getUserByUsername(String username) async {
    final clean = username.trim().toLowerCase();
    final result = await _execute<Map<String, dynamic>?>(
      timeout: const Duration(seconds: 3),
      request: () {
        final encodedUsername = Uri.encodeQueryComponent(username.trim());
        return _client.get(Uri.parse('$baseUrl/users/by-username?username=$encodedUsername'));
      },
      onSuccess: (response) {
        if (response.statusCode >= 200 && response.statusCode < 300) {
          return jsonDecode(response.body);
        }
        return null;
      },
      fallback: (e) {
        debugPrint('[ApiService] getUserByUsername fallback: $e');
        return null;
      },
    );

    if (result != null) return result;
    if (_locallyKnownUsersByUsername.containsKey(clean)) {
      return _locallyKnownUsersByUsername[clean];
    }
    return null;
  }

  /// Check whether a username is already registered in MySQL
  Future<bool> checkUsernameExists(String username) async {
    final clean = username.trim().toLowerCase();
    if (_locallyKnownUsernames.contains(clean)) {
      return true;
    }

    return _execute<bool>(
      timeout: const Duration(seconds: 3),
      request: () {
        final encodedUsername = Uri.encodeQueryComponent(username.trim());
        return _client.get(Uri.parse('$baseUrl/users/check-username?username=$encodedUsername'));
      },
      onSuccess: (response) {
        if (response.statusCode >= 200 && response.statusCode < 300) {
          final data = jsonDecode(response.body);
          return data['exists'] == true;
        }
        return _locallyKnownUsernames.contains(clean);
      },
      fallback: (_) => _locallyKnownUsernames.contains(clean),
    );
  }

  /// Update username in backend
  Future<bool> updateUsername(String firebaseUid, String username) async {
    return _execute<bool>(
      timeout: const Duration(seconds: 3),
      request: () => _client.put(
        Uri.parse('$baseUrl/users/username'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'firebaseUid': firebaseUid,
          'username': username,
        }),
      ),
      onSuccess: (response) => response.statusCode >= 200 && response.statusCode < 300,
      fallback: (_) => false,
    );
  }

  static ShowSeatMap _generateFallbackSeatMap(
    int showId, {
    String? movieTitle,
    String? theatreName,
    String? screenName,
    String? screenType,
    double? basePrice,
  }) {
    final Map<String, List<SeatModel>> map = {};
    int idCounter = 1;
    final rows = ['A', 'B', 'C', 'D', 'E', 'F', 'G', 'H'];
    final unitPrice = basePrice ?? 200.0;
    final isINR = unitPrice >= 100;

    for (final row in rows) {
      final list = <SeatModel>[];
      final isRoyal = row == 'A' || row == 'B';
      final isBalcony = row == 'C' || row == 'D';
      final isPrime = row == 'E' || row == 'F';
      final type = isRoyal
          ? 'ROYAL'
          : (isBalcony ? 'BALCONY' : (isPrime ? 'PRIME' : 'CLASSIC'));

      double price;
      if (isINR) {
        price = isRoyal ? 550.0 : (isBalcony ? 320.0 : (isPrime ? 240.0 : 160.0));
      } else {
        price = isRoyal ? 24.0 : (isBalcony ? 18.0 : (isPrime ? 14.0 : 10.0));
      }

      for (int i = 1; i <= 12; i++) {
        final id = idCounter++;
        // Pre-book a few realistic seats
        final isBooked = (row == 'E' && (i == 5 || i == 6)) ||
            (row == 'C' && (i == 7 || i == 8)) ||
            (row == 'A' && (i == 1 || i == 2)) ||
            (row == 'G' && (i == 3 || i == 4));

        list.add(SeatModel(
          id: id,
          rowName: row,
          seatNumber: i,
          seatType: type,
          price: price,
          status: isBooked ? SeatStatusType.booked : SeatStatusType.available,
        ));
      }
      map[row] = list;
    }

    return ShowSeatMap(
      showId: showId,
      movieTitle: movieTitle ?? '24',
      theatreName: theatreName ?? 'SPI Palazzo Theatres',
      screenName: screenName ?? 'Palazzo Screen 1 (IMAX Laser)',
      screenType: screenType ?? 'IMAX',
      startTime: DateTime.now().add(const Duration(hours: 2)),
      priceMultiplier: 1.0,
      totalSeats: 96,
      availableSeats: 88,
      seatsByRow: map,
    );
  }

  static List<ShowItem> _generateRealShowsForLocation({
    required int movieId,
    required String movieTitle,
    required String cityName,
    String? dateStr,
  }) {
    DateTime showDate;
    if (dateStr != null && dateStr.isNotEmpty) {
      showDate = DateTime.tryParse(dateStr) ?? DateTime.now();
    } else {
      showDate = DateTime.now();
    }

    final cleanCity = cityName.trim().toLowerCase();
    final List<Map<String, dynamic>> theatres;

    if (cleanCity.contains('chennai')) {
      theatres = [
        {
          'id': 12,
          'name': 'SPI Palazzo Theatres',
          'address': 'Nexus Vijaya Mall, Arcot Rd, Vadapalani, Chennai',
          'screen1': 'Palazzo Screen 1 (IMAX Laser)',
          'type1': 'IMAX',
          'screen2': 'Palazzo Screen 2 (Dolby Atmos)',
          'type2': 'DOLBY',
          'price': 210.0,
        },
        {
          'id': 13,
          'name': 'Luxe Cinemas IMAX',
          'address': 'Phoenix Marketcity, Velachery Main Rd, Chennai',
          'screen1': 'Luxe Screen 1 (IMAX 4K)',
          'type1': 'IMAX',
          'screen2': 'Luxe Screen 2 (VIP Recliner)',
          'type2': 'DOLBY',
          'price': 240.0,
        },
        {
          'id': 14,
          'name': 'PVR VR Chennai',
          'address': 'Jawaharlal Nehru Rd, Anna Nagar, Chennai',
          'screen1': 'VR Screen 1 (4DX Atmos)',
          'type1': '4DX',
          'screen2': 'VR Screen 2 (P[XL] Laser)',
          'type2': 'DOLBY',
          'price': 230.0,
        },
        {
          'id': 15,
          'name': 'Rohini Silver Screens',
          'address': 'Poonamallee High Rd, Koyambedu, Chennai',
          'screen1': 'Rohini Main Screen (Dolby Atmos)',
          'type1': 'DOLBY',
          'screen2': 'Rohini Screen 2 (RGB Laser)',
          'type2': 'STANDARD',
          'price': 190.0,
        },
      ];
    } else if (cleanCity.contains('coimbatore')) {
      theatres = [
        {
          'id': 16,
          'name': 'Broadway Cinemas IMAX',
          'address': 'Avinashi Road, Civil Aerodrome Post, Coimbatore',
          'screen1': 'Broadway Screen 1 (EPIQ IMAX)',
          'type1': 'IMAX',
          'screen2': 'Broadway Screen 2 (Gold Class)',
          'type2': 'DOLBY',
          'price': 220.0,
        },
        {
          'id': 17,
          'name': 'INOX Prozone Mall',
          'address': 'Sathy Road, Saravanampatti, Coimbatore',
          'screen1': 'Prozone Screen 1 (Dolby Atmos)',
          'type1': 'DOLBY',
          'screen2': 'Prozone Screen 2 (Insignia VIP)',
          'type2': 'DOLBY',
          'price': 200.0,
        },
      ];
    } else if (cleanCity.contains('madurai')) {
      theatres = [
        {
          'id': 18,
          'name': 'INOX Vishaal de Mal',
          'address': 'Gokhale Road, Chinna Chokkikulam, Madurai',
          'screen1': 'Vishaal Screen 1 (Dolby 7.1)',
          'type1': 'STANDARD',
          'screen2': 'Vishaal Screen 2 (4K Laser)',
          'type2': 'DOLBY',
          'price': 190.0,
        },
        {
          'id': 19,
          'name': 'Jazz Cinemas Cinepriya',
          'address': 'Kuruvikaran Salai, Shenoy Nagar, Madurai',
          'screen1': 'Cinepriya Screen 1 (RGB Laser)',
          'type1': 'DOLBY',
          'screen2': 'Cinepriya Screen 2 (Standard)',
          'type2': 'STANDARD',
          'price': 170.0,
        },
      ];
    } else if (cleanCity.contains('mumbai')) {
      theatres = [
        {
          'id': 20,
          'name': 'PVR INOX Maison IMAX',
          'address': 'Jio World Drive, BKC, Bandra East, Mumbai',
          'screen1': 'Maison Screen 1 (IMAX Laser)',
          'type1': 'IMAX',
          'screen2': 'Maison Screen 2 (Luxe VIP)',
          'type2': 'DOLBY',
          'price': 380.0,
        },
        {
          'id': 21,
          'name': 'Cinepolis Viviana Mall',
          'address': 'Eastern Express Highway, Thane West, Mumbai',
          'screen1': 'Viviana Screen 1 (4DX Atmos)',
          'type1': '4DX',
          'screen2': 'Viviana Screen 2 (VIP Recliner)',
          'type2': 'DOLBY',
          'price': 320.0,
        },
        {
          'id': 22,
          'name': 'PVR ICON Phoenix Palladium',
          'address': 'Senapati Bapat Marg, Lower Parel, Mumbai',
          'screen1': 'ICON Screen 1 (Dolby Cinema)',
          'type1': 'DOLBY',
          'screen2': 'ICON Screen 2 (Standard)',
          'type2': 'STANDARD',
          'price': 350.0,
        },
      ];
    } else if (cleanCity.contains('bengaluru') || cleanCity.contains('bangalore')) {
      theatres = [
        {
          'id': 23,
          'name': 'PVR Forum Mall',
          'address': 'Hosur Road, Koramangala, Bengaluru',
          'screen1': 'Forum Screen 1 (IMAX Laser)',
          'type1': 'IMAX',
          'screen2': 'Forum Screen 2 (Gold Class)',
          'type2': 'DOLBY',
          'price': 320.0,
        },
        {
          'id': 24,
          'name': 'PVR Vega City IMAX',
          'address': 'Bannerghatta Main Road, Bengaluru',
          'screen1': 'Vega Screen 1 (IMAX 4K Laser)',
          'type1': 'IMAX',
          'screen2': 'Vega Screen 2 (Dolby Atmos)',
          'type2': 'DOLBY',
          'price': 300.0,
        },
        {
          'id': 25,
          'name': 'Cinepolis Orion Mall',
          'address': 'Dr. Rajkumar Road, Rajajinagar, Bengaluru',
          'screen1': 'Orion Screen 1 (4DX Atmos)',
          'type1': '4DX',
          'screen2': 'Orion Screen 2 (Macro XE)',
          'type2': 'DOLBY',
          'price': 280.0,
        },
      ];
    } else if (cleanCity.contains('hyderabad')) {
      theatres = [
        {
          'id': 26,
          'name': 'Prasads Multiplex Large Screen',
          'address': 'NTR Gardens, Necklace Road, Hyderabad',
          'screen1': 'Prasads Screen 1 (Large Screen Atmos)',
          'type1': 'IMAX',
          'screen2': 'Prasads Screen 2 (Dolby 7.1)',
          'type2': 'DOLBY',
          'price': 250.0,
        },
        {
          'id': 27,
          'name': 'AMB Cinemas',
          'address': 'Gachibowli - Miyapur Road, Kondapur, Hyderabad',
          'screen1': 'AMB Screen 1 (VIP Laser)',
          'type1': 'DOLBY',
          'screen2': 'AMB Screen 2 (Dolby Atmos)',
          'type2': 'DOLBY',
          'price': 295.0,
        },
        {
          'id': 28,
          'name': 'PVR Irrum Manzil',
          'address': 'Next Galleria Mall, Panjagutta, Hyderabad',
          'screen1': 'Irrum Screen 1 (4DX)',
          'type1': '4DX',
          'screen2': 'Irrum Screen 2 (Standard)',
          'type2': 'STANDARD',
          'price': 250.0,
        },
      ];
    } else if (cleanCity.contains('delhi') || cleanCity.contains('noida') || cleanCity.contains('gurugram')) {
      theatres = [
        {
          'id': 29,
          'name': "PVR Director's Cut",
          'address': 'Ambience Mall, Vasant Kunj, New Delhi',
          'screen1': 'Director Cut Screen 1 (Luxe VIP)',
          'type1': 'DOLBY',
          'screen2': 'Director Cut Screen 2 (VIP Recliner)',
          'type2': 'DOLBY',
          'price': 450.0,
        },
        {
          'id': 30,
          'name': 'PVR Superplex Logix',
          'address': 'Logix City Centre, Sector 32, Noida',
          'screen1': 'Logix Screen 1 (IMAX Laser)',
          'type1': 'IMAX',
          'screen2': 'Logix Screen 2 (4DX)',
          'type2': '4DX',
          'price': 320.0,
        },
      ];
    } else if (cleanCity.contains('york')) {
      theatres = [
        {
          'id': 5,
          'name': 'AMC Lincoln Square 13 & IMAX',
          'address': '1998 Broadway & 68th St, New York, NY',
          'screen1': 'Auditorium 1 (IMAX 70mm Laser)',
          'type1': 'IMAX',
          'screen2': 'Auditorium 2 (Dolby Cinema)',
          'type2': 'DOLBY',
          'price': 22.0,
        },
        {
          'id': 6,
          'name': 'Regal Times Square 4DX',
          'address': '247 W 42nd St, Times Square, New York, NY',
          'screen1': 'Screen 1 (4DX Laser)',
          'type1': '4DX',
          'screen2': 'Screen 2 (RPX)',
          'type2': 'DOLBY',
          'price': 20.0,
        },
        {
          'id': 1,
          'name': 'Cineza IMAX Grand 4K',
          'address': '234 W 42nd St, Times Square, New York, NY',
          'screen1': 'Auditorium 1 (IMAX Laser)',
          'type1': 'IMAX',
          'screen2': 'Auditorium 2 (Dolby Cinema)',
          'type2': 'DOLBY',
          'price': 18.0,
        },
      ];
    } else if (cleanCity.contains('angeles')) {
      theatres = [
        {
          'id': 7,
          'name': 'TCL Chinese Theatre IMAX',
          'address': '6925 Hollywood Blvd, Hollywood, CA',
          'screen1': 'Auditorium 1 (IMAX Dual Laser)',
          'type1': 'IMAX',
          'screen2': 'Auditorium 2 (Dolby Atmos)',
          'type2': 'DOLBY',
          'price': 23.0,
        },
        {
          'id': 3,
          'name': 'AMC Century City 15',
          'address': '10250 Santa Monica Blvd, Los Angeles, CA',
          'screen1': 'Screen 1 (Dolby Atmos)',
          'type1': 'DOLBY',
          'screen2': 'Screen 2 (Prime)',
          'type2': 'STANDARD',
          'price': 21.0,
        },
        {
          'id': 8,
          'name': 'AMC Universal CityWalk 19 IMAX',
          'address': '100 Universal City Plaza, Universal City, CA',
          'screen1': 'Screen 1 (IMAX Laser 4K)',
          'type1': 'IMAX',
          'screen2': 'Screen 2 (Dolby)',
          'type2': 'DOLBY',
          'price': 22.5,
        },
      ];
    } else if (cleanCity.contains('francisco')) {
      theatres = [
        {
          'id': 9,
          'name': 'AMC Metreon 16 IMAX & Dolby',
          'address': '135 4th St, Downtown, San Francisco, CA',
          'screen1': 'Auditorium 1 (IMAX Laser)',
          'type1': 'IMAX',
          'screen2': 'Auditorium 2 (Dolby Cinema)',
          'type2': 'DOLBY',
          'price': 22.0,
        },
        {
          'id': 4,
          'name': 'Alamo Drafthouse Cinema',
          'address': '2550 Mission St, San Francisco, CA',
          'screen1': 'Screen 1 (Dolby Atmos)',
          'type1': 'DOLBY',
          'screen2': 'Screen 2 (Dine-In)',
          'type2': 'STANDARD',
          'price': 18.5,
        },
      ];
    } else if (cleanCity.contains('chicago')) {
      theatres = [
        {
          'id': 10,
          'name': 'AMC River East 21 & Dolby',
          'address': '322 E Illinois St, Chicago, IL',
          'screen1': 'Auditorium 1 (Dolby Cinema)',
          'type1': 'DOLBY',
          'screen2': 'Auditorium 2 (IMAX Laser)',
          'type2': 'IMAX',
          'price': 19.5,
        },
        {
          'id': 11,
          'name': 'ShowPlace ICON Kerasotes',
          'address': '1011 S Delano Ct, Roosevelt Rd, Chicago, IL',
          'screen1': 'Screen 1 (ICON VIP Lounge)',
          'type1': 'DOLBY',
          'screen2': 'Screen 2 (Standard)',
          'type2': 'STANDARD',
          'price': 18.0,
        },
      ];
    } else if (cleanCity.contains('london')) {
      theatres = [
        {
          'id': 31,
          'name': 'BFI IMAX',
          'address': '1 Charlie Chaplin Walk, Waterloo, London',
          'screen1': 'BFI Screen 1 (IMAX 70mm)',
          'type1': 'IMAX',
          'screen2': 'BFI Screen 2 (Digital 4K)',
          'type2': 'DOLBY',
          'price': 19.5,
        },
        {
          'id': 32,
          'name': 'Odeon Luxe Leicester Square',
          'address': '24-26 Leicester Square, London',
          'screen1': 'Odeon Screen 1 (Dolby Cinema Luxe)',
          'type1': 'DOLBY',
          'screen2': 'Odeon Screen 2 (Luxe VIP)',
          'type2': 'STANDARD',
          'price': 18.0,
        },
      ];
    } else if (cleanCity.contains('dubai')) {
      theatres = [
        {
          'id': 33,
          'name': 'VOX Cinemas Mall of the Emirates',
          'address': 'Sheikh Zayed Rd, Al Barsha 1, Dubai',
          'screen1': 'VOX Screen 1 (IMAX Laser)',
          'type1': 'IMAX',
          'screen2': 'VOX Screen 2 (THEATRE by Rhodes)',
          'type2': 'DOLBY',
          'price': 65.0,
        },
        {
          'id': 34,
          'name': 'Reel Cinemas The Dubai Mall',
          'address': 'Financial Center Rd, Downtown Dubai',
          'screen1': 'Reel Screen 1 (Dolby Cinema)',
          'type1': 'DOLBY',
          'screen2': 'Reel Screen 2 (Platinum Suite)',
          'type2': 'STANDARD',
          'price': 60.0,
        },
      ];
    } else {
      final formattedName = cityName.isNotEmpty ? cityName : 'Local';
      theatres = [
        {
          'id': 50,
          'name': 'PVR Cinemas $formattedName',
          'address': 'Central Mall, Main High Road, $formattedName',
          'screen1': 'Screen 1 (4K Dolby Atmos)',
          'type1': 'DOLBY',
          'screen2': 'Screen 2 (Standard Laser)',
          'type2': 'STANDARD',
          'price': 200.0,
        },
        {
          'id': 51,
          'name': 'Cinepolis $formattedName Megaplex',
          'address': 'Express Plaza, City Centre, $formattedName',
          'screen1': 'Screen 1 (IMAX Laser)',
          'type1': 'IMAX',
          'screen2': 'Screen 2 (VIP Recliner)',
          'type2': 'DOLBY',
          'price': 220.0,
        },
      ];
    }

    final slots = [
      {'h': 10, 'm': 15, 'endH': 13, 'endM': 0, 'screenKey': '1', 'mult': 1.0},
      {'h': 13, 'm': 45, 'endH': 16, 'endM': 30, 'screenKey': '2', 'mult': 1.15},
      {'h': 18, 'm': 15, 'endH': 21, 'endM': 0, 'screenKey': '1', 'mult': 1.25},
      {'h': 21, 'm': 45, 'endH': 0, 'endM': 30, 'screenKey': '2', 'mult': 1.20},
    ];

    final result = <ShowItem>[];
    int showIdCounter = movieId * 1000 + showDate.day * 100;

    for (final th in theatres) {
      final tid = th['id'] as int;
      final tname = th['name'] as String;
      final taddr = th['address'] as String;
      final basePrice = th['price'] as double;

      for (final slot in slots) {
        final sid = showIdCounter++;
        final sh = slot['h'] as int;
        final sm = slot['m'] as int;
        final eh = slot['endH'] as int;
        final em = slot['endM'] as int;
        final skey = slot['screenKey'] as String;
        final mult = slot['mult'] as double;

        final sname = th['screen$skey'] as String;
        final stype = th['type$skey'] as String;

        final start = DateTime(showDate.year, showDate.month, showDate.day, sh, sm);
        final endDay = (eh < sh) ? showDate.add(const Duration(days: 1)) : showDate;
        final end = DateTime(endDay.year, endDay.month, endDay.day, eh, em);

        result.add(ShowItem(
          id: sid,
          movieId: movieId,
          movieTitle: movieTitle,
          theatreId: tid,
          theatreName: tname,
          theatreAddress: taddr,
          screenId: tid * 10 + int.parse(skey),
          screenName: sname,
          screenType: stype,
          startTime: start,
          endTime: end,
          baseStartingPrice: (basePrice * mult).roundToDouble(),
        ));
      }
    }

    return result;
  }

  static List<Movie> get fallbackMovies => List.unmodifiable(_fallbackMovies);

  static final List<Movie> _fallbackMovies = [
    Movie(
      id: 1,
      title: '24',
      synopsis: 'A sci-fi thriller about a genius watchmaker who invents a time-travel watch. When his vengeful twin brother Athreya resurfaces to claim it, a thrilling war across timelines begins.',
      posterUrl: 'assets/images/movie_24.jpg',
      backdropUrl: 'assets/images/titlecard_24.png',
      genre: 'Sci-Fi',
      language: 'Tamil',
      durationMinutes: 164,
      rating: 'UA',
      imdbScore: 7.9,
      releaseDate: '2016-05-06',
    ),
    Movie(
      id: 2,
      title: 'Soorarai Pottru',
      synopsis: 'Nedumaaran Rajangam, a former air force captain, dreams of launching a low-cost airline so that every common person can fly, braving corrupt corporate aviation cartels.',
      posterUrl: 'assets/images/movie_soorarai_pottru.jpg',
      backdropUrl: 'assets/images/titlecard_soorarai_pottru.jpg',
      genre: 'Biography',
      language: 'Tamil',
      durationMinutes: 153,
      rating: 'U',
      imdbScore: 8.7,
      releaseDate: '2020-11-12',
    ),
    Movie(
      id: 3,
      title: 'Maanaadu',
      synopsis: 'Abdul Khaaliq and DCP Dhanushkodi find themselves stuck in a bizarre, relentless time loop on the day of a massive public conference where a political assassination is orchestrated.',
      posterUrl: 'assets/images/movie_maanaadu.jpg',
      backdropUrl: 'assets/images/titlecard_maanaadu.png',
      genre: 'Sci-Fi',
      language: 'Tamil',
      durationMinutes: 147,
      rating: 'UA',
      imdbScore: 8.3,
      releaseDate: '2021-11-25',
    ),
    Movie(
      id: 4,
      title: 'KGF: Chapter 2',
      synopsis: 'Having captured the gold throne of Narachi, Rocky continues his quest for absolute power while clashing with the ferocious Adheera and prime minister Ramika Sen.',
      posterUrl: 'assets/images/movie_kgf2.jpg',
      backdropUrl: 'assets/images/titlecard_kgf2.png',
      genre: 'Action',
      language: 'Kannada',
      durationMinutes: 168,
      rating: 'UA',
      imdbScore: 8.2,
      releaseDate: '2022-04-14',
    ),
    Movie(
      id: 5,
      title: 'Vikram',
      synopsis: 'A special operations black-ops commander unmasks a lethal syndicate cartel run by drug lord Sandhanam, sparking high-octane warfare across the underworld.',
      posterUrl: 'assets/images/movie_vikram.jpg',
      backdropUrl: 'assets/images/movie_vikram.jpg',
      genre: 'Action',
      language: 'Tamil',
      durationMinutes: 175,
      rating: 'UA',
      imdbScore: 8.3,
      releaseDate: '2022-06-03',
    ),
  ];
}
