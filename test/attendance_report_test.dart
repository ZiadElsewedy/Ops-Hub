import 'package:flutter_test/flutter_test.dart';
import 'package:drop/core/enums/attendance_status.dart';
import 'package:drop/core/enums/schedule_shift.dart';
import 'package:drop/features/attendance/domain/attendance_id.dart';
import 'package:drop/features/attendance/domain/entities/attendance_entity.dart';
import 'package:drop/features/attendance/domain/reporting/attendance_expectation.dart';
import 'package:drop/features/attendance/domain/reporting/attendance_report.dart';
import 'package:drop/features/schedule/domain/entities/weekly_schedule_entity.dart';

void main() {
  group('AttendanceRate', () {
    test('zero denominator is null, not zero', () {
      const rate = AttendanceRate(
        numerator: 0,
        denominator: 0,
        denominatorLabel: 'scheduled shifts',
      );

      expect(rate.percent, isNull);
      expect(rate.describe(), '-- · 0 / 0 scheduled shifts');
    });
  });

  group('AttendanceReportSummary', () {
    test('empty summary rates have null denominators', () {
      expect(AttendanceReportSummary.empty.showUpRate.percent, isNull);
      expect(AttendanceReportSummary.empty.unexcusedAbsenceRate.percent, isNull);
      expect(AttendanceReportSummary.empty.punctualArrivalRate.percent, isNull);
    });

    test('unscheduled work does not inflate the expected-shift denominator', () {
      final date = DateTime(2026, 7, 26);
      final record = AttendanceEntity(
        id: attendanceDocId(
          uid: 'u1',
          date: date,
          shift: ScheduleShift.morning,
        ),
        userId: 'u1',
        branchId: 'b1',
        shift: ScheduleShift.morning,
        date: date,
        clockIn: DateTime(2026, 7, 26, 9),
        clockOut: DateTime(2026, 7, 26, 10),
        status: AttendanceStatus.completed,
      );
      final schedule = WeeklyScheduleEntity(
        id: 'b1_2026-07-26',
        branchId: 'b1',
        weekStart: date,
      );

      final rows = unscheduledWorkRows(
        records: [record],
        schedule: schedule,
        now: DateTime(2026, 7, 26, 11),
      );
      final summary = AttendanceReportSummary.fromRows(rows);

      expect(rows.single.recordId, record.id);
      expect(summary.unscheduledWork, 1);
      expect(summary.expectedWorkShifts, 0);
      expect(summary.present, 0);
      expect(summary.showUpRate.percent, isNull);
    });

    test('manager presence work is reported, but not as unscheduled work', () {
      // Same shape as the case above — a record with no roster slot — except
      // it is presence-only. The row must still exist (the work happened and
      // has to be visible), but it is not an anomaly to explain, so it never
      // carries the unscheduledWork code.
      final date = DateTime(2026, 7, 26);
      final record = AttendanceEntity(
        id: attendanceDocId(
          uid: 'm1',
          date: date,
          shift: ScheduleShift.morning,
        ),
        userId: 'm1',
        branchId: 'b1',
        shift: ScheduleShift.morning,
        date: date,
        presenceOnly: true,
        clockIn: DateTime(2026, 7, 26, 9),
        clockOut: DateTime(2026, 7, 26, 17),
        status: AttendanceStatus.completed,
      );
      final schedule = WeeklyScheduleEntity(
        id: 'b1_2026-07-26',
        branchId: 'b1',
        weekStart: date,
      );

      final rows = unscheduledWorkRows(
        records: [record],
        schedule: schedule,
        now: DateTime(2026, 7, 26, 18),
      );

      expect(rows.single.recordId, record.id, reason: 'the work stays visible');
      expect(rows.single.exceptions, isEmpty);

      final summary = AttendanceReportSummary.fromRows(rows);
      expect(summary.unscheduledWork, 0, reason: 'not an anomaly');
      // Presence work is real work, but it is not roster adherence: it must
      // stay out of both sides of the show-up rate while still contributing
      // its hours.
      expect(summary.expectedWorkShifts, 0);
      expect(summary.present, 0);
      expect(summary.showUpRate.percent, isNull);
      expect(summary.workedMinutes, 480);
    });
  });
}
