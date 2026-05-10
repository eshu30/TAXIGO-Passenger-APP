import 'package:flutter/material.dart';
import 'auth_screen.dart';
import '../widgets/wave_clipper.dart'; // This widget creates the wave design

class GetStartedScreen extends StatelessWidget {
  const GetStartedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: const Color(0xFFFFC107),
        elevation: 0,
        centerTitle: true,
        title: Image.asset(
          'assets/images/logo.png',
          height: 40,
          fit: BoxFit.contain,
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    'Get\nStarted!',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 48,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 60),
                  // A single button simplifies the user's choice.
                  _buildAuthButton(
                    context,
                    text: 'Continue with Phone Number',
                    onPressed: () => _navigateToAuth(context),
                  ),
                ],
              ),
            ),
          ),
          // This is the decorative wave design at the bottom.
          _buildWaveDecoration(),
        ],
      ),
    );
  }

  /// Builds a consistently styled authentication button.
  Widget _buildAuthButton(BuildContext context, {required String text, required VoidCallback onPressed}) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFFFC107),
          foregroundColor: Colors.black,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
        ),
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  /// Navigates to the authentication screen.
  void _navigateToAuth(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const AuthScreen(),
      ),
    );
  }

  /// Builds the stacked wave decoration for the bottom of the screen.
  Widget _buildWaveDecoration() {
    return SizedBox(
      height: 200,
      child: Stack(
        children: [
          _waveLayer(clipper: WaveClipper(0), height: 200, color: const Color(0xFFFFE082)),
          _waveLayer(clipper: WaveClipper(20), height: 180, color: const Color(0xFFFFC107)),
          _waveLayer(clipper: WaveClipper(40), height: 160, color: const Color(0xFFFF8F00)),
        ],
      ),
    );
  }

  Widget _waveLayer({required CustomClipper<Path> clipper, required double height, required Color color}) {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: ClipPath(
        clipper: clipper,
        child: Container(
          height: height,
          color: color,
        ),
      ),
    );
  }
}

