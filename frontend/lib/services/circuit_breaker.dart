import 'dart:async';

/// Exception thrown when a circuit breaker is currently open and failing fast.
class CircuitOpenException implements Exception {
  final String serviceName;
  final Duration retryAfter;

  const CircuitOpenException(this.serviceName, this.retryAfter);

  @override
  String toString() =>
      'Service "$serviceName" is temporarily paused for ${retryAfter.inSeconds}s.';
}

/// Non-tripping exception for HTTP 4xx business rejections (valid response from a healthy service).
class ClientRejectionException implements Exception {
  final String message;
  final int statusCode;

  const ClientRejectionException(this.message, this.statusCode);

  @override
  String toString() => message;
}

enum CircuitState { closed, open, halfOpen }

/// Lightweight 3-state Circuit Breaker + Timeout wrapper for external APIs.
/// Uses wall-clock timestamps instead of background [Timer] instances so UI/widget tests stay deterministic.
class CircuitBreaker {
  final String serviceName;
  final int failureThreshold;
  final Duration openDuration;
  final Duration defaultTimeout;

  CircuitState _state = CircuitState.closed;
  int _consecutiveFailures = 0;
  DateTime? _openedUntil;
  bool _probeInFlight = false;

  CircuitBreaker(
    this.serviceName, {
    this.failureThreshold = 3,
    this.openDuration = const Duration(seconds: 30),
    this.defaultTimeout = const Duration(seconds: 5),
  });

  CircuitState get state {
    if (_state == CircuitState.open &&
        _openedUntil != null &&
        DateTime.now().isAfter(_openedUntil!)) {
      return CircuitState.halfOpen;
    }
    return _state;
  }

  /// Runs [action] bounded by [timeout] and protected by this circuit breaker.
  /// On timeout, error, or open circuit, executes [fallback] instead of hanging.
  Future<T> run<T>({
    required Future<T> Function() action,
    required FutureOr<T> Function(Object error) fallback,
    Duration? timeout,
    bool Function(Object error)? shouldTrip,
  }) async {
    final effectiveTimeout = timeout ?? defaultTimeout;
    if (!allowRequest()) {
      final remaining = remainingCooldown();
      return await fallback(CircuitOpenException(serviceName, remaining));
    }

    try {
      final result = await action().timeout(effectiveTimeout);
      recordSuccess();
      return result;
    } catch (error) {
      if (shouldTrip == null || shouldTrip(error)) {
        recordFailure();
      } else {
        recordSuccess();
      }
      return await fallback(error);
    } finally {
      _probeInFlight = false;
    }
  }

  bool allowRequest() {
    final current = state;
    if (current == CircuitState.closed) {
      return true;
    }
    if (current == CircuitState.open) {
      return false;
    }
    // halfOpen: allow single recovery probe
    if (_probeInFlight) {
      return false;
    }
    _state = CircuitState.halfOpen;
    _probeInFlight = true;
    return true;
  }

  Duration remainingCooldown() {
    if (_openedUntil == null) return Duration.zero;
    final diff = _openedUntil!.difference(DateTime.now());
    return diff.isNegative ? Duration.zero : diff;
  }

  void recordSuccess() {
    _consecutiveFailures = 0;
    _openedUntil = null;
    _state = CircuitState.closed;
  }

  void recordFailure() {
    _consecutiveFailures++;
    if (_state == CircuitState.halfOpen ||
        _consecutiveFailures >= failureThreshold) {
      _state = CircuitState.open;
      _openedUntil = DateTime.now().add(openDuration);
    }
  }

  void reset() {
    _state = CircuitState.closed;
    _consecutiveFailures = 0;
    _openedUntil = null;
    _probeInFlight = false;
  }
}

/// Shared named circuit breakers for all Cineza external dependencies.
class ServiceCircuitBreakers {
  ServiceCircuitBreakers._();

  static final CircuitBreaker backendApi = CircuitBreaker(
    'backend-api',
    failureThreshold: 3,
    openDuration: const Duration(seconds: 25),
    defaultTimeout: const Duration(seconds: 4),
  );

  static final CircuitBreaker authToken = CircuitBreaker(
    'auth-token',
    failureThreshold: 3,
    openDuration: const Duration(seconds: 30),
    defaultTimeout: const Duration(seconds: 6),
  );

  static final CircuitBreaker payments = CircuitBreaker(
    'payments',
    failureThreshold: 3,
    openDuration: const Duration(seconds: 30),
    defaultTimeout: const Duration(seconds: 5),
  );

  static final CircuitBreaker email = CircuitBreaker(
    'email',
    failureThreshold: 3,
    openDuration: const Duration(seconds: 30),
    defaultTimeout: const Duration(seconds: 4),
  );

  static void resetAll() {
    backendApi.reset();
    authToken.reset();
    payments.reset();
    email.reset();
  }
}
