import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart'; // Required for "Remember Me"
import 'package:supabase_flutter/supabase_flutter.dart';
import 'home_screen.dart';
import 'profile_setup_screen.dart'; // Import this to handle new users

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _phoneController = TextEditingController();
  final _otpController = TextEditingController();
  
  bool _isLoading = false;
  bool _isOtpSent = false;
  
  // Checkbox States
  bool _agreeToTerms = false;
  bool _rememberMe = false; // "Remember Me" toggle state

  @override
  void initState() {
    super.initState();
    _loadSavedPhone(); // Load the saved number when screen opens
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  /// 1. Load phone number from local storage if "Remember Me" was used
  Future<void> _loadSavedPhone() async {
    final prefs = await SharedPreferences.getInstance();
    final savedPhone = prefs.getString('saved_phone');
    if (savedPhone != null && savedPhone.isNotEmpty) {
      setState(() {
        _phoneController.text = savedPhone;
        _rememberMe = true; // Check the box automatically
      });
    }
  }

  /// 2. Send OTP and Save Phone Number if "Remember Me" is checked
  Future<void> _signInWithPhone() async {
    if (_phoneController.text.length != 10) {
      _showSnackBar('Please enter a valid 10-digit number');
      return;
    }
    if (!_agreeToTerms) {
      _showSnackBar('Please agree to the privacy policy');
      return;
    }

    setState(() => _isLoading = true);

    try {
      // --- Handle "Remember Me" Logic ---
      final prefs = await SharedPreferences.getInstance();
      if (_rememberMe) {
        await prefs.setString('saved_phone', _phoneController.text.trim());
      } else {
        await prefs.remove('saved_phone');
      }
      // ----------------------------------

      await Supabase.instance.client.auth.signInWithOtp(
        phone: '+91${_phoneController.text.trim()}',
      );

      setState(() => _isOtpSent = true);
      _showSnackBar('OTP sent successfully!');
      
    } on AuthException catch (e) {
      _showSnackBar(e.message);
    } catch (e) {
      _showSnackBar('Error sending OTP: ${e.toString()}');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  /// 3. Verify OTP and Navigate
  Future<void> _verifyOtp() async {
    if (_otpController.text.length != 6) {
      _showSnackBar('Please enter a 6-digit OTP');
      return;
    }

    setState(() => _isLoading = true);
    try {
      final response = await Supabase.instance.client.auth.verifyOTP(
        type: OtpType.sms,
        token: _otpController.text.trim(),
        phone: '+91${_phoneController.text.trim()}',
      );

      if (response.session != null) {
        if (!mounted) return;
        
        // Check if user has a profile, if not go to Setup, else go Home
        await _checkProfileAndNavigate(response.user!.id);
      }
    } on AuthException catch (e) {
      _showSnackBar(e.message);
    } catch (e) {
      _showSnackBar('Invalid OTP: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Helper to check if profile exists in Supabase
  Future<void> _checkProfileAndNavigate(String userId) async {
    try {
      final data = await Supabase.instance.client
          .from('passengers')
          .select()
          .eq('id', userId)
          .maybeSingle();

      if (!mounted) return;

      if (data != null) {
        // Profile exists -> Go to Home
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const HomeScreen()),
          (route) => false,
        );
      } else {
        // New User -> Go to Profile Setup
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const ProfileSetupScreen()),
          (route) => false,
        );
      }
    } catch (e) {
      // If error (e.g. offline), just go to Home for now
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const HomeScreen()),
        (route) => false,
      );
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.black,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: const Color(0xFFFFC107),
        elevation: 0,
        title: Image.asset('assets/images/logo.png', height: 40),
        centerTitle: true,
        automaticallyImplyLeading: false,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Hello!', style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold)),
            const Text('Join us on this ride', style: TextStyle(color: Colors.grey, fontSize: 16)),
            const SizedBox(height: 30),

            if (!_isOtpSent) ...[
              // --- PHONE INPUT ---
              TextField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                inputFormatters: [LengthLimitingTextInputFormatter(10), FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(
                  labelText: 'Enter your Phone number',
                  prefixIcon: Icon(Icons.phone),
                  border: UnderlineInputBorder(),
                ),
              ),
              const SizedBox(height: 20),

              // --- PRIVACY CHECKBOX ---
              Row(
                children: [
                  Checkbox(
                    value: _agreeToTerms,
                    activeColor: const Color(0xFFFFC107),
                    onChanged: (v) => setState(() => _agreeToTerms = v!),
                  ),
                  const Expanded(child: Text('I agree with privacy policy', style: TextStyle(fontSize: 14))),
                ],
              ),
              
              // --- REMEMBER ME CHECKBOX ---
              Row(
                children: [
                  Checkbox(
                    value: _rememberMe,
                    activeColor: const Color(0xFFFFC107),
                    onChanged: (v) => setState(() => _rememberMe = v!),
                  ),
                  const Text('Remember me', style: TextStyle(fontSize: 14)),
                ],
              ),
              // -----------------------------

              const SizedBox(height: 30),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFFC107),
                    foregroundColor: Colors.black,
                  ),
                  onPressed: _isLoading ? null : _signInWithPhone,
                  child: _isLoading 
                    ? const CircularProgressIndicator(color: Colors.black) 
                    : const Text('SEND OTP', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ),
              ),
            ] else ...[
              // --- OTP INPUT ---
              TextField(
                controller: _otpController,
                keyboardType: TextInputType.number,
                inputFormatters: [LengthLimitingTextInputFormatter(6), FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(
                  labelText: 'Enter 6-digit OTP',
                  prefixIcon: Icon(Icons.lock),
                  border: UnderlineInputBorder(),
                ),
              ),
              const SizedBox(height: 30),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFFC107),
                    foregroundColor: Colors.black,
                  ),
                  onPressed: _isLoading ? null : _verifyOtp,
                  child: _isLoading 
                    ? const CircularProgressIndicator(color: Colors.black) 
                    : const Text('VERIFY OTP', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ),
              ),
              Center(
                child: TextButton(
                  onPressed: () => setState(() => _isOtpSent = false),
                  child: const Text('Change Phone Number', style: TextStyle(color: Colors.grey)),
                ),
              )
            ],
          ],
        ),
      ),
    );
  }
}