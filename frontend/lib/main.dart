import 'package:flutter/material.dart';
import 'screens/home_screen.dart';
import 'screens/movie_details_screen.dart';
import 'screens/seat_selection_screen.dart';
import 'theme/app_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
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
            '/movie-details': (context) => const MovieDetailsScreen(),
            '/seat-selection': (context) => const SeatSelectionScreen(),
          },
        );
      },
    );
  }
}
