import 'package:opshub/core/enums/user_role.dart';
import 'package:opshub/core/errors/exceptions.dart';
import 'package:opshub/core/errors/failures.dart';
import 'package:opshub/core/network/network_guard.dart';
import 'package:opshub/features/admin/data/datasources/user_admin_remote_datasource.dart';
import 'package:opshub/features/admin/domain/entities/user_compensation.dart';
import 'package:opshub/features/admin/domain/repositories/user_admin_repository.dart';
import 'package:opshub/features/auth/domain/entities/user_entity.dart';

class UserAdminRepositoryImpl implements UserAdminRepository {
  final UserAdminRemoteDataSource _remote;

  UserAdminRepositoryImpl(this._remote);

  @override
  Future<List<UserEntity>> getAllUsers() async {
    try {
      final models = await _remote.getAllUsers();
      return models.map((m) => m.toEntity()).toList();
    } on ServerException catch (e) {
      throw ServerFailure(e.message);
    }
  }

  @override
  Future<List<UserEntity>> getUsersByRole(UserRole role) async {
    try {
      final models = await _remote.getUsersByRole(role.value);
      return models.map((m) => m.toEntity()).toList();
    } on ServerException catch (e) {
      throw ServerFailure(e.message);
    }
  }

  @override
  Future<String> createAccount({
    required String name,
    required String email,
    required String temporaryPassword,
    required UserRole role,
    String? branchId,
    String? assignedShift,
    String? position,
  }) async {
    NetworkGuard.ensureWritable();
    try {
      return await _remote.createAccount(
        name: name,
        email: email,
        password: temporaryPassword,
        role: role.value,
        branchId: branchId,
        assignedShift: assignedShift,
        position: position,
      );
    } on ServerException catch (e) {
      throw ServerFailure(e.message);
    }
  }

  @override
  Future<void> resetPassword({
    required String uid,
    required String temporaryPassword,
  }) =>
      _run(() => _remote.resetPassword(uid: uid, tempPassword: temporaryPassword));

  @override
  Future<void> deleteAccount(String uid) =>
      _run(() => _remote.deleteAccount(uid));

  @override
  Future<void> setUserActive(String uid, bool isActive) =>
      _run(() => _remote.updateUser(uid, {'isActive': isActive}));

  @override
  Future<void> changeUserRole(String uid, UserRole role) =>
      _run(() => _remote.updateUser(uid, {'role': role.value}));

  @override
  Future<void> changeUserBranch(String uid, String? branchId) =>
      _run(() => _remote.updateUser(uid, {'branchId': branchId}));

  @override
  Future<void> changeUserPosition(String uid, String? position) =>
      _run(() => _remote.updateUser(uid, {'position': position}));

  @override
  Future<void> updateUserDetails(
    String uid, {
    String? displayName,
    String? phoneNumber,
    String? address,
    String? emergencyContact,
  }) =>
      _run(() => _remote.updateUser(uid, {
            // `fullName` mirrors `displayName` (the same doc carries both keys;
            // the profile feature reads `fullName`).
            'displayName': ?displayName,
            'fullName': ?displayName,
            'phoneNumber': ?phoneNumber,
            'address': ?address,
            'emergencyContact': ?emergencyContact,
          }));

  @override
  Future<void> changeUserEmploymentStatus(String uid, String status) =>
      _run(() => _remote.updateUser(uid, {'employmentStatus': status}));

  @override
  Future<void> updateUserCompensation(
    String uid, {
    required double? salaryAmount,
    required String? salaryType,
    required String? paymentMethod,
    required String? paymentNumber,
  }) =>
      // All four keys written unconditionally — null clears (the sheet's empty
      // inputs must remove stale values, unlike the skip-null contact map).
      // Written to the PRIVATE subdocument (C2 fix), never the user doc.
      _run(() => _remote.setCompensation(
            uid,
            UserCompensation(
              salaryAmount: salaryAmount,
              salaryType: salaryType,
              paymentMethod: paymentMethod,
              paymentNumber: paymentNumber,
            ),
          ));

  @override
  Future<UserCompensation> getUserCompensation(String uid) async {
    try {
      return await _remote.getCompensation(uid);
    } on ServerException catch (e) {
      throw ServerFailure(e.message);
    }
  }

  /// Every single-shot admin write funnels through here, so this is the one
  /// place the offline guard has to live for all nine of them.
  Future<void> _run(Future<void> Function() action) async {
    NetworkGuard.ensureWritable();
    try {
      await action();
    } on ServerException catch (e) {
      throw ServerFailure(e.message);
    }
  }
}
