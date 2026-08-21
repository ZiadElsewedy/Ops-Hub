import 'dart:math' as math;

import 'package:opshub/features/sales/domain/entities/daily_sales_submission_entity.dart';

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

/// How today's close measures against what today needed to bring in.
///
/// This is the one signal the sales surfaces colour. It is deliberately about
/// **today**, not the month: a month can be behind while today was a good day,
/// and that is exactly the distinction a branch acts on.
enum SalesDayPace {
  /// Today met or beat what the remaining days each need. Green.
  onPace,

  /// Today landed at 50–99% of what it needed. Amber.
  close,

  /// Today landed under half of what it needed. Red.
  behind,

  /// Nothing to judge — no target, target already met, or no close submitted
  /// yet today. Rendered neutral, never as a failure.
  none,
}

SalesDayPace salesDayPace({
  required int neededPerDayPiastres,
  required int? todayPiastres,
}) {
  // Nothing needed today (no target, or the month is already won) is not a
  // failure and must never render red.
  if (neededPerDayPiastres <= 0) return SalesDayPace.none;
  if (todayPiastres == null) return SalesDayPace.none;
  if (todayPiastres >= neededPerDayPiastres) return SalesDayPace.onPace;
  // Halve the requirement rather than scaling the day, so integer piastres
  // never round a genuine 50% down into the red band.
  return todayPiastres * 2 >= neededPerDayPiastres
      ? SalesDayPace.close
      : SalesDayPace.behind;
}

/// Where the **month** is headed against target — the "are we going to make it?"
/// verdict the pace card leads with.
///
/// Deliberately read off the forecast ([monthEndForecastPiastres]), never a
/// naive achieved-to-date vs. elapsed-days comparison: approvals lag by a day
/// or more, so the latter reads "behind" every single day even for a branch
/// comfortably on pace. The forecast counts recorded days at their real value
/// and projects only unrecorded days at the branch's average approved day.
enum SalesTargetOutlook {
  /// Projected to finish at or above target. Green — the only "good" state.
  ahead,

  /// Projected to finish short of target. Amber — a nudge, not a failure.
  behind,

  /// No approved day yet, so any projection would be invented. Neutral.
  tooEarly,
}

SalesTargetOutlook salesTargetOutlook({
  required int expectedMonthEndPiastres,
  required int targetPiastres,
  required int approvedDayCount,
}) {
  if (targetPiastres <= 0 || approvedDayCount <= 0) {
    return SalesTargetOutlook.tooEarly;
  }
  return expectedMonthEndPiastres >= targetPiastres
      ? SalesTargetOutlook.ahead
      : SalesTargetOutlook.behind;
}
