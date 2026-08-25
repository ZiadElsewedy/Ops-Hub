import 'package:opshub/features/attendance/domain/attendance_break.dart';
import 'package:opshub/features/attendance/domain/attendance_config.dart';
import 'package:opshub/features/attendance/domain/entities/attendance_entity.dart';

/// The five worked-time totals for a shift, in whole minutes.
class AttendanceTotals {
  final int workedMinutes;
  final int lateMinutes;
  final int earlyLeaveMinutes;
  final int overtimeMinutes;
  final int breakMinutes;

  const AttendanceTotals({
    this.workedMinutes = 0,
    this.lateMinutes = 0,
    this.earlyLeaveMinutes = 0,
    this.overtimeMinutes = 0,
    this.breakMinutes = 0,
  });

  static const AttendanceTotals zero = AttendanceTotals();

  @override
  bool operator ==(Object other) =>
      other is AttendanceTotals &&
      other.workedMinutes == workedMinutes &&
      other.lateMinutes == lateMinutes &&
      other.earlyLeaveMinutes == earlyLeaveMinutes &&
      other.overtimeMinutes == overtimeMinutes &&
      other.breakMinutes == breakMinutes;

  @override
  int get hashCode => Object.hash(workedMinutes, lateMinutes, earlyLeaveMinutes,
      overtimeMinutes, breakMinutes);

  @override
  String toString() =>
      'AttendanceTotals(worked: $workedMinutes, late: $lateMinutes, '
      'early: $earlyLeaveMinutes, ot: $overtimeMinutes, break: $breakMinutes)';
}

/// The single source of truth for worked / late / early-leave / overtime / break
/// minutes. Pure + framework-free, so both the **live timer** (recomputing
/// against `now`) and the **persisted snapshot** (written at clock-out with
/// `now == clockOut`) go through exactly the same math and can never disagree.
///
/// Everything is instant subtraction, so an overnight shift that crosses midnight
/// is handled automatically (no special-casing).
class AttendanceCalculator {
  AttendanceCalculator._();

  /// Compute the totals from raw fields.
  ///
  /// * [now] is the moment to measure an *in-progress* session against; once
  ///   [clockOut] is set it wins, so passing `now == clockOut` yields the final
  ///   snapshot.
  /// * Lateness / early-leave / overtime are measured against the scheduled
  ///   instants and **suppressed under the grace windows** in [config] (a couple
  ///   of trivial minutes don't count). Early-leave and overtime are only known
  ///   once clocked out; while a session is open they stay 0 (honest, not
  ///   projected).
  static AttendanceTotals compute({
    required DateTime? scheduledStart,
    required DateTime? scheduledEnd,
    required DateTime? clockIn,
    required DateTime? clockOut,
    required List<AttendanceBreak> breaks,
    required DateTime now,
    AttendanceConfig config = AttendanceConfig.defaults,
  }) {
    if (clockIn == null) return AttendanceTotals.zero;

    // The session either ends at clockOut, or is measured live to now.
    final end = clockOut ?? now;
    // Worked time is measured from `max(clockIn, scheduledStart)` — clocking in
    // early never inflates the total (spec R2). Lateness (below) still measures
    // the real clock-in, so an early arrival is simply neither early-worked nor
    // late.
    final workStart =
        (scheduledStart != null && scheduledStart.isAfter(clockIn))
            ? scheduledStart
            : clockIn;
    final gross = _nonNeg(end.difference(workStart).inMinutes);
    final breakMinutes = totalBreakMinutes(breaks, end);
    final worked = _nonNeg(gross - breakMinutes);

    // Lateness — clocking in after the scheduled start, beyond the grace window.
    var late = 0;
    if (scheduledStart != null) {
      final rawLate = clockIn.difference(scheduledStart).inMinutes;
      if (rawLate > config.lateGraceMinutes) late = rawLate;
    }

    // Early leave / overtime need a clock-out to be real.
    var earlyLeave = 0;
    var overtime = 0;
    if (clockOut != null && scheduledEnd != null) {
      final beforeEnd = scheduledEnd.difference(clockOut).inMinutes; // >0 = early
      if (beforeEnd > config.earlyLeaveGraceMinutes) earlyLeave = beforeEnd;

      final afterEnd = clockOut.difference(scheduledEnd).inMinutes; // >0 = over
      if (afterEnd > config.overtimeGraceMinutes) overtime = afterEnd;
    }

    return AttendanceTotals(
      workedMinutes: worked,
      lateMinutes: _nonNeg(late),
      earlyLeaveMinutes: _nonNeg(earlyLeave),
      overtimeMinutes: _nonNeg(overtime),
      breakMinutes: breakMinutes,
    );
  }

  /// Totals for [a] measured at [now] (a live, in-progress session reads the
  /// timer; a clocked-out record reads its own clock-out).
  static AttendanceTotals forEntity(
    AttendanceEntity a,
    DateTime now, {
    AttendanceConfig config = AttendanceConfig.defaults,
  }) =>
      compute(
        scheduledStart: a.scheduledStart,
        scheduledEnd: a.scheduledEnd,
        clockIn: a.clockIn,
        clockOut: a.clockOut,
        breaks: a.breaks,
        now: now,
        config: config,
      );

  /// The live worked minutes for [a] at [now] — the number the session timer
  /// shows.
  static int liveWorkedMinutes(
    AttendanceEntity a,
    DateTime now, {
    AttendanceConfig config = AttendanceConfig.defaults,
  }) =>
      forEntity(a, now, config: config).workedMinutes;

  static int _nonNeg(int v) => v < 0 ? 0 : v;
}
