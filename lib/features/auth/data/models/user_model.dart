import 'package:drop/core/extensions/firestore_extensions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:drop/core/enums/user_role.dart';
import 'package:drop/features/auth/domain/entities/user_entity.dart';

class UserModel {
  final String uid;
  final String email;
  final String? displayName;
  final String? photoUrl;
  final String? phoneNumber;
  final String? address;
  final String? emergencyContact;
  final String authProvider;
  final bool isEmailVerified;
  final DateTime? createdAt;
  // ─── Roles & foundation (Phase 1) ───────────────────────────
  final UserRole role;
  final String? branchId;
  final bool isActive;
  final String? assignedShift;
  final String? position;
  // ─── Account provisioning (admin-created) ───────────────────
  final bool mustChangePassword;
  final bool isProfileCompleted;
  final bool hasCompletedOnboarding;
  final String employmentStatus;
  final String? createdBy;
  /// The single-active-session claim (see [UserEntity.activeSessionId]). READ
  /// here, but deliberately absent from [toMap]: the claim is written only by
  /// `UserRemoteDataSource.claimSession`, so a routine profile save can never
  /// stamp a stale id and evict the device that actually owns the session.
  final String? activeSessionId;
  // NOTE (C2 fix, 2026-07-03): compensation fields are deliberately absent —
  // they live in users/{uid}/private/compensation (UserCompensation) and are
  // loaded on demand, never as part of a user fetch.

  const UserModel({
    required this.uid,
    required this.email,
    required this.authProvider,
    this.displayName,
    this.photoUrl,
    this.phoneNumber,
    this.address,
    this.emergencyContact,
    this.isEmailVerified = false,
    this.createdAt,
    this.role = UserRole.employee,
    this.branchId,
    this.isActive = true,
    this.assignedShift,
    this.position,
    this.mustChangePassword = false,
    this.isProfileCompleted = true,
    this.hasCompletedOnboarding = true,
    this.employmentStatus = 'active',
    this.createdBy,
    this.activeSessionId,
  });

  factory UserModel.fromFirebaseUser(User user, {String authProvider = 'unknown'}) =>
      UserModel(
        uid: user.uid,
        email: user.email ?? '',
        displayName: user.displayName,
        photoUrl: user.photoURL,
        phoneNumber: user.phoneNumber,
        authProvider: authProvider,
        isEmailVerified: user.emailVerified,
      );

  factory UserModel.fromEntity(UserEntity entity) => UserModel(
        uid: entity.uid,
        email: entity.email,
        displayName: entity.displayName,
        photoUrl: entity.photoUrl,
        phoneNumber: entity.phoneNumber,
        address: entity.address,
        emergencyContact: entity.emergencyContact,
        authProvider: entity.authProvider,
        isEmailVerified: entity.isEmailVerified,
        createdAt: entity.createdAt,
        role: entity.role,
        branchId: entity.branchId,
        isActive: entity.isActive,
        assignedShift: entity.assignedShift,
        position: entity.position,
        mustChangePassword: entity.mustChangePassword,
        isProfileCompleted: entity.isProfileCompleted,
        hasCompletedOnboarding: entity.hasCompletedOnboarding,
        employmentStatus: entity.employmentStatus,
        createdBy: entity.createdBy,
        activeSessionId: entity.activeSessionId,
      );

  factory UserModel.fromMap(Map<String, dynamic> map) => UserModel(
        // Defensive: a malformed / partial user doc must never crash a whole
        // user-list load (schedule team, assignee picker, admin lists). Degrade
        // to empty strings like every other model does.
        uid: map['uid'] as String? ?? '',
        email: map['email'] as String? ?? '',
        // `name` maps to displayName (canonical), falling back to the legacy
        // profile `fullName` key the same doc carries.
        displayName: (map['displayName'] as String?) ?? (map['fullName'] as String?),
        photoUrl: map['photoUrl'] as String?,
        phoneNumber: map['phoneNumber'] as String?,
        address: map['address'] as String?,
        emergencyContact: map['emergencyContact'] as String?,
        authProvider: map['authProvider'] as String? ?? 'unknown',
        isEmailVerified: map['isEmailVerified'] as bool? ?? false,
        createdAt: map.date('createdAt'),
        role: UserRole.fromString(map['role'] as String?),
        branchId: map['branchId'] as String?,
        isActive: map['isActive'] as bool? ?? true,
        assignedShift: map['assignedShift'] as String?,
        position: map['position'] as String?,
        // Legacy / pre-migration docs lack these → default to NOT forced
        // (mustChangePassword false, isProfileCompleted true) so they're never
        // trapped in the onboarding flow.
        mustChangePassword: map['mustChangePassword'] as bool? ?? false,
        isProfileCompleted: map['isProfileCompleted'] as bool? ?? true,
        // Absent on every pre-onboarding-feature doc → default true = "already
        // welcomed", so no existing user is ever shown the Welcome screen. Only
        // a new account seeded false at profile completion triggers it.
        hasCompletedOnboarding: map['hasCompletedOnboarding'] as bool? ?? true,
        employmentStatus: map['employmentStatus'] as String? ?? 'active',
        createdBy: map['createdBy'] as String?,
        // Absent on every document written before single-active-session
        // shipped → null, which the auth layer reads as "no claim on record"
        // and therefore never treats as an eviction.
        activeSessionId: map['activeSessionId'] as String?,
        // Compensation keys on legacy (pre-migration) docs are intentionally
        // NOT parsed — salary data never enters the public user entity.
      );

  /// Identity/auth fields only. The privileged + provisioning fields (`role`,
  /// `branchId`, `isActive`, `assignedShift`, `position`, `employmentStatus`,
  /// `createdBy`, `mustChangePassword`, `isProfileCompleted`) are intentionally
  /// EXCLUDED so a routine write can never overwrite admin-assigned values
  /// (they are seeded once, server-side, by the `createUserAccount` Cloud
  /// Function). Compensation lives in the private subdocument entirely.
  ///
  /// `activeSessionId` is excluded for the same reason: it is owned by
  /// `UserRemoteDataSource.claimSession` alone. Round-tripping it through a
  /// profile save would let a device that had been evicted seconds earlier
  /// re-stamp its own stale id and steal the session back.
  Map<String, dynamic> toMap() => {
        'uid': uid,
        'email': email,
        'displayName': displayName,
        'photoUrl': photoUrl,
        'phoneNumber': phoneNumber,
        'address': address,
        'emergencyContact': emergencyContact,
        'authProvider': authProvider,
        'isEmailVerified': isEmailVerified,
      };

  UserEntity toEntity() => UserEntity(
        uid: uid,
        email: email,
        displayName: displayName,
        photoUrl: photoUrl,
        phoneNumber: phoneNumber,
        address: address,
        emergencyContact: emergencyContact,
        authProvider: authProvider,
        isEmailVerified: isEmailVerified,
        createdAt: createdAt,
        role: role,
        branchId: branchId,
        isActive: isActive,
        assignedShift: assignedShift,
        position: position,
        mustChangePassword: mustChangePassword,
        isProfileCompleted: isProfileCompleted,
        hasCompletedOnboarding: hasCompletedOnboarding,
        employmentStatus: employmentStatus,
        createdBy: createdBy,
        activeSessionId: activeSessionId,
      );
}
