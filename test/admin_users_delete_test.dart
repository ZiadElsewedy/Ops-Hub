import 'package:flutter_test/flutter_test.dart';
import 'package:opshub/core/enums/user_role.dart';
import 'package:opshub/features/admin/domain/repositories/user_admin_repository.dart';
import 'package:opshub/features/admin/presentation/cubit/admin_users_cubit.dart';
import 'package:opshub/features/auth/domain/entities/user_entity.dart';
import 'package:opshub/features/branch/domain/entities/branch_entity.dart';
import 'package:opshub/features/branch/domain/repositories/branch_repository.dart';

/// Records the delete and simulates the backend removing the account: after a
/// delete, the role query no longer returns that uid — so the cubit's refresh
/// must drop the person from the list.
class _FakeUserAdminRepository implements UserAdminRepository {
  _FakeUserAdminRepository(this._users);
  final List<UserEntity> _users;
  final deleted = <String>[];

  @override
  Future<void> deleteAccount(String uid) async {
    deleted.add(uid);
    _users.removeWhere((u) => u.uid == uid);
  }

  @override
  Future<List<UserEntity>> getUsersByRole(UserRole role) async =>
      _users.where((u) => u.role == role).toList();

  @override
  Future<List<UserEntity>> getAllUsers() async => List.of(_users);

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class _FakeBranchRepository implements BranchRepository {
  @override
  Future<List<BranchEntity>> getBranches({
    bool includeDeleted = false,
    bool forceRefresh = false,
  }) async => const [];
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

UserEntity _employee(String uid) => UserEntity(
      uid: uid,
      email: '$uid@x.com',
      authProvider: 'password',
      role: UserRole.employee,
      branchId: 'branch1',
      displayName: uid,
    );

void main() {
  test('deleteAccount removes the person from the refreshed list', () async {
    final keep = _employee('keep');
    final gone = _employee('gone');
    final repo = _FakeUserAdminRepository([keep, gone]);
    final cubit = AdminUsersCubit(repo, _FakeBranchRepository());
    addTearDown(cubit.close);

    await cubit.load(AdminUserFilter.employees);
    expect(
      cubit.state.maybeWhen(loaded: (u, _) => u.length, orElse: () => -1),
      2,
    );

    await cubit.deleteAccount(gone);

    expect(repo.deleted, ['gone']);
    final remaining = cubit.state.maybeWhen(
      loaded: (u, _) => u.map((e) => e.uid).toList(),
      orElse: () => const <String>[],
    );
    expect(remaining, ['keep']);
  });

  test('a delete failure surfaces an error and keeps the prior list', () async {
    final gone = _employee('gone');
    final repo = _ThrowingRepository([gone]);
    final cubit = AdminUsersCubit(repo, _FakeBranchRepository());
    addTearDown(cubit.close);

    await cubit.load(AdminUserFilter.employees);
    final errors = <String>[];
    final sub = cubit.stream.listen((s) {
      final message = s.maybeWhen(error: (m) => m, orElse: () => null);
      if (message != null) errors.add(message);
    });

    await cubit.deleteAccount(gone);
    await Future<void>.delayed(Duration.zero);
    await sub.cancel();

    expect(errors, isNotEmpty);
    // The person is still listed — a failed delete must not drop them locally.
    expect(
      cubit.state.maybeWhen(
        loaded: (u, _) => u.map((e) => e.uid).toList(),
        orElse: () => const <String>[],
      ),
      ['gone'],
    );
  });
}

/// Fails the delete but still answers role queries (the list never shrinks).
class _ThrowingRepository extends _FakeUserAdminRepository {
  _ThrowingRepository(super.users);
  @override
  Future<void> deleteAccount(String uid) async =>
      throw Exception('backend refused');
}
