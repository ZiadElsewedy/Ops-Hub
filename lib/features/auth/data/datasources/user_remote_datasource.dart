import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:drop/core/errors/exceptions.dart';
import 'package:drop/features/auth/data/models/user_model.dart';

abstract class UserRemoteDataSource {
  Future<UserModel?> getUser(String uid);
  Future<List<UserModel>> getUsersByBranch(String branchId);

  /// Every user document, unfiltered. Backs the **chat directory**, whose access
  /// model is deliberately flat: anyone signed in may message anyone else, so
  /// there is no branch or role predicate to push into the query. Rules permit
  /// this read for any signed-in user; the caller applies whatever presentation
  /// filtering it needs (see `GetChatDirectory`).
  Future<List<UserModel>> getAllUsers();

  /// Live stream of a user's document — used to detect role/access changes in
  /// real time (e.g. an admin disabling the account mid-session) without polling.
  Stream<UserModel?> watchUser(String uid);

  /// Clears the admin-issued temporary-password flag once the user has set their
  /// own password. A self-write (rules allow the owner to flip this flag).
  Future<void> setMustChangePassword(String uid, bool value);

  /// Marks onboarding complete once the user has filled their profile. A
  /// self-write (rules allow the owner to flip this flag).
  Future<void> setProfileCompleted(String uid, bool value);

  /// Flips the one-time Welcome flag: seeded `false` at profile completion (so a
  /// new employee is shown Welcome once) and set `true` when they dismiss it. A
  /// self-write — `hasCompletedOnboarding` is a non-privileged field, so the
  /// existing owner-update rule already permits it (no rules change).
  Future<void> setOnboardingCompleted(String uid, bool value);
}

class UserRemoteDataSourceImpl implements UserRemoteDataSource {
  final FirebaseFirestore _firestore;

  UserRemoteDataSourceImpl(this._firestore);

  CollectionReference<Map<String, dynamic>> get _users =>
      _firestore.collection('users');

  @override
  Future<UserModel?> getUser(String uid) async {
    final doc = await _users.doc(uid).get();
    if (!doc.exists || doc.data() == null) return null;
    return UserModel.fromMap(doc.data()!);
  }

  @override
  Future<List<UserModel>> getUsersByBranch(String branchId) async {
    // Used by managers/admins (assignee/roster pickers) and employees (their
    // branch teammates + manager for the weekly schedule). Security rules let any
    // member read users in their own branch; an admin reads any.
    try {
      final snap =
          await _users.where('branchId', isEqualTo: branchId).get();
      return snap.docs
          .where((d) => d.data().isNotEmpty)
          .map((d) => UserModel.fromMap(d.data()))
          .toList();
    } on FirebaseException catch (e) {
      throw AuthException(e.message ?? 'Failed to load branch members.');
    }
  }

  @override
  Future<List<UserModel>> getAllUsers() async {
    try {
      final snap = await _users.get();
      return snap.docs
          .where((d) => d.data().isNotEmpty)
          .map((d) => UserModel.fromMap(d.data()))
          .toList();
    } on FirebaseException catch (e) {
      throw AuthException(e.message ?? 'Failed to load users.');
    }
  }

  @override
  Stream<UserModel?> watchUser(String uid) {
    return _users.doc(uid).snapshots().map(
          (doc) => (!doc.exists || doc.data() == null)
              ? null
              : UserModel.fromMap(doc.data()!),
        );
  }

  @override
  Future<void> setMustChangePassword(String uid, bool value) async {
    try {
      await _users.doc(uid).set({
        'mustChangePassword': value,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } on FirebaseException catch (e) {
      throw AuthException(e.message ?? 'Failed to update account.');
    }
  }

  @override
  Future<void> setProfileCompleted(String uid, bool value) async {
    try {
      await _users.doc(uid).set({
        'isProfileCompleted': value,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } on FirebaseException catch (e) {
      throw AuthException(e.message ?? 'Failed to update account.');
    }
  }

  @override
  Future<void> setOnboardingCompleted(String uid, bool value) async {
    try {
      await _users.doc(uid).set({
        'hasCompletedOnboarding': value,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } on FirebaseException catch (e) {
      throw AuthException(e.message ?? 'Failed to update account.');
    }
  }
}
