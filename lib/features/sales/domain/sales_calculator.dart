import 'dart:math' as math;

import 'package:drop/features/sales/domain/entities/daily_sales_submission_entity.dart';

int sumApprovedPiastres(Iterable<DailySalesSubmissionEntity> submissions) =>
    submissions
        .where((submission) => submission.isApproved)
        .fold(
          0,
          (total, submission) => total + math.max(0, submission.amountPiastres),
        );

int remainingPiastres(int target, int achieved) =>
    math.max(0, math.max(0, target) - math.max(0, achieved));

double progressRatioRaw(int target, int achieved) =>
    target <= 0 ? 0 : math.max(0, achieved) / target;

double progressRatioCapped(int target, int achieved) =>
    progressRatioRaw(target, achieved).clamp(0, 1).toDouble();

int averageApprovedDailyPiastres(int approvedTotal, int elapsedDays) =>
    elapsedDays <= 0 ? 0 : math.max(0, approvedTotal) ~/ elapsedDays;

int requiredDailyRunRatePiastres(int remaining, int daysRemaining) {
  if (remaining <= 0 || daysRemaining <= 0) return 0;
  return (remaining + daysRemaining - 1) ~/ daysRemaining;
}

int calendarDaysRemaining(int daysInMonth, int elapsedDays) =>
    math.max(0, daysInMonth - math.max(0, elapsedDays));

/// Calendar-day run-rate forecast; it intentionally does not infer opening days.
int monthEndForecastPiastres(
  int approvedTotal,
  int averageDailyPiastres,
  int daysRemaining,
) =>
    math.max(0, approvedTotal) +
    math.max(0, averageDailyPiastres) * math.max(0, daysRemaining);

DateTime? completionDateEstimate({
  required int targetPiastres,
  required int approvedPiastres,
  required int averageDailyPiastres,
  required DateTime today,
}) {
  if (targetPiastres <= 0 || approvedPiastres >= targetPiastres) return today;
  if (averageDailyPiastres <= 0) return null;
  final days =
      (targetPiastres - approvedPiastres + averageDailyPiastres - 1) ~/
      averageDailyPiastres;
  return DateTime(today.year, today.month, today.day).add(Duration(days: days));
}
