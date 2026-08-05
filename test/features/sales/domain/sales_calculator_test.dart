import 'package:drop/core/enums/sales_submission_status.dart';
import 'package:drop/features/sales/domain/entities/daily_sales_submission_entity.dart';
import 'package:drop/features/sales/domain/sales_calculator.dart';
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
}
