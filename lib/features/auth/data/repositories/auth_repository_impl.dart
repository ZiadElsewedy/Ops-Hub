import 'package:drop/core/errors/exceptions.dart';
import 'package:drop/core/errors/failures.dart';
import 'package:drop/features/auth/data/datasources/auth_remote_datasource.dart';
import 'package:drop/features/auth/data/datasources/user_remote_datasource.dart';
import 'package:drop/features/auth/domain/entities/user_entity.dart';
import 'package:drop/features/auth/domain/repositories/auth_repository.dart';

class AuthRepositoryImpl implements AuthRepository {
  final AuthRemoteDataSource _remote;
  final UserRemoteDataSource _userRemote;

  AuthRepositoryImpl(this._remote, this._userRemote);

  @override
  Stream<UserEntity?> get authStateChanges =>
      _remote.authStateChanges.map((m) => m?.toEntity());

  @override
  UserEntity? get currentUser => _remote.currentUser?.toEntity();

  @override
  Future<UserEntity> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      final model = await _remote.signInWithEmail(email: email, password: password);
      return model.toEntity();
    } on AuthException catch (e) {
      throw AuthFailure(e.message);
    }
  }

  @override
  Future<void> signOut() => _remote.signOut();

  @override
  Future<UserEntity?> getUser(String uid) async {
    final model = await _userRemote.getUser(uid);
    return model?.toEntity();
  }

  @override
  Future<List<UserEntity>> getUsersByBranch(String branchId) async {
    try {
      final models = await _userRemote.getUsersByBranch(branchId);
      return models.map((m) => m.toEntity()).toList();
    } on AuthException catch (e) {
      throw AuthFailure(e.message);
    }
  }

  @override
  Future<List<UserEntity>> getAllUsers() async {
    try {
      final models = await _userRemote.getAllUsers();
      return models.map((m) => m.toEntity()).toList();
    } on AuthException catch (e) {
      throw AuthFailure(e.message);
    }
  }

  @override
  Stream<UserEntity?> watchUser(String uid) =>
      _userRemote.watchUser(uid).map((model) => model?.toEntity());

  @override
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _remote.sendPasswordResetEmail(email);
    } on AuthException catch (e) {
      throw AuthFailure(e.message);
    }
  }

  @override
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    try {
      await _remote.changePassword(
        currentPassword: currentPassword,
        newPassword: newPassword,
      );
    } on AuthException catch (e) {
      throw AuthFailure(e.message);
    }
  }

  @override
  Future<void> setMustChangePassword(String uid, bool value) async {
    try {
      await _userRemote.setMustChangePassword(uid, value);
    } on AuthException catch (e) {
      throw AuthFailure(e.message);
    }
  }

  @override
  Future<void> setProfileCompleted(String uid, bool value) async {
    try {
      await _userRemote.setProfileCompleted(uid, value);
    } on AuthException catch (e) {
      throw AuthFailure(e.message);
    }
  }

  @override
  Future<void> setOnboardingCompleted(String uid, bool value) async {
    try {
      await _userRemote.setOnboardingCompleted(uid, value);
    } on AuthException catch (e) {
      throw AuthFailure(e.message);
    }
  }
}
