import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:opshub/core/enums/schedule_shift.dart';
import 'package:opshub/core/enums/task_priority.dart';
import 'package:opshub/core/enums/template_repeat_mode.dart';
import 'package:opshub/features/task/domain/entities/checklist_item.dart';

part 'recurring_task_template_entity.freezed.dart';

/// A permanent blueprint for a **shift-assigned** task that repeats on its own
/// clock (Shift Assignment feature) — e.g. "Open Store" every day on the
/// Morning shift. Distinct from [TaskTemplateEntity], which is a one-shot
/// checklist blueprint a manager instantiates by hand; this one is read by the
/// `generateShiftTaskInstances` Cloud Function, which creates one real
/// `tasks/{id}` document per due date (so completion is trackable per day) and
/// links it back here via `TaskEntity.sourceTemplateId`.
///
/// Always branch-scoped (a shift only means something within one branch's
/// roster) and always [TaskAssignmentType.shift] — there is no
/// individual/team recurring-template path (existing per-task `RecurrenceConfig`
/// already covers that case).
@freezed
class RecurringTaskTemplateEntity with _$RecurringTaskTemplateEntity {
  const RecurringTaskTemplateEntity._();

  const factory RecurringTaskTemplateEntity({
    required String id,
    required String title,
    String? description,
    @Default(TaskPriority.normal) TaskPriority priority,
    @Default(<ChecklistItemTemplate>[]) List<ChecklistItemTemplate> checklistItems,
    required String branchId,
    required ScheduleShift shift,
    @Default(TemplateRepeatMode.daily) TemplateRepeatMode repeat,
    /// Target weekday when [repeat] is [TemplateRepeatMode.weekly]:
    /// `DateTime.monday` = 1 … `DateTime.sunday` = 7 (matches [RecurrenceConfig.weekday]).
    @Default(1) int weekday,
    /// Whether the generator should still produce instances from this template.
    /// A manager pausing/retiring a routine sets this false rather than
    /// deleting the template — past instances (and their analytics) are
    /// untouched either way.
    @Default(true) bool active,
    String? createdBy,
    /// uid of whoever last edited this routine (client-written on update).
    String? updatedBy,
    DateTime? createdAt,
    DateTime? updatedAt,
    // ─── Automation health (Automation Center) ──────────────────────────
    // Cloud-Function-owned rollups, written by `generateShiftTaskInstances` via
    // the Admin SDK and **read-only** to the client (never in `toMap`, like a
    // task's `version`). They let the Automation Center show a routine's health
    // without reading Cloud Logging — see docs/design/AUTOMATION_ENGINE.md.
    /// Last time the generator attempted this routine.
    DateTime? lastRunAt,
    /// Next scheduled generation (computed by the function; advisory).
    DateTime? nextRunAt,
    /// Outcome of the last run: `completed` / `skipped` / `failed`
    /// (null = never run).
    String? lastStatus,
    /// The task id the last successful run generated.
    String? lastGeneratedTaskId,
    /// Consecutive generation failures; reset to 0 on a successful run.
    @Default(0) int failureCount,
    // ─── Cumulative health counters (Automation observability, ADR-011) ──
    // Monotonic totals the Cloud Function increments per run (O(1) writes) so the
    // whole health panel is ONE read; derived rate/avg live in [AutomationHealth]
    // and are never stored. All CF-owned and **read-only** to the client (never
    // in `toMap`, like the rollups above).
    /// A monotonic version of the definition, bumped by the lifecycle CF on any
    /// config change; captured onto each run so history is attributable.
    @Default(1) int configVersion,
    /// Total generation runs recorded (completed + skipped + failed).
    @Default(0) int runCount,
    /// Runs that completed (a task was generated).
    @Default(0) int successCount,
    /// Runs that failed.
    @Default(0) int failedCount,
    /// Runs that were skipped (the day's task already existed).
    @Default(0) int skippedCount,
    /// Sum of run durations in ms; averaged on read (never stored averaged).
    @Default(0) int totalDurationMs,
    /// Last successful generation.
    DateTime? lastSuccessAt,
    /// Last failed generation.
    DateTime? lastFailureAt,
  }) = _RecurringTaskTemplateEntity;

  /// Builds the instance-level checklist (all items uncompleted) for a newly
  /// generated day's task.
  List<ChecklistItem> buildTaskChecklist() =>
      [for (final i in checklistItems) i.toTaskItem()];
}
