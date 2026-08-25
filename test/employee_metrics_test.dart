import 'package:flutter_test/flutter_test.dart';
import 'package:opshub/core/enums/task_status.dart';
import 'package:opshub/features/admin/presentation/employee_metrics.dart';
import 'package:opshub/features/task/domain/entities/task_entity.dart';

/// Pure-logic verification for the admin Employees page performance metrics —
/// derived from the task list (no Firebase needed).
void main() {
  final past = DateTime.now().subtract(const Duration(days: 1));
  final future = DateTime.now().add(const Duration(days: 1));

  group('computeEmployeeMetrics', () {
    test('buckets approved vs open tasks per assignee', () {
      final tasks = [
        const TaskEntity(
            id: '1', title: 'a', status: TaskStatus.approved, assigneeIds: ['u1']),
        const TaskEntity(
            id: '2', title: 'b', status: TaskStatus.approved, assigneeIds: ['u1']),
        const TaskEntity(
            id: '3', title: 'c', status: TaskStatus.started, assigneeIds: ['u1']),
        const TaskEntity(
            id: '4', title: 'd', status: TaskStatus.pending, assigneeIds: ['u2']),
      ];
      final m = computeEmployeeMetrics(tasks);
      expect(m['u1']!.completed, 2);
      expect(m['u1']!.pending, 1);
      expect(m['u1']!.total, 3);
      expect(m['u1']!.completionRatePct, 67); // 2/3 rounded
      expect(m['u2']!.completed, 0);
      expect(m['u2']!.pending, 1);
    });

    test('counts a task once per assignee (multi-assignee)', () {
      final tasks = [
        const TaskEntity(
            id: '1',
            title: 'a',
            status: TaskStatus.approved,
            assigneeIds: ['u1', 'u2']),
      ];
      final m = computeEmployeeMetrics(tasks);
      expect(m['u1']!.completed, 1);
      expect(m['u2']!.completed, 1);
    });

    test('flags an open task past its deadline as late', () {
      final tasks = [
        TaskEntity(
            id: '1',
            title: 'a',
            status: TaskStatus.started,
            deadline: past,
            assigneeIds: const ['u1']),
        TaskEntity(
            id: '2',
            title: 'b',
            status: TaskStatus.started,
            deadline: future,
            assigneeIds: const ['u1']),
      ];
      final m = computeEmployeeMetrics(tasks);
      expect(m['u1']!.late, 1);
    });

    test('flags an approved task submitted after the deadline as late', () {
      final tasks = [
        TaskEntity(
            id: '1',
            title: 'a',
            status: TaskStatus.approved,
            deadline: past,
            approvedAt: DateTime.now(),
            assigneeIds: const ['u1']),
      ];
      final m = computeEmployeeMetrics(tasks);
      expect(m['u1']!.late, 1);
      expect(m['u1']!.completed, 1);
    });

    test('an employee with no tasks is absent from the map', () {
      final m = computeEmployeeMetrics(const []);
      expect(m.containsKey('u1'), isFalse);
      const fallback = EmployeeMetrics();
      expect(fallback.completionRatePct, isNull);
      expect(fallback.hasData, isFalse);
    });
  });
}
