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

  String get resolvedBackdropUrl {
    final titleKey = title.toLowerCase().trim();
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
    if (backdropUrl.isNotEmpty && backdropUrl.startsWith('assets/')) {
      return backdropUrl;
    }
    return backdropUrl.isNotEmpty ? backdropUrl : posterUrl;
  }

  String get resolvedPosterUrl {
    final titleKey = title.toLowerCase().trim();
    if (titleKey.contains('kgf') || titleKey.contains('k.g.f')) {
      return 'assets/images/movie_kgf2.jpg';
    }
    if (titleKey.contains('soorarai')) {
      return 'assets/images/movie_soorarai_pottru.jpg';
    }
    if (titleKey.contains('maanaadu')) {
      return 'assets/images/movie_maanaadu.jpg';
    }
    if (titleKey == '24' || titleKey.contains('24')) {
      return 'assets/images/movie_24.jpg';
    }
    if (titleKey.contains('vikram')) {
      return 'assets/images/movie_vikram.jpg';
    }
    return posterUrl;
  }

  /// Official Movie Trailer YouTube ID
  String? get trailerYoutubeId {
    final titleKey = title.toLowerCase().trim();
    if (titleKey == '24' || titleKey.contains('24')) {
      return 'wqXE_es_I3M'; // Official 24 Movie Trailer
    }
    if (titleKey.contains('kgf') || titleKey.contains('k.g.f')) {
      return 'JKa05nyUmuQ'; // K.G.F Chapter 2 Trailer
    }
    if (titleKey.contains('soorarai')) {
      return 'fa_DIwRsa9o'; // Soorarai Pottru Trailer
    }
    if (titleKey.contains('maanaadu')) {
      return 't9krhbwD-4M'; // Maanaadu Trailer
    }
    if (titleKey.contains('vikram')) {
      return 'OKBMCLzuvWU'; // Vikram Trailer
    }
    return null;
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
