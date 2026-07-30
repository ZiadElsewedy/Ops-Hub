import 'package:drop/features/attendance/domain/reporting/attendance_exception.dart';
import 'package:drop/features/attendance/domain/reporting/attendance_expectation.dart';

/// A rate with its denominator exposed so the UI can disclose exactly what was
/// counted.
class AttendanceRate {
  const AttendanceRate({
    required this.numerator,
    required this.denominator,
    required this.denominatorLabel,
  });

  final int numerator;
  final int denominator;
  final String denominatorLabel;

  double? get percent =>
      denominator == 0 ? null : (numerator / denominator) * 100;

  String describe() {
    final pct = percent;
    final pctLabel = pct == null ? '--' : '${pct.round()}%';
    return '$pctLabel · $numerator / $denominator $denominatorLabel';
  }

  @override
  bool operator ==(Object other) =>
      other is AttendanceRate &&
      other.numerator == numerator &&
      other.denominator == denominator &&
      other.denominatorLabel == denominatorLabel;

  @override
  int get hashCode => Object.hash(numerator, denominator, denominatorLabel);

  @override
  String toString() =>
      'AttendanceRate(numerator: $numerator, denominator: $denominator, '
      'label: $denominatorLabel)';
}

/// Folded attendance-report metrics with explicit denominators. Leave and
/// excused rows are excluded from every denominator: excluded means excluded,
/// not failure. A late arrival still counts as present for [showUpRate], which
/// is exactly why [punctualArrivalRate] exists as a separate figure and why the
/// old single "Rate" was misleading.
class AttendanceReportSummary {
  const AttendanceReportSummary({
    this.expectedWorkShifts = 0,
    this.present = 0,
    this.absent = 0,
    this.excused = 0,
    this.onLeave = 0,
    this.lateArrivals = 0,
    this.earlyLeaves = 0,
    this.overtimeShifts = 0,
    this.missingPunches = 0,
    this.implausibleRecords = 0,
    this.unscheduledWork = 0,
    this.unresolved = 0,
    this.workedMinutes = 0,
    this.lateMinutes = 0,
    this.earlyLeaveMinutes = 0,
    this.overtimeMinutes = 0,
  });

  final int expectedWorkShifts;
  final int present;
  final int absent;
  final int excused;
  final int onLeave;
  final int lateArrivals;
  final int earlyLeaves;
  final int overtimeShifts;
  final int missingPunches;
  final int implausibleRecords;
  final int unscheduledWork;
  final int unresolved;
  final int workedMinutes;
  final int lateMinutes;
  final int earlyLeaveMinutes;
  final int overtimeMinutes;

  /// Present shifts divided by expected work shifts. It drives ADR-017's
  /// staffing-reliability metric and uses expected work shifts as denominator.
  AttendanceRate get showUpRate => AttendanceRate(
        numerator: present,
        denominator: expectedWorkShifts,
        denominatorLabel: 'expected work shifts',
      );

  /// Unexcused absences divided by expected work shifts. It drives ADR-017's
  /// coverage-intervention metric and uses expected work shifts as denominator.
  AttendanceRate get unexcusedAbsenceRate => AttendanceRate(
        numerator: absent,
        denominator: expectedWorkShifts,
        denominatorLabel: 'expected work shifts',
      );

  /// On-time present arrivals divided by present scheduled arrivals. It drives
  /// ADR-017's shift-handoff coaching metric and uses present as denominator.
  AttendanceRate get punctualArrivalRate => AttendanceRate(
        numerator: present - lateArrivals,
        denominator: present,
        denominatorLabel: 'present scheduled arrivals',
      );

  factory AttendanceReportSummary.fromRows(List<ExpectedShiftRow> rows) {
    var expected = 0;
    var present = 0;
    var absent = 0;
    var excused = 0;
    var onLeave = 0;
    var late = 0;
    var early = 0;
    var overtime = 0;
    var missing = 0;
    var implausible = 0;
    var unscheduled = 0;
    var unresolved = 0;
    var workedMinutes = 0;
    var lateMinutes = 0;
    var earlyMinutes = 0;
    var overtimeMinutes = 0;

    for (final row in rows) {
      final isUnscheduled = row.exceptions.contains(
        AttendanceExceptionCode.unscheduledWork,
      );
      if (isUnscheduled) unscheduled++;
      if (row.exceptions.contains(AttendanceExceptionCode.missingPunch)) missing++;
      if (row.exceptions.contains(AttendanceExceptionCode.implausibleRecord)) {
        implausible++;
      }

      if (isUnscheduled) continue;

      if (row.outcome.countsAsExpectedWork) expected++;
      if (row.outcome.countsAsPresent) present++;
      if (row.outcome.countsAsAbsence) absent++;
      if (row.outcome == ExpectedShiftOutcome.excused) excused++;
      if (row.outcome == ExpectedShiftOutcome.onLeave) onLeave++;
      if (row.outcome.isUnresolved) unresolved++;
      if (row.exceptions.contains(AttendanceExceptionCode.late)) late++;
      if (row.exceptions.contains(AttendanceExceptionCode.earlyLeave)) early++;
      if (row.exceptions.contains(AttendanceExceptionCode.overtime)) overtime++;

      workedMinutes += row.totals.workedMinutes;
      lateMinutes += row.totals.lateMinutes;
      earlyMinutes += row.totals.earlyLeaveMinutes;
      overtimeMinutes += row.totals.overtimeMinutes;
    }

    return AttendanceReportSummary(
      expectedWorkShifts: expected,
      present: present,
      absent: absent,
      excused: excused,
      onLeave: onLeave,
      lateArrivals: late,
      earlyLeaves: early,
      overtimeShifts: overtime,
      missingPunches: missing,
      implausibleRecords: implausible,
      unscheduledWork: unscheduled,
      unresolved: unresolved,
      workedMinutes: workedMinutes,
      lateMinutes: lateMinutes,
      earlyLeaveMinutes: earlyMinutes,
      overtimeMinutes: overtimeMinutes,
    );
  }

  static const AttendanceReportSummary empty = AttendanceReportSummary();

  @override
  bool operator ==(Object other) =>
      other is AttendanceReportSummary &&
      other.expectedWorkShifts == expectedWorkShifts &&
      other.present == present &&
      other.absent == absent &&
      other.excused == excused &&
      other.onLeave == onLeave &&
      other.lateArrivals == lateArrivals &&
      other.earlyLeaves == earlyLeaves &&
      other.overtimeShifts == overtimeShifts &&
      other.missingPunches == missingPunches &&
      other.implausibleRecords == implausibleRecords &&
      other.unscheduledWork == unscheduledWork &&
      other.unresolved == unresolved &&
      other.workedMinutes == workedMinutes &&
      other.lateMinutes == lateMinutes &&
      other.earlyLeaveMinutes == earlyLeaveMinutes &&
      other.overtimeMinutes == overtimeMinutes;

  @override
  int get hashCode => Object.hash(
        expectedWorkShifts,
        present,
        absent,
        excused,
        onLeave,
        lateArrivals,
        earlyLeaves,
        overtimeShifts,
        missingPunches,
        implausibleRecords,
        unscheduledWork,
        unresolved,
        workedMinutes,
        lateMinutes,
        earlyLeaveMinutes,
        overtimeMinutes,
      );

  @override
  String toString() =>
      'AttendanceReportSummary(expected: $expectedWorkShifts, '
      'present: $present, absent: $absent, excused: $excused, '
      'onLeave: $onLeave, late: $lateArrivals, unresolved: $unresolved)';
}
