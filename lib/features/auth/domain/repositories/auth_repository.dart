import 'package:drop/features/auth/domain/entities/user_entity.dart';

/// Auth contract for the **admin-provisioned** model: email/password sign-in,
/// password reset/change, the first-login flag writes, and user reads/streams.
/// No registration / Google / phone — accounts are created by a Cloud Function.
abstract class AuthRepository {
  Stream<UserEntity?> get authStateChanges;
  UserEntity? get currentUser;

  Future<UserEntity> signInWithEmail({required String email, required String password});
  Future<void> signOut();

  Future<UserEntity?> getUser(String uid);
  Future<List<UserEntity>> getUsersByBranch(String branchId);

  /// Every user, unfiltered — the chat directory's source (flat access model:
  /// anyone may message anyone). Branch-scoped features use [getUsersByBranch].
  Future<List<UserEntity>> getAllUsers();

  /// Live stream of a user's document — emits on every change so callers react to
  /// role/access changes (e.g. an admin disabling the account) in real time.
  Stream<UserEntity?> watchUser(String uid);

  Future<void> sendPasswordResetEmail(String email);
  Future<void> changePassword({required String currentPassword, required String newPassword});

  /// First-login flags (self-writes). Cleared once the user changes the temp
  /// password / completes their profile.
  Future<void> setMustChangePassword(String uid, bool value);
  Future<void> setProfileCompleted(String uid, bool value);

  /// One-time Welcome flag (self-write): seeded `false` at profile completion so
  /// a new employee sees the Welcome screen once, set `true` when they dismiss it.
  Future<void> setOnboardingCompleted(String uid, bool value);
}
