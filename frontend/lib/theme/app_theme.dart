import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Cinematic Dark Palette
  static const Color background = Color(0xFF0C0D14);
  static const Color surface = Color(0xFF141622);
  static const Color surfaceLight = Color(0xFF1E2132);
  static const Color surfaceBorder = Color(0xFF2B2E42);

  // Accents
  static const Color primary = Color(0xFFFFB800); // Amber Gold
  static const Color primaryGlow = Color(0xFFFFD56B);
  static const Color accent = Color(0xFF8B5CF6); // Neon Violet
  static const Color cyanAccent = Color(0xFF06B6D4); // Cyber Cyan
  static const Color danger = Color(0xFFEF4444); // Locked / Sold out Red
  static const Color warning = Color(0xFFF59E0B); // Reserved / Locking Orange
  static const Color success = Color(0xFF10B981); // Available Green

  // Seat Status Colors
  static const Color seatAvailable = Color(0xFF282C3F);
  static const Color seatAvailableBorder = Color(0xFF404664);
  static const Color seatSelected = Color(0xFFFFB800);
  static const Color seatLocked = Color(0xFFF97316); // Locked by another in Redis
  static const Color seatBooked = Color(0xFF1C1E2A); // Sold / Booked

  // Text Colors
  static const Color textPrimary = Color(0xFFF8FAFC);
  static const Color textSecondary = Color(0xFF94A3B8);
  static const Color textMuted = Color(0xFF64748B);

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: background,
      primaryColor: primary,
      colorScheme: const ColorScheme.dark(
        primary: primary,
        secondary: accent,
        surface: surface,
        error: danger,
      ),
      fontFamily: GoogleFonts.outfit().fontFamily,
      textTheme: const TextTheme().apply(
        bodyColor: textPrimary,
        displayColor: textPrimary,
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: surfaceBorder, width: 1),
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: background.withOpacity(0.9),
        elevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.outfit(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: textPrimary,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.black,
          elevation: 4,
          shadowColor: primary.withOpacity(0.4),
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
          foregroundColor: textPrimary,
          side: const BorderSide(color: surfaceBorder),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceLight,
        hintStyle: const TextStyle(color: textMuted),
        prefixIconColor: textSecondary,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: surfaceBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: surfaceBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: primary, width: 1.5),
        ),
      ),
    );
  }
}
