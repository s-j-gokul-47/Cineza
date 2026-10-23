import 'package:flutter/material.dart';
import '../models/city.dart';
import '../models/movie.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';

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

  @override
  void initState() {
    super.initState();
    _loadInitialData();
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
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = ThemeController.isDark(context);
    final activePrimary = AppTheme.getPrimary(isDark);

    return Scaffold(
      backgroundColor: AppTheme.getBackground(isDark),
      appBar: AppBar(
        backgroundColor: AppTheme.getSurface(isDark),
        titleSpacing: 20,
        title: Row(
          children: [
            // Brand Logo
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [activePrimary, AppTheme.accent],
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'CINEZA',
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                  letterSpacing: 2.0,
                  color: Colors.black,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'CINEMAS',
              style: TextStyle(
                fontWeight: FontWeight.w400,
                fontSize: 14,
                letterSpacing: 3.0,
                color: AppTheme.getTextSecondary(isDark),
              ),
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
                          color: AppTheme.getTextSecondary(isDark),
                        ),
                        contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                        suffixIcon: _searchController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, size: 16),
                                onPressed: () {
                                  _searchController.clear();
                                  _filterMovies();
                                },
                              )
                            : null,
                        filled: true,
                        fillColor: AppTheme.getSurfaceLight(isDark),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide(color: AppTheme.getSurfaceBorder(isDark)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide(color: AppTheme.getSurfaceBorder(isDark)),
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
          // Theme Toggle Button (Dark Mode / Bright Mode)
          Container(
            margin: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: AppTheme.getSurfaceLight(isDark),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppTheme.getSurfaceBorder(isDark)),
            ),
            child: IconButton(
              icon: Icon(
                isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                color: activePrimary,
                size: 20,
              ),
              tooltip: isDark ? 'Switch to Bright Mode' : 'Switch to Dark Mode',
              onPressed: () {
                ThemeController.toggleTheme();
              },
            ),
          ),

          const SizedBox(width: 8),

          // City Selector Dropdown
          if (_cities.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(right: 20, top: 8, bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: AppTheme.getSurfaceLight(isDark),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppTheme.getSurfaceBorder(isDark)),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<City>(
                  value: _selectedCity,
                  dropdownColor: AppTheme.getSurface(isDark),
                  icon: Icon(Icons.location_on_rounded, color: activePrimary, size: 18),
                  items: _cities.map((city) {
                    return DropdownMenuItem<City>(
                      value: city,
                      child: Text(
                        '${city.name}, ${city.state}',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.getTextPrimary(isDark),
                        ),
                      ),
                    );
                  }).toList(),
                  onChanged: (city) {
                    if (city != null) {
                      setState(() => _selectedCity = city);
                      _filterMovies();
                    }
                  },
                ),
              ),
            ),
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

                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
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
                  label: const Text('Book Tickets', style: TextStyle(fontSize: 13)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: activePrimary,
                    foregroundColor: isDark ? Colors.black : Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
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
                    errorBuilder: (_, _, _) => Container(
                      color: AppTheme.getSurfaceLight(isDark),
                      child: Icon(
                        Icons.movie_creation_outlined,
                        color: AppTheme.getTextMuted(isDark),
                        size: 40,
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
}
