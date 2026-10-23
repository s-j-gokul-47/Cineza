import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class ThemeController {
  static final ValueNotifier<ThemeMode> themeMode = ValueNotifier(ThemeMode.dark);

  static void toggleTheme() {
    themeMode.value =
        themeMode.value == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
  }

  static bool isDark(BuildContext context) {
    if (themeMode.value == ThemeMode.system) {
      return MediaQuery.platformBrightnessOf(context) == Brightness.dark;
    }
    return themeMode.value == ThemeMode.dark;
  }
}

class AppTheme {
  // Cinematic Dark Palette
  static const Color darkBackground = Color(0xFF0C0D14);
  static const Color darkSurface = Color(0xFF141622);
  static const Color darkSurfaceLight = Color(0xFF1E2132);
  static const Color darkSurfaceBorder = Color(0xFF2B2E42);

  // Bright / Light Mode Palette
  static const Color lightBackground = Color(0xFFF8FAFC);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightSurfaceLight = Color(0xFFF1F5F9);
  static const Color lightSurfaceBorder = Color(0xFFE2E8F0);

  // Accents
  static const Color primary = Color(0xFFFFB800); // Amber Gold
  static const Color lightPrimary = Color(0xFFD97706); // Rich Amber for bright mode
  static const Color primaryGlow = Color(0xFFFFD56B);
  static const Color accent = Color(0xFF8B5CF6); // Neon Violet
  static const Color cyanAccent = Color(0xFF06B6D4); // Cyber Cyan
  static const Color danger = Color(0xFFEF4444); // Locked / Sold out Red
  static const Color warning = Color(0xFFF59E0B); // Reserved / Locking Orange
  static const Color success = Color(0xFF10B981); // Available Green

  // Dark Text Colors
  static const Color darkTextPrimary = Color(0xFFF8FAFC);
  static const Color darkTextSecondary = Color(0xFF94A3B8);
  static const Color darkTextMuted = Color(0xFF64748B);

  // Light Text Colors
  static const Color lightTextPrimary = Color(0xFF0F172A);
  static const Color lightTextSecondary = Color(0xFF475569);
  static const Color lightTextMuted = Color(0xFF94A3B8);

  // Seat Status Colors
  static const Color darkSeatAvailable = Color(0xFF282C3F);
  static const Color darkSeatAvailableBorder = Color(0xFF404664);
  static const Color lightSeatAvailable = Color(0xFFE2E8F0);
  static const Color lightSeatAvailableBorder = Color(0xFFCBD5E1);

  static const Color seatSelected = Color(0xFFFFB800);
  static const Color seatLocked = Color(0xFFF97316); // Locked by another in Redis
  static const Color darkSeatBooked = Color(0xFF1C1E2A); // Sold / Booked
  static const Color lightSeatBooked = Color(0xFFE2E8F0);

  // Dynamic getters based on brightness
  static Color getBackground(bool isDark) => isDark ? darkBackground : lightBackground;
  static Color getSurface(bool isDark) => isDark ? darkSurface : lightSurface;
  static Color getSurfaceLight(bool isDark) => isDark ? darkSurfaceLight : lightSurfaceLight;
  static Color getSurfaceBorder(bool isDark) => isDark ? darkSurfaceBorder : lightSurfaceBorder;
  static Color getTextPrimary(bool isDark) => isDark ? darkTextPrimary : lightTextPrimary;
  static Color getTextSecondary(bool isDark) => isDark ? darkTextSecondary : lightTextSecondary;
  static Color getTextMuted(bool isDark) => isDark ? darkTextMuted : lightTextMuted;
  static Color getPrimary(bool isDark) => isDark ? primary : lightPrimary;

  // --- DARK THEME ---
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: darkBackground,
      primaryColor: primary,
      colorScheme: const ColorScheme.dark(
        primary: primary,
        secondary: accent,
        surface: darkSurface,
        error: danger,
      ),
      fontFamily: GoogleFonts.outfit().fontFamily,
      textTheme: const TextTheme().apply(
        bodyColor: darkTextPrimary,
        displayColor: darkTextPrimary,
      ),
      cardTheme: CardThemeData(
        color: darkSurface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: darkSurfaceBorder, width: 1),
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: darkBackground,
        elevation: 0,
        centerTitle: false,
        iconTheme: const IconThemeData(color: darkTextPrimary),
        titleTextStyle: GoogleFonts.outfit(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: darkTextPrimary,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.black,
          elevation: 4,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: GoogleFonts.outfit(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: darkTextPrimary,
          side: const BorderSide(color: darkSurfaceBorder),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: darkSurfaceLight,
        hintStyle: const TextStyle(color: darkTextMuted),
        prefixIconColor: darkTextSecondary,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: darkSurfaceBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: darkSurfaceBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: primary, width: 1.5),
        ),
      ),
    );
  }

  // --- BRIGHT / LIGHT THEME ---
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: lightBackground,
      primaryColor: lightPrimary,
      colorScheme: const ColorScheme.light(
        primary: lightPrimary,
        secondary: accent,
        surface: lightSurface,
        error: danger,
      ),
      fontFamily: GoogleFonts.outfit().fontFamily,
      textTheme: const TextTheme().apply(
        bodyColor: lightTextPrimary,
        displayColor: lightTextPrimary,
      ),
      cardTheme: CardThemeData(
        color: lightSurface,
        elevation: 2,
        shadowColor: Colors.black.withValues(alpha: 0.06),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: lightSurfaceBorder, width: 1),
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: lightSurface,
        elevation: 0.5,
        centerTitle: false,
        iconTheme: const IconThemeData(color: lightTextPrimary),
        titleTextStyle: GoogleFonts.outfit(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: lightTextPrimary,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: lightPrimary,
          foregroundColor: Colors.white,
          elevation: 2,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: GoogleFonts.outfit(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: lightTextPrimary,
          side: const BorderSide(color: lightSurfaceBorder),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: lightSurfaceLight,
        hintStyle: const TextStyle(color: lightTextMuted),
        prefixIconColor: lightTextSecondary,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: lightSurfaceBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: lightSurfaceBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: lightPrimary, width: 1.5),
        ),
      ),
    );
  }
}
