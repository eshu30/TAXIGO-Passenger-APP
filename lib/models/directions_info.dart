import 'package:google_maps_flutter/google_maps_flutter.dart';

/// A model class to hold all the relevant information about a calculated route.
class DirectionsInfo {
  final Polyline polyline;
  final String distance;
  final String duration;

  DirectionsInfo({
    required this.polyline,
    required this.distance,
    required this.duration,
  });
}


