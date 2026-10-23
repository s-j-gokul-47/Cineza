class City {
  final int id;
  final String name;
  final String state;
  final String country;

  City({
    required this.id,
    required this.name,
    required this.state,
    required this.country,
  });

  factory City.fromJson(Map<String, dynamic> json) {
    return City(
      id: json['id'] is int ? json['id'] : int.parse(json['id'].toString()),
      name: json['name'] ?? '',
      state: json['state'] ?? '',
      country: json['country'] ?? 'USA',
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'state': state,
    'country': country,
  };
}
