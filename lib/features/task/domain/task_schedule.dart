/// Task Scheduling V2 — the **derived, time-aware phase** of a task. Pure Dart
/// (no Flutter/Firestore): computed from `startsAt` / `dueAt` + the lifecycle
/// status, so it's unit-testable and can't drift from the data.
///
/// It is **not** a persisted status and does not replace `TaskStatus`. The
/// phase remains orthogonal to lifecycle: a `pending` task whose window is
/// *now* reads [TaskSchedulePhase.active] (it should be running but nobody
/// started it), while a terminal `missed` task reads [TaskSchedulePhase.done].
/// That is exactly the operational distinction a manager needs.
library;

import 'package:opshub/core/enums/schedule_day.dart';
import 'package:opshub/core/enums/schedule_shift.dart';
import 'package:opshub/core/enums/task_status.dart';
import 'package:opshub/core/utils/app_date_formatter.dart';
import 'package:opshub/features/schedule/domain/shift_hours.dart';
// `cairoCivilTime` is a general Africa/Cairo business-time helper (it happens to
// live under the sales feature); reused here so the shift-window DST rule is not
// duplicated. See `shiftDefaultSchedule`.
import 'package:opshub/features/sales/domain/sales_business_time.dart';
import 'package:opshub/features/task/domain/entities/task_entity.dart';
import 'package:opshub/features/task/domain/task_feed.dart' show isTaskOverdue;

/// The time-aware operational phase, derived per [schedulePhase].
enum TaskSchedulePhase { scheduled, active, dueSoon, overdue, done }

extension TaskSchedulePhaseX on TaskSchedulePhase {
  String get label => switch (this) {
    TaskSchedulePhase.scheduled => 'Scheduled',
    TaskSchedulePhase.active => 'Active',
    TaskSchedulePhase.dueSoon => 'Due soon',
    TaskSchedulePhase.overdue => 'Late',
    TaskSchedulePhase.done => 'Done',
  };

  /// A time-phase chip only makes sense for **in-flight** work; a finished task
  /// tells its story through the lifecycle status pill instead.
  bool get isActionable => this != TaskSchedulePhase.done;
}

/// The window (before [TaskEntity.dueAt]) within which a task reads "due soon".
const Duration kDueSoonWindow = Duration(minutes: 30);

/// The grace period between a generated shift task's deadline and the moment the
/// server may record it as **Missed** — a fixed, global 30 minutes
/// ([ADR-013](../../../../docs/decisions/ADR-013-task-grace-period.md)).
///
/// **This is a tolerance on the close, not a deadline.** It must never be added
/// to `dueAt`, fed into [schedulePhase], or used to delay the Overdue/Late
/// reading: a task is Late from its deadline (spec §3.1) and the employee should
/// feel that immediately — they are simply not *recorded as failed* until the
/// grace expires. The only legitimate client use is telling a manager when a
/// task will close.
///
/// Mirrors `TASK_GRACE_MINUTES` in `functions/recurring_task_deadline.js`, which
/// is the enforcing copy. Not configurable, by decision — a per-branch grace
/// would be a dial on the headline completion rate held by the person that rate
/// evaluates.
const Duration kTaskGracePeriod = Duration(minutes: 30);

/// When [t] becomes eligible to be recorded as Missed — its deadline plus
/// [kTaskGracePeriod]. Null when the task has no deadline. Read-only insight for
/// the UI; the server decides.
DateTime? missedEvaluationAt(TaskEntity t) {
  final due = t.dueAt;
  return due?.add(kTaskGracePeriod);
}

/// Whether [task] may transition into `started` at [now].
///
/// The start gate
/// ([ADR-016](../../../../docs/decisions/ADR-016-task-start-gate.md)): a task is
/// **visible when upcoming, startable only from [TaskEntity.startsAt]**.
///
/// This is a **scheduling** gate only, orthogonal to [TaskStatus], and it is
/// keyed on the *destination* status — so every transition into `started` is
/// blocked before `startsAt`, **rework included, with no exceptions**. A null
/// `startsAt` remains startable for legacy and manually-created rows, and the
/// boundary is inclusive. `firestore.rules` re-checks the same boundary against
/// server time; the two must never disagree.
bool canStartTaskNow(TaskEntity task, DateTime now) {
  final start = task.startsAt;
  return start == null || !now.isBefore(start);
}

/// Human explanation for a closed [canStartTaskNow] gate, or null when the task
/// is startable. Kept in the scheduling domain so every caller uses the same
/// wording and the same DateTime formatter.
///
/// 24-hour by deliberate choice ([AppDateFormatter.time24]): this sits beside a
/// shift window rendered as `08:30 – 16:30`, and mixing clock formats on one
/// screen reads as a bug.
String? startBlockedReason(TaskEntity task, DateTime now) {
  if (canStartTaskNow(task, now)) return null;
  return 'Starts at ${AppDateFormatter.time24(task.startsAt!)}';
}

/// The derived phase of [t] at [now]. Ordering:
/// terminal (approved/completed/submitted/missed) → [done]; else overdue
/// ([isTaskOverdue]) → [overdue]; else due within [dueSoonWindow] → [dueSoon];
/// else `now < startsAt` → [scheduled]; else [active]. Missing timestamps degrade
/// gracefully (no due → never overdue/due-soon; no start → never scheduled).
TaskSchedulePhase schedulePhase(
  TaskEntity t,
  DateTime now, {
  Duration dueSoonWindow = kDueSoonWindow,
}) {
  // The doer is finished — the lifecycle badge carries it from here.
  final s = t.status;
  if (s.isTerminal ||
      s == TaskStatus.completed ||
      s == TaskStatus.waitingReview) {
    return TaskSchedulePhase.done;
  }
  if (isTaskOverdue(t, now)) return TaskSchedulePhase.overdue;
  final due = t.dueAt;
  if (due != null &&
      !now.isAfter(due) &&
      due.difference(now) <= dueSoonWindow) {
    return TaskSchedulePhase.dueSoon;
  }
  final start = t.startsAt;
  if (start != null && now.isBefore(start)) return TaskSchedulePhase.scheduled;
  return TaskSchedulePhase.active;
}

/// The **smart-default** schedule window for a task on [date] in [shift] — the
/// suggestion the create form pre-fills (and the manager can override). Uses the
/// standing [ShiftHours.standard] baseline unless a resolved [hours] is passed;
/// overnight ends (endMinutes > 1440) roll into the next day automatically.
({DateTime start, DateTime due}) shiftDefaultSchedule(
  DateTime date,
  ScheduleShift shift, {
  ShiftHours? hours,
}) {
  final h = hours ?? ShiftHours.standard(ScheduleDay.fromDate(date), shift);
  // Anchor the window to Africa/Cairo wall-clock, not the DEVICE timezone. The
  // old `DateTime(y,m,d).add(minutes)` built the shift at the device's local
  // midnight, so a phone in another timezone stored 08:30 *device-local*
  // instead of 08:30 Cairo — a wrong deadline that then drives the reminder
  // ladder. The Cairo UTC offset (2 or 3, with DST) is derived from the shared
  // `cairoCivilTime` rule via a noon probe, so the DST logic lives in exactly
  // one place. On a Cairo device the result is byte-for-byte the old value.
  final probe = DateTime.utc(date.year, date.month, date.day, 12);
  final cairoOffset = cairoCivilTime(probe).difference(probe);
  final cairoMidnightUtc =
      DateTime.utc(date.year, date.month, date.day).subtract(cairoOffset);
  return (
    start: cairoMidnightUtc.add(Duration(minutes: h.startMinutes)).toLocal(),
    due: cairoMidnightUtc.add(Duration(minutes: h.endMinutes)).toLocal(),
  );
}

/// Count of in-flight tasks whose due time is within [window] (the dashboard's
/// "Due soon" figure).
int dueSoonCount(
  List<TaskEntity> tasks,
  DateTime now, {
  Duration window = kDueSoonWindow,
}) => tasks
    .where(
      (t) =>
          schedulePhase(t, now, dueSoonWindow: window) ==
          TaskSchedulePhase.dueSoon,
    )
    .length;

/// How well a set of assignees' rostered shifts agree — drives the create form's
/// smart default beyond explicit shift assignment (Scheduling V2 refinement).
enum AssigneeShiftFit { none, unanimous, mixed }

/// Given each assignee's rostered shift(s) for the target day, decide the smart
/// default: [unanimous] (everyone shares one shift → suggest it), [mixed]
/// (people on different shifts → ask the user to choose), or [none] (nobody
/// rostered → manual). Pure so it's testable without the schedule repository.
({AssigneeShiftFit fit, ScheduleShift? shift}) assigneeShiftFit(
  Iterable<List<ScheduleShift>> perAssigneeShifts,
) {
  final all = <ScheduleShift>{};
  var anyRostered = false;
  for (final shifts in perAssigneeShifts) {
    if (shifts.isNotEmpty) anyRostered = true;
    all.addAll(shifts);
  }
  if (!anyRostered) return (fit: AssigneeShiftFit.none, shift: null);
  if (all.length == 1) {
    return (fit: AssigneeShiftFit.unanimous, shift: all.first);
  }
  return (fit: AssigneeShiftFit.mixed, shift: null);
}

/// The scheduled window length (`dueAt − startsAt`), or null when either end is
/// unset. Naturally spans midnight (instant subtraction), so an overnight task
/// yields a correct positive duration.
Duration? scheduledDuration(TaskEntity t) {
  final s = t.startsAt, d = t.dueAt;
  if (s == null || d == null) return null;
  return d.difference(s);
}

/// A compact human duration — "8h 30m" / "8h" / "45m"; empty for a non-positive
/// span. Informational (the schedule section + Task Details) and the basis of
/// future duration analytics (expected `dueAt−startsAt` vs actual).
String formatScheduleDuration(Duration d) {
  if (d.inMinutes <= 0) return '';
  final h = d.inHours;
  final m = d.inMinutes % 60;
  if (h > 0 && m > 0) return '${h}h ${m}m';
  if (h > 0) return '${h}h';
  return '${m}m';
}
