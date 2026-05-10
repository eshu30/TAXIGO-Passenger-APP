import 'package:geolocator/geolocator.dart';

class DailyRoute {
  final String id;
  final String? routeName;
  final String driverId;
  final DateTime date;
  final List<Position> positions;
  final Position? startLocation;
  final Position? endLocation;
  final String? startLocationName;
  final String? endLocationName;
  final String? destinationName;
  final List<String> preferredPickupNames;
  final String commuteTime;
  final List<String> operatingDays;
  final double totalDistance;
  final Duration totalDuration;
  final String status;

  DailyRoute({
    required this.id,
    this.routeName,
    required this.driverId,
    required this.date,
    this.positions = const [], // Fixed: make it optional with default
    this.startLocation,
    this.endLocation,
    this.startLocationName,
    this.endLocationName,
    this.destinationName,
    this.preferredPickupNames = const [],
    this.commuteTime = '',
    this.operatingDays = const [],
    required this.totalDistance,
    required this.totalDuration,
    required this.status,
  });

  // Create a simple factory for navigation (without Position objects)
  factory DailyRoute.forNavigation({
    required String id,
    String? routeName,
    required String driverId,
    required DateTime date,
    String? startLocationName,
    String? endLocationName,
    String? destinationName,
    List<String> preferredPickupNames = const [],
    String commuteTime = '',
    List<String> operatingDays = const [],
    required double totalDistance,
    required Duration totalDuration,
    required String status,
  }) {
    return DailyRoute(
      id: id,
      routeName: routeName,
      driverId: driverId,
      date: date,
      positions: [], // Empty for navigation
      startLocation: null, // Null for navigation
      endLocation: null, // Null for navigation
      startLocationName: startLocationName,
      endLocationName: endLocationName,
      destinationName: destinationName,
      preferredPickupNames: preferredPickupNames,
      commuteTime: commuteTime,
      operatingDays: operatingDays,
      totalDistance: totalDistance,
      totalDuration: totalDuration,
      status: status,
    );
  }

  factory DailyRoute.fromJson(Map<String, dynamic> json) {
    return DailyRoute(
      id: json['id'] ?? '',
      routeName: json['routeName'],
      driverId: json['driverId'] ?? '',
      date: DateTime.parse(json['date'] ?? DateTime.now().toIso8601String()),
      positions: [], // Skip positions parsing for navigation
      startLocation: null, // Skip for navigation
      endLocation: null, // Skip for navigation
      startLocationName: json['startLocationName'],
      endLocationName: json['endLocationName'],
      destinationName: json['destinationName'],
      preferredPickupNames: List<String>.from(json['preferredPickupNames'] ?? []),
      commuteTime: json['commuteTime'] ?? '',
      operatingDays: List<String>.from(json['operatingDays'] ?? []),
      totalDistance: (json['totalDistance'] ?? 0.0).toDouble(),
      totalDuration: Duration(seconds: json['totalDuration'] ?? 0),
      status: json['status'] ?? 'active',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'routeName': routeName,
      'driverId': driverId,
      'date': date.toIso8601String(),
      // Skip positions for navigation
      'startLocationName': startLocationName,
      'endLocationName': endLocationName,
      'destinationName': destinationName,
      'preferredPickupNames': preferredPickupNames,
      'commuteTime': commuteTime,
      'operatingDays': operatingDays,
      'totalDistance': totalDistance,
      'totalDuration': totalDuration.inSeconds,
      'status': status,
    };
  }

  DailyRoute copyWith({
    String? id,
    String? routeName,
    String? driverId,
    DateTime? date,
    List<Position>? positions,
    Position? startLocation,
    Position? endLocation,
    String? startLocationName,
    String? endLocationName,
    String? destinationName,
    List<String>? preferredPickupNames,
    String? commuteTime,
    List<String>? operatingDays,
    double? totalDistance,
    Duration? totalDuration,
    String? status,
  }) {
    return DailyRoute(
      id: id ?? this.id,
      routeName: routeName ?? this.routeName,
      driverId: driverId ?? this.driverId,
      date: date ?? this.date,
      positions: positions ?? this.positions,
      startLocation: startLocation ?? this.startLocation,
      endLocation: endLocation ?? this.endLocation,
      startLocationName: startLocationName ?? this.startLocationName,
      endLocationName: endLocationName ?? this.endLocationName,
      destinationName: destinationName ?? this.destinationName,
      preferredPickupNames: preferredPickupNames ?? this.preferredPickupNames,
      commuteTime: commuteTime ?? this.commuteTime,
      operatingDays: operatingDays ?? this.operatingDays,
      totalDistance: totalDistance ?? this.totalDistance,
      totalDuration: totalDuration ?? this.totalDuration,
      status: status ?? this.status,
    );
  }
}