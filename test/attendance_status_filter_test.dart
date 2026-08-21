import 'package:flutter_test/flutter_test.dart';
import 'package:opshub/core/enums/attendance_status.dart';
import 'package:opshub/core/enums/attendance_status_filter.dart';
import 'package:opshub/core/enums/schedule_shift.dart';
import 'package:opshub/features/attendance/domain/attendance_history_query.dart';
import 'package:opshub/features/attendance/domain/entities/attendance_entity.dart';

AttendanceEntity _rec({
  AttendanceStatus status = AttendanceStatus.completed,
  int late = 0,
  int early = 0,
  int overtime = 0,
}) =>
    AttendanceEntity(
      id: 'r',
      userId: 'u1',
      shift: ScheduleShift.morning,
      date: DateTime(2026, 7, 10),
      status: status,
      lateMinutes: late,
      earlyLeaveMinutes: early,
      overtimeMinutes: overtime,
    );

void main() {
  group('matchesAttendanceStatusFilter', () {
    test('all matches everything', () {
      for (final s in AttendanceStatus.values) {
        expect(
          matchesAttendanceStatusFilter(AttendanceStatusFilter.all, _rec(status: s)),
          isTrue,
        );
      }
    });

    test('onTime = present and not late', () {
      expect(
        matchesAttendanceStatusFilter(
            AttendanceStatusFilter.onTime, _rec(status: AttendanceStatus.completed)),
        isTrue,
      );
      // Present but late → not on time.
      expect(
        matchesAttendanceStatusFilter(AttendanceStatusFilter.onTime,
            _rec(status: AttendanceStatus.completed, late: 5)),
        isFalse,
      );
      // Absent → not present → not on time.
      expect(
        matchesAttendanceStatusFilter(
            AttendanceStatusFilter.onTime, _rec(status: AttendanceStatus.absent)),
        isFalse,
      );
    });

    test('late = lateMinutes > 0', () {
      expect(
        matchesAttendanceStatusFilter(AttendanceStatusFilter.late, _rec(late: 12)),
        isTrue,
      );
      expect(
        matchesAttendanceStatusFilter(AttendanceStatusFilter.late, _rec(late: 0)),
        isFalse,
      );
    });

    test('absent / leave map to the lifecycle status', () {
      expect(
        matchesAttendanceStatusFilter(
            AttendanceStatusFilter.absent, _rec(status: AttendanceStatus.absent)),
        isTrue,
      );
      expect(
        matchesAttendanceStatusFilter(
            AttendanceStatusFilter.leave, _rec(status: AttendanceStatus.onLeave)),
        isTrue,
      );
      // A completed record is neither absent nor leave.
      expect(
        matchesAttendanceStatusFilter(
            AttendanceStatusFilter.absent, _rec(status: AttendanceStatus.completed)),
        isFalse,
      );
    });

    test('excused maps to the excused lifecycle status only', () {
      expect(
        matchesAttendanceStatusFilter(AttendanceStatusFilter.excused,
            _rec(status: AttendanceStatus.excused)),
        isTrue,
      );
      // An absent (unforgiven) record does not match the excused facet.
      expect(
        matchesAttendanceStatusFilter(
            AttendanceStatusFilter.excused, _rec(status: AttendanceStatus.absent)),
        isFalse,
      );
    });

    test('earlyLeave / overtime read the derived minute fields', () {
      expect(
        matchesAttendanceStatusFilter(
            AttendanceStatusFilter.earlyLeave, _rec(early: 8)),
        isTrue,
      );
      expect(
        matchesAttendanceStatusFilter(
            AttendanceStatusFilter.overtime, _rec(overtime: 30)),
        isTrue,
      );
      expect(
        matchesAttendanceStatusFilter(
            AttendanceStatusFilter.earlyLeave, _rec(early: 0)),
        isFalse,
      );
    });
  });
}
