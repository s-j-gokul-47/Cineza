import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/city.dart';
import '../models/movie.dart';
import '../models/user.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../services/location_service.dart';
import '../theme/app_theme.dart';
import '../widgets/cineza_animations.dart';
import 'location_selector_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  final ApiService _apiService = ApiService();

  List<City> _cities = [];
  City? _selectedCity;
  List<Movie> _movies = [];
  Movie? _selectedMovie;
  bool _isLoading = true;
  String _selectedGenre = 'All';
  final TextEditingController _searchController = TextEditingController();

  final List<String> _genres = ['All', 'Sci-Fi', 'Action', 'Biography'];

  Widget _buildImageWidget(String url, {required bool isDark, BoxFit fit = BoxFit.cover, double logoSize = 50}) {
    if (url.startsWith('assets/')) {
      return Image.asset(
        url,
        fit: fit,
        errorBuilder: (context, error, stackTrace) => Container(
          color: AppTheme.getSurfaceLight(isDark),
          alignment: Alignment.center,
          child: Opacity(
            opacity: isDark ? 0.35 : 0.45,
            child: Image.asset(
              'assets/images/cineza_logo_transparent.png',
              width: logoSize,
              height: logoSize,
              fit: BoxFit.contain,
            ),
          ),
        ),
      );
    }
    return Image.network(
      url,
      fit: fit,
      errorBuilder: (context, error, stackTrace) => Container(
        color: AppTheme.getSurfaceLight(isDark),
        alignment: Alignment.center,
        child: Opacity(
          opacity: isDark ? 0.35 : 0.45,
          child: Image.asset(
            'assets/images/cineza_logo_transparent.png',
            width: logoSize,
            height: logoSize,
            fit: BoxFit.contain,
          ),
        ),
      ),
    );
  }

  bool _isSyncingUser = false;

  /// Resolves the user's display name from CinezaUser profile
  String _getResolvedDisplayName(CinezaUser user) {
    if (user.displayName != null &&
        user.displayName!.trim().isNotEmpty &&
        user.displayName != 'Cineza User' &&
        user.displayName != 'Cineza Member') {
      return user.displayName!.trim();
    }
    // Fallback to email prefix
    if (user.email != null && user.email!.trim().isNotEmpty) {
      return user.email!.split('@').first;
    }
    // Fallback to phone number
    if (user.phoneNumber != null && user.phoneNumber!.trim().isNotEmpty) {
      return user.phoneNumber!;
    }
    return 'Cineza Member';
  }

  /// Automatically synchronizes the user profile with Firebase Auth and MySQL backend
  void _syncUserProfileIfNeeded(CinezaUser user) {
    if (_isSyncingUser) return;
    if (user.displayName == null ||
        user.displayName!.trim().isEmpty ||
        user.displayName == 'Cineza User' ||
        user.displayName == 'Cineza Member') {
      _isSyncingUser = true;
      AuthService().resolveAndSyncUser(user).then((resolvedName) {
        _isSyncingUser = false;
        if (mounted && resolvedName != 'Cineza User' && resolvedName != 'Cineza Member') {
          setState(() {});
        }
      }).catchError((_) {
        _isSyncingUser = false;
      });
    }
  }

  /// Dialog to edit or update the username anytime
  void _showEditUsernameDialog(BuildContext context, CinezaUser user) {
    final messenger = ScaffoldMessenger.of(context);
    final currentName = _getResolvedDisplayName(user);
    final controller = TextEditingController(
      text: (currentName == 'Cineza User' || currentName == 'Cineza Member') ? '' : currentName,
    );
    final isDark = ThemeController.themeMode.value == ThemeMode.dark;

    showDialog(
      context: context,
      builder: (ctx) {
        bool isSaving = false;
        String? errorText;

        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            return AlertDialog(
              backgroundColor: isDark ? AppTheme.darkSurface : Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(
                  color: isDark ? AppTheme.getSurfaceBorder(isDark) : const Color(0xFFCFE0F8),
                ),
              ),
              title: Row(
                children: [
                  Icon(
                    Icons.edit_rounded,
                    color: isDark ? AppTheme.goldAccent : const Color(0xFF0062FF),
                    size: 22,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Change Username',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Update the name displayed on your Cineza tickets, bookings, and profile.',
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark ? AppTheme.getTextMuted(isDark) : Colors.black54,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: controller,
                    autofocus: true,
                    style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                    decoration: InputDecoration(
                      labelText: 'Username',
                      hintText: 'Enter new username',
                      errorText: errorText,
                      filled: true,
                      fillColor: isDark ? AppTheme.getSurfaceLight(isDark) : const Color(0xFFF1F5F9),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(
                          color: isDark ? AppTheme.getSurfaceBorder(isDark) : const Color(0xFFCFE0F8),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: isSaving ? null : () => Navigator.of(ctx).pop(),
                  child: Text(
                    'Cancel',
                    style: TextStyle(color: isDark ? AppTheme.getTextMuted(isDark) : Colors.black54),
                  ),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isDark ? AppTheme.getPrimary(isDark) : const Color(0xFF0062FF),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: isSaving
                      ? null
                      : () async {
                          final newName = controller.text.trim();
                          if (newName.isEmpty) {
                            setDialogState(() => errorText = 'Username cannot be empty');
                            return;
                          }
                          if (newName.length < 2) {
                            setDialogState(() => errorText = 'Minimum 2 characters required');
                            return;
                          }

                          setDialogState(() {
                            isSaving = true;
                            errorText = null;
                          });

                          try {
                            await AuthService().updateUsername(newName);
                            if (ctx.mounted) Navigator.of(ctx).pop();
                            if (mounted) {
                              setState(() {});
                              messenger.showSnackBar(
                                SnackBar(
                                  content: Text('Username updated to "$newName"'),
                                  backgroundColor: const Color(0xFF0062FF),
                                  duration: const Duration(seconds: 2),
                                ),
                              );
                            }
                          } catch (e) {
                            setDialogState(() {
                              isSaving = false;
                              errorText = 'Failed to update username';
                            });
                          }
                        },
                  child: isSaving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }


  late AnimationController _locationPulseController;
  late Animation<double> _locationPulseAnimation;
  Timer? _frequentReminderTimer;
  VoidCallback? _authListener;
  bool _wasLoggedIn = false;
  final OverlayPortalController _locationPopupController = OverlayPortalController();
  final LayerLink _locationLayerLink = LayerLink();

  late final PageController _marqueePageController;
  int _currentMarqueeIndex = 0;
  Timer? _marqueeTimer;

  @override
  void initState() {
    super.initState();
    _marqueePageController = PageController();
    _startMarqueeTimer();
    ThemeController.themeMode.addListener(_onThemeChanged);
    LocationService.currentCity.addListener(_onLocationServiceChanged);

    _locationPulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    _locationPulseAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _locationPulseController, curve: Curves.easeInOut),
    );

    _selectedCity = LocationService.currentCity.value;
    _loadInitialData();

    _wasLoggedIn = AuthService.isLoggedIn;
    _authListener = () {
      final loggedIn = AuthService.isLoggedIn;
      if (_wasLoggedIn && !loggedIn) {
        // User logged out – erase all location and session data
        _handlePostLogoutReset();
      }
      _wasLoggedIn = loggedIn;
      if (mounted) setState(() {});
    };
    AuthService.currentUserNotifier.addListener(_authListener!);

    // Trigger pop-up on home page whenever user hasn't fixed a location
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _selectedCity == null) {
        _showFrequentLocationPrompt();
      }
    });

    _startFrequentReminderTimer();
  }

  /// Complete reset of local and session state when user logs out
  void _handlePostLogoutReset() {
    AuthService.clearAllUserData();
    if (mounted) {
      setState(() {
        _selectedCity = null;
        _selectedGenre = 'All';
        _selectedMovie = null;
        _searchController.clear();
      });
      _filterMovies();
      _startFrequentReminderTimer();
      _showFrequentLocationPrompt();
    }
  }

  void _onLocationServiceChanged() {
    if (mounted) {
      setState(() {
        _selectedCity = LocationService.currentCity.value;
      });
      _filterMovies();
      if (_selectedCity != null) {
        if (_locationPopupController.isShowing) {
          _locationPopupController.hide();
        }
        _frequentReminderTimer?.cancel();
      } else {
        _startFrequentReminderTimer();
        _showFrequentLocationPrompt();
      }
    }
  }

  void _startFrequentReminderTimer() {
    _frequentReminderTimer?.cancel();
    // Remind frequently every 12 seconds while location is not chosen
    _frequentReminderTimer = Timer.periodic(const Duration(seconds: 12), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_selectedCity == null) {
        _showFrequentLocationPrompt();
      } else {
        timer.cancel();
      }
    });
  }

  void _showFrequentLocationPrompt() {
    if (_selectedCity != null || !mounted) {
      if (_locationPopupController.isShowing) {
        _locationPopupController.hide();
      }
      return;
    }
    if (!_locationPopupController.isShowing) {
      _locationPopupController.show();
    }
  }

  Future<void> _openLocationSelector() async {
    if (_locationPopupController.isShowing) {
      _locationPopupController.hide();
    }
    final chosenCity = await Navigator.push<City>(
      context,
      MaterialPageRoute(
        builder: (_) => LocationSelectorScreen(
          currentCity: _selectedCity,
          availableCities: _cities,
          onLocationConfirmed: (newCity) {
            setState(() => _selectedCity = newCity);
            LocationService.setCity(newCity);
            _filterMovies();
          },
        ),
      ),
    );
    if (chosenCity != null && mounted) {
      setState(() => _selectedCity = chosenCity);
      LocationService.setCity(chosenCity);
      _filterMovies();
    }
  }

  void _onThemeChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _loadInitialData() async {
    setState(() => _isLoading = true);
    final cities = await _apiService.getCities();
    // Do NOT default to cities.first! Keep null initially as requested
    final selected = LocationService.currentCity.value;
    final movies = await _apiService.getMovies(
      cityId: selected?.id,
      genre: _selectedGenre,
    );

    if (mounted) {
      setState(() {
        _cities = cities;
        _selectedCity = selected;
        _movies = movies;
        if (_selectedMovie == null || !movies.any((m) => m.id == _selectedMovie?.id)) {
          _selectedMovie = movies.isNotEmpty ? movies.first : null;
        }
        _isLoading = false;
      });
    }
  }

  Future<void> _filterMovies() async {
    setState(() => _isLoading = true);
    final movies = await _apiService.getMovies(
      cityId: _selectedGenre == 'All' ? null : _selectedCity?.id,
      search: _searchController.text.trim(),
      genre: _selectedGenre,
    );
    if (mounted) {
      setState(() {
        _movies = movies;
        if (!movies.any((m) => m.id == _selectedMovie?.id)) {
          _selectedMovie = movies.isNotEmpty ? movies.first : null;
        }
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _marqueeTimer?.cancel();
    _marqueePageController.dispose();
    if (_locationPopupController.isShowing) {
      _locationPopupController.hide();
    }
    if (_authListener != null) {
      AuthService.currentUserNotifier.removeListener(_authListener!);
    }
    ThemeController.themeMode.removeListener(_onThemeChanged);
    LocationService.currentCity.removeListener(_onLocationServiceChanged);
    _locationPulseController.dispose();
    _frequentReminderTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _startMarqueeTimer() {
    _marqueeTimer?.cancel();
    _marqueeTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (!mounted || !_marqueePageController.hasClients) return;
      final featuredCount = _movies.isNotEmpty ? _movies.take(4).length : 4;
      if (featuredCount <= 1) return;
      final nextIndex = (_currentMarqueeIndex + 1) % featuredCount;
      _marqueePageController.animateToPage(
        nextIndex,
        duration: const Duration(milliseconds: 650),
        curve: Curves.easeInOutCubic,
      );
    });
  }

  Widget _buildSearchBar(bool isDark, Color activePrimary) {
    return SizedBox(
      height: 40,
      child: TextField(
        controller: _searchController,
        onChanged: (_) => _filterMovies(),
        style: TextStyle(
          fontSize: 13,
          color: AppTheme.getTextPrimary(isDark),
        ),
        decoration: InputDecoration(
          hintText: 'Search movies, genres, actors...',
          hintStyle: TextStyle(
            fontSize: 13,
            color: AppTheme.getTextMuted(isDark),
          ),
          prefixIcon: Icon(
            Icons.search_rounded,
            size: 20,
            color: isDark ? AppTheme.getTextSecondary(isDark) : const Color(0xFF0062FF),
          ),
          contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: Icon(Icons.clear, size: 16, color: AppTheme.getTextMuted(isDark)),
                  onPressed: () {
                    _searchController.clear();
                    _filterMovies();
                  },
                )
              : null,
          filled: true,
          fillColor: isDark ? AppTheme.getSurfaceLight(isDark) : Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(24),
            borderSide: BorderSide(
              color: isDark ? AppTheme.getSurfaceBorder(isDark) : const Color(0xFFCFE0F8),
            ),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(24),
            borderSide: BorderSide(
              color: isDark ? AppTheme.getSurfaceBorder(isDark) : const Color(0xFFCFE0F8),
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(24),
            borderSide: BorderSide(color: activePrimary, width: 1.5),
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderLogo(bool isDark, Color activePrimary, bool isCompact, bool isNarrow, bool isUltraNarrow) {
    if (isNarrow) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset(
            'assets/images/cineza_logo_transparent.png',
            height: isUltraNarrow ? 22 : 26,
            width: isUltraNarrow ? 22 : 26,
            fit: BoxFit.contain,
          ),
          SizedBox(width: isUltraNarrow ? 4 : 6),
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: isUltraNarrow ? 6 : 9,
              vertical: isUltraNarrow ? 3 : 5,
            ),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isDark
                    ? [const Color(0xFF18A0FB), const Color(0xFF0062FF)]
                    : [const Color(0xFF0062FF), const Color(0xFF38BDF8)],
              ),
              borderRadius: BorderRadius.circular(7),
              boxShadow: [
                BoxShadow(
                  color: activePrimary.withValues(alpha: 0.3),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Text(
              'CINEZA',
              style: TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: isUltraNarrow ? 12 : 13.5,
                letterSpacing: isUltraNarrow ? 0.8 : 1.4,
                color: Colors.white,
              ),
            ),
          ),
        ],
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Image.asset(
          'assets/images/cineza_logo_transparent.png',
          height: 30,
          width: 30,
          fit: BoxFit.contain,
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isDark
                  ? [const Color(0xFF18A0FB), const Color(0xFF0062FF)]
                  : [const Color(0xFF0062FF), const Color(0xFF38BDF8)],
            ),
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: activePrimary.withValues(alpha: 0.35),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          // React Bits: SplitBlurText – staggered blur-to-sharp letter reveal
          child: SplitBlurText(
            text: 'CINEZA',
            stagger: const Duration(milliseconds: 80),
            style: const TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 15,
              letterSpacing: 2.0,
              color: Colors.white,
            ),
          ),
        ),
        if (!isCompact) ...[
          const SizedBox(width: 8),
          Text(
            'CINEMAS',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 13.5,
              letterSpacing: 3.0,
              color: isDark ? AppTheme.getTextSecondary(isDark) : const Color(0xFF0A1B39),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildAccountAction(bool isDark, Color activePrimary, bool isCompact, bool isUltraNarrow) {
    return ValueListenableBuilder<CinezaUser?>(
      valueListenable: AuthService.currentUserNotifier,
      builder: (context, user, _) {
        if (user != null) {
          _syncUserProfileIfNeeded(user);
          final resolvedDisplayName = _getResolvedDisplayName(user);
          final displayFirstName = resolvedDisplayName.contains(' ')
              ? resolvedDisplayName.split(' ').first
              : resolvedDisplayName;

          return Container(
            margin: const EdgeInsets.symmetric(vertical: 6),
            decoration: BoxDecoration(
              color: isDark ? AppTheme.getSurfaceLight(isDark) : const Color(0xFFE8F1FC),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isDark ? AppTheme.getSurfaceBorder(isDark) : const Color(0xFFCFE0F8),
              ),
            ),
            child: PopupMenuButton<String>(
              tooltip: 'Account Options',
              offset: const Offset(0, 44),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(
                  color: isDark ? AppTheme.getSurfaceBorder(isDark) : const Color(0xFFCFE0F8),
                ),
              ),
              color: isDark ? AppTheme.darkSurface : Colors.white,
              onSelected: (value) async {
                if (value == 'logout') {
                  final messenger = ScaffoldMessenger.of(context);
                  await AuthService().signOut();
                  _handlePostLogoutReset();
                  if (mounted) {
                    messenger.hideCurrentSnackBar();
                    messenger.showSnackBar(
                      SnackBar(
                        content: const Row(
                          children: [
                            Icon(Icons.check_circle_outline_rounded, color: Colors.greenAccent, size: 20),
                            SizedBox(width: 10),
                            Text('Logged out. All location and session data has been erased.'),
                          ],
                        ),
                        behavior: SnackBarBehavior.floating,
                        duration: const Duration(seconds: 3),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        backgroundColor: isDark ? const Color(0xFF1E293B) : const Color(0xFF0F172A),
                      ),
                    );
                  }
                } else if (value == 'edit_username') {
                  _showEditUsernameDialog(context, user);
                }
              },
              itemBuilder: (context) => [
                PopupMenuItem(
                  enabled: false,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        resolvedDisplayName,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                      if (user.phoneNumber != null || user.email != null)
                        Text(
                          user.phoneNumber ?? user.email ?? '',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? AppTheme.getTextMuted(isDark) : Colors.black54,
                          ),
                        ),
                    ],
                  ),
                ),
                const PopupMenuDivider(),
                PopupMenuItem(
                  value: 'edit_username',
                  child: Row(
                    children: [
                      Icon(Icons.edit_rounded, size: 18, color: isDark ? AppTheme.goldAccent : activePrimary),
                      const SizedBox(width: 8),
                      Text(
                        'Change Username',
                        style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                      ),
                    ],
                  ),
                ),
                const PopupMenuDivider(),
                const PopupMenuItem(
                  value: 'logout',
                  child: Row(
                    children: [
                      Icon(Icons.logout_rounded, size: 18, color: Colors.redAccent),
                      SizedBox(width: 8),
                      Text('Sign Out', style: TextStyle(color: Colors.redAccent)),
                    ],
                  ),
                ),
              ],
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: isCompact ? 6 : 12,
                  vertical: isCompact ? 5 : 6,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.account_circle_rounded,
                      color: isDark ? AppTheme.goldAccent : const Color(0xFF0062FF),
                      size: isUltraNarrow ? 18 : 20,
                    ),
                    if (!isCompact) ...[
                      const SizedBox(width: 6),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 80),
                        child: Text(
                          displayFirstName,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white : const Color(0xFF0A1B39),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          );
        }

        return Container(
          margin: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(
            color: isDark ? AppTheme.getSurfaceLight(isDark) : const Color(0xFFE8F1FC),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isDark ? AppTheme.getSurfaceBorder(isDark) : const Color(0xFFCFE0F8),
            ),
          ),
          child: isCompact
              ? IconButton(
                  padding: const EdgeInsets.all(5),
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  visualDensity: VisualDensity.compact,
                  tooltip: 'Login',
                  icon: Icon(
                    Icons.login_rounded,
                    color: isDark ? AppTheme.goldAccent : const Color(0xFF0062FF),
                    size: 17,
                  ),
                  onPressed: () {
                    Navigator.pushNamed(context, '/login');
                  },
                )
              : TextButton.icon(
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    minimumSize: const Size(0, 36),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  icon: Icon(
                    Icons.login_rounded,
                    color: isDark ? AppTheme.goldAccent : const Color(0xFF0062FF),
                    size: 18,
                  ),
                  label: Text(
                    'Login',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : const Color(0xFF0A1B39),
                    ),
                  ),
                  onPressed: () {
                    Navigator.pushNamed(context, '/login');
                  },
                ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isCompact = screenWidth < 1080;
    final isNarrow = screenWidth < 780;
    final isUltraNarrow = screenWidth < 520;

    return ValueListenableBuilder<ThemeMode>(
      valueListenable: ThemeController.themeMode,
      builder: (context, currentMode, _) {
        final isDark = currentMode == ThemeMode.dark;
        final activePrimary = AppTheme.getPrimary(isDark);

        return Scaffold(
          backgroundColor: AppTheme.getBackground(isDark),
          appBar: PreferredSize(
            preferredSize: const Size.fromHeight(60),
            child: Container(
              height: 60,
              decoration: BoxDecoration(
                color: AppTheme.getSurface(isDark),
                border: Border(
                  bottom: BorderSide(
                    color: isDark ? AppTheme.getSurfaceBorder(isDark) : const Color(0xFFCFE0F8),
                    width: 1,
                  ),
                ),
                boxShadow: isDark
                    ? null
                    : [
                        BoxShadow(
                          color: const Color(0xFF0062FF).withValues(alpha: 0.06),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
              ),
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: isUltraNarrow ? 8 : (isNarrow ? 12 : 20),
                  ),
                  child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minWidth: (screenWidth - (isUltraNarrow ? 16 : (isNarrow ? 24 : 40))).clamp(0.0, double.infinity),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // 1. BRAND LOGO (Left side) - Flexible with FittedBox for zoom resilience
                        Flexible(
                          flex: isNarrow ? 1 : 0,
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: _buildHeaderLogo(isDark, activePrimary, isCompact, isNarrow, isUltraNarrow),
                          ),
                        ),

                        // 2. SEARCH BAR (Center) - Only on wide desktop (>= 780px)
                        if (!isNarrow) ...[
                          const SizedBox(width: 16),
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 540, minWidth: 200),
                            child: _buildSearchBar(isDark, activePrimary),
                          ),
                          const SizedBox(width: 16),
                        ],

                        // 3. ACTIONS ROW (Right side) - Flexible with FittedBox for zoom resilience
                        Flexible(
                          flex: 0,
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerRight,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _buildAccountAction(isDark, activePrimary, isCompact, isUltraNarrow),
                                SizedBox(width: isUltraNarrow ? 4 : (isCompact ? 6 : 8)),
                                CinezaThemeToggle(compact: isCompact),
                                SizedBox(width: isUltraNarrow ? 4 : (isCompact ? 6 : 8)),
                                _buildLocationBar(isDark, activePrimary, compact: isCompact, ultraCompact: isUltraNarrow),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                ),
              ),
            ),
          ),
          body: _isLoading
              ? Center(
                  child: CircularProgressIndicator(color: activePrimary),
                )
              : RefreshIndicator(
                  onRefresh: _filterMovies,
                  color: activePrimary,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (isNarrow)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                            child: _buildSearchBar(isDark, activePrimary),
                          ),

                        const SizedBox(height: 16),

                    // Genre Pills
                    SizedBox(
                      height: 48,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        itemCount: _genres.length,
                        separatorBuilder: (_, _) => const SizedBox(width: 8),
                        itemBuilder: (context, index) {
                          final genre = _genres[index];
                          final isSelected = genre == _selectedGenre;
                          return ChoiceChip(
                            label: Text(genre),
                            selected: isSelected,
                            onSelected: (selected) {
                              setState(() => _selectedGenre = genre);
                              _filterMovies();
                            },
                            selectedColor: activePrimary,
                            backgroundColor: AppTheme.getSurfaceLight(isDark),
                            labelStyle: TextStyle(
                              color: isSelected
                                  ? (isDark ? Colors.black : Colors.white)
                                  : AppTheme.getTextSecondary(isDark),
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                              fontSize: 13,
                            ),
                            side: BorderSide(
                              color: isSelected
                                  ? activePrimary
                                  : AppTheme.getSurfaceBorder(isDark),
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                          );
                        },
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Featured Marquee Hero Billboard (Inspo Marquee Archetype)
                    _buildFeaturedMarqueeHero(isDark, activePrimary, isNarrow),

                    const SizedBox(height: 20),

                    // Trust & Perks Highlight Strip
                    _buildPerksStrip(isDark, activePrimary),

                    const SizedBox(height: 28),

                    // Gift Vouchers Section
                    _buildGiftVouchersSection(isDark, activePrimary),

                    const SizedBox(height: 28),

                    // Now Showing Title
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Flexible(
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
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
                                Flexible(
                                  child: Text(
                                    'Now Showing',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: -0.5,
                                      color: AppTheme.getTextPrimary(isDark),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '${_movies.length} Movies Available',
                            style: TextStyle(
                              fontSize: 13,
                              color: AppTheme.getTextMuted(isDark),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Movie Grid or Empty State
                    if (_movies.isEmpty)
                      _buildEmptyState(isDark, activePrimary)
                    else
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            final crossAxisCount = constraints.maxWidth > 900
                                ? 4
                                : constraints.maxWidth > 600
                                    ? 3
                                    : constraints.maxWidth > 350
                                        ? 2
                                        : 1;

                            return GridView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: _movies.length,
                              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: crossAxisCount,
                                childAspectRatio: 0.54,
                                crossAxisSpacing: 16,
                                mainAxisSpacing: 20,
                              ),
                              itemBuilder: (context, index) {
                                return _buildMovieCard(_movies[index], isDark, activePrimary);
                              },
                            );
                          },
                        ),
                      ),

                    const SizedBox(height: 30),

                    // Legal & Brand Footer
                    _buildFooter(isDark, activePrimary),
                  ],
                ),
              ),
            ),
        );
      },
    );
  }

  Widget _buildFeaturedMarqueeHero(bool isDark, Color activePrimary, bool isNarrow) {
    final featuredMovies = _movies.isNotEmpty
        ? _movies.take(4).toList()
        : ApiService.fallbackMovies.take(4).toList();

    if (featuredMovies.isEmpty) return const SizedBox.shrink();

    final heroHeight = isNarrow ? 310.0 : 360.0;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      height: heroHeight,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark ? AppTheme.getSurfaceBorder(isDark) : const Color(0xFFCFE0F8),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.55 : 0.12),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          children: [
            // PageView of Featured Blockbusters
            PageView.builder(
              controller: _marqueePageController,
              itemCount: featuredMovies.length,
              onPageChanged: (index) {
                setState(() => _currentMarqueeIndex = index);
              },
              itemBuilder: (context, index) {
                final movie = featuredMovies[index];
                final backdropUrl = movie.resolvedBackdropUrl;

                return Stack(
                  fit: StackFit.expand,
                  children: [
                    // Backdrop Image
                    _buildImageWidget(
                      backdropUrl,
                      isDark: isDark,
                      fit: BoxFit.cover,
                      logoSize: 100,
                    ),

                    // Atmospheric Particle Overlay
                    const ParticleOverlay(
                      count: 20,
                      color: Colors.white,
                      child: SizedBox.expand(),
                    ),

                    // Multi-layer Dark Gradient for high legibility
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: [
                            const Color(0xFF0A0C12).withValues(alpha: 0.98),
                            const Color(0xFF0A0C12).withValues(alpha: 0.70),
                            const Color(0xFF0A0C12).withValues(alpha: 0.25),
                            Colors.transparent,
                          ],
                          stops: const [0.0, 0.45, 0.75, 1.0],
                        ),
                      ),
                    ),
                    // Left horizontal vignette so text has solid contrast
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                          colors: [
                            const Color(0xFF0A0C12).withValues(alpha: 0.92),
                            const Color(0xFF0A0C12).withValues(alpha: 0.55),
                            Colors.transparent,
                          ],
                          stops: const [0.0, 0.55, 1.0],
                        ),
                      ),
                    ),

                    // Content Container
                    Positioned.fill(
                      child: Padding(
                        padding: EdgeInsets.all(isNarrow ? 18.0 : 28.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            // Eyebrow Premiere Chip
                            Wrap(
                              spacing: 8,
                              runSpacing: 6,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: AppTheme.goldAccent.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: AppTheme.goldAccent.withValues(alpha: 0.7),
                                      width: 1,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: AppTheme.goldAccent.withValues(alpha: 0.25),
                                        blurRadius: 8,
                                      ),
                                    ],
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.local_fire_department_rounded, color: AppTheme.goldAccent, size: 14),
                                      SizedBox(width: 5),
                                      Text(
                                        'SPOTLIGHT PREMIERE',
                                        style: TextStyle(
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.w900,
                                          letterSpacing: 1.0,
                                          color: AppTheme.goldAccent,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(color: Colors.white24, width: 0.8),
                                  ),
                                  child: const Text(
                                    'IMAX 3D & 4DX',
                                    style: TextStyle(
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 0.5,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),

                            // Movie Title
                            Text(
                              movie.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTheme.argentHeading(
                                fontSize: isNarrow ? 24 : 32,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                                letterSpacing: -0.5,
                              ),
                            ),
                            const SizedBox(height: 8),

                            // Metadata Badges (Rating, Certificate, Duration, Genre)
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
                                      const Icon(Icons.star_rounded, size: 13, color: Colors.black),
                                      const SizedBox(width: 3),
                                      Text(
                                        movie.imdbScore.toStringAsFixed(1),
                                        style: const TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w900,
                                          color: Colors.black,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(color: Colors.white38),
                                  ),
                                  child: Text(
                                    movie.rating,
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                                ConstrainedBox(
                                  constraints: const BoxConstraints(maxWidth: 320),
                                  child: Text(
                                    '• ${movie.durationFormatted} • ${movie.genre} • ${movie.language}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w500,
                                      color: Color(0xFFE2E8F0),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),

                            // Synopsis snippet
                            if (!isNarrow) ...[
                              ConstrainedBox(
                                constraints: const BoxConstraints(maxWidth: 580),
                                child: Text(
                                  movie.synopsis,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    height: 1.4,
                                    color: Color(0xFFCBD5E1),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),
                            ] else ...[
                              const SizedBox(height: 8),
                            ],

                            // CTAs Row
                            Wrap(
                              spacing: 12,
                              runSpacing: 10,
                              children: [
                                ElevatedButton.icon(
                                  onPressed: () {
                                    Navigator.pushNamed(
                                      context,
                                      '/movie-details',
                                      arguments: {
                                        'movie': movie,
                                        'city': _selectedCity,
                                      },
                                    );
                                  },
                                  icon: const Icon(Icons.confirmation_num_rounded, size: 16),
                                  label: const Text('Book Tickets'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: activePrimary,
                                    foregroundColor: Colors.white,
                                    elevation: 6,
                                    shadowColor: activePrimary.withValues(alpha: 0.5),
                                    padding: EdgeInsets.symmetric(
                                      horizontal: isNarrow ? 16 : 22,
                                      vertical: isNarrow ? 10 : 13,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    textStyle: const TextStyle(
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 0.3,
                                    ),
                                  ),
                                ),
                                OutlinedButton.icon(
                                  onPressed: () {
                                    Navigator.pushNamed(
                                      context,
                                      '/movie-details',
                                      arguments: {
                                        'movie': movie,
                                        'city': _selectedCity,
                                      },
                                    );
                                  },
                                  icon: const Icon(Icons.info_outline_rounded, size: 16, color: Colors.white),
                                  label: const Text(
                                    'Details & Cast',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white,
                                    ),
                                  ),
                                  style: OutlinedButton.styleFrom(
                                    side: const BorderSide(color: Colors.white38, width: 1.2),
                                    backgroundColor: Colors.black.withValues(alpha: 0.35),
                                    padding: EdgeInsets.symmetric(
                                      horizontal: isNarrow ? 14 : 18,
                                      vertical: isNarrow ? 10 : 13,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),

            // Pagination Dots (Bottom Right)
            Positioned(
              bottom: 16,
              right: 20,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(featuredMovies.length, (index) {
                  final isCurrent = index == _currentMarqueeIndex;
                  return GestureDetector(
                    onTap: () {
                      _marqueePageController.animateToPage(
                        index,
                        duration: const Duration(milliseconds: 400),
                        curve: Curves.easeInOut,
                      );
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      width: isCurrent ? 24 : 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: isCurrent ? activePrimary : Colors.white38,
                        borderRadius: BorderRadius.circular(4),
                        boxShadow: isCurrent
                            ? [
                                BoxShadow(
                                  color: activePrimary.withValues(alpha: 0.6),
                                  blurRadius: 6,
                                ),
                              ]
                            : null,
                      ),
                    ),
                  );
                }),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPerksStrip(bool isDark, Color activePrimary) {
    final perks = [
      {
        'icon': Icons.lock_clock_rounded,
        'title': '10-Min Seat Lock',
        'desc': 'Zero double-booking via Redis lock',
        'color': const Color(0xFFF59E0B),
      },
      {
        'icon': Icons.qr_code_2_rounded,
        'title': 'Instant M-Ticket',
        'desc': 'Contactless QR gate entry',
        'color': const Color(0xFF10B981),
      },
      {
        'icon': Icons.fastfood_rounded,
        'title': 'Seat Concessions',
        'desc': 'Hot snacks delivered to your seat',
        'color': const Color(0xFF38BDF8),
      },
      {
        'icon': Icons.verified_user_rounded,
        'title': '100% Refundable',
        'desc': 'Hassle-free cancellation guarantee',
        'color': const Color(0xFF8B5CF6),
      },
    ];

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppTheme.getSurface(isDark),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppTheme.getSurfaceBorder(isDark) : const Color(0xFFCFE0F8),
        ),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isNarrow = constraints.maxWidth < 680;
          if (isNarrow) {
            return SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: perks.map((p) {
                  final color = p['color'] as Color;
                  return Padding(
                    padding: const EdgeInsets.only(right: 20),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(7),
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: isDark ? 0.2 : 0.12),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(p['icon'] as IconData, size: 16, color: color),
                        ),
                        const SizedBox(width: 8),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              p['title'] as String,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.getTextPrimary(isDark),
                              ),
                            ),
                            Text(
                              p['desc'] as String,
                              style: TextStyle(
                                fontSize: 10.5,
                                color: AppTheme.getTextMuted(isDark),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            );
          }

          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: perks.map((p) {
              final color = p['color'] as Color;
              return Expanded(
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: isDark ? 0.2 : 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(p['icon'] as IconData, size: 18, color: color),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            p['title'] as String,
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.getTextPrimary(isDark),
                            ),
                          ),
                          Text(
                            p['desc'] as String,
                            style: TextStyle(
                              fontSize: 11,
                              color: AppTheme.getTextMuted(isDark),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          );
        },
      ),
    );
  }

  Widget _buildEmptyState(bool isDark, Color activePrimary) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      padding: const EdgeInsets.all(36),
      decoration: BoxDecoration(
        color: AppTheme.getSurface(isDark),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.getSurfaceBorder(isDark)),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: activePrimary.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.movie_filter_outlined, size: 48, color: activePrimary),
            ),
            const SizedBox(height: 18),
            Text(
              'No movies found',
              style: AppTheme.argentHeading(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppTheme.getTextPrimary(isDark),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              _searchController.text.isNotEmpty
                  ? 'No titles matched "${_searchController.text.trim()}". Try searching for "Action", "Sci-Fi", or "KGF".'
                  : 'No movies currently scheduled for this genre. Select another category.',
              style: TextStyle(
                fontSize: 13,
                color: AppTheme.getTextMuted(isDark),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () {
                setState(() {
                  _selectedGenre = 'All';
                  _searchController.clear();
                });
                _filterMovies();
              },
              icon: const Icon(Icons.restart_alt_rounded, size: 18),
              label: const Text('Reset All Filters'),
              style: ElevatedButton.styleFrom(
                backgroundColor: activePrimary,
                foregroundColor: isDark ? Colors.black : Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMovieCard(Movie movie, bool isDark, Color activePrimary) {
    return GestureDetector(
      onTap: () {
        Navigator.pushNamed(
          context,
          '/movie-details',
          arguments: {
            'movie': movie,
            'city': _selectedCity,
          },
        );
      },
      // React Bits: TiltedCard - 3D perspective tilt on hover
      child: TiltedCard(
        maxTilt: 6.0,
        scale: 1.03,
        child: SpotlightCard(
          spotColor: activePrimary,
          spotRadius: 100,
          spotOpacity: 0.15,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            decoration: BoxDecoration(
              color: AppTheme.getSurface(isDark),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.getSurfaceBorder(isDark)),
              boxShadow: isDark
                  ? null
                  : [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Poster
                Expanded(
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      _buildImageWidget(
                        movie.resolvedPosterUrl,
                        isDark: isDark,
                        fit: BoxFit.cover,
                        logoSize: 50,
                      ),
                      // Top Left: Star rating badge with amber gold pill
                      Positioned(
                        top: 8,
                        left: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3.5),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0F1117).withValues(alpha: 0.85),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: AppTheme.goldAccent.withValues(alpha: 0.6),
                              width: 1,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.4),
                                blurRadius: 4,
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.star_rounded, size: 13, color: AppTheme.goldAccent),
                              const SizedBox(width: 3),
                              Text(
                                movie.imdbScore.toStringAsFixed(1),
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      // Top Right: Cinema format tag
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3.5),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF0284C7), Color(0xFF0062FF)],
                            ),
                            borderRadius: BorderRadius.circular(8),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF0062FF).withValues(alpha: 0.35),
                                blurRadius: 6,
                              ),
                            ],
                          ),
                          child: const Text(
                            'IMAX 2D',
                            style: TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.5,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                      // Bottom Left: Language & Censor tag
                      Positioned(
                        bottom: 8,
                        left: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.75),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: Colors.white24, width: 0.8),
                          ),
                          child: Text(
                            '${movie.language.toUpperCase()} • ${movie.rating}',
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.3,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Movie Info & Action Button
                Padding(
                  padding: const EdgeInsets.all(10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // React Bits: ShinyText – sweeping light sheen on movie title
                      ShinyText(
                        text: movie.title,
                        shineColor: Colors.white,
                        period: const Duration(seconds: 4),
                        style: AppTheme.argentHeading(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: AppTheme.getTextPrimary(isDark),
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${movie.genre} • ${movie.durationFormatted}',
                        style: TextStyle(
                          color: AppTheme.getTextSecondary(isDark),
                          fontSize: 11.5,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      // Dedicated "Book Tickets" gradient action button
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 7),
                        decoration: BoxDecoration(
                          gradient: isDark
                              ? AppTheme.cobaltActionGradient
                              : const LinearGradient(colors: [Color(0xFF0062FF), Color(0xFF1D4ED8)]),
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: [
                            BoxShadow(
                              color: activePrimary.withValues(alpha: isDark ? 0.3 : 0.2),
                              blurRadius: 5,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.confirmation_num_rounded, size: 13, color: Colors.white),
                            SizedBox(width: 5),
                            Text(
                              'Book Tickets',
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.3,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGiftVouchersSection(bool isDark, Color activePrimary) {
    final vouchers = [
      {
        'title': 'Movie Buff Pass',
        'subtitle': 'Save 25% on IMAX & 4DX',
        'price': '\$50',
        'code': 'BUFF25',
        'image': 'assets/images/movie_buff_pass.jpg',
        'blur': 3.5,
        'gradient': [const Color(0xFF6366F1), const Color(0xFFA855F7)],
        'icon': Icons.local_activity_rounded,
      },
      {
        'title': 'Weekend Escape',
        'subtitle': 'Free Large Popcorn Included',
        'price': '\$30',
        'code': 'WEEKEND30',
        'image': 'assets/images/weekend_escape.jpg',
        'blur': 3.5,
        'gradient': [const Color(0xFF06B6D4), const Color(0xFF3B82F6)],
        'icon': Icons.fastfood_rounded,
      },
      {
        'title': 'VIP Recliner Pass',
        'subtitle': '4 VIP Tickets + Lounge Access',
        'price': '\$100',
        'code': 'VIPLUX100',
        'image': 'assets/images/vip_recliner_pass.jpg',
        'blur': 3.5,
        'gradient': [const Color(0xFFFFB800), const Color(0xFFEF4444)],
        'icon': Icons.chair_rounded,
      },
      {
        'title': 'Birthday Special',
        'subtitle': 'Custom Greeting & Snacks',
        'price': '\$75',
        'code': 'BDAY75',
        'image': 'assets/images/birthday_special.jpg',
        'blur': 3.5,
        'gradient': [const Color(0xFF10B981), const Color(0xFF06B6D4)],
        'icon': Icons.card_giftcard_rounded,
      },
      {
        'title': 'Annual Cinephile',
        'subtitle': 'Unlimited Standard Pass',
        'price': '\$200',
        'code': 'YEAR200',
        'image': 'assets/images/annual_cinephile.jpg',
        'blur': 3.5,
        'gradient': [const Color(0xFF8B5CF6), const Color(0xFFEC4899)],
        'icon': Icons.movie_filter_rounded,
      },
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 4,
                      height: 20,
                      decoration: BoxDecoration(
                        color: AppTheme.goldAccent,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        'Exclusive Gift Vouchers',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          letterSpacing: -0.5,
                          color: AppTheme.getTextPrimary(isDark),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Instant Delivery',
                style: TextStyle(
                  fontSize: 13,
                  color: AppTheme.getTextMuted(isDark),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        SizedBox(
          height: 145,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: vouchers.length,
            separatorBuilder: (_, index) => const SizedBox(width: 14),
            itemBuilder: (context, index) {
              final v = vouchers[index];
              final imageAsset = v['image'] as String?;
              final hasImage = imageAsset != null;
              final blur = (v['blur'] as double?) ?? 0.0;
              final gradientColors = v['gradient'] as List<Color>;
              return Container(
                width: 260,
                decoration: BoxDecoration(
                  gradient: hasImage
                      ? null
                      : LinearGradient(
                          colors: gradientColors,
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: (hasImage ? Colors.black : gradientColors.first).withValues(alpha: 0.35),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                clipBehavior: Clip.antiAlias,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // Background Image with adjustable blur
                    if (hasImage)
                      Positioned.fill(
                        child: blur > 0
                            ? ImageFiltered(
                                imageFilter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
                                child: Image.asset(
                                  imageAsset,
                                  fit: BoxFit.cover,
                                ),
                              )
                            : Image.asset(
                                imageAsset,
                                fit: BoxFit.cover,
                              ),
                      ),

                    // Darkening gradient overlay for high contrast and readability
                    Positioned.fill(
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: hasImage                              ? LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    Colors.black.withValues(alpha: 0.35),
                                    Colors.black.withValues(alpha: 0.75),
                                  ],
                                )
                              : null,
                        ),
                      ),
                    ),

                    // Card Foreground Content (stays 100% crisp and readable)
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(v['icon'] as IconData, color: Colors.white, size: 20),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.3),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            v['price'] as String,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          v['title'] as String,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          v['subtitle'] as String,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Code: ${v['code']}',
                          style: const TextStyle(
                            color: Colors.white60,
                            fontSize: 10,
                            fontFamily: 'monospace',
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        GestureDetector(
                          onTap: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Gift Voucher "${v['title']}" selected! Code: ${v['code']}'),
                                backgroundColor: activePrimary,
                                duration: const Duration(seconds: 2),
                              ),
                            );
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              'Claim',
                              style: TextStyle(
                                color: Colors.black,
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
            },
          ),
        ),
      ],
    );
  }

  // --- FOOTER WITH TERMS & PRIVACY LINKS ---

  Widget _buildFooter(bool isDark, Color activePrimary) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurface : const Color(0xFFF1F5F9),
        border: Border(
          top: BorderSide(
            color: isDark ? AppTheme.darkSurfaceBorder : const Color(0xFFE2E8F0),
            width: 1,
          ),
        ),
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1040),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Image.asset(
                    'assets/images/cineza_logo_transparent.png',
                    height: 24,
                    fit: BoxFit.contain,
                    errorBuilder: (_, _, _) => Icon(
                      Icons.confirmation_number_rounded,
                      color: activePrimary,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'CINEZA CINEMAS',
                    style: TextStyle(
                      fontFamily: 'PlusJakartaSans',
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                      letterSpacing: 0.8,
                      color: AppTheme.getTextPrimary(isDark),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                'Next-Gen Cinematic Ticketing • High-Concurrency 10-Min Distributed Redis Seat Locks',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  color: AppTheme.getTextMuted(isDark),
                ),
              ),
              const SizedBox(height: 14),
              Wrap(
                alignment: WrapAlignment.center,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 14,
                runSpacing: 8,
                children: [
                  InkWell(
                    onTap: () => Navigator.pushNamed(context, '/terms-policy', arguments: 0),
                    borderRadius: BorderRadius.circular(6),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                      child: Text(
                        'Terms of Service',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: activePrimary,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                  ),
                  Text(
                    '•',
                    style: TextStyle(color: AppTheme.getTextMuted(isDark)),
                  ),
                  InkWell(
                    onTap: () => Navigator.pushNamed(context, '/terms-policy', arguments: 1),
                    borderRadius: BorderRadius.circular(6),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                      child: Text(
                        'Privacy Policy',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: activePrimary,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                '© 2026 Cineza Entertainment Technologies Pvt. Ltd. All Rights Reserved.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11,
                  color: AppTheme.getTextMuted(isDark).withValues(alpha: 0.8),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- INTERACTIVE LOCATION BAR (REGION DISCOVERY) ---

  Widget _buildLocationBar(bool isDark, Color activePrimary, {bool compact = false, bool ultraCompact = false}) {
    final hasCity = _selectedCity != null;
    final cityName = hasCity ? _selectedCity!.name : 'LOCATION';
    final stateName = hasCity ? _selectedCity!.state : 'Select City';

    final buttonDecoration = BoxDecoration(
      color: hasCity
          ? (isDark ? AppTheme.getSurfaceLight(isDark) : const Color(0xFFE8F1FC))
          : (isDark ? const Color(0xFF0F172A) : const Color(0xFFE0F2FE)),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(
        color: hasCity
            ? (isDark ? AppTheme.getSurfaceBorder(isDark) : const Color(0xFFCFE0F8))
            : activePrimary,
        width: hasCity ? 1.0 : 1.8,
      ),
      boxShadow: [
        BoxShadow(
          color: activePrimary.withValues(alpha: hasCity ? (isDark ? 0.15 : 0.08) : 0.35),
          blurRadius: hasCity ? 8 : 12,
          spreadRadius: hasCity ? 0 : 1.0,
          offset: const Offset(0, 2),
        ),
      ],
    );

    final locationButton = Tooltip(
      message: hasCity
          ? 'Region Discovery: $cityName, $stateName (Click to change)'
          : 'Location: Not selected (Click to set location)',
      child: AnimatedBuilder(
        animation: _locationPulseAnimation,
        builder: (context, child) {
          final scale = hasCity ? 1.0 : _locationPulseAnimation.value;
          return Transform.scale(
            scale: scale,
            child: child,
          );
        },
        child: Container(
          margin: EdgeInsets.only(right: ultraCompact ? 2 : (compact ? 6 : 16), top: 7, bottom: 7),
          decoration: buttonDecoration,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: _openLocationSelector,
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: ultraCompact ? 6 : (compact ? 8 : 12), vertical: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Glowing Pin / GPS Icon with pulse indicator
                    Container(
                      padding: const EdgeInsets.all(5),
                      decoration: BoxDecoration(
                        color: activePrimary.withValues(alpha: hasCity ? (isDark ? 0.2 : 0.12) : 0.25),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.near_me_rounded,
                        color: activePrimary,
                        size: 14,
                      ),
                    ),

                    if (!ultraCompact) ...[
                      const SizedBox(width: 6),
                      if (compact) ...[
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 85),
                          child: Text(
                            cityName,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              letterSpacing: hasCity ? 0 : 0.6,
                              color: hasCity ? AppTheme.getTextPrimary(isDark) : activePrimary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ] else ...[
                        Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  hasCity ? 'REGION DISCOVERY' : 'LOCATION',
                                  style: TextStyle(
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 0.8,
                                    color: hasCity
                                        ? (isDark ? AppTheme.getTextMuted(isDark) : const Color(0xFF64748B))
                                        : activePrimary,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Container(
                                  width: 5,
                                  height: 5,
                                  decoration: BoxDecoration(
                                    color: activePrimary,
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: activePrimary.withValues(alpha: 0.6),
                                        blurRadius: 4,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 130),
                              child: Text(
                                hasCity ? '$cityName, $stateName' : 'Choose Location',
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w800,
                                  color: hasCity
                                      ? AppTheme.getTextPrimary(isDark)
                                      : (isDark ? Colors.white : const Color(0xFF0F172A)),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                    if (!ultraCompact) ...[
                      const SizedBox(width: 3),
                      Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: hasCity
                            ? (isDark ? AppTheme.getTextMuted(isDark) : const Color(0xFF64748B))
                            : activePrimary,
                        size: 15,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );

    return CompositedTransformTarget(
      link: _locationLayerLink,
      child: OverlayPortal(
        controller: _locationPopupController,
        overlayChildBuilder: (context) {
          if (_selectedCity != null) return const SizedBox.shrink();
          return CompositedTransformFollower(
            link: _locationLayerLink,
            showWhenUnlinked: false,
            targetAnchor: Alignment.bottomRight,
            followerAnchor: Alignment.topRight,
            offset: const Offset(0, 6),
            child: Align(
              alignment: Alignment.topRight,
              child: Material(
                color: Colors.transparent,
                child: _buildLocationPopoverBubble(isDark, activePrimary),
              ),
            ),
          );
        },
        child: locationButton,
      ),
    );
  }

  /// Anchored Callout Bubble attached directly below the LOCATION button
  Widget _buildLocationPopoverBubble(bool isDark, Color activePrimary) {
    return Container(
      width: 275,
      margin: const EdgeInsets.only(right: 6),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Upward pointing arrow caret pointing directly into the location button
          Padding(
            padding: const EdgeInsets.only(right: 36),
            child: CustomPaint(
              size: const Size(14, 8),
              painter: _PopoverCaretPainter(
                color: isDark ? const Color(0xFF0F172A) : Colors.white,
                borderColor: activePrimary,
              ),
            ),
          ),
          // Main callout bubble card
          Container(
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0F172A) : Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: activePrimary, width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: activePrimary.withValues(alpha: isDark ? 0.35 : 0.2),
                  blurRadius: 18,
                  spreadRadius: 1,
                  offset: const Offset(0, 4),
                ),
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.5 : 0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {
                  _locationPopupController.hide();
                  _openLocationSelector();
                },
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(5),
                            decoration: BoxDecoration(
                              color: activePrimary.withValues(alpha: 0.15),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(Icons.near_me_rounded, color: activePrimary, size: 15),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Choose a Location',
                              style: AppTheme.argentHeading(
                                fontSize: 13.5,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white : const Color(0xFF0F172A),
                              ),
                            ),
                          ),
                          InkWell(
                            onTap: () => _locationPopupController.hide(),
                            borderRadius: BorderRadius.circular(12),
                            child: Padding(
                              padding: const EdgeInsets.all(4),
                              child: Icon(
                                Icons.close_rounded,
                                size: 16,
                                color: isDark ? Colors.white54 : Colors.black45,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Select your city to explore real local theatres and showtimes.',
                        style: TextStyle(
                          fontSize: 11.5,
                          height: 1.35,
                          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Upward pointer caret for the location popover bubble
class _PopoverCaretPainter extends CustomPainter {
  final Color color;
  final Color borderColor;

  const _PopoverCaretPainter({required this.color, required this.borderColor});

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(size.width / 2, 0)
      ..lineTo(size.width, size.height + 1)
      ..lineTo(0, size.height + 1)
      ..close();

    final fillPaint = Paint()..color = color;
    canvas.drawPath(path, fillPaint);

    final borderPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    final borderPath = Path()
      ..moveTo(0, size.height)
      ..lineTo(size.width / 2, 0)
      ..lineTo(size.width, size.height);

    canvas.drawPath(borderPath, borderPaint);
  }

  @override
  bool shouldRepaint(covariant _PopoverCaretPainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.borderColor != borderColor;
  }
}

