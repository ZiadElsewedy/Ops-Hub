// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'task_entity.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

/// @nodoc
mixin _$TaskEntity {
  String get id => throw _privateConstructorUsedError;
  String get title => throw _privateConstructorUsedError;
  String? get description => throw _privateConstructorUsedError;
  TaskType get type => throw _privateConstructorUsedError;

  /// The **operational kind** of this work (Registry-backed — see
  /// `WorkTypeRegistry`). A stable string id (`general`, `transfer`,
  /// `purchaseErrand`, `inventoryCount`, `inspection`, …) resolved to a
  /// `WorkTypeDefinition` that owns this task's dynamic fields, milestones,
  /// completion gate, review disposition and analytics. Orthogonal to [type]
  /// (`daily`/`special`), which is a cadence tag. A missing / unknown id
  /// resolves to `general`, so old docs and rolled-back types never break (see
  /// the `TaskWorkX` adapter). Defaults to `general` for every task that
  /// predates work types — no migration needed.
  String get workType => throw _privateConstructorUsedError;
  TaskStatus get status => throw _privateConstructorUsedError;
  TaskPriority get priority => throw _privateConstructorUsedError;

  /// Owning branch (admin: any · manager: own branch).
  String? get branchId => throw _privateConstructorUsedError;

  /// Employees assigned to execute the task (Phase 9 — multi-assignee). Empty
  /// while unassigned. Supersedes the legacy single `assignedEmployeeId`.
  List<String> get assigneeIds => throw _privateConstructorUsedError;

  /// Checklist the employee must work through (generated from a template).
  List<ChecklistItem> get checklist => throw _privateConstructorUsedError;

  /// Reference images attached by the manager/admin when creating/editing the
  /// task — "what good looks like" / context the employee sees **before** doing
  /// the work. Distinct from employee *proof* media, which lives on the
  /// submission [ActivityEntry] (and the legacy [proofImageUrl]). Stored in
  /// Storage at `tasks/{id}/attachments/{attId}.<ext>` like all task media.
  List<TaskAttachment> get referenceAttachments =>
      throw _privateConstructorUsedError;

  /// Schema-driven values for this work type's dynamic fields, keyed by
  /// `WorkFieldSpec.key` (e.g. an inventory count's `expectedQty`/`countedQty`,
  /// a purchase's `budget`/`spentAmount`, an inspection's per-point `results`).
  /// Empty for a general task. Persists at `tasks/{id}.data`; the model
  /// converts any `DateTime` values to/from `Timestamp` on the boundary.
  Map<String, dynamic> get data => throw _privateConstructorUsedError;

  /// uid of the manager/admin who created the task.
  String? get createdBy => throw _privateConstructorUsedError;

  /// Optional shift this task belongs to (references `shifts/{shiftId}`).
  String? get assignedShiftId => throw _privateConstructorUsedError;

  /// The operational shift this task belongs to (Branch Operations) —
  /// `morning` / `night`, or **null** when the task is not shift-specific
  /// ("any", applies under every shift filter). Drives the Branch Operations
  /// shift filter; supersedes the unused legacy [assignedShiftId] string. When
  /// [assignmentType] is [TaskAssignmentType.shift] this is also the actual
  /// assignment target (see `canUserAccessTask`), not just a filter tag.
  ScheduleShift? get shift => throw _privateConstructorUsedError;

  /// How this task is assigned. `individual`/`team` both read [assigneeIds];
  /// `shift` leaves [assigneeIds] empty and targets whoever is rostered on
  /// [shift] for [instanceDate] instead. Missing on any task written before
  /// this field existed → [TaskAssignmentType.individual] (no migration
  /// needed; see `TaskModel.fromMap`).
  TaskAssignmentType get assignmentType => throw _privateConstructorUsedError;

  /// The calendar day a shift-assigned instance is *for* — distinct from
  /// [deadline] (which may carry a specific time of day). Null for
  /// individual/team tasks and for any task predating shift assignment.
  DateTime? get instanceDate => throw _privateConstructorUsedError;

  /// Links a shift instance back to the [RecurringTaskTemplateEntity] that
  /// generated it (`generateShiftTaskInstances` Cloud Function). Null for
  /// one-off tasks and for every task predating recurring shift templates.
  String? get sourceTemplateId => throw _privateConstructorUsedError;

  /// Stable lineage id for a **per-task recurrence** chain (Path B). Set on
  /// every auto-spawned successor to the id of the chain's *root* task (the
  /// first, manually-created one), so an admin can group / query a whole
  /// recurring lineage. Null on a one-off task and on the root itself until it
  /// spawns. Additive — no migration. See `TaskCubit._spawnNextRecurrence`.
  String? get recurrenceRootId => throw _privateConstructorUsedError;

  /// The occurrence this auto-spawned task is *for* — the successor's due-date
  /// key (`yyyy-MM-dd`), stored for display/debugging in the Automation Center.
  /// Distinct from the **document id**, which is the deterministic idempotency
  /// key `rec_{sourceTaskId}` (each task spawns at most one successor, so the
  /// successor keys off the current task id and never off a possibly-null
  /// deadline). Null for non-recurring tasks. Additive — no migration.
  String? get occurrenceKey => throw _privateConstructorUsedError;

  /// The automation-execution **correlation id** (`AUT-{yyyymmdd}-{hash}`) that
  /// created this task, shared with the run record, its notifications and its
  /// audit entries so the task can be traced back to the whole execution.
  /// Server-stamped by `generateShiftTaskInstances`; null for any task not
  /// produced by a recurring shift automation. Additive — no migration.
  String? get correlationId => throw _privateConstructorUsedError;

  /// When the task is scheduled to **start** (Task Scheduling V2). Pre-filled
  /// from the assigned shift's hours as a *smart default* the manager can
  /// override; null on tasks predating scheduling (unknown start). Additive —
  /// no migration. See [dueAt] for the due side and `task_schedule.dart` for
  /// the derived [TaskSchedulePhase] (Scheduled → Active → Due-soon → Overdue).
  DateTime? get startsAt => throw _privateConstructorUsedError;

  /// When the task becomes **due / overdue** — the canonical due timestamp,
  /// exposed as [dueAt]. Kept named `deadline` for backward compatibility (all
  /// existing reads + old Firestore docs are unchanged).
  DateTime? get deadline => throw _privateConstructorUsedError;

  /// When a recurring shift task was automatically ended because its shift
  /// deadline passed before the work was completed. Written only by the
  /// server-side automation sweep; null for every task that has not missed
  /// its shift window. Additive — old task documents remain valid.
  DateTime? get missedAt =>
      throw _privateConstructorUsedError; // ─── Cancellation (Automated Tasks spec §5) ──────────────────
  /// When a manager/admin cancelled the task, and who. Cancellation is a
  /// terminal **business decision** — the work will not be done — taken from
  /// `pending` or `started` only, and it is neither success nor failure for
  /// reporting (§8). Null on every task that was never cancelled. Additive —
  /// old task documents remain valid.
  DateTime? get cancelledAt => throw _privateConstructorUsedError;
  String? get cancelledBy => throw _privateConstructorUsedError;

  /// The mandatory structured reason (§5.5). Always set on a cancelled task;
  /// null otherwise. **Immutable once written** (frozen in `firestore.rules`)
  /// so reporting by reason code stays historically honest.
  TaskCancelReason? get cancelReason => throw _privateConstructorUsedError;

  /// Optional free-text note accompanying [cancelReason]. Never a substitute
  /// for the code — it exists to add context a picklist can't carry.
  String? get cancelNote =>
      throw _privateConstructorUsedError; // ─── Reported incorrect (Automated Tasks spec §5.2) ───────────
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
  String? get reportedIncorrectBy => throw _privateConstructorUsedError;
  DateTime? get reportedIncorrectAt => throw _privateConstructorUsedError;
  String? get reportedIncorrectNote => throw _privateConstructorUsedError;

  /// Free-text notes added by the executing employee.
  String? get notes => throw _privateConstructorUsedError;

  /// Download URL of the proof image the employee uploads on completion.
  String? get proofImageUrl =>
      throw _privateConstructorUsedError; // ─── Lifecycle timestamps (one per status transition, set atomically) ───
  /// When an employee first started the task.
  DateTime? get startedAt => throw _privateConstructorUsedError;

  /// When the employee submitted for review (via completeAndSubmit or submitForReview).
  DateTime? get submittedAt =>
      throw _privateConstructorUsedError; // ─── Review audit fields ─────────────────────────────────────
  /// uid of the manager/admin who approved the task, + when.
  String? get approvedBy => throw _privateConstructorUsedError;
  DateTime? get approvedAt => throw _privateConstructorUsedError;

  /// uid of the manager/admin who rejected the task, + when.
  String? get rejectedBy => throw _privateConstructorUsedError;
  DateTime? get rejectedAt => throw _privateConstructorUsedError;

  /// Reviewer's note left on approve/reject.
  String? get reviewNotes =>
      throw _privateConstructorUsedError; // ─── Rework distinction (Notification System Phase 1) ─────────
  /// How many times this task has been sent back for rework. 0 = a new task,
  /// 1 = first rework, 2 = second, … Incremented only by "Request Rework"
  /// (not by a terminal "Reject"). Drives the `REWORK #n` badge + payload.
  int get revisionNumber => throw _privateConstructorUsedError;

  /// True while the task is awaiting a redo after a rework request; cleared
  /// when the employee resubmits. Distinguishes a rework loop from a plain
  /// rejection / new task.
  bool get requiresRework => throw _privateConstructorUsedError;

  /// The reviewer's reason captured on the last rework / reject decision
  /// (shown to the employee + carried in the notification body).
  String? get rejectionReason => throw _privateConstructorUsedError;

  /// Recurrence rule — null means "one-off" (does not repeat). When set, the
  /// [TaskCubit] auto-creates the next instance after this task is approved.
  RecurrenceConfig? get recurrence => throw _privateConstructorUsedError;

  /// Activity timeline: one entry per status transition, ordered oldest→newest.
  List<ActivityEntry> get activityLog => throw _privateConstructorUsedError;
  DateTime? get createdAt => throw _privateConstructorUsedError;
  DateTime? get updatedAt => throw _privateConstructorUsedError;

  /// When the task was archived by the retention pass (`taskHousekeeping`
  /// Cloud Function) — set only on an `approved` task older than the branch's
  /// `archiveAfterDays`. Null = live. Server-managed: the function stamps it
  /// via the Admin SDK; the client only ever *reads* it (to filter archived
  /// work out of active views) or *clears* it on an admin reopen. An archived
  /// task is still a full record in `tasks` (soft archive — never deleted
  /// unless a retention `deleteAfterDays` is explicitly configured), so
  /// statistics and deep-links keep working.
  DateTime? get archivedAt => throw _privateConstructorUsedError;

  /// Optimistic-concurrency counter, bumped by the server-authoritative
  /// transition path (`TaskRepository.transitionTask`) on every lifecycle move.
  /// A plain content edit never writes it. Additive — missing on any doc
  /// predating it → 0 (no migration). Not persisted by `TaskModel.toMap` (the
  /// transaction owns it, exactly like `createdAt`/`updatedAt`), so a stale
  /// client edit can never regress it. Read-only to the UI.
  int get version => throw _privateConstructorUsedError;

  /// Create a copy of TaskEntity
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $TaskEntityCopyWith<TaskEntity> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $TaskEntityCopyWith<$Res> {
  factory $TaskEntityCopyWith(
    TaskEntity value,
    $Res Function(TaskEntity) then,
  ) = _$TaskEntityCopyWithImpl<$Res, TaskEntity>;
  @useResult
  $Res call({
    String id,
    String title,
    String? description,
    TaskType type,
    String workType,
    TaskStatus status,
    TaskPriority priority,
    String? branchId,
    List<String> assigneeIds,
    List<ChecklistItem> checklist,
    List<TaskAttachment> referenceAttachments,
    Map<String, dynamic> data,
    String? createdBy,
    String? assignedShiftId,
    ScheduleShift? shift,
    TaskAssignmentType assignmentType,
    DateTime? instanceDate,
    String? sourceTemplateId,
    String? recurrenceRootId,
    String? occurrenceKey,
    String? correlationId,
    DateTime? startsAt,
    DateTime? deadline,
    DateTime? missedAt,
    DateTime? cancelledAt,
    String? cancelledBy,
    TaskCancelReason? cancelReason,
    String? cancelNote,
    String? reportedIncorrectBy,
    DateTime? reportedIncorrectAt,
    String? reportedIncorrectNote,
    String? notes,
    String? proofImageUrl,
    DateTime? startedAt,
    DateTime? submittedAt,
    String? approvedBy,
    DateTime? approvedAt,
    String? rejectedBy,
    DateTime? rejectedAt,
    String? reviewNotes,
    int revisionNumber,
    bool requiresRework,
    String? rejectionReason,
    RecurrenceConfig? recurrence,
    List<ActivityEntry> activityLog,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? archivedAt,
    int version,
  });

  $RecurrenceConfigCopyWith<$Res>? get recurrence;
}

/// @nodoc
class _$TaskEntityCopyWithImpl<$Res, $Val extends TaskEntity>
    implements $TaskEntityCopyWith<$Res> {
  _$TaskEntityCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of TaskEntity
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? title = null,
    Object? description = freezed,
    Object? type = null,
    Object? workType = null,
    Object? status = null,
    Object? priority = null,
    Object? branchId = freezed,
    Object? assigneeIds = null,
    Object? checklist = null,
    Object? referenceAttachments = null,
    Object? data = null,
    Object? createdBy = freezed,
    Object? assignedShiftId = freezed,
    Object? shift = freezed,
    Object? assignmentType = null,
    Object? instanceDate = freezed,
    Object? sourceTemplateId = freezed,
    Object? recurrenceRootId = freezed,
    Object? occurrenceKey = freezed,
    Object? correlationId = freezed,
    Object? startsAt = freezed,
    Object? deadline = freezed,
    Object? missedAt = freezed,
    Object? cancelledAt = freezed,
    Object? cancelledBy = freezed,
    Object? cancelReason = freezed,
    Object? cancelNote = freezed,
    Object? reportedIncorrectBy = freezed,
    Object? reportedIncorrectAt = freezed,
    Object? reportedIncorrectNote = freezed,
    Object? notes = freezed,
    Object? proofImageUrl = freezed,
    Object? startedAt = freezed,
    Object? submittedAt = freezed,
    Object? approvedBy = freezed,
    Object? approvedAt = freezed,
    Object? rejectedBy = freezed,
    Object? rejectedAt = freezed,
    Object? reviewNotes = freezed,
    Object? revisionNumber = null,
    Object? requiresRework = null,
    Object? rejectionReason = freezed,
    Object? recurrence = freezed,
    Object? activityLog = null,
    Object? createdAt = freezed,
    Object? updatedAt = freezed,
    Object? archivedAt = freezed,
    Object? version = null,
  }) {
    return _then(
      _value.copyWith(
            id: null == id
                ? _value.id
                : id // ignore: cast_nullable_to_non_nullable
                      as String,
            title: null == title
                ? _value.title
                : title // ignore: cast_nullable_to_non_nullable
                      as String,
            description: freezed == description
                ? _value.description
                : description // ignore: cast_nullable_to_non_nullable
                      as String?,
            type: null == type
                ? _value.type
                : type // ignore: cast_nullable_to_non_nullable
                      as TaskType,
            workType: null == workType
                ? _value.workType
                : workType // ignore: cast_nullable_to_non_nullable
                      as String,
            status: null == status
                ? _value.status
                : status // ignore: cast_nullable_to_non_nullable
                      as TaskStatus,
            priority: null == priority
                ? _value.priority
                : priority // ignore: cast_nullable_to_non_nullable
                      as TaskPriority,
            branchId: freezed == branchId
                ? _value.branchId
                : branchId // ignore: cast_nullable_to_non_nullable
                      as String?,
            assigneeIds: null == assigneeIds
                ? _value.assigneeIds
                : assigneeIds // ignore: cast_nullable_to_non_nullable
                      as List<String>,
            checklist: null == checklist
                ? _value.checklist
                : checklist // ignore: cast_nullable_to_non_nullable
                      as List<ChecklistItem>,
            referenceAttachments: null == referenceAttachments
                ? _value.referenceAttachments
                : referenceAttachments // ignore: cast_nullable_to_non_nullable
                      as List<TaskAttachment>,
            data: null == data
                ? _value.data
                : data // ignore: cast_nullable_to_non_nullable
                      as Map<String, dynamic>,
            createdBy: freezed == createdBy
                ? _value.createdBy
                : createdBy // ignore: cast_nullable_to_non_nullable
                      as String?,
            assignedShiftId: freezed == assignedShiftId
                ? _value.assignedShiftId
                : assignedShiftId // ignore: cast_nullable_to_non_nullable
                      as String?,
            shift: freezed == shift
                ? _value.shift
                : shift // ignore: cast_nullable_to_non_nullable
                      as ScheduleShift?,
            assignmentType: null == assignmentType
                ? _value.assignmentType
                : assignmentType // ignore: cast_nullable_to_non_nullable
                      as TaskAssignmentType,
            instanceDate: freezed == instanceDate
                ? _value.instanceDate
                : instanceDate // ignore: cast_nullable_to_non_nullable
                      as DateTime?,
            sourceTemplateId: freezed == sourceTemplateId
                ? _value.sourceTemplateId
                : sourceTemplateId // ignore: cast_nullable_to_non_nullable
                      as String?,
            recurrenceRootId: freezed == recurrenceRootId
                ? _value.recurrenceRootId
                : recurrenceRootId // ignore: cast_nullable_to_non_nullable
                      as String?,
            occurrenceKey: freezed == occurrenceKey
                ? _value.occurrenceKey
                : occurrenceKey // ignore: cast_nullable_to_non_nullable
                      as String?,
            correlationId: freezed == correlationId
                ? _value.correlationId
                : correlationId // ignore: cast_nullable_to_non_nullable
                      as String?,
            startsAt: freezed == startsAt
                ? _value.startsAt
                : startsAt // ignore: cast_nullable_to_non_nullable
                      as DateTime?,
            deadline: freezed == deadline
                ? _value.deadline
                : deadline // ignore: cast_nullable_to_non_nullable
                      as DateTime?,
            missedAt: freezed == missedAt
                ? _value.missedAt
                : missedAt // ignore: cast_nullable_to_non_nullable
                      as DateTime?,
            cancelledAt: freezed == cancelledAt
                ? _value.cancelledAt
                : cancelledAt // ignore: cast_nullable_to_non_nullable
                      as DateTime?,
            cancelledBy: freezed == cancelledBy
                ? _value.cancelledBy
                : cancelledBy // ignore: cast_nullable_to_non_nullable
                      as String?,
            cancelReason: freezed == cancelReason
                ? _value.cancelReason
                : cancelReason // ignore: cast_nullable_to_non_nullable
                      as TaskCancelReason?,
            cancelNote: freezed == cancelNote
                ? _value.cancelNote
                : cancelNote // ignore: cast_nullable_to_non_nullable
                      as String?,
            reportedIncorrectBy: freezed == reportedIncorrectBy
                ? _value.reportedIncorrectBy
                : reportedIncorrectBy // ignore: cast_nullable_to_non_nullable
                      as String?,
            reportedIncorrectAt: freezed == reportedIncorrectAt
                ? _value.reportedIncorrectAt
                : reportedIncorrectAt // ignore: cast_nullable_to_non_nullable
                      as DateTime?,
            reportedIncorrectNote: freezed == reportedIncorrectNote
                ? _value.reportedIncorrectNote
                : reportedIncorrectNote // ignore: cast_nullable_to_non_nullable
                      as String?,
            notes: freezed == notes
                ? _value.notes
                : notes // ignore: cast_nullable_to_non_nullable
                      as String?,
            proofImageUrl: freezed == proofImageUrl
                ? _value.proofImageUrl
                : proofImageUrl // ignore: cast_nullable_to_non_nullable
                      as String?,
            startedAt: freezed == startedAt
                ? _value.startedAt
                : startedAt // ignore: cast_nullable_to_non_nullable
                      as DateTime?,
            submittedAt: freezed == submittedAt
                ? _value.submittedAt
                : submittedAt // ignore: cast_nullable_to_non_nullable
                      as DateTime?,
            approvedBy: freezed == approvedBy
                ? _value.approvedBy
                : approvedBy // ignore: cast_nullable_to_non_nullable
                      as String?,
            approvedAt: freezed == approvedAt
                ? _value.approvedAt
                : approvedAt // ignore: cast_nullable_to_non_nullable
                      as DateTime?,
            rejectedBy: freezed == rejectedBy
                ? _value.rejectedBy
                : rejectedBy // ignore: cast_nullable_to_non_nullable
                      as String?,
            rejectedAt: freezed == rejectedAt
                ? _value.rejectedAt
                : rejectedAt // ignore: cast_nullable_to_non_nullable
                      as DateTime?,
            reviewNotes: freezed == reviewNotes
                ? _value.reviewNotes
                : reviewNotes // ignore: cast_nullable_to_non_nullable
                      as String?,
            revisionNumber: null == revisionNumber
                ? _value.revisionNumber
                : revisionNumber // ignore: cast_nullable_to_non_nullable
                      as int,
            requiresRework: null == requiresRework
                ? _value.requiresRework
                : requiresRework // ignore: cast_nullable_to_non_nullable
                      as bool,
            rejectionReason: freezed == rejectionReason
                ? _value.rejectionReason
                : rejectionReason // ignore: cast_nullable_to_non_nullable
                      as String?,
            recurrence: freezed == recurrence
                ? _value.recurrence
                : recurrence // ignore: cast_nullable_to_non_nullable
                      as RecurrenceConfig?,
            activityLog: null == activityLog
                ? _value.activityLog
                : activityLog // ignore: cast_nullable_to_non_nullable
                      as List<ActivityEntry>,
            createdAt: freezed == createdAt
                ? _value.createdAt
                : createdAt // ignore: cast_nullable_to_non_nullable
                      as DateTime?,
            updatedAt: freezed == updatedAt
                ? _value.updatedAt
                : updatedAt // ignore: cast_nullable_to_non_nullable
                      as DateTime?,
            archivedAt: freezed == archivedAt
                ? _value.archivedAt
                : archivedAt // ignore: cast_nullable_to_non_nullable
                      as DateTime?,
            version: null == version
                ? _value.version
                : version // ignore: cast_nullable_to_non_nullable
                      as int,
          )
          as $Val,
    );
  }

  /// Create a copy of TaskEntity
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $RecurrenceConfigCopyWith<$Res>? get recurrence {
    if (_value.recurrence == null) {
      return null;
    }

    return $RecurrenceConfigCopyWith<$Res>(_value.recurrence!, (value) {
      return _then(_value.copyWith(recurrence: value) as $Val);
    });
  }
}

/// @nodoc
abstract class _$$TaskEntityImplCopyWith<$Res>
    implements $TaskEntityCopyWith<$Res> {
  factory _$$TaskEntityImplCopyWith(
    _$TaskEntityImpl value,
    $Res Function(_$TaskEntityImpl) then,
  ) = __$$TaskEntityImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String id,
    String title,
    String? description,
    TaskType type,
    String workType,
    TaskStatus status,
    TaskPriority priority,
    String? branchId,
    List<String> assigneeIds,
    List<ChecklistItem> checklist,
    List<TaskAttachment> referenceAttachments,
    Map<String, dynamic> data,
    String? createdBy,
    String? assignedShiftId,
    ScheduleShift? shift,
    TaskAssignmentType assignmentType,
    DateTime? instanceDate,
    String? sourceTemplateId,
    String? recurrenceRootId,
    String? occurrenceKey,
    String? correlationId,
    DateTime? startsAt,
    DateTime? deadline,
    DateTime? missedAt,
    DateTime? cancelledAt,
    String? cancelledBy,
    TaskCancelReason? cancelReason,
    String? cancelNote,
    String? reportedIncorrectBy,
    DateTime? reportedIncorrectAt,
    String? reportedIncorrectNote,
    String? notes,
    String? proofImageUrl,
    DateTime? startedAt,
    DateTime? submittedAt,
    String? approvedBy,
    DateTime? approvedAt,
    String? rejectedBy,
    DateTime? rejectedAt,
    String? reviewNotes,
    int revisionNumber,
    bool requiresRework,
    String? rejectionReason,
    RecurrenceConfig? recurrence,
    List<ActivityEntry> activityLog,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? archivedAt,
    int version,
  });

  @override
  $RecurrenceConfigCopyWith<$Res>? get recurrence;
}

/// @nodoc
class __$$TaskEntityImplCopyWithImpl<$Res>
    extends _$TaskEntityCopyWithImpl<$Res, _$TaskEntityImpl>
    implements _$$TaskEntityImplCopyWith<$Res> {
  __$$TaskEntityImplCopyWithImpl(
    _$TaskEntityImpl _value,
    $Res Function(_$TaskEntityImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of TaskEntity
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? title = null,
    Object? description = freezed,
    Object? type = null,
    Object? workType = null,
    Object? status = null,
    Object? priority = null,
    Object? branchId = freezed,
    Object? assigneeIds = null,
    Object? checklist = null,
    Object? referenceAttachments = null,
    Object? data = null,
    Object? createdBy = freezed,
    Object? assignedShiftId = freezed,
    Object? shift = freezed,
    Object? assignmentType = null,
    Object? instanceDate = freezed,
    Object? sourceTemplateId = freezed,
    Object? recurrenceRootId = freezed,
    Object? occurrenceKey = freezed,
    Object? correlationId = freezed,
    Object? startsAt = freezed,
    Object? deadline = freezed,
    Object? missedAt = freezed,
    Object? cancelledAt = freezed,
    Object? cancelledBy = freezed,
    Object? cancelReason = freezed,
    Object? cancelNote = freezed,
    Object? reportedIncorrectBy = freezed,
    Object? reportedIncorrectAt = freezed,
    Object? reportedIncorrectNote = freezed,
    Object? notes = freezed,
    Object? proofImageUrl = freezed,
    Object? startedAt = freezed,
    Object? submittedAt = freezed,
    Object? approvedBy = freezed,
    Object? approvedAt = freezed,
    Object? rejectedBy = freezed,
    Object? rejectedAt = freezed,
    Object? reviewNotes = freezed,
    Object? revisionNumber = null,
    Object? requiresRework = null,
    Object? rejectionReason = freezed,
    Object? recurrence = freezed,
    Object? activityLog = null,
    Object? createdAt = freezed,
    Object? updatedAt = freezed,
    Object? archivedAt = freezed,
    Object? version = null,
  }) {
    return _then(
      _$TaskEntityImpl(
        id: null == id
            ? _value.id
            : id // ignore: cast_nullable_to_non_nullable
                  as String,
        title: null == title
            ? _value.title
            : title // ignore: cast_nullable_to_non_nullable
                  as String,
        description: freezed == description
            ? _value.description
            : description // ignore: cast_nullable_to_non_nullable
                  as String?,
        type: null == type
            ? _value.type
            : type // ignore: cast_nullable_to_non_nullable
                  as TaskType,
        workType: null == workType
            ? _value.workType
            : workType // ignore: cast_nullable_to_non_nullable
                  as String,
        status: null == status
            ? _value.status
            : status // ignore: cast_nullable_to_non_nullable
                  as TaskStatus,
        priority: null == priority
            ? _value.priority
            : priority // ignore: cast_nullable_to_non_nullable
                  as TaskPriority,
        branchId: freezed == branchId
            ? _value.branchId
            : branchId // ignore: cast_nullable_to_non_nullable
                  as String?,
        assigneeIds: null == assigneeIds
            ? _value._assigneeIds
            : assigneeIds // ignore: cast_nullable_to_non_nullable
                  as List<String>,
        checklist: null == checklist
            ? _value._checklist
            : checklist // ignore: cast_nullable_to_non_nullable
                  as List<ChecklistItem>,
        referenceAttachments: null == referenceAttachments
            ? _value._referenceAttachments
            : referenceAttachments // ignore: cast_nullable_to_non_nullable
                  as List<TaskAttachment>,
        data: null == data
            ? _value._data
            : data // ignore: cast_nullable_to_non_nullable
                  as Map<String, dynamic>,
        createdBy: freezed == createdBy
            ? _value.createdBy
            : createdBy // ignore: cast_nullable_to_non_nullable
                  as String?,
        assignedShiftId: freezed == assignedShiftId
            ? _value.assignedShiftId
            : assignedShiftId // ignore: cast_nullable_to_non_nullable
                  as String?,
        shift: freezed == shift
            ? _value.shift
            : shift // ignore: cast_nullable_to_non_nullable
                  as ScheduleShift?,
        assignmentType: null == assignmentType
            ? _value.assignmentType
            : assignmentType // ignore: cast_nullable_to_non_nullable
                  as TaskAssignmentType,
        instanceDate: freezed == instanceDate
            ? _value.instanceDate
            : instanceDate // ignore: cast_nullable_to_non_nullable
                  as DateTime?,
        sourceTemplateId: freezed == sourceTemplateId
            ? _value.sourceTemplateId
            : sourceTemplateId // ignore: cast_nullable_to_non_nullable
                  as String?,
        recurrenceRootId: freezed == recurrenceRootId
            ? _value.recurrenceRootId
            : recurrenceRootId // ignore: cast_nullable_to_non_nullable
                  as String?,
        occurrenceKey: freezed == occurrenceKey
            ? _value.occurrenceKey
            : occurrenceKey // ignore: cast_nullable_to_non_nullable
                  as String?,
        correlationId: freezed == correlationId
            ? _value.correlationId
            : correlationId // ignore: cast_nullable_to_non_nullable
                  as String?,
        startsAt: freezed == startsAt
            ? _value.startsAt
            : startsAt // ignore: cast_nullable_to_non_nullable
                  as DateTime?,
        deadline: freezed == deadline
            ? _value.deadline
            : deadline // ignore: cast_nullable_to_non_nullable
                  as DateTime?,
        missedAt: freezed == missedAt
            ? _value.missedAt
            : missedAt // ignore: cast_nullable_to_non_nullable
                  as DateTime?,
        cancelledAt: freezed == cancelledAt
            ? _value.cancelledAt
            : cancelledAt // ignore: cast_nullable_to_non_nullable
                  as DateTime?,
        cancelledBy: freezed == cancelledBy
            ? _value.cancelledBy
            : cancelledBy // ignore: cast_nullable_to_non_nullable
                  as String?,
        cancelReason: freezed == cancelReason
            ? _value.cancelReason
            : cancelReason // ignore: cast_nullable_to_non_nullable
                  as TaskCancelReason?,
        cancelNote: freezed == cancelNote
            ? _value.cancelNote
            : cancelNote // ignore: cast_nullable_to_non_nullable
                  as String?,
        reportedIncorrectBy: freezed == reportedIncorrectBy
            ? _value.reportedIncorrectBy
            : reportedIncorrectBy // ignore: cast_nullable_to_non_nullable
                  as String?,
        reportedIncorrectAt: freezed == reportedIncorrectAt
            ? _value.reportedIncorrectAt
            : reportedIncorrectAt // ignore: cast_nullable_to_non_nullable
                  as DateTime?,
        reportedIncorrectNote: freezed == reportedIncorrectNote
            ? _value.reportedIncorrectNote
            : reportedIncorrectNote // ignore: cast_nullable_to_non_nullable
                  as String?,
        notes: freezed == notes
            ? _value.notes
            : notes // ignore: cast_nullable_to_non_nullable
                  as String?,
        proofImageUrl: freezed == proofImageUrl
            ? _value.proofImageUrl
            : proofImageUrl // ignore: cast_nullable_to_non_nullable
                  as String?,
        startedAt: freezed == startedAt
            ? _value.startedAt
            : startedAt // ignore: cast_nullable_to_non_nullable
                  as DateTime?,
        submittedAt: freezed == submittedAt
            ? _value.submittedAt
            : submittedAt // ignore: cast_nullable_to_non_nullable
                  as DateTime?,
        approvedBy: freezed == approvedBy
            ? _value.approvedBy
            : approvedBy // ignore: cast_nullable_to_non_nullable
                  as String?,
        approvedAt: freezed == approvedAt
            ? _value.approvedAt
            : approvedAt // ignore: cast_nullable_to_non_nullable
                  as DateTime?,
        rejectedBy: freezed == rejectedBy
            ? _value.rejectedBy
            : rejectedBy // ignore: cast_nullable_to_non_nullable
                  as String?,
        rejectedAt: freezed == rejectedAt
            ? _value.rejectedAt
            : rejectedAt // ignore: cast_nullable_to_non_nullable
                  as DateTime?,
        reviewNotes: freezed == reviewNotes
            ? _value.reviewNotes
            : reviewNotes // ignore: cast_nullable_to_non_nullable
                  as String?,
        revisionNumber: null == revisionNumber
            ? _value.revisionNumber
            : revisionNumber // ignore: cast_nullable_to_non_nullable
                  as int,
        requiresRework: null == requiresRework
            ? _value.requiresRework
            : requiresRework // ignore: cast_nullable_to_non_nullable
                  as bool,
        rejectionReason: freezed == rejectionReason
            ? _value.rejectionReason
            : rejectionReason // ignore: cast_nullable_to_non_nullable
                  as String?,
        recurrence: freezed == recurrence
            ? _value.recurrence
            : recurrence // ignore: cast_nullable_to_non_nullable
                  as RecurrenceConfig?,
        activityLog: null == activityLog
            ? _value._activityLog
            : activityLog // ignore: cast_nullable_to_non_nullable
                  as List<ActivityEntry>,
        createdAt: freezed == createdAt
            ? _value.createdAt
            : createdAt // ignore: cast_nullable_to_non_nullable
                  as DateTime?,
        updatedAt: freezed == updatedAt
            ? _value.updatedAt
            : updatedAt // ignore: cast_nullable_to_non_nullable
                  as DateTime?,
        archivedAt: freezed == archivedAt
            ? _value.archivedAt
            : archivedAt // ignore: cast_nullable_to_non_nullable
                  as DateTime?,
        version: null == version
            ? _value.version
            : version // ignore: cast_nullable_to_non_nullable
                  as int,
      ),
    );
  }
}

/// @nodoc

class _$TaskEntityImpl extends _TaskEntity {
  const _$TaskEntityImpl({
    required this.id,
    required this.title,
    this.description,
    this.type = TaskType.daily,
    this.workType = 'general',
    this.status = TaskStatus.pending,
    this.priority = TaskPriority.normal,
    this.branchId,
    final List<String> assigneeIds = const <String>[],
    final List<ChecklistItem> checklist = const <ChecklistItem>[],
    final List<TaskAttachment> referenceAttachments = const <TaskAttachment>[],
    final Map<String, dynamic> data = const <String, dynamic>{},
    this.createdBy,
    this.assignedShiftId,
    this.shift,
    this.assignmentType = TaskAssignmentType.individual,
    this.instanceDate,
    this.sourceTemplateId,
    this.recurrenceRootId,
    this.occurrenceKey,
    this.correlationId,
    this.startsAt,
    this.deadline,
    this.missedAt,
    this.cancelledAt,
    this.cancelledBy,
    this.cancelReason,
    this.cancelNote,
    this.reportedIncorrectBy,
    this.reportedIncorrectAt,
    this.reportedIncorrectNote,
    this.notes,
    this.proofImageUrl,
    this.startedAt,
    this.submittedAt,
    this.approvedBy,
    this.approvedAt,
    this.rejectedBy,
    this.rejectedAt,
    this.reviewNotes,
    this.revisionNumber = 0,
    this.requiresRework = false,
    this.rejectionReason,
    this.recurrence,
    final List<ActivityEntry> activityLog = const <ActivityEntry>[],
    this.createdAt,
    this.updatedAt,
    this.archivedAt,
    this.version = 0,
  }) : _assigneeIds = assigneeIds,
       _checklist = checklist,
       _referenceAttachments = referenceAttachments,
       _data = data,
       _activityLog = activityLog,
       super._();

  @override
  final String id;
  @override
  final String title;
  @override
  final String? description;
  @override
  @JsonKey()
  final TaskType type;

  /// The **operational kind** of this work (Registry-backed — see
  /// `WorkTypeRegistry`). A stable string id (`general`, `transfer`,
  /// `purchaseErrand`, `inventoryCount`, `inspection`, …) resolved to a
  /// `WorkTypeDefinition` that owns this task's dynamic fields, milestones,
  /// completion gate, review disposition and analytics. Orthogonal to [type]
  /// (`daily`/`special`), which is a cadence tag. A missing / unknown id
  /// resolves to `general`, so old docs and rolled-back types never break (see
  /// the `TaskWorkX` adapter). Defaults to `general` for every task that
  /// predates work types — no migration needed.
  @override
  @JsonKey()
  final String workType;
  @override
  @JsonKey()
  final TaskStatus status;
  @override
  @JsonKey()
  final TaskPriority priority;

  /// Owning branch (admin: any · manager: own branch).
  @override
  final String? branchId;

  /// Employees assigned to execute the task (Phase 9 — multi-assignee). Empty
  /// while unassigned. Supersedes the legacy single `assignedEmployeeId`.
  final List<String> _assigneeIds;

  /// Employees assigned to execute the task (Phase 9 — multi-assignee). Empty
  /// while unassigned. Supersedes the legacy single `assignedEmployeeId`.
  @override
  @JsonKey()
  List<String> get assigneeIds {
    if (_assigneeIds is EqualUnmodifiableListView) return _assigneeIds;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_assigneeIds);
  }

  /// Checklist the employee must work through (generated from a template).
  final List<ChecklistItem> _checklist;

  /// Checklist the employee must work through (generated from a template).
  @override
  @JsonKey()
  List<ChecklistItem> get checklist {
    if (_checklist is EqualUnmodifiableListView) return _checklist;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_checklist);
  }

  /// Reference images attached by the manager/admin when creating/editing the
  /// task — "what good looks like" / context the employee sees **before** doing
  /// the work. Distinct from employee *proof* media, which lives on the
  /// submission [ActivityEntry] (and the legacy [proofImageUrl]). Stored in
  /// Storage at `tasks/{id}/attachments/{attId}.<ext>` like all task media.
  final List<TaskAttachment> _referenceAttachments;

  /// Reference images attached by the manager/admin when creating/editing the
  /// task — "what good looks like" / context the employee sees **before** doing
  /// the work. Distinct from employee *proof* media, which lives on the
  /// submission [ActivityEntry] (and the legacy [proofImageUrl]). Stored in
  /// Storage at `tasks/{id}/attachments/{attId}.<ext>` like all task media.
  @override
  @JsonKey()
  List<TaskAttachment> get referenceAttachments {
    if (_referenceAttachments is EqualUnmodifiableListView)
      return _referenceAttachments;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_referenceAttachments);
  }

  /// Schema-driven values for this work type's dynamic fields, keyed by
  /// `WorkFieldSpec.key` (e.g. an inventory count's `expectedQty`/`countedQty`,
  /// a purchase's `budget`/`spentAmount`, an inspection's per-point `results`).
  /// Empty for a general task. Persists at `tasks/{id}.data`; the model
  /// converts any `DateTime` values to/from `Timestamp` on the boundary.
  final Map<String, dynamic> _data;

  /// Schema-driven values for this work type's dynamic fields, keyed by
  /// `WorkFieldSpec.key` (e.g. an inventory count's `expectedQty`/`countedQty`,
  /// a purchase's `budget`/`spentAmount`, an inspection's per-point `results`).
  /// Empty for a general task. Persists at `tasks/{id}.data`; the model
  /// converts any `DateTime` values to/from `Timestamp` on the boundary.
  @override
  @JsonKey()
  Map<String, dynamic> get data {
    if (_data is EqualUnmodifiableMapView) return _data;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(_data);
  }

  /// uid of the manager/admin who created the task.
  @override
  final String? createdBy;

  /// Optional shift this task belongs to (references `shifts/{shiftId}`).
  @override
  final String? assignedShiftId;

  /// The operational shift this task belongs to (Branch Operations) —
  /// `morning` / `night`, or **null** when the task is not shift-specific
  /// ("any", applies under every shift filter). Drives the Branch Operations
  /// shift filter; supersedes the unused legacy [assignedShiftId] string. When
  /// [assignmentType] is [TaskAssignmentType.shift] this is also the actual
  /// assignment target (see `canUserAccessTask`), not just a filter tag.
  @override
  final ScheduleShift? shift;

  /// How this task is assigned. `individual`/`team` both read [assigneeIds];
  /// `shift` leaves [assigneeIds] empty and targets whoever is rostered on
  /// [shift] for [instanceDate] instead. Missing on any task written before
  /// this field existed → [TaskAssignmentType.individual] (no migration
  /// needed; see `TaskModel.fromMap`).
  @override
  @JsonKey()
  final TaskAssignmentType assignmentType;

  /// The calendar day a shift-assigned instance is *for* — distinct from
  /// [deadline] (which may carry a specific time of day). Null for
  /// individual/team tasks and for any task predating shift assignment.
  @override
  final DateTime? instanceDate;

  /// Links a shift instance back to the [RecurringTaskTemplateEntity] that
  /// generated it (`generateShiftTaskInstances` Cloud Function). Null for
  /// one-off tasks and for every task predating recurring shift templates.
  @override
  final String? sourceTemplateId;

  /// Stable lineage id for a **per-task recurrence** chain (Path B). Set on
  /// every auto-spawned successor to the id of the chain's *root* task (the
  /// first, manually-created one), so an admin can group / query a whole
  /// recurring lineage. Null on a one-off task and on the root itself until it
  /// spawns. Additive — no migration. See `TaskCubit._spawnNextRecurrence`.
  @override
  final String? recurrenceRootId;

  /// The occurrence this auto-spawned task is *for* — the successor's due-date
  /// key (`yyyy-MM-dd`), stored for display/debugging in the Automation Center.
  /// Distinct from the **document id**, which is the deterministic idempotency
  /// key `rec_{sourceTaskId}` (each task spawns at most one successor, so the
  /// successor keys off the current task id and never off a possibly-null
  /// deadline). Null for non-recurring tasks. Additive — no migration.
  @override
  final String? occurrenceKey;

  /// The automation-execution **correlation id** (`AUT-{yyyymmdd}-{hash}`) that
  /// created this task, shared with the run record, its notifications and its
  /// audit entries so the task can be traced back to the whole execution.
  /// Server-stamped by `generateShiftTaskInstances`; null for any task not
  /// produced by a recurring shift automation. Additive — no migration.
  @override
  final String? correlationId;

  /// When the task is scheduled to **start** (Task Scheduling V2). Pre-filled
  /// from the assigned shift's hours as a *smart default* the manager can
  /// override; null on tasks predating scheduling (unknown start). Additive —
  /// no migration. See [dueAt] for the due side and `task_schedule.dart` for
  /// the derived [TaskSchedulePhase] (Scheduled → Active → Due-soon → Overdue).
  @override
  final DateTime? startsAt;

  /// When the task becomes **due / overdue** — the canonical due timestamp,
  /// exposed as [dueAt]. Kept named `deadline` for backward compatibility (all
  /// existing reads + old Firestore docs are unchanged).
  @override
  final DateTime? deadline;

  /// When a recurring shift task was automatically ended because its shift
  /// deadline passed before the work was completed. Written only by the
  /// server-side automation sweep; null for every task that has not missed
  /// its shift window. Additive — old task documents remain valid.
  @override
  final DateTime? missedAt;
  // ─── Cancellation (Automated Tasks spec §5) ──────────────────
  /// When a manager/admin cancelled the task, and who. Cancellation is a
  /// terminal **business decision** — the work will not be done — taken from
  /// `pending` or `started` only, and it is neither success nor failure for
  /// reporting (§8). Null on every task that was never cancelled. Additive —
  /// old task documents remain valid.
  @override
  final DateTime? cancelledAt;
  @override
  final String? cancelledBy;

  /// The mandatory structured reason (§5.5). Always set on a cancelled task;
  /// null otherwise. **Immutable once written** (frozen in `firestore.rules`)
  /// so reporting by reason code stays historically honest.
  @override
  final TaskCancelReason? cancelReason;

  /// Optional free-text note accompanying [cancelReason]. Never a substitute
  /// for the code — it exists to add context a picklist can't carry.
  @override
  final String? cancelNote;
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
  @override
  final String? reportedIncorrectBy;
  @override
  final DateTime? reportedIncorrectAt;
  @override
  final String? reportedIncorrectNote;

  /// Free-text notes added by the executing employee.
  @override
  final String? notes;

  /// Download URL of the proof image the employee uploads on completion.
  @override
  final String? proofImageUrl;
  // ─── Lifecycle timestamps (one per status transition, set atomically) ───
  /// When an employee first started the task.
  @override
  final DateTime? startedAt;

  /// When the employee submitted for review (via completeAndSubmit or submitForReview).
  @override
  final DateTime? submittedAt;
  // ─── Review audit fields ─────────────────────────────────────
  /// uid of the manager/admin who approved the task, + when.
  @override
  final String? approvedBy;
  @override
  final DateTime? approvedAt;

  /// uid of the manager/admin who rejected the task, + when.
  @override
  final String? rejectedBy;
  @override
  final DateTime? rejectedAt;

  /// Reviewer's note left on approve/reject.
  @override
  final String? reviewNotes;
  // ─── Rework distinction (Notification System Phase 1) ─────────
  /// How many times this task has been sent back for rework. 0 = a new task,
  /// 1 = first rework, 2 = second, … Incremented only by "Request Rework"
  /// (not by a terminal "Reject"). Drives the `REWORK #n` badge + payload.
  @override
  @JsonKey()
  final int revisionNumber;

  /// True while the task is awaiting a redo after a rework request; cleared
  /// when the employee resubmits. Distinguishes a rework loop from a plain
  /// rejection / new task.
  @override
  @JsonKey()
  final bool requiresRework;

  /// The reviewer's reason captured on the last rework / reject decision
  /// (shown to the employee + carried in the notification body).
  @override
  final String? rejectionReason;

  /// Recurrence rule — null means "one-off" (does not repeat). When set, the
  /// [TaskCubit] auto-creates the next instance after this task is approved.
  @override
  final RecurrenceConfig? recurrence;

  /// Activity timeline: one entry per status transition, ordered oldest→newest.
  final List<ActivityEntry> _activityLog;

  /// Activity timeline: one entry per status transition, ordered oldest→newest.
  @override
  @JsonKey()
  List<ActivityEntry> get activityLog {
    if (_activityLog is EqualUnmodifiableListView) return _activityLog;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_activityLog);
  }

  @override
  final DateTime? createdAt;
  @override
  final DateTime? updatedAt;

  /// When the task was archived by the retention pass (`taskHousekeeping`
  /// Cloud Function) — set only on an `approved` task older than the branch's
  /// `archiveAfterDays`. Null = live. Server-managed: the function stamps it
  /// via the Admin SDK; the client only ever *reads* it (to filter archived
  /// work out of active views) or *clears* it on an admin reopen. An archived
  /// task is still a full record in `tasks` (soft archive — never deleted
  /// unless a retention `deleteAfterDays` is explicitly configured), so
  /// statistics and deep-links keep working.
  @override
  final DateTime? archivedAt;

  /// Optimistic-concurrency counter, bumped by the server-authoritative
  /// transition path (`TaskRepository.transitionTask`) on every lifecycle move.
  /// A plain content edit never writes it. Additive — missing on any doc
  /// predating it → 0 (no migration). Not persisted by `TaskModel.toMap` (the
  /// transaction owns it, exactly like `createdAt`/`updatedAt`), so a stale
  /// client edit can never regress it. Read-only to the UI.
  @override
  @JsonKey()
  final int version;

  @override
  String toString() {
    return 'TaskEntity(id: $id, title: $title, description: $description, type: $type, workType: $workType, status: $status, priority: $priority, branchId: $branchId, assigneeIds: $assigneeIds, checklist: $checklist, referenceAttachments: $referenceAttachments, data: $data, createdBy: $createdBy, assignedShiftId: $assignedShiftId, shift: $shift, assignmentType: $assignmentType, instanceDate: $instanceDate, sourceTemplateId: $sourceTemplateId, recurrenceRootId: $recurrenceRootId, occurrenceKey: $occurrenceKey, correlationId: $correlationId, startsAt: $startsAt, deadline: $deadline, missedAt: $missedAt, cancelledAt: $cancelledAt, cancelledBy: $cancelledBy, cancelReason: $cancelReason, cancelNote: $cancelNote, reportedIncorrectBy: $reportedIncorrectBy, reportedIncorrectAt: $reportedIncorrectAt, reportedIncorrectNote: $reportedIncorrectNote, notes: $notes, proofImageUrl: $proofImageUrl, startedAt: $startedAt, submittedAt: $submittedAt, approvedBy: $approvedBy, approvedAt: $approvedAt, rejectedBy: $rejectedBy, rejectedAt: $rejectedAt, reviewNotes: $reviewNotes, revisionNumber: $revisionNumber, requiresRework: $requiresRework, rejectionReason: $rejectionReason, recurrence: $recurrence, activityLog: $activityLog, createdAt: $createdAt, updatedAt: $updatedAt, archivedAt: $archivedAt, version: $version)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$TaskEntityImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.title, title) || other.title == title) &&
            (identical(other.description, description) ||
                other.description == description) &&
            (identical(other.type, type) || other.type == type) &&
            (identical(other.workType, workType) ||
                other.workType == workType) &&
            (identical(other.status, status) || other.status == status) &&
            (identical(other.priority, priority) ||
                other.priority == priority) &&
            (identical(other.branchId, branchId) ||
                other.branchId == branchId) &&
            const DeepCollectionEquality().equals(
              other._assigneeIds,
              _assigneeIds,
            ) &&
            const DeepCollectionEquality().equals(
              other._checklist,
              _checklist,
            ) &&
            const DeepCollectionEquality().equals(
              other._referenceAttachments,
              _referenceAttachments,
            ) &&
            const DeepCollectionEquality().equals(other._data, _data) &&
            (identical(other.createdBy, createdBy) ||
                other.createdBy == createdBy) &&
            (identical(other.assignedShiftId, assignedShiftId) ||
                other.assignedShiftId == assignedShiftId) &&
            (identical(other.shift, shift) || other.shift == shift) &&
            (identical(other.assignmentType, assignmentType) ||
                other.assignmentType == assignmentType) &&
            (identical(other.instanceDate, instanceDate) ||
                other.instanceDate == instanceDate) &&
            (identical(other.sourceTemplateId, sourceTemplateId) ||
                other.sourceTemplateId == sourceTemplateId) &&
            (identical(other.recurrenceRootId, recurrenceRootId) ||
                other.recurrenceRootId == recurrenceRootId) &&
            (identical(other.occurrenceKey, occurrenceKey) ||
                other.occurrenceKey == occurrenceKey) &&
            (identical(other.correlationId, correlationId) ||
                other.correlationId == correlationId) &&
            (identical(other.startsAt, startsAt) ||
                other.startsAt == startsAt) &&
            (identical(other.deadline, deadline) ||
                other.deadline == deadline) &&
            (identical(other.missedAt, missedAt) ||
                other.missedAt == missedAt) &&
            (identical(other.cancelledAt, cancelledAt) ||
                other.cancelledAt == cancelledAt) &&
            (identical(other.cancelledBy, cancelledBy) ||
                other.cancelledBy == cancelledBy) &&
            (identical(other.cancelReason, cancelReason) ||
                other.cancelReason == cancelReason) &&
            (identical(other.cancelNote, cancelNote) ||
                other.cancelNote == cancelNote) &&
            (identical(other.reportedIncorrectBy, reportedIncorrectBy) ||
                other.reportedIncorrectBy == reportedIncorrectBy) &&
            (identical(other.reportedIncorrectAt, reportedIncorrectAt) ||
                other.reportedIncorrectAt == reportedIncorrectAt) &&
            (identical(other.reportedIncorrectNote, reportedIncorrectNote) ||
                other.reportedIncorrectNote == reportedIncorrectNote) &&
            (identical(other.notes, notes) || other.notes == notes) &&
            (identical(other.proofImageUrl, proofImageUrl) ||
                other.proofImageUrl == proofImageUrl) &&
            (identical(other.startedAt, startedAt) ||
                other.startedAt == startedAt) &&
            (identical(other.submittedAt, submittedAt) ||
                other.submittedAt == submittedAt) &&
            (identical(other.approvedBy, approvedBy) ||
                other.approvedBy == approvedBy) &&
            (identical(other.approvedAt, approvedAt) ||
                other.approvedAt == approvedAt) &&
            (identical(other.rejectedBy, rejectedBy) ||
                other.rejectedBy == rejectedBy) &&
            (identical(other.rejectedAt, rejectedAt) ||
                other.rejectedAt == rejectedAt) &&
            (identical(other.reviewNotes, reviewNotes) ||
                other.reviewNotes == reviewNotes) &&
            (identical(other.revisionNumber, revisionNumber) ||
                other.revisionNumber == revisionNumber) &&
            (identical(other.requiresRework, requiresRework) ||
                other.requiresRework == requiresRework) &&
            (identical(other.rejectionReason, rejectionReason) ||
                other.rejectionReason == rejectionReason) &&
            (identical(other.recurrence, recurrence) ||
                other.recurrence == recurrence) &&
            const DeepCollectionEquality().equals(
              other._activityLog,
              _activityLog,
            ) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt) &&
            (identical(other.updatedAt, updatedAt) ||
                other.updatedAt == updatedAt) &&
            (identical(other.archivedAt, archivedAt) ||
                other.archivedAt == archivedAt) &&
            (identical(other.version, version) || other.version == version));
  }

  @override
  int get hashCode => Object.hashAll([
    runtimeType,
    id,
    title,
    description,
    type,
    workType,
    status,
    priority,
    branchId,
    const DeepCollectionEquality().hash(_assigneeIds),
    const DeepCollectionEquality().hash(_checklist),
    const DeepCollectionEquality().hash(_referenceAttachments),
    const DeepCollectionEquality().hash(_data),
    createdBy,
    assignedShiftId,
    shift,
    assignmentType,
    instanceDate,
    sourceTemplateId,
    recurrenceRootId,
    occurrenceKey,
    correlationId,
    startsAt,
    deadline,
    missedAt,
    cancelledAt,
    cancelledBy,
    cancelReason,
    cancelNote,
    reportedIncorrectBy,
    reportedIncorrectAt,
    reportedIncorrectNote,
    notes,
    proofImageUrl,
    startedAt,
    submittedAt,
    approvedBy,
    approvedAt,
    rejectedBy,
    rejectedAt,
    reviewNotes,
    revisionNumber,
    requiresRework,
    rejectionReason,
    recurrence,
    const DeepCollectionEquality().hash(_activityLog),
    createdAt,
    updatedAt,
    archivedAt,
    version,
  ]);

  /// Create a copy of TaskEntity
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$TaskEntityImplCopyWith<_$TaskEntityImpl> get copyWith =>
      __$$TaskEntityImplCopyWithImpl<_$TaskEntityImpl>(this, _$identity);
}

abstract class _TaskEntity extends TaskEntity {
  const factory _TaskEntity({
    required final String id,
    required final String title,
    final String? description,
    final TaskType type,
    final String workType,
    final TaskStatus status,
    final TaskPriority priority,
    final String? branchId,
    final List<String> assigneeIds,
    final List<ChecklistItem> checklist,
    final List<TaskAttachment> referenceAttachments,
    final Map<String, dynamic> data,
    final String? createdBy,
    final String? assignedShiftId,
    final ScheduleShift? shift,
    final TaskAssignmentType assignmentType,
    final DateTime? instanceDate,
    final String? sourceTemplateId,
    final String? recurrenceRootId,
    final String? occurrenceKey,
    final String? correlationId,
    final DateTime? startsAt,
    final DateTime? deadline,
    final DateTime? missedAt,
    final DateTime? cancelledAt,
    final String? cancelledBy,
    final TaskCancelReason? cancelReason,
    final String? cancelNote,
    final String? reportedIncorrectBy,
    final DateTime? reportedIncorrectAt,
    final String? reportedIncorrectNote,
    final String? notes,
    final String? proofImageUrl,
    final DateTime? startedAt,
    final DateTime? submittedAt,
    final String? approvedBy,
    final DateTime? approvedAt,
    final String? rejectedBy,
    final DateTime? rejectedAt,
    final String? reviewNotes,
    final int revisionNumber,
    final bool requiresRework,
    final String? rejectionReason,
    final RecurrenceConfig? recurrence,
    final List<ActivityEntry> activityLog,
    final DateTime? createdAt,
    final DateTime? updatedAt,
    final DateTime? archivedAt,
    final int version,
  }) = _$TaskEntityImpl;
  const _TaskEntity._() : super._();

  @override
  String get id;
  @override
  String get title;
  @override
  String? get description;
  @override
  TaskType get type;

  /// The **operational kind** of this work (Registry-backed — see
  /// `WorkTypeRegistry`). A stable string id (`general`, `transfer`,
  /// `purchaseErrand`, `inventoryCount`, `inspection`, …) resolved to a
  /// `WorkTypeDefinition` that owns this task's dynamic fields, milestones,
  /// completion gate, review disposition and analytics. Orthogonal to [type]
  /// (`daily`/`special`), which is a cadence tag. A missing / unknown id
  /// resolves to `general`, so old docs and rolled-back types never break (see
  /// the `TaskWorkX` adapter). Defaults to `general` for every task that
  /// predates work types — no migration needed.
  @override
  String get workType;
  @override
  TaskStatus get status;
  @override
  TaskPriority get priority;

  /// Owning branch (admin: any · manager: own branch).
  @override
  String? get branchId;

  /// Employees assigned to execute the task (Phase 9 — multi-assignee). Empty
  /// while unassigned. Supersedes the legacy single `assignedEmployeeId`.
  @override
  List<String> get assigneeIds;

  /// Checklist the employee must work through (generated from a template).
  @override
  List<ChecklistItem> get checklist;

  /// Reference images attached by the manager/admin when creating/editing the
  /// task — "what good looks like" / context the employee sees **before** doing
  /// the work. Distinct from employee *proof* media, which lives on the
  /// submission [ActivityEntry] (and the legacy [proofImageUrl]). Stored in
  /// Storage at `tasks/{id}/attachments/{attId}.<ext>` like all task media.
  @override
  List<TaskAttachment> get referenceAttachments;

  /// Schema-driven values for this work type's dynamic fields, keyed by
  /// `WorkFieldSpec.key` (e.g. an inventory count's `expectedQty`/`countedQty`,
  /// a purchase's `budget`/`spentAmount`, an inspection's per-point `results`).
  /// Empty for a general task. Persists at `tasks/{id}.data`; the model
  /// converts any `DateTime` values to/from `Timestamp` on the boundary.
  @override
  Map<String, dynamic> get data;

  /// uid of the manager/admin who created the task.
  @override
  String? get createdBy;

  /// Optional shift this task belongs to (references `shifts/{shiftId}`).
  @override
  String? get assignedShiftId;

  /// The operational shift this task belongs to (Branch Operations) —
  /// `morning` / `night`, or **null** when the task is not shift-specific
  /// ("any", applies under every shift filter). Drives the Branch Operations
  /// shift filter; supersedes the unused legacy [assignedShiftId] string. When
  /// [assignmentType] is [TaskAssignmentType.shift] this is also the actual
  /// assignment target (see `canUserAccessTask`), not just a filter tag.
  @override
  ScheduleShift? get shift;

  /// How this task is assigned. `individual`/`team` both read [assigneeIds];
  /// `shift` leaves [assigneeIds] empty and targets whoever is rostered on
  /// [shift] for [instanceDate] instead. Missing on any task written before
  /// this field existed → [TaskAssignmentType.individual] (no migration
  /// needed; see `TaskModel.fromMap`).
  @override
  TaskAssignmentType get assignmentType;

  /// The calendar day a shift-assigned instance is *for* — distinct from
  /// [deadline] (which may carry a specific time of day). Null for
  /// individual/team tasks and for any task predating shift assignment.
  @override
  DateTime? get instanceDate;

  /// Links a shift instance back to the [RecurringTaskTemplateEntity] that
  /// generated it (`generateShiftTaskInstances` Cloud Function). Null for
  /// one-off tasks and for every task predating recurring shift templates.
  @override
  String? get sourceTemplateId;

  /// Stable lineage id for a **per-task recurrence** chain (Path B). Set on
  /// every auto-spawned successor to the id of the chain's *root* task (the
  /// first, manually-created one), so an admin can group / query a whole
  /// recurring lineage. Null on a one-off task and on the root itself until it
  /// spawns. Additive — no migration. See `TaskCubit._spawnNextRecurrence`.
  @override
  String? get recurrenceRootId;

  /// The occurrence this auto-spawned task is *for* — the successor's due-date
  /// key (`yyyy-MM-dd`), stored for display/debugging in the Automation Center.
  /// Distinct from the **document id**, which is the deterministic idempotency
  /// key `rec_{sourceTaskId}` (each task spawns at most one successor, so the
  /// successor keys off the current task id and never off a possibly-null
  /// deadline). Null for non-recurring tasks. Additive — no migration.
  @override
  String? get occurrenceKey;

  /// The automation-execution **correlation id** (`AUT-{yyyymmdd}-{hash}`) that
  /// created this task, shared with the run record, its notifications and its
  /// audit entries so the task can be traced back to the whole execution.
  /// Server-stamped by `generateShiftTaskInstances`; null for any task not
  /// produced by a recurring shift automation. Additive — no migration.
  @override
  String? get correlationId;

  /// When the task is scheduled to **start** (Task Scheduling V2). Pre-filled
  /// from the assigned shift's hours as a *smart default* the manager can
  /// override; null on tasks predating scheduling (unknown start). Additive —
  /// no migration. See [dueAt] for the due side and `task_schedule.dart` for
  /// the derived [TaskSchedulePhase] (Scheduled → Active → Due-soon → Overdue).
  @override
  DateTime? get startsAt;

  /// When the task becomes **due / overdue** — the canonical due timestamp,
  /// exposed as [dueAt]. Kept named `deadline` for backward compatibility (all
  /// existing reads + old Firestore docs are unchanged).
  @override
  DateTime? get deadline;

  /// When a recurring shift task was automatically ended because its shift
  /// deadline passed before the work was completed. Written only by the
  /// server-side automation sweep; null for every task that has not missed
  /// its shift window. Additive — old task documents remain valid.
  @override
  DateTime? get missedAt; // ─── Cancellation (Automated Tasks spec §5) ──────────────────
  /// When a manager/admin cancelled the task, and who. Cancellation is a
  /// terminal **business decision** — the work will not be done — taken from
  /// `pending` or `started` only, and it is neither success nor failure for
  /// reporting (§8). Null on every task that was never cancelled. Additive —
  /// old task documents remain valid.
  @override
  DateTime? get cancelledAt;
  @override
  String? get cancelledBy;

  /// The mandatory structured reason (§5.5). Always set on a cancelled task;
  /// null otherwise. **Immutable once written** (frozen in `firestore.rules`)
  /// so reporting by reason code stays historically honest.
  @override
  TaskCancelReason? get cancelReason;

  /// Optional free-text note accompanying [cancelReason]. Never a substitute
  /// for the code — it exists to add context a picklist can't carry.
  @override
  String? get cancelNote; // ─── Reported incorrect (Automated Tasks spec §5.2) ───────────
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
  @override
  String? get reportedIncorrectBy;
  @override
  DateTime? get reportedIncorrectAt;
  @override
  String? get reportedIncorrectNote;

  /// Free-text notes added by the executing employee.
  @override
  String? get notes;

  /// Download URL of the proof image the employee uploads on completion.
  @override
  String? get proofImageUrl; // ─── Lifecycle timestamps (one per status transition, set atomically) ───
  /// When an employee first started the task.
  @override
  DateTime? get startedAt;

  /// When the employee submitted for review (via completeAndSubmit or submitForReview).
  @override
  DateTime? get submittedAt; // ─── Review audit fields ─────────────────────────────────────
  /// uid of the manager/admin who approved the task, + when.
  @override
  String? get approvedBy;
  @override
  DateTime? get approvedAt;

  /// uid of the manager/admin who rejected the task, + when.
  @override
  String? get rejectedBy;
  @override
  DateTime? get rejectedAt;

  /// Reviewer's note left on approve/reject.
  @override
  String? get reviewNotes; // ─── Rework distinction (Notification System Phase 1) ─────────
  /// How many times this task has been sent back for rework. 0 = a new task,
  /// 1 = first rework, 2 = second, … Incremented only by "Request Rework"
  /// (not by a terminal "Reject"). Drives the `REWORK #n` badge + payload.
  @override
  int get revisionNumber;

  /// True while the task is awaiting a redo after a rework request; cleared
  /// when the employee resubmits. Distinguishes a rework loop from a plain
  /// rejection / new task.
  @override
  bool get requiresRework;

  /// The reviewer's reason captured on the last rework / reject decision
  /// (shown to the employee + carried in the notification body).
  @override
  String? get rejectionReason;

  /// Recurrence rule — null means "one-off" (does not repeat). When set, the
  /// [TaskCubit] auto-creates the next instance after this task is approved.
  @override
  RecurrenceConfig? get recurrence;

  /// Activity timeline: one entry per status transition, ordered oldest→newest.
  @override
  List<ActivityEntry> get activityLog;
  @override
  DateTime? get createdAt;
  @override
  DateTime? get updatedAt;

  /// When the task was archived by the retention pass (`taskHousekeeping`
  /// Cloud Function) — set only on an `approved` task older than the branch's
  /// `archiveAfterDays`. Null = live. Server-managed: the function stamps it
  /// via the Admin SDK; the client only ever *reads* it (to filter archived
  /// work out of active views) or *clears* it on an admin reopen. An archived
  /// task is still a full record in `tasks` (soft archive — never deleted
  /// unless a retention `deleteAfterDays` is explicitly configured), so
  /// statistics and deep-links keep working.
  @override
  DateTime? get archivedAt;

  /// Optimistic-concurrency counter, bumped by the server-authoritative
  /// transition path (`TaskRepository.transitionTask`) on every lifecycle move.
  /// A plain content edit never writes it. Additive — missing on any doc
  /// predating it → 0 (no migration). Not persisted by `TaskModel.toMap` (the
  /// transaction owns it, exactly like `createdAt`/`updatedAt`), so a stale
  /// client edit can never regress it. Read-only to the UI.
  @override
  int get version;

  /// Create a copy of TaskEntity
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$TaskEntityImplCopyWith<_$TaskEntityImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
