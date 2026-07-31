import 'package:drop/core/enums/leave_type.dart';
import 'package:drop/core/enums/schedule_shift.dart';
import 'package:drop/features/attendance/domain/reporting/attendance_exception.dart';

enum AttendanceLedgerOutcome {
  worked,
  workedLate,
  absent,
  excused,
  onLeave,
  openSession,
  needsReview,
  noRecordYet,
  unknown;

  String get wireValue => switch (this) {
    AttendanceLedgerOutcome.worked => 'worked',
    AttendanceLedgerOutcome.workedLate => 'workedLate',
    AttendanceLedgerOutcome.absent => 'absent',
    AttendanceLedgerOutcome.excused => 'excused',
    AttendanceLedgerOutcome.onLeave => 'onLeave',
    AttendanceLedgerOutcome.openSession => 'openSession',
    AttendanceLedgerOutcome.needsReview => 'needsReview',
    AttendanceLedgerOutcome.noRecordYet => 'noRecordYet',
    AttendanceLedgerOutcome.unknown => 'unknown',
  };

  /// What a manager reads. [wireValue] is the persisted contract and must never
  /// be rendered — a shift outcome column showing `workedLate` / `noRecordYet`
  /// is the data model leaking onto a store surface.
  String get label => switch (this) {
    AttendanceLedgerOutcome.worked => 'Worked',
    AttendanceLedgerOutcome.workedLate => 'Worked, late',
    AttendanceLedgerOutcome.absent => 'Absent',
    AttendanceLedgerOutcome.excused => 'Excused',
    AttendanceLedgerOutcome.onLeave => 'On leave',
    AttendanceLedgerOutcome.openSession => 'Still clocked in',
    AttendanceLedgerOutcome.needsReview => 'Needs review',
    AttendanceLedgerOutcome.noRecordYet => 'No clock-in',
    AttendanceLedgerOutcome.unknown => 'Unknown',
  };

  bool get countsAsPresent =>
      this == AttendanceLedgerOutcome.worked ||
      this == AttendanceLedgerOutcome.workedLate ||
      this == AttendanceLedgerOutcome.openSession ||
      this == AttendanceLedgerOutcome.needsReview;

  bool get countsAsAbsence => this == AttendanceLedgerOutcome.absent;

  bool get isUnresolved =>
      this == AttendanceLedgerOutcome.openSession ||
      this == AttendanceLedgerOutcome.needsReview ||
      this == AttendanceLedgerOutcome.noRecordYet ||
      this == AttendanceLedgerOutcome.unknown;

  static AttendanceLedgerOutcome fromWire(String? raw) => switch (raw) {
    'worked' => AttendanceLedgerOutcome.worked,
    'workedLate' => AttendanceLedgerOutcome.workedLate,
    'absent' => AttendanceLedgerOutcome.absent,
    'excused' => AttendanceLedgerOutcome.excused,
    'onLeave' => AttendanceLedgerOutcome.onLeave,
    'openSession' => AttendanceLedgerOutcome.openSession,
    'needsReview' => AttendanceLedgerOutcome.needsReview,
    'noRecordYet' => AttendanceLedgerOutcome.noRecordYet,
    _ => AttendanceLedgerOutcome.unknown,
  };
}

/// Persisted reporting facts read from `attendance_expectations`.
///
/// [AttendanceLedgerRow] is the server-materialized counterpart to
/// `ExpectedShiftRow`, but the two types are deliberately separate. Expected
/// rows are a client-side parity/reference computation; attendance reporting
/// reads this persisted ledger so numbers are durable, auditable, and identical
/// for every reader.
class AttendanceLedgerRow {
  const AttendanceLedgerRow({
    required this.id,
    required this.rowId,
    required this.userId,
    this.userName,
    required this.branchId,
    required this.dayKey,
    required this.businessDate,
    required this.shift,
    this.scheduledStartAt,
    this.scheduledEndAt,
    required this.outcome,
    required this.expected,
    this.recordId,
    this.leaveType,
    this.workedMinutes = 0,
    this.lateMinutes = 0,
    this.earlyLeaveMinutes = 0,
    this.overtimeMinutes = 0,
    this.breakMinutes = 0,
    this.exceptionCodes = const [],
    this.unknownExceptionCodes = const [],
    this.locked = false,
    this.version = 1,
    this.closedAt,
    this.restatedAt,
    this.source = 'system',
    this.schemaVersion = 1,
  });

  final String id;
  final String rowId;
  final String userId;
  final String? userName;
  final String branchId;
  final String dayKey;
  final String businessDate;
  final ScheduleShift shift;
  final DateTime? scheduledStartAt;
  final DateTime? scheduledEndAt;
  final AttendanceLedgerOutcome outcome;
  final bool expected;
  final String? recordId;
  final LeaveType? leaveType;
  final int workedMinutes;
  final int lateMinutes;
  final int earlyLeaveMinutes;
  final int overtimeMinutes;
  final int breakMinutes;
  final List<AttendanceExceptionCode> exceptionCodes;
  final List<String> unknownExceptionCodes;
  final bool locked;
  final int version;
  final DateTime? closedAt;
  final DateTime? restatedAt;
  final String source;
  final int schemaVersion;

  bool get isPhantom => recordId == null;

  /// True when this row stops its period closing. An **unknown** server-emitted
  /// exception counts as blocking: the client cannot judge a code it does not
  /// know, so it fails safe rather than silently dropping a payroll-relevant
  /// flag. It is deliberately not relabelled as a known code — see
  /// [attendanceExceptionCodeFromWire].
  bool get hasBlockingException =>
      exceptionCodes.any((code) => code.blocksClose) ||
      unknownExceptionCodes.isNotEmpty;

  bool get isUnscheduledWork =>
      exceptionCodes.contains(AttendanceExceptionCode.unscheduledWork);

  @override
  bool operator ==(Object other) =>
      other is AttendanceLedgerRow &&
      other.id == id &&
      other.rowId == rowId &&
      other.userId == userId &&
      other.userName == userName &&
      other.branchId == branchId &&
      other.dayKey == dayKey &&
      other.businessDate == businessDate &&
      other.shift == shift &&
      other.scheduledStartAt == scheduledStartAt &&
      other.scheduledEndAt == scheduledEndAt &&
      other.outcome == outcome &&
      other.expected == expected &&
      other.recordId == recordId &&
      other.leaveType == leaveType &&
      other.workedMinutes == workedMinutes &&
      other.lateMinutes == lateMinutes &&
      other.earlyLeaveMinutes == earlyLeaveMinutes &&
      other.overtimeMinutes == overtimeMinutes &&
      other.breakMinutes == breakMinutes &&
      _listEquals(other.exceptionCodes, exceptionCodes) &&
      _listEquals(other.unknownExceptionCodes, unknownExceptionCodes) &&
      other.locked == locked &&
      other.version == version &&
      other.closedAt == closedAt &&
      other.restatedAt == restatedAt &&
      other.source == source &&
      other.schemaVersion == schemaVersion;

  @override
  int get hashCode => Object.hashAll([
    id,
    rowId,
    userId,
    userName,
    branchId,
    dayKey,
    businessDate,
    shift,
    scheduledStartAt,
    scheduledEndAt,
    outcome,
    expected,
    recordId,
    leaveType,
    workedMinutes,
    lateMinutes,
    earlyLeaveMinutes,
    overtimeMinutes,
    breakMinutes,
    Object.hashAll(exceptionCodes),
    Object.hashAll(unknownExceptionCodes),
    locked,
    version,
    closedAt,
    restatedAt,
    source,
    schemaVersion,
  ]);

  @override
  String toString() =>
      'AttendanceLedgerRow(id: $id, userId: $userId, dayKey: $dayKey, '
      'shift: $shift, outcome: $outcome, expected: $expected, '
      'exceptions: $exceptionCodes)';
}

class LedgerCoverage {
  const LedgerCoverage({
    required this.hasRows,
    required this.closedRowCount,
    required this.blockingExceptionRowCount,
  });

  factory LedgerCoverage.fromRows(List<AttendanceLedgerRow> rows) =>
      LedgerCoverage(
        hasRows: rows.isNotEmpty,
        closedRowCount: rows.where((row) => row.closedAt != null).length,
        blockingExceptionRowCount: rows
            .where((row) => row.hasBlockingException)
            .length,
      );

  final bool hasRows;
  final int closedRowCount;
  final int blockingExceptionRowCount;

  bool get awaitingClose => !hasRows;

  static const empty = LedgerCoverage(
    hasRows: false,
    closedRowCount: 0,
    blockingExceptionRowCount: 0,
  );

  @override
  bool operator ==(Object other) =>
      other is LedgerCoverage &&
      other.hasRows == hasRows &&
      other.closedRowCount == closedRowCount &&
      other.blockingExceptionRowCount == blockingExceptionRowCount;

  @override
  int get hashCode =>
      Object.hash(hasRows, closedRowCount, blockingExceptionRowCount);

  @override
  String toString() =>
      'LedgerCoverage(hasRows: $hasRows, closedRows: $closedRowCount, '
      'blockingRows: $blockingExceptionRowCount)';
}

/// Parses a ledger exception wire value. Returns `null` for a code this client
/// does not know — see the fallback comment below.
AttendanceExceptionCode? attendanceExceptionCodeFromWire(String? raw) =>
    switch (raw) {
      'late' => AttendanceExceptionCode.late,
      'earlyLeave' => AttendanceExceptionCode.earlyLeave,
      'overtime' => AttendanceExceptionCode.overtime,
      'missingPunch' => AttendanceExceptionCode.missingPunch,
      'implausibleRecord' => AttendanceExceptionCode.implausibleRecord,
      'unscheduledWork' => AttendanceExceptionCode.unscheduledWork,
      'pendingCorrection' => AttendanceExceptionCode.pendingCorrection,
      // Unknown wire code → null, NOT a coerced known code. An unknown code must
      // never be relabelled as a specific business fact: rendering a future
      // server code as "Implausible record" would tell a manager something
      // concrete and false about that person's record. The fail-safe is
      // preserved instead by [AttendanceLedgerRow.hasBlockingException], which
      // treats any retained `unknownExceptionCodes` as close-blocking — so an
      // unrecognized exception still stops a period closing, it just doesn't
      // lie about what it is.
      _ => null,
    };

String attendanceExceptionCodeWireValue(AttendanceExceptionCode code) =>
    switch (code) {
      AttendanceExceptionCode.late => 'late',
      AttendanceExceptionCode.earlyLeave => 'earlyLeave',
      AttendanceExceptionCode.overtime => 'overtime',
      AttendanceExceptionCode.missingPunch => 'missingPunch',
      AttendanceExceptionCode.implausibleRecord => 'implausibleRecord',
      AttendanceExceptionCode.unscheduledWork => 'unscheduledWork',
      AttendanceExceptionCode.pendingCorrection => 'pendingCorrection',
    };

bool isKnownAttendanceExceptionCodeWire(String? raw) =>
    raw == 'late' ||
    raw == 'earlyLeave' ||
    raw == 'overtime' ||
    raw == 'missingPunch' ||
    raw == 'implausibleRecord' ||
    raw == 'unscheduledWork' ||
    raw == 'pendingCorrection';

bool _listEquals<T>(List<T> a, List<T> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
