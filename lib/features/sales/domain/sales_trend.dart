import 'dart:math' as math;

import 'package:opshub/features/sales/domain/entities/sales_month_snapshot.dart';
import 'package:opshub/features/sales/domain/sales_business_time.dart';

/// One day in the trailing sales trend: a business date and the **approved**
/// takings that closed on it (0 when the day has no approved close yet).
class SalesTrendDay {
  const SalesTrendDay({
    required this.businessDateKey,
    required this.approvedPiastres,
    required this.isToday,
  });

  final String businessDateKey;
  final int approvedPiastres;
  final bool isToday;

  bool get hasApproved => approvedPiastres > 0;
}

/// A descriptive read of recent pace: the day-by-day approved takings for the
/// trailing window, its average, and the average of the window immediately
/// before it (the baseline the trend chip compares against).
///
/// Only **approved** money counts — a pending or rejected close is not takings.
/// No instance is persisted; this is derived on read from the ledger already in
/// memory, so the chart costs zero extra Firestore reads.
class SalesTrend {
  const SalesTrend({
    required this.days,
    required this.averagePerDayPiastres,
    required this.previousAveragePerDayPiastres,
  });

  /// The trailing window, **oldest → newest**, exactly [window] entries; the
  /// last entry is always today.
  final List<SalesTrendDay> days;

  /// Mean takings of the **approved days** in the window, not of the calendar
  /// days. Approvals lag by a day or more, so dividing by the window length
  /// would understate pace whenever the newest day has no approval yet — the
  /// same trap `averagePerApprovedDayPiastres` avoids month-wide.
  final int averagePerDayPiastres;

  /// The same average for the window immediately before this one.
  final int previousAveragePerDayPiastres;

  /// How many trailing days the trend spans.
  static const int window = 7;

  /// The tallest bar — the denominator for drawing the chart to scale.
  int get peakPiastres =>
      days.fold(0, (max, day) => math.max(max, day.approvedPiastres));

  /// True when at least one day in the window has an approved close. The pace
  /// card hides itself when this is false: an all-zero chart says nothing and
  /// reads as a component that failed to load.
  bool get hasAnyApproved => days.any((day) => day.hasApproved);

  /// Fractional change of this window's average over the previous window's.
  /// Null when there is no baseline (the previous window had no approved day),
  /// so the surface shows no misleading "+∞%".
  double? get changeRatio {
    if (previousAveragePerDayPiastres <= 0) return null;
    return (averagePerDayPiastres - previousAveragePerDayPiastres) /
        previousAveragePerDayPiastres;
  }
}

/// Builds the trailing [SalesTrend.window]-day approved-sales trend for [now]'s
/// Cairo business day, plus the prior window used as the comparison baseline.
///
/// [now] is injected so the Cairo day math stays deterministic and this remains
/// pure domain — no Flutter, no Firebase.
SalesTrend computeSalesTrend(
  SalesMonthSnapshot snapshot, {
  required DateTime now,
}) {
  const window = SalesTrend.window;
  final todayKey = businessDateKey(now);

  // Approved takings summed per business day. A day corrected and resubmitted
  // still has exactly one approved record, so this never double-counts a day.
  final approvedByDay = <String, int>{};
  for (final submission in snapshot.submissions) {
    if (!submission.isApproved) continue;
    approvedByDay.update(
      submission.businessDateKey,
      (value) => value + math.max(0, submission.amountPiastres),
      ifAbsent: () => math.max(0, submission.amountPiastres),
    );
  }

  // Anchor the walk on Cairo's civil date, in UTC space so subtracting whole
  // days never drifts across the device's local DST transition.
  final cairoToday = cairoCivilTime(now);
  final anchor = DateTime.utc(cairoToday.year, cairoToday.month, cairoToday.day);

  String keyForOffset(int daysAgo) {
    final date = anchor.subtract(Duration(days: daysAgo));
    return '${date.year.toString().padLeft(4, '0')}'
        '${date.month.toString().padLeft(2, '0')}'
        '${date.day.toString().padLeft(2, '0')}';
  }

  List<SalesTrendDay> buildWindow(int startDaysAgo) {
    final out = <SalesTrendDay>[];
    for (var i = window - 1; i >= 0; i--) {
      final key = keyForOffset(startDaysAgo + i);
      out.add(
        SalesTrendDay(
          businessDateKey: key,
          approvedPiastres: approvedByDay[key] ?? 0,
          isToday: key == todayKey,
        ),
      );
    }
    return out;
  }

  int averageApprovedDay(List<SalesTrendDay> days) {
    final approved = days.where((day) => day.hasApproved).toList();
    if (approved.isEmpty) return 0;
    final total = approved.fold(0, (sum, day) => sum + day.approvedPiastres);
    return total ~/ approved.length;
  }

  final current = buildWindow(0);
  final previous = buildWindow(window);
  return SalesTrend(
    days: current,
    averagePerDayPiastres: averageApprovedDay(current),
    previousAveragePerDayPiastres: averageApprovedDay(previous),
  );
}
