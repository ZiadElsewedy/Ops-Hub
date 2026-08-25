import 'package:opshub/core/enums/sales_submission_status.dart';
import 'package:opshub/features/sales/domain/entities/daily_sales_submission_entity.dart';
import 'package:opshub/features/sales/domain/entities/sales_month_snapshot.dart';
import 'package:opshub/features/sales/domain/sales_trend.dart';
import 'package:flutter_test/flutter_test.dart';

DailySalesSubmissionEntity _sub(
  String day,
  int amount, [
  SalesSubmissionStatus status = SalesSubmissionStatus.approved,
]) => DailySalesSubmissionEntity(
  id: '$day-$amount-${status.name}',
  branchId: 'b1',
  monthKey: '202608',
  businessDateKey: day,
  amountPiastres: amount,
  status: status,
);

void main() {
  // 2026-08-10 10:00 UTC is 13:00 in Cairo (August is DST, UTC+3), so the
  // business day is 2026-08-10 and the trailing window is 04→10 August.
  final now = DateTime.utc(2026, 8, 10, 10);

  SalesTrend trendOf(List<DailySalesSubmissionEntity> submissions) =>
      computeSalesTrend(
        SalesMonthSnapshot(submissions: submissions),
        now: now,
      );

  test('builds seven oldest-first days ending on today', () {
    final trend = trendOf([_sub('20260810', 2660)]);
    expect(trend.days.length, SalesTrend.window);
    expect(trend.days.first.businessDateKey, '20260804');
    expect(trend.days.last.businessDateKey, '20260810');
    expect(trend.days.last.isToday, isTrue);
    expect(trend.days.where((d) => d.isToday).length, 1);
  });

  test('counts only approved money, per business day', () {
    final trend = trendOf([
      _sub('20260810', 2660),
      _sub('20260809', 2450),
      _sub('20260808', 2270),
      _sub('20260806', 1930),
      // Ignored: a pending close on an approved day does not inflate it.
      _sub('20260808', 500, SalesSubmissionStatus.pending),
      // Ignored: a rejected close is not takings.
      _sub('20260805', 900, SalesSubmissionStatus.rejected),
    ]);

    int on(String day) => trend.days
        .firstWhere((d) => d.businessDateKey == day)
        .approvedPiastres;

    expect(on('20260808'), 2270); // pending did not add to it
    expect(on('20260806'), 1930);
    expect(on('20260807'), 0); // no close at all
    expect(on('20260805'), 0); // rejected only
    expect(trend.peakPiastres, 2660);
    expect(trend.hasAnyApproved, isTrue);

    // Average over the four APPROVED days, not the seven calendar days.
    expect(trend.averagePerDayPiastres, (2660 + 2450 + 2270 + 1930) ~/ 4);
  });

  test('compares against the previous window for the trend chip', () {
    final trend = trendOf([
      _sub('20260810', 3000),
      _sub('20260809', 3000),
      // Previous window (28 Jul → 3 Aug):
      _sub('20260801', 1000),
      _sub('20260802', 1500),
    ]);

    expect(trend.averagePerDayPiastres, 3000); // (3000+3000)/2
    expect(trend.previousAveragePerDayPiastres, 1250); // (1000+1500)/2
    expect(trend.changeRatio, closeTo((3000 - 1250) / 1250, 1e-9));
  });

  test('no baseline means no misleading percentage', () {
    // Approved days only in the current window; the prior window is empty.
    final trend = trendOf([_sub('20260810', 2000)]);
    expect(trend.previousAveragePerDayPiastres, 0);
    expect(trend.changeRatio, isNull);
  });

  test('an empty ledger has nothing to draw', () {
    final trend = trendOf(const []);
    expect(trend.days.length, SalesTrend.window);
    expect(trend.hasAnyApproved, isFalse);
    expect(trend.averagePerDayPiastres, 0);
    expect(trend.peakPiastres, 0);
    expect(trend.changeRatio, isNull);
  });
}
