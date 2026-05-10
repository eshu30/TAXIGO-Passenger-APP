// lib/services/location_service.dart

import 'package:geolocator/geolocator.dart';

class LocationService {
  /// Checks and requests location permissions from the user.
  static Future<void> requestLocationPermission() async {
    LocationPermission permission = await Geolocator.checkPermission();
    
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    
    if (permission == LocationPermission.deniedForever) {
      // You might want to show a dialog to the user to open app settings
      throw Exception('Location permissions are permanently denied. Please enable them in app settings.');
    }
  }

  /// Fetches the user's current GPS position with high accuracy.
  static Future<Position> getCurrentLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception('Location services are disabled. Please enable GPS.');
    }

    // Ensure permissions are handled before getting location
    await requestLocationPermission();

    return await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );
  }

  /// Provides a stream of location updates.
  /// This is ideal for live tracking the driver or passenger's movement.
  static Stream<Position> getLocationStream() {
    return Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        // The location will update whenever the device moves more than 10 meters.
        distanceFilter: 10, 
      ),
    );
  }
}