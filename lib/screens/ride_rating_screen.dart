import 'package:flutter/material.dart';

import '../services/booking_service.dart';
import 'home_screen.dart';

class RideRatingScreen extends StatefulWidget {
  final String rideId;

  const RideRatingScreen({
    super.key,
    required this.rideId,
  });

  @override
  State<RideRatingScreen> createState() => _RideRatingScreenState();
}

class _RideRatingScreenState extends State<RideRatingScreen> {
  final _bookingService = BookingService();
  final _feedbackController = TextEditingController();

  int _selectedRating = 0;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _feedbackController.dispose();
    super.dispose();
  }

  Future<void> _showPointsEarnedPopup() {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Reward Points Added'),
        content: const Text('You got 5 reward points! ⭐'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _submitRating() async {
    if (_selectedRating <= 0 || _isSubmitting) {
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      await _bookingService.submitRating(
        rideId: widget.rideId,
        rating: _selectedRating,
        feedback: _feedbackController.text.trim(),
      );

      if (!mounted) {
        return;
      }

      await _showPointsEarnedPopup();
      if (!mounted) {
        return;
      }

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const HomeScreen()),
        (route) => false,
      );
    } catch (e) {
      if (!mounted) {
        return;
      }

      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to submit rating: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Rate Your Ride'),
        backgroundColor: const Color(0xFFFFC107),
        automaticallyImplyLeading: false,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 12),
            const Text(
              'How was your trip?',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (index) {
                return IconButton(
                  onPressed: _isSubmitting
                      ? null
                      : () => setState(() => _selectedRating = index + 1),
                  icon: Icon(
                    Icons.star,
                    size: 36,
                    color: index < _selectedRating
                        ? const Color(0xFFFFC107)
                        : Colors.grey.shade300,
                  ),
                );
              }),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _feedbackController,
              maxLines: 4,
              enabled: !_isSubmitting,
              decoration: const InputDecoration(
                labelText: 'Feedback (optional)',
                border: OutlineInputBorder(),
              ),
            ),
            const Spacer(),
            SizedBox(
              height: 50,
              child: ElevatedButton(
                onPressed: _selectedRating > 0 && !_isSubmitting
                    ? _submitRating
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black,
                  foregroundColor: Colors.white,
                ),
                child: _isSubmitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        'Submit Rating',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
