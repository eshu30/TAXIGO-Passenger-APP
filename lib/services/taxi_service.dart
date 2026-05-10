import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/taxi.dart';

class TaxiService {
  TaxiService();

  static const double _routeThresholdMeters = 1000;
  static const double _driverVicinityRadiusMeters = 10000;

  final _supabase = Supabase.instance.client;

  Stream<List<Taxi>> fetchAvailableDrivers({
    String? origin,
    String? destination,
    LatLng? originLocation,
    LatLng? destinationLocation,
  }) {
    final stream =
        _supabase.from('taxi_hardware_live').stream(primaryKey: ['taxi_id']);

    return stream.asyncMap((liveRows) async {
      try {
        final mergedRows = await _mergeTaxiReferenceData(liveRows);
        final onlineRows = mergedRows.where(_matchesOnlineStatus).toList();
        final filteredRows = _filterRowsForPassengerTrip(
          onlineRows,
          destination: destination,
          originLocation: originLocation,
          destinationLocation: destinationLocation,
        );
        return filteredRows.map((item) => Taxi.fromJson(item)).toList();
      } catch (e) {
        debugPrint('Taxi discovery fallback triggered: $e');
        final onlineRows = liveRows.where(_matchesOnlineStatus).toList();
        final nearbyRows = originLocation == null
            ? onlineRows
            : onlineRows
                .where(
                  (row) => _isDriverNearPassenger(
                    row,
                    passengerOrigin: originLocation,
                  ),
                )
                .toList();
        final fallbackRows = nearbyRows.isNotEmpty ? nearbyRows : onlineRows;
        return fallbackRows.map((item) => Taxi.fromJson(item)).toList();
      }
    });
  }

  Stream<List<Taxi>> getRealtimeTaxiUpdates() {
    return fetchAvailableDrivers();
  }

  Future<List<Map<String, dynamic>>> _mergeTaxiReferenceData(
    List<Map<String, dynamic>> liveRows,
  ) async {
    final rowsWithMaster = await _mergeTaxiMasterViewData(liveRows);
    return _mergeDriverProfileData(rowsWithMaster);
  }

  Future<List<Map<String, dynamic>>> _mergeTaxiMasterViewData(
    List<Map<String, dynamic>> liveRows,
  ) async {
    if (liveRows.isEmpty) {
      return const <Map<String, dynamic>>[];
    }

    final liveIds = _collectKeys(liveRows, const ['taxi_id', 'id']);
    if (liveIds.isEmpty) {
      return liveRows;
    }

    List<dynamic> masterRows = const <dynamic>[];
    try {
      masterRows = await _supabase
          .from('taxi_master_view')
          .select()
          .inFilter('taxi_id', liveIds);
    } catch (_) {
      try {
        masterRows = await _supabase
            .from('taxi_master_view')
            .select()
            .inFilter('id', liveIds);
      } catch (_) {
        masterRows = const <dynamic>[];
      }
    }

    final masterByTaxiId = <String, Map<String, dynamic>>{};
    for (final row in masterRows) {
      final map = Map<String, dynamic>.from(row as Map);
      final key = _firstStringValue(map, const ['taxi_id', 'id']);
      if (key != null) {
        masterByTaxiId[key] = map;
      }
    }

    return liveRows.map((liveRow) {
      final merged = <String, dynamic>{...liveRow};
      final key = _firstStringValue(liveRow, const ['taxi_id', 'id']);
      final masterRow = key == null ? null : masterByTaxiId[key];
      if (masterRow != null) {
        merged.addAll(masterRow);
      }
      return merged;
    }).toList();
  }

  Future<List<Map<String, dynamic>>> _mergeDriverProfileData(
    List<Map<String, dynamic>> rows,
  ) async {
    if (rows.isEmpty) {
      return const <Map<String, dynamic>>[];
    }

    final driverIds = _collectKeys(rows, const ['driver_id', 'id']);
    if (driverIds.isEmpty) {
      return rows;
    }

    try {
      final driverRows =
          await _supabase.from('drivers').select().inFilter('id', driverIds);

      final driversById = <String, Map<String, dynamic>>{};
      for (final row in driverRows) {
        final map = Map<String, dynamic>.from(row as Map);
        final key = _firstStringValue(map, const ['id']);
        if (key != null) {
          driversById[key] = map;
        }
      }

      return rows.map((row) {
        final merged = <String, dynamic>{...row};
        final driverId = _firstStringValue(row, const ['driver_id', 'id']);
        final driverRow = driverId == null ? null : driversById[driverId];
        if (driverRow != null) {
          merged.addAll(driverRow);
        }
        return merged;
      }).toList();
    } catch (_) {
      return rows;
    }
  }

  List<Map<String, dynamic>> _filterRowsForPassengerTrip(
    List<Map<String, dynamic>> onlineRows, {
    required String? destination,
    required LatLng? originLocation,
    required LatLng? destinationLocation,
  }) {
    if (originLocation == null) {
      return onlineRows;
    }

    try {
      final nearbyRows = onlineRows
          .where(
            (row) => _isDriverNearPassenger(
              row,
              passengerOrigin: originLocation,
            ),
          )
          .toList();

      if (nearbyRows.isEmpty) {
        return onlineRows;
      }

      final directionRows = destinationLocation == null
          ? nearbyRows
          : nearbyRows
              .where(
                (row) => _matchesDirectionHint(
                  row,
                  passengerOrigin: originLocation,
                  passengerDestination: destinationLocation,
                ),
              )
              .toList();

      final candidateRows =
          directionRows.isNotEmpty ? directionRows : nearbyRows;
      final destinationRows = destination == null
          ? const <Map<String, dynamic>>[]
          : candidateRows
              .where((row) => _matchesDestinationHint(row, destination))
              .toList();

      return destinationRows.isNotEmpty ? destinationRows : candidateRows;
    } catch (e) {
      debugPrint('Smart filter math fallback triggered: $e');
      final nearbyRows = onlineRows
          .where(
            (row) => _isDriverNearPassenger(
              row,
              passengerOrigin: originLocation,
            ),
          )
          .toList();
      return nearbyRows.isNotEmpty ? nearbyRows : onlineRows;
    }
  }

  bool _matchesDestinationHint(Map<String, dynamic> row, String destination) {
    final passengerDestination = _normalizeText(destination);
    final workLocation = _normalizeText(row['work_location']?.toString());
    if (passengerDestination == null || workLocation == null) {
      return false;
    }
    return workLocation.contains(passengerDestination);
  }

  bool _isDriverNearPassenger(
    Map<String, dynamic> row, {
    required LatLng passengerOrigin,
  }) {
    final currentPoint = _extractCurrentPoint(row);
    if (currentPoint == null) {
      return false;
    }

    return _distanceMeters(currentPoint, passengerOrigin) <=
        _driverVicinityRadiusMeters;
  }

  bool _matchesDirectionHint(
    Map<String, dynamic> row, {
    required LatLng passengerOrigin,
    required LatLng passengerDestination,
  }) {
    final driverStart = _extractHomeWorkPoint(row, isStart: true);
    final driverEnd = _extractHomeWorkPoint(row, isStart: false);
    if (driverStart == null || driverEnd == null) {
      return true;
    }

    if (!_isPointWithinExpandedBoundingBox(
      point: passengerOrigin,
      driverStart: driverStart,
      driverEnd: driverEnd,
    )) {
      return false;
    }

    final originOffset = _distancePointToSegmentMeters(
      passengerOrigin,
      driverStart,
      driverEnd,
    );
    if (originOffset > _routeThresholdMeters) {
      return false;
    }

    final distanceFromDriverStartToOrigin =
        _distanceMeters(driverStart, passengerOrigin);
    final distanceFromDriverStartToDestination =
        _distanceMeters(driverStart, passengerDestination);

    return distanceFromDriverStartToOrigin <
        distanceFromDriverStartToDestination;
  }

  bool _matchesOnlineStatus(Map<String, dynamic> row) {
    final statusValues = [
      row['onboarding_status'],
      row['status'],
      row['driver_status'],
      row['availability_status'],
    ];

    for (final value in statusValues) {
      final normalized = value?.toString().trim().toLowerCase();
      if (normalized == null || normalized.isEmpty) {
        continue;
      }

      if (const {'online', 'active', 'available', 'idle', 'ready'}
          .contains(normalized)) {
        return true;
      }

      if (const {'offline', 'inactive', 'busy', 'unavailable'}
          .contains(normalized)) {
        return false;
      }
    }

    final boolValues = [
      row['is_online'],
      row['online'],
      row['is_active'],
    ];

    for (final value in boolValues) {
      if (value is bool) {
        return value;
      }
    }

    return true;
  }

  LatLng? _extractCurrentPoint(Map<String, dynamic> row) {
    final currentLat =
        _firstDoubleValue(row, const ['current_lat', 'latitude']);
    final currentLng =
        _firstDoubleValue(row, const ['current_lng', 'longitude']);
    if (currentLat != null && currentLng != null) {
      return LatLng(currentLat, currentLng);
    }

    return _parseCoordinateValue(row['current_location']);
  }

  LatLng? _extractHomeWorkPoint(
    Map<String, dynamic> row, {
    required bool isStart,
  }) {
    final raw = isStart
        ? row['home_location']?.toString()
        : row['work_location']?.toString();
    final normalized = _normalizeText(raw);
    if (normalized == null) {
      return null;
    }
    return _knownStops[normalized];
  }

  bool _isPointWithinExpandedBoundingBox({
    required LatLng point,
    required LatLng driverStart,
    required LatLng driverEnd,
  }) {
    final minLat = math.min(driverStart.latitude, driverEnd.latitude);
    final maxLat = math.max(driverStart.latitude, driverEnd.latitude);
    final minLng = math.min(driverStart.longitude, driverEnd.longitude);
    final maxLng = math.max(driverStart.longitude, driverEnd.longitude);

    final midLatRadians =
        ((driverStart.latitude + driverEnd.latitude) / 2) * math.pi / 180;
    const latPadding = _routeThresholdMeters / 111320;
    final lngPadding = _routeThresholdMeters /
        (111320 * math.max(math.cos(midLatRadians), 0.1));

    return _pointInBounds(
      point,
      minLat: minLat - latPadding,
      maxLat: maxLat + latPadding,
      minLng: minLng - lngPadding,
      maxLng: maxLng + lngPadding,
    );
  }

  bool _pointInBounds(
    LatLng point, {
    required double minLat,
    required double maxLat,
    required double minLng,
    required double maxLng,
  }) {
    return point.latitude >= minLat &&
        point.latitude <= maxLat &&
        point.longitude >= minLng &&
        point.longitude <= maxLng;
  }

  double _distancePointToSegmentMeters(
    LatLng point,
    LatLng segmentStart,
    LatLng segmentEnd,
  ) {
    final projected = _projectPointToMeters(point, segmentStart);
    final start = _projectPointToMeters(segmentStart, segmentStart);
    final end = _projectPointToMeters(segmentEnd, segmentStart);

    final dx = end.x - start.x;
    final dy = end.y - start.y;
    final lengthSquared = (dx * dx) + (dy * dy);
    if (lengthSquared == 0) {
      return math.sqrt(
        math.pow(projected.x - start.x, 2) + math.pow(projected.y - start.y, 2),
      );
    }

    final t =
        (((projected.x - start.x) * dx) + ((projected.y - start.y) * dy)) /
            lengthSquared;
    final clampedT = t.clamp(0.0, 1.0);
    final closestX = start.x + (clampedT * dx);
    final closestY = start.y + (clampedT * dy);

    return math.sqrt(
      math.pow(projected.x - closestX, 2) + math.pow(projected.y - closestY, 2),
    );
  }

  _PointMeters _projectPointToMeters(LatLng point, LatLng reference) {
    final latRad = reference.latitude * math.pi / 180;
    final x =
        (point.longitude - reference.longitude) * 111320 * math.cos(latRad);
    final y = (point.latitude - reference.latitude) * 111320;
    return _PointMeters(x, y);
  }

  double _distanceMeters(LatLng a, LatLng b) {
    const earthRadius = 6371000.0;
    final lat1 = a.latitude * math.pi / 180;
    final lat2 = b.latitude * math.pi / 180;
    final dLat = (b.latitude - a.latitude) * math.pi / 180;
    final dLng = (b.longitude - a.longitude) * math.pi / 180;

    final h = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1) *
            math.cos(lat2) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2);
    return 2 * earthRadius * math.asin(math.min(1, math.sqrt(h)));
  }

  LatLng? _parseCoordinateValue(dynamic value) {
    if (value == null) {
      return null;
    }

    if (value is Map) {
      final lat = _firstDoubleFromDynamicMap(value, const ['lat', 'latitude']);
      final lng =
          _firstDoubleFromDynamicMap(value, const ['lng', 'lon', 'longitude']);
      if (lat != null && lng != null) {
        return LatLng(lat, lng);
      }
      return null;
    }

    if (value is List && value.length >= 2) {
      final first = _toDouble(value[0]);
      final second = _toDouble(value[1]);
      if (first != null && second != null) {
        return _latLngFromPair(first, second);
      }
    }

    final matches = RegExp(r'-?\d+(?:\.\d+)?')
        .allMatches(value.toString())
        .map((match) => double.tryParse(match.group(0)!))
        .whereType<double>()
        .toList();
    if (matches.length >= 2) {
      return _latLngFromPair(matches[0], matches[1]);
    }

    return null;
  }

  LatLng _latLngFromPair(double first, double second) {
    final firstLooksLikeLat = first >= -90 && first <= 90;
    final secondLooksLikeLng = second >= -180 && second <= 180;
    if (firstLooksLikeLat && secondLooksLikeLng) {
      return LatLng(first, second);
    }
    return LatLng(second, first);
  }

  double? _firstDoubleValue(Map<String, dynamic> row, List<String> keys) {
    for (final key in keys) {
      final value = _toDouble(row[key]);
      if (value != null) {
        return value;
      }
    }
    return null;
  }

  double? _firstDoubleFromDynamicMap(Map value, List<String> keys) {
    for (final key in keys) {
      final parsed = _toDouble(value[key]);
      if (parsed != null) {
        return parsed;
      }
    }
    return null;
  }

  double? _toDouble(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }
    if (value is String) {
      return double.tryParse(value.trim());
    }
    return null;
  }

  List<String> _collectKeys(
    List<Map<String, dynamic>> rows,
    List<String> keys,
  ) {
    final collected = <String>{};
    for (final row in rows) {
      final value = _firstStringValue(row, keys);
      if (value != null && value.isNotEmpty) {
        collected.add(value);
      }
    }
    return collected.toList();
  }

  String? _firstStringValue(Map<String, dynamic> row, List<String> keys) {
    for (final key in keys) {
      final value = row[key]?.toString().trim();
      if (value != null && value.isNotEmpty) {
        return value;
      }
    }
    return null;
  }

  String? _normalizeText(String? value) {
    final trimmed = value?.trim().toLowerCase();
    if (trimmed == null || trimmed.isEmpty) {
      return null;
    }
    return trimmed.replaceAll(RegExp(r'[^a-z0-9]+'), '');
  }

  Future<List<Taxi>> getTaxisNear({
    required LatLng location,
    double radiusInMeters = 5000,
  }) async {
    try {
      final response = await _supabase.rpc('get_nearby_taxis', params: {
        'user_lat': location.latitude,
        'user_lon': location.longitude,
        'search_radius': radiusInMeters,
      });

      final taxiData = response as List;
      return taxiData.map((item) => Taxi.fromJson(item)).toList();
    } catch (e) {
      debugPrint('Error fetching nearby taxis from RPC: $e');
      rethrow;
    }
  }
}

class _PointMeters {
  const _PointMeters(this.x, this.y);

  final double x;
  final double y;
}

final Map<String, LatLng> _knownStops = {
  'goldenest': const LatLng(19.2941703, 72.8607536),
  'mcd': const LatLng(19.2873218, 72.867687),
  'skstone': const LatLng(19.2858842, 72.8699832),
  'silverpark': const LatLng(19.2819602, 72.8743962),
  'pleasantpark': const LatLng(19.2785062, 72.8799909),
  'kashimira': const LatLng(19.2726395, 72.8814615),
  'thakurmall': const LatLng(19.2632657, 72.8751989),
  'checknaka': const LatLng(19.2579576, 72.8712408),
  'dahisare': const LatLng(19.2509501, 72.8670882),
  'ovaripada': const LatLng(19.2440605, 72.8649657),
  'rashtriyaudyan': const LatLng(19.2347442, 72.8645902),
  'devipada': const LatLng(19.2243638, 72.8657316),
  'magathane': const LatLng(19.2154985, 72.8668289),
  'poisar': const LatLng(19.2041485, 72.8632302),
  'akurli': const LatLng(19.1988213, 72.8606621),
  'kurar': const LatLng(19.186836, 72.8589401),
  'dindoshi': const LatLng(19.1806671, 72.858971),
  'aarey': const LatLng(19.1690898, 72.8592491),
  'goregaone': const LatLng(19.1527534, 72.8570184),
  'jogeshwarie': const LatLng(19.1411949, 72.856634),
  'mogra': const LatLng(19.1284731, 72.8560885),
  'gundavali': const LatLng(19.1187756, 72.8549076),
};
