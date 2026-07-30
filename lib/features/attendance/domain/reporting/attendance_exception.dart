import 'package:drop/features/attendance/domain/attendance_calculator.dart';
import 'package:drop/features/attendance/domain/entities/attendance_entity.dart';

/// Derived reporting exception facts. These are not persisted attendance
/// lifecycle states and must not be added to `AttendanceStatus`.
enum AttendanceExceptionCode {
  late,
  earlyLeave,
  overtime,
  missingPunch,
  implausibleRecord,
  unscheduledWork,
  pendingCorrection;

  String get label => switch (this) {
        AttendanceExceptionCode.late => 'Late',
        AttendanceExceptionCode.earlyLeave => 'Early leave',
        AttendanceExceptionCode.overtime => 'Overtime',
        AttendanceExceptionCode.missingPunch => 'Missing punch',
        AttendanceExceptionCode.implausibleRecord => 'Implausible record',
        AttendanceExceptionCode.unscheduledWork => 'Unscheduled work',
        AttendanceExceptionCode.pendingCorrection => 'Pending correction',
      };

  bool get blocksClose =>
      this == AttendanceExceptionCode.missingPunch ||
      this == AttendanceExceptionCode.implausibleRecord ||
      this == AttendanceExceptionCode.pendingCorrection;
}

/// Classifies derived report exceptions for a row.
///
/// `implausibleRecord` is a review flag, never a punishment and never a status.
/// It catches records whose arithmetic is technically correct but operationally
/// absurd: for example, a 14:14->14:15 session on an 8-hour shift can produce
/// nearly zero worked minutes plus large late and early-leave values. Each
/// number is honest; the row still needs human review before export.
List<AttendanceExceptionCode> classifyExceptions({
  required AttendanceEntity? record,
  required AttendanceTotals totals,
  required DateTime? scheduledStart,
  required DateTime? scheduledEnd,
  bool hasOpenCorrection = false,
  int implausibleWorkedMinutesFloor = 15,
  int implausibleScheduledMinutesFloor = 240,
}) {
  final codes = <AttendanceExceptionCode>[];

  if (totals.lateMinutes > 0) codes.add(AttendanceExceptionCode.late);
  if (totals.earlyLeaveMinutes > 0) {
    codes.add(AttendanceExceptionCode.earlyLeave);
  }
  if (totals.overtimeMinutes > 0) codes.add(AttendanceExceptionCode.overtime);

  if (record != null) {
    if (record.needsReview || _openPastScheduledEnd(record, totals, scheduledEnd)) {
      codes.add(AttendanceExceptionCode.missingPunch);
    }
    if (scheduledStart == null) {
      codes.add(AttendanceExceptionCode.unscheduledWork);
    }
    if (_isImplausibleClockedOutRecord(
      record: record,
      totals: totals,
      scheduledStart: scheduledStart,
      scheduledEnd: scheduledEnd,
      workedFloor: implausibleWorkedMinutesFloor,
      scheduledFloor: implausibleScheduledMinutesFloor,
    )) {
      codes.add(AttendanceExceptionCode.implausibleRecord);
    }
  }

  if (hasOpenCorrection) codes.add(AttendanceExceptionCode.pendingCorrection);

  return List.unmodifiable(codes);
}

bool _openPastScheduledEnd(
  AttendanceEntity record,
  AttendanceTotals totals,
  DateTime? scheduledEnd,
) {
  final clockIn = record.clockIn;
  if (!record.isOpen || clockIn == null || scheduledEnd == null) return false;
  final workStart = record.scheduledStart != null &&
          record.scheduledStart!.isAfter(clockIn)
      ? record.scheduledStart!
      : clockIn;
  final measuredEnd = workStart.add(
    Duration(minutes: totals.workedMinutes + totals.breakMinutes),
  );
  return measuredEnd.isAfter(scheduledEnd);
}

bool _isImplausibleClockedOutRecord({
  required AttendanceEntity record,
  required AttendanceTotals totals,
  required DateTime? scheduledStart,
  required DateTime? scheduledEnd,
  required int workedFloor,
  required int scheduledFloor,
}) {
  if (!record.hasClockedOut || scheduledStart == null || scheduledEnd == null) {
    return false;
  }
  final scheduledMinutes = scheduledEnd.difference(scheduledStart).inMinutes;
  return scheduledMinutes >= scheduledFloor && totals.workedMinutes < workedFloor;
}
