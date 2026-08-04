import 'package:flutter_test/flutter_test.dart';
import 'package:drop/core/enums/attendance_status.dart';
import 'package:drop/core/enums/schedule_shift.dart';
import 'package:drop/features/attendance/domain/attendance_break.dart';
import 'package:drop/features/attendance/domain/entities/attendance_entity.dart';

void main() {
  AttendanceEntity make({
    DateTime? clockIn,
    DateTime? clockOut,
    List<AttendanceBreak> breaks = const [],
    int lateMinutes = 0,
    int earlyLeaveMinutes = 0,
    int overtimeMinutes = 0,
    bool unscheduled = false,
    DateTime? deletedAt,
    AttendanceStatus status = AttendanceStatus.inProgress,
  }) =>
      AttendanceEntity(
        id: 'u_20260711_morning',
        userId: 'u',
        shift: ScheduleShift.morning,
        date: DateTime(2026, 7, 11),
        scheduledStart: unscheduled ? null : DateTime(2026, 7, 11, 8, 30),
        clockIn: clockIn,
        clockOut: clockOut,
        breaks: breaks,
        lateMinutes: lateMinutes,
        earlyLeaveMinutes: earlyLeaveMinutes,
        overtimeMinutes: overtimeMinutes,
        deletedAt: deletedAt,
        status: status,
      );

  test('dayKey derives from the date', () {
    expect(make().dayKey, '20260711');
  });

  test('isOpen: clocked in, not out', () {
    expect(make(clockIn: DateTime(2026, 7, 11, 8, 30)).isOpen, isTrue);
    expect(
      make(clockIn: DateTime(2026, 7, 11, 8, 30), clockOut: DateTime(2026, 7, 11, 16, 30))
          .isOpen,
      isFalse,
    );
    expect(make().isOpen, isFalse); // never clocked in
  });

  test('derived facts read from the minute snapshot', () {
    expect(make(lateMinutes: 12).isLate, isTrue);
    expect(make(earlyLeaveMinutes: 8).hasEarlyLeave, isTrue);
    expect(make(overtimeMinutes: 20).hasOvertime, isTrue);
    final clean = make();
    expect(clean.isLate, isFalse);
    expect(clean.hasEarlyLeave, isFalse);
    expect(clean.hasOvertime, isFalse);
  });

  test('isUnscheduled when no scheduled start was captured', () {
    expect(make(unscheduled: true).isUnscheduled, isTrue);
    expect(make().isUnscheduled, isFalse);
  });

  test('a presence-only record is never "unscheduled"', () {
    // It has no schedule by policy, not by accident — so there is no anomaly
    // to explain and nothing downstream should treat it as one.
    final presence = make(unscheduled: true).copyWith(presenceOnly: true);
    expect(presence.scheduledStart, isNull);
    expect(presence.isUnscheduled, isFalse);
  });

  test('soft delete flag', () {
    expect(make(deletedAt: DateTime(2026, 7, 12)).isDeleted, isTrue);
    expect(make().isDeleted, isFalse);
  });
}
