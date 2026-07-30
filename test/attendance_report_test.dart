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
        denominatorLabel: 'expected work shifts',
      );

      expect(rate.percent, isNull);
      expect(rate.describe(), '-- · 0 / 0 expected work shifts');
    });
  });

  group('AttendanceReportSummary', () {
    test('empty summary rates have null denominators', () {
      expect(AttendanceReportSummary.empty.showUpRate.percent, isNull);
      expect(AttendanceReportSummary.empty.unexcusedAbsenceRate.percent, isNull);
      expect(AttendanceReportSummary.empty.punctualArrivalRate.percent, isNull);
    });

    test('unscheduled work does not inflate expected work shifts', () {
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
  });
}
