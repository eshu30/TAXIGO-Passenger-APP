import 'package:flutter/material.dart';
import '../services/booking_service.dart'; // Ensure this import exists

class MessageScreen extends StatefulWidget {
  const MessageScreen({super.key});

  @override
  State<MessageScreen> createState() => _MessageScreenState();
}

class _MessageScreenState extends State<MessageScreen> {
  final _bookingService = BookingService();
  
  // This list will hold your completed rides to be rated
  List<Map<String, dynamic>> _completedRides = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchCompletedRides();
  }

  Future<void> _fetchCompletedRides() async {
    try {
      final history = await _bookingService.getBookingHistory();
      // Filter only completed rides that haven't been rated yet (logic depends on your needs)
      // For now, we just show all completed rides
      setState(() {
        _completedRides = history.where((ride) => 
            ride['status'].toString().toLowerCase() == 'completed').toList();
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
      print('Error loading messages: $e');
    }
  }

  void _showRatingDialog(Map<String, dynamic> booking) {
    int selectedRating = 0;
    final feedbackController = TextEditingController();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Rate Your Ride', style: TextStyle(fontWeight: FontWeight.bold)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('How was your ride with ${booking['driver_name']}?'),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(5, (index) {
                      return IconButton(
                        onPressed: () => setState(() => selectedRating = index + 1),
                        icon: Icon(
                          Icons.star,
                          size: 40,
                          color: index < selectedRating ? const Color(0xFFFFC107) : Colors.grey.shade300,
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: feedbackController,
                    decoration: const InputDecoration(
                      hintText: 'Add your feedback (optional)',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 3,
                  ),
                ],
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                ElevatedButton(
                  onPressed: selectedRating > 0
                      ? () => _submitRating(booking, selectedRating, feedbackController.text)
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFFC107),
                    foregroundColor: Colors.black,
                  ),
                  child: const Text('Submit'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _submitRating(Map<String, dynamic> booking, int rating, String feedback) async {
    try {
      // ✅ FIX: Use 'rideId' (String) instead of 'bookingId'
      await _bookingService.submitRating(
        rideId: booking['id'].toString(), // Convert UUID to String
        rating: rating,
        feedback: feedback.trim(),
      );

      if (!mounted) return;
      Navigator.pop(context); // Close dialog
      
      // Refresh list
      _fetchCompletedRides();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('🌟 Thank you! You earned 5 bonus points!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Rating failed: ${e.toString()}'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Messages & Notifications'),
        backgroundColor: const Color(0xFFFFC107),
      ),
      body: _isLoading 
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFFFC107)))
          : _completedRides.isEmpty
              ? const Center(child: Text("No new notifications"))
              : ListView.builder(
                  itemCount: _completedRides.length,
                  itemBuilder: (context, index) {
                    final ride = _completedRides[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: ListTile(
                        leading: const CircleAvatar(
                          backgroundColor: Colors.green,
                          child: Icon(Icons.check, color: Colors.white),
                        ),
                        title: Text('Ride Completed: ${ride['destination']}'),
                        subtitle: Text('Tap to rate your driver ${ride['driver_name']}'),
                        trailing: const Icon(Icons.star_rate, color: Colors.amber),
                        onTap: () => _showRatingDialog(ride),
                      ),
                    );
                  },
                ),
    );
  }
}