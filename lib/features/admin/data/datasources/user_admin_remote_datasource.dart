import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:opshub/core/constants/app_constants.dart';
import 'package:opshub/core/errors/exceptions.dart';
import 'package:opshub/features/admin/domain/entities/user_compensation.dart';
import 'package:opshub/features/auth/data/models/user_model.dart';

/// Admin-side access to the `users` collection (reuses the auth [UserModel]).
/// Reads + field updates require an admin caller (enforced by `firestore.rules`).
/// Account PROVISIONING (creating an Auth user / resetting a password) is done
/// server-side by admin-only Cloud Functions — clients never create Auth users.
abstract class UserAdminRemoteDataSource {
  Future<List<UserModel>> getAllUsers();
  Future<List<UserModel>> getUsersByRole(String role);

  /// Admin field update on `users/{uid}` ([data] is merged + `updatedAt` set).
  Future<void> updateUser(String uid, Map<String, dynamic> data);

  /// The private compensation record at `users/{uid}/private/compensation`
  /// (C2 fix). Loaded ON DEMAND only — never part of a user-list fetch. During
  /// the migration window a missing subdocument falls back to the four legacy
  /// fields still sitting on the `users/{uid}` doc.
  Future<UserCompensation> getCompensation(String uid);

  /// Writes the FULL compensation record to the private subdocument (all four
  /// keys, null clears). Rules: admin-only for salary fields; the owner may
  /// touch only their own `paymentNumber` (a different, profile-side path).
  Future<void> setCompensation(String uid, UserCompensation compensation);

  /// Provisions a brand-new account via the admin-only `createUserAccount` Cloud
  /// Function (Firebase Admin SDK creates the Auth user + the Firestore doc;
  /// the admin is NOT signed out). Returns the new uid.
  Future<String> createAccount({
    required String name,
    required String email,
    required String password,
    required String role,
    String? branchId,
    String? assignedShift,
    String? position,
  });

  /// Resets an account: sets a new temporary password (Admin SDK) and forces a
  /// password change on next login, via the admin-only `adminResetPassword`
  /// Cloud Function.
  Future<void> resetPassword({required String uid, required String tempPassword});

  /// Permanently deletes an account (Auth user + Firestore doc) and cleans up its
  /// active references, via the admin-only `deleteUserAccount` Cloud Function.
  Future<void> deleteAccount(String uid);
}

class UserAdminRemoteDataSourceImpl implements UserAdminRemoteDataSource {
  final FirebaseFirestore _firestore;
  final FirebaseFunctions _functions;

  UserAdminRemoteDataSourceImpl(this._firestore, this._functions);

  CollectionReference<Map<String, dynamic>> get _users =>
      _firestore.collection(AppConstants.usersCollection);

  List<UserModel> _map(QuerySnapshot<Map<String, dynamic>> snap) => snap.docs
      .where((d) => d.data().isNotEmpty)
      .map((d) => UserModel.fromMap(d.data()))
      .toList();

  @override
  Future<List<UserModel>> getAllUsers() async {
    try {
      return _map(await _users.get());
    } on FirebaseException catch (e) {
      throw ServerException(e.message ?? 'Failed to load users.');
    }
  }

  @override
  Future<List<UserModel>> getUsersByRole(String role) async {
    try {
      return _map(await _users.where('role', isEqualTo: role).get());
    } on FirebaseException catch (e) {
      throw ServerException(e.message ?? 'Failed to load users.');
    }
  }

  @override
  Future<void> updateUser(String uid, Map<String, dynamic> data) async {
    try {
      await _users.doc(uid).set({
        ...data,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } on FirebaseException catch (e) {
      throw ServerException(e.message ?? 'Failed to update user.');
    }
  }

  DocumentReference<Map<String, dynamic>> _compensationDoc(String uid) =>
      _users.doc(uid).collection('private').doc('compensation');

  @override
  Future<UserCompensation> getCompensation(String uid) async {
    try {
      final sub = await _compensationDoc(uid).get();
      if (sub.exists && sub.data() != null) {
        return UserCompensation.fromMap(sub.data());
      }
      // Migration window: the record may still live on the user doc.
      final legacy = await _users.doc(uid).get();
      return UserCompensation.fromMap(legacy.data());
    } on FirebaseException catch (e) {
      throw ServerException(e.message ?? 'Failed to load compensation.');
    }
  }

  @override
  Future<void> setCompensation(String uid, UserCompensation compensation) async {
    try {
      await _compensationDoc(uid).set({
        ...compensation.toMap(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } on FirebaseException catch (e) {
      throw ServerException(e.message ?? 'Failed to save compensation.');
    }
  }

  @override
  Future<String> createAccount({
    required String name,
    required String email,
    required String password,
    required String role,
    String? branchId,
    String? assignedShift,
    String? position,
  }) async {
    try {
      final callable = _functions.httpsCallable('createUserAccount');
      final result = await callable.call<Map<String, dynamic>>({
        'name': name,
        'email': email,
        'password': password,
        'role': role,
        'branchId': branchId ?? '',
        'assignedShift': assignedShift ?? '',
        'position': position ?? '',
      });
      final uid = (result.data['uid'] ?? '').toString();
      if (uid.isEmpty) {
        throw const ServerException('Account creation did not return a user.');
      }
      return uid;
    } on FirebaseFunctionsException catch (e) {
      throw ServerException(e.message ?? 'Failed to create account.');
    }
  }

  @override
  Future<void> resetPassword({
    required String uid,
    required String tempPassword,
  }) async {
    try {
      final callable = _functions.httpsCallable('adminResetPassword');
      await callable.call<Map<String, dynamic>>({
        'uid': uid,
        'tempPassword': tempPassword,
      });
    } on FirebaseFunctionsException catch (e) {
      throw ServerException(e.message ?? 'Failed to reset the account.');
    }
  }

  @override
  Future<void> deleteAccount(String uid) async {
    try {
      final callable = _functions.httpsCallable('deleteUserAccount');
      await callable.call<Map<String, dynamic>>({'uid': uid});
    } on FirebaseFunctionsException catch (e) {
      throw ServerException(e.message ?? 'Failed to delete the account.');
    }
  }
}
