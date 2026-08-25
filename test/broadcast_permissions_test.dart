import 'package:flutter_test/flutter_test.dart';
import 'package:opshub/core/enums/broadcast_audience.dart';
import 'package:opshub/core/enums/user_role.dart';
import 'package:opshub/features/communications/domain/broadcast_permissions.dart';

/// The recipient-resolution permission matrix (client-side guard). The
/// `sendBroadcast` Cloud Function enforces the identical rules authoritatively;
/// these tests lock the matrix that the UI + cubit rely on.
void main() {
  group('BroadcastPermissions.canSend', () {
    test('admin may send to every audience', () {
      for (final a in BroadcastAudience.values) {
        expect(BroadcastPermissions.canSend(UserRole.admin, a), isTrue,
            reason: 'admin → $a');
      }
    });

    test('manager may send to a branch or an individual, never all branches',
        () {
      expect(BroadcastPermissions.canSend(UserRole.manager, BroadcastAudience.branch), isTrue);
      expect(BroadcastPermissions.canSend(UserRole.manager, BroadcastAudience.user), isTrue);
      expect(BroadcastPermissions.canSend(UserRole.manager, BroadcastAudience.allBranches), isFalse);
    });

    test('employee may not send anything', () {
      for (final a in BroadcastAudience.values) {
        expect(BroadcastPermissions.canSend(UserRole.employee, a), isFalse,
            reason: 'employee → $a');
      }
      expect(BroadcastPermissions.canBroadcast(UserRole.employee), isFalse);
    });

    test('allowedAudiences excludes the derived custom audience', () {
      // `custom` is derived (a multi-pick under the people picker), not a chip.
      expect(BroadcastPermissions.allowedAudiences(UserRole.admin), [
        BroadcastAudience.allBranches,
        BroadcastAudience.branch,
        BroadcastAudience.user,
      ]);
      expect(BroadcastPermissions.allowedAudiences(UserRole.manager),
          [BroadcastAudience.branch, BroadcastAudience.user]);
      expect(BroadcastPermissions.allowedAudiences(UserRole.employee), isEmpty);
      // custom is still permitted (canSend) for admin + manager, just not listed.
      expect(
          BroadcastPermissions.canSend(UserRole.manager, BroadcastAudience.custom),
          isTrue);
      expect(
          BroadcastPermissions.canSend(UserRole.employee, BroadcastAudience.custom),
          isFalse);
    });
  });

  group('BroadcastPermissions.validate', () {
    test('admin all-branches is allowed', () {
      expect(
        BroadcastPermissions.validate(
          role: UserRole.admin,
          audience: BroadcastAudience.allBranches,
        ),
        isNull,
      );
    });

    test('manager all-branches is rejected', () {
      expect(
        BroadcastPermissions.validate(
          role: UserRole.manager,
          audience: BroadcastAudience.allBranches,
          senderBranchId: 'b1',
        ),
        isNotNull,
      );
    });

    test('manager branch send is allowed only for their own branch', () {
      expect(
        BroadcastPermissions.validate(
          role: UserRole.manager,
          audience: BroadcastAudience.branch,
          senderBranchId: 'b1',
          targetBranchId: 'b1',
        ),
        isNull,
      );
      expect(
        BroadcastPermissions.validate(
          role: UserRole.manager,
          audience: BroadcastAudience.branch,
          senderBranchId: 'b1',
          targetBranchId: 'b2',
        ),
        isNotNull,
      );
    });

    test('manager individual send only inside their own branch', () {
      expect(
        BroadcastPermissions.validate(
          role: UserRole.manager,
          audience: BroadcastAudience.user,
          senderBranchId: 'b1',
          targetUserBranchId: 'b1',
        ),
        isNull,
      );
      expect(
        BroadcastPermissions.validate(
          role: UserRole.manager,
          audience: BroadcastAudience.user,
          senderBranchId: 'b1',
          targetUserBranchId: 'b2',
        ),
        isNotNull,
      );
    });

    test('admin individual send to any branch is allowed', () {
      expect(
        BroadcastPermissions.validate(
          role: UserRole.admin,
          audience: BroadcastAudience.user,
          targetUserBranchId: 'b9',
        ),
        isNull,
      );
    });

    test('manager with no branch assigned is rejected', () {
      expect(
        BroadcastPermissions.validate(
          role: UserRole.manager,
          audience: BroadcastAudience.branch,
          senderBranchId: '',
          targetBranchId: '',
        ),
        isNotNull,
      );
    });

    test('employee is always rejected', () {
      expect(
        BroadcastPermissions.validate(
          role: UserRole.employee,
          audience: BroadcastAudience.branch,
          senderBranchId: 'b1',
          targetBranchId: 'b1',
        ),
        isNotNull,
      );
    });
  });
}
