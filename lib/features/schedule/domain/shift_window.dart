import 'package:opshub/core/enums/schedule_day.dart';
import 'package:opshub/core/enums/schedule_shift.dart';
import 'package:opshub/features/schedule/domain/shift_hours.dart';
import 'package:opshub/features/schedule/domain/swap_eligibility.dart';

/// Where a shift sits relative to a moment in time.
enum ShiftPhase { upcoming, active, finished }

/// Pure, framework-free time math for a concrete shift slot — the single place
/// that turns a slot's **configured** [ShiftHours] into real start/end
/// **instants** and a live phase. Nothing here assumes a fixed weekend close:
/// the end (and whether the shift crosses midnight) comes entirely from the
/// [ShiftHours] the caller resolves via `WeeklyScheduleEntity.hoursFor`.
///
/// Overnight is handled by [ShiftHours.endMinutes] exceeding 1440 (00:30 = 1470,
/// 01:00 = 1500): added as a [Duration] to the slot day's midnight it rolls into
/// the next day, so a night that closes 01:00 stays *active* until 01:00.
class ShiftWindow {
  ShiftWindow._();

  /// The slot's start instant (delegates to the swap-eligibility source of
  /// truth so the two never disagree). Start times are stable in this business.
  static DateTime start(
    DateTime weekStart,
    ScheduleDay day,
    ScheduleShift shift,
  ) => SwapEligibility.slotStart(weekStart, day, shift);

  /// The slot's configured start instant from [hours].
  static DateTime startOf(
    DateTime weekStart,
    ScheduleDay day,
    ShiftHours hours,
  ) {
    final base = DateTime(
      weekStart.year,
      weekStart.month,
      weekStart.day,
    ).add(Duration(days: day.index));
    return base.add(Duration(minutes: hours.startMinutes));
  }

  /// The slot's end instant, from its configured [hours] — past midnight for an
  /// overnight shift.
  static DateTime endOf(DateTime weekStart, ScheduleDay day, ShiftHours hours) {
    final base = DateTime(
      weekStart.year,
      weekStart.month,
      weekStart.day,
    ).add(Duration(days: day.index));
    return base.add(Duration(minutes: hours.endMinutes));
  }

  /// The slot's phase at [now] for its configured [hours] — interval `[start,
  /// end)`.
  static ShiftPhase phaseOf(
    DateTime weekStart,
    ScheduleDay day,
    ScheduleShift shift,
    ShiftHours hours,
    DateTime now,
  ) {
    if (now.isBefore(startOf(weekStart, day, hours))) {
      return ShiftPhase.upcoming;
    }
    if (now.isBefore(endOf(weekStart, day, hours))) return ShiftPhase.active;
    return ShiftPhase.finished;
  }

  /// When [now] falls in the small-hours tail of **yesterday's** overnight night
  /// shift, the end instant of that shift; otherwise null. [yesterdayNightHours]
  /// is yesterday's resolved night [ShiftHours]. Non-null only when that shift
  /// crosses midnight and [now] is before its end — e.g. a Saturday night that
  /// closes 01:00 keeps the employee "on shift" until 01:00 on Sunday.
  ///
  /// The caller still checks that the person actually worked that night
  /// (including the Saturday→Sunday case, whose crew lives in the previous
  /// week's doc — `ScheduleCubit.previousSaturdayNight`).
  static DateTime? nightSpillEnd(DateTime now, ShiftHours yesterdayNightHours) {
    // Cheap gate: an overnight close is at most a few hours after midnight.
    if (now.hour >= 6) return null;
    if (!yesterdayNightHours.crossesMidnight) return null;
    final todayMidnight = DateTime(now.year, now.month, now.day);
    final end = todayMidnight.add(
      Duration(minutes: yesterdayNightHours.endMinutes - 1440),
    );
    return now.isBefore(end) ? end : null;
  }
}
