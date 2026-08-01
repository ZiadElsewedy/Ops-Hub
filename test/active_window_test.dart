import 'package:flutter_test/flutter_test.dart';
import 'package:drop/core/enums/task_status.dart';
import 'package:drop/features/task/domain/active_window.dart';
import 'package:drop/features/task/domain/entities/task_entity.dart';

/// Pure-logic verification of the employee home's "active operational window"
/// (the fix for approved tasks counting toward progress forever). `now` is
/// injected so the day boundary is deterministic.
void main() {
  final now = DateTime(2026, 6, 25, 14, 0);

  TaskEntity task(
    TaskStatus status, {
    DateTime? approvedAt,
    DateTime? startsAt,
  }) => TaskEntity(
    id: 't',
    title: 'T',
    status: status,
    approvedAt: approvedAt,
    startsAt: startsAt,
  );

  group('isTaskInActiveWindow', () {
    test('outstanding/in-flight statuses are always in the window', () {
      for (final s in [
        TaskStatus.pending,
        TaskStatus.started,
        TaskStatus.waitingReview,
        TaskStatus.completed,
        TaskStatus.rejected,
      ]) {
        expect(isTaskInActiveWindow(task(s), now), isTrue, reason: s.name);
      }
    });

    test('approved today is in the window (credit for this shift)', () {
      final approved = task(
        TaskStatus.approved,
        approvedAt: DateTime(2026, 6, 25, 9, 0),
      );
      expect(isTaskInActiveWindow(approved, now), isTrue);
    });

    test('approved on a previous day is excluded (historical)', () {
      final approved = task(
        TaskStatus.approved,
        approvedAt: DateTime(2026, 6, 24, 23, 59),
      );
      expect(isTaskInActiveWindow(approved, now), isFalse);
    });

    test('approved with no timestamp is excluded (legacy/unknown date)', () {
      expect(isTaskInActiveWindow(task(TaskStatus.approved), now), isFalse);
    });

    test('missed work is a closed record, never active work', () {
      expect(isTaskInActiveWindow(task(TaskStatus.missed), now), isFalse);
    });

    test('pending work stays visible before its scheduled start', () {
      expect(
        isTaskInActiveWindow(
          task(TaskStatus.pending, startsAt: now.add(const Duration(hours: 1))),
          now,
        ),
        isTrue,
      );
    });
  });

  group('activeWindowTasks', () {
    test('drops only stale approved tasks, keeps the rest', () {
      final tasks = [
        task(TaskStatus.pending),
        task(TaskStatus.started),
        task(TaskStatus.waitingReview),
        task(
          TaskStatus.approved,
          approvedAt: DateTime(2026, 6, 25, 8),
        ), // today
        task(TaskStatus.approved, approvedAt: DateTime(2026, 6, 20)), // old
        task(TaskStatus.approved), // no date
        task(TaskStatus.missed),
      ];
      expect(activeWindowTasks(tasks, now).length, 4);
    });
  });
}
