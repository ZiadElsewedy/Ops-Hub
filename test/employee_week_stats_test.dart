import 'package:flutter_test/flutter_test.dart';
import 'package:opshub/core/enums/schedule_day.dart';
import 'package:opshub/core/enums/schedule_shift.dart';
import 'package:opshub/features/schedule/domain/employee_week_stats.dart';
import 'package:opshub/features/schedule/domain/entities/weekly_schedule_entity.dart';

WeeklyScheduleEntity _sched(
  Map<ScheduleDay, Map<ScheduleShift, List<String>>> assignments,
) =>
    WeeklyScheduleEntity(
      id: 'b1_2026-06-14',
      branchId: 'b1',
      weekStart: DateTime(2026, 6, 14),
      assignments: assignments,
    );

void main() {
  group('computeEmployeeWeekStats', () {
    test('counts days worked, weekend days, hours and the longest run', () {
      // Sun–Tue mornings (08:30–16:30 = 8h each), Thu+Sat nights. Thu & Sat are
      // weekend days (Thu/Fri/Sat); their nights run 16:30→00:30 = 8h.
      final stats = computeEmployeeWeekStats(
        _sched({
          ScheduleDay.sunday: {ScheduleShift.morning: ['u1']},
          ScheduleDay.monday: {ScheduleShift.morning: ['u1']},
          ScheduleDay.tuesday: {ScheduleShift.morning: ['u1']},
          // Wednesday off — breaks the run
          ScheduleDay.thursday: {ScheduleShift.night: ['u1']},
          ScheduleDay.saturday: {ScheduleShift.night: ['u1']},
        }),
        'u1',
      );

      expect(stats.workedDays, 5);
      expect(stats.weekendCount, 2); // Thu + Sat
      expect(stats.longestRun, 3); // Sun·Mon·Tue
      // 3×8h mornings + 2×8h weekend nights = 40h.
      expect(stats.totalMinutes, 40 * 60);
      expect(stats.hoursLabel, '40h');
      expect(stats.offDays, contains(ScheduleDay.wednesday));
      expect(stats.offDays, contains(ScheduleDay.friday));
    });

    test('a weekday night is 8h and shows a whole-hour label', () {
      // Monday is a weekday → night 15:00–23:00 = 8h.
      final stats = computeEmployeeWeekStats(
        _sched({
          ScheduleDay.monday: {ScheduleShift.night: ['u1']},
        }),
        'u1',
      );

      expect(stats.workedDays, 1);
      expect(stats.weekendCount, 0);
      expect(stats.totalMinutes, 8 * 60);
      expect(stats.hoursLabel, '8h');
    });

    test('an unscheduled person is empty, all seven days off', () {
      final stats = computeEmployeeWeekStats(_sched(const {}), 'ghost');
      expect(stats.isEmpty, isTrue);
      expect(stats.workedDays, 0);
      expect(stats.offDays, hasLength(7));
      expect(stats.totalMinutes, 0);
    });
  });
}
