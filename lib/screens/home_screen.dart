import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:pointer_interceptor/pointer_interceptor.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../constants.dart';
import '../models/taxi.dart';
import '../services/location_service.dart';
import '../services/ride_service.dart';
import '../services/taxi_service.dart';
import 'bookings_screen.dart';
import 'payment_screen.dart';
import 'profile_screen.dart';
import 'ride_tracking_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  GoogleMapController? _mapController;
  LatLng? _currentLocation;
  Set<Marker> _markers = {};
  Set<Circle> _circles = {};
  final Set<Polyline> _polylines = {};
  BitmapDescriptor? _taxiIcon;

  bool _isLoading = true;
  bool _hasShownTaxiSheet = false;
  final int _bottomNavIndex = 0;

  final _taxiService = TaxiService();
  final _rideService = RideService();
  StreamSubscription? _taxiSubscription;
  final Map<String, Stream<List<Map<String, dynamic>>>> _seatStreams = {};
  List<Taxi> _availableTaxis = [];
  List<Taxi> _filteredTaxis = [];

  String? _selectedDestinationName;
  String? _selectedPickupName;
  String? _selectedPaymentMethod; // ✅ State for payment choice

  int? _tripDurationMinutes;
  double? _estimatedFare;

  final Map<String, LatLng> _mumbaiSuburbs = {
    'Goldenest': const LatLng(19.2941703, 72.8607536),
    'MCD': const LatLng(19.2873218, 72.867687),
    'SK Stone': const LatLng(19.2858842, 72.8699832),
    'Silver Park': const LatLng(19.2819602, 72.8743962),
    'Pleasant Park': const LatLng(19.2785062, 72.8799909),
    'Kashimira': const LatLng(19.2726395, 72.8814615),
    'Thakur Mall': const LatLng(19.2632657, 72.8751989),
    'Checknaka': const LatLng(19.2579576, 72.8712408),
    'Dahisar (E)': const LatLng(19.2509501, 72.8670882),
    'Ovaripada': const LatLng(19.2440605, 72.8649657),
    'Rashtriya Udyan': const LatLng(19.2347442, 72.8645902),
    'Devipada': const LatLng(19.2243638, 72.8657316),
    'Magathane': const LatLng(19.2154985, 72.8668289),
    'Poisar': const LatLng(19.2041485, 72.8632302),
    'Akurli': const LatLng(19.1988213, 72.8606621),
    'Kurar': const LatLng(19.186836, 72.8589401),
    'Dindoshi': const LatLng(19.1806671, 72.858971),
    'Aarey': const LatLng(19.1690898, 72.8592491),
    'Goregaon (E)': const LatLng(19.1527534, 72.8570184),
    'Jogeshwari (E)': const LatLng(19.1411949, 72.856634),
    'Mogra': const LatLng(19.1284731, 72.8560885),
    'Gundavali': const LatLng(19.1187756, 72.8549076),
  };

  final List<String> _orderedStops = const [
    'Goldenest',
    'MCD',
    'SK Stone',
    'Silver Park',
    'Pleasant Park',
    'Kashimira',
    'Thakur Mall',
    'Checknaka',
    'Dahisar (E)',
    'Ovaripada',
    'Rashtriya Udyan',
    'Devipada',
    'Magathane',
    'Poisar',
    'Akurli',
    'Kurar',
    'Dindoshi',
    'Aarey',
    'Goregaon (E)',
    'Jogeshwari (E)',
    'Mogra',
    'Gundavali',
  ];

  @override
  void initState() {
    super.initState();
    _initializeScreen();
  }

  @override
  void dispose() {
    _taxiSubscription?.cancel();
    super.dispose();
  }

  Future<void> _initializeScreen() async {
    await _loadCustomIcons();
    await _initializeLocation();
    _subscribeToAvailableDrivers();
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _loadCustomIcons() async {
    try {
      _taxiIcon = await BitmapDescriptor.asset(
        const ImageConfiguration(size: Size(48, 48)),
        'assets/images/taxi.png',
      );
    } catch (e) {
      debugPrint("Icon error: $e");
    }
  }

  Future<void> _initializeLocation() async {
    try {
      setState(() => _currentLocation = const LatLng(19.2183, 72.8591));
      final position = await LocationService.getCurrentLocation();
      if (mounted) {
        setState(() =>
            _currentLocation = LatLng(position.latitude, position.longitude));
      }
    } catch (e) {
      debugPrint('Location init fallback: $e');
    }
  }

  void _subscribeToAvailableDrivers() {
    _taxiSubscription?.cancel();
    final originLocation = _selectedPickupName == null
        ? null
        : _mumbaiSuburbs[_selectedPickupName!];
    final destinationLocation = _selectedDestinationName == null
        ? null
        : _mumbaiSuburbs[_selectedDestinationName!];
    _taxiSubscription = _taxiService
        .fetchAvailableDrivers(
      origin: _selectedPickupName,
      destination: _selectedDestinationName,
      originLocation: originLocation,
      destinationLocation: destinationLocation,
    )
        .listen((updatedTaxis) {
      if (!mounted) return;
      final destination = _selectedDestinationName;
      final taxisForDisplay = destination == null
          ? updatedTaxis
          : _filterTaxisForExactDestination(updatedTaxis, destination);
      _primeSeatStreams(updatedTaxis);

      setState(() {
        _availableTaxis = updatedTaxis;
        _filteredTaxis = taxisForDisplay;
        _isLoading = false;
      });
      _updateMapElements();
      if (destination != null) {
        _maybeShowTaxiSheet(destination, taxisForDisplay);
      }
    });
  }

  void _primeSeatStreams(List<Taxi> taxis) {
    for (final taxi in taxis) {
      final taxiId = _seatStreamTaxiId(taxi);
      if (taxiId.isEmpty || _seatStreams.containsKey(taxiId)) {
        continue;
      }

      _seatStreams[taxiId] = Supabase.instance.client
          .from('taxi_hardware_live')
          .stream(primaryKey: ['taxi_id']).eq('taxi_id', taxiId);
    }
  }

  String _seatStreamTaxiId(Taxi taxi) {
    return taxi.hardwareTaxiId.isNotEmpty ? taxi.hardwareTaxiId : taxi.id;
  }

  _SeatAvailability _seatAvailabilityFromSnapshot(
    AsyncSnapshot<List<Map<String, dynamic>>> snapshot,
  ) {
    if (!snapshot.hasData || snapshot.data!.isEmpty) {
      return const _SeatAvailability(availableSeats: 4, totalSeats: 4);
    }

    final data = snapshot.data!.first;
    final bool seat1 = data['seat1'] ?? false;
    final bool seat2 = data['seat2'] ?? false;
    final bool seat3 = data['seat3'] ?? false;
    final bool seat4 = data['seat4'] ?? false;

    final occupied =
        (seat1 ? 1 : 0) + (seat2 ? 1 : 0) + (seat3 ? 1 : 0) + (seat4 ? 1 : 0);
    const totalSeats = 4;
    final availableSeats = totalSeats - occupied;

    return _SeatAvailability(
      availableSeats: availableSeats < 0 ? 0 : availableSeats,
      totalSeats: totalSeats,
    );
  }

  Widget _buildSeatText(String taxiId, {double fontSize = 16}) {
    final seatStream = _seatStreams[taxiId];
    if (seatStream == null) {
      return Text(
        "4 Seats",
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: FontWeight.bold,
          color: Colors.black,
        ),
      );
    }

    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: seatStream,
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Text(
            "4 Seats",
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          );
        }

        final availability = _seatAvailabilityFromSnapshot(snapshot);

        return Text(
          availability.availableSeats == 0
              ? "FULL"
              : "${availability.availableSeats} / ${availability.totalSeats} Seats",
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: FontWeight.bold,
            color: availability.availableSeats < availability.totalSeats
                ? Colors.red
                : Colors.black,
          ),
        );
      },
    );
  }

  List<Taxi> _filterTaxisForExactDestination(
    List<Taxi> taxis,
    String destination,
  ) {
    final normalizedDestination = _normalizeStopText(destination);
    final matchedTaxis = taxis.where((taxi) {
      final workLocation = _normalizeStopText(taxi.workLocation);
      final endLocationAddress = _normalizeStopText(taxi.endLocationAddress);
      return workLocation == normalizedDestination ||
          endLocationAddress == normalizedDestination;
    }).toList();

    return matchedTaxis.isNotEmpty ? matchedTaxis : taxis;
  }

  String? _normalizeStopText(String? value) {
    final trimmed = value?.trim().toLowerCase();
    if (trimmed == null || trimmed.isEmpty) {
      return null;
    }
    return trimmed.replaceAll(RegExp(r'[^a-z0-9]+'), '');
  }

  Future<void> _filterTaxisForDestination(String destination) async {
    setState(() {
      _isLoading = true;
      _hasShownTaxiSheet = false;
    });

    try {
      _subscribeToAvailableDrivers();
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        debugPrint('Error finding taxis: $e');
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not load taxis for this route right now.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _maybeShowTaxiSheet(String destination, List<Taxi> taxis) {
    if (!mounted || _selectedPickupName == null || _hasShownTaxiSheet) {
      return;
    }

    _hasShownTaxiSheet = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _selectedDestinationName != destination) return;
      _showTaxiListBottomSheet(destination, taxis);
    });
  }

  void _updateMapElements() {
    final newMarkers = <Marker>{};
    final newCircles = <Circle>{};

    if (_currentLocation != null) {
      newMarkers.add(Marker(
        markerId: const MarkerId('current_location'),
        position: _currentLocation!,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
      ));
    }

    _mumbaiSuburbs.forEach((name, latLng) {
      bool isDestination = (name == _selectedDestinationName);
      bool isPickup = (name == _selectedPickupName);

      Color circleColor = Colors.pink.withValues(alpha: 0.3);
      if (isDestination) circleColor = Colors.red.withValues(alpha: 0.6);
      if (isPickup) circleColor = Colors.green.withValues(alpha: 0.6);

      newCircles.add(Circle(
        circleId: CircleId('${name}_circle'),
        center: latLng,
        radius: 400,
        fillColor: circleColor,
        strokeColor: circleColor.withValues(alpha: 1),
        strokeWidth: 2,
        consumeTapEvents: true,
        onTap: () async {
          if (_selectedPickupName == null) {
            setState(() => _selectedPickupName = name);
          } else {
            setState(() {
              _selectedDestinationName = name;
              _hasShownTaxiSheet = false;
            });
            _calculateFakeTrip();
            await _filterTaxisForDestination(name);
          }
        },
      ));

      if (isDestination || isPickup) {
        newMarkers.add(Marker(
          markerId: MarkerId(name),
          position: latLng,
          icon: BitmapDescriptor.defaultMarkerWithHue(isDestination
              ? BitmapDescriptor.hueRed
              : BitmapDescriptor.hueGreen),
          infoWindow: InfoWindow(title: name),
        ));
      }
    });

    for (final taxi in _filteredTaxis) {
      newMarkers.add(Marker(
        markerId: MarkerId('taxi_${taxi.id}'),
        position: LatLng(taxi.latitude, taxi.longitude),
        icon: _taxiIcon ?? BitmapDescriptor.defaultMarker,
        onTap: () => _showSingleTaxiDetails(taxi),
      ));
    }

    if (mounted) {
      setState(() {
        _markers = newMarkers;
        _circles = newCircles;
      });
    }
  }

  void _calculateFakeTrip() {
    if (_selectedPickupName == null || _selectedDestinationName == null) {
      finalFare = 0;
      return;
    }

    LatLng start = _mumbaiSuburbs[_selectedPickupName]!;

    final pickupIndex = _orderedStops.indexOf(_selectedPickupName!);
    final destIndex = _orderedStops.indexOf(_selectedDestinationName!);
    if (pickupIndex == -1 || destIndex == -1) {
      finalFare = 0;
      return;
    }

    final stopCount = (destIndex - pickupIndex).abs();
    final traversedStops = stopCount == 0 ? 1 : stopCount;

    if (stopCount <= 5) {
      finalFare = 20;
    } else if (stopCount <= 13) {
      finalFare = 50;
    } else if (stopCount <= 20) {
      finalFare = 70;
    } else {
      finalFare = 80;
    }

    final int time = 2 + (traversedStops ~/ 2);
    setState(() {
      _polylines.clear();
      // ✅ REMOVED DISPLACEMENT LINE
      /* _polylines.add(Polyline(
        polylineId: const PolylineId('demo_route'),
        points: [start, end],
        color: Colors.blue,
        width: 5,
        patterns: [PatternItem.dash(10), PatternItem.gap(5)], 
      )); */

      _tripDurationMinutes = time;
      _estimatedFare = finalFare.toDouble();
    });

    _mapController?.animateCamera(CameraUpdate.newLatLngZoom(start, 13));
  }

  String _getMumbaiCarModel(String driverName) {
    if (driverName.contains('Babu') || driverName.contains('Raju Rastogi')) {
      return 'Maruti Omni';
    }
    if (driverName.contains('Ganpat') ||
        driverName.contains('Ismail') ||
        driverName.contains('Ramesh')) {
      return 'Maruti Eeco';
    }
    if (driverName.contains('Anil') ||
        driverName.contains('Rajesh') ||
        driverName.contains('Deepak')) {
      return 'Hyundai i10';
    }
    return 'Hyundai Santro';
  }

  void _showTaxiListBottomSheet(String destination, List<Taxi> taxis) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      barrierColor: Colors.black12,
      builder: (context) => PointerInterceptor(
        child: DraggableScrollableSheet(
          initialChildSize: 0.45,
          minChildSize: 0.3,
          maxChildSize: 0.7,
          builder: (_, controller) => Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              boxShadow: [BoxShadow(blurRadius: 10, color: Colors.black26)],
            ),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16.0,
                    vertical: 12.0,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Taxis to $destination',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.grey),
                        onPressed: () {
                          Navigator.pop(context);
                          setState(() {
                            _hasShownTaxiSheet = false;
                            _selectedDestinationName = null;
                            _filteredTaxis = _availableTaxis;
                          });
                          _updateMapElements();
                        },
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Flexible(
                  child: SingleChildScrollView(
                    controller: controller,
                    child: taxis.isEmpty
                        ? const Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 32,
                            ),
                            child: Text(
                              'No drivers available for this specific route right now.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.black54,
                              ),
                            ),
                          )
                        : Column(
                            children: List.generate(taxis.length, (index) {
                              final taxi = taxis[index];
                              final fixedFare = finalFare > 0
                                  ? finalFare
                                  : (_estimatedFare?.toInt() ?? taxi.fare);
                              final carModel =
                                  _getMumbaiCarModel(taxi.driverName);

                              return Card(
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 8,
                                ),
                                elevation: 2,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(12),
                                  onTap: () {
                                    Navigator.pop(context);
                                    _showSingleTaxiDetails(
                                      taxi,
                                      fareOverride: fixedFare,
                                    );
                                  },
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 12,
                                      horizontal: 16,
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Row(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            CircleAvatar(
                                              backgroundColor:
                                                  const Color(0xFFFFC107)
                                                      .withValues(alpha: 0.2),
                                              child: const Icon(
                                                Icons.local_taxi,
                                                color: Colors.black87,
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Text(
                                                    taxi.driverName,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                    style: const TextStyle(
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      fontSize: 16,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 4),
                                                  Text(
                                                    carModel,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                    style: const TextStyle(
                                                      color: Colors.black54,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            Text(
                                              '\u20B9$fixedFare',
                                              style: const TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.green,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 10),
                                        Row(
                                          children: [
                                            Expanded(
                                              child: _buildSeatText(
                                                _seatStreamTaxiId(taxi),
                                                fontSize: 14,
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            const Text(
                                              'View',
                                              style: TextStyle(
                                                color: Colors.blue,
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            }),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showSingleTaxiDetails(Taxi taxi, {int? fareOverride}) {
    final selectedFare =
        fareOverride ?? (finalFare > 0 ? finalFare : taxi.fare);
    final carModel = _getMumbaiCarModel(taxi.driverName);
    final taxiId = _seatStreamTaxiId(taxi);
    _primeSeatStreams([taxi]);
    _selectedPaymentMethod = null;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.account_circle,
                      size: 50, color: Colors.grey),
                  const SizedBox(width: 15),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        taxi.driverName,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '$carModel \u2022 4.8 \u2605',
                        style: const TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 20),
              const Text(
                'Select Payment Method',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.payment),
                      label: const Text('Pay Online'),
                      style: OutlinedButton.styleFrom(
                        backgroundColor: _selectedPaymentMethod == 'Online'
                            ? const Color(0xFFFFF9C4)
                            : null,
                        side: BorderSide(
                          color: _selectedPaymentMethod == 'Online'
                              ? const Color(0xFFFFC107)
                              : Colors.grey.shade300,
                        ),
                      ),
                      onPressed: () => setModalState(
                          () => _selectedPaymentMethod = 'Online'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.money),
                      label: const Text('Cash'),
                      style: OutlinedButton.styleFrom(
                        backgroundColor: _selectedPaymentMethod == 'Cash'
                            ? Colors.green.withValues(alpha: 0.05)
                            : null,
                        side: BorderSide(
                          color: _selectedPaymentMethod == 'Cash'
                              ? Colors.green
                              : Colors.grey.shade300,
                        ),
                      ),
                      onPressed: () =>
                          setModalState(() => _selectedPaymentMethod = 'Cash'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              _detailRow('Vehicle No', taxi.licensePlate),
              _detailRow('Total Fare', '\u20B9$selectedFare', isPrice: true),
              const SizedBox(height: 20),
              StreamBuilder<List<Map<String, dynamic>>>(
                stream: _seatStreams[taxiId],
                builder: (context, snapshot) {
                  final availability = _seatAvailabilityFromSnapshot(snapshot);
                  final isFull = availability.availableSeats == 0;
                  final isBookingDisabled =
                      _selectedPaymentMethod == null || isFull;
                  final buttonText = isFull
                      ? 'FULL'
                      : _selectedPaymentMethod == 'Online'
                          ? 'Pay Online'
                          : 'CONFIRM BOOKING';

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _detailRow(
                        'Available Seats',
                        isFull
                            ? 'FULL'
                            : '${availability.availableSeats} / ${availability.totalSeats} Seats',
                        valueColor: availability.availableSeats <
                                availability.totalSeats
                            ? Colors.red
                            : Colors.black87,
                      ),
                      if (isFull)
                        const Padding(
                          padding: EdgeInsets.only(top: 4, bottom: 12),
                          child: Text(
                            'No seats available',
                            style: TextStyle(
                              color: Colors.red,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        )
                      else
                        const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        height: AppDimensions.largeButtonHeight,
                        child: Opacity(
                          opacity: isFull ? 0.5 : 1.0,
                          child: ElevatedButton(
                            onPressed: isBookingDisabled
                                ? null
                                : () async {
                                    Navigator.of(context).pop();
                                    if (_selectedPaymentMethod == 'Online') {
                                      await _openPaymentScreen(
                                          taxi, selectedFare);
                                      return;
                                    }
                                    await _startCashRide(taxi, selectedFare);
                                  },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: isFull
                                  ? Colors.grey
                                  : const Color(0xFFFFC107),
                              disabledBackgroundColor: Colors.grey,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(
                                  AppBorderRadius.circular,
                                ),
                              ),
                              elevation: AppDimensions.cardElevation,
                            ),
                            child: Text(
                              buttonText,
                              style: AppTextStyles.buttonText.copyWith(
                                color: AppColors.textDark,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _detailRow(
    String label,
    String value, {
    bool isPrice = false,
    Color? valueColor,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey, fontSize: 16)),
          Text(value,
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color:
                      valueColor ?? (isPrice ? Colors.black : Colors.black87))),
        ],
      ),
    );
  }

  Future<void> _openPaymentScreen(Taxi taxi, int selectedFare) async {
    final origin = _selectedPickupName;
    final destination = _selectedDestinationName ?? taxi.destination;
    final start = origin == null ? null : _mumbaiSuburbs[origin];
    final end = _mumbaiSuburbs[destination];

    if (origin == null || start == null || end == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Please select a valid pickup and destination.')));
      return;
    }

    finalFare = selectedFare;

    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (context) => PaymentScreen(
          taxi: taxi,
          taxiId: taxi.hardwareTaxiId,
          amount: selectedFare,
          origin: origin,
          destination: destination,
          vehicleNumber: taxi.licensePlate,
          start: start,
          end: end,
          durationMinutes: _tripDurationMinutes ?? 5,
        ),
      ),
    );
  }

  Future<void> _startCashRide(Taxi taxi, int selectedFare) async {
    final origin = _selectedPickupName;
    final destination = _selectedDestinationName;
    if (origin == null || destination == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Please select both pickup and destination.')));
      return;
    }
    final pickupLocation = _mumbaiSuburbs[origin];
    final destinationLocation = _mumbaiSuburbs[destination];
    if (pickupLocation == null ||
        pickupLocation.latitude == 0.0 ||
        pickupLocation.longitude == 0.0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Please select a valid pickup location.')));
      return;
    }
    if (destinationLocation == null ||
        destinationLocation.latitude == 0.0 ||
        destinationLocation.longitude == 0.0) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select a valid destination.')));
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
          child: CircularProgressIndicator(color: Color(0xFFFFC107))),
    );
    try {
      final rideId = await _rideService.createRide(
        origin: origin,
        destination: destination,
        startLocationLat: pickupLocation.latitude,
        startLocationLng: pickupLocation.longitude,
        endLocationLat: destinationLocation.latitude,
        endLocationLng: destinationLocation.longitude,
        status: 'pending',
        fare: selectedFare,
        paymentMethod: 'cash',
      );
      if (!mounted) return;
      Navigator.of(context).pop();

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => TaxiMovingSimulation(
            rideId: rideId,
            start: pickupLocation,
            end: destinationLocation,
            taxi: taxi,
            fare: selectedFare,
            durationMinutes: _tripDurationMinutes ?? 5,
            origin: origin,
            destination: destination,
            paymentMethod: 'cash',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ride request failed: ${e.toString()}')));
    }
  }

  void _onBottomNavTapped(int index) {
    if (index == _bottomNavIndex) return;
    switch (index) {
      case 1:
        Navigator.push(context,
            MaterialPageRoute(builder: (context) => const BookingsScreen()));
        break;
      case 2:
        Navigator.push(context,
            MaterialPageRoute(builder: (context) => const ProfileScreen()));
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFFFFC107),
        elevation: 0,
        centerTitle: true,
        automaticallyImplyLeading: false,
        title: Image.asset('assets/images/logo.png',
            height: 40, fit: BoxFit.contain),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFFFFC107)))
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: DropdownButtonFormField<String>(
                    initialValue: _selectedPickupName,
                    decoration: InputDecoration(
                      hintText: 'Select Pickup Location',
                      prefixIcon:
                          const Icon(Icons.my_location, color: Colors.green),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(25),
                          borderSide: BorderSide.none),
                      filled: true,
                      fillColor: Colors.grey.shade100,
                    ),
                    items: _mumbaiSuburbs.keys
                        .map((suburb) => DropdownMenuItem(
                            value: suburb, child: Text(suburb)))
                        .toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setState(() => _selectedPickupName = value);
                        _calculateFakeTrip();
                        _updateMapElements();
                        if (_selectedDestinationName != null) {
                          _filterTaxisForDestination(_selectedDestinationName!);
                        }
                      }
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: DropdownButtonFormField<String>(
                    initialValue: _selectedDestinationName,
                    decoration: InputDecoration(
                      hintText: 'Select Destination',
                      prefixIcon:
                          const Icon(Icons.location_on, color: Colors.red),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(25),
                          borderSide: BorderSide.none),
                      filled: true,
                      fillColor: Colors.grey.shade100,
                    ),
                    items: _mumbaiSuburbs.keys
                        .map((suburb) => DropdownMenuItem(
                            value: suburb, child: Text(suburb)))
                        .toList(),
                    onChanged: (value) async {
                      if (value != null) {
                        setState(() => _selectedDestinationName = value);
                        if (_selectedPickupName != null) {
                          _calculateFakeTrip();
                          await _filterTaxisForDestination(value);
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text(
                                      'Please select a Pickup location first.')));
                        }
                      }
                    },
                  ),
                ),
                Expanded(
                  child: GoogleMap(
                    initialCameraPosition: CameraPosition(
                        target:
                            _currentLocation ?? const LatLng(19.2183, 72.8591),
                        zoom: 12),
                    markers: _markers,
                    circles: _circles,
                    polylines: _polylines,
                    onMapCreated: (controller) => _mapController = controller,
                    gestureRecognizers: <Factory<OneSequenceGestureRecognizer>>{
                      Factory<EagerGestureRecognizer>(
                        () => EagerGestureRecognizer(),
                      ),
                    },
                    myLocationEnabled: true,
                    myLocationButtonEnabled: true,
                  ),
                ),
              ],
            ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _bottomNavIndex,
        onTap: _onBottomNavTapped,
        selectedItemColor: const Color(0xFFFFC107),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.history), label: 'Bookings'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }
}

class _SeatAvailability {
  final int availableSeats;
  final int totalSeats;

  const _SeatAvailability({
    required this.availableSeats,
    required this.totalSeats,
  });
}
