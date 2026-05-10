import 'package:flutter/material.dart';
import 'dart:async';
import 'package:taxigo/main.dart'; 
import 'get_started_screen.dart';
import 'home_screen.dart';
import 'profile_setup_screen.dart'; // ✅ Added for mandatory profile check

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
    _animation = Tween<double>(begin: -200, end: 200).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    _animationController.forward();

    // After a delay, check the user's session and profile status
    Timer(const Duration(seconds: 2, milliseconds: 500), _redirect);
  }

  /// Checks the session and ensures the user has a profile
  Future<void> _redirect() async {
    if (!mounted) return;

    try {
      final session = supabase.auth.currentSession;
      
      if (session != null) {
        final userId = session.user.id;

        // ✅ MANDATORY PROFILE CHECK: Look for name in passengers table
        final profile = await supabase
            .from('passengers')
            .select('full_name')
            .eq('id', userId)
            .maybeSingle();

        if (!mounted) return;

        if (profile != null && profile['full_name'] != null) {
          // User has completed profile setup, go to Home
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (context) => const HomeScreen()),
          );
        } else {
          // Logged in but profile is empty, force Setup
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (context) => const ProfileSetupScreen()),
          );
        }
      } else {
        // No session found
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const GetStartedScreen()),
        );
      }
    } catch (e) {
      debugPrint('Error during splash redirect: $e');
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const GetStartedScreen()),
      );
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFC107),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(
              'assets/images/logo.png',
              width: 200,
              height: 200,
              fit: BoxFit.contain,
            ),
            const SizedBox(height: 60),
            AnimatedBuilder(
              animation: _animation,
              builder: (context, child) {
                return Transform.translate(
                  offset: Offset(_animation.value, 0),
                  child: SizedBox(
                    width: 150,
                    height: 80,
                    child: Image.asset(
                      'assets/images/taxi.png',
                      fit: BoxFit.contain,
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }
}