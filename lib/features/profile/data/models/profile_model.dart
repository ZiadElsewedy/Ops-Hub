import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:drop/core/extensions/firestore_extensions.dart';
import 'package:drop/features/profile/domain/entities/profile_entity.dart';

/// Firestore serialization for [ProfileEntity], stored in `users/{uid}`.
///
/// Reads are back-compat: documents created by the original auth flow only
/// have `displayName`/`photoUrl`, so [fromMap] falls back to those when the
/// newer `fullName`/`profileImage` keys are absent.
class ProfileModel {
  final ProfileEntity entity;

  const ProfileModel(this.entity);

  factory ProfileModel.fromMap(Map<String, dynamic> map) {
    String? str(dynamic v) => (v is String && v.isNotEmpty) ? v : null;

    return ProfileModel(ProfileEntity(
      // Defensive: never crash the profile screen on a partial doc.
      uid: map['uid'] as String? ?? '',
      email: (map['email'] as String?) ?? '',
      phoneNumber: str(map['phoneNumber']),
      authProvider: (map['authProvider'] as String?) ?? 'unknown',
      // Prefer the new key, fall back to the legacy auth field.
      fullName: str(map['fullName']) ?? str(map['displayName']),
      username: str(map['username']),
      profileImage: str(map['profileImage']) ?? str(map['photoUrl']),
      coverImage: str(map['coverImage']),
      bio: str(map['bio']),
      gender: str(map['gender']),
      birthDate: map.date('birthDate'),
      country: str(map['country']),
      city: str(map['city']),
      website: str(map['website']),
      address: str(map['address']),
      emergencyContact: str(map['emergencyContact']),
      paymentNumber: str(map['paymentNumber']),
      isVerified: (map['isVerified'] as bool?) ?? false,
      accountStatus: (map['accountStatus'] as String?) ?? 'active',
      createdAt: map.date('createdAt'),
      updatedAt: map.date('updatedAt'),
      isOnline: (map['isOnline'] as bool?) ?? false,
      lastSeen: map.date('lastSeen'),
      isProfilePublic: (map['isProfilePublic'] as bool?) ?? true,
      allowMessages: (map['allowMessages'] as bool?) ?? true,
      allowNotifications: (map['allowNotifications'] as bool?) ?? true,
    ));
  }

  ProfileEntity toEntity() => entity;

  /// Builds a partial-update map from the editable fields. Only non-null
  /// values are written (merge), so untouched fields are preserved. Keeps the
  /// legacy `displayName`/`photoUrl` keys in sync so the auth/home layer that
  /// still reads them stays correct.
  static Map<String, dynamic> editMap({
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
  }) {
    final map = <String, dynamic>{'updatedAt': FieldValue.serverTimestamp()};
    if (fullName != null) {
      map['fullName'] = fullName;
      map['displayName'] = fullName; // legacy sync
    }
    if (username != null) map['username'] = username;
    if (bio != null) map['bio'] = bio;
    if (phoneNumber != null) map['phoneNumber'] = phoneNumber;
    if (country != null) map['country'] = country;
    if (city != null) map['city'] = city;
    if (website != null) map['website'] = website;
    if (gender != null) map['gender'] = gender;
    if (birthDate != null) map['birthDate'] = Timestamp.fromDate(birthDate);
    if (profileImage != null) {
      map['profileImage'] = profileImage;
      map['photoUrl'] = profileImage; // legacy sync
    }
    if (coverImage != null) map['coverImage'] = coverImage;
    // Onboarding fields (Profile Completion). Stored on users/{uid}.
    if (emergencyContact != null) map['emergencyContact'] = emergencyContact;
    if (address != null) map['address'] = address;
    // NOTE (C2 fix): `paymentNumber` is deliberately NOT part of this map —
    // it is private compensation data living in
    // users/{uid}/private/compensation; the datasource writes it there.
    return map;
  }
}
