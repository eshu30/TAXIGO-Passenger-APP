import 'dart:math';

class FareService {
  // --- Constants for Fare Calculation ---
  // You can adjust these values to change your pricing model.
  static const double baseFare = 50.0; // Base price in INR for any ride.
  static const double perKilometerRate = 18.0; // Rate per kilometer in INR.
  static const double perMinuteRate = 1.5; // Rate per minute to account for traffic.

  /// Calculates the estimated fare based on trip distance and duration.
  /// [distanceText] should be in a format like "10.5 km" or "25 mi".
  /// [durationText] should be in a format like "25 mins" or "1 hour 30 mins".
  static double calculateFare(String distanceText, String durationText) {
    try {
      // --- Parse Distance ---
      // This robustly extracts only the numerical value from the distance string.
      final double kilometers = double.tryParse(
        distanceText.replaceAll(RegExp(r'[^0-9.]'), '')
      ) ?? 0.0;

      // --- Parse Duration ---
      // This robustly extracts only the numerical value from the duration string.
      final int minutes = int.tryParse(
        durationText.replaceAll(RegExp(r'[^0-9]'), '')
      ) ?? 0;

      // --- Calculate the total fare ---
      final double distanceCharge = kilometers * perKilometerRate;
      final double timeCharge = minutes * perMinuteRate;
      final double estimatedFare = baseFare + distanceCharge + timeCharge;

      // Round to the nearest whole number for a cleaner price display.
      return estimatedFare.roundToDouble();

    } catch (e) {
      print('Error calculating fare: $e');
      // If there's an error in parsing, return 0.0 to avoid crashing.
      return 0.0;
    }
  }
}

