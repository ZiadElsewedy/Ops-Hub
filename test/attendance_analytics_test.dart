import 'package:flutter_test/flutter_test.dart';
import 'package:opshub/core/enums/attendance_status.dart';
import 'package:opshub/core/enums/schedule_shift.dart';
import 'package:opshub/features/attendance/domain/attendance_analytics.dart';
import 'package:opshub/features/attendance/domain/entities/attendance_entity.dart';

void main() {
  AttendanceEntity rec({
    String userId = 'u1',
    String branchId = 'b1',
    required DateTime date,
    AttendanceStatus status = AttendanceStatus.completed,
    DateTime? clockIn,
    DateTime? clockOut,
    int worked = 0,
    int late = 0,
    int early = 0,
    int overtime = 0,
  }) =>
      AttendanceEntity(
        id: '${userId}_${date.year}_${status.name}',
        userId: userId,
        branchId: branchId,
        shift: ScheduleShift.morning,
        date: date,
        status: status,
        clockIn: clockIn,
        clockOut: clockOut,
        workedMinutes: worked,
        lateMinutes: late,
        earlyLeaveMinutes: early,
        overtimeMinutes: overtime,
      );

  group('attendanceStreaks', () {
    test('empty', () {
      final s = attendanceStreaks(const []);
      expect(s.current, 0);
      expect(s.longest, 0);
    });

    test('single day', () {
      final s = attendanceStreaks([DateTime(2026, 7, 1)]);
      expect(s.current, 1);
      expect(s.longest, 1);
    });

    test('a clean consecutive run', () {
      final s = attendanceStreaks([
        DateTime(2026, 7, 1),
        DateTime(2026, 7, 2),
        DateTime(2026, 7, 3),
      ]);
      expect(s.longest, 3);
      expect(s.current, 3);
    });

    test('a gap resets, longest is the best run, current is the tail run', () {
      final s = attendanceStreaks([
        DateTime(2026, 7, 1),
        DateTime(2026, 7, 2),
        DateTime(2026, 7, 5),
        DateTime(2026, 7, 6),
        DateTime(2026, 7, 7),
      ]);
      expect(s.longest, 3); // 5,6,7
      expect(s.current, 3);
    });

    test('duplicate days are de-duplicated', () {
      final s = attendanceStreaks([
        DateTime(2026, 7, 1, 8),
        DateTime(2026, 7, 1, 20),
        DateTime(2026, 7, 2),
      ]);
      expect(s.longest, 2);
      expect(s.current, 2);
    });

    test('asOf breaks the current streak when the last present day is stale', () {
      final s = attendanceStreaks(
        [DateTime(2026, 7, 1), DateTime(2026, 7, 2)],
        asOf: DateTime(2026, 7, 10),
      );
      expect(s.current, 0);
      expect(s.longest, 2);
    });

    test('asOf keeps the streak when the last present day is yesterday', () {
      final s = attendanceStreaks(
        [DateTime(2026, 7, 9), DateTime(2026, 7, 10)],
        asOf: DateTime(2026, 7, 11),
      );
      expect(s.current, 2);
    });
  });

  group('AttendanceStats.from', () {
    final records = [
      rec(
        date: DateTime(2026, 7, 10),
        clockIn: DateTime(2026, 7, 10, 8, 30),
        clockOut: DateTime(2026, 7, 10, 16, 30),
        worked: 480,
      ),
      rec(
        date: DateTime(2026, 7, 11),
        clockIn: DateTime(2026, 7, 11, 8, 50),
        clockOut: DateTime(2026, 7, 11, 16, 30),
        worked: 440,
        late: 20,
      ),
      rec(date: DateTime(2026, 7, 12), status: AttendanceStatus.absent),
      rec(date: DateTime(2026, 7, 13), status: AttendanceStatus.onLeave),
    ];

    final stats = AttendanceStats.from(records);

    test('present / absent counts (leave excluded from both)', () {
      expect(stats.presentCount, 2);
      expect(stats.absentCount, 1);
      expect(stats.totalRecords, 4);
    });

    test('attendance rate = present / (present + absent)', () {
      expect(stats.attendancePercent, closeTo(66.67, 0.01));
    });

    test('late rate over those present', () {
      expect(stats.lateCount, 1);
      expect(stats.latePercent, closeTo(50, 0.01));
    });

    test('average worked over completed records', () {
      expect(stats.completedCount, 2);
      expect(stats.workedMinutes, 920);
      expect(stats.avgWorkedMinutes, 460);
    });

    test('average arrival minute-of-day', () {
      // 08:30 = 510, 08:50 = 530 → 520
      expect(stats.avgArrivalMinuteOfDay, 520);
    });

    test('excused is counted separately and excluded from the rate', () {
      final withExcused = AttendanceStats.from([
        rec(
          date: DateTime(2026, 7, 10),
          clockIn: DateTime(2026, 7, 10, 8, 30),
          clockOut: DateTime(2026, 7, 10, 16, 30),
          worked: 480,
        ), // present
        rec(date: DateTime(2026, 7, 11), status: AttendanceStatus.absent),
        rec(date: DateTime(2026, 7, 12), status: AttendanceStatus.excused),
      ]);
      expect(withExcused.excusedCount, 1);
      expect(withExcused.presentCount, 1); // excused is not present
      expect(withExcused.absentCount, 1); // nor absent
      // Rate = present / (present + absent) = 1/2; the excused day doesn't drag it.
      expect(withExcused.attendancePercent, closeTo(50, 0.01));
    });

    test('empty input is safe (no divide-by-zero)', () {
      const s = AttendanceStats.empty;
      expect(s.attendancePercent, 0);
      expect(s.latePercent, 0);
      expect(s.avgWorkedMinutes, 0);
      expect(s.avgArrivalMinuteOfDay, isNull);
    });
  });

  group('grouping', () {
    final records = [
      rec(userId: 'u1', branchId: 'b1', date: DateTime(2026, 7, 10), worked: 480, clockOut: DateTime(2026, 7, 10, 16, 30)),
      rec(userId: 'u2', branchId: 'b1', date: DateTime(2026, 7, 10), status: AttendanceStatus.absent),
      rec(userId: 'u1', branchId: 'b2', date: DateTime(2026, 7, 11), worked: 300, clockOut: DateTime(2026, 7, 11, 13, 30)),
    ];

    test('byUser buckets per employee', () {
      final byUser = AttendanceStats.byUser(records);
      expect(byUser.keys.toSet(), {'u1', 'u2'});
      expect(byUser['u1']!.presentCount, 2);
      expect(byUser['u2']!.absentCount, 1);
    });

    test('byBranch buckets per branch', () {
      final byBranch = AttendanceStats.byBranch(records);
      expect(byBranch.keys.toSet(), {'b1', 'b2'});
      expect(byBranch['b1']!.presentCount, 1);
      expect(byBranch['b1']!.absentCount, 1);
    });
  });
}
