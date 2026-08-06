import 'package:drop/core/enums/user_role.dart';
import 'package:drop/features/admin/domain/entities/user_compensation.dart';
import 'package:drop/features/auth/domain/entities/user_entity.dart';

/// Admin operations over users. Reuses the auth [UserEntity]. All methods require
/// an admin caller (Firestore rules for field updates; admin-only Cloud Functions
/// for account provisioning).
abstract class UserAdminRepository {
  Future<List<UserEntity>> getAllUsers();
  Future<List<UserEntity>> getUsersByRole(UserRole role);

  /// Provision a new account (Auth user + Firestore doc) via the secure backend.
  /// Returns the new uid. The account starts active, with `mustChangePassword`
  /// + `isProfileCompleted == false` (first-login flow).
  Future<String> createAccount({
    required String name,
    required String email,
    required String temporaryPassword,
    required UserRole role,
    String? branchId,
    String? assignedShift,
    String? position,
  });

  /// Reset an account: issue a new temp password + re-force a password change.
  Future<void> resetPassword({required String uid, required String temporaryPassword});

  /// Permanently delete an account (Auth user + Firestore doc) and clean up its
  /// active/forward-looking references — current+future schedule slots, open
  /// task assignments (an orphaned open task is cancelled), pending
  /// swaps/requests/sales, the notification inbox — via the admin-only
  /// `deleteUserAccount` Cloud Function. Finished history is kept. Irreversible.
  Future<void> deleteAccount(String uid);

  Future<void> setUserActive(String uid, bool isActive);
  Future<void> changeUserRole(String uid, UserRole role);
  Future<void> changeUserBranch(String uid, String? branchId);

  /// Set the user's job position (drives shift-swap role compatibility). Pass
  /// null/empty to clear it.
  Future<void> changeUserPosition(String uid, String? position);

  /// Edit the user's contact details (display name + phone + address +
  /// emergency contact). Only the provided fields are written; pass an empty
  /// string to clear one. These are non-privileged profile fields an admin can
  /// fill in or correct at any time after the account is created.
  Future<void> updateUserDetails(
    String uid, {
    String? displayName,
    String? phoneNumber,
    String? address,
    String? emergencyContact,
  });

  /// Set the HR employment label (`active` / `suspended` / `terminated`).
  Future<void> changeUserEmploymentStatus(String uid, String status);

  /// Set the user's compensation record (admin-only fields). Unlike
  /// [updateUserDetails], all four keys are ALWAYS written — null clears a
  /// field — so the sheet's empty inputs reliably remove stale values.
  /// Writes the PRIVATE subdocument `users/{uid}/private/compensation`
  /// (C2 fix) — never the branch-readable user doc.
  Future<void> updateUserCompensation(
    String uid, {
    required double? salaryAmount,
    required String? salaryType,
    required String? paymentMethod,
    required String? paymentNumber,
  });

  /// The user's private compensation record, loaded ON DEMAND (admin
  /// Details / Edit-Info surfaces). Never part of a user-list fetch.
  Future<UserCompensation> getUserCompensation(String uid);
}
