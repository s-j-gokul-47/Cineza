import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'screens/movie_details_screen.dart';
import 'screens/seat_selection_screen.dart';
import 'screens/terms_policy_screen.dart';
import 'screens/location_selector_screen.dart';
import 'services/auth_service.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Suppress intrusive yellow-and-black hazard warning strips on web zoom
  // and show a friendly error screen instead of the default red crash screen
  ErrorWidget.builder = (FlutterErrorDetails details) {
    final msg = details.exceptionAsString();
    if (msg.contains('overflowed by')) {
      return const SizedBox.shrink();
    }
    // Friendly error screen for all other unhandled errors
    return Material(
      color: const Color(0xFF0A0E17),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.movie_filter_rounded, color: Color(0xFFE50914), size: 56),
              const SizedBox(height: 20),
              const Text(
                'Something went wrong',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Please go back to the home screen and try again.',
                style: TextStyle(color: Colors.white60, fontSize: 14),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  };

  // Suppress RenderFlex overflow console errors and debug overlay stripes globally
  FlutterError.onError = (FlutterErrorDetails details) {
    if (details.exceptionAsString().contains('overflowed by')) return;
    if (details.exceptionAsString().contains('LateInitializationError') ||
        details.exceptionAsString().contains('Null check operator')) {
      // Log the error but don't crash the app
      debugPrint('[Cineza] Caught widget error: ${details.exceptionAsString()}');
      return;
    }
    FlutterError.presentError(details);
  };

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Initialize unified authentication state & local persistence
  AuthService.initialize();

  runApp(const CinezaApp());
}


class CinezaApp extends StatelessWidget {
  const CinezaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: ThemeController.themeMode,
      builder: (context, currentMode, _) {
        return MaterialApp(
          title: 'Cineza Cinemas - Premium Movie Ticketing',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: currentMode,
          initialRoute: '/',
          routes: {
            '/': (context) => const HomeScreen(),
            '/login': (context) => const LoginScreen(),
            '/signup': (context) => const LoginScreen(initialMode: AuthMode.signUp),
            '/movie-details': (context) => const MovieDetailsScreen(),
            // Support both hyphen and underscore variants (browser URL bar / direct link)
            '/seat-selection': (context) => const SeatSelectionScreen(),
            '/seat_selection': (context) => const SeatSelectionScreen(),
            '/terms-policy': (context) => const TermsPolicyScreen(),
            '/terms': (context) => const TermsPolicyScreen(initialTab: 0),
            '/privacy': (context) => const TermsPolicyScreen(initialTab: 1),
            '/location': (context) => const LocationSelectorScreen(),
          },
          onGenerateRoute: (settings) {
            final name = settings.name?.toLowerCase() ?? '';
            if (name.contains('privacy')) {
              return MaterialPageRoute(
                settings: settings,
                builder: (_) => const TermsPolicyScreen(initialTab: 1),
              );
            }
            if (name.contains('term')) {
              return MaterialPageRoute(
                settings: settings,
                builder: (_) => const TermsPolicyScreen(initialTab: 0),
              );
            }
            // Normalize underscores to hyphens for any other routes
            final normalized = name.replaceAll('_', '-');
            if (normalized.contains('seat-selection')) {
              return MaterialPageRoute(
                settings: settings,
                builder: (_) => const SeatSelectionScreen(),
              );
            }
            if (normalized.contains('movie-details')) {
              return MaterialPageRoute(
                settings: settings,
                builder: (_) => const MovieDetailsScreen(),
              );
            }
            return null;
          },
          onUnknownRoute: (settings) {
            // Any unrecognized route → redirect to home gracefully
            return MaterialPageRoute(
              builder: (_) => const HomeScreen(),
            );
          },
        );
      },
    );
  }
}
