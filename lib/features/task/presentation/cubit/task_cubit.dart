import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:drop/core/utils/app_logger.dart';
import 'package:drop/core/enums/notification_type.dart';
import 'package:drop/core/enums/schedule_day.dart';
import 'package:drop/core/enums/schedule_shift.dart';
import 'package:drop/core/enums/task_assignment_type.dart';
import 'package:drop/core/enums/task_cancel_reason.dart';
import 'package:drop/core/enums/task_priority.dart';
import 'package:drop/core/enums/task_status.dart';
import 'package:drop/core/enums/task_type.dart';
import 'package:drop/core/enums/template_repeat_mode.dart';
import 'package:drop/core/errors/failures.dart';
import 'package:drop/core/enums/audit_event_type.dart';
import 'package:drop/core/media/media_upload_service.dart';
import 'package:drop/core/media/picked_attachment.dart';
import 'package:drop/core/utils/concurrent.dart';
import 'package:drop/features/audit/domain/entities/audit_actor.dart';
import 'package:drop/features/audit/domain/services/event_tracking_service.dart';
import 'package:drop/features/notifications/domain/usecases/notify_task_event.dart';
import 'package:drop/features/auth/domain/entities/user_entity.dart';
import 'package:drop/features/auth/domain/usecases/get_users_by_branch.dart';
import 'package:drop/features/branch/domain/entities/branch_entity.dart';
import 'package:drop/features/branch/domain/repositories/branch_repository.dart';
import 'package:drop/core/enums/attachment_type.dart';
import 'package:drop/features/schedule/domain/repositories/schedule_repository.dart';
import 'package:drop/features/schedule/domain/schedule_week.dart';
import 'package:drop/features/schedule/domain/shift_hours.dart';
import 'package:drop/features/task/domain/entities/activity_entry.dart';
import 'package:drop/features/task/domain/entities/checklist_item.dart';
import 'package:drop/features/task/domain/entities/recurrence_config.dart';
import 'package:drop/features/task/domain/entities/automation_run_entity.dart';
import 'package:drop/features/task/domain/entities/recurring_task_template_entity.dart';
import 'package:drop/features/task/domain/entities/task_attachment.dart';
import 'package:drop/features/task/domain/entities/task_entity.dart';
import 'package:drop/features/task/domain/entities/task_template_entity.dart';
import 'package:drop/features/task/domain/note_category.dart';
import 'package:drop/features/task/domain/repositories/task_repository.dart';
import 'package:drop/features/task/domain/task_ordering.dart';
import 'package:drop/features/task/domain/task_schedule.dart';
import 'package:drop/features/task/domain/work_types/task_work_x.dart';
import 'package:drop/features/task/domain/usecases/assign_task.dart';
import 'package:drop/features/task/domain/usecases/create_task.dart';
import 'package:drop/features/task/domain/usecases/delete_task.dart';
import 'package:drop/features/task/domain/usecases/resolve_task_reviewers.dart';
import 'package:drop/features/task/domain/usecases/update_task.dart';
import 'package:drop/features/task/domain/usecases/upload_task_attachment.dart';
import 'package:drop/features/task/presentation/submission_progress.dart';
import 'task_state.dart';

/// Drives the task workflow for all three roles. The list loaded depends on the
/// signed-in user's role (admin: all · manager: own branch · employee: tasks
/// they're assigned to) and is **realtime** — a Firestore snapshot stream.
///
/// Phase 9+: tasks support **multiple assignees**, an optional **checklist**,
/// **recurring schedules** (auto-creates the next instance on approve), and an
/// **activity timeline** (one entry per status transition). The cubit resolves
/// assignee uids → [UserEntity] (the [directory]) so cards show real names.
class TaskCubit extends Cubit<TaskState> {
  final TaskRepository _repository;
  final BranchRepository _branchRepository;
  final ScheduleRepository _scheduleRepository;
  final CreateTask _createTask;
  final UpdateTask _updateTask;
  final DeleteTask _deleteTask;
  final AssignTask _assignTask;
  final UploadTaskAttachment _uploadTaskAttachment;
  final GetUsersByBranch _getUsersByBranch;
  final NotifyTaskEvent _notifyTaskEvent;

  /// Immutable audit trail (optional — null in tests that don't exercise it).
  /// Every task-lifecycle write records one event through this single seam.
  final EventTrackingService? _eventTracking;

  /// Resolves who is told a task is waiting for review (optional — null in
  /// tests that don't exercise it, following [_eventTracking]'s precedent in
  /// this same constructor).
  ///
  /// When null, `taskSubmitted` degrades to `NotifyTaskEvent`'s own fallback of
  /// `[task.createdBy]` — i.e. exactly the behaviour that shipped before the
  /// reviewer ladder existed. DI always supplies it; see
  /// `task/domain/task_review_routing.dart` for the rule.
  final ResolveTaskReviewers? _resolveTaskReviewers;

  UserEntity? _user;

  /// One subscription per task source feeding the current scope, keyed by the
  /// same source key as [_taskSources]. Admin/manager have exactly one (all
  /// tasks / branch tasks); an employee has one for their individually-assigned
  /// tasks plus one per shift they're rostered on today (Shift Assignment
  /// feature) — see [_subscribeFor]/[_updateSource].
  ///
  /// Keyed rather than a flat list because the shift sources are re-bound on
  /// their own when the server roster turns out to differ from the cached one
  /// ([_bindShiftStreams]); the assignee source must survive that untouched.
  final Map<String, StreamSubscription<List<TaskEntity>>> _subs = {};
  final Map<String, List<TaskEntity>> _taskSources = {};
  bool _mutating = false;
  // Submission lives on the cubit (not a widget) so the whole screen reacts and
  // it survives rebuilds; carried on every `loaded` emit (incl. the stream).
  bool _submitting = false;
  SubmissionProgress? _submissionProgress;

  /// Cancels the in-flight submission's uploads (the overlay's Cancel button).
  /// Non-null only while [completeAndSubmit] is uploading.
  UploadCanceller? _canceller;

  /// Per-submission cache of already-uploaded attachments (file path → result),
  /// so a retry after a partial failure/cancel re-uploads ONLY what didn't
  /// already succeed. Scoped to one task; cleared on success or a task change.
  final Map<String, TaskAttachment> _uploadedCache = {};
  String? _uploadCacheTaskId;
  final Map<String, UserEntity> _directory = {};
  final Set<String> _fetchedBranches = {};
  final Map<String, String> _branchNames = {};

  Map<String, UserEntity> get directory => Map.unmodifiable(_directory);

  /// branchId → branch name, so screens (e.g. the review header) can show which
  /// branch a task belongs to. Populated once per session in [load].
  Map<String, String> get branchNames => Map.unmodifiable(_branchNames);

  TaskCubit({
    required this._repository,
    required this._branchRepository,
    required this._scheduleRepository,
    required this._createTask,
    required this._updateTask,
    required this._deleteTask,
    required this._assignTask,
    required this._uploadTaskAttachment,
    required this._getUsersByBranch,
    required this._notifyTaskEvent,
    this._eventTracking,
    this._resolveTaskReviewers,
  }) : super(const TaskState.initial());

  /// Records an immutable audit event for a task action — best-effort and
  /// fire-and-forget (the underlying write has already succeeded; the service
  /// never throws). No-op when tracking isn't wired or the actor is unknown.
  /// [entityId] is the task id, so an audit reader can pull a task's whole
  /// history via `AuditRepository.forEntity`.
  void _trackTask(
    TaskEntity task,
    AuditEventType type, {
    Map<String, dynamic> metadata = const {},
  }) {
    final tracker = _eventTracking;
    final user = _user;
    if (tracker == null || user == null) return;
    tracker.trackEvent(
      type: type,
      actor: AuditActor.of(user),
      entityId: task.id,
      branchId: task.branchId,
      metadata: {'title': task.title, ...metadata},
    );
  }

  /// Why a **terminal** task refuses an action. One message source across
  /// edit / delete / reassign so a closed record is never mislabelled — a
  /// cancelled task must not be reported as "approved and locked", since the
  /// two carry opposite meanings and only one of them has a reopen path.
  /// [closedPhrase] completes "… tasks are closed and {phrase}."; [approved] is
  /// the whole sentence for an approved task (which *is* reopenable).
  static String _terminalBlockMessage(
    TaskStatus status, {
    required String closedPhrase,
    required String approved,
  }) => switch (status) {
    TaskStatus.missed => 'Missed tasks are closed and $closedPhrase.',
    TaskStatus.cancelled => 'Cancelled tasks are closed and $closedPhrase.',
    _ => approved,
  };

  List<TaskEntity> get _tasks =>
      state.maybeWhen(loaded: (t, _, _, _, _) => t, orElse: () => const []);

  /// The currently-loaded task with [id], or null if not in the live list.
  TaskEntity? _taskById(String id) {
    for (final t in _tasks) {
      if (t.id == id) return t;
    }
    return null;
  }

  /// Identifies which Firestore stream the current subscription is bound to.
  /// Role and branch select **different** streams ([_streamFor]: admin →
  /// `watchAllTasks`, manager → `watchTasksByBranch`, employee →
  /// `watchEmployeeTasks`), so the subscription's identity is the full scope, not
  /// just the uid — a same-uid role/branch change (e.g. an employee promoted to
  /// manager, or moved branches, while the app is active) must force a
  /// resubscribe or we'd keep streaming the wrong scope.
  static String _scopeKey(UserEntity u) =>
      '${u.uid}:${u.role.value}:${u.branchId ?? ''}';

  Future<void> load(UserEntity user, {bool forceRefresh = false}) async {
    // Already streaming this exact scope — the live Firestore snapshot keeps the
    // list fresh, so a screen revisit must not cancel + re-subscribe (a fresh
    // server read) or flash a skeleton. Still re-load after an error so a revisit
    // can recover; pull-to-refresh passes forceRefresh to re-subscribe.
    final inError = state.maybeWhen(error: (_) => true, orElse: () => false);
    final sameScope = _user != null && _scopeKey(_user!) == _scopeKey(user);
    if (!forceRefresh && !inError && _subs.isNotEmpty && sameScope) {
      return;
    }
    // Scope changed (different user, or same user with a new role/branch) — the
    // resolved directory + branch caches belonged to the old scope, so drop them.
    if (!sameScope) {
      _directory.clear();
      _fetchedBranches.clear();
      _branchNames.clear();
    }
    _user = user;
    _loadBranchNames();
    // Only show the full-screen spinner when there's nothing to show yet.
    final hasTasks = state.maybeWhen(
      loaded: (t, _, _, _, _) => true,
      orElse: () => false,
    );
    if (!hasTasks) emit(const TaskState.loading());
    await _cancelSubs();
    _taskSources.clear();
    await _subscribeFor(user);
  }

  Future<void> refresh() async {
    final user = _user;
    if (user != null) await load(user, forceRefresh: true);
  }

  Future<void> _cancelSubs() async {
    for (final s in _subs.values) {
      await s.cancel();
    }
    _subs.clear();
  }

  /// Drops the sources whose key satisfies [where] — both the subscription and
  /// its last snapshot, so [_updateSource]'s next merge cannot resurrect tasks
  /// from a source we no longer listen to.
  Future<void> _cancelSubsWhere(bool Function(String key) where) async {
    for (final key in _subs.keys.where(where).toList()) {
      await _subs.remove(key)?.cancel();
      _taskSources.remove(key);
    }
  }

  /// Sets up every task source for [user]'s scope. Admin/manager get exactly
  /// one (unchanged from before shift assignment). An employee gets their
  /// individually/team-assigned stream **plus** one shift stream per shift
  /// they're rostered on today (0, 1, or 2 — `shiftsFor` may return both) — a
  /// shift task's `assigneeIds` is empty, so it would never appear in
  /// `watchEmployeeTasks` alone.
  Future<void> _subscribeFor(UserEntity user) async {
    if (user.role.isAdmin) {
      _subscribe('all', _repository.watchAllTasks());
      return;
    }
    if (user.role.isManager) {
      _subscribe('branch', _repository.watchTasksByBranch(user.branchId ?? ''));
      return;
    }
    _subscribe('assignee', _repository.watchEmployeeTasks(user.uid));
    await _subscribeEmployeeShifts(user);
  }

  void _subscribe(String sourceKey, Stream<List<TaskEntity>> stream) {
    _subs[sourceKey] = stream.listen(
      (tasks) => _updateSource(sourceKey, tasks),
      // Capture the real error/stack (a swallowed exception is why this only
      // ever showed a generic UI message — e.g. a missing Firestore composite
      // index surfaces here as `failed-precondition`). The UI message stays
      // friendly.
      onError: (Object error, StackTrace stackTrace) {
        AppLog.error('task', 'Task stream "$sourceKey" failed', error,
            stackTrace);
        emit(
          const TaskState.error('Failed to load tasks. Please try again.'),
        );
      },
    );
  }

  /// Resolves the employee's shift(s) today from the branch's weekly schedule
  /// (`WeeklyScheduleEntity.shiftsFor` — the same primitive
  /// `computeBranchWorkload` uses for the same "who's on shift X today"
  /// question) and subscribes one `watchShiftTasks` stream per shift. A shift
  /// task carries no `assigneeIds`, so these streams are the *only* way it
  /// reaches the employee.
  ///
  /// **Cache-first, then reconciled.** Resolving the roster used to be an
  /// awaited server read, which meant shift tasks — and therefore the Late and
  /// Missed counts that include them — appeared about a second after the rest
  /// of the screen. The roster is now read from the on-device cache so the
  /// streams bind in the same frame, and the authoritative server read runs
  /// **unawaited** behind it, re-binding only if today's roster actually
  /// differs. So the fast path never goes stale for more than one round trip,
  /// and an employee moved to another shift still gets the right tasks without
  /// touching refresh.
  ///
  /// Best-effort — an employee with no branch or no resolvable schedule simply
  /// gets no shift streams (unchanged behaviour from before this feature).
  Future<void> _subscribeEmployeeShifts(UserEntity user) async {
    final branchId = user.branchId;
    if (branchId == null || branchId.isEmpty) return;

    final fromCache = await _rosteredShiftsToday(user, branchId, cached: true);
    _bindShiftStreams(branchId, fromCache);

    // Deliberately not awaited: `load()` awaits this method, and the whole
    // point is that the first paint no longer waits on the network.
    unawaited(_reconcileShiftStreams(user, branchId, fromCache));
  }

  /// The shifts [user] is rostered on today, as source keys. Empty on any
  /// failure — a roster we cannot read must not tear down existing streams.
  Future<Set<ScheduleShift>> _rosteredShiftsToday(
    UserEntity user,
    String branchId, {
    required bool cached,
  }) async {
    try {
      final week = ScheduleWeek.currentWeekStart();
      final schedule = cached
          ? await _scheduleRepository.getScheduleCacheFirst(branchId, week)
          : await _scheduleRepository.getSchedule(branchId, week);
      if (schedule == null) return const {};
      return schedule.shiftsFor(user.uid, ScheduleDay.today()).toSet();
    } catch (_) {
      return const {};
    }
  }

  /// Re-reads the roster from the server and re-binds the shift sources only
  /// when the set genuinely changed, so the common case (cache was right) costs
  /// one read and causes no stream churn or list flicker.
  Future<void> _reconcileShiftStreams(
    UserEntity user,
    String branchId,
    Set<ScheduleShift> fromCache,
  ) async {
    final fromServer = await _rosteredShiftsToday(user, branchId, cached: false);
    // The scope may have changed while the read was in flight (signed out,
    // switched user, pulled to refresh) — that load owns the streams now.
    if (isClosed || _user == null || _scopeKey(_user!) != _scopeKey(user)) {
      return;
    }
    if (fromServer.isEmpty && fromCache.isEmpty) return;
    // Same roster (the common case) — leave the live streams alone. At most two
    // shifts, so a plain compare beats pulling in a set-equality helper.
    if (fromServer.length == fromCache.length &&
        fromServer.every(fromCache.contains)) {
      return;
    }
    await _cancelSubsWhere((key) => key.startsWith('shift:'));
    _bindShiftStreams(branchId, fromServer);
  }

  void _bindShiftStreams(String branchId, Set<ScheduleShift> shifts) {
    for (final shift in shifts) {
      _subscribe(
        'shift:${shift.value}',
        _repository.watchShiftTasks(branchId: branchId, shift: shift),
      );
    }
  }

  /// Scheduling V2 smart default — resolve the rostered shift of the given
  /// [uids] on [date] in [branchId], to pre-fill a non-shift task's schedule.
  /// Returns [AssigneeShiftFit.unanimous] with the shift when everyone shares one,
  /// [AssigneeShiftFit.mixed] when they differ (the form asks the user to choose),
  /// or [AssigneeShiftFit.none] when nobody's rostered / no schedule. Best-effort
  /// (a read error degrades to `none` — the manager just schedules manually).
  Future<({AssigneeShiftFit fit, ScheduleShift? shift})> resolveAssigneeShift({
    required String branchId,
    required List<String> uids,
    required DateTime date,
  }) async {
    if (branchId.isEmpty || uids.isEmpty) {
      return (fit: AssigneeShiftFit.none, shift: null);
    }
    try {
      final schedule = await _scheduleRepository.getSchedule(
        branchId,
        ScheduleWeek.startOf(date),
      );
      if (schedule == null) return (fit: AssigneeShiftFit.none, shift: null);
      final day = ScheduleDay.fromDate(date);
      return assigneeShiftFit([
        for (final uid in uids) schedule.shiftsFor(uid, day),
      ]);
    } catch (_) {
      return (fit: AssigneeShiftFit.none, shift: null);
    }
  }

  /// Merges every task source's latest snapshot (keyed by source, each holding
  /// that source's *full* current result set) into one deduped-by-id list and
  /// emits it. A task disappearing from its source's next snapshot (reassigned,
  /// deleted, no longer matching a query) is naturally dropped on the next
  /// merge — no stale entries linger.
  void _updateSource(String sourceKey, List<TaskEntity> tasks) {
    _taskSources[sourceKey] = tasks;
    final merged = <String, TaskEntity>{};
    for (final list in _taskSources.values) {
      for (final t in list) {
        merged[t.id] = t;
      }
    }
    final combined = sortTasksNewestFirst(merged.values.toList());
    // Preserve in-flight submission state — a Firestore write during submit
    // fires this stream, and we must not drop the overlay mid-finalize.
    emit(
      TaskState.loaded(
        combined,
        busy: _mutating,
        directory: _directory,
        isSubmitting: _submitting,
        submissionProgress: _submissionProgress,
      ),
    );
    _ensureDirectory(combined);
  }

  /// Loads branchId → name once so the UI can label a task's branch. Re-emits a
  /// fresh loaded state (new directory map reference) so listeners rebuild when
  /// the names arrive. Best-effort — failure leaves names empty (no branch label).
  Future<void> _loadBranchNames() async {
    try {
      final list = await _branchRepository.getBranches();
      for (final b in list) {
        _branchNames[b.id] = b.name;
      }
      if (!isClosed) {
        state.mapOrNull(
          loaded: (s) => emit(s.copyWith(directory: Map.of(_directory))),
        );
      }
    } catch (e) {
      AppLog.warning('task', 'branch-name enrichment failed: $e');
    }
  }

  Future<void> _ensureDirectory(List<TaskEntity> tasks) async {
    final branchIds = <String>{
      for (final t in tasks)
        if ((t.branchId ?? '').isNotEmpty) t.branchId!,
    }..removeAll(_fetchedBranches);
    if (branchIds.isEmpty) return;

    var changed = false;
    for (final branchId in branchIds) {
      _fetchedBranches.add(branchId);
      try {
        final users = await _getUsersByBranch(branchId);
        for (final u in users) {
          _directory[u.uid] = u;
          changed = true;
        }
      } catch (e) {
        AppLog.warning('task', 'member-directory enrichment failed: $e');
      }
    }
    if (changed && !isClosed) {
      state.mapOrNull(
        loaded: (s) => emit(s.copyWith(directory: Map.of(_directory))),
      );
    }
  }

  // ─── Manager / admin actions ───────────────────────────────────
  Future<void> createTask({
    required String title,
    String? description,
    required TaskType type,

    /// The operational work type (Registry id — `general`, `transfer`,
    /// `inventoryCount`, …). Defaults to `general` so every existing call site
    /// (recurrence spawn, template materialize) is unaffected.
    String workType = 'general',

    /// Schema-driven values for [workType]'s dynamic fields.
    Map<String, dynamic> data = const {},
    required TaskPriority priority,
    required String branchId,

    /// Task Scheduling V2 — when the task is scheduled to start (smart-defaulted
    /// from the shift in the form, fully overridable). Additive/optional; every
    /// existing call site omits it (→ null).
    DateTime? startsAt,
    DateTime? deadline,
    List<String> assigneeIds = const [],
    List<ChecklistItem> checklist = const [],
    RecurrenceConfig? recurrence,
    List<PickedAttachment> referenceAttachments = const [],

    /// Shift Assignment feature. Defaults to [TaskAssignmentType.individual]
    /// (existing behaviour, unchanged) for every pre-existing call site.
    TaskAssignmentType assignmentType = TaskAssignmentType.individual,

    /// Required when [assignmentType] is [TaskAssignmentType.shift].
    ScheduleShift? shift,

    /// The day a shift instance is *for*; defaults to [deadline] (date part) or
    /// today when omitted. Ignored for individual/team tasks.
    DateTime? instanceDate,
  }) async {
    // A shift task targets whoever's rostered on `shift`, never named people.
    final isShift = assignmentType == TaskAssignmentType.shift;
    final effectiveAssigneeIds = isShift ? const <String>[] : assigneeIds;
    final effectiveInstanceDate = isShift
        ? (instanceDate ?? deadline ?? DateTime.now())
        : null;

    TaskEntity? created;
    final ok = await _mutate(() async {
      created = await _createTask(
        TaskEntity(
          id: '',
          title: title,
          description: description,
          type: type,
          workType: workType,
          data: data,
          priority: priority,
          branchId: branchId,
          assigneeIds: effectiveAssigneeIds,
          checklist: checklist,
          recurrence: recurrence,
          assignmentType: assignmentType,
          shift: shift,
          instanceDate: effectiveInstanceDate,
          createdBy: _user?.uid,
          startsAt: startsAt,
          deadline: deadline,
          activityLog: [
            ActivityEntry(
              status: TaskStatus.pending.value,
              actorId: _user?.uid ?? '',
              actorName: _user?.displayName,
              at: DateTime.now(),
            ),
          ],
        ),
      );
      // Reference images upload AFTER create (the Storage path needs the task
      // id), then patch the task. Best-effort relative to the task itself: a
      // failed upload throws inside _mutate, which rolls the list back so the
      // manager can retry — the half-created task without images would be worse.
      if (referenceAttachments.isNotEmpty && created != null) {
        final uploaded = await _uploadReferences(
          created!.id,
          referenceAttachments,
        );
        created = created!.copyWith(referenceAttachments: uploaded);
        await _updateTask(created!);
      }
    });
    if (!ok || created == null || _user == null) return;

    // Notify (best-effort) — a shift task resolves its recipients from today's
    // roster instead of a fixed assignee list; reuses the same NotifyTaskEvent
    // call individual/team assignment already uses, just with a different
    // recipient source.
    if (isShift && shift != null) {
      final recipients = await _shiftRecipients(
        branchId: branchId,
        shift: shift,
        day: effectiveInstanceDate!,
      );
      if (recipients.isNotEmpty) {
        await _notifyTaskEvent(
          task: created!,
          type: NotificationType.taskAssigned,
          actor: _user!,
          recipientOverride: recipients,
        );
      }
    } else if (assigneeIds.isNotEmpty) {
      await _notifyTaskEvent(
        task: created!,
        type: NotificationType.taskAssigned,
        actor: _user!,
        recipientOverride: assigneeIds,
      );
    }

    // Audit: the task was created (assignment details ride in the metadata).
    // Previously logged as `taskAssigned`, which fired even for an unassigned
    // task; creation and assignment are now distinct facts (P1-4).
    _trackTask(
      created!,
      AuditEventType.taskCreated,
      metadata: {
        'assignmentType': created!.assignmentType.value,
        'priority': created!.priority.value,
        if (isShift && shift != null) 'shift': shift.value,
        if (!isShift && assigneeIds.isNotEmpty) 'assignedTo': assigneeIds,
      },
    );
  }

  /// The uids rostered on [shift] for [day] at [branchId] — the recipients for
  /// a shift task's assignment notification. Reuses the exact schedule lookup
  /// (`ScheduleRepository.getSchedule` + `WeeklyScheduleEntity.employeesFor`)
  /// `computeBranchWorkload` already relies on. Best-effort: no schedule ⇒ no
  /// recipients, never throws.
  Future<List<String>> _shiftRecipients({
    required String branchId,
    required ScheduleShift shift,
    required DateTime day,
  }) async {
    try {
      final schedule = await _scheduleRepository.getSchedule(
        branchId,
        ScheduleWeek.startOf(day),
      );
      if (schedule == null) return const [];
      return schedule.employeesFor(ScheduleDay.fromDate(day), shift);
    } catch (_) {
      return const [];
    }
  }

  Future<void> editTask(
    TaskEntity task, {
    List<PickedAttachment> newReferenceAttachments = const [],
  }) async {
    // Terminal records are immutable. The UI hides these affordances, but this
    // remains the cubit-level backstop for a stale route/snapshot. An approved
    // task has an admin reopen path; a deadline-missed task does not.
    final existing = _taskById(task.id);
    if (existing?.status.isTerminal ?? false) {
      _emitTransientError(
        _terminalBlockMessage(
          existing!.status,
          closedPhrase: 'cannot be edited',
          approved: 'Approved tasks are locked. Reopen the task to edit it.',
        ),
      );
      return;
    }
    // Notify only employees newly added by this edit (not the existing ones).
    final before = existing?.assigneeIds.toSet() ?? const {};
    final added = task.assigneeIds.where((id) => !before.contains(id)).toList();
    final ok = await _mutate(() async {
      // [task] already carries the kept reference images (the form drops removed
      // ones); upload any newly-picked ones and append before the write.
      var next = task;
      if (newReferenceAttachments.isNotEmpty) {
        final uploaded = await _uploadReferences(
          task.id,
          newReferenceAttachments,
        );
        next = task.copyWith(
          referenceAttachments: [...task.referenceAttachments, ...uploaded],
        );
      }
      await _updateTask(next);
    });
    if (ok && _user != null) {
      // Notify + audit only the newly-added assignees for the assignment fact…
      if (added.isNotEmpty) {
        await _notifyTaskEvent(
          task: task,
          type: NotificationType.taskAssigned,
          actor: _user!,
          recipientOverride: added,
        );
        _trackTask(
          task,
          AuditEventType.taskAssigned,
          metadata: {'assignedTo': added},
        );
      }
      // …and always audit the edit itself (P1-4 — was previously unaudited).
      _trackTask(task, AuditEventType.taskUpdated);
    }
  }

  Future<void> deleteTask(String taskId) async {
    final existing = _taskById(taskId);
    if (existing?.status.isTerminal ?? false) {
      _emitTransientError(
        _terminalBlockMessage(
          existing!.status,
          closedPhrase: 'cannot be deleted',
          approved:
              'Approved tasks are locked. Reopen the task before deleting it.',
        ),
      );
      return;
    }
    final ok = await _mutate(() => _deleteTask(taskId));
    // Audit the deletion (P1-4 — previously unaudited).
    if (ok && existing != null) {
      _trackTask(existing, AuditEventType.taskDeleted);
    }
  }

  /// Admin escape hatch — reopens an approved task for correction. Moves it back
  /// to `started` (clearing the approval audit) and logs the reopen on the
  /// timeline, so a mistaken approval is recoverable. Wired only behind an
  /// admin-gated affordance; `firestore.rules` permits only an admin to move a
  /// task out of `approved`.
  Future<void> reopenTask(TaskEntity task) async {
    if (task.status != TaskStatus.approved) return;
    final now = DateTime.now();
    final ok = await _transition(
      task,
      from: const {TaskStatus.approved},
      patch: {
        'status': TaskStatus.started.value,
        'approvedBy': null,
        'approvedAt': null,
        // Reopening a task that the retention pass had archived brings it back
        // into active views (it's no longer an approved historical record).
        'archivedAt': null,
        'requiresRework': false,
      },
      appendLog: [
        ActivityEntry(
          status: TaskStatus.started.value,
          actorId: _user?.uid ?? '',
          actorName: _user?.displayName,
          at: now,
          note: 'Reopened for changes',
        ),
      ],
    );
    // Audit the reopen — undoing a locked, reviewed record is the single most
    // consequential admin action, so it must leave a trail (P1-4).
    if (ok) _trackTask(task, AuditEventType.taskReopened);
  }

  Future<void> assignEmployees({
    required String taskId,
    required List<String> employeeIds,
    String? shiftId,
  }) async {
    final existing = _taskById(taskId);
    if (existing?.status.isTerminal ?? false) {
      _emitTransientError(
        _terminalBlockMessage(
          existing!.status,
          closedPhrase: 'cannot change assignees',
          approved:
              'Approved tasks are locked. Reopen the task to change assignees.',
        ),
      );
      return;
    }
    final before = existing?.assigneeIds.toSet() ?? const {};
    final added = employeeIds.where((id) => !before.contains(id)).toList();
    final ok = await _mutate(
      () => _assignTask(
        taskId: taskId,
        employeeIds: employeeIds,
        assignedShiftId: shiftId,
      ),
    );
    // Notify + audit the newly-assigned employees (best-effort).
    if (ok && added.isNotEmpty && existing != null && _user != null) {
      await _notifyTaskEvent(
        task: existing.copyWith(assigneeIds: employeeIds),
        type: NotificationType.taskAssigned,
        actor: _user!,
        recipientOverride: added,
      );
      _trackTask(
        existing,
        AuditEventType.taskAssigned,
        metadata: {'assignedTo': added},
      );
    }
  }

  Future<void> approveTask(TaskEntity task, {String? reviewNotes}) async {
    final now = DateTime.now();
    final ok = await _transition(
      task,
      from: const {TaskStatus.waitingReview},
      patch: {
        'status': TaskStatus.approved.value,
        'approvedBy': _user?.uid,
        'approvedAt': now,
        'reviewNotes': reviewNotes,
        'requiresRework': false,
      },
      appendLog: [
        ActivityEntry(
          status: TaskStatus.approved.value,
          actorId: _user?.uid ?? '',
          actorName: _user?.displayName,
          at: now,
          note: reviewNotes,
        ),
      ],
    );
    if (ok && _user != null) {
      // Spawn the next recurrence AFTER the atomic approve — only the reviewer
      // that actually won the transition reaches here, so two concurrent
      // approves can never both spawn an instance (a stale one hits a conflict).
      if (task.recurrence != null &&
          task.recurrence!.frequency.value != 'none') {
        await _spawnNextRecurrence(task);
      }
      await _notifyTaskEvent(
        task: task,
        type: NotificationType.taskApproved,
        actor: _user!,
        recipientOverride: await _reviewRecipients(task),
      );
      _trackTask(
        task,
        AuditEventType.taskApproved,
        metadata: {
          if ((reviewNotes ?? '').trim().isNotEmpty) 'reviewNotes': reviewNotes,
        },
      );
    }
  }

  /// Sends a task back to be redone (the "Request Rework" review action). Bumps
  /// [TaskEntity.revisionNumber], flags [TaskEntity.requiresRework], stores the
  /// [reviewNotes] as the rejection reason, and notifies the assignees
  /// ([NotificationType.taskRework] → `REWORK #n` badge). Distinct from a
  /// terminal [rejectTask].
  Future<void> reworkTask(TaskEntity task, {String? reviewNotes}) async {
    final nextRevision = task.revisionNumber + 1;
    final now = DateTime.now();
    final ok = await _transition(
      task,
      from: const {TaskStatus.waitingReview},
      patch: {
        'status': TaskStatus.rejected.value,
        'requiresRework': true,
        'revisionNumber': nextRevision,
        'rejectionReason': reviewNotes,
        'rejectedBy': _user?.uid,
        'rejectedAt': now,
        'reviewNotes': reviewNotes,
      },
      appendLog: [
        ActivityEntry(
          // Stored as `rejected` so the existing timeline rendering is
          // unchanged; the rework distinction lives in requiresRework /
          // revisionNumber + the notification type.
          status: TaskStatus.rejected.value,
          actorId: _user?.uid ?? '',
          actorName: _user?.displayName,
          at: now,
          note: reviewNotes,
        ),
      ],
    );
    if (ok && _user != null) {
      await _notifyTaskEvent(
        task: task.copyWith(
          revisionNumber: nextRevision,
          requiresRework: true,
          rejectionReason: reviewNotes,
        ),
        type: NotificationType.taskRework,
        actor: _user!,
        recipientOverride: await _reviewRecipients(task),
      );
      _trackTask(
        task,
        AuditEventType.taskReworkRequested,
        metadata: {
          'revision': nextRevision,
          if ((reviewNotes ?? '').trim().isNotEmpty) 'reviewNotes': reviewNotes,
        },
      );
    }
  }

  /// Terminal rejection (the distinct "Reject" review action). Does **not** bump
  /// the revision count or flag rework; notifies the assignees
  /// ([NotificationType.taskRejected] → red `Rejected` badge).
  Future<void> rejectTask(TaskEntity task, {String? reviewNotes}) async {
    final now = DateTime.now();
    final ok = await _transition(
      task,
      from: const {TaskStatus.waitingReview},
      patch: {
        'status': TaskStatus.rejected.value,
        'requiresRework': false,
        'rejectionReason': reviewNotes,
        'rejectedBy': _user?.uid,
        'rejectedAt': now,
        'reviewNotes': reviewNotes,
      },
      appendLog: [
        ActivityEntry(
          status: TaskStatus.rejected.value,
          actorId: _user?.uid ?? '',
          actorName: _user?.displayName,
          at: now,
          note: reviewNotes,
        ),
      ],
    );
    if (ok && _user != null) {
      await _notifyTaskEvent(
        task: task.copyWith(rejectionReason: reviewNotes),
        type: NotificationType.taskRejected,
        actor: _user!,
        recipientOverride: await _reviewRecipients(task),
      );
      _trackTask(
        task,
        AuditEventType.taskRejected,
        metadata: {
          if ((reviewNotes ?? '').trim().isNotEmpty) 'reviewNotes': reviewNotes,
        },
      );
    }
  }

  /// **Admin-only terminal correction** (Automated Tasks spec §6.4) — returns a
  /// mistakenly-closed task to `pending`, clearing the terminal evidence.
  ///
  /// Without it, a mistimed or fat-fingered terminal is a **permanent lie in the
  /// reporting**: a cancel that lost the race to the Missed sweep by seconds, a
  /// cancel of the wrong task, a miss recorded against work that was actually
  /// done. This is the cheapest possible safety valve, and it is deliberately
  /// narrow — admin only, always audited — so it can't become a routine escape
  /// hatch that erodes accountability.
  ///
  /// Scoped to `missed` / `cancelled`. Correcting an **approved** task is the
  /// separate, longer-standing [reopenTask] (which a manager may also do, per
  /// the spec's §6 permission table); this one is the admin's alone. The caller
  /// gates on role; `firestore.rules` is the real enforcement.
  Future<void> correctTerminal(TaskEntity task, {String? note}) async {
    if (task.status != TaskStatus.missed &&
        task.status != TaskStatus.cancelled) {
      _emitTransientError('Only a missed or cancelled task can be corrected.');
      return;
    }
    final now = DateTime.now();
    final trimmed = note?.trim();
    final from = task.status;
    final ok = await _transition(
      task,
      from: const {TaskStatus.missed, TaskStatus.cancelled},
      patch: {
        'status': TaskStatus.pending.value,
        // Every trace of the wrong outcome goes, or the task would sit in
        // `pending` still carrying a cancellation reason and a missed stamp.
        'missedAt': null,
        'cancelledAt': null,
        'cancelledBy': null,
        'cancelReason': null,
        'cancelNote': null,
        // A corrected task rejoins active views; the retention pass may have
        // archived it while it was closed.
        'archivedAt': null,
      },
      appendLog: [
        ActivityEntry(
          status: kActivityTerminalCorrected,
          actorId: _user?.uid ?? '',
          actorName: _user?.displayName,
          at: now,
          note: (trimmed?.isEmpty ?? true)
              ? 'Reopened — ${from.value} recorded in error'
              : trimmed,
        ),
      ],
    );
    if (ok) {
      _trackTask(
        task,
        AuditEventType.taskTerminalCorrected,
        metadata: {
          'correctedFrom': from.value,
          if (trimmed != null && trimmed.isNotEmpty) 'note': trimmed,
        },
      );
    }
  }

  /// Cancels a task — the terminal **business decision** that this work will not
  /// be done (Automated Tasks spec §5). Distinct from both Approved (success)
  /// and Missed (a shift wall closed on unfinished work): a cancellation is
  /// neither, and is excluded from the completion rate entirely (§8).
  ///
  /// Reachable from `pending` or `started` **only** — a submitted task must be
  /// reviewed, never voided (§5.4) — and never by an employee (§5.1; the real
  /// gate is `firestore.rules`, which also holds a manager to their own branch).
  /// [reason] is mandatory and structured; [note] may add context but never
  /// substitutes for the code, because cancellation volume *by reason* is the
  /// signal that catches a misconfigured template or a routine that should be
  /// paused (§10.3).
  ///
  /// **Instance-scoped (§4.3):** cancelling today's generated shift task cancels
  /// only that instance. Tomorrow's still generates — stopping a routine is a
  /// separate action on its template, deliberately outside this workflow.
  Future<void> cancelTask(
    TaskEntity task, {
    required TaskCancelReason reason,
    String? note,
  }) async {
    // A reason is the point of the feature; `unknown` is a read-side fallback
    // for a code written by a newer build, never something we may write.
    if (!TaskCancelReason.selectable.contains(reason)) {
      _emitTransientError('Choose a reason before cancelling this task.');
      return;
    }
    final trimmed = note?.trim();
    final now = DateTime.now();
    final ok = await _transition(
      task,
      from: const {TaskStatus.pending, TaskStatus.started},
      patch: {
        'status': TaskStatus.cancelled.value,
        'cancelledAt': now,
        'cancelledBy': _user?.uid,
        'cancelReason': reason.value,
        'cancelNote': (trimmed?.isEmpty ?? true) ? null : trimmed,
        // Cancelling IS the answer to an open "this task is wrong" report, so
        // the flag clears with it — otherwise a closed task would keep asking
        // for a decision that has just been made.
        'reportedIncorrectBy': null,
        'reportedIncorrectAt': null,
        'reportedIncorrectNote': null,
      },
      appendLog: [
        ActivityEntry(
          status: TaskStatus.cancelled.value,
          actorId: _user?.uid ?? '',
          actorName: _user?.displayName,
          at: now,
          // The reason always reaches the timeline, so the record reads
          // honestly even where the cancel fields aren't rendered.
          note: (trimmed?.isEmpty ?? true)
              ? reason.label
              : '${reason.label} — $trimmed',
        ),
      ],
    );
    if (ok) {
      if (_user != null) {
        // Targeted, never branch-wide (§9.2): the people who were going to do
        // this work. For a shift broadcast there are no named assignees, so
        // resolve the rostered crew exactly as a review outcome does (§9.3) —
        // nobody rostered yields an empty list, which `NotifyTaskEvent` treats
        // as "no recipients", not as a failure.
        await _notifyTaskEvent(
          task: task.copyWith(cancelReason: reason, cancelNote: trimmed),
          type: NotificationType.taskCancelled,
          actor: _user!,
          recipientOverride: await _reviewRecipients(task),
        );
      }
      _trackTask(
        task,
        AuditEventType.taskCancelled,
        metadata: {
          'reason': reason.value,
          if (trimmed != null && trimmed.isNotEmpty) 'note': trimmed,
          'cancelledFrom': task.status.value,
        },
      );
    }
  }

  /// An employee flags a task as **incorrect** and routes it to their branch's
  /// managers, who decide (Automated Tasks spec §5.2). This is the release valve
  /// that makes manager-only cancellation workable: the person actually holding
  /// the wrong work has a way to say so, without ever getting the power to
  /// cancel it themselves.
  ///
  /// [note] is required — a report with no explanation gives the manager nothing
  /// to decide on. Filing does **not** change the task's status: the work stays
  /// exactly where it was until a manager cancels it or dismisses the report.
  Future<void> reportTaskIncorrect(TaskEntity task, {required String note}) async {
    final trimmed = note.trim();
    if (trimmed.isEmpty) {
      _emitTransientError("Tell your manager what's wrong with this task.");
      return;
    }
    if (task.status.isTerminal) {
      _emitTransientError('This task is already closed.');
      return;
    }
    final user = _user;
    if (user == null) return;
    final now = DateTime.now();
    final ok = await _transition(
      task,
      // Any live state — a task can be wrong at any point before it closes, and
      // reporting is not a lifecycle move, so there is no predecessor to assert
      // beyond "not terminal" (checked above).
      from: const {
        TaskStatus.pending,
        TaskStatus.started,
        TaskStatus.completed,
        TaskStatus.waitingReview,
        TaskStatus.rejected,
      },
      patch: {
        'reportedIncorrectBy': user.uid,
        'reportedIncorrectAt': now,
        'reportedIncorrectNote': trimmed,
      },
      appendLog: [
        ActivityEntry(
          status: kActivityReportedIncorrect,
          actorId: user.uid,
          actorName: user.displayName,
          at: now,
          note: trimmed,
        ),
      ],
    );
    if (!ok) return;

    final reported = task.copyWith(
      reportedIncorrectBy: user.uid,
      reportedIncorrectAt: now,
      reportedIncorrectNote: trimmed,
    );
    await _notifyTaskEvent(
      task: reported,
      type: NotificationType.taskReportedIncorrect,
      actor: user,
      recipientOverride: await _branchManagers(task.branchId),
    );
    _trackTask(
      task,
      AuditEventType.taskReportedIncorrect,
      metadata: {'note': trimmed},
    );
  }

  /// A manager/admin closes an employee's report **without** cancelling — the
  /// task is fine as issued. Clears the report so the banner and the manager's
  /// queue don't keep showing work that has already been judged.
  Future<void> dismissIncorrectReport(TaskEntity task) async {
    if (!task.isReportedIncorrect) return;
    final now = DateTime.now();
    final ok = await _transition(
      task,
      from: const {
        TaskStatus.pending,
        TaskStatus.started,
        TaskStatus.completed,
        TaskStatus.waitingReview,
        TaskStatus.rejected,
      },
      patch: {
        'reportedIncorrectBy': null,
        'reportedIncorrectAt': null,
        'reportedIncorrectNote': null,
      },
      appendLog: [
        ActivityEntry(
          status: kActivityReportDismissed,
          actorId: _user?.uid ?? '',
          actorName: _user?.displayName,
          at: now,
          note: 'Report reviewed — the task stands',
        ),
      ],
    );
    if (ok) _trackTask(task, AuditEventType.taskReportDismissed);
  }

  /// The branch's active managers — the routing target for an employee's
  /// incorrect-task report. Falls back to an empty list (a valid "nobody to
  /// tell"), never to a broadcast.
  Future<List<String>> _branchManagers(String? branchId) async {
    if (branchId == null || branchId.isEmpty) return const [];
    try {
      final users = await _getUsersByBranch(branchId);
      return [
        for (final u in users)
          if (u.role.isManager && u.isActive) u.uid,
      ];
    } catch (_) {
      return const [];
    }
  }

  // ─── Employee actions ──────────────────────────────────────────
  Future<void> startTask(TaskEntity task) async {
    final now = DateTime.now();
    // The start gate (ADR-016) — refuse before writing, so every caller is
    // covered, including any surface added later. No status exemptions.
    final blockedReason = startBlockedReason(task, now);
    if (blockedReason != null) {
      _emitTransientError(blockedReason);
      return;
    }
    // pending → started (a fresh task) or rejected → started (redoing a
    // reworked/rejected task); the same schedule gate above applies to both.
    final ok = await _transition(
      task,
      from: const {TaskStatus.pending, TaskStatus.rejected},
      patch: {'status': TaskStatus.started.value, 'startedAt': now},
      appendLog: [
        ActivityEntry(
          status: TaskStatus.started.value,
          actorId: _user?.uid ?? '',
          actorName: _user?.displayName,
          at: now,
        ),
      ],
    );
    if (ok) _trackTask(task, AuditEventType.taskStarted);
  }

  Future<void> toggleChecklistItem(TaskEntity task, String itemId) {
    final updated = [
      for (final i in task.checklist)
        if (i.id == itemId)
          ChecklistItem(
            id: i.id,
            title: i.title,
            isRequired: i.isRequired,
            completed: !i.completed,
            completedAt: i.completed ? null : DateTime.now(),
          )
        else
          i,
    ];
    return _mutate(() => _updateTask(task.copyWith(checklist: updated)));
  }

  /// Merges [patch] into the task's schema-driven work-type [TaskEntity.data] —
  /// the employee-captured completion fields (a counted quantity, an amount
  /// spent, inspection results). A single `_updateTask` write; a `null` value in
  /// [patch] removes the key. Permitted for an assignee by the deployed rules
  /// (it's an ordinary field like notes/checklist — no frozen field is touched).
  Future<void> updateWorkData(TaskEntity task, Map<String, dynamic> patch) {
    if (patch.isEmpty) return Future<void>.value();
    final next = {...task.data};
    patch.forEach((k, v) {
      if (v == null) {
        next.remove(k);
      } else {
        next[k] = v;
      }
    });
    return _mutate(() => _updateTask(task.copyWith(data: next)));
  }

  /// Records a per-type [WorkEvent] milestone on the timeline (a transfer's
  /// "dispatched" / "received", a purchase's "purchased", …). The milestone
  /// rides `ActivityEntry.status` as its [eventId], so it renders on the generic
  /// activity timeline with no core-status change. Idempotent — a no-op if the
  /// milestone is already logged.
  Future<void> logWorkEvent(
    TaskEntity task, {
    required String eventId,
    String? note,
  }) {
    if (task.activityLog.any((e) => e.status == eventId)) {
      return Future<void>.value();
    }
    // Pure log append (a per-type milestone, no core-status change) — atomic
    // against the server's current log so it never clobbers a concurrent write.
    return _mutate(
      () => _repository.transitionTask(
        taskId: task.id,
        expectedFrom: const {},
        patch: const {},
        appendLog: [
          ActivityEntry(
            status: eventId,
            actorId: _user?.uid ?? '',
            actorName: _user?.displayName,
            at: DateTime.now(),
            note: note,
          ),
        ],
      ),
    );
  }

  /// Appends a manager/admin operational **note** to the task's timeline WITHOUT
  /// a status change — fast feedback from the feed's triage surface. No-op on
  /// blank text. The [category] (info / warning / issue) sets the note's
  /// activity kind so `activity_format` can render its hierarchy.
  Future<void> addNote(
    TaskEntity task,
    String note, {
    NoteCategory category = NoteCategory.info,
  }) {
    final text = note.trim();
    if (text.isEmpty) return Future<void>.value();
    // Pure log append (manager note, no status change) — atomic against the
    // server's current log so it can't clobber a concurrent transition's entry.
    return _mutate(
      () => _repository.transitionTask(
        taskId: task.id,
        expectedFrom: const {},
        patch: const {},
        appendLog: [
          ActivityEntry(
            status: category.activityStatus,
            actorId: _user?.uid ?? '',
            actorName: _user?.displayName,
            at: DateTime.now(),
            note: text,
          ),
        ],
      ),
    );
  }

  Future<void> submitForReview(TaskEntity task) async {
    final submission = task.workDefinition.validateSubmission(task.workContext);
    if (!submission.ok) {
      _emitTransientError(
        submission.firstError ?? "This task isn't ready to submit yet.",
      );
      return;
    }
    final now = DateTime.now();
    final ok = await _transition(
      task,
      from: const {TaskStatus.started, TaskStatus.completed},
      patch: {
        'status': TaskStatus.waitingReview.value,
        'submittedAt': now,
        // Resubmitting clears the rework flag (the redo is in for review).
        'requiresRework': false,
      },
      appendLog: [
        ActivityEntry(
          status: TaskStatus.waitingReview.value,
          actorId: _user?.uid ?? '',
          actorName: _user?.displayName,
          at: now,
        ),
      ],
    );
    if (ok && _user != null) {
      await _notifyTaskEvent(
        task: task,
        type: NotificationType.taskSubmitted,
        actor: _user!,
        recipientOverride: await _reviewerRecipients(task),
      );
    }
  }

  /// Completes + submits a task for review in a single action (so the employee
  /// doesn't re-open the task to hit "Submit for Review").
  ///
  /// Media is uploaded **before** the status write: if any upload fails the
  /// whole transition is aborted — the task stays `started`, the real Storage
  /// error is surfaced, and the employee keeps their selected media to retry.
  /// Evidence the review depends on must never be silently dropped. The uploaded
  /// [attachments] are attached to the **submission event** (Phase 10), and the
  /// first image also mirrors to the legacy `proofImageUrl` so older surfaces
  /// keep working. Returns true only when the submission actually persisted.
  Future<bool> completeAndSubmit(
    TaskEntity task, {
    String? notes,
    List<PickedAttachment> attachments = const [],
  }) async {
    if (task.status != TaskStatus.started) {
      _emitTransientError(
        "That action isn't allowed for this task's current status.",
      );
      return false;
    }
    // The work type owns its completion gate (a general task = required checklist
    // items done; an inventory count = a counted quantity; a transfer = a
    // handover photo). Proof being uploaded *now* counts toward the gate.
    final submission = task.workDefinition.validateSubmission(
      task.workContext.withPendingProof(attachments.length),
    );
    if (!submission.ok) {
      _emitTransientError(
        submission.firstError ?? "This task isn't ready to submit yet.",
      );
      return false;
    }
    if (_user == null || _mutating) return false;

    // The retry cache is scoped to one task — a different task starts fresh so a
    // stale entry can never be reused across submissions.
    if (_uploadCacheTaskId != task.id) {
      _uploadedCache.clear();
      _uploadCacheTaskId = task.id;
    }

    final hasMedia = attachments.isNotEmpty;
    final imageCount = attachments.where((a) => a.type.isImage).length;
    final videoCount = attachments.where((a) => a.type.isVideo).length;

    final prev = _tasks;
    _mutating = true;
    _submitting = true;
    final canceller = UploadCanceller();
    _canceller = canceller;
    final stopwatch = Stopwatch()..start();

    // Throttled progress → state: emit only on a stage change or a whole-percent
    // change, so the screen never rebuilds faster than it needs to.
    SubmissionStage? lastStage;
    int? lastPercent;
    void setProgress(SubmissionProgress p) {
      if (isClosed) return;
      if (p.stage == lastStage && p.percent == lastPercent) return;
      lastStage = p.stage;
      lastPercent = p.percent;
      _submissionProgress = p;
      emit(
        TaskState.loaded(
          _tasks,
          busy: true,
          directory: _directory,
          isSubmitting: true,
          submissionProgress: p,
        ),
      );
    }

    void clearSubmissionState() {
      _mutating = false;
      _submitting = false;
      _submissionProgress = null;
      _canceller = null;
    }

    try {
      setProgress(const SubmissionProgress(SubmissionStage.preparing));

      // Fixed, accurate denominator up front (summed file sizes) so the pooled
      // upload shows a smooth bar — otherwise the total would jump as each file
      // starts, since only a few are ever in flight at once.
      final transferred = List<int>.filled(attachments.length, 0);
      final totals = <int>[for (final a in attachments) await a.file.length()];
      final totalBytes = totals.fold(0, (a, b) => a + b);
      void report() => setProgress(
        SubmissionProgress(
          SubmissionStage.uploading,
          transferredBytes: transferred.fold(0, (a, b) => a + b),
          totalBytes: totalBytes,
        ),
      );

      // Analytics: the upload attempt started (best-effort, never blocks).
      if (hasMedia) {
        _trackTask(
          task,
          AuditEventType.mediaUploadStarted,
          metadata: {
            'fileCount': attachments.length,
            'imageCount': imageCount,
            'videoCount': videoCount,
            'totalBytes': totalBytes,
          },
        );
      }

      // Reuse anything a previous (failed / cancelled) attempt already uploaded,
      // so a retry only re-uploads what's actually missing.
      final results = List<TaskAttachment?>.filled(attachments.length, null);
      for (var i = 0; i < attachments.length; i++) {
        final cached = _uploadedCache[attachments[i].file.path];
        if (cached != null) {
          results[i] = cached;
          transferred[i] = totals[i]; // already done → counts as fully sent
        }
      }
      report(); // enters the uploading stage at (cached)/total before first byte

      // Upload only the not-yet-uploaded files, with bounded concurrency and a
      // shared canceller so the overlay's Cancel aborts every active upload. Any
      // failure throws → the write is aborted and the real error surfaced,
      // keeping the employee's selection.
      final pending = <Future<void> Function()>[];
      for (var i = 0; i < attachments.length; i++) {
        if (results[i] != null) continue; // cache hit — skip the upload
        final idx = i;
        final a = attachments[idx];
        pending.add(() async {
          final uploaded = await _uploadTaskAttachment(
            taskId: task.id,
            file: a.file,
            type: a.type,
            uploadedBy: _user?.uid ?? '',
            uploadedByName: _user?.displayName,
            durationMs: a.durationMs,
            canceller: canceller,
            onProgress: (sent, _) {
              transferred[idx] = sent;
              report();
            },
          );
          results[idx] = uploaded;
          _uploadedCache[a.file.path] = uploaded; // remember for a retry
        });
      }
      await mapPooled(3, pending);
      final uploaded = results.cast<TaskAttachment>();

      setProgress(const SubmissionProgress(SubmissionStage.finalizing));
      String? firstImage;
      for (final a in uploaded) {
        if (a.type == AttachmentType.image) {
          firstImage = a.url;
          break;
        }
      }
      final now = DateTime.now();
      // Atomic finalize: the uploads have already succeeded (immutable Storage
      // objects), so verify the task is STILL `started` on the server and append
      // both events to the server's current log in one transaction. If another
      // device beat us to it, this throws a ConflictFailure (handled below) —
      // the just-uploaded objects orphan and are reclaimed by the orphan-GC pass.
      await _repository.transitionTask(
        taskId: task.id,
        expectedFrom: {TaskStatus.started.value},
        patch: {
          'status': TaskStatus.waitingReview.value,
          'submittedAt': now,
          'notes': notes ?? task.notes,
          // Resubmitting clears the rework flag (the redo is in for review).
          'requiresRework': false,
          // Mirror the first image to the legacy field for back-compat.
          'proofImageUrl': firstImage ?? task.proofImageUrl,
        },
        appendLog: [
          ActivityEntry(
            status: TaskStatus.completed.value,
            actorId: _user?.uid ?? '',
            actorName: _user?.displayName,
            at: now,
            note: notes,
            attachments: uploaded,
          ),
          ActivityEntry(
            status: TaskStatus.waitingReview.value,
            actorId: _user?.uid ?? '',
            actorName: _user?.displayName,
            at: now.add(const Duration(milliseconds: 1)),
          ),
        ],
      );

      // Success — evidence is committed, so drop the retry cache.
      _uploadedCache.clear();
      _uploadCacheTaskId = null;
      clearSubmissionState();
      stopwatch.stop();
      // The Firestore write already pushed the new state through the stream;
      // emit once more to clear the submission flags immediately.
      if (!isClosed) {
        emit(TaskState.loaded(_tasks, busy: false, directory: _directory));
      }
      // Notify whoever can actually review it (best-effort) — the creator when
      // they still can, else the branch's managers, else an admin.
      if (_user != null) {
        await _notifyTaskEvent(
          task: task,
          type: NotificationType.taskSubmitted,
          actor: _user!,
          recipientOverride: await _reviewerRecipients(task),
        );
      }
      // Audit: the business facts (unchanged), plus upload analytics with metrics.
      _trackTask(
        task,
        AuditEventType.taskCompleted,
        metadata: {'attachments': uploaded.length},
      );
      if (uploaded.isNotEmpty) {
        _trackTask(
          task,
          AuditEventType.taskPhotoUploaded,
          metadata: {
            'count': uploaded.length,
            'storagePaths': [for (final a in uploaded) a.url],
          },
        );
        // compressionRatio = compressed / original across the videos that were
        // compressed (originalBytes captured at pick time); null when none were.
        var origBytes = 0;
        var compBytes = 0;
        for (var i = 0; i < attachments.length; i++) {
          final ob = attachments[i].originalBytes;
          if (ob != null && ob > 0) {
            origBytes += ob;
            compBytes += totals[i];
          }
        }
        _trackTask(
          task,
          AuditEventType.mediaUploadCompleted,
          metadata: {
            'fileCount': uploaded.length,
            'imageCount': imageCount,
            'videoCount': videoCount,
            'totalBytes': totalBytes,
            'durationMs': stopwatch.elapsedMilliseconds,
            if (origBytes > 0) 'compressionRatio': compBytes / origBytes,
          },
        );
      }
      return true;
    } on UploadCancelledException {
      // Clean cancel — no error snackbar, keep the selection, and KEEP the retry
      // cache so a re-submit reuses whatever already uploaded.
      clearSubmissionState();
      stopwatch.stop();
      if (!isClosed) emit(TaskState.loaded(prev, directory: _directory));
      if (hasMedia) {
        _trackTask(
          task,
          AuditEventType.mediaUploadCancelled,
          metadata: {
            'fileCount': attachments.length,
            'uploadedCount': _uploadedCache.length,
            'durationMs': stopwatch.elapsedMilliseconds,
          },
        );
      }
      return false;
    } on Failure catch (e) {
      clearSubmissionState();
      stopwatch.stop();
      emit(TaskState.error(e.message));
      emit(TaskState.loaded(prev, directory: _directory));
      if (hasMedia) {
        _trackTask(
          task,
          AuditEventType.mediaUploadFailed,
          metadata: {
            'fileCount': attachments.length,
            'uploadedCount': _uploadedCache.length,
            'durationMs': stopwatch.elapsedMilliseconds,
            'error': e.message,
          },
        );
      }
      return false;
    } catch (_) {
      clearSubmissionState();
      stopwatch.stop();
      emit(const TaskState.error('Something went wrong. Please try again.'));
      emit(TaskState.loaded(prev, directory: _directory));
      if (hasMedia) {
        _trackTask(
          task,
          AuditEventType.mediaUploadFailed,
          metadata: {
            'fileCount': attachments.length,
            'uploadedCount': _uploadedCache.length,
            'durationMs': stopwatch.elapsedMilliseconds,
          },
        );
      }
      return false;
    }
  }

  /// Cancels the in-flight submission's uploads (the overlay's Cancel button):
  /// aborts every active Firebase upload; the submission then unwinds through
  /// [UploadCancelledException] and restores the UI, keeping the picked media.
  /// No-op when nothing is uploading, and harmless once the upload phase is done
  /// (the Firestore write is allowed to finish so uploaded evidence isn't
  /// orphaned mid-commit — the overlay hides Cancel during finalizing).
  void cancelSubmission() => _canceller?.cancel();

  // ─── Picker support ────────────────────────────────────────────
  Future<List<UserEntity>> branchEmployees(String branchId) async {
    try {
      final users = await _getUsersByBranch(branchId);
      // Deactivated accounts are off the roster — they can't be newly assigned
      // a task (an already-assigned inactive user still resolves for display).
      return users.where((u) => u.role.isEmployee && u.isActive).toList();
    } catch (_) {
      return const [];
    }
  }

  Future<List<BranchEntity>> branches() async {
    try {
      final list = await _branchRepository.getBranches();
      return list.where((b) => b.isActive).toList();
    } catch (_) {
      return const [];
    }
  }

  // ─── Task templates ────────────────────────────────────────────
  Future<List<TaskTemplateEntity>> templates({String? branchId}) async {
    try {
      final all = await _repository.getTemplates();
      if (branchId == null || branchId.isEmpty) return all;
      return all
          .where((t) => (t.branchId ?? '').isEmpty || t.branchId == branchId)
          .toList();
    } catch (_) {
      return const [];
    }
  }

  Future<void> saveTemplate({
    required String title,
    String? description,
    required TaskType type,
    required TaskPriority priority,
    String? branchId,
    List<ChecklistItemTemplate> checklistItems = const [],
  }) => _repository.createTemplate(
    TaskTemplateEntity(
      id: '',
      title: title,
      description: description,
      type: type,
      priority: priority,
      branchId: branchId,
      checklistItems: checklistItems,
      createdBy: _user?.uid,
    ),
  );

  Future<void> deleteTemplate(String templateId) =>
      _repository.deleteTemplate(templateId);

  // ─── Recurring shift-task templates ────────────────────────────
  Future<List<RecurringTaskTemplateEntity>> recurringTemplates(
    String branchId,
  ) => _repository.getRecurringTemplates(branchId);

  /// Creates a daily/weekly recurring shift-task template, then starts a
  /// best-effort materialization of *today's* instance (if due today) without
  /// blocking the Save UI on the follow-up task/roster/notification I/O. The
  /// scheduled Cloud Function remains the fallback if that background work
  /// cannot complete.
  Future<void> createRecurringShiftTemplate({
    required String title,
    String? description,
    required TaskPriority priority,
    required String branchId,
    required ScheduleShift shift,
    List<ChecklistItemTemplate> checklistItems = const [],
    required TemplateRepeatMode repeat,
    int weekday = 1,
  }) async {
    final created = await _repository.createRecurringTemplate(
      RecurringTaskTemplateEntity(
        id: '',
        title: title,
        description: description,
        priority: priority,
        checklistItems: checklistItems,
        branchId: branchId,
        shift: shift,
        repeat: repeat,
        weekday: weekday,
        createdBy: _user?.uid,
        updatedBy: _user?.uid,
      ),
    );
    unawaited(_materializeTodayInstance(created));
  }

  Future<void> setRecurringTemplateActive(
    RecurringTaskTemplateEntity template,
    bool active,
  ) => _repository.updateRecurringTemplate(
    template.copyWith(active: active, updatedBy: _user?.uid),
  );

  Future<void> deleteRecurringTemplate(String templateId) =>
      _repository.deleteRecurringTemplate(templateId);

  /// One page of a recurring template's execution history, newest-first
  /// (observability, ADR-011). [before] is the pagination cursor (the last
  /// row's `startedAt`); null loads the first page. Presentation-only read —
  /// the runs are written server-side by `generateShiftTaskInstances`.
  Future<List<AutomationRunEntity>> automationRuns(
    String templateId, {
    required String branchId,
    int limit = 20,
    DateTime? before,
  }) => _repository.getAutomationRuns(
    templateId,
    branchId: branchId,
    limit: limit,
    before: before,
  );

  /// Traceability: the automation run a generated task / notification / audit
  /// entry belongs to, looked up by its shared [correlationId] (null if none).
  Future<AutomationRunEntity?> automationRunByCorrelationId(
    String correlationId, {
    required String branchId,
  }) => _repository.getAutomationRunByCorrelationId(
    correlationId,
    branchId: branchId,
  );

  /// Creates *today's* instance of [template] at the same deterministic id
  /// (`rt_{templateId}_{yyyy-MM-dd}`) the `generateShiftTaskInstances` Cloud
  /// Function uses. "Today" is device-local because DROP operates in one
  /// business timezone (Egypt); the server generator is still the authority if a
  /// device clock or zone is wrong. A no-op when [template] isn't due today
  /// (weekly, wrong weekday), an instance for today already exists, or the
  /// resolved shift window has already closed. Creating mid-window is allowed so
  /// a manager saving a live routine can still get today's task immediately.
  /// Best-effort: the template save already succeeded, and the Cloud Function
  /// will generate the next occurrence at its scheduled run if this fails.
  Future<void> _materializeTodayInstance(
    RecurringTaskTemplateEntity template,
  ) async {
    final now = DateTime.now();
    if (template.repeat == TemplateRepeatMode.weekly &&
        template.weekday != now.weekday) {
      return;
    }
    final today = DateTime(now.year, now.month, now.day);
    final instanceId = 'rt_${template.id}_${_dateKey(today)}';
    final scheduleDay = ScheduleDay.fromDate(today);
    var weekStart = ScheduleWeek.startOf(today);
    ShiftHours hours = ShiftHours.standard(scheduleDay, template.shift);
    try {
      final schedule = await _scheduleRepository.getSchedule(
        template.branchId,
        weekStart,
      );
      if (schedule != null) {
        weekStart = ScheduleWeek.startOf(schedule.weekStart);
        hours = schedule.hoursFor(scheduleDay, template.shift);
      }
    } catch (_) {
      // This is best-effort materialization; the server generator is still the
      // durable fallback and resolves the same policy on its next run.
    }
    final slotDay = DateTime(
      weekStart.year,
      weekStart.month,
      weekStart.day + scheduleDay.index,
    );
    // Wall-clock, not elapsed minutes: a configured 08:30 stays 08:30 even on a
    // DST-transition day, which is how the server resolves it too
    // (`businessCivilTimeMs` in functions/recurring_task_deadline.js). An
    // overnight end (endMinutes > 1440) rolls into the next day by construction.
    DateTime civil(int minutes) => DateTime(
      slotDay.year,
      slotDay.month,
      slotDay.day + minutes ~/ 1440,
      minutes % 1440 ~/ 60,
      minutes % 60,
    );
    final startsAt = civil(hours.startMinutes);
    final deadline = civil(hours.endMinutes);
    if (DateTime.now().isAfter(deadline)) return;
    final instance = TaskEntity(
      id: instanceId,
      title: template.title,
      description: template.description,
      type: TaskType.daily,
      priority: template.priority,
      branchId: template.branchId,
      checklist: template.buildTaskChecklist(),
      assignmentType: TaskAssignmentType.shift,
      shift: template.shift,
      instanceDate: slotDay,
      sourceTemplateId: template.id,
      startsAt: startsAt,
      deadline: deadline,
      createdBy: _user?.uid,
      activityLog: [
        ActivityEntry(
          status: TaskStatus.pending.value,
          actorId: _user?.uid ?? '',
          actorName: _user?.displayName,
          at: now,
        ),
      ],
    );
    try {
      final createdInstance = await _repository.createTaskWithId(instance);
      if (createdInstance == null) return; // already generated today
      final recipients = await _shiftRecipients(
        branchId: template.branchId,
        shift: template.shift,
        day: slotDay,
      );
      if (recipients.isNotEmpty && _user != null) {
        await _notifyTaskEvent(
          task: createdInstance,
          type: NotificationType.taskAssigned,
          actor: _user!,
          recipientOverride: recipients,
        );
      }
    } catch (_) {
      // Best-effort — see doc comment.
    }
  }

  static String _dateKey(DateTime date) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${date.year}-${two(date.month)}-${two(date.day)}';
  }

  // ─── Internals ─────────────────────────────────────────────────
  /// Uploads the manager/admin's picked reference images for [taskId] (in
  /// parallel) and returns the resolved [TaskAttachment]s. Used by create/edit;
  /// a failure propagates so the caller's [_mutate] rolls back and surfaces it.
  Future<List<TaskAttachment>> _uploadReferences(
    String taskId,
    List<PickedAttachment> picked,
  ) => Future.wait([
    for (final p in picked)
      _uploadTaskAttachment(
        taskId: taskId,
        file: p.file,
        type: p.type,
        uploadedBy: _user?.uid ?? '',
        uploadedByName: _user?.displayName,
        durationMs: p.durationMs,
      ),
  ]);

  /// Creates the next instance of a recurring task immediately after [source]
  /// is approved. Resets checklist items to uncompleted; inherits everything
  /// else (title, description, type, priority, branchId, assignees, recurrence).
  ///
  /// **Idempotent by construction.** Each task spawns at most one successor, so
  /// the successor's document id is the deterministic `rec_{source.id}` — a
  /// reopen→re-approve of the same task, a retried spawn, or two racing writers
  /// all target that one id, and the atomic [TaskRepository.createTaskWithId]
  /// makes a duplicate a silent no-op (returns null). This replaced a random
  /// auto-id that double-spawned on reopen→re-approve. The successor keys off
  /// the (stable, unique) current task id rather than the next deadline, so it's
  /// safe even when [source] has no deadline. Its deadline is rolled forward
  /// from the later of the source deadline and now, so approving long after the
  /// original deadline cannot create an already-overdue successor. Best-effort:
  /// the approval itself already committed.
  Future<void> _spawnNextRecurrence(TaskEntity source) async {
    final recurrence = source.recurrence!;
    final now = DateTime.now();
    var anchor = source.deadline != null && source.deadline!.isAfter(now)
        ? source.deadline!
        : now;
    var nextDeadline = recurrence.nextOccurrence(anchor);
    for (var i = 0; i < 400 && !nextDeadline.isAfter(now); i++) {
      anchor = nextDeadline;
      nextDeadline = recurrence.nextOccurrence(anchor);
    }
    if (!nextDeadline.isAfter(now)) return;
    try {
      await _repository.createTaskWithId(
        TaskEntity(
          id: 'rec_${source.id}',
          title: source.title,
          description: source.description,
          type: source.type,
          priority: source.priority,
          branchId: source.branchId,
          assigneeIds: source.assigneeIds,
          checklist: [
            for (final item in source.checklist)
              ChecklistItem(
                id: item.id,
                title: item.title,
                isRequired: item.isRequired,
                completed: false,
                completedAt: null,
              ),
          ],
          recurrence: recurrence,
          assignmentType: source.assignmentType,
          shift: source.shift,
          createdBy: source.createdBy,
          deadline: nextDeadline,
          recurrenceRootId: source.recurrenceRootId ?? source.id,
          occurrenceKey: _dateKey(nextDeadline),
          activityLog: [
            ActivityEntry(
              status: TaskStatus.pending.value,
              actorId: _user?.uid ?? '',
              actorName: _user?.displayName,
              at: now,
              note: 'Auto-created (recurring)',
            ),
          ],
        ),
      );
    } catch (_) {
      // Recurrence spawn is best-effort; the approval itself already succeeded.
    }
  }

  /// Runs a write [action] with optimistic busy state. Returns true on success;
  /// on failure it surfaces the error and rolls the list back to [prev].
  Future<bool> _mutate(Future<void> Function() action) async {
    if (_user == null || _mutating) return false;
    final prev = _tasks;
    _mutating = true;
    emit(TaskState.loaded(prev, busy: true, directory: _directory));
    try {
      await action();
      _mutating = false;
      emit(TaskState.loaded(_tasks, busy: false, directory: _directory));
      return true;
    } on Failure catch (e) {
      _mutating = false;
      emit(TaskState.error(e.message));
      emit(TaskState.loaded(prev, directory: _directory));
      return false;
    } catch (_) {
      _mutating = false;
      emit(const TaskState.error('Something went wrong. Please try again.'));
      emit(TaskState.loaded(prev, directory: _directory));
      return false;
    }
  }

  /// Atomic lifecycle move — the server-authoritative replacement for the old
  /// read-modify-write. A fast client pre-check that [task] is in one of [from]
  /// (skips a pointless transaction on an obviously-illegal action), then
  /// delegates to [TaskRepository.transitionTask], which re-verifies [from]
  /// inside a Firestore transaction and appends [appendLog] to the SERVER's
  /// current activity log (so a concurrent reviewer can't clobber history or
  /// double-fire a transition). A [ConflictFailure] — someone moved the task
  /// first — surfaces the benign refresh notice through [_mutate]; the realtime
  /// stream then delivers the true state. Returns true only when it committed.
  ///
  /// [from] is the legal predecessor set (the task's state machine, previously
  /// encoded in `_canTransition`). [patch] carries only the fields this move
  /// changes (DateTime values are encoded at the data boundary); an explicit
  /// `null` clears a field (e.g. `approvedBy` on reopen).
  Future<bool> _transition(
    TaskEntity task, {
    required Set<TaskStatus> from,
    required Map<String, Object?> patch,
    required List<ActivityEntry> appendLog,
  }) {
    if (!from.contains(task.status)) {
      _emitTransientError(
        "That action isn't allowed for this task's current status.",
      );
      return Future.value(false);
    }
    return _mutate(
      () => _repository.transitionTask(
        taskId: task.id,
        expectedFrom: {for (final s in from) s.value},
        patch: patch,
        appendLog: appendLog,
      ),
    );
  }

  /// Recipients for a **submitted-for-review** notice — the reviewer ladder in
  /// `task/domain/task_review_routing.dart` (creator → branch managers →
  /// admins). Null when the resolver isn't wired, which leaves
  /// `NotifyTaskEvent` on its `[createdBy]` fallback.
  ///
  /// Returning an empty list is meaningful and must be passed through as-is:
  /// `NotifyTaskEvent` reads a non-null empty override as "we looked and there
  /// is nobody", which is the honest outcome for a branch with no reviewer at
  /// all — never as "fall back to the assignees", which would tell the person
  /// who just submitted the work that it had been submitted.
  Future<List<String>?> _reviewerRecipients(TaskEntity task) async {
    final resolve = _resolveTaskReviewers;
    if (resolve == null) return null;
    return resolve(task);
  }

  /// Recipients for a manager/admin review action (approve / reject / rework).
  /// Null for an individual/team task → [NotifyTaskEvent] falls back to
  /// [TaskEntity.assigneeIds]. A shift task has no named assignees, so resolve
  /// the employees rostered on its shift that day (mirrors assignment) — without
  /// this the person who did the work is never told the review outcome. An empty
  /// list means nobody is rostered (valid — simply no recipients).
  Future<List<String>?> _reviewRecipients(TaskEntity task) async {
    if (task.assignmentType != TaskAssignmentType.shift) return null;
    final shift = task.shift;
    final branchId = task.branchId;
    if (shift == null || branchId == null || branchId.isEmpty) return const [];
    return _shiftRecipients(
      branchId: branchId,
      shift: shift,
      day: task.instanceDate ?? task.deadline ?? DateTime.now(),
    );
  }

  /// Emits a one-shot error (for the UI's snackbar listener) then immediately
  /// restores the loaded list so the screen isn't left stuck on an error state.
  void _emitTransientError(String message) {
    final prev = _tasks;
    emit(TaskState.error(message));
    emit(TaskState.loaded(prev, directory: _directory));
  }

  /// Drops every user-scoped stream and cache, returning the cubit to
  /// [TaskState.initial]. Called on sign-out **and** on single-active-session
  /// eviction (both run `AuthCubit`'s pre-sign-out hook), because this cubit is
  /// app-wide: it outlives the session, so without this its Firestore listeners
  /// keep running against a signed-out user and the next person to sign in on
  /// this device sees the previous one's tasks until the first refresh lands.
  void reset() {
    for (final s in _subs.values) {
      s.cancel();
    }
    _subs.clear();
    _taskSources.clear();
    _directory.clear();
    _fetchedBranches.clear();
    _branchNames.clear();
    _uploadedCache.clear();
    _uploadCacheTaskId = null;
    _canceller = null;
    _submissionProgress = null;
    _submitting = false;
    _mutating = false;
    _user = null;
    if (!isClosed) emit(const TaskState.initial());
  }

  @override
  Future<void> close() {
    for (final s in _subs.values) {
      s.cancel();
    }
    return super.close();
  }
}
