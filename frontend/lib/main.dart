import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'screens/movie_details_screen.dart';
import 'screens/seat_selection_screen.dart';
import 'screens/terms_policy_screen.dart';
import 'screens/location_selector_screen.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Suppress intrusive yellow-and-black hazard warning strips on web zoom
  ErrorWidget.builder = (FlutterErrorDetails details) {
    final isOverflow = details.exceptionAsString().contains('overflowed by');
    if (isOverflow) {
      // Return an empty box so zoom clipping is seamless and never displays debug stripes
      return const SizedBox.shrink();
    }
    return ErrorWidget(details.exception);
  };

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

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
            '/movie-details': (context) => const MovieDetailsScreen(),
            '/seat-selection': (context) => const SeatSelectionScreen(),
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
            return null;
          },
        );
      },
    );
  }
}
