import 'package:supabase_flutter/supabase_flutter.dart';

class RideService {
  final _supabase = Supabase.instance.client;

  Future<String> createRide({
    required String origin,
    required String destination,
    required double startLocationLat,
    required double startLocationLng,
    required double endLocationLat,
    required double endLocationLng,
    String? passengerId,
    String status = 'searching',
    int? fare,
    String? paymentMethod,
  }) async {
    final startAddress = origin.trim();
    final endAddress = destination.trim();
    final user = _supabase.auth.currentUser!;
    final rideStartedAt = DateTime.now().toUtc();

    if (startAddress.isEmpty || endAddress.isEmpty) {
      throw ArgumentError('Pickup and destination are required.');
    }
    if (!startLocationLat.isFinite ||
        !startLocationLng.isFinite ||
        startLocationLat == 0.0 ||
        startLocationLng == 0.0) {
      throw ArgumentError('Pickup location coordinates are required.');
    }
    if (!endLocationLat.isFinite ||
        !endLocationLng.isFinite ||
        endLocationLat == 0.0 ||
        endLocationLng == 0.0) {
      throw ArgumentError('Destination coordinates are required.');
    }

    final passenger = passengerId ?? user.id;
    final requiredPayload = <String, dynamic>{
      'status': status,
      'origin': startAddress,
      'destination': endAddress,
      'start_location_lat': startLocationLat,
      'start_location_lng': startLocationLng,
      'end_location_lat': endLocationLat,
      'end_location_lng': endLocationLng,
      'passenger_id': passenger,
    };

    final attempts = <Map<String, dynamic>>[
      {
        ...requiredPayload,
        if (fare != null) 'fare': fare,
        if (paymentMethod != null) 'payment_method': paymentMethod,
      },
      {
        ...requiredPayload,
        if (fare != null) 'fare': fare,
      },
      requiredPayload,
    ];

    Object? lastError;
    for (final payload in attempts) {
      try {
        final response =
            await _supabase.from('rides').insert(payload).select('id').single();
        return response['id'].toString();
      } catch (error) {
        lastError = error;
        final recoveredId = await _findLatestMatchingRideId(
          passengerId: passenger,
          origin: startAddress,
          destination: endAddress,
          status: status,
          createdAfter: rideStartedAt,
        );
        if (recoveredId != null) {
          return recoveredId;
        }
      }
    }

    throw StateError('Could not create ride: $lastError');
  }

  Future<String?> _findLatestMatchingRideId({
    required String passengerId,
    required String origin,
    required String destination,
    required String status,
    required DateTime createdAfter,
  }) async {
    try {
      final ride = await _supabase
          .from('rides')
          .select('id, created_at')
          .eq('passenger_id', passengerId)
          .eq('origin', origin)
          .eq('destination', destination)
          .eq('status', status)
          .gte('created_at', createdAfter.toIso8601String())
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();

      return ride?['id']?.toString();
    } catch (_) {
      return null;
    }
  }

  Future<void> completeRide(String rideId, {String? paymentMethod}) async {
    final normalizedRideId = rideId.trim();
    if (normalizedRideId.isEmpty) {
      throw ArgumentError('Ride ID is required.');
    }

    final nextStatus =
        paymentMethod?.trim().toLowerCase() == 'cash' ? 'pending' : 'completed';

    final response = await _supabase
        .from('rides')
        .update({'status': nextStatus})
        .eq('id', normalizedRideId)
        .select('id')
        .maybeSingle();

    if (response == null) {
      throw StateError('Ride not found.');
    }
  }

  Stream<Map<String, dynamic>> watchRideStatus(String rideId) {
    return _supabase
        .from('rides')
        .stream(primaryKey: ['id'])
        .eq('id', rideId)
        .map((rows) => rows.isNotEmpty ? rows.first : <String, dynamic>{});
  }
}
