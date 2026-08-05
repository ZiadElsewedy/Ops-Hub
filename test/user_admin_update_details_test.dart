import 'package:flutter_test/flutter_test.dart';
import 'package:drop/core/enums/user_role.dart';
import 'package:drop/features/admin/data/datasources/user_admin_remote_datasource.dart';
import 'package:drop/features/admin/data/repositories/user_admin_repository_impl.dart';
import 'package:drop/features/admin/domain/entities/user_compensation.dart';
import 'package:drop/features/auth/data/models/user_model.dart';

/// Captures the exact merge map an admin "Edit Info" write produces — the
/// behaviour the owner asked for: edit a person's contact details anytime after
/// account creation, without touching privileged fields.
class _CapturingDataSource implements UserAdminRemoteDataSource {
  String? lastUid;
  Map<String, dynamic>? lastData;
  String? lastCompensationUid;
  UserCompensation? lastCompensation;
  String? deletedUid;

  @override
  Future<void> updateUser(String uid, Map<String, dynamic> data) async {
    lastUid = uid;
    lastData = data;
  }

  // Unused by these tests.
  @override
  Future<List<UserModel>> getAllUsers() async => const [];
  @override
  Future<List<UserModel>> getUsersByRole(String role) async => const [];
  @override
  Future<String> createAccount({
    required String name,
    required String email,
    required String password,
    required String role,
    String? branchId,
    String? assignedShift,
    String? position,
  }) async =>
      'uid';
  @override
  Future<void> resetPassword({
    required String uid,
    required String tempPassword,
  }) async {}
  @override
  Future<void> deleteAccount(String uid) async {
    deletedUid = uid;
  }
  @override
  Future<UserCompensation> getCompensation(String uid) async =>
      UserCompensation.empty;
  @override
  Future<void> setCompensation(String uid, UserCompensation compensation) async {
    lastCompensationUid = uid;
    lastCompensation = compensation;
  }
}

void main() {
  group('UserAdminRepository.updateUserDetails', () {
    late _CapturingDataSource ds;
    late UserAdminRepositoryImpl repo;

    setUp(() {
      ds = _CapturingDataSource();
      repo = UserAdminRepositoryImpl(ds);
    });

    test('writes name (mirrored to fullName) + phone + address + emergency', () async {
      await repo.updateUserDetails(
        'u1',
        displayName: 'Ahmed Hassan',
        phoneNumber: '+201000000000',
        address: '12 Tahrir St, Cairo',
        emergencyContact: 'Mona · +201111111111',
      );

      expect(ds.lastUid, 'u1');
      final data = ds.lastData!;
      expect(data['displayName'], 'Ahmed Hassan');
      // displayName is mirrored to the legacy profile `fullName` key.
      expect(data['fullName'], 'Ahmed Hassan');
      expect(data['phoneNumber'], '+201000000000');
      expect(data['address'], '12 Tahrir St, Cairo');
      expect(data['emergencyContact'], 'Mona · +201111111111');
      // NEVER touches privileged/role fields in this path.
      expect(data.containsKey('role'), isFalse);
      expect(data.containsKey('branchId'), isFalse);
      expect(data.containsKey('isActive'), isFalse);
      expect(data.containsKey('employmentStatus'), isFalse);
    });

    test('only sends the fields provided (null fields are omitted)', () async {
      await repo.updateUserDetails('u2', phoneNumber: '+20999');

      final data = ds.lastData!;
      expect(data.keys, contains('phoneNumber'));
      expect(data['phoneNumber'], '+20999');
      // Untouched fields are not written, so a phone-only edit can't blank a name.
      expect(data.containsKey('displayName'), isFalse);
      expect(data.containsKey('fullName'), isFalse);
      expect(data.containsKey('address'), isFalse);
      expect(data.containsKey('emergencyContact'), isFalse);
    });

    test('an empty string clears a field (distinct from null = leave alone)', () async {
      await repo.updateUserDetails('u3', address: '');

      final data = ds.lastData!;
      expect(data.containsKey('address'), isTrue);
      expect(data['address'], '');
    });
  });

  group('UserAdminRepository.updateUserCompensation (C2 fix)', () {
    test('routes to the PRIVATE subdocument write, never the user doc', () async {
      final ds = _CapturingDataSource();
      final repo = UserAdminRepositoryImpl(ds);

      await repo.updateUserCompensation(
        'u9',
        salaryAmount: 4500,
        salaryType: 'monthly',
        paymentMethod: 'wallet',
        paymentNumber: '+2010',
      );

      expect(ds.lastCompensationUid, 'u9');
      expect(ds.lastCompensation,
          isNotNull);
      expect(ds.lastCompensation!.salaryAmount, 4500);
      // The public user-doc write path was NOT used.
      expect(ds.lastData, isNull,
          reason: 'compensation must never land on users/{uid}');
    });
  });

  group('UserAdminRepository.deleteAccount', () {
    test('delegates the uid to the datasource (deleteUserAccount callable)',
        () async {
      final ds = _CapturingDataSource();
      final repo = UserAdminRepositoryImpl(ds);

      await repo.deleteAccount('gone1');

      expect(ds.deletedUid, 'gone1');
      // Hard delete never routes through the ordinary field-update path.
      expect(ds.lastData, isNull);
    });
  });

  // Sanity: the role enum import is exercised so the file matches repo style.
  test('UserRole enum is reachable', () {
    expect(UserRole.employee.value, isNotEmpty);
  });
}
