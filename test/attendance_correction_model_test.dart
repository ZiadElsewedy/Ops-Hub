import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opshub/core/enums/attendance_correction_kind.dart';
import 'package:opshub/core/enums/attendance_status.dart';
import 'package:opshub/core/enums/request_status.dart';
import 'package:opshub/core/enums/schedule_shift.dart';
import 'package:opshub/features/attendance/data/models/attendance_correction_model.dart';
import 'package:opshub/features/attendance/domain/attendance_resolution.dart';
import 'package:opshub/features/attendance/domain/entities/attendance_correction.dart';

void main() {
  test('toCreateMap is a pending filing payload without decision fields', () {
    final e = AttendanceCorrectionEntity(
      id: 'c1',
      attendanceId: 'u1_20260713_morning',
      userId: 'u1',
      userName: 'Ziad',
      branchId: 'b1',
      shift: ScheduleShift.morning,
      date: DateTime(2026, 7, 13),
      requestedBy: 'u1',
      requestedByName: 'Ziad',
      kind: AttendanceCorrectionKind.missingClockOut,
      reason: 'Forgot to clock out',
      proposedClockOut: DateTime(2026, 7, 13, 16, 30),
    );
    final map = AttendanceCorrectionModel.fromEntity(e).toCreateMap();

    expect(map['status'], RequestStatus.pending.value);
    expect(map['userId'], 'u1');
    expect(map['requestedBy'], 'u1');
    expect(map['kind'], 'missingClockOut');
    expect(map['reason'], 'Forgot to clock out');
    expect(map['proposedClockOut'], isA<Timestamp>());
    // No decision / resolution / server timestamps in the filing payload.
    expect(map.containsKey('resolution'), isFalse);
    expect(map.containsKey('decidedBy'), isFalse);
    expect(map.containsKey('createdAt'), isFalse);
  });

  test('fromMap parses a decided correction with its resolution', () {
    final map = <String, dynamic>{
      'attendanceId': 'u1_20260713_morning',
      'userId': 'u1',
      'branchId': 'b1',
      'shift': 'morning',
      'date': Timestamp.fromDate(DateTime(2026, 7, 13)),
      'requestedBy': 'u1',
      'kind': 'missingClockOut',
      'status': 'approved',
      'reason': 'Forgot to clock out',
      'proposedClockOut': Timestamp.fromDate(DateTime(2026, 7, 13, 16, 30)),
      'resolution': {
        'clockIn': Timestamp.fromDate(DateTime(2026, 7, 13, 8, 30)),
        'clockOut': Timestamp.fromDate(DateTime(2026, 7, 13, 16, 30)),
        'status': 'completed',
        'workedMinutes': 480,
        'lateMinutes': 0,
        'earlyLeaveMinutes': 0,
        'overtimeMinutes': 0,
        'breakMinutes': 0,
      },
      'decidedBy': 'm1',
      'decidedByName': 'Manager',
      'decidedAt': Timestamp.fromDate(DateTime(2026, 7, 13, 18)),
      'createdAt': Timestamp.fromDate(DateTime(2026, 7, 13, 17)),
    };
    final e = AttendanceCorrectionModel.fromMap(map, id: 'c1').toEntity();

    expect(e.id, 'c1');
    expect(e.status, RequestStatus.approved);
    expect(e.kind, AttendanceCorrectionKind.missingClockOut);
    expect(e.shift, ScheduleShift.morning);
    expect(e.isApproved, isTrue);
    expect(e.resolution, isNotNull);
    expect(e.resolution!.workedMinutes, 480);
    expect(e.resolution!.status, AttendanceStatus.completed);
    expect(e.resolution!.clockOut, DateTime(2026, 7, 13, 16, 30));
    expect(e.decidedBy, 'm1');
  });

  test('resolutionToMap round-trips through fromMap', () {
    const res = AttendanceResolution(
      clockIn: null,
      clockOut: null,
      status: AttendanceStatus.completed,
      workedMinutes: 300,
      lateMinutes: 12,
      earlyLeaveMinutes: 0,
      overtimeMinutes: 5,
      breakMinutes: 30,
    );
    final resMap = AttendanceCorrectionModel.resolutionToMap(res);
    final parsed = AttendanceCorrectionModel.fromMap({
      'attendanceId': 'a',
      'userId': 'u1',
      'requestedBy': 'u1',
      'kind': 'wrongTime',
      'reason': 'x',
      'resolution': resMap,
    }).toEntity();

    expect(parsed.resolution, res);
  });

  test('unknown kind / status fall back to safe defaults', () {
    final e = AttendanceCorrectionModel.fromMap({
      'attendanceId': 'a',
      'userId': 'u1',
      'requestedBy': 'u1',
      'kind': 'nonsense',
      'status': 'nonsense',
      'reason': 'x',
    }).toEntity();
    expect(e.kind, AttendanceCorrectionKind.other);
    expect(e.status, RequestStatus.pending);
    expect(e.resolution, isNull);
  });
}
