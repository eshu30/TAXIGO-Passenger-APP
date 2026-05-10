import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../constants.dart';
import '../services/ride_service.dart';
import '../widgets/custom_button.dart';

class SearchingScreen extends StatefulWidget {
  final String rideId;

  const SearchingScreen({
    super.key,
    required this.rideId,
  });

  @override
  State<SearchingScreen> createState() => _SearchingScreenState();
}

class _SearchingScreenState extends State<SearchingScreen> {
  final _rideService = RideService();
  Stream<Map<String, dynamic>>? _rideStatusStream;
  String? _subscriptionError;
  bool _hasOpenedLiveMap = false;

  @override
  void initState() {
    super.initState();
    _subscribeToRideStatus();
  }

  @override
  void didUpdateWidget(covariant SearchingScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.rideId != widget.rideId) {
      _hasOpenedLiveMap = false;
      _subscribeToRideStatus();
    }
  }

  void _subscribeToRideStatus() {
    try {
      final stream = _rideService.watchRideStatus(widget.rideId);
      setState(() {
        _subscriptionError = null;
        _rideStatusStream = stream;
      });
    } catch (e) {
      if (e is RealtimeSubscribeException) {
        setState(() {
          _subscriptionError = e.toString();
          _rideStatusStream = null;
        });
        return;
      }
      rethrow;
    }
  }

  void _openLiveMap() {
    if (_hasOpenedLiveMap) return;
    _hasOpenedLiveMap = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, '/live_map');
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF111111),
      appBar: AppBar(
        title: const Text('Searching Ride'),
        backgroundColor: AppColors.primaryYellow,
        foregroundColor: Colors.black,
      ),
      body: SafeArea(
        child: _subscriptionError != null
            ? _RetryState(
                message: _subscriptionError!,
                onRetry: _subscribeToRideStatus,
              )
            : StreamBuilder<Map<String, dynamic>>(
                stream: _rideStatusStream,
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    if (snapshot.error is RealtimeSubscribeException) {
                      return _RetryState(
                        message: snapshot.error.toString(),
                        onRetry: _subscribeToRideStatus,
                      );
                    }
                    return _CenteredMessage(
                      icon: Icons.error_outline,
                      title: 'Unable to fetch ride status',
                      subtitle: snapshot.error.toString(),
                    );
                  }

                  if (snapshot.hasData) {
                    final status = snapshot.data!['status']
                        ?.toString()
                        .trim()
                        .toLowerCase();
                    if (status == 'accepted') {
                      _openLiveMap();
                    }
                  }

                  return const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(
                      child: _SearchingState(),
                    ),
                  );
                },
              ),
      ),
    );
  }
}

class _SearchingState extends StatelessWidget {
  const _SearchingState();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 120,
          height: 120,
          decoration: BoxDecoration(
            color: const Color(0xFFFFC107).withAlpha(36),
            shape: BoxShape.circle,
          ),
          child: const Center(
            child: SizedBox(
              width: 54,
              height: 54,
              child: CircularProgressIndicator(
                strokeWidth: 4,
                valueColor:
                    AlwaysStoppedAnimation<Color>(AppColors.primaryYellow),
              ),
            ),
          ),
        ),
        const SizedBox(height: 28),
        const Text(
          'Searching for Drivers...',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 30,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          'We are matching you with the nearest available driver in realtime.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 16,
            color: Colors.white70,
            height: 1.5,
          ),
        ),
      ],
    );
  }
}

class _CenteredMessage extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _CenteredMessage({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: AppColors.primaryYellow),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 15,
                color: Colors.white70,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RetryState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _RetryState({
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.wifi_off_rounded,
                size: 56, color: AppColors.primaryYellow),
            const SizedBox(height: 16),
            const Text(
              'Realtime connection timed out',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 15,
                color: Colors.white70,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 24),
            CustomButton(
              text: 'Retry',
              onPressed: onRetry,
            ),
          ],
        ),
      ),
    );
  }
}
