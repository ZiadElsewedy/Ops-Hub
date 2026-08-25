import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:opshub/core/errors/exceptions.dart';
import 'package:opshub/features/auth/data/models/user_model.dart';

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

  /// Claims the account's ONE active session for the calling device by stamping
  /// [sessionId] on `users/{uid}.activeSessionId`. Every other device is
  /// watching this document, sees an id that is not the one in its own
  /// `SessionStore`, and signs itself out.
  ///
  /// A self-write. `activeSessionId` is deliberately NOT in the privileged
  /// freeze-list of the `users` update rule, so the existing owner-update
  /// clause already permits it — **no rules change and no deploy**.
  Future<void> claimSession(String uid, String sessionId);
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

  /// Live user document — **server-confirmed snapshots only**.
  ///
  /// `snapshots()` replays the locally cached document the instant you
  /// subscribe, before the backend has said anything. Every consumer of this
  /// stream acts on it destructively — deactivated, hard-deleted, or session
  /// taken over all end the session — so acting on a cached copy means ending a
  /// session on data that may be minutes or days old. That is exactly what
  /// signed a device out the moment it signed in: its cache still held the
  /// PREVIOUS session's `activeSessionId`.
  ///
  /// `isFromCache` is false only once the document has been read from the
  /// backend, so filtering on it keeps every decision here server-authoritative.
  /// A device that is offline simply gets no emissions — it stays signed in,
  /// which matches "offline gates the writes, never the app".
  @override
  Stream<UserModel?> watchUser(String uid) {
    return _users
        .doc(uid)
        .snapshots()
        .where((doc) => !doc.metadata.isFromCache)
        .map(
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

  @override
  Future<void> claimSession(String uid, String sessionId) async {
    try {
      await _users.doc(uid).set({
        'activeSessionId': sessionId,
        // When the claim was made. Not read by the client — it exists so an
        // admin looking at a "why was I signed out?" report can see when the
        // account was last taken over, and from a support view that is the only
        // evidence the eviction was legitimate.
        'activeSessionAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } on FirebaseException catch (e) {
      throw AuthException(e.message ?? 'Failed to start your session.');
    }
  }
}
