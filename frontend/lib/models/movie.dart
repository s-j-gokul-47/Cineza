class Movie {
  final int id;
  final String title;
  final String synopsis;
  final String posterUrl;
  final String backdropUrl;
  final String genre;
  final String language;
  final int durationMinutes;
  final String rating;
  final double imdbScore;
  final String? releaseDate;

  Movie({
    required this.id,
    required this.title,
    required this.synopsis,
    required this.posterUrl,
    required this.backdropUrl,
    required this.genre,
    required this.language,
    required this.durationMinutes,
    required this.rating,
    required this.imdbScore,
    this.releaseDate,
  });

  String get durationFormatted {
    final hours = durationMinutes ~/ 60;
    final minutes = durationMinutes % 60;
    return '${hours}h ${minutes}m';
  }

  factory Movie.fromJson(Map<String, dynamic> json) {
    return Movie(
      id: json['id'] is int ? json['id'] : int.parse(json['id'].toString()),
      title: json['title'] ?? '',
      synopsis: json['synopsis'] ?? '',
      posterUrl: json['posterUrl'] ?? 'https://via.placeholder.com/300x450',
      backdropUrl: json['backdropUrl'] ?? 'https://via.placeholder.com/800x450',
      genre: json['genre'] ?? 'Cinema',
      language: json['language'] ?? 'English',
      durationMinutes: json['durationMinutes'] is int
          ? json['durationMinutes']
          : int.tryParse(json['durationMinutes'].toString()) ?? 120,
      rating: json['rating'] ?? 'PG-13',
      imdbScore: (json['imdbScore'] is num)
          ? (json['imdbScore'] as num).toDouble()
          : double.tryParse(json['imdbScore'].toString()) ?? 8.0,
      releaseDate: json['releaseDate']?.toString(),
    );
  }
}
