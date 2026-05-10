// lib/widgets/live_map_widget.dart
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:async';
import '../constants.dart';
import '../models/pickup_point.dart';
import '../models/daily_route.dart';

class LiveMapWidget extends StatefulWidget {
  final DailyRoute? dailyRoute;
  final Function(Position)? onLocationUpdate;

  const LiveMapWidget({
    Key? key,
    this.dailyRoute,
    this.onLocationUpdate,
  }) : super(key: key);

  @override
  State<LiveMapWidget> createState() => _LiveMapWidgetState();
}

class _LiveMapWidgetState extends State<LiveMapWidget> {
  GoogleMapController? _mapController;
  Position? _currentPosition;
  StreamSubscription<Position>? _positionStream;
  final Set<Marker> _markers = {};
  bool _isLoading = true;
  String? _errorMessage;

  final List<PickupPoint> _pickupPoints = [];
  bool _isAddingPickupPoint = false;

  @override
  void initState() {
    super.initState();
    _initializeLocation();
  }

  @override
  void dispose() {
    _positionStream?.cancel();
    _mapController?.dispose();
    _mapController = null;
    super.dispose();
  }

  Future<void> _initializeLocation() async {
    setState(() => _isLoading = true);
    try {
      final hasPermission = await _requestLocationPermission();
      if (!hasPermission) {
        setState(() {
          _errorMessage = 'Location permission is required';
          _isLoading = false;
        });
        return;
      }

      if (!await Geolocator.isLocationServiceEnabled()) {
        setState(() {
          _errorMessage = 'Please enable location services';
          _isLoading = false;
        });
        return;
      }

      final position = await Geolocator.getCurrentPosition();
      setState(() {
        _currentPosition = position;
        _isLoading = false;
      });

      _startLocationTracking();
      _updateMarkers();
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to get location: $e';
        _isLoading = false;
      });
    }
  }

  Future<bool> _requestLocationPermission() async {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.deniedForever) {
      await openAppSettings();
      return false;
    }
    return permission == LocationPermission.always || permission == LocationPermission.whileInUse;
  }

  void _startLocationTracking() {
    _positionStream = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10,
      ),
    ).listen(
      (position) {
        if (!mounted) return;
        setState(() => _currentPosition = position);
        _updateCamera(position);
        _updateMarkers();
        widget.onLocationUpdate?.call(position);
      },
      onError: (error) {
        if (mounted) {
          setState(() {
            _errorMessage = 'Location tracking error: $error';
          });
        }
      },
    );
  }

  void _updateCamera(Position position) {
    if (_mapController != null) {
      _mapController!.animateCamera(
        CameraUpdate.newLatLng(
          LatLng(position.latitude, position.longitude),
        ),
      );
    }
  }

  void _centerOnUser() {
    if (_currentPosition == null || _mapController == null) return;
    _mapController!.animateCamera(
      CameraUpdate.newLatLngZoom(
        LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
        16,
      ),
    );
  }

  void _updateMarkers() {
    final markers = <Marker>{};

    if (_currentPosition != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('current_location'),
          position: LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
          infoWindow: const InfoWindow(title: 'You are here'),
        ),
      );
    }

    for (int i = 0; i < _pickupPoints.length; i++) {
      final point = _pickupPoints[i];
      markers.add(
        Marker(
          markerId: MarkerId('pickup_$i'),
          position: LatLng(point.latitude, point.longitude),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
          infoWindow: InfoWindow(title: point.name, snippet: point.description),
          onTap: () => _showPickupOptions(point, i),
        ),
      );
    }

    if (widget.dailyRoute?.startLocation != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('start'),
          position: LatLng(
            widget.dailyRoute!.startLocation!.latitude,
            widget.dailyRoute!.startLocation!.longitude,
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
          infoWindow: InfoWindow(title: 'Start: ${widget.dailyRoute!.startLocationName}'),
        ),
      );
    }

    if (widget.dailyRoute?.endLocation != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('end'),
          position: LatLng(
            widget.dailyRoute!.endLocation!.latitude,
            widget.dailyRoute!.endLocation!.longitude,
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
          infoWindow: InfoWindow(title: 'End: ${widget.dailyRoute!.endLocationName}'),
        ),
      );
    }

    setState(() {
      _markers.clear();
      _markers.addAll(markers);
    });
  }

  void _showPickupOptions(PickupPoint point, int index) {
    showModalBottomSheet(
      context: context,
      builder: (_) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.edit),
            title: const Text('Edit'),
            onTap: () {
              Navigator.pop(context);
              _editPickupPoint(point, index);
            },
          ),
          ListTile(
            leading: const Icon(Icons.delete),
            title: const Text('Remove'),
            onTap: () {
              Navigator.pop(context);
              setState(() {
                _pickupPoints.removeAt(index);
              });
              _updateMarkers();
            },
          ),
        ],
      ),
    );
  }

  void _editPickupPoint(PickupPoint point, int index) {
    final nameCtrl = TextEditingController(text: point.name);
    final descCtrl = TextEditingController(text: point.description);

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Edit Pickup Point'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Name')),
            TextField(controller: descCtrl, decoration: const InputDecoration(labelText: 'Description')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _pickupPoints[index] = PickupPoint(
                  id: point.id,
                  name: nameCtrl.text,
                  description: descCtrl.text,
                  latitude: point.latitude,
                  longitude: point.longitude,
                  createdAt: point.createdAt,
                );
              });
              _updateMarkers();
              Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  // Stub for map tap to add pickup points (or disable if you don't want)
  void _onMapTap(LatLng position) {
    if (_isAddingPickupPoint) {
      final newPoint = PickupPoint(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: 'New Pickup',
        description: 'Description',
        latitude: position.latitude,
        longitude: position.longitude,
        createdAt: DateTime.now(),
      );
      setState(() {
        _pickupPoints.add(newPoint);
        _isAddingPickupPoint = false;
      });
      _updateMarkers();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return Center(child: Text(_errorMessage!));
    }

    return Stack(
      children: [
        GoogleMap(
          initialCameraPosition: CameraPosition(
            target: LatLng(
              _currentPosition?.latitude ?? 0,
              _currentPosition?.longitude ?? 0,
            ),
            zoom: 16,
          ),
          onMapCreated: (controller) {
            _mapController = controller;
            if (_currentPosition != null) {
              _updateCamera(_currentPosition!);
            }
          },
          myLocationEnabled: true,
          markers: _markers,
          onTap: _onMapTap,
        ),
        Positioned(
          top: 16,
          right: 16,
          child: Column(
            children: [
              FloatingActionButton(
                heroTag: 'add',
                mini: true,
                onPressed: () => setState(() => _isAddingPickupPoint = !_isAddingPickupPoint),
                child: Icon(_isAddingPickupPoint ? Icons.close : Icons.add_location),
              ),
              const SizedBox(height: 8),
              FloatingActionButton(
                heroTag: 'center',
                mini: true,
                onPressed: _centerOnUser,
                child: const Icon(Icons.my_location),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
