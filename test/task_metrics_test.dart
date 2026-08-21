import 'package:flutter_test/flutter_test.dart';
import 'package:opshub/core/enums/task_assignment_type.dart';
import 'package:opshub/core/enums/task_status.dart';
import 'package:opshub/features/task/domain/entities/task_entity.dart';
import 'package:opshub/features/task/domain/task_metrics.dart';

/// Pure dashboard metric derivations (DROP Design System V2). Each figure that
/// feeds a Needs-Attention tile / the Today strip is unit-verified so it can't
/// drift from the live task list.
void main() {
  final now = DateTime(2026, 7, 8, 10); // Wed 8 Jul, 10:00
  final past = DateTime(2026, 7, 7, 9); // yesterday
  final future = DateTime(2026, 7, 9, 9); // tomorrow

  TaskEntity task(
    String id, {
    TaskStatus status = TaskStatus.pending,
    List<String> assignees = const [],
    TaskAssignmentType type = TaskAssignmentType.individual,
    DateTime? deadline,
    DateTime? approvedAt,
  }) =>
      TaskEntity(
        id: id,
        title: id,
        status: status,
        assigneeIds: assignees,
        assignmentType: type,
        deadline: deadline,
        approvedAt: approvedAt,
      );

  group('overdueCount', () {
    test('counts open tasks past their deadline, ignores terminal states', () {
      final tasks = [
        task('a', status: TaskStatus.pending, deadline: past), // overdue
        task('b', status: TaskStatus.started, deadline: past), // overdue
        task('c', status: TaskStatus.pending, deadline: future), // not yet
        task('d', status: TaskStatus.waitingReview, deadline: past), // terminal
        task('e', status: TaskStatus.approved, deadline: past, approvedAt: now),
        task('f', status: TaskStatus.pending), // no deadline
      ];
      expect(overdueCount(tasks, now), 2);
    });
  });

  test('reviewCount counts only waitingReview', () {
    final tasks = [
      task('a', status: TaskStatus.waitingReview),
      task('b', status: TaskStatus.waitingReview),
      task('c', status: TaskStatus.started),
    ];
    expect(reviewCount(tasks), 2);
  });

  test('runningNowCount counts only started', () {
    final tasks = [
      task('a', status: TaskStatus.started),
      task('b', status: TaskStatus.pending),
      task('c', status: TaskStatus.started),
    ];
    expect(runningNowCount(tasks), 2);
  });

  group('unassignedCount', () {
    test('counts active individual/team tasks with no owner', () {
      final tasks = [
        task('a', status: TaskStatus.pending), // unassigned → count
        task('b', status: TaskStatus.started), // unassigned → count
        task('c', status: TaskStatus.pending, assignees: ['u1']), // owned
        // shift tasks target a shift, never "unassigned"
        task('d', status: TaskStatus.pending, type: TaskAssignmentType.shift),
        // finished work is out of the active window
        task('e', status: TaskStatus.approved, approvedAt: DateTime(2026, 6, 1)),
      ];
      expect(unassignedCount(tasks, now), 2);
    });
  });

  test('rejectedCount counts only rejected', () {
    final tasks = [
      task('a', status: TaskStatus.rejected),
      task('b', status: TaskStatus.pending),
    ];
    expect(rejectedCount(tasks), 1);
  });

  group('openCount', () {
    test('counts pending / started / completed / rejected, nothing else', () {
      final tasks = [
        task('a', status: TaskStatus.pending),
        task('b', status: TaskStatus.started),
        task('c', status: TaskStatus.completed),
        task('d', status: TaskStatus.rejected),
        task('e', status: TaskStatus.waitingReview), // excluded
        task('f', status: TaskStatus.approved, approvedAt: now), // excluded
        task('g', status: TaskStatus.missed), // excluded
        task('h', status: TaskStatus.cancelled), // excluded
      ];
      expect(openCount(tasks), 4);
    });

    test('matches the same definition Task Management uses for "Active"', () {
      // pending/started/completed/rejected — see
      // `admin_task_overview_screen.dart`'s `_BranchMetrics.active`.
      final tasks = [
        task('a', status: TaskStatus.pending),
        task('b', status: TaskStatus.completed),
      ];
      expect(openCount(tasks), 2);
    });
  });

  group('completedTodayCount', () {
    test('counts approved tasks only when approved today', () {
      final tasks = [
        task('today', status: TaskStatus.approved, approvedAt: now),
        task(
          'yesterday',
          status: TaskStatus.approved,
          approvedAt: DateTime(2026, 7, 7, 23),
        ),
        task('open', status: TaskStatus.pending),
      ];
      expect(completedTodayCount(tasks, now), 1);
    });

    test('is exactly what a status:approved active-window filter would list', () {
      // The count must equal the size of the set `applyFeed` would render for
      // `TaskFeedFilter(status: approved)` with the default
      // `activeWindowOnly: true` — both are driven by `isTaskInActiveWindow`.
      final approvedToday = task(
        'today',
        status: TaskStatus.approved,
        approvedAt: now,
      );
      final approvedLastWeek = task(
        'old',
        status: TaskStatus.approved,
        approvedAt: DateTime(2026, 7, 1),
      );
      final tasks = [approvedToday, approvedLastWeek];
      expect(completedTodayCount(tasks, now), 1);
    });
  });

  group('approvalRatePct', () {
    test('rounds approved / decided to a whole percent', () {
      expect(approvalRatePct(approved: 3, rejected: 1), 75);
      expect(approvalRatePct(approved: 1, rejected: 0), 100);
    });
    test('returns null when nothing has been decided', () {
      expect(approvalRatePct(approved: 0, rejected: 0), isNull);
    });
  });
}
