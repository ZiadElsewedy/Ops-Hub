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

/// How many distinct business days these records cover. A branch closes once per
/// day, so this is the honest denominator for "per day" figures — counting
/// documents would double-count a day that was corrected and resubmitted.
int distinctBusinessDays(Iterable<DailySalesSubmissionEntity> submissions) =>
    submissions.map((submission) => submission.businessDateKey).toSet().length;

/// Average takings of a day that actually has an **approved** close.
///
/// Deliberately NOT divided by calendar days elapsed: approvals lag by a day or
/// more, so the newest day (or two) of every month-to-date has no approved
/// record yet. Dividing by elapsed calendar days understated the branch's pace
/// every single day and dragged the forecast down with it.
int averagePerApprovedDayPiastres(int approvedTotal, int approvedDayCount) =>
    approvedDayCount <= 0 ? 0 : math.max(0, approvedTotal) ~/ approvedDayCount;

/// What each remaining selling day must bring in to land exactly on target.
/// Rounded **up** — landing a piastre short is not hitting the target.
int requiredDailyRunRatePiastres(int remaining, int daysRemaining) {
  if (remaining <= 0 || daysRemaining <= 0) return 0;
  return (remaining + daysRemaining - 1) ~/ daysRemaining;
}

/// Selling days left in the month **including today**.
///
/// Today is still a day the branch can sell, so on the 31st of a 31-day month
/// this is 1, not 0. The exclusive version made "needed per day" collapse to
/// zero on the last day of every month while the branch was still short of its
/// target — the most misleading number on the dashboard.
int sellingDaysRemaining(int daysInMonth, int elapsedDays) => math.max<int>(
  0,
  math.max<int>(0, daysInMonth) - math.max<int>(0, elapsedDays) + 1,
);

/// Where the month lands if every day with no record yet performs like an
/// average approved day. Days already recorded are counted at their real value
/// (they are inside [approvedTotal]) and never re-projected.
int monthEndForecastPiastres(
  int approvedTotal,
  int averagePerApprovedDay,
  int unrecordedDaysRemaining,
) =>
    math.max(0, approvedTotal) +
    math.max(0, averagePerApprovedDay) * math.max(0, unrecordedDaysRemaining);

/// The single plain-language verdict the pace figures exist to support.
enum SalesPace {
  /// The target is already met — nothing left to decide.
  achieved,

  /// No approved day yet, so there is no pace to judge.
  noData,

  /// Projected to finish the month at or above target.
  onTrack,

  /// Projected to finish short — this is the day to intervene.
  behind,
}

SalesPace salesPace({
  required int targetPiastres,
  required int approvedPiastres,
  required int expectedMonthEndPiastres,
  required int approvedDayCount,
}) {
  if (targetPiastres <= 0) return SalesPace.noData;
  if (approvedPiastres >= targetPiastres) return SalesPace.achieved;
  if (approvedDayCount <= 0) return SalesPace.noData;
  return expectedMonthEndPiastres >= targetPiastres
      ? SalesPace.onTrack
      : SalesPace.behind;
}
