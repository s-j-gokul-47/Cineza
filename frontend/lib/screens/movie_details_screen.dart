import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/city.dart';
import '../models/movie.dart';
import '../models/show.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';

class MovieDetailsScreen extends StatefulWidget {
  const MovieDetailsScreen({super.key});

  @override
  State<MovieDetailsScreen> createState() => _MovieDetailsScreenState();
}

class _MovieDetailsScreenState extends State<MovieDetailsScreen> {
  final ApiService _apiService = ApiService();

  late Movie _movie;
  City? _city;
  List<ShowItem> _shows = [];
  bool _isLoading = true;
  int _selectedDateIndex = 0;

  late List<DateTime> _dates;

  @override
  void initState() {
    super.initState();
    ThemeController.themeMode.addListener(_onThemeChanged);
    final today = DateTime.now();
    _dates = List.generate(5, (index) => today.add(Duration(days: index)));
  }

  void _onThemeChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    ThemeController.themeMode.removeListener(_onThemeChanged);
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    if (args != null) {
      _movie = args['movie'] as Movie;
      _city = args['city'] as City?;
      _fetchShows();
    }
  }

  Future<void> _fetchShows() async {
    setState(() => _isLoading = true);
    final selectedDate = _dates[_selectedDateIndex];
    final dateStr = DateFormat('yyyy-MM-dd').format(selectedDate);

    final shows = await _apiService.getShows(
      movieId: _movie.id,
      cityId: _city?.id,
      date: dateStr,
    );

    if (mounted) {
      setState(() {
        _shows = shows;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: ThemeController.themeMode,
      builder: (context, currentMode, _) {
        final isDark = currentMode == ThemeMode.dark;
        final activePrimary = AppTheme.getPrimary(isDark);
        final timeFormat = DateFormat('h:mm a');

        // Group shows by Theatre
        final Map<String, List<ShowItem>> showsByTheatre = {};
        for (final show in _shows) {
          showsByTheatre.putIfAbsent(show.theatreName, () => []).add(show);
        }

        return Scaffold(
          backgroundColor: AppTheme.getBackground(isDark),
      body: CustomScrollView(
        slivers: [
          // Collapsible Backdrop App Bar
          SliverAppBar(
            expandedHeight: 280,
            pinned: true,
            backgroundColor: AppTheme.getSurface(isDark),
            leading: IconButton(
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isDark ? Colors.black54 : Colors.white.withValues(alpha: 0.85),
                  shape: BoxShape.circle,
                  boxShadow: isDark
                      ? null
                      : [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.1),
                            blurRadius: 6,
                          ),
                        ],
                ),
                child: Icon(
                  Icons.arrow_back_ios_new_rounded,
                  size: 16,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              onPressed: () => Navigator.pop(context),
            ),
            actions: [
              Container(
                margin: const EdgeInsets.only(right: 16),
                decoration: BoxDecoration(
                  color: isDark ? Colors.black54 : Colors.white.withValues(alpha: 0.85),
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  icon: Icon(
                    isDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
                    color: activePrimary,
                    size: 20,
                  ),
                  tooltip: isDark ? 'Switch to Bright Mode' : 'Switch to Dark Mode',
                  onPressed: () {
                    ThemeController.toggleTheme();
                  },
                ),
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  Image.network(
                    _movie.backdropUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => Container(color: AppTheme.getSurfaceLight(isDark)),
                  ),
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [
                          AppTheme.getBackground(isDark),
                          AppTheme.getBackground(isDark).withValues(alpha: isDark ? 0.6 : 0.75),
                          Colors.transparent,
                        ],
                        stops: const [0.0, 0.55, 1.0],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Movie Content
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title and Badges
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.network(
                          _movie.posterUrl,
                          width: 85,
                          height: 125,
                          fit: BoxFit.cover,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _movie.title,
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                letterSpacing: -0.3,
                                color: AppTheme.getTextPrimary(isDark),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Icon(Icons.star_rounded, size: 18, color: activePrimary),
                                const SizedBox(width: 4),
                                Text(
                                  '${_movie.imdbScore} / 10',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                    color: AppTheme.getTextPrimary(isDark),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppTheme.getSurfaceLight(isDark),
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(color: AppTheme.getSurfaceBorder(isDark)),
                                  ),
                                  child: Text(
                                    _movie.rating,
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: AppTheme.getTextPrimary(isDark),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '${_movie.genre} • ${_movie.durationFormatted} • ${_movie.language}',
                              style: TextStyle(
                                color: AppTheme.getTextSecondary(isDark),
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // Synopsis
                  Text(
                    'Synopsis',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.getTextPrimary(isDark),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _movie.synopsis,
                    style: TextStyle(
                      color: AppTheme.getTextSecondary(isDark),
                      fontSize: 14,
                      height: 1.5,
                    ),
                  ),

                  const SizedBox(height: 24),
                  Divider(color: AppTheme.getSurfaceBorder(isDark)),
                  const SizedBox(height: 16),

                  // Date Selector
                  Text(
                    'Select Date',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.getTextPrimary(isDark),
                    ),
                  ),
                  const SizedBox(height: 12),

                  SizedBox(
                    height: 70,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: _dates.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 10),
                      itemBuilder: (context, index) {
                        final date = _dates[index];
                        final isSelected = index == _selectedDateIndex;
                        return GestureDetector(
                          onTap: () {
                            setState(() => _selectedDateIndex = index);
                            _fetchShows();
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            width: 60,
                            decoration: BoxDecoration(
                              color: isSelected ? activePrimary : AppTheme.getSurfaceLight(isDark),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: isSelected ? activePrimary : AppTheme.getSurfaceBorder(isDark),
                              ),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  DateFormat('EEE').format(date).toUpperCase(),
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: isSelected
                                        ? (isDark ? Colors.black87 : Colors.white)
                                        : AppTheme.getTextMuted(isDark),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  DateFormat('d').format(date),
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: isSelected
                                        ? (isDark ? Colors.black : Colors.white)
                                        : AppTheme.getTextPrimary(isDark),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Theatres & Showtimes
                  Row(
                    children: [
                      Container(
                        width: 4,
                        height: 20,
                        decoration: BoxDecoration(
                          color: activePrimary,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Theatres & Showtimes',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          letterSpacing: -0.5,
                          color: AppTheme.getTextPrimary(isDark),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  if (_isLoading)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32.0),
                        child: CircularProgressIndicator(color: activePrimary),
                      ),
                    )
                  else if (showsByTheatre.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: AppTheme.getSurface(isDark),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppTheme.getSurfaceBorder(isDark)),
                      ),
                      child: Center(
                        child: Text(
                          'No showtimes available for the selected date.',
                          style: TextStyle(color: AppTheme.getTextSecondary(isDark)),
                        ),
                      ),
                    )
                  else
                    ...showsByTheatre.entries.map((entry) {
                      final theatreName = entry.key;
                      final theatreShows = entry.value;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppTheme.getSurface(isDark),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppTheme.getSurfaceBorder(isDark)),
                          boxShadow: isDark
                              ? null
                              : [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.04),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.theater_comedy_rounded, color: activePrimary, size: 20),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    theatreName,
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                      color: AppTheme.getTextPrimary(isDark),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              theatreShows.first.theatreAddress,
                              style: TextStyle(color: AppTheme.getTextMuted(isDark), fontSize: 12),
                            ),
                            const SizedBox(height: 14),

                            // Showtimes Chips
                            Wrap(
                              spacing: 10,
                              runSpacing: 10,
                              children: theatreShows.map((show) {
                                return InkWell(
                                  onTap: () {
                                    Navigator.pushNamed(
                                      context,
                                      '/seat-selection',
                                      arguments: {
                                        'show': show,
                                        'movie': _movie,
                                      },
                                    );
                                  },
                                  borderRadius: BorderRadius.circular(10),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                    decoration: BoxDecoration(
                                      color: AppTheme.getSurfaceLight(isDark),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color: show.screenType == 'IMAX'
                                            ? AppTheme.cyanAccent.withValues(alpha: 0.5)
                                            : AppTheme.getSurfaceBorder(isDark),
                                      ),
                                    ),
                                    child: Column(
                                      children: [
                                        Text(
                                          timeFormat.format(show.startTime),
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold,
                                            color: activePrimary,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          show.screenType,
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w600,
                                            color: show.screenType == 'IMAX'
                                                ? (isDark ? AppTheme.cyanAccent : const Color(0xFF0284C7))
                                                : AppTheme.getTextMuted(isDark),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ],
                        ),
                      );
                    }),

                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
      },
    );
  }
}
