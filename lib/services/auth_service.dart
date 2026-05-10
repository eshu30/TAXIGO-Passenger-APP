import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final supabase = Supabase.instance.client;
final avatarBucketName =
    (dotenv.env['SUPABASE_AVATAR_BUCKET']?.trim().isNotEmpty ?? false)
        ? dotenv.env['SUPABASE_AVATAR_BUCKET']!.trim()
        : 'avatars';

/// Merged Service class handling Auth and Profile logic with Supabase.
class AuthService {
  /// Provides the currently signed-in user object, or null if nobody is signed in.
  User? get currentUser => supabase.auth.currentUser;

  /// Provides a real-time stream of authentication state changes.
  Stream<AuthState> get authStateChanges => supabase.auth.onAuthStateChange;

  // --- Authentication Methods ---

  /// Sends a one-time password (OTP) to the user's phone.
  Future<void> sendOTP(String phone) async {
    try {
      final String fullPhoneNumber = '+91$phone';
      await supabase.auth.signInWithOtp(phone: fullPhoneNumber);
    } catch (e) {
      debugPrint('Error sending OTP: $e');
      rethrow;
    }
  }

  /// Verifies the OTP sent to the user's phone.
  Future<void> verifyOTP(String phone, String otp) async {
    try {
      final String fullPhoneNumber = '+91$phone';
      final response = await supabase.auth.verifyOTP(
        type: OtpType.sms,
        token: otp,
        phone: fullPhoneNumber,
      );
      if (response.user == null) {
        throw 'Invalid OTP or session expired. Please try again.';
      }
    } catch (e) {
      debugPrint('Error verifying OTP: $e');
      rethrow;
    }
  }

  /// Signs the current user out.
  Future<void> signOut() async {
    await supabase.auth.signOut();
  }

  // --- Profile Management Methods ---

  /// Checks if a profile exists in the 'passengers' table.
  Future<bool> doesProfileExist() async {
    if (currentUser == null) return false;
    try {
      final data = await supabase
          .from('passengers')
          .select('id')
          .eq('id', currentUser!.id)
          .maybeSingle();
      return data != null;
    } catch (e) {
      debugPrint('Error checking profile existence: $e');
      return false;
    }
  }

  /// Fetches the profile for the currently logged-in user.
  Future<Map<String, dynamic>> getProfile() async {
    if (currentUser == null) throw 'User is not logged in.';
    try {
      final data = await supabase
          .from('passengers')
          .select()
          .eq('id', currentUser!.id)
          .maybeSingle();

      if (data != null) {
        return data;
      }

      return {
        'id': currentUser!.id,
        'full_name': currentUser!.userMetadata?['full_name'] ?? '',
        'email': currentUser!.email ?? '',
        'phone': currentUser!.phone,
        'profile_pic_url': null,
        'short_id': currentUser!.id.substring(0, 4).toUpperCase(),
        'points': 0,
      };
    } catch (e) {
      debugPrint('Error fetching profile: $e');
      rethrow;
    }
  }

  ({String extension, String contentType}) _detectImageMetadata(
      Uint8List imageBytes) {
    if (imageBytes.length >= 8 &&
        imageBytes[0] == 0x89 &&
        imageBytes[1] == 0x50 &&
        imageBytes[2] == 0x4E &&
        imageBytes[3] == 0x47) {
      return (extension: 'png', contentType: 'image/png');
    }

    if (imageBytes.length >= 3 &&
        imageBytes[0] == 0xFF &&
        imageBytes[1] == 0xD8 &&
        imageBytes[2] == 0xFF) {
      return (extension: 'jpg', contentType: 'image/jpeg');
    }

    if (imageBytes.length >= 12 &&
        imageBytes[0] == 0x52 &&
        imageBytes[1] == 0x49 &&
        imageBytes[2] == 0x46 &&
        imageBytes[3] == 0x46 &&
        imageBytes[8] == 0x57 &&
        imageBytes[9] == 0x45 &&
        imageBytes[10] == 0x42 &&
        imageBytes[11] == 0x50) {
      return (extension: 'webp', contentType: 'image/webp');
    }

    return (extension: 'jpg', contentType: 'image/jpeg');
  }

  Future<String> _uploadProfileImage(Uint8List imageBytes) async {
    if (currentUser == null) throw 'User is not logged in.';

    final metadata = _detectImageMetadata(imageBytes);
    final imagePath =
        '${currentUser!.id}/profile_${DateTime.now().millisecondsSinceEpoch}.${metadata.extension}';

    try {
      await supabase.storage.from(avatarBucketName).uploadBinary(
            imagePath,
            imageBytes,
            fileOptions: FileOptions(
              upsert: true,
              contentType: metadata.contentType,
            ),
          );
    } on StorageException catch (error) {
      final message = error.message.toLowerCase();
      if (message.contains('bucket not found')) {
        throw StateError(
          'Storage bucket "$avatarBucketName" was not found for the current Supabase project. '
          'Check that SUPABASE_URL and SUPABASE_ANON_KEY point to the same project where the bucket exists, '
          'or set SUPABASE_AVATAR_BUCKET in .env if the bucket name is different.',
        );
      }
      rethrow;
    }

    return supabase.storage.from(avatarBucketName).getPublicUrl(imagePath);
  }

  /// ✅ FINALIZED: Merged update logic with Short ID fix and Binary Uploads.
  /// This handles both the Profile Setup and the Profile Edit screens.
  Future<void> updateProfile({
    required String fullName,
    String? email,
    String? phone,
    Uint8List? imageBytes,
    bool removeImage = false,
    bool onboardingCompleted = false,
  }) async {
    if (currentUser == null) throw 'User is not logged in.';

    try {
      String? imageUrl;
      final normalizedEmail = email?.trim();
      final normalizedPhone = phone?.trim();

      // 1. Generate persistent Short ID from UUID
      // This ensures the "#USER" placeholder is replaced by a real ID.
      final String shortId = currentUser!.id.substring(0, 4).toUpperCase();

      // 2. Handle Profile Picture logic
      if (removeImage) {
        imageUrl = null;
      } else if (imageBytes != null) {
        imageUrl = await _uploadProfileImage(imageBytes);
      }

      // 3. Prepare data for 'passengers' table
      final updates = <String, dynamic>{
        'id': currentUser!.id,
        'full_name': fullName,
        'email': normalizedEmail == null || normalizedEmail.isEmpty
            ? null
            : normalizedEmail,
        'phone': normalizedPhone != null && normalizedPhone.isNotEmpty
            ? normalizedPhone
            : currentUser!.phone,
        'short_id': shortId,
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      };

      if (onboardingCompleted) {
        updates['onboarding_status'] = 'completed';
      }

      // 4. Update image URL only if it was modified or removed
      if (imageBytes != null || removeImage) {
        updates['profile_pic_url'] = imageUrl; // ✅ Uses correct database key
      }

      // 5. Upsert (Update if exists, Insert if new)
      await supabase.from('passengers').upsert(updates, onConflict: 'id');
    } catch (e) {
      debugPrint('AuthService Update Error: $e');
      rethrow;
    }
  }
}
