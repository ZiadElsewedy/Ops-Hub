import 'package:flutter_test/flutter_test.dart';
import 'package:opshub/core/enums/schedule_day.dart';
import 'package:opshub/core/enums/schedule_shift.dart';
import 'package:opshub/core/enums/task_status.dart';
import 'package:opshub/features/auth/domain/entities/user_entity.dart';
import 'package:opshub/features/operations/domain/branch_workload.dart';
import 'package:opshub/features/operations/domain/employee_workload.dart';
import 'package:opshub/features/operations/domain/shift_filter.dart';
import 'package:opshub/features/schedule/domain/entities/weekly_schedule_entity.dart';
import 'package:opshub/features/task/domain/entities/task_entity.dart';

/// Pure-logic verification for the Branch Operations aggregation — derived from
/// the task stream joined with today's roster (no Firebase). `day` + `now` are
/// injected so the join is deterministic regardless of the wall clock.
void main() {
  final now = DateTime(2026, 6, 14, 12); // clock for overdue / completed-today
  final past = now.subtract(const Duration(days: 1));
  final future = now.add(const Duration(days: 1));

  UserEntity user(String uid, String name) =>
      UserEntity(uid: uid, email: '$uid@x.com', authProvider: 'password', displayName: name);

  final u1 = user('u1', 'Ahmed');
  final u2 = user('u2', 'Sara');
  final u3 = user('u3', 'Nabil');
  final u4 = user('u4', 'Omar'); // off today

  final schedule = WeeklyScheduleEntity(
    id: 'b_2026-06-14',
    branchId: 'b',
    weekStart: DateTime(2026, 6, 14),
    assignments: const {
      ScheduleDay.sunday: {
        ScheduleShift.morning: ['u1', 'u2'],
        ScheduleShift.night: ['u3'],
      },
    },
  );

  // t1 morning/started/overdue · t2 any/pending · t3 morning/in-review ·
  // t4 morning/approved-today · t5 night/started(no deadline) · t6 night/overdue
  final t1 = TaskEntity(
      id: 't1', title: 'open', status: TaskStatus.started,
      assigneeIds: const ['u1'], shift: ScheduleShift.morning, deadline: past);
  final t2 = TaskEntity(
      id: 't2', title: 'restock', status: TaskStatus.pending,
      assigneeIds: const ['u1'], deadline: future); // shift == null → "any"
  final t3 = TaskEntity(
      id: 't3', title: 'count', status: TaskStatus.waitingReview,
      assigneeIds: const ['u1'], shift: ScheduleShift.morning);
  final t4 = TaskEntity(
      id: 't4', title: 'clean', status: TaskStatus.approved,
      assigneeIds: const ['u1'], shift: ScheduleShift.morning, approvedAt: now);
  final t5 = TaskEntity(
      id: 't5', title: 'night a', status: TaskStatus.started,
      assigneeIds: const ['u2'], shift: ScheduleShift.night);
  final t6 = TaskEntity(
      id: 't6', title: 'lock', status: TaskStatus.started,
      assigneeIds: const ['u3'], shift: ScheduleShift.night, deadline: past);

  final allTasks = [t1, t2, t3, t4, t5, t6];

  BranchWorkload run(ShiftFilter filter, {List<UserEntity>? employees}) =>
      computeBranchWorkload(
        employees: employees ?? [u1, u2, u3, u4],
        tasks: allTasks,
        schedule: schedule,
        filter: filter,
        day: ScheduleDay.sunday,
        now: now,
      );

  EmployeeWorkloadFinder by(BranchWorkload w) => EmployeeWorkloadFinder(w);

  group('computeBranchWorkload — all lens', () {
    test('buckets per-employee counts and the branch summary', () {
      final w = run(ShiftFilter.all);
      expect(w.summary.activeTasks, 4); // t1,t2,t5,t6
      expect(w.summary.overdueTasks, 2); // t1,t6
      expect(w.summary.pendingReviews, 1); // t3
      expect(w.summary.staffActive, 3); // u1,u2,u3 rostered (u4 off)

      final a = by(w)['u1'];
      expect(a.active, 2); // t1,t2
      expect(a.overdue, 1); // t1
      expect(a.submitted, 1); // t3
      expect(a.completedToday, 1); // t4
      expect(a.currentTask?.id, 't1');
      expect(a.needsAttention, isTrue);
    });

    test('sorts overload-first (overdue, then active, then name)', () {
      final w = run(ShiftFilter.all);
      expect(w.employees.map((e) => e.user.uid).toList(),
          ['u1', 'u3', 'u2', 'u4']);
    });

    test('an off employee with no tasks is idle and not counted as staff', () {
      final w = run(ShiftFilter.all);
      final o = by(w)['u4'];
      expect(o.isIdle, isTrue);
      expect(o.isScheduledToday, isFalse);
      expect(o.currentTask, isNull);
    });
  });

  group('computeBranchWorkload — shift lens', () {
    test('morning hides night employees and night tasks', () {
      final w = run(ShiftFilter.morning);
      expect(w.employees.map((e) => e.user.uid).toList(), ['u1', 'u2']);
      expect(by(w)['u2'].active, 0); // t5 is a night task → hidden
      expect(by(w)['u2'].currentTask, isNull);
      expect(w.summary.activeTasks, 2); // t1,t2 only
      expect(w.summary.staffActive, 2);
    });

    test('a specific shift still counts "any"-shift tasks in the summary', () {
      final w = run(ShiftFilter.night);
      expect(w.employees.map((e) => e.user.uid).toList(), ['u3']);
      // night-visible active tasks: t2 (any) + t5 + t6
      expect(w.summary.activeTasks, 3);
      expect(w.summary.overdueTasks, 1); // t6
      expect(by(w)['u3'].overdue, 1);
    });
  });

  group('computeBranchWorkload — edge cases', () {
    test('currentTask prefers a started task over a pending one', () {
      final w = run(ShiftFilter.all);
      expect(by(w)['u1'].currentTask?.status, TaskStatus.started);
    });

    test('completedToday counts only tasks approved today', () {
      final tasks = [
        TaskEntity(id: 'a', title: 'x', status: TaskStatus.approved,
            assigneeIds: const ['u1'], approvedAt: now),
        TaskEntity(id: 'b', title: 'y', status: TaskStatus.approved,
            assigneeIds: const ['u1'], approvedAt: past),
      ];
      final w = computeBranchWorkload(
          employees: [u1], tasks: tasks, schedule: schedule,
          day: ScheduleDay.sunday, now: now);
      expect(w.employees.single.completedToday, 1);
    });

    test('with no schedule, the all lens still derives counts', () {
      final w = computeBranchWorkload(
          employees: [u1], tasks: allTasks, day: ScheduleDay.sunday, now: now);
      expect(by(w)['u1'].active, 2);
      expect(w.summary.staffActive, 0); // nobody rostered without a schedule
    });
  });
}

/// Tiny lookup helper so tests read `by(w)['u1'].active`.
class EmployeeWorkloadFinder {
  EmployeeWorkloadFinder(this.workload);
  final BranchWorkload workload;
  EmployeeWorkload operator [](String uid) =>
      workload.employees.firstWhere((e) => e.user.uid == uid);
}
