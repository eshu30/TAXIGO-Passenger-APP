// lib/models/pickup_point.dart
class PickupPoint {
  final String id;
  final String name;
  final String description;
  final double latitude;
  final double longitude;
  final DateTime createdAt;

  PickupPoint({
    required this.id,
    required this.name,
    required this.description,
    required this.latitude,
    required this.longitude,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'latitude': latitude,
      'longitude': longitude,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory PickupPoint.fromJson(Map<String, dynamic> json) {
    return PickupPoint(
      id: json['id'],
      name: json['name'],
      description: json['description'] ?? '',
      latitude: json['latitude'].toDouble(),
      longitude: json['longitude'].toDouble(),
      createdAt: DateTime.parse(json['createdAt']),
    );
  }

  PickupPoint copyWith({
    String? id,
    String? name,
    String? description,
    double? latitude,
    double? longitude,
    DateTime? createdAt,
  }) {
    return PickupPoint(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

