import 'dart:math' as math;

import 'package:opshub/features/sales/domain/entities/sales_kpis.dart';
import 'package:opshub/features/sales/domain/entities/sales_month_snapshot.dart';
import 'package:opshub/features/sales/domain/sales_business_time.dart';
import 'package:opshub/features/sales/domain/sales_calculator.dart';

/// Composes the current month's read-only KPIs from the sales ledger.
///
/// [now] is injected so Cairo calendar calculations stay deterministic and this
/// domain function remains independent of Flutter and Firebase.
SalesKpis computeSalesKpis(
  SalesMonthSnapshot snapshot, {
  required DateTime now,
}) {
  if (!snapshot.hasTarget) return const SalesKpis();

  final approvedTotal = snapshot.approvedTotalPiastres;
  final daysInMonth = calendarDaysInMonth(now);
  final elapsedDays = calendarDaysElapsed(now);
  final daysRemaining = sellingDaysRemaining(daysInMonth, elapsedDays);

  final approvedDayCount = distinctBusinessDays(snapshot.approved);
  final average = averagePerApprovedDayPiastres(
    approvedTotal,
    approvedDayCount,
  );

  // Days the branch has not closed at all yet — the only days a projection may
  // invent takings for. Days already recorded count at their real value.
  final recordedDayCount = distinctBusinessDays(snapshot.submissions);
  final unrecordedDays = math.max(0, daysInMonth - recordedDayCount);

  return SalesKpis(
    daysRemaining: daysRemaining,
    approvedDayCount: approvedDayCount,
    averagePerApprovedDayPiastres: average,
    neededPerDayPiastres: requiredDailyRunRatePiastres(
      snapshot.remainingPiastres,
      daysRemaining,
    ),
    expectedMonthEndPiastres: monthEndForecastPiastres(
      approvedTotal,
      average,
      unrecordedDays,
    ),
  );
}
