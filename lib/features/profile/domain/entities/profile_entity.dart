import 'package:freezed_annotation/freezed_annotation.dart';

part 'profile_entity.freezed.dart';

/// The complete DROP user profile.
///
/// This is the production social-profile contract. Some fields (social
/// counters, presence) are not yet driven by a backend — they default to 0 /
/// false so the UI and Firestore schema are ready for future features to plug
/// in without a migration.
@freezed
class ProfileEntity with _$ProfileEntity {
  const factory ProfileEntity({
    // ─── Identity ───────────────────────────────────────────────
    required String uid,
    required String email,
    String? phoneNumber,
    @Default('unknown') String authProvider,
    String? fullName,
    String? username,
    String? profileImage,
    String? coverImage,

    // ─── Personal ───────────────────────────────────────────────
    String? bio,
    String? gender,
    DateTime? birthDate,
    String? country,
    String? city,
    String? website,

    // ─── Contact & payroll (operations — stored on the same users doc) ──
    /// Home / mailing address. Self-editable.
    String? address,
    /// Emergency contact (name · phone). Self-editable.
    String? emergencyContact,
    /// The phone / wallet / account number the salary is sent to — the one
    /// compensation field the employee edits themselves. The admin-only salary
    /// fields (amount / type / method) are NOT part of the profile contract.
    String? paymentNumber,

    // ─── Account ────────────────────────────────────────────────
    @Default(false) bool isVerified,
    @Default('active') String accountStatus,
    DateTime? createdAt,
    DateTime? updatedAt,

    // ─── Presence ───────────────────────────────────────────────
    @Default(false) bool isOnline,
    DateTime? lastSeen,

    // ─── Settings ───────────────────────────────────────────────
    @Default(true) bool isProfilePublic,
    @Default(true) bool allowMessages,
    @Default(true) bool allowNotifications,
  }) = _ProfileEntity;

  const ProfileEntity._();

  /// Best display name, falling back gracefully.
  String get displayName =>
      (fullName != null && fullName!.trim().isNotEmpty)
          ? fullName!.trim()
          : (username != null && username!.trim().isNotEmpty)
              ? username!.trim()
              : email.split('@').first;

  /// `@handle` form, or empty if no username set.
  String get handle =>
      (username != null && username!.trim().isNotEmpty) ? '@${username!.trim()}' : '';

  bool get hasProfileImage =>
      profileImage != null && profileImage!.trim().isNotEmpty;

  bool get hasCoverImage =>
      coverImage != null && coverImage!.trim().isNotEmpty;

  /// True when the essential fields a new user must fill are present.
  bool get isComplete =>
      (fullName?.trim().isNotEmpty ?? false) &&
      (username?.trim().isNotEmpty ?? false);
}
