import 'package:opshub/core/enums/attendance_status.dart';
import 'package:opshub/features/attendance/domain/attendance_break.dart';
import 'package:opshub/features/attendance/domain/attendance_config.dart';
import 'package:opshub/features/attendance/domain/attendance_calculator.dart';

/// The concrete result an **approved** correction applies to its parent record:
/// the settled clock-in / clock-out, the resulting [status], and the recomputed
/// minute snapshot. Pure + framework-free (serialized by `AttendanceCorrectionModel`).
///
/// It is computed once, on approval, by `DecideCorrection` through
/// [AttendanceCalculator] — the single source of the minute math — and stored on
/// the correction doc. The `onAttendanceCorrectionWritten` Cloud Function then
/// copies it verbatim onto `attendance/{id}` (server-authoritative apply), so the
/// client never recomputes totals and the numbers can't drift from the clock-out
/// path.
class AttendanceResolution {
  final DateTime? clockIn;
  final DateTime? clockOut;
  final AttendanceStatus status;
  final int workedMinutes;
  final int lateMinutes;
  final int earlyLeaveMinutes;
  final int overtimeMinutes;
  final int breakMinutes;

  const AttendanceResolution({
    this.clockIn,
    this.clockOut,
    this.status = AttendanceStatus.completed,
    this.workedMinutes = 0,
    this.lateMinutes = 0,
    this.earlyLeaveMinutes = 0,
    this.overtimeMinutes = 0,
    this.breakMinutes = 0,
  });

  /// Builds a resolution from settled [clockIn]/[clockOut] and the [totals] the
  /// [AttendanceCalculator] produced for them.
  factory AttendanceResolution.fromTotals({
    DateTime? clockIn,
    DateTime? clockOut,
    AttendanceStatus status = AttendanceStatus.completed,
    required AttendanceTotals totals,
  }) =>
      AttendanceResolution(
        clockIn: clockIn,
        clockOut: clockOut,
        status: status,
        workedMinutes: totals.workedMinutes,
        lateMinutes: totals.lateMinutes,
        earlyLeaveMinutes: totals.earlyLeaveMinutes,
        overtimeMinutes: totals.overtimeMinutes,
        breakMinutes: totals.breakMinutes,
      );

  /// Builds a resolution by running the settled clock times through
  /// [AttendanceCalculator] — **the single source of the minute math**. Both the
  /// reviewer's approve path (`DecideCorrection`) and a manager's direct action
  /// (add-record / resolve) go through here, so a corrected record's totals can
  /// never drift from the clock-out path. [now] only matters when [clockOut] is
  /// null (an open settlement) — a missed-punch supplies a real clock-out, so it
  /// yields a final snapshot.
  factory AttendanceResolution.fromRecord({
    DateTime? scheduledStart,
    DateTime? scheduledEnd,
    DateTime? clockIn,
    DateTime? clockOut,
    AttendanceStatus status = AttendanceStatus.completed,
    List<AttendanceBreak> breaks = const [],
    required DateTime now,
    AttendanceConfig config = AttendanceConfig.defaults,
  }) =>
      AttendanceResolution.fromTotals(
        clockIn: clockIn,
        clockOut: clockOut,
        status: status,
        totals: AttendanceCalculator.compute(
          scheduledStart: scheduledStart,
          scheduledEnd: scheduledEnd,
          clockIn: clockIn,
          clockOut: clockOut,
          breaks: breaks,
          now: clockOut ?? now,
          config: config,
        ),
      );

  AttendanceTotals get totals => AttendanceTotals(
        workedMinutes: workedMinutes,
        lateMinutes: lateMinutes,
        earlyLeaveMinutes: earlyLeaveMinutes,
        overtimeMinutes: overtimeMinutes,
        breakMinutes: breakMinutes,
      );

  @override
  bool operator ==(Object other) =>
      other is AttendanceResolution &&
      other.clockIn == clockIn &&
      other.clockOut == clockOut &&
      other.status == status &&
      other.workedMinutes == workedMinutes &&
      other.lateMinutes == lateMinutes &&
      other.earlyLeaveMinutes == earlyLeaveMinutes &&
      other.overtimeMinutes == overtimeMinutes &&
      other.breakMinutes == breakMinutes;

  @override
  int get hashCode => Object.hash(clockIn, clockOut, status, workedMinutes,
      lateMinutes, earlyLeaveMinutes, overtimeMinutes, breakMinutes);
}
