/// Pure task-metric derivations for the dashboard "Needs Attention" tiles and
/// the "Today" stat strip (OpsHub Design System V2). No Flutter, no Firestore — it
/// derives the operational counts straight from the already-in-memory
/// `TaskCubit` stream (zero new reads), so each figure is unit-testable and
/// cannot drift from the live task list. Reuses the canonical predicates in
/// [isTaskOverdue] / [isTaskInActiveWindow] so a task counts the same way here as
/// it does in the feed.
library;

import 'package:opshub/core/enums/task_assignment_type.dart';
import 'package:opshub/core/enums/task_status.dart';
import 'package:opshub/features/task/domain/active_window.dart';
import 'package:opshub/features/task/domain/entities/task_entity.dart';
import 'package:opshub/features/task/domain/task_feed.dart';

/// Open tasks (pending / started / rejected) past their deadline — the shared
/// "overdue" definition (terminal states are never overdue).
int overdueCount(List<TaskEntity> tasks, DateTime now) =>
    tasks.where((t) => isTaskOverdue(t, now)).length;

/// Tasks submitted and awaiting a manager/admin review decision.
int reviewCount(List<TaskEntity> tasks) =>
    tasks.where((t) => t.status == TaskStatus.waitingReview).length;

/// Tasks an employee is actively executing right now.
int runningNowCount(List<TaskEntity> tasks) =>
    tasks.where((t) => t.status == TaskStatus.started).length;

/// All outstanding work, whatever stage — pending / started / completed /
/// rejected. The same definition the Task Management stat row uses for
/// "Active", so the two screens can never disagree on "how much is on the
/// table" (2026-08-01 — the dashboard's "Today" strip had no such number at
/// all, which is why `runningNowCount` alone was misread as it).
int openCount(List<TaskEntity> tasks) => tasks.where((t) {
  switch (t.status) {
    case TaskStatus.pending:
    case TaskStatus.started:
    case TaskStatus.completed:
    case TaskStatus.rejected:
      return true;
    case TaskStatus.waitingReview:
    case TaskStatus.approved:
    case TaskStatus.missed:
    case TaskStatus.cancelled:
      return false;
  }
}).length;

/// Tasks approved **today** — deliberately reuses [isTaskInActiveWindow]
/// rather than re-deriving "same day" locally: that predicate is exactly
/// what [applyFeed] runs when a caller filters `status: approved` with its
/// default `activeWindowOnly: true`, so this count and that drill-down's list
/// can never disagree (2026-08-01 — the dashboard used to read this from
/// `StatisticsCubit`'s lifetime-scoped `completedTasksToday`, a different data
/// source from the task stream any drill-down would have rendered).
int completedTodayCount(List<TaskEntity> tasks, DateTime now) => tasks
    .where(
      (t) => t.status == TaskStatus.approved && isTaskInActiveWindow(t, now),
    )
    .length;

/// Active individual/team tasks with **no owner** — they can't progress until
/// someone is assigned. Shift tasks target a shift (never "unassigned"), and
/// already-finished work is excluded via the active window.
int unassignedCount(List<TaskEntity> tasks, DateTime now) => tasks
    .where((t) =>
        isTaskInActiveWindow(t, now) &&
        t.assignmentType != TaskAssignmentType.shift &&
        t.assigneeIds.isEmpty &&
        t.status != TaskStatus.approved)
    .length;

/// Tasks sent back to the employee (rejected / rework) and still outstanding.
int rejectedCount(List<TaskEntity> tasks) =>
    tasks.where((t) => t.status == TaskStatus.rejected).length;

/// Approval rate as a whole-number percentage (0–100) over decided work, or
/// `null` when nothing has been decided yet (so the UI can show "—" instead of a
/// misleading 0%). [approved] + [rejected] is the decided total.
int? approvalRatePct({required int approved, required int rejected}) {
  final decided = approved + rejected;
  if (decided <= 0) return null;
  return ((approved / decided) * 100).round();
}
