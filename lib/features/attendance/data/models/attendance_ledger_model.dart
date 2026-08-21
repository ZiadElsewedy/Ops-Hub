import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:opshub/core/enums/leave_type.dart';
import 'package:opshub/core/enums/schedule_shift.dart';
import 'package:opshub/core/extensions/firestore_extensions.dart';
import 'package:opshub/features/attendance/domain/reporting/attendance_exception.dart';
import 'package:opshub/features/attendance/domain/reporting/attendance_ledger_row.dart';

class AttendanceLedgerModel {
  const AttendanceLedgerModel({
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

  factory AttendanceLedgerModel.fromMap(
    Map<String, dynamic> map, {
    String? id,
  }) {
    final rawCodes = _stringList(map['exceptionCodes']);
    final unknownCodes = [
      for (final code in rawCodes)
        if (!isKnownAttendanceExceptionCodeWire(code)) code,
    ];

    return AttendanceLedgerModel(
      id: id ?? _string(map['id']) ?? _string(map['rowId']) ?? '',
      rowId: _string(map['rowId']) ?? id ?? '',
      userId: _string(map['userId']) ?? '',
      userName: _string(map['userName']),
      branchId: _string(map['branchId']) ?? '',
      dayKey: _string(map['dayKey']) ?? '',
      businessDate: _string(map['businessDate']) ?? '',
      shift: ScheduleShift.fromString(_string(map['shift'])),
      scheduledStartAt: map.date('scheduledStartAt'),
      scheduledEndAt: map.date('scheduledEndAt'),
      outcome: AttendanceLedgerOutcome.fromWire(_string(map['outcome'])),
      expected: map['expected'] == true,
      recordId: _string(map['recordId']),
      leaveType: LeaveType.fromStringOrNull(_string(map['leaveType'])),
      workedMinutes: _int(map['workedMinutes']),
      lateMinutes: _int(map['lateMinutes']),
      earlyLeaveMinutes: _int(map['earlyLeaveMinutes']),
      overtimeMinutes: _int(map['overtimeMinutes']),
      breakMinutes: _int(map['breakMinutes']),
      exceptionCodes: List.unmodifiable(
        rawCodes
            .map(attendanceExceptionCodeFromWire)
            .whereType<AttendanceExceptionCode>(),
      ),
      unknownExceptionCodes: List.unmodifiable(unknownCodes),
      locked: map['locked'] == true,
      version: _int(map['version'], fallback: 1),
      closedAt: map.date('closedAt'),
      restatedAt: map.date('restatedAt'),
      source: _string(map['source']) ?? 'system',
      schemaVersion: _int(map['schemaVersion'], fallback: 1),
    );
  }

  AttendanceLedgerRow toEntity() => AttendanceLedgerRow(
    id: id,
    rowId: rowId,
    userId: userId,
    userName: userName,
    branchId: branchId,
    dayKey: dayKey,
    businessDate: businessDate,
    shift: shift,
    scheduledStartAt: scheduledStartAt,
    scheduledEndAt: scheduledEndAt,
    outcome: outcome,
    expected: expected,
    recordId: recordId,
    leaveType: leaveType,
    workedMinutes: workedMinutes,
    lateMinutes: lateMinutes,
    earlyLeaveMinutes: earlyLeaveMinutes,
    overtimeMinutes: overtimeMinutes,
    breakMinutes: breakMinutes,
    exceptionCodes: exceptionCodes,
    unknownExceptionCodes: unknownExceptionCodes,
    locked: locked,
    version: version,
    closedAt: closedAt,
    restatedAt: restatedAt,
    source: source,
    schemaVersion: schemaVersion,
  );

  Map<String, dynamic> toMap() => {
    'rowId': rowId,
    'userId': userId,
    'userName': userName,
    'branchId': branchId,
    'dayKey': dayKey,
    'businessDate': businessDate,
    'shift': shift.value,
    'scheduledStartAt': _ts(scheduledStartAt),
    'scheduledEndAt': _ts(scheduledEndAt),
    'outcome': outcome.wireValue,
    'expected': expected,
    'recordId': recordId,
    'leaveType': leaveType?.value,
    'workedMinutes': workedMinutes,
    'lateMinutes': lateMinutes,
    'earlyLeaveMinutes': earlyLeaveMinutes,
    'overtimeMinutes': overtimeMinutes,
    'breakMinutes': breakMinutes,
    'exceptionCodes': exceptionCodes
        .map(attendanceExceptionCodeWireValue)
        .toList(),
    'locked': locked,
    'version': version,
    'closedAt': _ts(closedAt),
    'restatedAt': _ts(restatedAt),
    'source': source,
    'schemaVersion': schemaVersion,
  };

  static int _int(dynamic value, {int fallback = 0}) =>
      value is num ? value.toInt() : fallback;

  static String? _string(dynamic value) => value is String ? value : null;

  static List<String> _stringList(dynamic raw) {
    if (raw is! List) return const [];
    return [
      for (final item in raw)
        if (item != null) item.toString(),
    ];
  }

  static Timestamp? _ts(DateTime? date) =>
      date == null ? null : Timestamp.fromDate(date);
}
