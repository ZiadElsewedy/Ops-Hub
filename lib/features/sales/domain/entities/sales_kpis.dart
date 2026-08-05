import 'package:freezed_annotation/freezed_annotation.dart';

part 'sales_kpis.freezed.dart';

/// Derived, in-memory sales KPIs. No instance is persisted to Firestore.
@freezed
class SalesKpis with _$SalesKpis {
  const SalesKpis._();

  const factory SalesKpis({
    @Default(0) int daysRemaining,
    @Default(0) int averageApprovedDailyPiastres,
    @Default(0) int requiredDailyRunRatePiastres,
    @Default(0) int monthEndForecastPiastres,
    DateTime? completionDateEstimate,
  }) = _SalesKpis;
}
