import 'package:freezed_annotation/freezed_annotation.dart';

part 'sales_kpis.freezed.dart';

/// Derived, in-memory sales KPIs. No instance is persisted to Firestore.
///
/// Every field answers one question a manager actually asks. If a figure stops
/// answering one, delete it rather than leaving it on the dashboard.
@freezed
class SalesKpis with _$SalesKpis {
  const SalesKpis._();

  const factory SalesKpis({
    /// Selling days left this month, **including today**.
    @Default(0) int daysRemaining,

    /// Distinct business days that already have an approved close.
    @Default(0) int approvedDayCount,

    /// Average takings of an approved day — the branch's real pace.
    @Default(0) int averagePerApprovedDayPiastres,

    /// What each remaining day must bring in to land on target.
    @Default(0) int neededPerDayPiastres,

    /// Where the month lands if unrecorded days perform like an average day.
    @Default(0) int expectedMonthEndPiastres,
  }) = _SalesKpis;
}
