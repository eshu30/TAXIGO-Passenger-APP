// lib/widgets/platform_map.dart
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:google_maps_flutter/google_maps_flutter.dart';

class PlatformMap extends StatelessWidget {
  final LatLng? initialPosition;
  final Set<Marker> markers;
  final Set<Circle> circles; // New circles parameter
  final Function(GoogleMapController)? onMapCreated;
  final Function(LatLng)? onTap;
  final bool myLocationEnabled;
  final bool myLocationButtonEnabled;
  final MapType mapType;
  final double zoom;

  const PlatformMap({
    Key? key,
    this.initialPosition,
    this.markers = const {},
    this.circles = const {}, // Initialize the new parameter
    this.onMapCreated,
    this.onTap,
    this.myLocationEnabled = true,
    this.myLocationButtonEnabled = true,
    this.mapType = MapType.normal,
    this.zoom = 12,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GoogleMap(
      onMapCreated: onMapCreated,
      initialCameraPosition: CameraPosition(
        target: initialPosition ?? const LatLng(19.0760, 72.8777),
        zoom: zoom,
      ),
      markers: markers,
      circles: circles, // Pass the circles to the map
      myLocationEnabled: myLocationEnabled,
      myLocationButtonEnabled: myLocationButtonEnabled,
      onTap: onTap,
      mapType: mapType,
    );
  }
}