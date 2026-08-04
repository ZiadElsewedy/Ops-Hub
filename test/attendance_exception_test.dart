import 'package:flutter_test/flutter_test.dart';
import 'package:drop/core/enums/attendance_status.dart';
import 'package:drop/core/enums/schedule_shift.dart';
import 'package:drop/features/attendance/domain/attendance_calculator.dart';
import 'package:drop/features/attendance/domain/attendance_id.dart';
import 'package:drop/features/attendance/domain/entities/attendance_entity.dart';
import 'package:drop/features/attendance/domain/reporting/attendance_exception.dart';

void main() {
  AttendanceEntity record({
    required DateTime date,
    required DateTime scheduledStart,
    required DateTime scheduledEnd,
    required DateTime? clockIn,
    required DateTime? clockOut,
    AttendanceStatus status = AttendanceStatus.completed,
  }) {
    return AttendanceEntity(
      id: attendanceDocId(
        uid: 'u1',
        date: date,
        shift: ScheduleShift.morning,
      ),
      userId: 'u1',
      branchId: 'b1',
      shift: ScheduleShift.morning,
      date: date,
      scheduledStart: scheduledStart,
      scheduledEnd: scheduledEnd,
      clockIn: clockIn,
      clockOut: clockOut,
      status: status,
    );
  }

  group('classifyExceptions', () {
    test('flags implausible 14:14 to 14:15 record on an 8-hour shift', () {
      final date = DateTime(2026, 7, 26);
      final start = DateTime(2026, 7, 26, 8, 30);
      final end = DateTime(2026, 7, 26, 16, 30);
      final r = record(
        date: date,
        scheduledStart: start,
        scheduledEnd: end,
        clockIn: DateTime(2026, 7, 26, 14, 14),
        clockOut: DateTime(2026, 7, 26, 14, 15),
      );
      final totals = AttendanceCalculator.forEntity(r, r.clockOut!);

      final codes = classifyExceptions(
        record: r,
        totals: totals,
        scheduledStart: start,
        scheduledEnd: end,
      );

      expect(totals.workedMinutes, 1);
      expect(codes, [
        AttendanceExceptionCode.late,
        AttendanceExceptionCode.earlyLeave,
        AttendanceExceptionCode.implausibleRecord,
      ]);
    });

    test('does not flag implausible for a genuinely short scheduled shift', () {
      final date = DateTime(2026, 7, 26);
      final start = DateTime(2026, 7, 26, 14);
      final end = DateTime(2026, 7, 26, 14, 20);
      final r = record(
        date: date,
        scheduledStart: start,
        scheduledEnd: end,
        clockIn: DateTime(2026, 7, 26, 14, 14),
        clockOut: DateTime(2026, 7, 26, 14, 15),
      );
      final totals = AttendanceCalculator.forEntity(r, r.clockOut!);

      final codes = classifyExceptions(
        record: r,
        totals: totals,
        scheduledStart: start,
        scheduledEnd: end,
      );

      expect(codes.contains(AttendanceExceptionCode.implausibleRecord), isFalse);
    });

    test('marks missing punch for pending review and open-past-end records', () {
      final date = DateTime(2026, 7, 26);
      final start = DateTime(2026, 7, 26, 8, 30);
      final end = DateTime(2026, 7, 26, 16, 30);
      final pending = record(
        date: date,
        scheduledStart: start,
        scheduledEnd: end,
        clockIn: start,
        clockOut: null,
        status: AttendanceStatus.pendingReview,
      );
      final open = record(
        date: date,
        scheduledStart: start,
        scheduledEnd: end,
        clockIn: start,
        clockOut: null,
        status: AttendanceStatus.inProgress,
      );
      final openTotals = AttendanceCalculator.forEntity(
        open,
        DateTime(2026, 7, 26, 17),
      );

      expect(
        classifyExceptions(
          record: pending,
          totals: AttendanceCalculator.forEntity(pending, end),
          scheduledStart: start,
          scheduledEnd: end,
        ),
        contains(AttendanceExceptionCode.missingPunch),
      );
      expect(
        classifyExceptions(
          record: open,
          totals: openTotals,
          scheduledStart: start,
          scheduledEnd: end,
        ),
        contains(AttendanceExceptionCode.missingPunch),
      );
    });

    // Presence-only records (managers) have no schedule *by policy*. They must
    // never be filed as anomalies, or reporting drops them from present/absent
    // counts and managers vanish from attendance stats.
    group('presence-only records', () {
      final date = DateTime(2026, 7, 26);

      AttendanceEntity presence({
        DateTime? clockIn,
        DateTime? clockOut,
        AttendanceStatus status = AttendanceStatus.completed,
      }) =>
          AttendanceEntity(
            id: attendanceDocId(
                uid: 'm1', date: date, shift: ScheduleShift.morning),
            userId: 'm1',
            branchId: 'b1',
            shift: ScheduleShift.morning,
            date: date,
            presenceOnly: true,
            clockIn: clockIn,
            clockOut: clockOut,
            status: status,
          );

      test('a schedule-less presence record is not unscheduled work', () {
        final r = presence(
          clockIn: DateTime(2026, 7, 26, 9, 0),
          clockOut: DateTime(2026, 7, 26, 17, 0),
        );
        expect(
          classifyExceptions(
            record: r,
            totals: AttendanceCalculator.forEntity(r, DateTime(2026, 7, 26, 18)),
            scheduledStart: null,
            scheduledEnd: null,
          ),
          isNot(contains(AttendanceExceptionCode.unscheduledWork)),
        );
      });

      test('a schedule-less EMPLOYEE record is still unscheduled work', () {
        final r = AttendanceEntity(
          id: attendanceDocId(
              uid: 'e1', date: date, shift: ScheduleShift.morning),
          userId: 'e1',
          branchId: 'b1',
          shift: ScheduleShift.morning,
          date: date,
          clockIn: DateTime(2026, 7, 26, 9, 0),
          clockOut: DateTime(2026, 7, 26, 17, 0),
          status: AttendanceStatus.completed,
        );
        expect(
          classifyExceptions(
            record: r,
            totals: AttendanceCalculator.forEntity(r, DateTime(2026, 7, 26, 18)),
            scheduledStart: null,
            scheduledEnd: null,
          ),
          contains(AttendanceExceptionCode.unscheduledWork),
        );
      });

      test('a short presence visit is never implausible against a roster slot',
          () {
        // The same 1-minute-on-an-8-hour-slot shape the first test in this file
        // flags for an employee.
        final r = presence(
          clockIn: DateTime(2026, 7, 26, 14, 14),
          clockOut: DateTime(2026, 7, 26, 14, 15),
        );
        expect(
          classifyExceptions(
            record: r,
            totals: AttendanceCalculator.forEntity(r, DateTime(2026, 7, 26, 18)),
            scheduledStart: DateTime(2026, 7, 26, 8, 30),
            scheduledEnd: DateTime(2026, 7, 26, 16, 30),
          ),
          isNot(contains(AttendanceExceptionCode.implausibleRecord)),
        );
      });
    });

    test('blocksClose is true only for close-blocking exception codes', () {
      expect(AttendanceExceptionCode.missingPunch.blocksClose, isTrue);
      expect(AttendanceExceptionCode.implausibleRecord.blocksClose, isTrue);
      expect(AttendanceExceptionCode.pendingCorrection.blocksClose, isTrue);
      expect(AttendanceExceptionCode.late.blocksClose, isFalse);
      expect(AttendanceExceptionCode.earlyLeave.blocksClose, isFalse);
      expect(AttendanceExceptionCode.overtime.blocksClose, isFalse);
    });
  });
}
