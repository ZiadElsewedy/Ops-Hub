import 'package:opshub/core/enums/task_status.dart';
import 'package:opshub/features/task/domain/entities/task_entity.dart';

/// Per-employee task performance, derived from the admin's live task stream — no
/// new backend query or schema. Counts every task the employee is assigned to.
class EmployeeMetrics {
  const EmployeeMetrics({
    this.completed = 0,
    this.pending = 0,
    this.late = 0,
  });

  /// Approved tasks.
  final int completed;

  /// Open tasks (pending / started / completed / waiting review / needs rework).
  final int pending;

  /// Tasks closed after their deadline, or still open past their deadline.
  final int late;

  int get total => completed + pending;

  /// 0–100 completion rate, or null when the employee has no tasks yet.
  int? get completionRatePct =>
      total == 0 ? null : ((completed / total) * 100).round();

  bool get hasData => total > 0;
}

/// Builds a `uid → EmployeeMetrics` map from a task list. A uid that owns no
/// tasks is simply absent (callers fall back to `const EmployeeMetrics()`).
Map<String, EmployeeMetrics> computeEmployeeMetrics(List<TaskEntity> tasks) {
  final completed = <String, int>{};
  final pending = <String, int>{};
  final late = <String, int>{};
  final now = DateTime.now();

  for (final t in tasks) {
    final isDone = t.status == TaskStatus.approved;
    final isOpen = t.status == TaskStatus.pending ||
        t.status == TaskStatus.started ||
        t.status == TaskStatus.completed ||
        t.status == TaskStatus.waitingReview ||
        t.status == TaskStatus.rejected;

    var isLate = false;
    final deadline = t.deadline;
    if (deadline != null) {
      if (isDone) {
        final closedAt = t.approvedAt ?? t.submittedAt;
        isLate = closedAt != null && closedAt.isAfter(deadline);
      } else if (isOpen) {
        isLate = deadline.isBefore(now);
      }
    }

    for (final uid in t.assigneeIds) {
      if (isDone) completed[uid] = (completed[uid] ?? 0) + 1;
      if (isOpen) pending[uid] = (pending[uid] ?? 0) + 1;
      if (isLate) late[uid] = (late[uid] ?? 0) + 1;
    }
  }

  final uids = {...completed.keys, ...pending.keys, ...late.keys};
  return {
    for (final uid in uids)
      uid: EmployeeMetrics(
        completed: completed[uid] ?? 0,
        pending: pending[uid] ?? 0,
        late: late[uid] ?? 0,
      ),
  };
}
