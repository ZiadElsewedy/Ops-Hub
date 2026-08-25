import 'package:flutter_test/flutter_test.dart';
import 'package:opshub/core/enums/schedule_day.dart';
import 'package:opshub/core/enums/schedule_shift.dart';
import 'package:opshub/core/enums/user_role.dart';
import 'package:opshub/features/auth/domain/entities/user_entity.dart';
import 'package:opshub/features/schedule/domain/entities/weekly_schedule_entity.dart';
import 'package:opshub/features/schedule/domain/shift_hours.dart';
import 'package:opshub/features/schedule/domain/today_roster.dart';

/// `todayRoster` — the pure join behind the "who is on shift today" peek
/// (added 2026-08-03, so tapping the coverage card answers *who is in* instead
/// of opening the weekly editor).
UserEntity _user(String uid, String name, {UserRole role = UserRole.employee}) =>
    UserEntity(
      uid: uid,
      email: '$uid@drop.test',
      authProvider: 'password',
      role: role,
      displayName: name,
      branchId: 'arkan',
    );

const _day = ScheduleDay.monday;

WeeklyScheduleEntity _schedule(
  Map<ScheduleShift, List<String>> monday, {
  Map<ScheduleDay, Map<ScheduleShift, ShiftHours>> hours = const {},
}) => WeeklyScheduleEntity(
  id: 'arkan_2026-08-03',
  branchId: 'arkan',
  weekStart: DateTime(2026, 8, 3),
  assignments: {_day: monday},
  shiftHours: hours,
);

void main() {
  final zoz = _user('u1', 'Zoz');
  final adam = _user('u2', 'Adam');
  final richard = _user('u3', 'Richard');
  final members = [zoz, adam, richard];

  test('groups people under the shift they are rostered on', () {
    final roster = todayRoster(
      schedule: _schedule({
        ScheduleShift.morning: ['u2'],
        ScheduleShift.night: ['u1', 'u3'],
      }),
      members: members,
      day: _day,
    );

    final morning = roster.shifts.firstWhere(
      (s) => s.shift == ScheduleShift.morning,
    );
    final night = roster.shifts.firstWhere(
      (s) => s.shift == ScheduleShift.night,
    );
    expect(morning.people.map((u) => u.displayName), ['Adam']);
    expect(night.people.map((u) => u.displayName), ['Richard', 'Zoz']);
    expect(roster.onShift, 3);
    expect(roster.teamSize, 3);
  });

  test('sorts each shift by display name, not assignment order', () {
    final roster = todayRoster(
      schedule: _schedule({
        ScheduleShift.morning: ['u3', 'u1', 'u2'],
      }),
      members: members,
      day: _day,
    );
    expect(
      roster.shifts.first.people.map((u) => u.displayName),
      ['Adam', 'Richard', 'Zoz'],
    );
  });

  test('someone on both shifts counts once in the headcount', () {
    final roster = todayRoster(
      schedule: _schedule({
        ScheduleShift.morning: ['u1'],
        ScheduleShift.night: ['u1'],
      }),
      members: members,
      day: _day,
    );
    // Drawn under both shifts — that is the operational truth — but one person.
    expect(roster.shifts.every((s) => s.people.length == 1), isTrue);
    expect(roster.onShift, 1);
  });

  test('an empty shift is reported, never omitted', () {
    final roster = todayRoster(
      schedule: _schedule({
        ScheduleShift.morning: ['u1'],
      }),
      members: members,
      day: _day,
    );
    // "Nobody is on nights" is the single most important thing this view can
    // say, so the shift must still be in the list.
    expect(roster.shifts, hasLength(ScheduleShift.values.length));
    final night = roster.shifts.firstWhere(
      (s) => s.shift == ScheduleShift.night,
    );
    expect(night.isEmpty, isTrue);
    expect(roster.isEmpty, isFalse);
  });

  test('an unpublished week reads as empty, not as an error', () {
    final roster = todayRoster(schedule: null, members: members, day: _day);
    expect(roster.isEmpty, isTrue);
    expect(roster.onShift, 0);
    expect(roster.teamSize, 3);
    // Hours still resolve, so the sheet can show the standing shift times.
    expect(roster.shifts.first.hours, ShiftHours.standard(_day, ScheduleShift.morning));
  });

  test('a rostered uid who left the branch is counted as unresolved', () {
    final roster = todayRoster(
      schedule: _schedule({
        ScheduleShift.morning: ['u1', 'ghost'],
      }),
      members: members,
      day: _day,
    );
    // Never silently dropped: this is the only reason the sheet's headcount
    // could disagree with a count derived straight from the assignment list.
    expect(roster.shifts.first.people.map((u) => u.uid), ['u1']);
    expect(roster.unresolved, 1);
  });

  test('per-slot hour overrides win over the standing default', () {
    final custom = ShiftHours.hm(10, 0, 18, 0);
    final roster = todayRoster(
      schedule: _schedule(
        {
          ScheduleShift.morning: ['u1'],
        },
        hours: {
          _day: {ScheduleShift.morning: custom},
        },
      ),
      members: members,
      day: _day,
    );
    expect(roster.shifts.first.hours, custom);
  });
}
