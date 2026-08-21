import 'package:opshub/core/enums/task_status.dart';
import 'package:opshub/features/task/domain/entities/task_entity.dart';

/// Whether [task] belongs to the employee's **current operational window** — the
/// set of work that should count toward "today's" progress on the home screen.
///
/// The home progress ring used to count *every* task the employee had ever been
/// assigned, so historically-approved work inflated the denominator forever
/// (the "Done 4 / 4" that never resets). The active window fixes that: it counts
/// outstanding work plus only *recently* finished work, so the number reflects
/// the current shift/day rather than the employee's entire history.
///
/// **Included**
///  - non-terminal work always (pending · started · waitingReview · completed);
///  - rejected / rework — still outstanding, regardless of age;
///  - approved **only when approved today** (the employee still sees credit for
///    work they finished this shift).
///
/// **Excluded**
///  - approved tasks from a previous day — historical / effectively archived.
///  - missed tasks — closed operational records, never active work.
///  - cancelled tasks — the business decided the work would not happen, so it
///    must never sit in a queue or count toward today's progress. Unlike an
///    approved task it earns **no** same-day credit: it was never done
///    (Automated Tasks spec §8 — cancelled is excluded from reporting entirely).
bool isTaskInActiveWindow(TaskEntity task, DateTime now) {
  switch (task.status) {
    case TaskStatus.pending:
    case TaskStatus.started:
    case TaskStatus.waitingReview:
    case TaskStatus.completed:
    case TaskStatus.rejected:
      return true;
    case TaskStatus.approved:
      final at = task.approvedAt;
      return at != null && _isSameDay(at, now);
    case TaskStatus.missed:
    case TaskStatus.cancelled:
      return false;
  }
}

/// The subset of [tasks] inside the active operational window — see
/// [isTaskInActiveWindow].
List<TaskEntity> activeWindowTasks(List<TaskEntity> tasks, DateTime now) => [
  for (final t in tasks)
    if (isTaskInActiveWindow(t, now)) t,
];

bool _isSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;
