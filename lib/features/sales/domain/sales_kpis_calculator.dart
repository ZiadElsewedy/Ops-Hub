import 'package:drop/features/sales/domain/entities/sales_kpis.dart';
import 'package:drop/features/sales/domain/entities/sales_month_snapshot.dart';
import 'package:drop/features/sales/domain/sales_business_time.dart';
import 'package:drop/features/sales/domain/sales_calculator.dart';

/// Composes the current month's read-only KPIs from the sales ledger.
///
/// [now] is injected so Cairo calendar calculations stay deterministic and this
/// domain function remains independent of Flutter and Firebase.
SalesKpis computeSalesKpis(SalesMonthSnapshot snapshot, {required DateTime now}) {
  if (!snapshot.hasTarget) return const SalesKpis();

  final approvedTotal = snapshot.approvedTotalPiastres;
  final elapsedDays = calendarDaysElapsed(now);
  final daysRemaining = calendarDaysRemainingInMonth(now);
  final averageDaily = averageApprovedDailyPiastres(approvedTotal, elapsedDays);
  final requiredRunRate = requiredDailyRunRatePiastres(
    snapshot.remainingPiastres,
    daysRemaining,
  );
  final forecast = monthEndForecastPiastres(
    approvedTotal,
    averageDaily,
    daysRemaining,
  );

  return SalesKpis(
    daysRemaining: daysRemaining,
    averageApprovedDailyPiastres: averageDaily,
    requiredDailyRunRatePiastres: requiredRunRate,
    monthEndForecastPiastres: forecast,
    completionDateEstimate: completionDateEstimate(
      targetPiastres: snapshot.target!.targetPiastres,
      approvedPiastres: approvedTotal,
      averageDailyPiastres: averageDaily,
      today: cairoCivilTime(now),
    ),
  );
}
