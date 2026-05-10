import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/auth_service.dart';
import '../services/booking_service.dart';

class BookingsScreen extends StatefulWidget {
  const BookingsScreen({super.key});

  @override
  State<BookingsScreen> createState() => _BookingsScreenState();
}

class _BookingsScreenState extends State<BookingsScreen> {
  final _authService = AuthService();
  final _bookingService = BookingService();
  final _supabase = Supabase.instance.client;
  int _userPoints = 0;
  late Future<List<Map<String, dynamic>>> _bookingsFuture;

  @override
  void initState() {
    super.initState();
    _bookingsFuture = _loadCompletedBookings();
    unawaited(_refreshBookings());
  }

  Future<void> _refreshBookings() async {
    await _loadUserData();
    if (!mounted) return;
    setState(() {
      _bookingsFuture = _loadCompletedBookings();
    });
    await _bookingsFuture;
  }

  Future<void> _loadUserData() async {
    final profile = await _authService.getProfile();
    if (mounted) {
      setState(() => _userPoints = profile['points'] ?? 0);
    }
  }

  Future<List<Map<String, dynamic>>> _loadCompletedBookings() async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      return [];
    }

    try {
      final response = await _supabase
          .from('rides')
          .select('id, origin, destination, fare, status, created_at')
          .eq('passenger_id', user.id)
          .eq('status', 'completed')
          .order('created_at', ascending: false);

      return List<Map<String, dynamic>>.from(response).map((ride) {
        return {
          'id': ride['id']?.toString() ?? '',
          'origin': ride['origin'] ?? 'Unknown',
          'destination': ride['destination'] ?? 'Unknown',
          'status': ride['status'] ?? 'completed',
          'created_at': ride['created_at'],
          'driver_name': 'Taxigo Driver',
          'fare': (ride['fare'] as num?)?.toDouble() ?? 0,
        };
      }).toList();
    } catch (error) {
      debugPrint('Completed bookings load failed: $error');
      return [];
    }
  }

  String _formatDate(String? dateString) {
    if (dateString == null) return 'Recent';
    try {
      final dateTime = DateTime.parse(dateString).toLocal();
      return DateFormat('d MMM, h:mm a').format(dateTime);
    } catch (e) {
      return 'Recent';
    }
  }

  String _formatFare(num fare) {
    final normalizedFare = fare.toDouble();
    if (normalizedFare == normalizedFare.roundToDouble()) {
      return normalizedFare.toInt().toString();
    }
    return normalizedFare.toStringAsFixed(2);
  }

  void _showRatingDialog(Map<String, dynamic> booking) {
    int selectedRating = 0;
    final feedbackController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Rate Your Ride'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Driver: ${booking['driver_name']}'),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (index) {
                  return IconButton(
                    onPressed: () => setState(() => selectedRating = index + 1),
                    icon: Icon(Icons.star,
                        size: 32,
                        color: index < selectedRating
                            ? const Color(0xFFFFC107)
                            : Colors.grey.shade300),
                  );
                }),
              ),
              TextField(
                  controller: feedbackController,
                  decoration: const InputDecoration(hintText: 'Feedback'))
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel')),
            ElevatedButton(
              onPressed: selectedRating > 0
                  ? () {
                      Navigator.pop(context);
                      // ✅ PASSING RIDE ID AS STRING
                      _submitRating(booking['id'].toString(), selectedRating,
                          feedbackController.text);
                    }
                  : null,
              child: const Text('Submit'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submitRating(String rideId, int rating, String feedback) async {
    try {
      await _bookingService.submitRating(
          rideId: rideId, rating: rating, feedback: feedback);
      await _loadUserData();
      setState(() => _bookingsFuture = _loadCompletedBookings());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Rated! +5 Points'), backgroundColor: Colors.green));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
          title: const Text('Taxigo Bookings'),
          backgroundColor: const Color(0xFFFFC107)),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            color: const Color(0xFFFFF9C4),
            child: Column(children: [
              const Text('Your Points'),
              Text('$_userPoints',
                  style: const TextStyle(
                      fontSize: 32, fontWeight: FontWeight.bold))
            ]),
          ),
          Expanded(
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: _bookingsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final bookings = snapshot.data ?? [];
                if (bookings.isEmpty) {
                  return RefreshIndicator(
                    onRefresh: _refreshBookings,
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: const [
                        SizedBox(height: 180),
                        Center(
                            child: Text(
                                'No bookings found. Pull down to refresh.')),
                      ],
                    ),
                  );
                }

                return RefreshIndicator(
                  onRefresh: _refreshBookings,
                  child: ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    itemCount: bookings.length,
                    itemBuilder: (context, index) {
                      final ride = bookings[index];
                      return Card(
                        margin: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        child: ListTile(
                          leading: const Icon(Icons.local_taxi,
                              color: Color(0xFFFFC107)),
                          title: Text(
                              '${ride['origin']} -> ${ride['destination']}'),
                          subtitle: Text(
                              '₹${_formatFare(ride['fare'] as num)} • ${ride['status']}\n${_formatDate(ride['created_at'])}'),
                          trailing: ElevatedButton(
                            onPressed: () => _showRatingDialog(ride),
                            child: const Text('Rate'),
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
