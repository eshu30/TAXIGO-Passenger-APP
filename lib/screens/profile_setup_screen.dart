// lib/screens/profile_setup_screen.dart

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/auth_service.dart';
import 'home_screen.dart';

class ProfileSetupScreen extends StatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _picker = ImagePicker();
  final _authService = AuthService();

  Uint8List? _imageBytes;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _fetchUserPhone();
  }

  void _fetchUserPhone() {
    final user = Supabase.instance.client.auth.currentUser;
    if (user?.phone != null) {
      setState(() {
        _phoneController.text = user!.phone!;
      });
    }
  }

  Future<void> _handleSavePressed() async {
    try {
      await _saveProfile();
    } catch (_) {
      _showSnackBar('Could not save your profile right now.');
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) {
        throw 'User session not found';
      }

      await _authService.updateProfile(
        fullName: _nameController.text.trim(),
        email: _emailController.text.trim(),
        phone: _phoneController.text.isNotEmpty
            ? _phoneController.text
            : user.phone,
        imageBytes: _imageBytes,
        onboardingCompleted: true,
      );

      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const HomeScreen()),
        (route) => false,
      );
    } catch (e) {
      if (mounted) {
        _showSnackBar('Could not save your profile right now.');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? image = await _picker.pickImage(
        source: source,
        imageQuality: 80,
        maxWidth: 512,
      );

      if (image != null) {
        final bytes = await image.readAsBytes();
        setState(() {
          _imageBytes = bytes;
        });
      }
    } catch (e) {
      debugPrint('Picker Error: $e');
    }
  }

  void _showImagePickerOptions() {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: <Widget>[
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Photo Library'),
              onTap: () {
                _pickImage(ImageSource.gallery);
                Navigator.of(context).pop();
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera),
              title: const Text('Camera'),
              onTap: () {
                _pickImage(ImageSource.camera);
                Navigator.of(context).pop();
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Setup Your Profile'),
        backgroundColor: const Color(0xFFFFC107),
        automaticallyImplyLeading: false,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              const SizedBox(height: 20),
              GestureDetector(
                onTap: _showImagePickerOptions,
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.grey.shade200,
                    border: Border.all(
                      color: const Color(0xFFFFC107),
                      width: 3,
                    ),
                  ),
                  child: ClipOval(
                    child: _imageBytes != null
                        ? Image.memory(
                            _imageBytes!,
                            fit: BoxFit.cover,
                            width: 120,
                            height: 120,
                          )
                        : const Icon(
                            Icons.add_a_photo,
                            size: 40,
                            color: Colors.grey,
                          ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Tap to upload a photo',
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 40),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Full Name',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.person_outline),
                ),
                validator: (val) =>
                    val!.isEmpty ? 'Please enter your name' : null,
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(
                  labelText: 'Email (Optional)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.email_outlined),
                ),
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _phoneController,
                readOnly: true,
                decoration: InputDecoration(
                  labelText: 'Phone Number',
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.phone),
                  fillColor: Colors.grey.shade100,
                  filled: true,
                ),
              ),
              const SizedBox(height: 40),
              SizedBox(
                height: 56,
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _handleSavePressed,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFFC107),
                    foregroundColor: Colors.black,
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.black)
                      : const Text(
                          'SAVE & CONTINUE',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
