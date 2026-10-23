enum SeatStatusType {
  available,
  selected,
  locked,
  booked,
}

class SeatModel {
  final int id;
  final String rowName;
  final int seatNumber;
  final String seatType; // VIP, PREMIUM, STANDARD
  final double price;
  SeatStatusType status;
  final bool lockedByCurrentUser;

  SeatModel({
    required this.id,
    required this.rowName,
    required this.seatNumber,
    required this.seatType,
    required this.price,
    required this.status,
    this.lockedByCurrentUser = false,
  });

  String get label => '$rowName$seatNumber';

  factory SeatModel.fromJson(Map<String, dynamic> json) {
    SeatStatusType parsedStatus;
    final statusStr = json['status']?.toString().toUpperCase();
    if (statusStr == 'BOOKED') {
      parsedStatus = SeatStatusType.booked;
    } else if (statusStr == 'LOCKED') {
      parsedStatus = SeatStatusType.locked;
    } else {
      parsedStatus = SeatStatusType.available;
    }

    return SeatModel(
      id: json['id'] is int ? json['id'] : int.parse(json['id'].toString()),
      rowName: json['rowName'] ?? '',
      seatNumber: json['seatNumber'] is int ? json['seatNumber'] : int.parse(json['seatNumber'].toString()),
      seatType: json['seatType'] ?? 'STANDARD',
      price: (json['price'] is num)
          ? (json['price'] as num).toDouble()
          : double.tryParse(json['price']?.toString() ?? '15.0') ?? 15.0,
      status: parsedStatus,
      lockedByCurrentUser: json['lockedByCurrentUser'] == true,
    );
  }
}

class ShowSeatMap {
  final int showId;
  final String movieTitle;
  final String theatreName;
  final String screenName;
  final String screenType;
  final DateTime startTime;
  final double priceMultiplier;
  final int totalSeats;
  final int availableSeats;
  final Map<String, List<SeatModel>> seatsByRow;

  ShowSeatMap({
    required this.showId,
    required this.movieTitle,
    required this.theatreName,
    required this.screenName,
    required this.screenType,
    required this.startTime,
    required this.priceMultiplier,
    required this.totalSeats,
    required this.availableSeats,
    required this.seatsByRow,
  });

  factory ShowSeatMap.fromJson(Map<String, dynamic> json) {
    final rawSeatsByRow = json['seatsByRow'] as Map<String, dynamic>? ?? {};
    final Map<String, List<SeatModel>> parsedMap = {};

    rawSeatsByRow.forEach((rowKey, list) {
      if (list is List) {
        parsedMap[rowKey] = list.map((item) => SeatModel.fromJson(item)).toList();
      }
    });

    return ShowSeatMap(
      showId: json['showId'] is int ? json['showId'] : int.parse(json['showId'].toString()),
      movieTitle: json['movieTitle'] ?? '',
      theatreName: json['theatreName'] ?? '',
      screenName: json['screenName'] ?? '',
      screenType: json['screenType'] ?? 'STANDARD',
      startTime: DateTime.tryParse(json['startTime']?.toString() ?? '') ?? DateTime.now(),
      priceMultiplier: (json['priceMultiplier'] is num)
          ? (json['priceMultiplier'] as num).toDouble()
          : 1.0,
      totalSeats: json['totalSeats'] is int ? json['totalSeats'] : 0,
      availableSeats: json['availableSeats'] is int ? json['availableSeats'] : 0,
      seatsByRow: parsedMap,
    );
  }
}
