import 'package:drop/core/routes/app_router.dart';
import 'package:drop/core/routes/route_names.dart';
import 'package:flutter_test/flutter_test.dart';

/// Regression guard for the routing bug that made the whole employee half of
/// Branch Sales unreachable.
///
/// `isManagerArea` used to match `/sales` by PREFIX. Every employee-owned and
/// role-shared sales path lives under `/sales/`, so the manager guard — which
/// runs before the employee-specific checks — bounced every employee straight
/// back to Home: they could not submit a daily close, could not open their own
/// record, and the sales notification deep link dead-ended.
void main() {
  group('sales paths are classified by role, not by prefix', () {
    test('the manager/admin surfaces ARE manager areas', () {
      expect(isManagerArea(RouteNames.salesManage), isTrue);
      expect(isManagerArea(RouteNames.salesHistory), isTrue);
    });

    test('the employee-owned surfaces are NOT manager areas', () {
      expect(isManagerArea(RouteNames.salesSubmit), isFalse);
      expect(isManagerArea(RouteNames.salesMine), isFalse);
    });

    test('the role-shared submission detail is NOT a manager area', () {
      expect(
        isManagerArea(RouteNames.salesSubmissionDetail('b1_20260805')),
        isFalse,
      );
    });

    test('the admin overview is NOT a manager area (it is admin-only)', () {
      expect(isManagerArea(RouteNames.salesAdminOverview), isFalse);
    });

    test('every employee-owned sales path really does sit under /sales/', () {
      // If this ever stops holding, the prefix trap is gone for a different
      // reason and the guard above should be re-read rather than trusted.
      for (final path in [RouteNames.salesSubmit, RouteNames.salesMine]) {
        expect(path.startsWith('${RouteNames.salesManage}/'), isTrue);
      }
    });
  });

  group('sales route builders', () {
    test('history carries branch and status filters', () {
      expect(RouteNames.salesHistoryFor(), RouteNames.salesHistory);
      expect(
        RouteNames.salesHistoryFor(branchId: 'b1', status: 'approved'),
        '${RouteNames.salesHistory}?branchId=b1&status=approved',
      );
      expect(
        RouteNames.salesHistoryFor(status: 'pending'),
        '${RouteNames.salesHistory}?status=pending',
      );
    });

    test('an empty branch id never produces a dangling query', () {
      expect(RouteNames.salesManageFor(''), RouteNames.salesManage);
      expect(
        RouteNames.salesManageFor('b1'),
        '${RouteNames.salesManage}?branchId=b1',
      );
    });
  });
}
