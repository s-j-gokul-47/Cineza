import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/city.dart';
import '../models/movie.dart';
import '../models/show.dart';
import '../services/api_service.dart';
import '../services/location_service.dart';
import '../theme/app_theme.dart';
import 'location_selector_screen.dart';

class MovieDetailsScreen extends StatefulWidget {
  const MovieDetailsScreen({super.key});

  @override
  State<MovieDetailsScreen> createState() => _MovieDetailsScreenState();
}

class _MovieDetailsScreenState extends State<MovieDetailsScreen> with SingleTickerProviderStateMixin {
  final ApiService _apiService = ApiService();

  Movie? _movie;
  City? _city;
  List<ShowItem> _shows = [];
  bool _isLoading = true;
  int _selectedDateIndex = 0;

  late List<DateTime> _dates;

  Widget _buildImageWidget(String url, {required bool isDark, BoxFit fit = BoxFit.cover, double? width, double? height, double logoSize = 40}) {
    final errorWidget = Container(
      width: width,
      height: height,
      color: AppTheme.getSurfaceLight(isDark),
      alignment: Alignment.center,
      child: Opacity(
        opacity: isDark ? 0.25 : 0.35,
        child: Image.asset(
          'assets/images/cineza_logo_transparent.png',
          width: logoSize,
          height: logoSize,
          fit: BoxFit.contain,
        ),
      ),
    );

    if (url.startsWith('assets/')) {
      return Image.asset(
        url,
        width: width,
        height: height,
        fit: fit,
        errorBuilder: (context, error, stackTrace) => errorWidget,
      );
    }
    return Image.network(
      url,
      width: width,
      height: height,
      fit: fit,
      errorBuilder: (context, error, stackTrace) => errorWidget,
    );
  }

  static const Map<String, String> _customTitleCardMap = {
    '24': 'assets/images/titlecard_24.png',
    'soorarai pottru': 'assets/images/titlecard_soorarai_pottru.jpg',
    'maanaadu': 'assets/images/titlecard_maanaadu.png',
    'kgf': 'assets/images/titlecard_kgf2.png',
    'k.g.f': 'assets/images/titlecard_kgf2.png',
    'k.g.f.': 'assets/images/titlecard_kgf2.png',
    'kgf 2': 'assets/images/titlecard_kgf2.png',
    'kgf: chapter 2': 'assets/images/titlecard_kgf2.png',
    'kgf chapter 2': 'assets/images/titlecard_kgf2.png',
    'k.g.f 2': 'assets/images/titlecard_kgf2.png',
    'k.g.f. 2': 'assets/images/titlecard_kgf2.png',
    'k.g.f: chapter 2': 'assets/images/titlecard_kgf2.png',
    'k.g.f. chapter 2': 'assets/images/titlecard_kgf2.png',
    // Add additional movie title cards here as provided by user:
    // 'vikram': 'assets/images/titlecard_vikram.png',
  };

  String _resolveBackdropUrl(Movie movie) {
    final titleKey = movie.title.toLowerCase().trim();
    if (_customTitleCardMap.containsKey(titleKey)) {
      return _customTitleCardMap[titleKey]!;
    }
    if (titleKey.contains('kgf') || titleKey.contains('k.g.f')) {
      return 'assets/images/titlecard_kgf2.png';
    }
    if (titleKey.contains('soorarai')) {
      return 'assets/images/titlecard_soorarai_pottru.jpg';
    }
    if (titleKey.contains('maanaadu')) {
      return 'assets/images/titlecard_maanaadu.png';
    }
    if (titleKey == '24' || titleKey.contains('24')) {
      return 'assets/images/titlecard_24.png';
    }
    return movie.backdropUrl;
  }

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    ThemeController.themeMode.addListener(_onThemeChanged);
    final today = DateTime.now();
    _dates = List.generate(7, (index) => today.add(Duration(days: index)));

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: -3.0, end: 4.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  void _onThemeChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    ThemeController.themeMode.removeListener(_onThemeChanged);
    _pulseController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_movie == null) {
      final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
      if (args != null && args['movie'] is Movie) {
        _movie = args['movie'] as Movie;
        _city = (args['city'] as City?) ?? LocationService.currentCity.value;
      } else {
        // Fallback default movie if user navigated directly or refreshed on /movie-details
        _movie = Movie(
          id: 1,
          title: '24',
          synopsis: 'A sci-fi thriller about a genius watchmaker who invents a time-travel watch. When his vengeful twin brother Athreya resurfaces to claim it, a thrilling war across timelines begins.',
          posterUrl: 'assets/images/movie_24.jpg',
          backdropUrl: 'assets/images/titlecard_24.png',
          genre: 'Sci-Fi',
          language: 'Tamil',
          durationMinutes: 164,
          rating: 'UA',
          imdbScore: 7.9,
          releaseDate: '2016-05-06',
        );
        _city = LocationService.currentCity.value;
      }

      // Do NOT default _city to Chennai! Keep it null if user hasn't chosen location
      if (_city != null) {
        _fetchShows();
      } else {
        setState(() {
          _shows = [];
          _isLoading = false;
        });
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _city == null) {
            _showChooseLocationBanner();
          }
        });
      }
    }
  }

  void _showChooseLocationBanner() {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    final isDark = ThemeController.isDark(context);
    final activePrimary = AppTheme.getPrimary(isDark);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 20),
        backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
        duration: const Duration(seconds: 4),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: activePrimary, width: 1.5),
        ),
        content: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: activePrimary.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.arrow_upward_rounded, color: activePrimary, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Choose a location',
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 13.5,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Tap the LOCATION symbol in the top bar to select your city & book tickets.',
                    style: TextStyle(
                      fontSize: 11.5,
                      color: isDark ? Colors.white70 : Colors.black54,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: () {
                ScaffoldMessenger.of(context).hideCurrentSnackBar();
                _openLocationSelector();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: activePrimary,
                foregroundColor: isDark ? Colors.black : Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('Choose', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _fetchShows() async {
    final currentMovie = _movie;
    if (currentMovie == null || _city == null) {
      setState(() {
        _shows = [];
        _isLoading = false;
      });
      return;
    }
    setState(() => _isLoading = true);
    final selectedDate = _dates[_selectedDateIndex];
    final dateStr = DateFormat('yyyy-MM-dd').format(selectedDate);

    final shows = await _apiService.getShows(
      movieId: currentMovie.id,
      cityId: _city?.id,
      cityName: _city?.name,
      movieTitle: currentMovie.title,
      date: dateStr,
    );

    if (mounted) {
      setState(() {
        _shows = shows;
        _isLoading = false;
      });
    }
  }

  Future<void> _openLocationSelector() async {
    final chosenCity = await Navigator.push<City>(
      context,
      MaterialPageRoute(
        builder: (context) => LocationSelectorScreen(
          currentCity: _city,
          onLocationConfirmed: (city) {
            setState(() => _city = city);
            LocationService.setCity(city);
            _fetchShows();
          },
        ),
      ),
    );
    if (chosenCity != null && mounted) {
      setState(() => _city = chosenCity);
      LocationService.setCity(chosenCity);
      _fetchShows();
    }
  }

  String _formatCurrency(double price) {
    final country = _city?.country.toLowerCase() ?? '';
    if (country.contains('united states') || country == 'usa') {
      return '\$${price.toStringAsFixed(2)}';
    } else if (country.contains('united kingdom') || country == 'uk') {
      return '£${price.toStringAsFixed(2)}';
    } else if (country.contains('emirates') || country == 'dubai' || country == 'uae') {
      return 'AED ${price.toStringAsFixed(0)}';
    }
    return '₹${price.toInt()}';
  }

  @override
  Widget build(BuildContext context) {
    final movie = _movie;
    if (movie == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
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
            expandedHeight: 300,
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
              // Pointer Prompt when location is not fixed
              if (_city == null) ...[
                AnimatedBuilder(
                  animation: _pulseAnimation,
                  builder: (context, _) => Transform.translate(
                    offset: Offset(_pulseAnimation.value, 0),
                    child: GestureDetector(
                      onTap: _openLocationSelector,
                      child: Center(
                        child: Container(
                          margin: const EdgeInsets.only(right: 6),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: isDark
                                  ? [const Color(0xFF18A0FB), const Color(0xFF0062FF)]
                                  : [const Color(0xFF0062FF), const Color(0xFF2563EB)],
                            ),
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: activePrimary.withValues(alpha: 0.5),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Choose a location',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w900,
                                  color: isDark ? Colors.black : Colors.white,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Icon(
                                Icons.arrow_forward_rounded,
                                size: 14,
                                color: isDark ? Colors.black : Colors.white,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],

              // Location Selector Pill
              Center(
                child: Container(
                  margin: const EdgeInsets.only(right: 8),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.black54 : Colors.white.withValues(alpha: 0.85),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: _city == null ? activePrimary : activePrimary.withValues(alpha: 0.35),
                      width: _city == null ? 1.8 : 1.0,
                    ),
                    boxShadow: _city == null
                        ? [
                            BoxShadow(
                              color: activePrimary.withValues(alpha: 0.4),
                              blurRadius: 8,
                            ),
                          ]
                        : null,
                  ),
                  child: InkWell(
                    onTap: _openLocationSelector,
                    borderRadius: BorderRadius.circular(20),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.location_on_rounded, color: activePrimary, size: 15),
                          const SizedBox(width: 4),
                          Text(
                            _city?.name ?? 'LOCATION',
                            style: TextStyle(
                              color: _city != null ? AppTheme.getTextPrimary(isDark) : activePrimary,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 2),
                          Icon(
                            Icons.arrow_drop_down_rounded,
                            color: AppTheme.getTextMuted(isDark),
                            size: 18,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
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
                  Container(color: Colors.black),
                  _buildImageWidget(
                    _resolveBackdropUrl(movie),
                    isDark: isDark,
                    fit: BoxFit.cover,
                    logoSize: 80,
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
                        stops: const [0.0, 0.40, 1.0],
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
                        child: _buildImageWidget(
                          movie.posterUrl,
                          isDark: isDark,
                          width: 85,
                          height: 125,
                          fit: BoxFit.cover,
                          logoSize: 36,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              movie.title,
                              style: AppTheme.argentHeading(
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
                                  '${movie.imdbScore} / 10',
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
                                    movie.rating,
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
                              '${movie.genre} • ${movie.durationFormatted} • ${movie.language}',
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
                    movie.synopsis,
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
                            if (_city == null) {
                              _showChooseLocationBanner();
                              return;
                            }
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

                  // Theatres & Showtimes Section Header
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Container(
                        width: 4,
                        height: 24,
                        decoration: BoxDecoration(
                          color: activePrimary,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Theatres & Showtimes',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                letterSpacing: -0.5,
                                color: AppTheme.getTextPrimary(isDark),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Real multiplexes in ${_city?.name ?? "your location"}',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppTheme.getTextSecondary(isDark),
                              ),
                            ),
                          ],
                        ),
                      ),
                      InkWell(
                        onTap: _openLocationSelector,
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppTheme.getSurfaceLight(isDark),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: activePrimary.withValues(alpha: 0.35)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.edit_location_alt_rounded, size: 14, color: activePrimary),
                              const SizedBox(width: 5),
                              Text(
                                _city?.name ?? 'Change City',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: activePrimary,
                                ),
                              ),
                              const SizedBox(width: 2),
                              Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: activePrimary),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  if (_city == null)
                    _buildNoLocationCard(isDark, activePrimary)
                  else if (_isLoading)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.all(36.0),
                        child: Column(
                          children: [
                            CircularProgressIndicator(color: activePrimary),
                            const SizedBox(height: 14),
                            Text(
                              'Fetching live theatres in ${_city?.name ?? "your city"}...',
                              style: TextStyle(
                                fontSize: 13,
                                color: AppTheme.getTextSecondary(isDark),
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else if (showsByTheatre.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(28),
                      decoration: BoxDecoration(
                        color: AppTheme.getSurface(isDark),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppTheme.getSurfaceBorder(isDark)),
                      ),
                      child: Center(
                        child: Column(
                          children: [
                            Icon(Icons.theaters_outlined, size: 40, color: AppTheme.getTextMuted(isDark)),
                            const SizedBox(height: 12),
                            Text(
                              'No showtimes currently scheduled in ${_city?.name ?? "this city"}.',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: AppTheme.getTextPrimary(isDark),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Try picking another date or switch your city.',
                              style: TextStyle(fontSize: 12, color: AppTheme.getTextSecondary(isDark)),
                            ),
                            const SizedBox(height: 14),
                            ElevatedButton.icon(
                              onPressed: _openLocationSelector,
                              icon: const Icon(Icons.location_city_rounded, size: 16),
                              label: const Text('Explore Other Cities'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: activePrimary,
                                foregroundColor: isDark ? Colors.black : Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    ...showsByTheatre.entries.map((entry) {
                      final theatreName = entry.key;
                      final theatreShows = entry.value;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 18),
                        padding: const EdgeInsets.all(18),
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
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: activePrimary.withValues(alpha: isDark ? 0.2 : 0.12),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Icon(Icons.theater_comedy_rounded, color: activePrimary, size: 20),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        theatreName,
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: AppTheme.getTextPrimary(isDark),
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Row(
                                        children: [
                                          Icon(Icons.place_outlined, size: 12, color: AppTheme.getTextMuted(isDark)),
                                          const SizedBox(width: 4),
                                          Expanded(
                                            child: Text(
                                              theatreShows.first.theatreAddress,
                                              style: TextStyle(
                                                color: AppTheme.getTextMuted(isDark),
                                                fontSize: 12,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Divider(color: AppTheme.getSurfaceBorder(isDark), height: 1),
                            const SizedBox(height: 14),

                            // Showtimes Chips
                            Wrap(
                              spacing: 12,
                              runSpacing: 12,
                              children: theatreShows.map((show) {
                                final isImax = show.screenType.toUpperCase().contains('IMAX');
                                final isDolby = show.screenType.toUpperCase().contains('DOLBY');
                                final is4Dx = show.screenType.toUpperCase().contains('4DX');
                                final isVip = show.screenType.toUpperCase().contains('VIP');

                                Color formatColor = AppTheme.getTextMuted(isDark);
                                Color formatBorderColor = AppTheme.getSurfaceBorder(isDark);
                                if (isImax) {
                                  formatColor = isDark ? AppTheme.cyanAccent : const Color(0xFF0284C7);
                                  formatBorderColor = AppTheme.cyanAccent.withValues(alpha: 0.4);
                                } else if (is4Dx) {
                                  formatColor = const Color(0xFFE11D48);
                                  formatBorderColor = const Color(0xFFE11D48).withValues(alpha: 0.4);
                                } else if (isVip) {
                                  formatColor = AppTheme.getGoldAccent(isDark);
                                  formatBorderColor = AppTheme.getGoldAccent(isDark).withValues(alpha: 0.4);
                                } else if (isDolby) {
                                  formatColor = const Color(0xFF8B5CF6);
                                  formatBorderColor = const Color(0xFF8B5CF6).withValues(alpha: 0.4);
                                }

                                return InkWell(
                                  onTap: () {
                                    Navigator.pushNamed(
                                      context,
                                      '/seat-selection',
                                      arguments: {
                                        'show': show,
                                        'movie': movie,
                                      },
                                    );
                                  },
                                  borderRadius: BorderRadius.circular(12),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                    decoration: BoxDecoration(
                                      color: AppTheme.getSurfaceLight(isDark),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: formatBorderColor),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
                                          blurRadius: 4,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.center,
                                      children: [
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Container(
                                              width: 6,
                                              height: 6,
                                              decoration: const BoxDecoration(
                                                color: Color(0xFF22C55E),
                                                shape: BoxShape.circle,
                                              ),
                                            ),
                                            const SizedBox(width: 6),
                                            Text(
                                              timeFormat.format(show.startTime),
                                              style: TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.bold,
                                                color: activePrimary,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: formatColor.withValues(alpha: 0.12),
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            show.screenType,
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                              color: formatColor,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          _formatCurrency(show.baseStartingPrice),
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                            color: AppTheme.getTextSecondary(isDark),
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

  Widget _buildNoLocationCard(bool isDark, Color activePrimary) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
      decoration: BoxDecoration(
        color: AppTheme.getSurface(isDark),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: activePrimary.withValues(alpha: 0.4), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: activePrimary.withValues(alpha: isDark ? 0.15 : 0.08),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Center(
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.arrow_upward_rounded, size: 18, color: activePrimary),
                const SizedBox(width: 6),
                Text(
                  'Choose a location using the location symbol above',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.4,
                    color: activePrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: activePrimary.withValues(alpha: isDark ? 0.2 : 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.location_on_rounded, size: 44, color: activePrimary),
            ),
            const SizedBox(height: 16),
            Text(
              'Choose a location',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: AppTheme.getTextPrimary(isDark),
              ),
            ),
            const SizedBox(height: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Text(
                'Please select your city to discover theatres, real multiplex showtimes, and book your tickets.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13.5,
                  height: 1.4,
                  color: AppTheme.getTextSecondary(isDark),
                ),
              ),
            ),
            const SizedBox(height: 22),
            ElevatedButton.icon(
              onPressed: _openLocationSelector,
              icon: const Icon(Icons.near_me_rounded, size: 18),
              label: const Text(
                'Choose Location Now',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: activePrimary,
                foregroundColor: isDark ? Colors.black : Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 13),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                elevation: 4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
