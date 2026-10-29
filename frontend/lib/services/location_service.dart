import 'package:flutter/material.dart';
import '../models/city.dart';

/// Centralized Location Service
/// Manages the user's selected city across the entire Cineza application.
/// Initially null until the user explicitly chooses a location.
class LocationService {
  /// Global selected city notifier (initially null)
  static final ValueNotifier<City?> currentCity = ValueNotifier<City?>(null);

  /// Check if the user has chosen a location
  static bool get hasLocation => currentCity.value != null;

  /// Set the chosen city and notify all listeners
  static void setCity(City? city) {
    currentCity.value = city;
  }

  /// Clear the chosen city (reverts to 'LOCATION')
  static void clearCity() {
    currentCity.value = null;
  }
}
