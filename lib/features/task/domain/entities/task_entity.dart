import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:drop/core/enums/task_assignment_type.dart';
import 'package:drop/core/enums/task_cancel_reason.dart';
import 'package:drop/core/enums/task_type.dart';
import 'package:drop/core/enums/task_status.dart';
import 'package:drop/core/enums/task_priority.dart';
import 'package:drop/core/enums/schedule_shift.dart';
import 'package:drop/features/task/domain/entities/activity_entry.dart';
import 'package:drop/features/task/domain/entities/checklist_item.dart';
import 'package:drop/features/task/domain/entities/recurrence_config.dart';
import 'package:drop/features/task/domain/entities/task_attachment.dart';

part 'task_entity.freezed.dart';

/// A unit of work in DROP (Phase 3) — the core operations workflow: a
/// manager/admin creates and assigns a task, one or more employees execute it
/// (start → complete, with optional notes + proof image), and a manager/admin
/// reviews it (approve / reject).
///
/// A task is branch-scoped via [branchId] and may be tied to an
/// [assignedShiftId]. It supports **multiple assignees** ([assigneeIds], Phase 9
/// — replaces the former single `assignedEmployeeId`) and an optional
/// **[checklist]** generated from a checklist template. Access is enforced
/// server-side in `firestore.rules` (admin: all branches · manager: own branch ·
/// employee: tasks they're assigned to).
@freezed
class TaskEntity with _$TaskEntity {
  const TaskEntity._();

  const factory TaskEntity({
    required String id,
    required String title,
    String? description,
    @Default(TaskType.daily) TaskType type,
    /// The **operational kind** of this work (Registry-backed — see
    /// `WorkTypeRegistry`). A stable string id (`general`, `transfer`,
    /// `purchaseErrand`, `inventoryCount`, `inspection`, …) resolved to a
    /// `WorkTypeDefinition` that owns this task's dynamic fields, milestones,
    /// completion gate, review disposition and analytics. Orthogonal to [type]
    /// (`daily`/`special`), which is a cadence tag. A missing / unknown id
    /// resolves to `general`, so old docs and rolled-back types never break (see
    /// the `TaskWorkX` adapter). Defaults to `general` for every task that
    /// predates work types — no migration needed.
    @Default('general') String workType,
    @Default(TaskStatus.pending) TaskStatus status,
    @Default(TaskPriority.normal) TaskPriority priority,
    /// Owning branch (admin: any · manager: own branch).
    String? branchId,
    /// Employees assigned to execute the task (Phase 9 — multi-assignee). Empty
    /// while unassigned. Supersedes the legacy single `assignedEmployeeId`.
    @Default(<String>[]) List<String> assigneeIds,
    /// Checklist the employee must work through (generated from a template).
    @Default(<ChecklistItem>[]) List<ChecklistItem> checklist,
    /// Reference images attached by the manager/admin when creating/editing the
    /// task — "what good looks like" / context the employee sees **before** doing
    /// the work. Distinct from employee *proof* media, which lives on the
    /// submission [ActivityEntry] (and the legacy [proofImageUrl]). Stored in
    /// Storage at `tasks/{id}/attachments/{attId}.<ext>` like all task media.
    @Default(<TaskAttachment>[]) List<TaskAttachment> referenceAttachments,
    /// Schema-driven values for this work type's dynamic fields, keyed by
    /// `WorkFieldSpec.key` (e.g. an inventory count's `expectedQty`/`countedQty`,
    /// a purchase's `budget`/`spentAmount`, an inspection's per-point `results`).
    /// Empty for a general task. Persists at `tasks/{id}.data`; the model
    /// converts any `DateTime` values to/from `Timestamp` on the boundary.
    @Default(<String, dynamic>{}) Map<String, dynamic> data,
    /// uid of the manager/admin who created the task.
    String? createdBy,
    /// Optional shift this task belongs to (references `shifts/{shiftId}`).
    String? assignedShiftId,
    /// The operational shift this task belongs to (Branch Operations) —
    /// `morning` / `night`, or **null** when the task is not shift-specific
    /// ("any", applies under every shift filter). Drives the Branch Operations
    /// shift filter; supersedes the unused legacy [assignedShiftId] string. When
    /// [assignmentType] is [TaskAssignmentType.shift] this is also the actual
    /// assignment target (see `canUserAccessTask`), not just a filter tag.
    ScheduleShift? shift,
    /// How this task is assigned. `individual`/`team` both read [assigneeIds];
    /// `shift` leaves [assigneeIds] empty and targets whoever is rostered on
    /// [shift] for [instanceDate] instead. Missing on any task written before
    /// this field existed → [TaskAssignmentType.individual] (no migration
    /// needed; see `TaskModel.fromMap`).
    @Default(TaskAssignmentType.individual) TaskAssignmentType assignmentType,
    /// The calendar day a shift-assigned instance is *for* — distinct from
    /// [deadline] (which may carry a specific time of day). Null for
    /// individual/team tasks and for any task predating shift assignment.
    DateTime? instanceDate,
    /// Links a shift instance back to the [RecurringTaskTemplateEntity] that
    /// generated it (`generateShiftTaskInstances` Cloud Function). Null for
    /// one-off tasks and for every task predating recurring shift templates.
    String? sourceTemplateId,
    /// Stable lineage id for a **per-task recurrence** chain (Path B). Set on
    /// every auto-spawned successor to the id of the chain's *root* task (the
    /// first, manually-created one), so an admin can group / query a whole
    /// recurring lineage. Null on a one-off task and on the root itself until it
    /// spawns. Additive — no migration. See `TaskCubit._spawnNextRecurrence`.
    String? recurrenceRootId,
    /// The occurrence this auto-spawned task is *for* — the successor's due-date
    /// key (`yyyy-MM-dd`), stored for display/debugging in the Automation Center.
    /// Distinct from the **document id**, which is the deterministic idempotency
    /// key `rec_{sourceTaskId}` (each task spawns at most one successor, so the
    /// successor keys off the current task id and never off a possibly-null
    /// deadline). Null for non-recurring tasks. Additive — no migration.
    String? occurrenceKey,
    /// The automation-execution **correlation id** (`AUT-{yyyymmdd}-{hash}`) that
    /// created this task, shared with the run record, its notifications and its
    /// audit entries so the task can be traced back to the whole execution.
    /// Server-stamped by `generateShiftTaskInstances`; null for any task not
    /// produced by a recurring shift automation. Additive — no migration.
    String? correlationId,
    /// When the task is scheduled to **start** (Task Scheduling V2). Pre-filled
    /// from the assigned shift's hours as a *smart default* the manager can
    /// override; null on tasks predating scheduling (unknown start). Additive —
    /// no migration. See [dueAt] for the due side and `task_schedule.dart` for
    /// the derived [TaskSchedulePhase] (Scheduled → Active → Due-soon → Overdue).
    DateTime? startsAt,
    /// When the task becomes **due / overdue** — the canonical due timestamp,
    /// exposed as [dueAt]. Kept named `deadline` for backward compatibility (all
    /// existing reads + old Firestore docs are unchanged).
    DateTime? deadline,
    /// When a recurring shift task was automatically ended because its shift
    /// deadline passed before the work was completed. Written only by the
    /// server-side automation sweep; null for every task that has not missed
    /// its shift window. Additive — old task documents remain valid.
    DateTime? missedAt,
    // ─── Cancellation (Automated Tasks spec §5) ──────────────────
    /// When a manager/admin cancelled the task, and who. Cancellation is a
    /// terminal **business decision** — the work will not be done — taken from
    /// `pending` or `started` only, and it is neither success nor failure for
    /// reporting (§8). Null on every task that was never cancelled. Additive —
    /// old task documents remain valid.
    DateTime? cancelledAt,
    String? cancelledBy,
    /// The mandatory structured reason (§5.5). Always set on a cancelled task;
    /// null otherwise. **Immutable once written** (frozen in `firestore.rules`)
    /// so reporting by reason code stays historically honest.
    TaskCancelReason? cancelReason,
    /// Optional free-text note accompanying [cancelReason]. Never a substitute
    /// for the code — it exists to add context a picklist can't carry.
    String? cancelNote,
    // ─── Reported incorrect (Automated Tasks spec §5.2) ───────────
    /// An employee flagged this task as wrong (duplicate, not applicable, aimed
    /// at the wrong shift…) and routed it to a manager, **who decides** — the
    /// employee never cancels. This is the release valve that makes manager-only
    /// cancellation workable rather than inhumane.
    ///
    /// [reportedIncorrectBy] is the reporting employee's uid; the note is their
    /// explanation and is required at the call site, because a report with no
    /// explanation gives the manager nothing to decide on. All three clear
    /// together when a manager dismisses the report or cancels the task. Null on
    /// every unreported task. Additive — no migration.
    String? reportedIncorrectBy,
    DateTime? reportedIncorrectAt,
    String? reportedIncorrectNote,
    /// Free-text notes added by the executing employee.
    String? notes,
    /// Download URL of the proof image the employee uploads on completion.
    String? proofImageUrl,
    // ─── Lifecycle timestamps (one per status transition, set atomically) ───
    /// When an employee first started the task.
    DateTime? startedAt,
    /// When the employee submitted for review (via completeAndSubmit or submitForReview).
    DateTime? submittedAt,
    // ─── Review audit fields ─────────────────────────────────────
    /// uid of the manager/admin who approved the task, + when.
    String? approvedBy,
    DateTime? approvedAt,
    /// uid of the manager/admin who rejected the task, + when.
    String? rejectedBy,
    DateTime? rejectedAt,
    /// Reviewer's note left on approve/reject.
    String? reviewNotes,
    // ─── Rework distinction (Notification System Phase 1) ─────────
    /// How many times this task has been sent back for rework. 0 = a new task,
    /// 1 = first rework, 2 = second, … Incremented only by "Request Rework"
    /// (not by a terminal "Reject"). Drives the `REWORK #n` badge + payload.
    @Default(0) int revisionNumber,
    /// True while the task is awaiting a redo after a rework request; cleared
    /// when the employee resubmits. Distinguishes a rework loop from a plain
    /// rejection / new task.
    @Default(false) bool requiresRework,
    /// The reviewer's reason captured on the last rework / reject decision
    /// (shown to the employee + carried in the notification body).
    String? rejectionReason,
    /// Recurrence rule — null means "one-off" (does not repeat). When set, the
    /// [TaskCubit] auto-creates the next instance after this task is approved.
    RecurrenceConfig? recurrence,
    /// Activity timeline: one entry per status transition, ordered oldest→newest.
    @Default(<ActivityEntry>[]) List<ActivityEntry> activityLog,
    DateTime? createdAt,
    DateTime? updatedAt,
    /// When the task was archived by the retention pass (`taskHousekeeping`
    /// Cloud Function) — set only on an `approved` task older than the branch's
    /// `archiveAfterDays`. Null = live. Server-managed: the function stamps it
    /// via the Admin SDK; the client only ever *reads* it (to filter archived
    /// work out of active views) or *clears* it on an admin reopen. An archived
    /// task is still a full record in `tasks` (soft archive — never deleted
    /// unless a retention `deleteAfterDays` is explicitly configured), so
    /// statistics and deep-links keep working.
    DateTime? archivedAt,
    /// Optimistic-concurrency counter, bumped by the server-authoritative
    /// transition path (`TaskRepository.transitionTask`) on every lifecycle move.
    /// A plain content edit never writes it. Additive — missing on any doc
    /// predating it → 0 (no migration). Not persisted by `TaskModel.toMap` (the
    /// transaction owns it, exactly like `createdAt`/`updatedAt`), so a stale
    /// client edit can never regress it. Read-only to the UI.
    @Default(0) int version,
  }) = _TaskEntity;

  /// Whether anyone is assigned — a named assignee, or (for a shift task) the
  /// shift itself is set.
  bool get isAssigned => assignmentType == TaskAssignmentType.shift
      ? shift != null
      : assigneeIds.isNotEmpty;

  /// A brand-new task: never reworked and still pending its first start. Drives
  /// the monochrome `NEW` badge (Notification System Phase 1).
  bool get isNew =>
      status == TaskStatus.pending && revisionNumber == 0 && !requiresRework;

  /// Whether the manager attached any reference images.
  bool get hasReferences => referenceAttachments.isNotEmpty;

  /// True while an employee's "this task is wrong" report is open and awaiting a
  /// manager's decision (spec §5.2). Drives the manager-facing banner.
  bool get isReportedIncorrect => reportedIncorrectAt != null;

  /// The canonical **due** timestamp (Task Scheduling V2). Aliases the physical
  /// [deadline] field so new code reads `dueAt` while old docs/readers keep
  /// working. Pairs with [startsAt].
  DateTime? get dueAt => deadline;

  /// True once the task carries an explicit schedule window (both ends set).
  bool get hasSchedule => startsAt != null && deadline != null;

  /// True once the retention pass has archived this (approved) task — it drops
  /// out of every active list/stream (filtered in `TaskRepositoryImpl`) but
  /// remains a full record for stats/audit/deep-links.
  bool get isArchived => archivedAt != null;

  // ─── Checklist progress (Phase 9) ──────────────────────────────
  bool get hasChecklist => checklist.isNotEmpty;
  int get checklistTotal => checklist.length;
  int get checklistDone => checklist.where((c) => c.completed).length;

  /// 0.0–1.0 completion (1.0 when there is no checklist).
  double get checklistProgress =>
      checklist.isEmpty ? 1 : checklistDone / checklistTotal;

  /// True when every **required** checklist item is completed — the gate for
  /// marking the task completed.
  bool get requiredChecklistComplete =>
      checklist.where((c) => c.isRequired).every((c) => c.completed);
}
