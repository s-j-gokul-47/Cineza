import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/city.dart';
import '../models/movie.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import 'location_selector_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ApiService _apiService = ApiService();

  List<City> _cities = [];
  City? _selectedCity;
  List<Movie> _movies = [];
  bool _isLoading = true;
  String _selectedGenre = 'All';
  final TextEditingController _searchController = TextEditingController();

  final List<String> _genres = ['All', 'Sci-Fi', 'Action', 'Biography', 'Animation'];

  bool _isSyncingUser = false;

  /// Resolves the user's display name from Firebase, Google provider data, or email/phone fallback
  String _getResolvedDisplayName(User user) {
    if (user.displayName != null &&
        user.displayName!.trim().isNotEmpty &&
        user.displayName != 'Cineza User') {
      return user.displayName!.trim();
    }
    // Check providerData (e.g. Google profile)
    for (final info in user.providerData) {
      if (info.displayName != null && info.displayName!.trim().isNotEmpty) {
        return info.displayName!.trim();
      }
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
  void _syncUserProfileIfNeeded(User user) {
    if (_isSyncingUser) return;
    if (user.displayName == null ||
        user.displayName!.trim().isEmpty ||
        user.displayName == 'Cineza User') {
      _isSyncingUser = true;
      AuthService().resolveAndSyncUser(user).then((resolvedName) {
        _isSyncingUser = false;
        if (mounted && resolvedName != 'Cineza User') {
          setState(() {});
        }
      }).catchError((_) {
        _isSyncingUser = false;
      });
    }
  }

  /// Dialog to edit or update the username anytime
  void _showEditUsernameDialog(BuildContext context, User user) {
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


  @override
  void initState() {
    super.initState();
    ThemeController.themeMode.addListener(_onThemeChanged);
    _loadInitialData();
  }

  void _onThemeChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _loadInitialData() async {
    setState(() => _isLoading = true);
    final cities = await _apiService.getCities();
    final selected = cities.isNotEmpty ? cities.first : null;
    final movies = await _apiService.getMovies(
      cityId: selected?.id,
      genre: _selectedGenre,
    );

    if (mounted) {
      setState(() {
        _cities = cities;
        _selectedCity = selected;
        _movies = movies;
        _isLoading = false;
      });
    }
  }

  Future<void> _filterMovies() async {
    setState(() => _isLoading = true);
    final movies = await _apiService.getMovies(
      cityId: _selectedCity?.id,
      search: _searchController.text.trim(),
      genre: _selectedGenre,
    );
    if (mounted) {
      setState(() {
        _movies = movies;
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    ThemeController.themeMode.removeListener(_onThemeChanged);
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: ThemeController.themeMode,
      builder: (context, currentMode, _) {
        final isDark = currentMode == ThemeMode.dark;
        final activePrimary = AppTheme.getPrimary(isDark);

        return Scaffold(
          backgroundColor: AppTheme.getBackground(isDark),
          appBar: AppBar(
            backgroundColor: AppTheme.getSurface(isDark),
            elevation: isDark ? 0 : 1,
            shadowColor: isDark ? null : const Color(0xFF0062FF).withValues(alpha: 0.08),
            titleSpacing: 20,
            title: Row(
              children: [
                // Brand Logo with Cineza Ticket Icon
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Image.asset(
                      'assets/images/cineza_logo_transparent.png',
                      height: 32,
                      width: 32,
                      fit: BoxFit.contain,
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: isDark
                              ? [activePrimary, AppTheme.accent]
                              : [const Color(0xFF0062FF), const Color(0xFF00C8FF)],
                        ),
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: [
                          BoxShadow(
                            color: (isDark ? activePrimary : const Color(0xFF0062FF)).withValues(alpha: 0.35),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Text(
                        'CINEZA',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                          letterSpacing: 2.0,
                          color: isDark ? Colors.black : Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'CINEMAS',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        letterSpacing: 3.0,
                        color: isDark ? AppTheme.getTextSecondary(isDark) : const Color(0xFF0A1B39),
                      ),
                    ),
                  ],
                ),

                const SizedBox(width: 24),

                // Search Bar located between "CINEMAS" and City Selector
                Expanded(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 560),
                      child: SizedBox(
                        height: 42,
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
                      ),
                    ),
                  ),
                ),

                const SizedBox(width: 16),
              ],
            ),
            actions: [
              // Login / Account Button (Left of Theme Icon)
              StreamBuilder<User?>(
                stream: FirebaseAuth.instance.authStateChanges(),
                builder: (context, snapshot) {
                  final user = snapshot.data;
                  if (user != null) {
                    _syncUserProfileIfNeeded(user);
                    final resolvedDisplayName = _getResolvedDisplayName(user);
                    final displayFirstName = resolvedDisplayName.contains(' ')
                        ? resolvedDisplayName.split(' ').first
                        : resolvedDisplayName;

                    return Container(
                      margin: const EdgeInsets.symmetric(vertical: 8),
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
                            await AuthService().signOut();
                          } else if (value == 'edit_username') {
                            _showEditUsernameDialog(context, user);
                          } else if (value == 'terms') {
                            Navigator.pushNamed(context, '/terms-policy', arguments: 0);
                          } else if (value == 'privacy') {
                            Navigator.pushNamed(context, '/terms-policy', arguments: 1);
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
                          PopupMenuItem(
                            value: 'terms',
                            child: Row(
                              children: [
                                Icon(Icons.gavel_rounded, size: 18, color: isDark ? AppTheme.goldAccent : activePrimary),
                                const SizedBox(width: 8),
                                Text(
                                  'Terms of Service',
                                  style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                                ),
                              ],
                            ),
                          ),
                          PopupMenuItem(
                            value: 'privacy',
                            child: Row(
                              children: [
                                Icon(Icons.shield_outlined, size: 18, color: isDark ? AppTheme.goldAccent : activePrimary),
                                const SizedBox(width: 8),
                                Text(
                                  'Privacy Policy',
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
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.account_circle_rounded,
                                color: isDark ? AppTheme.goldAccent : const Color(0xFF0062FF),
                                size: 18,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                displayFirstName,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? Colors.white : const Color(0xFF0A1B39),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }

                  return Container(
                    margin: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: isDark ? AppTheme.getSurfaceLight(isDark) : const Color(0xFFE8F1FC),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isDark ? AppTheme.getSurfaceBorder(isDark) : const Color(0xFFCFE0F8),
                      ),
                    ),
                    child: TextButton.icon(
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
              ),

              const SizedBox(width: 8),

              // Theme Toggle Button (Dark Mode / Bright Mode)
              Container(
                margin: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: isDark ? AppTheme.getSurfaceLight(isDark) : const Color(0xFFE8F1FC),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isDark ? AppTheme.getSurfaceBorder(isDark) : const Color(0xFFCFE0F8),
                  ),
                ),
                child: IconButton(
                  icon: Icon(
                    isDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
                    color: isDark ? AppTheme.goldAccent : const Color(0xFF0062FF),
                    size: 20,
                  ),
                  tooltip: isDark ? 'Switch to Bright Mode' : 'Switch to Dark Mode',
                  onPressed: () {
                    ThemeController.toggleTheme();
                  },
                ),
              ),

              const SizedBox(width: 8),

              // Interactive Location Bar Button (Region Discovery)
              _buildLocationBar(isDark, activePrimary),
        ],
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

                    // Featured Hero Banner
                    if (_movies.isNotEmpty) _buildFeaturedHeroBanner(_movies.first, isDark, activePrimary),

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
                                'Now Showing',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: -0.5,
                                  color: AppTheme.getTextPrimary(isDark),
                                ),
                              ),
                            ],
                          ),
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

                    // Movie Grid
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final crossAxisCount = constraints.maxWidth > 900
                              ? 4
                              : constraints.maxWidth > 600
                                  ? 3
                                  : 2;

                          return GridView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: _movies.length,
                            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: crossAxisCount,
                              childAspectRatio: 0.62,
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

  Widget _buildFeaturedHeroBanner(Movie movie, bool isDark, Color activePrimary) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      height: 220,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        image: DecorationImage(
          image: NetworkImage(movie.backdropUrl),
          fit: BoxFit.cover,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.15),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: [
              Colors.black.withValues(alpha: 0.95),
              Colors.black.withValues(alpha: 0.4),
              Colors.transparent,
            ],
            stops: const [0.0, 0.65, 1.0],
          ),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: activePrimary,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'FEATURED',
                    style: TextStyle(
                      color: isDark ? Colors.black : Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 10,
                      letterSpacing: 1.0,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.white24),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.star_rounded, size: 14, color: activePrimary),
                      const SizedBox(width: 4),
                      Text(
                        movie.imdbScore.toString(),
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              movie.title,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Text(
                  '${movie.genre} • ${movie.durationFormatted}',
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),
                const Spacer(),
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [activePrimary, AppTheme.accent]),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: activePrimary.withValues(alpha: 0.4),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ElevatedButton.icon(
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
                    icon: const Icon(Icons.confirmation_num_rounded, size: 16, color: Colors.white),
                    label: const Text('Book Tickets', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
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
                  Image.network(
                    movie.posterUrl,
                    fit: BoxFit.cover,
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return Container(
                        color: AppTheme.getSurfaceLight(isDark),
                        alignment: Alignment.center,
                        child: Opacity(
                          opacity: isDark ? 0.35 : 0.45,
                          child: Image.asset(
                            'assets/images/cineza_logo_transparent.png',
                            width: 50,
                            height: 50,
                            fit: BoxFit.contain,
                          ),
                        ),
                      );
                    },
                    errorBuilder: (_, _, _) => Container(
                      color: AppTheme.getSurfaceLight(isDark),
                      alignment: Alignment.center,
                      child: Opacity(
                        opacity: isDark ? 0.35 : 0.45,
                        child: Image.asset(
                          'assets/images/cineza_logo_transparent.png',
                          width: 50,
                          height: 50,
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.75),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.star_rounded, size: 12, color: activePrimary),
                          const SizedBox(width: 3),
                          Text(
                            movie.imdbScore.toString(),
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppTheme.accent.withValues(alpha: 0.85),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        movie.rating,
                        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Movie Info
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    movie.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: AppTheme.getTextPrimary(isDark),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${movie.genre} • ${movie.durationFormatted}',
                    style: TextStyle(
                      color: AppTheme.getTextSecondary(isDark),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
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
              Row(
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
                  Text(
                    'Exclusive Gift Vouchers',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      letterSpacing: -0.5,
                      color: AppTheme.getTextPrimary(isDark),
                    ),
                  ),
                ],
              ),
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
                  Text(
                    '•',
                    style: TextStyle(color: AppTheme.getTextMuted(isDark)),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.lock_rounded, size: 13, color: isDark ? AppTheme.goldAccent : activePrimary),
                      const SizedBox(width: 4),
                      Text(
                        '256-Bit Bank Encryption',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppTheme.getTextMuted(isDark),
                        ),
                      ),
                    ],
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

  Widget _buildLocationBar(bool isDark, Color activePrimary) {
    final cityName = _selectedCity?.name.isNotEmpty == true ? _selectedCity!.name : 'Mumbai';
    final stateName = _selectedCity?.state.isNotEmpty == true ? _selectedCity!.state : 'Maharashtra';

    return Container(
      margin: const EdgeInsets.only(right: 20, top: 7, bottom: 7),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.getSurfaceLight(isDark) : const Color(0xFFE8F1FC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? AppTheme.getSurfaceBorder(isDark) : const Color(0xFFCFE0F8),
        ),
        boxShadow: [
          BoxShadow(
            color: activePrimary.withValues(alpha: isDark ? 0.15 : 0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () async {
            final chosenCity = await Navigator.push<City>(
              context,
              MaterialPageRoute(
                builder: (_) => LocationSelectorScreen(
                  currentCity: _selectedCity,
                  availableCities: _cities,
                  onLocationConfirmed: (newCity) {
                    setState(() => _selectedCity = newCity);
                    _filterMovies();
                  },
                ),
              ),
            );
            if (chosenCity != null && mounted) {
              setState(() => _selectedCity = chosenCity);
              _filterMovies();
            }
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Glowing Pin / GPS Icon
                Container(
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    color: activePrimary.withValues(alpha: isDark ? 0.2 : 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.near_me_rounded,
                    color: activePrimary,
                    size: 15,
                  ),
                ),
                const SizedBox(width: 8),

                // Location Text (Two lines: Region Discovery / City, State)
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'REGION DISCOVERY',
                          style: TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.6,
                            color: isDark ? AppTheme.getTextMuted(isDark) : const Color(0xFF64748B),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Container(
                          width: 4,
                          height: 4,
                          decoration: BoxDecoration(
                            color: activePrimary,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      '$cityName, $stateName',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.getTextPrimary(isDark),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 8),

                // Edit / Dropdown Chevron Indicator
                Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: isDark ? AppTheme.getTextMuted(isDark) : const Color(0xFF64748B),
                  size: 18,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
