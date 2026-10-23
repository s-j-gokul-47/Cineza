class ShowItem {
  final int id;
  final int movieId;
  final String movieTitle;
  final int theatreId;
  final String theatreName;
  final String theatreAddress;
  final int screenId;
  final String screenName;
  final String screenType;
  final DateTime startTime;
  final DateTime endTime;
  final double baseStartingPrice;

  ShowItem({
    required this.id,
    required this.movieId,
    required this.movieTitle,
    required this.theatreId,
    required this.theatreName,
    required this.theatreAddress,
    required this.screenId,
    required this.screenName,
    required this.screenType,
    required this.startTime,
    required this.endTime,
    required this.baseStartingPrice,
  });

  factory ShowItem.fromJson(Map<String, dynamic> json) {
    return ShowItem(
      id: json['id'] is int ? json['id'] : int.parse(json['id'].toString()),
      movieId: json['movieId'] is int ? json['movieId'] : int.parse(json['movieId'].toString()),
      movieTitle: json['movieTitle'] ?? '',
      theatreId: json['theatreId'] is int ? json['theatreId'] : int.parse(json['theatreId'].toString()),
      theatreName: json['theatreName'] ?? '',
      theatreAddress: json['theatreAddress'] ?? '',
      screenId: json['screenId'] is int ? json['screenId'] : int.parse(json['screenId'].toString()),
      screenName: json['screenName'] ?? '',
      screenType: json['screenType'] ?? 'STANDARD',
      startTime: DateTime.tryParse(json['startTime']?.toString() ?? '') ?? DateTime.now(),
      endTime: DateTime.tryParse(json['endTime']?.toString() ?? '') ?? DateTime.now().add(const Duration(hours: 2)),
      baseStartingPrice: (json['baseStartingPrice'] is num)
          ? (json['baseStartingPrice'] as num).toDouble()
          : double.tryParse(json['baseStartingPrice']?.toString() ?? '15.0') ?? 15.0,
    );
  }
}
