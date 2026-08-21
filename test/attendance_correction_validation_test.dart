import 'package:flutter_test/flutter_test.dart';
import 'package:opshub/core/enums/attendance_status.dart';
import 'package:opshub/core/enums/schedule_shift.dart';
import 'package:opshub/features/attendance/domain/attendance_validation.dart';
import 'package:opshub/features/attendance/domain/entities/attendance_entity.dart';

void main() {
  AttendanceEntity record({
    DateTime? clockIn,
    DateTime? clockOut,
    AttendanceStatus status = AttendanceStatus.pendingReview,
    DateTime? deletedAt,
  }) =>
      AttendanceEntity(
        id: 'u1_20260713_morning',
        userId: 'u1',
        shift: ScheduleShift.morning,
        date: DateTime(2026, 7, 13),
        clockIn: clockIn ?? DateTime(2026, 7, 13, 8, 30),
        clockOut: clockOut,
        status: status,
        deletedAt: deletedAt,
      );

  AttendanceCheck check({
    AttendanceEntity? existing,
    String reason = 'Forgot to clock out',
    DateTime? proposedClockIn,
    DateTime? proposedClockOut,
    AttendanceStatus? proposedStatus,
  }) =>
      AttendanceValidation.checkCorrection(
        existing: existing ?? record(),
        reason: reason,
        proposedClockIn: proposedClockIn,
        proposedClockOut: proposedClockOut ?? DateTime(2026, 7, 13, 16, 30),
        proposedStatus: proposedStatus,
      );

  test('a well-formed correction on a settled record is allowed', () {
    expect(check().allowed, isTrue);
  });

  test('no record + no start time → missingStartTime (missed punch)', () {
    // A missed-punch materializes a record, so a null record is NOT recordMissing
    // (spec workflow 4) — but the employee must assert when they started.
    final c = AttendanceValidation.checkCorrection(
      existing: null,
      reason: 'Forgot to clock in',
      proposedClockOut: DateTime(2026, 7, 13, 16, 30),
    );
    expect(c.reason, AttendanceBlock.missingStartTime);
  });

  test('no record + a full missed punch is allowed', () {
    final c = AttendanceValidation.checkCorrection(
      existing: null,
      reason: 'Forgot to clock in — worked the full shift',
      proposedClockIn: DateTime(2026, 7, 13, 8, 30),
      proposedClockOut: DateTime(2026, 7, 13, 16, 30),
    );
    expect(c.allowed, isTrue);
  });

  test('an existing open correction → duplicateOpen', () {
    final c = AttendanceValidation.checkCorrection(
      existing: record(),
      reason: 'Fix the time',
      proposedClockOut: DateTime(2026, 7, 13, 16, 30),
      hasOpenCorrection: true,
    );
    expect(c.reason, AttendanceBlock.duplicateOpen);
  });

  test('soft-deleted record → recordMissing', () {
    expect(
      check(existing: record(deletedAt: DateTime(2026, 7, 13, 20))).reason,
      AttendanceBlock.recordMissing,
    );
  });

  test('a still-open session → sessionOpen', () {
    expect(
      check(existing: record(status: AttendanceStatus.inProgress)).reason,
      AttendanceBlock.sessionOpen,
    );
  });

  test('empty reason → emptyReason', () {
    expect(check(reason: '   ').reason, AttendanceBlock.emptyReason);
  });

  test('nothing proposed → invalidTimes', () {
    final c = AttendanceValidation.checkCorrection(
      existing: record(),
      reason: 'x',
    );
    expect(c.reason, AttendanceBlock.invalidTimes);
  });

  test('clock-out not after clock-in → invalidTimes', () {
    final c = check(
      proposedClockIn: DateTime(2026, 7, 13, 16, 30),
      proposedClockOut: DateTime(2026, 7, 13, 8, 30),
    );
    expect(c.reason, AttendanceBlock.invalidTimes);
  });

  test('a status-only dispute (no times) is allowed', () {
    final c = AttendanceValidation.checkCorrection(
      existing: record(status: AttendanceStatus.absent),
      reason: 'I did work',
      proposedStatus: AttendanceStatus.completed,
    );
    expect(c.allowed, isTrue);
  });

  group('checkManagerEntry (direct action)', () {
    final start = DateTime(2026, 7, 13, 8, 30);
    final end = DateTime(2026, 7, 13, 16, 30);

    test('add record for a missing shift is allowed', () {
      final c = AttendanceValidation.checkManagerEntry(
        existing: null,
        reason: 'Employee worked, forgot to clock in',
        proposedClockIn: start,
        proposedClockOut: end,
      );
      expect(c.allowed, isTrue);
    });

    test('resolve a pendingReview record is allowed', () {
      final c = AttendanceValidation.checkManagerEntry(
        existing: record(status: AttendanceStatus.pendingReview),
        reason: 'Left at 16:30',
        proposedClockIn: start,
        proposedClockOut: end,
      );
      expect(c.allowed, isTrue);
    });

    test('empty reason → emptyReason (reason is mandatory)', () {
      final c = AttendanceValidation.checkManagerEntry(
        existing: null,
        reason: '  ',
        proposedClockIn: start,
      );
      expect(c.reason, AttendanceBlock.emptyReason);
    });

    test('no start time → missingStartTime', () {
      final c = AttendanceValidation.checkManagerEntry(
        existing: null,
        reason: 'x',
      );
      expect(c.reason, AttendanceBlock.missingStartTime);
    });

    test('a still-running session cannot be resolved', () {
      final c = AttendanceValidation.checkManagerEntry(
        existing: record(status: AttendanceStatus.inProgress),
        reason: 'x',
        proposedClockIn: start,
      );
      expect(c.reason, AttendanceBlock.sessionOpen);
    });

    test('an open correction blocks a direct action → duplicateOpen', () {
      final c = AttendanceValidation.checkManagerEntry(
        existing: record(),
        reason: 'x',
        proposedClockIn: start,
        hasOpenCorrection: true,
      );
      expect(c.reason, AttendanceBlock.duplicateOpen);
    });

    test('clock-out before clock-in → invalidTimes', () {
      final c = AttendanceValidation.checkManagerEntry(
        existing: null,
        reason: 'x',
        proposedClockIn: end,
        proposedClockOut: start,
      );
      expect(c.reason, AttendanceBlock.invalidTimes);
    });
  });

  group('checkExcuse', () {
    test('excusing a virtual absence (no record) is allowed with a reason', () {
      final c = AttendanceValidation.checkExcuse(
        existing: null,
        reason: 'Approved family emergency',
      );
      expect(c.allowed, isTrue);
    });

    test('reason is mandatory → emptyReason', () {
      final c = AttendanceValidation.checkExcuse(existing: null, reason: '  ');
      expect(c.reason, AttendanceBlock.emptyReason);
    });

    test('a still-running session cannot be excused', () {
      final c = AttendanceValidation.checkExcuse(
        existing: record(status: AttendanceStatus.inProgress),
        reason: 'x',
      );
      expect(c.reason, AttendanceBlock.sessionOpen);
    });

    test('an open correction blocks an excuse → duplicateOpen', () {
      final c = AttendanceValidation.checkExcuse(
        existing: record(status: AttendanceStatus.absent),
        reason: 'x',
        hasOpenCorrection: true,
      );
      expect(c.reason, AttendanceBlock.duplicateOpen);
    });
  });
}
