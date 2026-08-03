import 'dart:io';

import 'package:drop/core/errors/exceptions.dart';
import 'package:drop/core/errors/failures.dart';
import 'package:drop/core/network/network_guard.dart';
import 'package:drop/features/auth/data/datasources/auth_remote_datasource.dart';
import 'package:drop/features/profile/data/datasources/profile_remote_datasource.dart';
import 'package:drop/features/profile/domain/entities/profile_entity.dart';
import 'package:drop/features/profile/domain/repositories/profile_repository.dart';

class ProfileRepositoryImpl implements ProfileRepository {
  final ProfileRemoteDataSource _profileRemote;
  final AuthRemoteDataSource _authRemote;

  ProfileRepositoryImpl(this._profileRemote, this._authRemote);

  @override
  Future<ProfileEntity?> getProfile(String uid) async {
    try {
      final model = await _profileRemote.getProfile(uid);
      return model?.toEntity();
    } on AuthException catch (e) {
      throw AuthFailure(e.message);
    }
  }

  @override
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
  }) async {
    NetworkGuard.ensureWritable();
    try {
      await _profileRemote.updateProfile(
        uid: uid,
        fullName: fullName,
        username: username?.toLowerCase(),
        bio: bio,
        phoneNumber: phoneNumber,
        country: country,
        city: city,
        website: website,
        gender: gender,
        birthDate: birthDate,
        profileImage: profileImage,
        coverImage: coverImage,
        emergencyContact: emergencyContact,
        address: address,
        paymentNumber: paymentNumber,
      );

      // Keep the Firebase Auth profile in sync so the auth session / Home
      // reflect the new name and avatar without a re-login. Best-effort:
      // a sync failure shouldn't fail the whole save.
      if (fullName != null && fullName.trim().isNotEmpty) {
        try {
          await _authRemote.updateDisplayName(fullName.trim());
        } on AuthException {/* non-fatal */}
      }
      if (profileImage != null && profileImage.trim().isNotEmpty) {
        try {
          await _authRemote.updatePhotoUrl(profileImage.trim());
        } on AuthException {/* non-fatal */}
      }

      final updated = await _profileRemote.getProfile(uid);
      if (updated == null) {
        throw const AuthFailure('Profile not found after update.');
      }
      return updated.toEntity();
    } on AuthException catch (e) {
      throw AuthFailure(e.message);
    }
  }

  @override
  Future<String> uploadProfileImage(String uid, File file,
      {void Function(double progress)? onProgress}) async {
    try {
      return await _profileRemote.uploadProfileImage(uid, file,
          onProgress: onProgress);
    } on AuthException catch (e) {
      throw AuthFailure(e.message);
    }
  }

  @override
  Future<String> uploadCoverImage(String uid, File file,
      {void Function(double progress)? onProgress}) async {
    try {
      return await _profileRemote.uploadCoverImage(uid, file,
          onProgress: onProgress);
    } on AuthException catch (e) {
      throw AuthFailure(e.message);
    }
  }

  @override
  Future<bool> isUsernameAvailable(String username, {required String forUid}) =>
      _profileRemote.isUsernameAvailable(username.toLowerCase(), forUid: forUid);
}
