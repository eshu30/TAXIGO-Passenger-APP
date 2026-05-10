import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../constants.dart';
import '../models/taxi.dart';
import '../services/ride_service.dart';
import 'ride_rating_screen.dart';

class TaxiMovingSimulation extends StatelessWidget {
  final String rideId;
  final LatLng start;
  final LatLng end;
  final Taxi taxi;
  final int fare;
  final int durationMinutes;
  final String origin;
  final String destination;
  final String paymentMethod;

  const TaxiMovingSimulation({
    super.key,
    required this.rideId,
    required this.start,
    required this.end,
    required this.taxi,
    required this.fare,
    required this.durationMinutes,
    required this.origin,
    required this.destination,
    required this.paymentMethod,
  });

  @override
  Widget build(BuildContext context) {
    return RideTrackingScreen(
      rideId: rideId,
      taxi: taxi,
      fare: fare,
      startPos: start,
      endPos: end,
      durationMinutes: durationMinutes,
      origin: origin,
      destination: destination,
      paymentMethod: paymentMethod,
    );
  }
}

class RideTrackingScreen extends StatefulWidget {
  final String rideId;
  final Taxi taxi;
  final int fare;
  final LatLng startPos;
  final LatLng endPos;
  final int durationMinutes;
  final String origin;
  final String destination;
  final String paymentMethod;

  const RideTrackingScreen({
    super.key,
    required this.rideId,
    required this.taxi,
    required this.fare,
    required this.startPos,
    required this.endPos,
    required this.durationMinutes,
    required this.origin,
    required this.destination,
    required this.paymentMethod,
  });

  @override
  State<RideTrackingScreen> createState() => _RideTrackingScreenState();
}

class _RideTrackingScreenState extends State<RideTrackingScreen> {
  final String _driverPhone = "+91 98765 43210";
  static const int _tripDurationSeconds = 180;
  final _rideService = RideService();

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

  final Map<String, LatLng> _mumbaiSuburbs = const {
    'Goldenest': LatLng(19.2941703, 72.8607536),
    'MCD': LatLng(19.2873218, 72.867687),
    'SK Stone': LatLng(19.2858842, 72.8699832),
    'Silver Park': LatLng(19.2819602, 72.8743962),
    'Pleasant Park': LatLng(19.2785062, 72.8799909),
    'Kashimira': LatLng(19.2726395, 72.8814615),
    'Thakur Mall': LatLng(19.2632657, 72.8751989),
    'Checknaka': LatLng(19.2579576, 72.8712408),
    'Dahisar (E)': LatLng(19.2509501, 72.8670882),
    'Ovaripada': LatLng(19.2440605, 72.8649657),
    'Rashtriya Udyan': LatLng(19.2347442, 72.8645902),
    'Devipada': LatLng(19.2243638, 72.8657316),
    'Magathane': LatLng(19.2154985, 72.8668289),
    'Poisar': LatLng(19.2041485, 72.8632302),
    'Akurli': LatLng(19.1988213, 72.8606621),
    'Kurar': LatLng(19.186836, 72.8589401),
    'Dindoshi': LatLng(19.1806671, 72.858971),
    'Aarey': LatLng(19.1690898, 72.8592491),
    'Goregaon (E)': LatLng(19.1527534, 72.8570184),
    'Jogeshwari (E)': LatLng(19.1411949, 72.856634),
    'Mogra': LatLng(19.1284731, 72.8560885),
    'Gundavali': LatLng(19.1187756, 72.8549076),
  };

  Timer? _timer;
  GoogleMapController? _mapController;
  int _totalSeconds = 0;
  int _currentSecond = 0;
  String _timeString = "--:--";
  bool _isCompletingRide = false;

  LatLng? _taxiPosition;
  BitmapDescriptor? _taxiIcon;
  late final List<String> _routeStopNames;
  late final List<LatLng> _routePoints;

  @override
  void initState() {
    super.initState();
    _routeStopNames = _buildRouteStopNames();
    _routePoints = _routeStopNames
        .map((name) => _mumbaiSuburbs[name])
        .whereType<LatLng>()
        .toList();

    if (_routePoints.isEmpty) {
      _routePoints.addAll([widget.startPos, widget.endPos]);
    }

    _taxiPosition = _routePoints.first;
    _totalSeconds = _tripDurationSeconds;
    _timeString = _formatDuration(_totalSeconds);

    _loadCustomIcon();
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _loadCustomIcon() async {
    try {
      _taxiIcon = await BitmapDescriptor.asset(
        const ImageConfiguration(size: Size(48, 48)),
        'assets/images/taxi.png',
      );
      if (mounted) setState(() {});
    } catch (e) {
      debugPrint("Icon Error: $e");
    }
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      final nextSecond = _currentSecond + 1;
      final hasArrived = nextSecond >= _totalSeconds;

      setState(() {
        _currentSecond = hasArrived ? _totalSeconds : nextSecond;
        final remaining = _totalSeconds - _currentSecond;
        _timeString = hasArrived ? "Arrived" : _formatDuration(remaining);
        _taxiPosition = hasArrived
            ? _routePoints.last
            : _calculateRoutePosition(_currentSecond / _totalSeconds);
      });
      unawaited(_syncMapCamera());

      if (hasArrived) {
        timer.cancel();
      }
    });
  }

  List<String> _buildRouteStopNames() {
    final pickupIndex = _orderedStops.indexOf(widget.origin.trim());
    final destinationIndex = _orderedStops.indexOf(widget.destination.trim());

    if (pickupIndex == -1 || destinationIndex == -1) {
      return const <String>[];
    }

    if (pickupIndex <= destinationIndex) {
      return _orderedStops.sublist(pickupIndex, destinationIndex + 1);
    }

    return _orderedStops
        .sublist(destinationIndex, pickupIndex + 1)
        .reversed
        .toList();
  }

  String _formatDuration(int totalSeconds) {
    final min = totalSeconds ~/ 60;
    final sec = totalSeconds % 60;
    return "${min.toString().padLeft(2, '0')}:${sec.toString().padLeft(2, '0')}";
  }

  LatLng _calculateIntermediatePoint(
      LatLng start, LatLng end, double fraction) {
    final lat = start.latitude + (end.latitude - start.latitude) * fraction;
    final lng = start.longitude + (end.longitude - start.longitude) * fraction;
    return LatLng(lat, lng);
  }

  LatLng _calculateRoutePosition(double progress) {
    if (_routePoints.length <= 1) {
      return _routePoints.first;
    }

    final clampedProgress = progress.clamp(0.0, 1.0);
    final segmentCount = _routePoints.length - 1;
    final totalProgress = clampedProgress * segmentCount;
    final segmentIndex = min(totalProgress.floor(), segmentCount - 1);
    final segmentProgress = totalProgress - segmentIndex;

    return _calculateIntermediatePoint(
      _routePoints[segmentIndex],
      _routePoints[segmentIndex + 1],
      segmentProgress,
    );
  }

  Future<void> _syncMapCamera() async {
    final taxiPosition = _taxiPosition;
    final controller = _mapController;
    if (taxiPosition == null || controller == null) {
      return;
    }

    await controller.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(target: taxiPosition, zoom: 15),
      ),
    );
  }

  Future<void> _openGoogleMapsNavigation() async {
    final googleMapsUri = Uri.parse(
      "google.navigation:q=${widget.endPos.latitude},${widget.endPos.longitude}&mode=d",
    );
    final appleMapsUri = Uri.parse(
      "https://maps.apple.com/?q=${widget.endPos.latitude},${widget.endPos.longitude}",
    );

    if (await canLaunchUrl(googleMapsUri)) {
      await launchUrl(googleMapsUri);
    } else if (await canLaunchUrl(appleMapsUri)) {
      await launchUrl(appleMapsUri);
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Could not open navigation app")),
      );
    }
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

  Future<void> _completeRide() async {
    if (_isCompletingRide) {
      return;
    }

    if (mounted) {
      setState(() => _isCompletingRide = true);
    }

    try {
      await _rideService.completeRide(
        widget.rideId,
        paymentMethod: widget.paymentMethod,
      );
      if (!mounted) return;

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => RideRatingScreen(rideId: widget.rideId),
        ),
      );
    } catch (error, stackTrace) {
      debugPrint('Ride completion update failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      if (!mounted) return;

      setState(() => _isCompletingRide = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not complete trip: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final carModel = _getMumbaiCarModel(widget.taxi.driverName);
    final displayedFare = finalFare > 0 ? finalFare : widget.fare;
    final paymentLabel = widget.paymentMethod.trim().toLowerCase() == 'cash'
        ? 'To Pay:'
        : 'Fare Paid';

    return Scaffold(
      appBar: AppBar(
        title: const Text("Taxigo Live Ride"),
        backgroundColor: const Color(0xFFFFC107),
        automaticallyImplyLeading: false,
      ),
      body: Column(
        children: [
          Expanded(
            flex: 4,
            child: Stack(
              alignment: Alignment.center,
              children: [
                GoogleMap(
                  initialCameraPosition:
                      CameraPosition(target: _routePoints.first, zoom: 14),
                  onMapCreated: (controller) => _mapController = controller,
                  polylines: {
                    Polyline(
                      polylineId: const PolylineId('nodal_route'),
                      points: _routePoints,
                      width: 5,
                      color: const Color(0xFF1A73E8),
                    ),
                  },
                  markers: {
                    ..._buildNodalMarkers(),
                    Marker(
                      markerId: const MarkerId('moving_taxi'),
                      position: _taxiPosition ?? _routePoints.first,
                      icon: _taxiIcon ?? BitmapDescriptor.defaultMarker,
                      anchor: const Offset(0.5, 0.5),
                    ),
                  },
                ),
                Positioned(
                  top: 20,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black87,
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: Text(
                      _timeString == "Arrived"
                          ? "Taxi Arrived!"
                          : "Arriving in $_timeString",
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 6,
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
                boxShadow: [BoxShadow(blurRadius: 10, color: Colors.black12)],
              ),
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    Row(
                      children: [
                        const CircleAvatar(
                          radius: 30,
                          backgroundColor: Colors.grey,
                          child: Icon(
                            Icons.person,
                            color: Colors.white,
                            size: 30,
                          ),
                        ),
                        const SizedBox(width: 15),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.taxi.driverName,
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                "${widget.taxi.licensePlate} - $carModel",
                                style: const TextStyle(color: Colors.grey),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.phone, color: Colors.green),
                          onPressed: () {},
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.phone_android,
                            color: Colors.grey,
                            size: 20,
                          ),
                          const SizedBox(width: 10),
                          Text(
                            _driverPhone,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const Spacer(),
                          const Text(
                            "Contact Driver",
                            style: TextStyle(color: Colors.blue, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 15),
                      child: Divider(),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          paymentLabel,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey,
                          ),
                        ),
                        Text(
                          "₹$displayedFare",
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 15),
                    ElevatedButton.icon(
                      onPressed: _openGoogleMapsNavigation,
                      icon: const Icon(Icons.navigation),
                      label: const Text("OPEN IN GOOGLE MAPS"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 50),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 25),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.black,
                          foregroundColor: Colors.white,
                        ),
                        onPressed: () => unawaited(_completeRide()),
                        child: _isCompletingRide
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text(
                                "END DEMO",
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Set<Marker> _buildNodalMarkers() {
    final markers = <Marker>{};
    for (var i = 0; i < _routePoints.length; i++) {
      final stopName =
          i < _routeStopNames.length ? _routeStopNames[i] : 'Stop ${i + 1}';
      final isStart = i == 0;
      final isEnd = i == _routePoints.length - 1;

      markers.add(
        Marker(
          markerId: MarkerId('route_stop_$i'),
          position: _routePoints[i],
          icon: BitmapDescriptor.defaultMarkerWithHue(
            isStart
                ? BitmapDescriptor.hueGreen
                : isEnd
                    ? BitmapDescriptor.hueRed
                    : BitmapDescriptor.hueYellow,
          ),
          infoWindow: InfoWindow(title: stopName),
          onTap: isEnd ? _openGoogleMapsNavigation : null,
        ),
      );
    }
    return markers;
  }
}
