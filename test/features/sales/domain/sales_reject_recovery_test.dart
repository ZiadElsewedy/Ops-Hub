import 'package:flutter_test/flutter_test.dart';
import 'package:opshub/core/enums/sales_submission_status.dart';
import 'package:opshub/features/sales/domain/entities/branch_sales_month_entity.dart';
import 'package:opshub/features/sales/domain/entities/daily_sales_submission_entity.dart';
import 'package:opshub/features/sales/domain/entities/sales_month_snapshot.dart';
import 'package:opshub/features/sales/presentation/cubit/sales_manager_dashboard_cubit.dart';
import 'package:opshub/features/sales/presentation/cubit/sales_month_state.dart';

// A rejected daily sales close must (1) be recoverable — its submitter can fix
// and resubmit it — and (2) NOT count as a valid close for "today's" amount.

const _today = '20260809';

DailySalesSubmissionEntity _sub(
  SalesSubmissionStatus status, {
  String date = _today,
  int amount = 3800,
  String submitter = 'me',
}) =>
    DailySalesSubmissionEntity(
      id: 'b1_$date',
      branchId: 'b1',
      monthKey: '202608',
      businessDateKey: date,
      status: status,
      amountPiastres: amount,
      submittedById: submitter,
    );

const _target = BranchSalesMonthEntity(
  id: 'b1_202608',
  branchId: 'b1',
  monthKey: '202608',
  targetPiastres: 100000000,
);

void main() {
  group('DailySalesSubmissionEntity.isResubmittable', () {
    test('a rejected or correction-requested day is resubmittable', () {
      expect(_sub(SalesSubmissionStatus.rejected).isResubmittable, isTrue);
      expect(_sub(SalesSubmissionStatus.correctionRequested).isResubmittable,
          isTrue);
    });

    test('pending and approved are not resubmittable', () {
      expect(_sub(SalesSubmissionStatus.pending).isResubmittable, isFalse);
      expect(_sub(SalesSubmissionStatus.approved).isResubmittable, isFalse);
    });
  });

  group('Manager dashboard todayPiastres excludes a rejected close', () {
    SalesManagerDashboardLoaded loaded(List<DailySalesSubmissionEntity> subs) =>
        SalesManagerDashboardLoaded(
          snapshot: SalesMonthSnapshot(target: _target, submissions: subs),
          monthKey: '202608',
          todayDateKey: _today,
        );

    test('a rejected today reads as no close (null), not its amount', () {
      expect(loaded([_sub(SalesSubmissionStatus.rejected)]).todayPiastres,
          isNull);
    });

    test('a pending today still counts as the day figure', () {
      expect(loaded([_sub(SalesSubmissionStatus.pending)]).todayPiastres, 3800);
    });

    test('an approved today counts', () {
      expect(loaded([_sub(SalesSubmissionStatus.approved)]).todayPiastres, 3800);
    });
  });

  group('Employee SalesMonthLoaded today + recovery', () {
    // The employee snapshot carries only branch-APPROVED records; own records
    // (any status) ride separately on ownSubmissions.
    SalesMonthLoaded loaded({
      List<DailySalesSubmissionEntity> approved = const [],
      List<DailySalesSubmissionEntity> own = const [],
    }) =>
        SalesMonthLoaded(
          snapshot: SalesMonthSnapshot(target: _target, submissions: approved),
          todayDateKey: _today,
          ownSubmissions: own,
        );

    test('a rejected own close is excluded from today\'s counted amount', () {
      expect(
        loaded(own: [_sub(SalesSubmissionStatus.rejected)]).todayCountedPiastres,
        isNull,
      );
    });

    test('a pending own close counts toward today', () {
      expect(
        loaded(own: [_sub(SalesSubmissionStatus.pending)]).todayCountedPiastres,
        3800,
      );
    });

    test('an approved branch close counts even without an own record', () {
      expect(
        loaded(approved: [_sub(SalesSubmissionStatus.approved, amount: 5000)])
            .todayCountedPiastres,
        5000,
      );
    });

    test('resubmittable surfaces rejected and correction-requested own days', () {
      final state = loaded(own: [
        _sub(SalesSubmissionStatus.rejected, date: '20260808'),
        _sub(SalesSubmissionStatus.correctionRequested, date: '20260807'),
        _sub(SalesSubmissionStatus.approved, date: '20260806'),
      ]);
      expect(state.resubmittable.map((s) => s.status), [
        SalesSubmissionStatus.rejected,
        SalesSubmissionStatus.correctionRequested,
      ]);
    });
  });
}
