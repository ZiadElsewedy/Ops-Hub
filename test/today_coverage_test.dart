import 'package:flutter_test/flutter_test.dart';
import 'package:drop/core/enums/schedule_day.dart';
import 'package:drop/core/enums/schedule_shift.dart';
import 'package:drop/core/enums/user_role.dart';
import 'package:drop/features/auth/domain/entities/user_entity.dart';
import 'package:drop/features/branch/domain/entities/branch_entity.dart';
import 'package:drop/features/schedule/domain/entities/weekly_schedule_entity.dart';
import 'package:drop/features/schedule/domain/today_coverage.dart';
import 'package:drop/features/schedule/domain/today_roster.dart';

const _day = ScheduleDay.monday;

UserEntity _member(String id) => UserEntity(
  uid: id,
  email: '$id@drop.test',
  authProvider: 'password',
  role: UserRole.employee,
  branchId: 'branch',
);

TodayCoverage _coverage(
  String name, {
  WeeklyScheduleEntity? schedule,
  List<UserEntity> members = const [],
}) {
  final branch = BranchEntity(id: name.toLowerCase(), name: name);
  return TodayCoverage(
    branch: branch,
    schedule: schedule,
    roster: todayRoster(schedule: schedule, members: members, day: _day),
  );
}

WeeklyScheduleEntity _schedule(Map<ScheduleShift, List<String>> assignments) =>
    WeeklyScheduleEntity(
      id: 'branch_2026-08-02',
      branchId: 'branch',
      weekStart: DateTime(2026, 8, 2),
      assignments: {_day: assignments},
    );

void main() {
  test('empty night shifts sort ahead of fully covered branches', () {
    final member = _member('u1');
    final covered = _coverage(
      'Zamalek',
      members: [member],
      schedule: _schedule({
        ScheduleShift.morning: ['u1'],
        ScheduleShift.night: ['u1'],
      }),
    );
    final uncovered = _coverage(
      'Arkan',
      members: [member],
      schedule: _schedule({ScheduleShift.morning: ['u1']}),
    );

    expect(orderTodayCoverage([covered, uncovered]).first.branch.name, 'Arkan');
    expect(uncovered.hasUncoveredShift, isTrue);
  });

  test('a week with no schedule is not fully covered or an uncovered shift', () {
    final row = _coverage('New Cairo', members: [_member('u1')]);

    expect(row.hasSchedule, isFalse);
    expect(row.hasUncoveredShift, isFalse);
    expect(row.isFullyCovered, isFalse);
    expect(fullyCoveredBranches([row]), 0);
  });
}
