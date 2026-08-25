/// The **four-way outcome classification** — the reporting contract frozen in
/// `docs/design/AUTOMATED_TASKS_PRODUCT_SPEC.md` §8 and §10.
///
/// Pure Dart (no Flutter, no Firestore): derived from the already-in-memory
/// `TaskCubit` stream, so every figure is unit-testable, costs zero extra reads,
/// and cannot drift from the live task list.
///
/// ## The four categories are independent and never merge
///
/// | Category | Scored as | In the completion rate? |
/// |---|---|---|
/// | **Approved** | success | yes — numerator **and** denominator |
/// | **Missed** | failure | denominator only |
/// | **Cancelled** | neither | **excluded entirely** |
/// | **Late** | timeliness signal, not an outcome | never |
///
/// **Hard invariant (§8):** "incomplete = Missed + Cancelled" is forbidden
/// anywhere in the product. There is deliberately no field, getter or helper in
/// this file that sums those two — the moment such a number exists, someone
/// renders it, and the distinction this whole spec protects is destroyed. A
/// cancellation is a decision that work would not happen; a miss is work the
/// branch owed and did not do. Adding them together says neither.
///
/// This module is **derivation only** — no analytics pipeline, no time series,
/// no stored aggregates ([ADR-009](../../../../docs/decisions/ADR-009-no-analytics-pipeline.md),
/// spec §13).
library;

import 'package:opshub/core/enums/task_cancel_reason.dart';
import 'package:opshub/core/enums/task_status.dart';
import 'package:opshub/features/task/domain/entities/task_entity.dart';

/// A branch's (or the estate's) task outcomes over some set of tasks.
///
/// Construct with [taskOutcomes]; every figure is a plain count so the shape
/// stays inspectable in a test failure.
class TaskOutcomes {
  const TaskOutcomes({
    this.approved = 0,
    this.missed = 0,
    this.cancelled = 0,
    this.open = 0,
    this.cancelledByReason = const {},
    this.completedOnTime = 0,
    this.completedLate = 0,
    this.totalLatenessMinutes = 0,
  });

  /// Work accepted on review — the success signal.
  final int approved;

  /// Work the shift window closed on, unfinished, after the grace period
  /// ([ADR-013](../../../../docs/decisions/ADR-013-task-grace-period.md)) — the
  /// real failure signal, and the reason it is now safe to score.
  final int missed;

  /// Work management decided would not be done. Counted here **only** so it can
  /// be reported on its own line (§8); it never reaches [completionRate].
  final int cancelled;

  /// Still live — neither closed nor cancelled. Not an outcome; exposed so a
  /// caller can say "12 of 40 still open" without recomputing.
  final int open;

  /// Cancellation volume broken down by reason code — the **secondary KPI**
  /// (§10.3). Each individual cancel is legitimate; a *cluster* is the smell.
  /// Repeated `noLongerNeeded` means a routine that should be paused; repeated
  /// `wrongTaskGenerated` means a misconfigured template. This is the
  /// laundering/quality detector, and it only works if the reason is mandatory.
  final Map<TaskCancelReason, int> cancelledByReason;

  /// Approved work that beat its deadline, and approved work that did not.
  /// Timeliness is measured on **completed** work only — it is coaching data,
  /// never pass/fail (§10.4), and it is the reason no "Completed Late" state
  /// needs to exist (spec §3.6).
  final int completedOnTime;
  final int completedLate;

  /// Summed minutes past deadline across [completedLate]. Raw so the average
  /// stays a derivation rather than a stored figure.
  final int totalLatenessMinutes;

  /// Every task that counts toward the record. **Cancelled is not in here** —
  /// by decision the work never happened, so it sits on neither side.
  int get scored => approved + missed;

  /// **The headline KPI (§10.1): Approved ÷ (Approved + Missed)**, as a
  /// whole-number percentage, or null when nothing has been decided yet (so the
  /// UI shows "—" rather than a misleading 0%).
  ///
  /// Excluding Cancelled is what makes this **ungameable**: a manager cannot
  /// improve the number by cancelling work they expect to fail, because a
  /// cancellation leaves the denominator instead of entering the numerator.
  int? get completionRatePct =>
      scored == 0 ? null : ((approved / scored) * 100).round();

  /// Completed work delivered after its deadline, as a whole-number percentage
  /// of completed work — "% completed after deadline" (§10.4). Null when nothing
  /// has been completed. A **timeliness** figure: it never affects
  /// [completionRatePct] and must never be presented as a pass/fail score.
  int? get lateCompletionPct {
    final completed = completedOnTime + completedLate;
    return completed == 0 ? null : ((completedLate / completed) * 100).round();
  }

  /// Mean minutes late across the work that *was* late, or null when none was.
  /// Deliberately averaged over late work only — averaging over all completions
  /// would dilute the signal into meaninglessness.
  int? get averageLatenessMinutes =>
      completedLate == 0 ? null : (totalLatenessMinutes / completedLate).round();

  /// True when there is nothing at all to report.
  bool get isEmpty => approved == 0 && missed == 0 && cancelled == 0 && open == 0;

  /// The reason codes present, most frequent first — the order a "cancellations
  /// by reason" line should read in, since the cluster is the point.
  List<MapEntry<TaskCancelReason, int>> get cancelReasonsByFrequency {
    final entries = cancelledByReason.entries.toList()
      ..sort((a, b) {
        final c = b.value.compareTo(a.value);
        return c != 0 ? c : a.key.label.compareTo(b.key.label);
      });
    return entries;
  }
}

/// The amount by which finished work missed its deadline, or null when the
/// task is not finished, has no deadline, or was delivered on time.
///
/// Finish moment is `submittedAt` (falling back to `approvedAt`) against
/// `deadline` — the same pair [taskOutcomes] measures its Approved-only
/// timeliness split from (§10.4), so the two can never drift apart.
///
/// Scoped to every status that carries a finish timestamp —
/// [TaskStatus.completed], [TaskStatus.waitingReview] and
/// [TaskStatus.approved] — so a task reads late from the moment it is
/// submitted, without waiting on a manager's review. [TaskStatus.missed] is a
/// separate outcome and never late; [TaskStatus.cancelled] counts nowhere
/// (§8). Either timestamp missing → null — guessing would invent a signal.
Duration? taskLateness(TaskEntity t) {
  final tracksFinish = switch (t.status) {
    TaskStatus.completed || TaskStatus.waitingReview || TaskStatus.approved =>
      true,
    _ => false,
  };
  if (!tracksFinish) return null;
  final finished = t.submittedAt ?? t.approvedAt;
  final due = t.deadline;
  if (finished == null || due == null) return null;
  if (!finished.isAfter(due)) return null;
  return finished.difference(due);
}

/// Derives the four-way classification over [tasks].
///
/// Lateness is measured from the timestamps already on the record via
/// [taskLateness] — the moment the employee submitted (`submittedAt`, falling
/// back to `approvedAt`) against `deadline`. That is the whole reason a
/// *Completed Late* status was rejected: the data was always there.
///
/// A cancelled task with an unrecognised reason code still counts under
/// [TaskCancelReason.unknown] rather than vanishing — a cancellation written by
/// a newer build must never silently drop out of the by-reason total.
TaskOutcomes taskOutcomes(Iterable<TaskEntity> tasks) {
  var approved = 0;
  var missed = 0;
  var cancelled = 0;
  var open = 0;
  var onTime = 0;
  var late = 0;
  var latenessMinutes = 0;
  final byReason = <TaskCancelReason, int>{};

  for (final t in tasks) {
    switch (t.status) {
      case TaskStatus.approved:
        approved++;
        final finished = t.submittedAt ?? t.approvedAt;
        final due = t.deadline;
        if (finished == null || due == null) {
          // No window to judge against — it cannot be late, and guessing would
          // invent a signal. Not counted on either side of the timeliness split.
          break;
        }
        final lateness = taskLateness(t);
        if (lateness != null) {
          late++;
          latenessMinutes += lateness.inMinutes;
        } else {
          onTime++;
        }
      case TaskStatus.missed:
        missed++;
      case TaskStatus.cancelled:
        cancelled++;
        // A cancelled task always carries a reason (mandatory, §5.5); a legacy
        // or malformed doc without one still counts in the total under
        // `unknown`, because an uncounted cancellation is worse than a vague one.
        final reason = t.cancelReason ?? TaskCancelReason.unknown;
        byReason[reason] = (byReason[reason] ?? 0) + 1;
      case TaskStatus.pending:
      case TaskStatus.started:
      case TaskStatus.completed:
      case TaskStatus.waitingReview:
      case TaskStatus.rejected:
        open++;
    }
  }

  return TaskOutcomes(
    approved: approved,
    missed: missed,
    cancelled: cancelled,
    open: open,
    cancelledByReason: Map.unmodifiable(byReason),
    completedOnTime: onTime,
    completedLate: late,
    totalLatenessMinutes: latenessMinutes,
  );
}
