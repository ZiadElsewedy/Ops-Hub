import 'package:flutter_test/flutter_test.dart';
import 'package:opshub/core/enums/user_role.dart';
import 'package:opshub/features/admin/domain/repositories/user_admin_repository.dart';
import 'package:opshub/features/admin/presentation/cubit/admin_users_cubit.dart';
import 'package:opshub/features/auth/domain/entities/user_entity.dart';
import 'package:opshub/features/branch/domain/entities/branch_entity.dart';
import 'package:opshub/features/branch/domain/repositories/branch_repository.dart';

/// Pins the people-directory invalidation seam: whenever the admin changes the
/// user set, `onUsersChanged` must fire so the chat + task name caches refresh
/// (a new/renamed teammate resolves to a real name instead of "Teammate" /
/// "Someone" until an app restart). A *failed* change must NOT fire it.
class _FakeUserAdminRepository implements UserAdminRepository {
  _FakeUserAdminRepository(this._users);
  final List<UserEntity> _users;
  bool failCreate = false;

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
    if (failCreate) throw Exception('backend refused');
    const uid = 'new-uid';
    _users.add(UserEntity(
      uid: uid,
      email: email,
      authProvider: 'password',
      role: role,
      branchId: branchId,
      displayName: name,
    ));
    return uid;
  }

  @override
  Future<void> deleteAccount(String uid) async =>
      _users.removeWhere((u) => u.uid == uid);

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
  test('createAccount fires onUsersChanged once on success', () async {
    final repo = _FakeUserAdminRepository([]);
    var calls = 0;
    final cubit = AdminUsersCubit(
      repo,
      _FakeBranchRepository(),
      onUsersChanged: () => calls++,
    );
    addTearDown(cubit.close);

    await cubit.createAccount(
      name: 'New Hire',
      email: 'new@x.com',
      temporaryPassword: 'temp1234',
      role: UserRole.employee,
      branchId: 'branch1',
    );

    expect(calls, 1);
  });

  test('a failed createAccount does NOT fire onUsersChanged', () async {
    final repo = _FakeUserAdminRepository([])..failCreate = true;
    var calls = 0;
    final cubit = AdminUsersCubit(
      repo,
      _FakeBranchRepository(),
      onUsersChanged: () => calls++,
    );
    addTearDown(cubit.close);

    await expectLater(
      cubit.createAccount(
        name: 'New Hire',
        email: 'new@x.com',
        temporaryPassword: 'temp1234',
        role: UserRole.employee,
      ),
      throwsA(isA<Exception>()),
    );

    expect(calls, 0);
  });

  test('a mutation (delete) fires onUsersChanged on success', () async {
    final gone = _employee('gone');
    final repo = _FakeUserAdminRepository([gone]);
    var calls = 0;
    final cubit = AdminUsersCubit(
      repo,
      _FakeBranchRepository(),
      onUsersChanged: () => calls++,
    );
    addTearDown(cubit.close);

    await cubit.load(AdminUserFilter.employees);
    await cubit.deleteAccount(gone);

    expect(calls, 1);
  });
}
