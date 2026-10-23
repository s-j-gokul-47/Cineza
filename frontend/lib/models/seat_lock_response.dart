class SeatLockResult {
  final bool success;
  final String message;
  final String? lockToken;
  final int showId;
  final List<int> lockedSeatIds;
  final List<int> conflictedSeatIds;
  final int ttlSeconds;
  final DateTime? expiresAt;

  SeatLockResult({
    required this.success,
    required this.message,
    this.lockToken,
    required this.showId,
    required this.lockedSeatIds,
    required this.conflictedSeatIds,
    required this.ttlSeconds,
    this.expiresAt,
  });

  factory SeatLockResult.fromJson(Map<String, dynamic> json) {
    return SeatLockResult(
      success: json['success'] == true,
      message: json['message'] ?? '',
      lockToken: json['lockToken']?.toString(),
      showId: json['showId'] is int ? json['showId'] : int.tryParse(json['showId']?.toString() ?? '0') ?? 0,
      lockedSeatIds: (json['lockedSeatIds'] as List<dynamic>?)
              ?.map((e) => e is int ? e : int.parse(e.toString()))
              .toList() ??
          [],
      conflictedSeatIds: (json['conflictedSeatIds'] as List<dynamic>?)
              ?.map((e) => e is int ? e : int.parse(e.toString()))
              .toList() ??
          [],
      ttlSeconds: json['ttlSeconds'] is int ? json['ttlSeconds'] : int.tryParse(json['ttlSeconds']?.toString() ?? '600') ?? 600,
      expiresAt: DateTime.tryParse(json['expiresAt']?.toString() ?? ''),
    );
  }
}
