class Theatre {
  final int id;
  final String name;
  final String address;
  final int totalScreens;

  Theatre({
    required this.id,
    required this.name,
    required this.address,
    required this.totalScreens,
  });

  factory Theatre.fromJson(Map<String, dynamic> json) {
    return Theatre(
      id: json['id'] is int ? json['id'] : int.parse(json['id'].toString()),
      name: json['name'] ?? '',
      address: json['address'] ?? '',
      totalScreens: json['totalScreens'] is int
          ? json['totalScreens']
          : int.tryParse(json['totalScreens'].toString()) ?? 1,
    );
  }
}
