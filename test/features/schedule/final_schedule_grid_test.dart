import 'package:flutter_test/flutter_test.dart';
import 'package:drop/core/enums/leave_type.dart';
import 'package:drop/core/enums/schedule_day.dart';
import 'package:drop/core/enums/schedule_shift.dart';
import 'package:drop/features/auth/domain/entities/user_entity.dart';
import 'package:drop/features/schedule/domain/entities/weekly_schedule_entity.dart';
import 'package:drop/features/schedule/domain/reporting/final_schedule_grid.dart';

UserEntity _emp(String uid, String name) => UserEntity(
      uid: uid,
      email: '$uid@drop.test',
      authProvider: 'password',
      displayName: name,
    );

WeeklyScheduleEntity _schedule({
  Map<ScheduleDay, Map<ScheduleShift, List<String>>> assignments = const {},
  Map<ScheduleDay, Map<String, LeaveType>> leave = const {},
}) =>
    WeeklyScheduleEntity(
      id: 'b1_2026-07-05',
      branchId: 'b1',
      weekStart: DateTime(2026, 7, 5),
      assignments: assignments,
      leave: leave,
    );

void main() {
  group('buildFinalScheduleGrid', () {
    final members = [
      _emp('u1', 'Salah Ahmed'),
      _emp('u2', 'Mona Adel'),
      _emp('u3', 'Karim Nabil'),
      _emp('u4', 'Never Scheduled'),
    ];

    final schedule = _schedule(
      assignments: {
        ScheduleDay.sunday: {
          ScheduleShift.morning: ['u1', 'u3'],
          ScheduleShift.night: ['u2'],
        },
        ScheduleDay.monday: {
          ScheduleShift.night: ['u1'],
        },
      },
      leave: {
        ScheduleDay.sunday: {'u2': LeaveType.annual}, // still works Sun night
        ScheduleDay.monday: {'u2': LeaveType.annual, 'u3': LeaveType.sick},
      },
    );

    test('has seven days, Sunday → Saturday', () {
      final grid = buildFinalScheduleGrid(schedule, members);
      expect(grid.days.length, 7);
      expect(grid.days.first.day, ScheduleDay.sunday);
      expect(grid.days.last.day, ScheduleDay.saturday);
    });

    test('counts only people actually on the schedule', () {
      final grid = buildFinalScheduleGrid(schedule, members);
      // u1, u2, u3 are scheduled somewhere; u4 never is.
      expect(grid.rosterCount, 3);
      expect(grid.isEmpty, isFalse);
    });

    test('names each shift cell, sorted alphabetically', () {
      final grid = buildFinalScheduleGrid(schedule, members);
      final sunday = grid.days[ScheduleDay.sunday.index];
      expect(sunday.morning, ['Karim Nabil', 'Salah Ahmed']); // sorted
      expect(sunday.night, ['Mona Adel']);
    });

    test('off row lists only explicitly off/on-leave people, tagging leave', () {
      final grid = buildFinalScheduleGrid(schedule, members);
      final monday = grid.days[ScheduleDay.monday.index];
      // Monday: u1 works night. u2 (annual) and u3 (sick) are explicitly off.
      final byName = {for (final p in monday.off) p.name: p};
      expect(byName.keys, containsAll(['Mona Adel', 'Karim Nabil']));
      expect(byName['Mona Adel']!.tag, 'V'); // annual → vacation
      expect(byName['Karim Nabil']!.tag, 'L'); // sick → leave
      // u1 is working Monday night → not in the off row.
      expect(byName.containsKey('Salah Ahmed'), isFalse);
      // u4 is not on the schedule at all → never appears.
      expect(byName.containsKey('Never Scheduled'), isFalse);
    });

    test('the off row never dumps every non-working member', () {
      final grid = buildFinalScheduleGrid(schedule, members);
      // Tuesday: nobody is assigned and nobody has a leave record. The Off row
      // must stay empty — it is not "everyone who happens not to work today".
      final tuesday = grid.days[ScheduleDay.tuesday.index];
      expect(tuesday.off, isEmpty);
      // u1 (rostered elsewhere) is simply idle Tuesday, with no leave → absent.
      expect(tuesday.off.map((p) => p.name), isNot(contains('Salah Ahmed')));
      // hasOff reflects that only Monday carries an off record.
      expect(grid.hasOff, isTrue);
    });

    test('an unscheduled member never appears anywhere', () {
      final grid = buildFinalScheduleGrid(schedule, members);
      for (final d in grid.days) {
        expect(d.morning, isNot(contains('Never Scheduled')));
        expect(d.night, isNot(contains('Never Scheduled')));
        expect(d.off.map((p) => p.name), isNot(contains('Never Scheduled')));
      }
    });

    test('empty schedule → empty grid', () {
      final grid = buildFinalScheduleGrid(_schedule(), members);
      expect(grid.isEmpty, isTrue);
      expect(grid.rosterCount, 0);
    });

    test('detects the later weekend night window', () {
      // Standard hours: weekday night 15:00–23:00, weekend night 16:00–00:00.
      final grid = buildFinalScheduleGrid(schedule, members);
      expect(grid.weekendNightDiffers, isTrue);
      expect(grid.nightHours.format(), '15:00 – 23:00');
      expect(grid.weekendNightHours.format(), '16:00 – 00:00');
    });
  });
}
