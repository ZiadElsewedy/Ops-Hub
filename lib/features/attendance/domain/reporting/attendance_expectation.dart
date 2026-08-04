import 'package:drop/core/enums/attendance_status.dart';
import 'package:drop/core/enums/leave_type.dart';
import 'package:drop/core/enums/schedule_day.dart';
import 'package:drop/core/enums/schedule_shift.dart';
import 'package:drop/features/attendance/domain/attendance_calculator.dart';
import 'package:drop/features/attendance/domain/attendance_config.dart';
import 'package:drop/features/attendance/domain/attendance_id.dart';
import 'package:drop/features/attendance/domain/entities/attendance_entity.dart';
import 'package:drop/features/attendance/domain/reporting/attendance_exception.dart';
import 'package:drop/features/schedule/domain/entities/weekly_schedule_entity.dart';
import 'package:drop/features/schedule/domain/schedule_week.dart';
import 'package:drop/features/schedule/domain/shift_window.dart';

/// Derived reporting classification for one roster expectation. These are
/// reporting facts, not persisted attendance statuses.
enum ExpectedShiftOutcome {
  worked,
  workedLate,
  absent,
  excused,
  onLeave,
  openSession,
  needsReview,
  noRecordYet;

  bool get countsAsExpectedWork =>
      this != ExpectedShiftOutcome.onLeave &&
      this != ExpectedShiftOutcome.excused;

  bool get countsAsPresent =>
      this == ExpectedShiftOutcome.worked ||
      this == ExpectedShiftOutcome.workedLate ||
      this == ExpectedShiftOutcome.openSession ||
      this == ExpectedShiftOutcome.needsReview;

  bool get countsAsAbsence => this == ExpectedShiftOutcome.absent;

  bool get isUnresolved =>
      this == ExpectedShiftOutcome.openSession ||
      this == ExpectedShiftOutcome.needsReview ||
      this == ExpectedShiftOutcome.noRecordYet;
}

/// Client-side parity model for the server close pipeline.
///
/// [ExpectedShiftRow] is computed from roster × raw attendance records so tests
/// can keep the Flutter rules aligned with `closeAttendanceExpectations`. It is
/// not a reporting read model. Attendance reports read the persisted
/// `attendance_expectations` ledger instead, so numbers are durable, auditable,
/// and identical for every reader.
class ExpectedShiftRow {
  const ExpectedShiftRow({
    required this.uid,
    required this.branchId,
    required this.date,
    required this.shift,
    required this.scheduledStart,
    required this.scheduledEnd,
    required this.outcome,
    required this.recordId,
    required this.leaveType,
    required this.totals,
    this.exceptions = const [],
  });

  final String uid;
  final String branchId;
  final DateTime date;
  final ScheduleShift shift;
  final DateTime? scheduledStart;
  final DateTime? scheduledEnd;
  final ExpectedShiftOutcome outcome;

  /// Null when no attendance document exists. This is the rostered no-show case
  /// the old materialized-record denominator dropped.
  final String? recordId;

  final LeaveType? leaveType;
  final AttendanceTotals totals;
  final List<AttendanceExceptionCode> exceptions;

  /// A phantom row is the durable reporting fact for a rostered slot with no raw
  /// attendance document.
  bool get isPhantom => recordId == null;

  @override
  bool operator ==(Object other) =>
      other is ExpectedShiftRow &&
      other.uid == uid &&
      other.branchId == branchId &&
      other.date == date &&
      other.shift == shift &&
      other.scheduledStart == scheduledStart &&
      other.scheduledEnd == scheduledEnd &&
      other.outcome == outcome &&
      other.recordId == recordId &&
      other.leaveType == leaveType &&
      other.totals == totals &&
      _listEquals(other.exceptions, exceptions);

  @override
  int get hashCode => Object.hash(
    uid,
    branchId,
    date,
    shift,
    scheduledStart,
    scheduledEnd,
    outcome,
    recordId,
    leaveType,
    totals,
    Object.hashAll(exceptions),
  );

  @override
  String toString() =>
      'ExpectedShiftRow(uid: $uid, date: $date, shift: $shift, '
      'outcome: $outcome, recordId: $recordId, totals: $totals, '
      'exceptions: $exceptions)';
}

/// Builds the roster-derived denominator rows for a schedule week.
List<ExpectedShiftRow> buildExpectedShiftRows({
  required WeeklyScheduleEntity schedule,
  required List<AttendanceEntity> records,
  required DateTime now,
  AttendanceConfig config = AttendanceConfig.defaults,
}) {
  final recordsById = {
    for (final record in records)
      if (!record.isDeleted) record.id: record,
  };
  final rows = <ExpectedShiftRow>[];

  for (final day in ScheduleDay.values) {
    final date = DateTime(
      schedule.weekStart.year,
      schedule.weekStart.month,
      schedule.weekStart.day,
    ).add(Duration(days: day.index));
    final leave = schedule.leaveOn(day);

    for (final shift in ScheduleShift.values) {
      final hours = schedule.hoursFor(day, shift);
      final scheduledStart = ShiftWindow.startOf(
        schedule.weekStart,
        day,
        hours,
      );
      final scheduledEnd = ShiftWindow.endOf(schedule.weekStart, day, hours);
      final employees = schedule.employeesFor(day, shift).toSet().toList()
        ..sort();

      for (final uid in employees) {
        final recordId = attendanceDocId(uid: uid, date: date, shift: shift);
        final record = recordsById[recordId];
        final leaveType = leave[uid];
        final totals = record == null
            ? AttendanceTotals.zero
            : AttendanceCalculator.forEntity(record, now, config: config);
        final outcome = _classifyExpectedOutcome(
          record: record,
          leaveType: leaveType,
          scheduledEnd: scheduledEnd,
          now: now,
          config: config,
          totals: totals,
        );
        final exceptions = classifyExceptions(
          record: record,
          totals: totals,
          scheduledStart: scheduledStart,
          scheduledEnd: scheduledEnd,
        );

        rows.add(
          ExpectedShiftRow(
            uid: uid,
            branchId: schedule.branchId,
            date: date,
            shift: shift,
            scheduledStart: scheduledStart,
            scheduledEnd: scheduledEnd,
            outcome: outcome,
            recordId: record?.id,
            leaveType: leaveType,
            totals: totals,
            exceptions: exceptions,
          ),
        );
      }
    }
  }

  rows.sort(_compareRows);
  return List.unmodifiable(rows);
}

/// Rows for real attendance records with no matching roster slot. These explain
/// real work that no roster expected, and must not inflate expected-work
/// denominators.
List<ExpectedShiftRow> unscheduledWorkRows({
  required List<AttendanceEntity> records,
  required WeeklyScheduleEntity schedule,
  required DateTime now,
  AttendanceConfig config = AttendanceConfig.defaults,
}) {
  final rows = <ExpectedShiftRow>[];
  final scheduleWeekStart = ScheduleWeek.startOf(schedule.weekStart);

  for (final record in records) {
    if (record.isDeleted) continue;
    final recordWeekStart = ScheduleWeek.startOf(record.date);
    final day = ScheduleDay.fromDate(record.date);
    final hasRosterSlot =
        recordWeekStart == scheduleWeekStart &&
        schedule.isAssigned(record.userId, day, record.shift);
    if (!record.isUnscheduled && hasRosterSlot) continue;

    final totals = AttendanceCalculator.forEntity(record, now, config: config);
    final baseExceptions = classifyExceptions(
      record: record,
      totals: totals,
      scheduledStart: record.scheduledStart,
      scheduledEnd: record.scheduledEnd,
    );
    // The row still exists — presence work must be visible — but it is only
    // *flagged* as unscheduled when nobody rostered a shift that was expected.
    // A presence-only role has no roster to deviate from.
    final exceptions = <AttendanceExceptionCode>{
      ...baseExceptions,
      if (!record.presenceOnly) AttendanceExceptionCode.unscheduledWork,
    }.toList()..sort((a, b) => a.index.compareTo(b.index));

    rows.add(
      ExpectedShiftRow(
        uid: record.userId,
        branchId: record.branchId ?? schedule.branchId,
        date: record.date,
        shift: record.shift,
        scheduledStart: record.scheduledStart,
        scheduledEnd: record.scheduledEnd,
        outcome: _classifyRecordOutcome(record, totals),
        recordId: record.id,
        leaveType: null,
        totals: totals,
        exceptions: exceptions,
      ),
    );
  }

  rows.sort(_compareRows);
  return List.unmodifiable(rows);
}

ExpectedShiftOutcome _classifyExpectedOutcome({
  required AttendanceEntity? record,
  required LeaveType? leaveType,
  required DateTime scheduledEnd,
  required DateTime now,
  required AttendanceConfig config,
  required AttendanceTotals totals,
}) {
  if (leaveType != null) return ExpectedShiftOutcome.onLeave;
  if (record?.status == AttendanceStatus.excused) {
    return ExpectedShiftOutcome.excused;
  }
  if (record == null) {
    final closeAfterGrace = scheduledEnd.add(
      Duration(minutes: config.autoCloseGraceMinutes),
    );
    return now.isBefore(closeAfterGrace)
        ? ExpectedShiftOutcome.noRecordYet
        : ExpectedShiftOutcome.absent;
  }
  if (record.status.isAbsence) return ExpectedShiftOutcome.absent;
  if (record.status == AttendanceStatus.onLeave) {
    return ExpectedShiftOutcome.onLeave;
  }
  return _classifyRecordOutcome(record, totals);
}

ExpectedShiftOutcome _classifyRecordOutcome(
  AttendanceEntity record,
  AttendanceTotals totals,
) {
  if (record.isOpen) return ExpectedShiftOutcome.openSession;
  if (record.needsReview) return ExpectedShiftOutcome.needsReview;
  return totals.lateMinutes > 0
      ? ExpectedShiftOutcome.workedLate
      : ExpectedShiftOutcome.worked;
}

int _compareRows(ExpectedShiftRow a, ExpectedShiftRow b) {
  final date = a.date.compareTo(b.date);
  if (date != 0) return date;
  final shift = a.shift.index.compareTo(b.shift.index);
  if (shift != 0) return shift;
  return a.uid.compareTo(b.uid);
}

bool _listEquals<T>(List<T> a, List<T> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) {
      return false;
    }
  }
  return true;
}
