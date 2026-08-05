import 'package:drop/core/enums/sales_submission_status.dart';
import 'package:drop/features/sales/domain/entities/daily_sales_submission_entity.dart';
import 'package:drop/features/sales/domain/sales_calculator.dart';
import 'package:drop/features/sales/domain/entities/branch_sales_month_entity.dart';
import 'package:drop/features/sales/domain/entities/sales_month_snapshot.dart';
import 'package:drop/features/sales/domain/entities/sales_kpis.dart';
import 'package:drop/features/sales/domain/sales_kpis_calculator.dart';
import 'package:flutter_test/flutter_test.dart';

DailySalesSubmissionEntity _submission(
  int amount,
  SalesSubmissionStatus status,
) => DailySalesSubmissionEntity(
  id: '$amount-${status.name}',
  branchId: 'b1',
  monthKey: '202608',
  businessDateKey: '20260801',
  amountPiastres: amount,
  status: status,
);

void main() {
  SalesMonthSnapshot snapshot({
    BranchSalesMonthEntity? target,
    List<DailySalesSubmissionEntity> submissions = const [],
  }) => SalesMonthSnapshot(target: target, submissions: submissions);

  final target = BranchSalesMonthEntity(
    id: 'b1_202608',
    branchId: 'b1',
    monthKey: '202608',
    targetPiastres: 31000,
  );

  test('derives totals, remaining, and raw versus capped progress', () {
    expect(
      sumApprovedPiastres([
        _submission(120, SalesSubmissionStatus.approved),
        _submission(80, SalesSubmissionStatus.pending),
      ]),
      120,
    );
    expect(remainingPiastres(100, 120), 0);
    expect(progressRatioRaw(100, 124), 1.24);
    expect(progressRatioCapped(100, 124), 1);
  });

  test('uses integer calendar-day run rates and safe zero guards', () {
    expect(averageApprovedDailyPiastres(101, 2), 50);
    expect(averageApprovedDailyPiastres(100, 0), 0);
    expect(requiredDailyRunRatePiastres(101, 2), 51);
    expect(requiredDailyRunRatePiastres(100, 0), 0);
    expect(calendarDaysRemaining(31, 32), 0);
    expect(monthEndForecastPiastres(100, 50, 2), 200);
    expect(progressRatioRaw(0, 100), 0);
    expect(
      completionDateEstimate(
        targetPiastres: 0,
        approvedPiastres: 0,
        averageDailyPiastres: 10,
        today: DateTime(2026, 8, 1),
      ),
      DateTime(2026, 8, 1),
    );
    expect(
      completionDateEstimate(
        targetPiastres: 100,
        approvedPiastres: 20,
        averageDailyPiastres: 0,
        today: DateTime(2026, 8, 1),
      ),
      isNull,
    );
  });

  test('composes mid-month KPIs from the approved ledger', () {
    final kpis = computeSalesKpis(
      snapshot(
        target: target,
        submissions: [_submission(15000, SalesSubmissionStatus.approved)],
      ),
      now: DateTime.utc(2026, 8, 10, 10),
    );

    expect(kpis.daysRemaining, 21);
    expect(kpis.averageApprovedDailyPiastres, 1500);
    expect(kpis.requiredDailyRunRatePiastres, 762);
    expect(kpis.monthEndForecastPiastres, 46500);
    expect(kpis.completionDateEstimate, DateTime(2026, 8, 21));
  });

  test('returns safe KPI defaults without a target or elapsed time', () {
    expect(
      computeSalesKpis(snapshot(), now: DateTime.utc(2026, 8, 10)),
      const SalesKpis(),
    );
    final kpis = computeSalesKpis(
      snapshot(target: target),
      now: DateTime.utc(2026, 8, 1),
    );
    expect(kpis.averageApprovedDailyPiastres, 0);
    expect(kpis.requiredDailyRunRatePiastres, 1034);
    expect(kpis.completionDateEstimate, isNull);
  });

  test('handles an already-met target at month end', () {
    final kpis = computeSalesKpis(
      snapshot(
        target: target,
        submissions: [_submission(32000, SalesSubmissionStatus.approved)],
      ),
      now: DateTime.utc(2026, 8, 31, 10),
    );
    expect(kpis.daysRemaining, 0);
    expect(kpis.requiredDailyRunRatePiastres, 0);
    expect(kpis.completionDateEstimate, DateTime(2026, 8, 31));
  });
}
