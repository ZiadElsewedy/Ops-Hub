import 'package:flutter_test/flutter_test.dart';
import 'package:opshub/core/enums/request_status.dart';
import 'package:opshub/core/enums/request_type.dart';
import 'package:opshub/core/enums/user_role.dart';
import 'package:opshub/features/auth/domain/entities/user_entity.dart';
import 'package:opshub/features/requests/domain/entities/request_entity.dart';
import 'package:opshub/features/requests/domain/request_access.dart';

void main() {
  UserEntity user(String uid, UserRole role, {String? branch}) => UserEntity(
        uid: uid,
        email: '$uid@x.com',
        authProvider: 'password',
        role: role,
        branchId: branch,
      );

  RequestEntity request({
    String requesterId = 'emp1',
    String? branch = 'b1',
    RequestType type = RequestType.leaveStore,
    RequestStatus status = RequestStatus.pending,
  }) =>
      RequestEntity(
        id: 'r1',
        branchId: branch,
        type: type,
        status: status,
        requesterId: requesterId,
      );

  group('canAccessRequest', () {
    test('the requester, an admin, and an own-branch manager can access', () {
      final r = request(requesterId: 'emp1', branch: 'b1');
      expect(canAccessRequest(user('emp1', UserRole.employee, branch: 'b1'), r),
          isTrue);
      expect(canAccessRequest(user('admin', UserRole.admin), r), isTrue);
      expect(
          canAccessRequest(user('mgr', UserRole.manager, branch: 'b1'), r),
          isTrue);
    });

    test('a manager of another branch cannot access', () {
      final r = request(branch: 'b1');
      expect(
          canAccessRequest(user('mgr', UserRole.manager, branch: 'b2'), r),
          isFalse);
    });

    test('an unrelated employee cannot access', () {
      final r = request(requesterId: 'emp1', branch: 'b1');
      expect(
          canAccessRequest(user('emp2', UserRole.employee, branch: 'b1'), r),
          isFalse);
    });
  });

  group('canDecideRequest', () {
    test('an own-branch manager can decide any request in their branch', () {
      final r = request(type: RequestType.cashRequest, branch: 'b1');
      expect(
          canDecideRequest(user('mgr', UserRole.manager, branch: 'b1'), r),
          isTrue);
    });

    test('a manager of another branch cannot decide', () {
      final r = request(branch: 'b1');
      expect(
          canDecideRequest(user('mgr', UserRole.manager, branch: 'b2'), r),
          isFalse);
    });

    test('any admin can decide', () {
      final r = request(branch: 'b1');
      expect(canDecideRequest(user('admin', UserRole.admin), r), isTrue);
    });

    test('the requesting employee can never decide their own request', () {
      final r = request(requesterId: 'emp1', branch: 'b1');
      expect(
          canDecideRequest(user('emp1', UserRole.employee, branch: 'b1'), r),
          isFalse);
    });
  });

  group('canReopenRequest', () {
    test('admin can reopen only a DECIDED request', () {
      final admin = user('admin', UserRole.admin);
      expect(canReopenRequest(admin, request(status: RequestStatus.approved)),
          isTrue);
      expect(canReopenRequest(admin, request(status: RequestStatus.rejected)),
          isTrue);
      expect(canReopenRequest(admin, request(status: RequestStatus.pending)),
          isFalse);
    });

    test('managers and employees can never reopen', () {
      final decided = request(status: RequestStatus.approved);
      expect(
          canReopenRequest(user('mgr', UserRole.manager, branch: 'b1'), decided),
          isFalse);
      expect(
          canReopenRequest(
              user('emp1', UserRole.employee, branch: 'b1'), decided),
          isFalse);
    });
  });

  group('canDeleteRequest', () {
    test('admin only', () {
      expect(canDeleteRequest(user('admin', UserRole.admin)), isTrue);
      expect(canDeleteRequest(user('mgr', UserRole.manager, branch: 'b1')),
          isFalse);
      expect(canDeleteRequest(user('emp1', UserRole.employee, branch: 'b1')),
          isFalse);
    });
  });

  group('canCommentOnRequest', () {
    test('participants can comment while pending, not once decided', () {
      final pending = request(status: RequestStatus.pending);
      final approved = request(status: RequestStatus.approved);
      final rejected = request(status: RequestStatus.rejected);
      final mgr = user('mgr', UserRole.manager, branch: 'b1');
      expect(canCommentOnRequest(mgr, pending), isTrue);
      expect(canCommentOnRequest(mgr, approved), isFalse);
      expect(canCommentOnRequest(mgr, rejected), isFalse);
    });
  });
}
