import 'dart:io';

import 'package:opshub/features/profile/domain/entities/profile_entity.dart';

abstract class ProfileRepository {
  Future<ProfileEntity?> getProfile(String uid);

  /// Updates the editable profile fields. Implementations also keep the
  /// Firebase Auth display name / photo in sync so the rest of the app
  /// (Home, session) reflects the change immediately.
  Future<ProfileEntity> updateProfile({
    required String uid,
    String? fullName,
    String? username,
    String? bio,
    String? phoneNumber,
    String? country,
    String? city,
    String? website,
    String? gender,
    DateTime? birthDate,
    String? profileImage,
    String? coverImage,
    String? emergencyContact,
    String? address,
    String? paymentNumber,
  });

  Future<String> uploadProfileImage(String uid, File file,
      {void Function(double progress)? onProgress});
  Future<String> uploadCoverImage(String uid, File file,
      {void Function(double progress)? onProgress});

  Future<bool> isUsernameAvailable(String username, {required String forUid});
}
