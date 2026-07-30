import 'package:flutter_test/flutter_test.dart';
import 'package:drop/core/enums/attendance_status.dart';
import 'package:drop/core/enums/leave_type.dart';
import 'package:drop/core/enums/schedule_day.dart';
import 'package:drop/core/enums/schedule_shift.dart';
import 'package:drop/features/attendance/domain/attendance_id.dart';
import 'package:drop/features/attendance/domain/entities/attendance_entity.dart';
import 'package:drop/features/attendance/domain/reporting/attendance_expectation.dart';
import 'package:drop/features/attendance/domain/reporting/attendance_report.dart';
import 'package:drop/features/schedule/domain/entities/weekly_schedule_entity.dart';
import 'package:drop/features/schedule/domain/shift_hours.dart';

void main() {
  final weekStart = DateTime(2026, 7, 26);

  WeeklyScheduleEntity schedule({
    Map<ScheduleDay, Map<ScheduleShift, List<String>>> assignments =
        const <ScheduleDay, Map<ScheduleShift, List<String>>>{},
    Map<ScheduleDay, Map<String, LeaveType>> leave =
        const <ScheduleDay, Map<String, LeaveType>>{},
    Map<ScheduleDay, Map<ScheduleShift, ShiftHours>> shiftHours =
        const <ScheduleDay, Map<ScheduleShift, ShiftHours>>{},
  }) {
    return WeeklyScheduleEntity(
      id: 'b1_2026-07-26',
      branchId: 'b1',
      weekStart: weekStart,
      assignments: assignments,
      leave: leave,
      shiftHours: shiftHours,
    );
  }

  AttendanceEntity record({
    required String uid,
    required DateTime date,
    required ScheduleShift shift,
    required DateTime scheduledStart,
    required DateTime scheduledEnd,
    required DateTime? clockIn,
    required DateTime? clockOut,
    AttendanceStatus status = AttendanceStatus.completed,
    DateTime? deletedAt,
  }) {
    return AttendanceEntity(
      id: attendanceDocId(uid: uid, date: date, shift: shift),
      userId: uid,
      branchId: 'b1',
      shift: shift,
      date: date,
      scheduledStart: scheduledStart,
      scheduledEnd: scheduledEnd,
      clockIn: clockIn,
      clockOut: clockOut,
      status: status,
      deletedAt: deletedAt,
    );
  }

  group('buildExpectedShiftRows', () {
    test('P0: rostered no-shows become phantom absent denominator rows', () {
      // P0 defect fixed: lazy no-shows used to write no documents, so the
      // history denominator never grew and the rate could pin at 100%.
      final s = schedule(assignments: {
        ScheduleDay.sunday: {
          ScheduleShift.morning: ['u1', 'u2', 'u3', 'u4'],
        },
      });

      final rows = buildExpectedShiftRows(
        schedule: s,
        records: const [],
        now: DateTime(2026, 7, 26, 19),
      );
      final summary = AttendanceReportSummary.fromRows(rows);

      expect(rows, hasLength(4));
      expect(rows.every((r) => r.outcome == ExpectedShiftOutcome.absent), isTrue);
      expect(rows.every((r) => r.recordId == null), isTrue);
      expect(rows.every((r) => r.isPhantom), isTrue);
      expect(summary.expectedWorkShifts, 4);
      expect(summary.absent, 4);
      expect(summary.showUpRate.percent, 0);
    });

    test('show-up rate excludes leave and excused from denominator', () {
      final date = DateTime(2026, 7, 26);
      final start = DateTime(2026, 7, 26, 8, 30);
      final end = DateTime(2026, 7, 26, 16, 30);
      final s = schedule(
        assignments: {
          ScheduleDay.sunday: {
            ScheduleShift.morning: ['present', 'leave', 'excused'],
          },
        },
        leave: {
          ScheduleDay.sunday: {'leave': LeaveType.annual},
        },
      );
      final rows = buildExpectedShiftRows(
        schedule: s,
        records: [
          record(
            uid: 'present',
            date: date,
            shift: ScheduleShift.morning,
            scheduledStart: start,
            scheduledEnd: end,
            clockIn: start,
            clockOut: end,
          ),
          record(
            uid: 'excused',
            date: date,
            shift: ScheduleShift.morning,
            scheduledStart: start,
            scheduledEnd: end,
            clockIn: null,
            clockOut: null,
            status: AttendanceStatus.excused,
          ),
        ],
        now: DateTime(2026, 7, 26, 19),
      );
      final summary = AttendanceReportSummary.fromRows(rows);

      expect(summary.expectedWorkShifts, 1);
      expect(summary.present, 1);
      expect(summary.onLeave, 1);
      expect(summary.excused, 1);
      expect(summary.showUpRate.percent, 100);
    });

    test('late present employee counts show-up but reduces punctuality', () {
      final date = DateTime(2026, 7, 26);
      final start = DateTime(2026, 7, 26, 8, 30);
      final end = DateTime(2026, 7, 26, 16, 30);
      final s = schedule(assignments: {
        ScheduleDay.sunday: {
          ScheduleShift.morning: ['on-time', 'late'],
        },
      });

      final rows = buildExpectedShiftRows(
        schedule: s,
        records: [
          record(
            uid: 'on-time',
            date: date,
            shift: ScheduleShift.morning,
            scheduledStart: start,
            scheduledEnd: end,
            clockIn: start,
            clockOut: end,
          ),
          record(
            uid: 'late',
            date: date,
            shift: ScheduleShift.morning,
            scheduledStart: start,
            scheduledEnd: end,
            clockIn: DateTime(2026, 7, 26, 8, 50),
            clockOut: end,
          ),
        ],
        now: DateTime(2026, 7, 26, 19),
      );
      final summary = AttendanceReportSummary.fromRows(rows);

      expect(summary.present, 2);
      expect(summary.lateArrivals, 1);
      expect(summary.showUpRate.percent, 100);
      expect(summary.punctualArrivalRate.percent, 50);
    });

    test('overnight shift end rolls into the following calendar day', () {
      final saturday = DateTime(2026, 8, 1);
      final start = DateTime(2026, 8, 1, 16, 30);
      final end = DateTime(2026, 8, 2, 1);
      final s = schedule(
        assignments: {
          ScheduleDay.saturday: {
            ScheduleShift.night: ['u1'],
          },
        },
        shiftHours: {
          ScheduleDay.saturday: {
            ScheduleShift.night: ShiftHours.hm(16, 30, 1, 0, endNextDay: true),
          },
        },
      );

      final rows = buildExpectedShiftRows(
        schedule: s,
        records: [
          record(
            uid: 'u1',
            date: saturday,
            shift: ScheduleShift.night,
            scheduledStart: start,
            scheduledEnd: end,
            clockIn: start,
            clockOut: DateTime(2026, 8, 2, 0, 55),
          ),
        ],
        now: DateTime(2026, 8, 2, 2),
      );

      expect(rows.single.scheduledEnd, end);
      expect(rows.single.outcome, ExpectedShiftOutcome.worked);
    });

    test('unfinished shift with no record is noRecordYet, not absent', () {
      final s = schedule(assignments: {
        ScheduleDay.sunday: {
          ScheduleShift.morning: ['u1'],
        },
      });

      final rows = buildExpectedShiftRows(
        schedule: s,
        records: const [],
        now: DateTime(2026, 7, 26, 12),
      );

      expect(rows.single.outcome, ExpectedShiftOutcome.noRecordYet);
    });

    test('soft-deleted records are ignored', () {
      final date = DateTime(2026, 7, 26);
      final start = DateTime(2026, 7, 26, 8, 30);
      final end = DateTime(2026, 7, 26, 16, 30);
      final s = schedule(assignments: {
        ScheduleDay.sunday: {
          ScheduleShift.morning: ['u1'],
        },
      });

      final rows = buildExpectedShiftRows(
        schedule: s,
        records: [
          record(
            uid: 'u1',
            date: date,
            shift: ScheduleShift.morning,
            scheduledStart: start,
            scheduledEnd: end,
            clockIn: start,
            clockOut: end,
            deletedAt: DateTime(2026, 7, 27),
          ),
        ],
        now: DateTime(2026, 7, 26, 19),
      );

      expect(rows.single.outcome, ExpectedShiftOutcome.absent);
      expect(rows.single.recordId, isNull);
    });

    test('row output ordering is deterministic', () {
      final s = schedule(assignments: {
        ScheduleDay.monday: {
          ScheduleShift.morning: ['u0'],
        },
        ScheduleDay.sunday: {
          ScheduleShift.night: ['u2'],
          ScheduleShift.morning: ['u3', 'u1'],
        },
      });

      final rows = buildExpectedShiftRows(
        schedule: s,
        records: const [],
        now: DateTime(2026, 7, 27, 19),
      );

      expect(
        rows.map((r) => '${r.date.day}:${r.shift.name}:${r.uid}').toList(),
        ['26:morning:u1', '26:morning:u3', '26:night:u2', '27:morning:u0'],
      );
    });
  });
}
