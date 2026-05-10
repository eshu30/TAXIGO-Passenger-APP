import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/taxi.dart';

class BookingService {
  final _supabase = Supabase.instance.client;

  // 1. BOOK A RIDE
  Future<void> bookTaxi({
    required Taxi taxi,
    required String destination,
  }) async {
    final user = _supabase.auth.currentUser;
    if (user == null) throw 'User not authenticated.';

    try {
      await _supabase.from('ride_passengers').insert({
        'ride_id': taxi.id, // Uses the Ride UUID
        'passenger_id': user.id,
      });

      // Bonus points (Wrapped in try-catch so it doesn't block booking)
      try {
        await _supabase.rpc('increment_points', params: {
          'user_id': user.id,
          'points_to_add': 20,
        });
      } catch (_) {}
    } catch (e) {
      if (e.toString().contains('duplicate key')) {
        throw 'You have already booked this ride.';
      }
      rethrow;
    }
  }

  Future<void> confirmBooking(String taxiId) async {
    final taxiRow = await _supabase
        .from('taxi_hardware_live')
        .select('occupied_seats')
        .eq('taxi_id', taxiId)
        .maybeSingle();

    if (taxiRow == null) {
      throw 'Taxi not found.';
    }

    final currentOccupiedSeats =
        (taxiRow['occupied_seats'] as num?)?.toInt() ?? 0;

    await _supabase.from('taxi_hardware_live').update({
      'occupied_seats': currentOccupiedSeats + 1,
      'last_update': DateTime.now().toUtc().toIso8601String(),
    }).eq('taxi_id', taxiId);
  }

  // 2. GET HISTORY
  Future<List<Map<String, dynamic>>> getBookingHistory() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return [];

    try {
      final response = await _supabase
          .from('rides')
          .select('id, origin, destination, fare, status, created_at')
          .eq('passenger_id', user.id)
          .eq('status', 'completed')
          .order('created_at', ascending: false);

      return List<Map<String, dynamic>>.from(response).map((item) {
        return {
          'id': item['id'] ?? '', // This is the UUID String
          'created_at': item['created_at'],
          'origin': item['origin'] ?? 'Unknown',
          'destination': item['destination'] ?? 'Unknown',
          'driver_name': 'Taxigo Driver',
          'status': item['status'] ?? 'Scheduled',
          'fare': (item['fare'] as num?)?.toDouble() ?? 0,
        };
      }).toList();
    } catch (e) {
      print('History Error: $e');
      return [];
    }
  }

  // 3. SUBMIT RATING (Updated to accept String rideId)
  Future<void> submitRating({
    required String rideId, // ✅ Changed from bookingId (int) to rideId (String)
    required int rating,
    String? feedback,
  }) async {
    final user = _supabase.auth.currentUser;
    if (user == null) throw 'User not authenticated.';

    try {
      await _supabase.from('ratings').insert({
        'ride_id': rideId,
        'passenger_id': user.id,
        'rating': rating,
        'feedback': feedback,
      });

      await _supabase.rpc('increment_points', params: {
        'user_id': user.id,
        'points_to_add': 5,
      });
    } catch (e) {
      if (e.toString().contains('duplicate key')) {
        throw 'You have already rated this ride.';
      }
      rethrow;
    }
  }
}
