// lib/screens/profile_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/auth_service.dart';
import 'auth_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _authService = AuthService();
  final _picker = ImagePicker();
  final _supabase = Supabase.instance.client;

  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();

  Map<String, dynamic>? _profileData;
  Uint8List? _newAvatarBytes;
  bool _isLoading = true;
  bool _isEditing = false;
  bool _removeAvatar = false;
  double _calculatedAvgRating = 0.0;

  @override
  void initState() {
    super.initState();
    _fetchProfileAndRating();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _fetchProfileAndRating() async {
    setState(() => _isLoading = true);
    try {
      final data = await _authService.getProfile();
      final userId = _supabase.auth.currentUser?.id;

      if (userId != null) {
        final List<dynamic> ratingsData = await _supabase
            .from('ratings')
            .select('rating')
            .eq('passenger_id', userId);

        if (ratingsData.isNotEmpty) {
          double sum = 0;
          for (var item in ratingsData) {
            sum += (item['rating'] as num).toDouble();
          }
          _calculatedAvgRating = sum / ratingsData.length;
        }
      }

      if (mounted) {
        setState(() {
          _profileData = data;
          _nameController.text = data['full_name'] ?? '';
          _phoneController.text = data['phone'] ?? '';
          _emailController.text = data['email'] ?? '';
          _newAvatarBytes = null;
          _removeAvatar = false;
        });
      }
    } catch (e) {
      if (mounted) _showSnackBar('Error: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _saveProfile() async {
    if (_nameController.text.trim().isEmpty) {
      _showSnackBar('Name cannot be empty.');
      return;
    }
    setState(() => _isLoading = true);
    try {
      await _authService.updateProfile(
        fullName: _nameController.text.trim(),
        email: _emailController.text.trim(),
        phone: _phoneController.text.trim(),
        imageBytes: _newAvatarBytes,
        removeImage: _removeAvatar,
      );

      if (mounted) {
        _showSnackBar('Profile updated!', isError: false);
        await _fetchProfileAndRating();
        setState(() => _isEditing = false);
      }
    } catch (e) {
      if (mounted) _showSnackBar('Update failed: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleSavePressed() async {
    try {
      await _saveProfile();
    } catch (_) {
      _showSnackBar('Could not save your profile right now.');
    }
  }

  Future<void> _signOut() async {
    try {
      await _authService.signOut();
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const AuthScreen()),
          (route) => false,
        );
      }
    } catch (e) {
      if (mounted) _showSnackBar('Sign out failed.');
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final image = await _picker.pickImage(
          source: source, imageQuality: 80, maxWidth: 512);
      if (image != null) {
        final bytes = await image.readAsBytes();
        setState(() {
          _newAvatarBytes = bytes;
          _removeAvatar = false;
        });
      }
    } catch (e) {
      _showSnackBar('Image pick failed: ${e.toString()}');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: const Color(0xFFFFC107),
        elevation: 0,
        title: const Text('My Profile',
            style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        iconTheme: const IconThemeData(color: Colors.black),
        actions: [
          if (!_isLoading && _profileData != null)
            TextButton(
              onPressed: () async {
                if (_isEditing) {
                  await _handleSavePressed();
                } else {
                  setState(() => _isEditing = true);
                }
              },
              child: Text(
                _isEditing ? 'SAVE' : 'EDIT',
                style: const TextStyle(
                    color: Colors.black, fontWeight: FontWeight.bold),
              ),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFFFFC107)))
          : _profileData == null
              ? _buildErrorState()
              : _buildProfileView(),
    );
  }

  Widget _buildProfileView() {
    final String? avatarUrl = _profileData?['profile_pic_url']?.toString();
    final points = _profileData?['points'] ?? 0;
    ImageProvider? avatarImage;
    if (_newAvatarBytes != null) {
      avatarImage = MemoryImage(_newAvatarBytes!);
    } else if (!_removeAvatar && avatarUrl != null) {
      avatarImage = NetworkImage(avatarUrl);
    }

    // ✅ Replaced "#USER" placeholder with the real Short ID from the database
    final String shortId = _profileData?['short_id'] ?? 'USER';

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
      children: [
        Center(
          child: Column(
            children: [
              // ✅ UI FIX: Picked image displays immediately via FileImage
              CircleAvatar(
                radius: 60,
                backgroundColor: Colors.grey.shade200,
                backgroundImage: avatarImage,
                child: (_newAvatarBytes == null &&
                        (_removeAvatar || avatarUrl == null))
                    ? const Icon(Icons.person, size: 60, color: Colors.grey)
                    : null,
              ),
              if (_isEditing) ...[
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    TextButton.icon(
                      onPressed: _showImagePickerOptions,
                      icon: const Icon(Icons.edit, size: 18),
                      label: const Text("Change"),
                    ),
                    if (avatarUrl != null || _newAvatarBytes != null)
                      TextButton.icon(
                        onPressed: () {
                          setState(() {
                            _newAvatarBytes = null;
                            _removeAvatar = true;
                          });
                        },
                        icon: const Icon(Icons.delete,
                            size: 18, color: Colors.red),
                        label: const Text("Remove",
                            style: TextStyle(color: Colors.red)),
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 24),

        Row(
          children: [
            _buildStatCard('Points', points.toString(), Colors.orange.shade50,
                Colors.orange),
            const SizedBox(width: 16),
            _buildStatCard(
                'Avg Rating',
                _calculatedAvgRating.toStringAsFixed(1),
                Colors.green.shade50,
                Colors.green),
          ],
        ),

        const SizedBox(height: 24),

        // ✅ PASSENGER ID SECTION
        Container(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
          decoration: BoxDecoration(
            color: const Color(0xFFFFC107).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFFFC107), width: 2),
          ),
          child: Column(
            children: [
              const Text("PASSENGER ID",
                  style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Colors.black54,
                      letterSpacing: 1.2)),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text("#$shortId",
                      style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                          color: Colors.black87,
                          letterSpacing: 2.0)),
                  const SizedBox(width: 10),
                  IconButton(
                    icon: const Icon(Icons.copy, color: Colors.black54),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: shortId));
                      _showSnackBar("ID Copied!", isError: false);
                    },
                  )
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),
        _buildTextField('Full Name', _nameController, Icons.person),
        const SizedBox(height: 16),
        _buildTextField(
            'Email Address', _emailController, Icons.email_outlined),
        const SizedBox(height: 16),
        _buildTextField('Phone Number', _phoneController, Icons.phone,
            readOnly: true),
        const SizedBox(height: 32),

        OutlinedButton.icon(
          onPressed: _signOut,
          icon: const Icon(Icons.logout, color: Colors.red),
          label: const Text('Sign Out',
              style: TextStyle(color: Colors.red, fontSize: 16)),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 12),
            side: BorderSide(color: Colors.grey.shade300),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ],
    );
  }

  Widget _buildTextField(
      String label, TextEditingController controller, IconData icon,
      {bool readOnly = false}) {
    bool isEffectivelyReadOnly = readOnly || !_isEditing;
    return TextFormField(
      controller: controller,
      readOnly: isEffectivelyReadOnly,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon,
            color:
                isEffectivelyReadOnly ? Colors.grey : const Color(0xFFFFC107)),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        filled: isEffectivelyReadOnly,
        fillColor: Colors.grey.shade100,
      ),
    );
  }

  Widget _buildStatCard(
      String title, String value, Color bgColor, Color fgColor) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: fgColor.withValues(alpha: 0.3)),
        ),
        child: Column(
          children: [
            Text(title,
                style: TextStyle(
                    color: Colors.grey.shade700,
                    fontSize: 12,
                    fontWeight: FontWeight.w500)),
            const SizedBox(height: 4),
            Text(value,
                style: TextStyle(
                    color: fgColor, fontSize: 24, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, color: Colors.red, size: 40),
          const SizedBox(height: 16),
          TextButton(
              onPressed: _fetchProfileAndRating,
              child: const Text('Retry loading profile')),
        ],
      ),
    );
  }

  void _showImagePickerOptions() {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return SafeArea(
          child: Wrap(
            children: <Widget>[
              ListTile(
                  leading: const Icon(Icons.photo_library),
                  title: const Text('Photo Library'),
                  onTap: () {
                    _pickImage(ImageSource.gallery);
                    Navigator.of(context).pop();
                  }),
              ListTile(
                  leading: const Icon(Icons.photo_camera),
                  title: const Text('Camera'),
                  onTap: () {
                    _pickImage(ImageSource.camera);
                    Navigator.of(context).pop();
                  }),
            ],
          ),
        );
      },
    );
  }

  void _showSnackBar(String message, {bool isError = true}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text(message),
          backgroundColor: isError ? null : Colors.green,
          behavior: SnackBarBehavior.floating),
    );
  }
}
