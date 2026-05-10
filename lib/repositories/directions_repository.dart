import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import '../models/directions_info.dart';

class DirectionsRepository {
  static const String _baseUrl = 'https://maps.googleapis.com/maps/api/directions/json';
  final String? _apiKey = dotenv.env['GOOGLE_MAPS_API_KEY'];

  Future<DirectionsInfo?> getDirections({
    required LatLng origin,
    required LatLng destination,
  }) async {
    if (_apiKey == null) {
      throw Exception('Google Maps API key not found in .env file.');
    }

    final uri = Uri.parse(
        '$_baseUrl?origin=${origin.latitude},${origin.longitude}&destination=${destination.latitude},${destination.longitude}&key=$_apiKey');

    try {
      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if ((data['routes'] as List).isNotEmpty) {
          final route = data['routes'][0];
          final leg = route['legs'][0];

          // Extract distance and duration directly from the API response
          final String distance = leg['distance']['text'];
          final String duration = leg['duration']['text'];

          // FIX: Called decodePolyline as a static method directly from the class.
          // This resolves both the "missing_argument" and "instance_access_to_static_member" errors.
          final points = PolylinePoints.decodePolyline(
            route['overview_polyline']['points'],
          );

          if (points.isNotEmpty) {
            final polylineCoordinates = points
                .map((point) => LatLng(point.latitude, point.longitude))
                .toList();

            final polyline = Polyline(
              polylineId: const PolylineId('route'),
              color: Colors.blueAccent,
              width: 5,
              points: polylineCoordinates,
            );

            return DirectionsInfo(
              polyline: polyline,
              distance: distance,
              duration: duration,
            );
          }
        } else {
          debugPrint('Directions API Error: ${data['error_message']}');
        }
      }
    } catch (e) {
      debugPrint('Error getting directions: $e');
    }
    return null;
  }
}

 