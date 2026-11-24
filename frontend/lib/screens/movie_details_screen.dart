import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/city.dart';
import '../models/movie.dart';
import '../models/show.dart';
import '../services/api_service.dart';
import '../services/location_service.dart';
import '../theme/app_theme.dart';
import '../widgets/cineza_animations.dart';
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
    LocationService.currentCity.addListener(_onLocationChanged);
  }

  void _onLocationChanged() {
    if (mounted) {
      setState(() {
        _city = LocationService.currentCity.value;
      });
      if (_city != null) {
        _fetchShows();
      } else {
        setState(() {
          _shows = [];
          _isLoading = false;
        });
      }
    }
  }

  void _onThemeChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    LocationService.currentCity.removeListener(_onLocationChanged);
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
      }
    }
  }

  void _showChooseLocationBanner() {
    _openLocationSelector();
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
              // All actions strictly constrained and scrollable to prevent RenderFlex overflow at any zoom level
              Builder(
                builder: (context) {
                  final sw = MediaQuery.of(context).size.width;
                  // On zoom or screens < 720, hide the redundant prompt to give plenty of breathing room
                  final isCompactZoom = sw < 720;
                  // Available width for actions is strictly bounded by screen width minus back button (56) and margins
                  final maxActionWidth = (sw - 68).clamp(80.0, sw);

                  return Container(
                    alignment: Alignment.centerRight,
                    constraints: BoxConstraints(maxWidth: maxActionWidth),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      reverse: true,
                      physics: const BouncingScrollPhysics(),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Pointer Prompt when location is not fixed (only on roomy desktop view)
                          if (_city == null && !isCompactZoom)
                            AnimatedBuilder(
                              animation: _pulseAnimation,
                              builder: (context, _) => Transform.translate(
                                offset: Offset(_pulseAnimation.value, 0),
                                child: GestureDetector(
                                  onTap: _openLocationSelector,
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

                          // Location Selector Pill
                          GestureDetector(
                            onTap: _openLocationSelector,
                            child: Container(
                              margin: const EdgeInsets.only(right: 6),
                              padding: EdgeInsets.symmetric(
                                horizontal: sw < 400 ? 8 : 10,
                                vertical: 6,
                              ),
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
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.location_on_rounded, color: activePrimary, size: 15),
                                  const SizedBox(width: 4),
                                  Text(
                                    _city?.name ?? 'LOCATION',
                                    style: TextStyle(
                                      color: _city != null ? AppTheme.getTextPrimary(isDark) : activePrimary,
                                      fontSize: sw < 400 ? 11 : 12,
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

                          // Theme toggle
                          Container(
                            margin: const EdgeInsets.only(right: 8),
                            decoration: BoxDecoration(
                              color: isDark ? Colors.black54 : Colors.white.withValues(alpha: 0.85),
                              shape: BoxShape.circle,
                            ),
                            child: IconButton(
                              icon: Icon(
                                isDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
                                color: activePrimary,
                                size: 18,
                              ),
                              tooltip: isDark ? 'Switch to Bright Mode' : 'Switch to Dark Mode',
                              onPressed: () {
                                ThemeController.toggleTheme();
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  Container(color: Colors.black),
                  // React Bits: ParallaxWidget – scroll-driven parallax on backdrop
                  ParallaxWidget(
                    factor: 0.25,
                    child: _buildImageWidget(
                      _resolveBackdropUrl(movie),
                      isDark: isDark,
                      fit: BoxFit.cover,
                      logoSize: 80,
                    ),
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
                      // React Bits: SpotlightCard – pointer-tracked glow on poster
                      SpotlightCard(
                        spotColor: activePrimary,
                        spotRadius: 80,
                        spotOpacity: 0.25,
                        borderRadius: BorderRadius.circular(12),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: _buildImageWidget(
                            movie.resolvedPosterUrl,
                            isDark: isDark,
                            width: 90,
                            height: 135,
                            fit: BoxFit.cover,
                            logoSize: 36,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // React Bits: GradientText – animated gradient on movie title
                            GradientText(
                              text: movie.title,
                              colors: isDark
                                  ? [const Color(0xFF60A5FA), const Color(0xFFA78BFA), const Color(0xFF38BDF8)]
                                  : [const Color(0xFF0062FF), const Color(0xFF6366F1), const Color(0xFF0284C7)],
                              style: AppTheme.argentHeading(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                letterSpacing: -0.3,
                                color: AppTheme.getTextPrimary(isDark),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 6,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF59E0B),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.star_rounded, size: 14, color: Colors.black),
                                      const SizedBox(width: 3),
                                      Text(
                                        '${movie.imdbScore.toStringAsFixed(1)} / 10',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w900,
                                          fontSize: 12,
                                          color: Colors.black,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: AppTheme.getSurfaceLight(isDark),
                                    borderRadius: BorderRadius.circular(6),
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
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      colors: [Color(0xFF0284C7), Color(0xFF0062FF)],
                                    ),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Text(
                                    'IMAX 3D',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w900,
                                      color: Colors.white,
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
                                fontWeight: FontWeight.w500,
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
                    height: 74,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: _dates.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 10),
                      itemBuilder: (context, index) {
                        final date = _dates[index];
                        final isSelected = index == _selectedDateIndex;
                        final isToday = index == 0;
                        final dayName = isToday ? 'TODAY' : DateFormat('EEE').format(date).toUpperCase();
                        final monthName = DateFormat('MMM').format(date).toUpperCase();

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
                            width: 66,
                            decoration: BoxDecoration(
                              color: isSelected ? activePrimary : AppTheme.getSurfaceLight(isDark),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: isSelected ? activePrimary : AppTheme.getSurfaceBorder(isDark),
                                width: isSelected ? 1.5 : 1.0,
                              ),
                              boxShadow: isSelected
                                  ? [
                                      BoxShadow(
                                        color: activePrimary.withValues(alpha: 0.4),
                                        blurRadius: 8,
                                        offset: const Offset(0, 2),
                                      ),
                                    ]
                                  : null,
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  dayName,
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.5,
                                    color: isSelected
                                        ? (isDark ? Colors.black87 : Colors.white)
                                        : AppTheme.getTextMuted(isDark),
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  DateFormat('d').format(date),
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w900,
                                    color: isSelected
                                        ? (isDark ? Colors.black : Colors.white)
                                        : AppTheme.getTextPrimary(isDark),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  monthName,
                                  style: TextStyle(
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w600,
                                    color: isSelected
                                        ? (isDark ? Colors.black54 : Colors.white70)
                                        : AppTheme.getTextMuted(isDark),
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
                            const SizedBox(height: 12),
                            // Theatre Amenities Strip
                            Wrap(
                              spacing: 8,
                              runSpacing: 6,
                              children: [
                                _buildAmenityChip(Icons.verified_rounded, '100% Refundable', const Color(0xFF10B981), isDark),
                                _buildAmenityChip(Icons.surround_sound_rounded, 'Dolby Atmos 7.1', activePrimary, isDark),
                                _buildAmenityChip(Icons.fastfood_rounded, 'F&B to Seat', const Color(0xFFF59E0B), isDark),
                                _buildAmenityChip(Icons.wheelchair_pickup_rounded, 'Wheelchair Access', const Color(0xFF94A3B8), isDark),
                              ],
                            ),
                            const SizedBox(height: 14),
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
            Wrap(
              alignment: WrapAlignment.center,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Icon(Icons.arrow_upward_rounded, size: 18, color: activePrimary),
                const SizedBox(width: 6),
                Text(
                  'Choose a location using the location symbol above',
                  textAlign: TextAlign.center,
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

  Widget _buildAmenityChip(IconData icon, String label, Color color, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.12 : 0.08),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.25), width: 0.8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white70 : Colors.black87,
            ),
          ),
        ],
      ),
    );
  }
}
