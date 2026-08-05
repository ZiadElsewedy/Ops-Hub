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
  SalesSubmissionStatus status, {
  String day = '20260801',
}) => DailySalesSubmissionEntity(
  id: '$day-$amount-${status.name}',
  branchId: 'b1',
  monthKey: '202608',
  businessDateKey: day,
  amountPiastres: amount,
  status: status,
);

void main() {
  SalesMonthSnapshot snapshot({
    BranchSalesMonthEntity? target,
    List<DailySalesSubmissionEntity> submissions = const [],
  }) => SalesMonthSnapshot(target: target, submissions: submissions);

  const target = BranchSalesMonthEntity(
    id: 'b1_202608',
    branchId: 'b1',
    monthKey: '202608',
    targetPiastres: 31000,
  );

  test('derives totals, remaining, and raw versus capped progress', () {
    expect(
      sumApprovedPiastres([
        _submission(120, SalesSubmissionStatus.approved),
        _submission(80, SalesSubmissionStatus.pending, day: '20260802'),
      ]),
      120,
    );
    expect(remainingPiastres(100, 120), 0);
    expect(progressRatioRaw(100, 124), 1.24);
    expect(progressRatioCapped(100, 124), 1);
    expect(progressRatioRaw(0, 100), 0);
  });

  test('counts business days, not documents', () {
    expect(
      distinctBusinessDays([
        _submission(10, SalesSubmissionStatus.approved, day: '20260801'),
        _submission(20, SalesSubmissionStatus.approved, day: '20260802'),
        // The same day resubmitted after a correction — still one day.
        _submission(30, SalesSubmissionStatus.approved, day: '20260802'),
      ]),
      2,
    );
    expect(distinctBusinessDays(const []), 0);
  });

  test('averages over approved DAYS, never over elapsed calendar days', () {
    expect(averagePerApprovedDayPiastres(101, 2), 50);
    expect(averagePerApprovedDayPiastres(100, 0), 0);
  });

  test('needed-per-day rounds up and guards a met target', () {
    expect(requiredDailyRunRatePiastres(101, 2), 51);
    expect(requiredDailyRunRatePiastres(0, 5), 0);
    expect(requiredDailyRunRatePiastres(100, 0), 0);
  });

  test('selling days remaining includes today', () {
    expect(sellingDaysRemaining(31, 10), 22);
    // The last day of the month is still a selling day — the exclusive version
    // returned 0 here and collapsed "needed per day" to zero.
    expect(sellingDaysRemaining(31, 31), 1);
    expect(sellingDaysRemaining(31, 40), 0);
  });

  test('forecast only projects days that carry no record', () {
    expect(monthEndForecastPiastres(100, 50, 2), 200);
    expect(monthEndForecastPiastres(100, 50, 0), 100);
    expect(monthEndForecastPiastres(100, 0, 10), 100);
  });

  test('pace names the one decision the figures support', () {
    expect(
      salesPace(
        targetPiastres: 100,
        approvedPiastres: 100,
        expectedMonthEndPiastres: 100,
        approvedDayCount: 3,
      ),
      SalesPace.achieved,
    );
    expect(
      salesPace(
        targetPiastres: 100,
        approvedPiastres: 0,
        expectedMonthEndPiastres: 0,
        approvedDayCount: 0,
      ),
      SalesPace.noData,
    );
    expect(
      salesPace(
        targetPiastres: 100,
        approvedPiastres: 40,
        expectedMonthEndPiastres: 120,
        approvedDayCount: 2,
      ),
      SalesPace.onTrack,
    );
    expect(
      salesPace(
        targetPiastres: 100,
        approvedPiastres: 40,
        expectedMonthEndPiastres: 60,
        approvedDayCount: 2,
      ),
      SalesPace.behind,
    );
  });

  test('composes mid-month KPIs from the approved ledger', () {
    final kpis = computeSalesKpis(
      snapshot(
        target: target,
        submissions: [
          _submission(9000, SalesSubmissionStatus.approved, day: '20260801'),
          _submission(6000, SalesSubmissionStatus.approved, day: '20260802'),
        ],
      ),
      now: DateTime.utc(2026, 8, 10, 10),
    );

    // 31-day month, day 10 → 22 selling days left including today.
    expect(kpis.daysRemaining, 22);
    expect(kpis.approvedDayCount, 2);
    // 15,000 over 2 approved days — NOT over the 10 calendar days elapsed.
    expect(kpis.averagePerApprovedDayPiastres, 7500);
    // 16,000 remaining over 22 days, rounded up.
    expect(kpis.neededPerDayPiastres, 728);
    // 29 days carry no record yet: 15,000 + 7,500 × 29.
    expect(kpis.expectedMonthEndPiastres, 232500);
  });

  test('returns safe KPI defaults without a target or any approved day', () {
    expect(
      computeSalesKpis(snapshot(), now: DateTime.utc(2026, 8, 10)),
      const SalesKpis(),
    );
    final kpis = computeSalesKpis(
      snapshot(target: target),
      now: DateTime.utc(2026, 8, 1),
    );
    expect(kpis.averagePerApprovedDayPiastres, 0);
    expect(kpis.approvedDayCount, 0);
    // 31,000 spread over all 31 days of the month.
    expect(kpis.neededPerDayPiastres, 1000);
    expect(kpis.expectedMonthEndPiastres, 0);
  });

  test('still asks for the shortfall on the last day of the month', () {
    final kpis = computeSalesKpis(
      snapshot(
        target: target,
        submissions: [
          _submission(30000, SalesSubmissionStatus.approved, day: '20260801'),
        ],
      ),
      now: DateTime.utc(2026, 8, 31, 10),
    );
    expect(kpis.daysRemaining, 1);
    // The old exclusive day count made this 0 while the branch was 1,000 short.
    expect(kpis.neededPerDayPiastres, 1000);
  });

  test('handles an already-met target at month end', () {
    final kpis = computeSalesKpis(
      snapshot(
        target: target,
        submissions: [
          _submission(32000, SalesSubmissionStatus.approved, day: '20260801'),
        ],
      ),
      now: DateTime.utc(2026, 8, 31, 10),
    );
    expect(kpis.daysRemaining, 1);
    expect(kpis.neededPerDayPiastres, 0);
    expect(
      salesPace(
        targetPiastres: target.targetPiastres,
        approvedPiastres: 32000,
        expectedMonthEndPiastres: kpis.expectedMonthEndPiastres,
        approvedDayCount: kpis.approvedDayCount,
      ),
      SalesPace.achieved,
    );
  });
}
