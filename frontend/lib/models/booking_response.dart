class BookingReceipt {
  final int bookingId;
  final String bookingReference;
  final String movieTitle;
  final String posterUrl;
  final String theatreName;
  final String screenName;
  final DateTime showTime;
  final List<String> seatLabels;
  final double totalAmount;
  final String status;
  final DateTime bookedAt;
  final String qrCodeData;
  final String? notificationMessage;

  BookingReceipt({
    required this.bookingId,
    required this.bookingReference,
    required this.movieTitle,
    required this.posterUrl,
    required this.theatreName,
    required this.screenName,
    required this.showTime,
    required this.seatLabels,
    required this.totalAmount,
    required this.status,
    required this.bookedAt,
    required this.qrCodeData,
    this.notificationMessage,
  });

  factory BookingReceipt.fromJson(Map<String, dynamic> json) {
    return BookingReceipt(
      bookingId: json['bookingId'] is int ? json['bookingId'] : int.tryParse(json['bookingId']?.toString() ?? '0') ?? 0,
      bookingReference: json['bookingReference'] ?? '',
      movieTitle: json['movieTitle'] ?? '',
      posterUrl: json['posterUrl'] ?? '',
      theatreName: json['theatreName'] ?? '',
      screenName: json['screenName'] ?? '',
      showTime: DateTime.tryParse(json['showTime']?.toString() ?? '') ?? DateTime.now(),
      seatLabels: (json['seatLabels'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      totalAmount: (json['totalAmount'] is num)
          ? (json['totalAmount'] as num).toDouble()
          : double.tryParse(json['totalAmount']?.toString() ?? '0.0') ?? 0.0,
      status: json['status'] ?? 'CONFIRMED',
      bookedAt: DateTime.tryParse(json['bookedAt']?.toString() ?? '') ?? DateTime.now(),
      qrCodeData: json['qrCodeData'] ?? '',
      notificationMessage: json['notificationMessage']?.toString(),
    );
  }
}
