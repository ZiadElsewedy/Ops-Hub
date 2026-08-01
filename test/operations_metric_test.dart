import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drop/core/enums/task_status.dart';
import 'package:drop/features/operations/domain/branch_summary.dart';
import 'package:drop/features/operations/domain/branch_workload.dart';
import 'package:drop/features/operations/presentation/pages/branch_operations_screen.dart';
import 'package:drop/features/operations/presentation/pages/operations_metric_screen.dart';
import 'package:drop/features/task/domain/entities/task_entity.dart';

void main() {
  test('metric predicates stay mutually aligned with the KPI semantics', () {
    final now = DateTime(2026, 7, 5, 12);
    final overdue = TaskEntity(
      id: 'overdue',
      title: 'Open late',
      status: TaskStatus.started,
      deadline: now.subtract(const Duration(hours: 2)),
    );
    final review = TaskEntity(
      id: 'review',
      title: 'Review me',
      status: TaskStatus.waitingReview,
      deadline: now.subtract(const Duration(hours: 2)),
    );
    final missed = TaskEntity(
      id: 'missed',
      title: 'Missed window',
      status: TaskStatus.missed,
      deadline: now.subtract(const Duration(hours: 2)),
    );

    expect(isOperationalActiveTask(overdue), isTrue);
    expect(isOperationalOverdueTask(overdue, now), isTrue);
    expect(isOperationalPendingReviewTask(overdue), isFalse);

    expect(isOperationalActiveTask(review), isFalse);
    expect(
      isOperationalOverdueTask(review, now),
      isFalse,
      reason: 'a submitted task is no longer operationally overdue',
    );
    expect(isOperationalPendingReviewTask(review), isTrue);

    expect(isOperationalActiveTask(missed), isFalse);
    expect(
      isOperationalOverdueTask(missed, now),
      isFalse,
      reason: 'a missed task is closed, not overdue work',
    );
  });

  test('isOperationalFinishedLateTask finds the work isOperationalOverdueTask stops counting', () {
    final due = DateTime(2026, 7, 5, 16, 30);
    final finishedLate = TaskEntity(
      id: 'finished-late',
      title: 'Finished after the deadline',
      status: TaskStatus.approved,
      deadline: due,
      submittedAt: due.add(const Duration(minutes: 45)),
    );
    final finishedOnTime = TaskEntity(
      id: 'finished-on-time',
      title: 'Finished before the deadline',
      status: TaskStatus.approved,
      deadline: due,
      submittedAt: due.subtract(const Duration(minutes: 5)),
    );
    final missed = TaskEntity(
      id: 'missed',
      title: 'Missed window',
      status: TaskStatus.missed,
      deadline: due,
    );
    final activeOverdue = TaskEntity(
      id: 'active-overdue',
      title: 'Still open, past due',
      status: TaskStatus.started,
      deadline: due,
    );

    expect(
      isOperationalFinishedLateTask(finishedLate),
      isTrue,
      reason: 'the whole point — this is invisible to isOperationalOverdueTask'
          ' once submitted',
    );
    expect(isOperationalFinishedLateTask(finishedOnTime), isFalse);
    expect(
      isOperationalFinishedLateTask(missed),
      isFalse,
      reason: 'Missed is a separate outcome, never late',
    );
    expect(
      isOperationalFinishedLateTask(activeOverdue),
      isFalse,
      reason: 'still active work belongs to isOperationalOverdueTask, not this',
    );
  });

  testWidgets('all four KPI tiles are tappable metric entry points', (
    tester,
  ) async {
    final opened = <OperationsMetric>[];
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: OperationsSummaryHeader(
            summary: const BranchSummary(
              activeTasks: 8,
              overdueTasks: 3,
              pendingReviews: 2,
              staffActive: 6,
            ),
            onSelect: opened.add,
          ),
        ),
      ),
    );

    for (final entry in const <(String, OperationsMetric)>[
      ('Active tasks', OperationsMetric.activeTasks),
      ('Late', OperationsMetric.overdue),
      ('Pending review', OperationsMetric.pendingReview),
      ('Staff active', OperationsMetric.staffActive),
    ]) {
      await tester.tap(find.text(entry.$1));
      await tester.pump();
      expect(opened.last, entry.$2);
    }
  });

  test('each metric has distinct premium page copy', () {
    expect(
      OperationsMetric.values.map((metric) => metric.title).toSet().length,
      OperationsMetric.values.length,
    );
    expect(
      OperationsMetric.values.map((metric) => metric.eyebrow).toSet().length,
      OperationsMetric.values.length,
    );
  });
}
