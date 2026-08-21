import 'package:flutter_test/flutter_test.dart';
import 'package:opshub/core/enums/attendance_correction_kind.dart';
import 'package:opshub/core/enums/attendance_status.dart';
import 'package:opshub/core/enums/request_status.dart';
import 'package:opshub/core/enums/schedule_shift.dart';
import 'package:opshub/features/attendance/domain/attendance_resolution.dart';
import 'package:opshub/features/attendance/domain/entities/attendance_correction.dart';
import 'package:opshub/features/attendance/domain/entities/attendance_entity.dart';
import 'package:opshub/features/attendance/domain/repositories/attendance_repository.dart';
import 'package:opshub/features/attendance/domain/usecases/decide_correction.dart';

/// Captures the decision write; everything else is unimplemented.
class _CaptureRepo implements AttendanceRepository {
  ({
    String id,
    RequestStatus status,
    String decidedBy,
    AttendanceResolution? resolution,
  })? decision;

  @override
  Future<void> decideCorrection(String id,
      {required RequestStatus status,
      required String decidedBy,
      String? decidedByName,
      String? decisionNote,
      AttendanceResolution? resolution}) async {
    decision = (
      id: id,
      status: status,
      decidedBy: decidedBy,
      resolution: resolution,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}

void main() {
  final record = AttendanceEntity(
    id: 'u1_20260713_morning',
    userId: 'u1',
    branchId: 'b1',
    shift: ScheduleShift.morning,
    date: DateTime(2026, 7, 13),
    scheduledStart: DateTime(2026, 7, 13, 8, 30),
    scheduledEnd: DateTime(2026, 7, 13, 16, 30),
    clockIn: DateTime(2026, 7, 13, 8, 30),
    status: AttendanceStatus.pendingReview, // auto-closed, no clock-out
  );

  final correction = AttendanceCorrectionEntity(
    id: 'c1',
    attendanceId: record.id,
    userId: 'u1',
    branchId: 'b1',
    requestedBy: 'u1',
    kind: AttendanceCorrectionKind.missingClockOut,
    reason: 'Forgot to clock out',
    proposedClockOut: DateTime(2026, 7, 13, 16, 30),
  );

  test('approve computes the resolution via AttendanceCalculator', () async {
    final repo = _CaptureRepo();
    final result = await DecideCorrection(repo).call(
      correction,
      record: record,
      approve: true,
      decidedBy: 'm1',
      decidedByName: 'Manager',
      now: DateTime(2026, 7, 13, 18),
    );

    expect(repo.decision, isNotNull);
    expect(repo.decision!.status, RequestStatus.approved);
    expect(repo.decision!.decidedBy, 'm1');
    final res = repo.decision!.resolution!;
    expect(res.clockIn, DateTime(2026, 7, 13, 8, 30));
    expect(res.clockOut, DateTime(2026, 7, 13, 16, 30));
    expect(res.status, AttendanceStatus.completed);
    expect(res.workedMinutes, 480); // 08:30 → 16:30, no breaks
    expect(res.overtimeMinutes, 0);
    expect(res.earlyLeaveMinutes, 0);
    // The use case returns the same resolution it persisted.
    expect(result, res);
  });

  test('reject writes no resolution and leaves status rejected', () async {
    final repo = _CaptureRepo();
    final result = await DecideCorrection(repo).call(
      correction,
      record: record,
      approve: false,
      decidedBy: 'm1',
      now: DateTime(2026, 7, 13, 18),
    );

    expect(result, isNull);
    expect(repo.decision!.status, RequestStatus.rejected);
    expect(repo.decision!.resolution, isNull);
  });

  test('missed-punch: prices from the correction\'s own scheduled window',
      () async {
    // The record never existed (the employee forgot to clock in). The admin cubit
    // passes a synthetic record shell whose scheduled window comes from the
    // correction — lateness must still be measured against it.
    final repo = _CaptureRepo();
    final missedPunch = AttendanceCorrectionEntity(
      id: 'c2',
      attendanceId: 'u1_20260713_morning',
      userId: 'u1',
      branchId: 'b1',
      requestedBy: 'u1',
      kind: AttendanceCorrectionKind.absenceDispute,
      reason: 'Forgot to clock in',
      scheduledStart: DateTime(2026, 7, 13, 8, 30),
      scheduledEnd: DateTime(2026, 7, 13, 16, 30),
      proposedClockIn: DateTime(2026, 7, 13, 8, 50), // 20 min late
      proposedClockOut: DateTime(2026, 7, 13, 16, 30),
    );
    // The synthetic shell the admin cubit builds: identity + window, no clock.
    final synthetic = AttendanceEntity(
      id: missedPunch.attendanceId,
      userId: 'u1',
      shift: ScheduleShift.morning,
      date: DateTime(2026, 7, 13),
      scheduledStart: missedPunch.scheduledStart,
      scheduledEnd: missedPunch.scheduledEnd,
      status: AttendanceStatus.pendingReview,
    );
    await DecideCorrection(repo).call(
      missedPunch,
      record: synthetic,
      approve: true,
      decidedBy: 'm1',
      now: DateTime(2026, 7, 13, 18),
    );
    final res = repo.decision!.resolution!;
    expect(res.clockIn, DateTime(2026, 7, 13, 8, 50));
    expect(res.workedMinutes, 460); // 08:50 → 16:30
    expect(res.lateMinutes, 20); // measured against the correction's window
  });

  test('proposedStatus overrides the resolved lifecycle (absence dispute)',
      () async {
    final repo = _CaptureRepo();
    final dispute = correction.copyWith(
      kind: AttendanceCorrectionKind.absenceDispute,
      proposedClockIn: DateTime(2026, 7, 13, 8, 30),
      proposedClockOut: DateTime(2026, 7, 13, 16, 30),
      proposedStatus: AttendanceStatus.completed,
    );
    await DecideCorrection(repo).call(
      dispute,
      record: record.copyWith(status: AttendanceStatus.absent),
      approve: true,
      decidedBy: 'm1',
      now: DateTime(2026, 7, 13, 18),
    );
    expect(repo.decision!.resolution!.status, AttendanceStatus.completed);
    expect(repo.decision!.resolution!.workedMinutes, 480);
  });
}
