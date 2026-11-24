import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:frontend/services/api_service.dart';
import 'package:frontend/services/circuit_breaker.dart';

void main() {
  setUp(() {
    ServiceCircuitBreakers.resetAll();
  });

  test('CircuitBreaker trips OPEN on timeout, skips calls, and recovers in halfOpen', () async {
    int attempts = 0;
    bool healthy = false;

    final breaker = CircuitBreaker(
      'test-gateway',
      failureThreshold: 2,
      openDuration: const Duration(milliseconds: 120),
      defaultTimeout: const Duration(milliseconds: 40),
    );

    Future<String> call() => breaker.run<String>(
          action: () async {
            attempts++;
            if (!healthy) {
              await Future<void>.delayed(const Duration(milliseconds: 200));
            }
            return 'ok';
          },
          fallback: (_) => 'fallback',
        );

    expect(await call(), 'fallback');
    expect(await call(), 'fallback');
    expect(breaker.state, CircuitState.open);

    // Must fail fast without calling action while circuit is open
    expect(await call(), 'fallback');
    expect(attempts, 2);

    // Wait for cooldown and recover
    await Future<void>.delayed(const Duration(milliseconds: 150));
    healthy = true;
    expect(await call(), 'ok');
    expect(breaker.state, CircuitState.closed);
  });

  test('ApiService trips circuit on hanging backend and returns friendly fallbacks fast', () async {
    int httpCalls = 0;
    final breaker = CircuitBreaker(
      'api-test',
      failureThreshold: 2,
      openDuration: const Duration(seconds: 10),
      defaultTimeout: const Duration(milliseconds: 40),
    );

    final hangingClient = MockClient((request) async {
      httpCalls++;
      await Future<void>.delayed(const Duration(milliseconds: 300));
      return http.Response('{}', 200);
    });

    final api = ApiService(client: hangingClient, circuitBreaker: breaker);

    final cities = await api.getCities();
    expect(cities, isNotEmpty);

    final movies = await api.getMovies();
    expect(movies, isNotEmpty);
    expect(breaker.state, CircuitState.open);

    // Next call must skip HTTP completely and return offline fallback shows/receipts
    final shows = await api.getShows(movieId: 1, cityName: 'Chennai');
    expect(shows, isNotEmpty);
    expect(httpCalls, 2);

    final receipt = await api.confirmBooking(
      showId: 1,
      seatIds: [1, 2],
      lockToken: 'tok',
      email: 'guest@cineza.com',
      phone: '9999999999',
    );
    expect(receipt.status, 'PENDING');
    expect(receipt.notificationMessage, isNotNull);
    expect(httpCalls, 2);
  });

  test('ApiService confirmBooking preserves 409 lock conflict without tripping circuit', () async {
    final breaker = CircuitBreaker('api-409-test', failureThreshold: 2);
    final conflictClient = MockClient((request) async {
      return http.Response(
        jsonEncode({'message': 'Seats already booked by another guest'}),
        409,
      );
    });

    final api = ApiService(client: conflictClient, circuitBreaker: breaker);

    await expectLater(
      api.confirmBooking(
        showId: 1,
        seatIds: [1],
        lockToken: 'expired',
        email: 'a@b.com',
        phone: '123',
      ),
      throwsA(predicate((e) => e.toString().contains('Seats already booked'))),
    );
    expect(breaker.state, CircuitState.closed);
  });
}
