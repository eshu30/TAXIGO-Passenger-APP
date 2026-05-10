import 'package:flutter/foundation.dart';

class Taxi {
  final String id;
  final String hardwareTaxiId;
  final String driverName;
  final String licensePlate;
  final String destination;
  final double latitude;
  final double longitude;
  final int availableSeats;
  final int fare;
  final String estimatedArrival;
  final bool isActive;
  final String? workLocation;
  final String? endLocationAddress;

  Taxi({
    required this.id,
    this.hardwareTaxiId = '',
    required this.driverName,
    required this.licensePlate,
    required this.destination,
    required this.latitude,
    required this.longitude,
    required this.availableSeats,
    required this.fare,
    required this.estimatedArrival,
    required this.isActive,
    this.workLocation,
    this.endLocationAddress,
  });

  factory Taxi.fromJson(Map<String, dynamic> json) {
    double lat = 0.0;
    double lng = 0.0;

    try {
      final currentLat = json['current_lat'] ?? json['latitude'];
      final currentLng = json['current_lng'] ?? json['longitude'];
      if (currentLat is num && currentLng is num) {
        lat = currentLat.toDouble();
        lng = currentLng.toDouble();
      } else if (json['current_location'] != null) {
        final loc = json['current_location'].toString();
        // Regex to keep only numbers, dots, and minus signs
        final clean = loc.replaceAll(RegExp(r'[^\d. -]'), '').trim();
        final parts = clean.split(' ').where((s) => s.isNotEmpty).toList();

        if (parts.length >= 2) {
          lng = double.tryParse(parts[0]) ?? 0.0;
          lat = double.tryParse(parts[1]) ?? 0.0;
        }
      }
    } catch (e) {
      debugPrint("Error parsing location: $e");
    }

    return Taxi(
      id: json['id']?.toString() ?? '',
      hardwareTaxiId:
          json['taxi_id']?.toString() ?? json['id']?.toString() ?? '',
      driverName: json['driver_name'] ?? 'Unknown Driver',
      licensePlate: json['license_plate'] ?? 'MH-04-TAXI',
      destination: json['destination'] ?? 'Mumbai',
      latitude: lat,
      longitude: lng,
      availableSeats: (json['available_seats'] as num?)?.toInt() ?? 4,
      fare: (json['fare'] as num?)?.toInt() ?? 100,
      estimatedArrival: json['estimated_arrival'] ?? '5 mins',
      isActive: json['is_active'] ?? true,
      workLocation: json['work_location']?.toString(),
      endLocationAddress: json['end_location_address']?.toString(),
    );
  }
}
