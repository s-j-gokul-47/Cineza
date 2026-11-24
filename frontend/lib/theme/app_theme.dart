import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class ThemeController {
  static final ValueNotifier<ThemeMode> themeMode = ValueNotifier(ThemeMode.dark);

  static void toggleTheme() {
    themeMode.value =
        themeMode.value == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
  }

  static void setTheme(ThemeMode mode) {
    themeMode.value = mode;
  }

  static bool isDark(BuildContext context) {
    if (themeMode.value == ThemeMode.system) {
      return MediaQuery.platformBrightnessOf(context) == Brightness.dark;
    }
    return themeMode.value == ThemeMode.dark;
  }
}

/// Google Stitch Official Design System Tokens for Cineza Cinema Application
/// Implements Modern Cinematic Dark-Mode and Crisp Luminous Bright-Mode
class AppTheme {
  // ---------------------------------------------------------------------------
  // GOOGLE STITCH CINEMATIC DARK PALETTE (Atmospheric Obsidian & Ruby)
  // ---------------------------------------------------------------------------
  static const Color darkBackground = Color(0xFF0F1117); // Base Ground Canvas
  static const Color darkSurfaceLowest = Color(0xFF0C0E14); // Surface Container Lowest
  static const Color darkSurface = Color(0xFF141722); // Surface Tier 1 (Panels)
  static const Color darkSurfaceContainer = Color(0xFF1E1F26); // Surface Tier 2 (Cards, Modals)
  static const Color darkSurfaceLight = Color(0xFF1E1F26); // Alias for compatibility
  static const Color darkSurfaceBorder = Color(0xFF282A30); // Surface Tier 3 (Borders, Hover)
  static const Color darkSurfaceHighest = Color(0xFF33343B); // Highest Surface / Chips
  static const Color darkSurfaceBright = Color(0xFF373940); // Brightest Dark Surface

  // Stitch Dark Accents (Google Stitch Cobalt Blue Cinema Palette)
  static const Color primary = Color(0xFF18A0FB); // Electric Action Cobalt Blue
  static const Color darkPrimary = Color(0xFF18A0FB);
  static const Color darkPrimaryContainer = Color(0xFF004A79); // Stitch Blue Primary Container
  static const Color darkPrimaryGlow = Color(0xFF60A5FA); // Primary Fixed / Glow
  static const Color primaryGlow = Color(0xFF60A5FA); // Compatible alias
  static const Color darkOnPrimary = Colors.white;
  static const Color accent = Color(0xFF38BDF8); // Electric Cinema Cyan
  static const Color cyanAccent = Color(0xFF00F2FF);
  static const Color goldAccent = Color(0xFFFFB800); // Golden Marquee / VIP / Ratings
  static const Color secondary = Color(0xFFFFDB9D); // Stitch Warm Secondary
  static const Color secondaryContainer = Color(0xFFFEB700);
  static const Color danger = Color(0xFFEF4444);
  static const Color warning = Color(0xFFF59E0B);
  static const Color success = Color(0xFF10B981);

  // Stitch Dark Text
  static const Color darkTextPrimary = Color(0xFFFFFFFF); // High Emphasis
  static const Color darkTextSecondary = Color(0xFFE2E2EB); // Medium-High Emphasis
  static const Color darkTextMuted = Color(0xFF94A3B8); // Subtitles / Outline
  static const Color darkOutline = Color(0xFF738A9C); // Subtle Blue-Slate Outline
  static const Color darkOutlineVariant = Color(0xFF3E4E5B);

  // ---------------------------------------------------------------------------
  // GOOGLE STITCH CRISP BRIGHT PALETTE (Luminous Snow & Vibrant Action Blue)
  // ---------------------------------------------------------------------------
  static const Color lightBackground = Color(0xFFF8FAFC); // Luminous Pearl Canvas
  static const Color lightSurfaceLowest = Color(0xFFFFFFFF);
  static const Color lightSurface = Color(0xFFFFFFFF); // Pure White Surface
  static const Color lightSurfaceContainer = Color(0xFFF1F5F9); // Crisp Card Container
  static const Color lightSurfaceLight = Color(0xFFF1F5F9); // Alias
  static const Color lightSurfaceBorder = Color(0xFFE2E8F0); // Fine Hairline Border
  static const Color lightSurfaceHighest = Color(0xFFCBD5E1);
  static const Color lightSurfaceBright = Color(0xFFFFFFFF);

  // Stitch Light Accents
  static const Color lightPrimary = Color(0xFF0062FF); // Vibrant Royal Cinema Blue
  static const Color lightPrimaryContainer = Color(0xFFDBEAFE); // Soft Ice Blue Container
  static const Color lightPrimaryGlow = Color(0xFF3B82F6);
  static const Color lightOnPrimary = Colors.white;
  static const Color lightAccent = Color(0xFF0284C7); // Vivid Sky Blue
  static const Color lightGoldAccent = Color(0xFFD97706); // Amber Gold Marquee

  // Stitch Light Text
  static const Color lightTextPrimary = Color(0xFF0F172A); // Deep Midnight Obsidian
  static const Color lightTextSecondary = Color(0xFF334155); // Slate Charcoal
  static const Color lightTextMuted = Color(0xFF64748B); // Soft Slate Gray
  static const Color lightOutline = Color(0xFF94A3B8);
  static const Color lightOutlineVariant = Color(0xFFCBD5E1);

  // ---------------------------------------------------------------------------
  // SEAT STATUS COLORS (Matching Stitch Seating Map Matrix)
  // ---------------------------------------------------------------------------
  static const Color darkSeatAvailable = Color(0xFF1E2336);
  static const Color darkSeatAvailableBorder = Color(0xFF4B5563);
  static const Color lightSeatAvailable = Color(0xFFF1F5F9);
  static const Color lightSeatAvailableBorder = Color(0xFFCBD5E1);

  static const Color seatSelected = Color(0xFF18A0FB); // Vibrant Blue Fill (Dark)
  static const Color lightSeatSelected = Color(0xFF0062FF); // Deep Royal Blue Fill (Light)
  static const Color seatLocked = Color(0xFFF97316); 
  static const Color darkSeatBooked = Color(0xFF12151E);
  static const Color lightSeatBooked = Color(0xFFE2E8F0);
  static const Color seatVip = Color(0xFFFFB800);

  // ---------------------------------------------------------------------------
  // DYNAMIC GETTERS BASED ON THEME BRIGHTNESS
  // ---------------------------------------------------------------------------
  static Color getBackground(bool isDark) => isDark ? darkBackground : lightBackground;
  static Color getSurfaceLowest(bool isDark) => isDark ? darkSurfaceLowest : lightSurfaceLowest;
  static Color getSurface(bool isDark) => isDark ? darkSurface : lightSurface;
  static Color getSurfaceLight(bool isDark) => isDark ? darkSurfaceLight : lightSurfaceLight;
  static Color getSurfaceContainer(bool isDark) => isDark ? darkSurfaceContainer : lightSurfaceContainer;
  static Color getSurfaceBorder(bool isDark) => isDark ? darkSurfaceBorder : lightSurfaceBorder;
  static Color getSurfaceHighest(bool isDark) => isDark ? darkSurfaceHighest : lightSurfaceHighest;
  static Color getTextPrimary(bool isDark) => isDark ? darkTextPrimary : lightTextPrimary;
  static Color getTextSecondary(bool isDark) => isDark ? darkTextSecondary : lightTextSecondary;
  static Color getTextMuted(bool isDark) => isDark ? darkTextMuted : lightTextMuted;
  static Color getOutline(bool isDark) => isDark ? darkOutline : lightOutline;
  static Color getPrimary(bool isDark) => isDark ? primary : lightPrimary;
  static Color getPrimaryContainer(bool isDark) => isDark ? darkPrimaryContainer : lightPrimaryContainer;
  static Color getPrimaryGlow(bool isDark) => isDark ? darkPrimaryGlow : lightPrimaryGlow;
  static Color getAccent(bool isDark) => isDark ? accent : lightAccent;
  static Color getGoldAccent(bool isDark) => isDark ? goldAccent : lightGoldAccent;

  // Seat Getters
  static Color getSeatAvailable(bool isDark) => isDark ? darkSeatAvailable : lightSeatAvailable;
  static Color getSeatAvailableBorder(bool isDark) => isDark ? darkSeatAvailableBorder : lightSeatAvailableBorder;
  static Color getSeatSelected(bool isDark) => isDark ? seatSelected : lightSeatSelected;
  static Color getSeatBooked(bool isDark) => isDark ? darkSeatBooked : lightSeatBooked;

  // ---------------------------------------------------------------------------
  // CINEMATIC LUXURY GRADIENTS (Inspo MCP Media Archetypes)
  // ---------------------------------------------------------------------------
  static const LinearGradient cobaltActionGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF18A0FB), Color(0xFF0062FF)],
  );

  static const LinearGradient amberGoldGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFFFB800), Color(0xFFF59E0B)],
  );

  static const LinearGradient cyanNeonGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF38BDF8), Color(0xFF00F2FF)],
  );

  static const LinearGradient rubyPremiereGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFEF4444), Color(0xFF991B1B)],
  );

  static LinearGradient getMarqueeGradient(bool isDark) {
    return LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: isDark
          ? [
              Colors.transparent,
              const Color(0xFF0F1117).withValues(alpha: 0.55),
              const Color(0xFF0F1117).withValues(alpha: 0.95),
            ]
          : [
              Colors.transparent,
              const Color(0xFFF8FAFC).withValues(alpha: 0.60),
              const Color(0xFFF8FAFC).withValues(alpha: 0.96),
            ],
      stops: const [0.0, 0.40, 1.0],
    );
  }

  // ---------------------------------------------------------------------------
  // GOOGLE STITCH TYPOGRAPHY (Argent CF for Headings & Proxima Nova for Body / UI)
  // ---------------------------------------------------------------------------
  static TextStyle argentHeading({
    double? fontSize,
    FontWeight? fontWeight,
    Color? color,
    double? letterSpacing,
    double? height,
    FontStyle? fontStyle,
    TextDecoration? decoration,
  }) {
    return TextStyle(
      fontFamily: 'Argent CF',
      fontFamilyFallback: const [
        'Playfair Display',
        'Cinzel',
        'Source Serif 4',
        'serif',
      ],
      fontSize: fontSize,
      fontWeight: fontWeight ?? FontWeight.w700,
      fontStyle: fontStyle,
      color: color,
      letterSpacing: letterSpacing,
      height: height,
      decoration: decoration,
    );
  }

  static TextStyle proximaBody({
    double? fontSize,
    FontWeight? fontWeight,
    Color? color,
    double? letterSpacing,
    double? height,
    FontStyle? fontStyle,
    TextDecoration? decoration,
  }) {
    return TextStyle(
      fontFamily: 'Proxima Nova',
      fontFamilyFallback: const [
        'Montserrat',
        'Inter',
        'Plus Jakarta Sans',
        'sans-serif',
      ],
      fontSize: fontSize,
      fontWeight: fontWeight ?? FontWeight.w400,
      fontStyle: fontStyle,
      color: color,
      letterSpacing: letterSpacing,
      height: height,
      decoration: decoration,
    );
  }

  // Backward compatibility alias
  static TextStyle greycliffHeading({
    double? fontSize,
    FontWeight? fontWeight,
    Color? color,
    double? letterSpacing,
    double? height,
    TextDecoration? decoration,
  }) => argentHeading(
    fontSize: fontSize,
    fontWeight: fontWeight,
    color: color,
    letterSpacing: letterSpacing,
    height: height,
    decoration: decoration,
  );

  // ---------------------------------------------------------------------------
  // THEME DATA DEFINITIONS (Google Stitch Argent CF & Proxima Nova)
  // ---------------------------------------------------------------------------
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: darkBackground,
      primaryColor: primary,
      colorScheme: const ColorScheme.dark(
        primary: primary,
        primaryContainer: darkPrimaryContainer,
        secondary: goldAccent,
        secondaryContainer: secondaryContainer,
        surface: darkSurface,
        error: danger,
        onPrimary: Colors.white,
        onSurface: darkTextPrimary,
        outline: darkSurfaceBorder,
      ),
      fontFamily: 'Proxima Nova',
      textTheme: const TextTheme().apply(
        fontFamily: 'Proxima Nova',
        bodyColor: darkTextPrimary,
        displayColor: darkTextPrimary,
      ),
      cardTheme: CardThemeData(
        color: darkSurfaceContainer,
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
        titleTextStyle: argentHeading(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: darkTextPrimary,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          elevation: 4,
          shadowColor: primary.withValues(alpha: 0.4),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: proximaBody(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.3,
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
          textStyle: proximaBody(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: darkSurfaceLowest,
        hintStyle: const TextStyle(color: darkTextMuted, fontSize: 14),
        prefixIconColor: darkTextMuted,
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

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: lightBackground,
      primaryColor: lightPrimary,
      colorScheme: const ColorScheme.light(
        primary: lightPrimary,
        primaryContainer: lightPrimaryContainer,
        secondary: lightGoldAccent,
        secondaryContainer: Color(0xFFFEF3C7),
        surface: lightSurface,
        error: danger,
        onPrimary: Colors.white,
        onSurface: lightTextPrimary,
        outline: lightSurfaceBorder,
      ),
      fontFamily: 'Proxima Nova',
      textTheme: const TextTheme().apply(
        fontFamily: 'Proxima Nova',
        bodyColor: lightTextPrimary,
        displayColor: lightTextPrimary,
      ),
      cardTheme: CardThemeData(
        color: lightSurface,
        elevation: 2,
        shadowColor: Colors.black.withValues(alpha: 0.05),
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
        titleTextStyle: argentHeading(
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
          shadowColor: lightPrimary.withValues(alpha: 0.3),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: proximaBody(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.3,
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
          textStyle: proximaBody(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: lightSurfaceContainer,
        hintStyle: const TextStyle(color: lightTextMuted, fontSize: 14),
        prefixIconColor: lightTextMuted,
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

/// A sleek, animated theme toggle button matching the Google Stitch aesthetic
class CinezaThemeToggle extends StatelessWidget {
  final bool compact;
  const CinezaThemeToggle({super.key, this.compact = false});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: ThemeController.themeMode,
      builder: (context, currentMode, _) {
        final isDark = currentMode == ThemeMode.dark;
        final activeColor = isDark ? AppTheme.goldAccent : AppTheme.lightPrimary;

        if (compact) {
          return IconButton(
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            visualDensity: VisualDensity.compact,
            tooltip: isDark ? 'Switch to Bright Mode' : 'Switch to Dark Mode',
            onPressed: ThemeController.toggleTheme,
            icon: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              transitionBuilder: (child, anim) => RotationTransition(
                turns: anim,
                child: FadeTransition(opacity: anim, child: child),
              ),
              child: Icon(
                isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                key: ValueKey(isDark),
                color: activeColor,
                size: 20,
              ),
            ),
          );
        }

        return InkWell(
          onTap: ThemeController.toggleTheme,
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: isDark ? AppTheme.darkSurfaceBorder : AppTheme.lightSurfaceContainer,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isDark ? AppTheme.darkSurfaceHighest : AppTheme.lightSurfaceBorder,
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: isDark ? Colors.black26 : Colors.black.withValues(alpha: 0.04),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  transitionBuilder: (child, anim) => RotationTransition(
                    turns: anim,
                    child: FadeTransition(opacity: anim, child: child),
                  ),
                  child: Icon(
                    isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                    key: ValueKey(isDark),
                    size: 16,
                    color: activeColor,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  isDark ? 'Bright Mode' : 'Dark Mode',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

