import 'package:flutter_test/flutter_test.dart';
import 'package:opshub/core/enums/schedule_day.dart';
import 'package:opshub/core/enums/schedule_shift.dart';
import 'package:opshub/core/enums/task_assignment_type.dart';
import 'package:opshub/features/schedule/domain/entities/weekly_schedule_entity.dart';
import 'package:opshub/features/task/domain/entities/task_entity.dart';
import 'package:opshub/features/task/domain/task_access.dart';

/// Pure-logic verification of the Shift Assignment feature's visibility gate:
/// an individual/team task is unaffected (still keyed off `assigneeIds`); a
/// shift task is visible only to a uid actually rostered on its shift for
/// `now`'s schedule day.
void main() {
  final now = DateTime(2026, 6, 25, 14, 0); // a Thursday

  TaskEntity individualTask({List<String> assigneeIds = const []}) =>
      TaskEntity(id: 't', title: 'T', assigneeIds: assigneeIds);

  TaskEntity shiftTask({ScheduleShift? shift}) => TaskEntity(
        id: 't',
        title: 'T',
        assignmentType: TaskAssignmentType.shift,
        shift: shift ?? ScheduleShift.morning,
      );

  WeeklyScheduleEntity scheduleWith(String uid, ScheduleDay day, ScheduleShift shift) =>
      WeeklyScheduleEntity(
        id: 's',
        branchId: 'b',
        weekStart: DateTime(2026, 6, 21),
        assignments: {
          day: {shift: [uid]},
        },
      );

  group('canUserAccessTask — individual/team (unaffected)', () {
    test('assigned uid → true', () {
      expect(
        canUserAccessTask(
          task: individualTask(assigneeIds: const ['u1']),
          uid: 'u1',
          now: now,
        ),
        isTrue,
      );
    });

    test('unassigned uid → false, regardless of any schedule', () {
      final schedule = scheduleWith('u1', ScheduleDay.thursday, ScheduleShift.morning);
      expect(
        canUserAccessTask(
          task: individualTask(assigneeIds: const ['u1']),
          uid: 'u2',
          schedule: schedule,
          now: now,
        ),
        isFalse,
      );
    });
  });

  group('canUserAccessTask — shift', () {
    test('scheduled on the task\'s shift today → true', () {
      final schedule = scheduleWith('u1', ScheduleDay.thursday, ScheduleShift.morning);
      expect(
        canUserAccessTask(
          task: shiftTask(shift: ScheduleShift.morning),
          uid: 'u1',
          schedule: schedule,
          now: now,
        ),
        isTrue,
      );
    });

    test('scheduled on the other shift today → false', () {
      final schedule = scheduleWith('u1', ScheduleDay.thursday, ScheduleShift.night);
      expect(
        canUserAccessTask(
          task: shiftTask(shift: ScheduleShift.morning),
          uid: 'u1',
          schedule: schedule,
          now: now,
        ),
        isFalse,
      );
    });

    test('scheduled on the right shift but a different day → false', () {
      final schedule = scheduleWith('u1', ScheduleDay.friday, ScheduleShift.morning);
      expect(
        canUserAccessTask(
          task: shiftTask(shift: ScheduleShift.morning),
          uid: 'u1',
          schedule: schedule,
          now: now,
        ),
        isFalse,
      );
    });

    test('no schedule document → false', () {
      expect(
        canUserAccessTask(
          task: shiftTask(),
          uid: 'u1',
          now: now,
        ),
        isFalse,
      );
    });

    test('shift task with no shift set → false', () {
      final schedule = scheduleWith('u1', ScheduleDay.thursday, ScheduleShift.morning);
      final task = TaskEntity(
        id: 't',
        title: 'T',
        assignmentType: TaskAssignmentType.shift,
      );
      expect(
        canUserAccessTask(task: task, uid: 'u1', schedule: schedule, now: now),
        isFalse,
      );
    });
  });
}
