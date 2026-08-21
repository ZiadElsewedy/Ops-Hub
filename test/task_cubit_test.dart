import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:opshub/core/enums/audit_event_type.dart';
import 'package:opshub/core/enums/notification_type.dart';
import 'package:opshub/core/enums/schedule_day.dart';
import 'package:opshub/core/enums/schedule_shift.dart';
import 'package:opshub/core/enums/recurrence_frequency.dart';
import 'package:opshub/core/enums/task_assignment_type.dart';
import 'package:opshub/core/enums/task_status.dart';
import 'package:opshub/core/enums/user_role.dart';
import 'package:opshub/core/errors/failures.dart';
import 'package:opshub/features/audit/domain/entities/audit_log_entry.dart';
import 'package:opshub/features/audit/domain/repositories/audit_repository.dart';
import 'package:opshub/features/audit/domain/services/event_tracking_service.dart';
import 'package:opshub/features/auth/domain/entities/user_entity.dart';
import 'package:opshub/features/auth/domain/usecases/get_users_by_branch.dart';
import 'package:opshub/features/branch/domain/entities/branch_entity.dart';
import 'package:opshub/features/branch/domain/repositories/branch_repository.dart';
import 'package:opshub/features/notifications/domain/entities/notification_entity.dart';
import 'package:opshub/features/notifications/domain/repositories/notification_repository.dart';
import 'package:opshub/features/notifications/domain/usecases/notify_task_event.dart';
import 'package:opshub/features/schedule/domain/entities/weekly_schedule_entity.dart';
import 'package:opshub/features/schedule/domain/repositories/schedule_repository.dart';
import 'package:opshub/features/task/domain/entities/activity_entry.dart';
import 'package:opshub/features/task/domain/entities/checklist_item.dart';
import 'package:opshub/features/task/domain/entities/recurrence_config.dart';
import 'package:opshub/features/task/domain/entities/task_entity.dart';
import 'package:opshub/features/task/domain/repositories/task_repository.dart';
import 'package:opshub/features/task/domain/usecases/assign_task.dart';
import 'package:opshub/features/task/domain/usecases/create_task.dart';
import 'package:opshub/features/task/domain/usecases/delete_task.dart';
import 'package:opshub/features/task/domain/usecases/update_task.dart';
import 'package:opshub/features/task/domain/usecases/upload_task_attachment.dart';
import 'package:opshub/features/task/presentation/cubit/task_cubit.dart';
import 'package:opshub/features/task/presentation/cubit/task_state.dart';

/// TaskCubit workflow contract — the P0 hardening pass. Verifies that every
/// lifecycle move now flows through the server-authoritative transactional path
/// (`transitionTask`) with the correct predecessor set, minimal field patch, and
/// a single appended log entry; that an illegal move never reaches the server;
/// that a lost-race [ConflictFailure] is surfaced benignly instead of crashing;
/// that shift-assigned tasks resolve their review notifications from the roster
/// (P1-3); and that reopen/delete are now audited (P1-4).
void main() {
  final manager = UserEntity(
    uid: 'mgr1',
    email: 'm@x.com',
    authProvider: 'password',
    role: UserRole.manager,
    branchId: 'branch1',
    displayName: 'Manager',
  );
  final admin = UserEntity(
    uid: 'admin1',
    email: 'a@x.com',
    authProvider: 'password',
    role: UserRole.admin,
    displayName: 'Admin',
  );

  TaskEntity task({
    required TaskStatus status,
    TaskAssignmentType assignmentType = TaskAssignmentType.individual,
    ScheduleShift? shift,
    List<String> assigneeIds = const ['emp1'],
    int revisionNumber = 0,
    DateTime? startsAt,
  }) => TaskEntity(
    id: 't1',
    title: 'Clean the walk-in',
    status: status,
    branchId: 'branch1',
    assignmentType: assignmentType,
    shift: shift,
    assigneeIds: assigneeIds,
    revisionNumber: revisionNumber,
    startsAt: startsAt,
    createdBy: 'mgr1',
    activityLog: [
      ActivityEntry(
        status: 'pending',
        actorId: 'mgr1',
        at: DateTime(2026, 1, 1),
      ),
    ],
  );

  group('lifecycle transitions are transactional', () {
    test(
      'approve runs from waitingReview with the right patch + one log entry',
      () async {
        final h = _build();
        await h.cubit.load(manager);
        await pumpEventQueue();

        await h.cubit.approveTask(
          task(status: TaskStatus.waitingReview),
          reviewNotes: 'looks good',
        );

        expect(h.repo.transitions, hasLength(1));
        final t = h.repo.transitions.single;
        expect(t.taskId, 't1');
        expect(t.expectedFrom, {'waitingReview'});
        expect(t.patch['status'], 'approved');
        expect(t.patch['approvedBy'], 'mgr1');
        expect(t.patch['requiresRework'], false);
        expect(t.appendLog, hasLength(1));
        expect(t.appendLog.single.status, 'approved');
        expect(t.appendLog.single.note, 'looks good');
      },
    );

    test('reject runs from waitingReview, no rework flag', () async {
      final h = _build();
      await h.cubit.load(manager);
      await pumpEventQueue();

      await h.cubit.rejectTask(
        task(status: TaskStatus.waitingReview),
        reviewNotes: 'no',
      );

      final t = h.repo.transitions.single;
      expect(t.expectedFrom, {'waitingReview'});
      expect(t.patch['status'], 'rejected');
      expect(t.patch['requiresRework'], false);
    });

    test('rework bumps the revision and flags rework', () async {
      final h = _build();
      await h.cubit.load(manager);
      await pumpEventQueue();

      await h.cubit.reworkTask(
        task(status: TaskStatus.waitingReview, revisionNumber: 2),
      );

      final t = h.repo.transitions.single;
      expect(t.patch['status'], 'rejected');
      expect(t.patch['requiresRework'], true);
      expect(t.patch['revisionNumber'], 3);
    });

    test('start accepts pending OR rejected as predecessors', () async {
      final h = _build();
      await h.cubit.load(manager);
      await pumpEventQueue();

      await h.cubit.startTask(task(status: TaskStatus.pending));

      final t = h.repo.transitions.single;
      expect(t.expectedFrom, {'pending', 'rejected'});
      expect(t.patch['status'], 'started');
    });

    test(
      'start before startsAt writes nothing and surfaces the schedule reason',
      () async {
        final h = _build();
        await h.cubit.load(manager);
        await pumpEventQueue();
        final states = <TaskState>[];
        final sub = h.cubit.stream.listen(states.add);

        await h.cubit.startTask(
          task(
            status: TaskStatus.pending,
            startsAt: DateTime.now().add(const Duration(hours: 1)),
          ),
        );
        await pumpEventQueue();
        await sub.cancel();

        expect(h.repo.transitions, isEmpty);
        expect(_errorMessages(states).single, startsWith('Starts at '));
      },
    );

    test(
      'start at an already-open startsAt still transitions normally',
      () async {
        final h = _build();
        await h.cubit.load(manager);
        await pumpEventQueue();

        await h.cubit.startTask(
          task(
            status: TaskStatus.pending,
            startsAt: DateTime.now().subtract(const Duration(seconds: 1)),
          ),
        );

        expect(h.repo.transitions, hasLength(1));
        expect(h.repo.transitions.single.patch['status'], 'started');
      },
    );
  });

  test('an illegal transition never reaches the server', () async {
    final h = _build();
    await h.cubit.load(manager);
    await pumpEventQueue();
    final states = <TaskState>[];
    final sub = h.cubit.stream.listen(states.add);

    // pending → approved is not a legal move.
    await h.cubit.approveTask(task(status: TaskStatus.pending));
    await sub.cancel();

    expect(h.repo.transitions, isEmpty);
    expect(_errorMessages(states), isNotEmpty);
  });

  test('a lost-race ConflictFailure is surfaced benignly, not crashed', () async {
    final h = _build();
    await h.cubit.load(manager);
    await pumpEventQueue();
    h.repo.failTransitionWith = const ConflictFailure(
      'This task was just updated by someone else.',
    );
    final states = <TaskState>[];
    final sub = h.cubit.stream.listen(states.add);

    await h.cubit.approveTask(task(status: TaskStatus.waitingReview));
    await pumpEventQueue();
    await sub.cancel();

    // It attempted the transaction, reported the conflict message, and recovered
    // to a loaded list (no stuck error state, no throw).
    expect(h.repo.transitions, hasLength(1));
    expect(
      _errorMessages(states),
      contains('This task was just updated by someone else.'),
    );
    expect(
      states.last.maybeWhen(
        loaded: (_, _, _, _, _) => true,
        orElse: () => false,
      ),
      isTrue,
    );
  });

  test(
    'reopen transitions out of approved and audits the reopen (P1-4)',
    () async {
      final audit = _RecordingAudit();
      final h = _build(audit: EventTrackingService(audit));
      await h.cubit.load(admin);
      await pumpEventQueue();

      await h.cubit.reopenTask(task(status: TaskStatus.approved));
      await pumpEventQueue();

      final t = h.repo.transitions.single;
      expect(t.expectedFrom, {'approved'});
      expect(t.patch['status'], 'started');
      // approvedBy is explicitly cleared to null (present-but-null, not absent).
      expect(t.patch.containsKey('approvedBy'), isTrue);
      expect(t.patch['approvedBy'], isNull);
      expect(audit.events, contains(AuditEventType.taskReopened));
    },
  );

  group('deletion', () {
    test('deletes and audits a non-approved task (P1-4)', () async {
      final audit = _RecordingAudit();
      final h = _build(audit: EventTrackingService(audit));
      await h.cubit.load(manager);
      await pumpEventQueue();
      h.seed([task(status: TaskStatus.pending)]);
      await pumpEventQueue();

      await h.cubit.deleteTask('t1');
      await pumpEventQueue();

      expect(h.repo.deleted, ['t1']);
      expect(audit.events, contains(AuditEventType.taskDeleted));
    });

    test('blocks deleting an approved task', () async {
      final h = _build();
      await h.cubit.load(manager);
      await pumpEventQueue();
      h.seed([task(status: TaskStatus.approved)]);
      await pumpEventQueue();

      await h.cubit.deleteTask('t1');

      expect(h.repo.deleted, isEmpty);
    });

    test('blocks deleting a missed task', () async {
      final h = _build();
      await h.cubit.load(manager);
      await pumpEventQueue();
      h.seed([task(status: TaskStatus.missed)]);
      await pumpEventQueue();

      await h.cubit.deleteTask('t1');

      expect(h.repo.deleted, isEmpty);
    });
  });

  test(
    'approving a shift task notifies the rostered employees (P1-3)',
    () async {
      final h = _build();
      h.schedule.schedule = _rosterEveryShift(const ['shiftEmp']);
      await h.cubit.load(manager);
      await pumpEventQueue();

      // A shift task has NO named assignees — the old code notified assigneeIds
      // (empty), so the person who did the work heard nothing.
      await h.cubit.approveTask(
        task(
          status: TaskStatus.waitingReview,
          assignmentType: TaskAssignmentType.shift,
          shift: ScheduleShift.morning,
          assigneeIds: const [],
        ),
      );
      await pumpEventQueue();

      final approved = h.notify.calls.firstWhere(
        (c) => c.type == NotificationType.taskApproved,
      );
      expect(approved.recipients, ['shiftEmp']);
    },
  );

  // ── Recurrence spawn is deterministic + idempotent (P0 duplicate fix) ──
  group('recurring approval spawns a deterministic, idempotent successor', () {
    TaskEntity recurring({
      required String id,
      String? rootId,
      DateTime? deadline,
    }) => TaskEntity(
      id: id,
      title: 'Restock cooler',
      status: TaskStatus.waitingReview,
      branchId: 'branch1',
      assigneeIds: const ['emp1'],
      deadline: deadline ?? DateTime(2026, 1, 10),
      recurrence: const RecurrenceConfig(frequency: RecurrenceFrequency.daily),
      recurrenceRootId: rootId,
      createdBy: 'mgr1',
      checklist: const [
        ChecklistItem(id: 'c1', title: 'Count stock', completed: true),
      ],
      activityLog: [
        ActivityEntry(
          status: 'pending',
          actorId: 'mgr1',
          at: DateTime(2026, 1, 1),
        ),
      ],
    );

    test(
      'successor id is rec_{sourceId}, root = source, checklist reset',
      () async {
        final h = _build();
        await h.cubit.load(manager);
        await pumpEventQueue();

        await h.cubit.approveTask(recurring(id: 't1'));
        await pumpEventQueue();

        expect(h.repo.createdWithId, hasLength(1));
        final spawned = h.repo.createdWithId.single;
        expect(spawned.id, 'rec_t1');
        expect(
          spawned.recurrenceRootId,
          't1',
        ); // root defaults to the source id
        expect(spawned.status, TaskStatus.pending);
        expect(
          spawned.checklist.single.completed,
          isFalse,
        ); // reset for the redo
      },
    );

    test(
      'reopen→re-approve targets the SAME id (no random double-spawn)',
      () async {
        final h = _build();
        await h.cubit.load(manager);
        await pumpEventQueue();

        // First approve creates rec_t1. On the reopen→re-approve replay the id now
        // exists, so the atomic createTaskWithId returns null — one task, not two.
        await h.cubit.approveTask(recurring(id: 't1'));
        await pumpEventQueue();
        h.repo.createWithIdExists = true;
        await h.cubit.approveTask(recurring(id: 't1'));
        await pumpEventQueue();

        // Both attempts used the identical deterministic id (the old bug used a
        // fresh random id each time → two successors).
        expect(h.repo.createdWithId.map((t) => t.id), ['rec_t1', 'rec_t1']);
      },
    );

    test(
      'a child keeps the lineage root while keying off its own id',
      () async {
        final h = _build();
        await h.cubit.load(manager);
        await pumpEventQueue();

        await h.cubit.approveTask(recurring(id: 'rec_t1', rootId: 't1'));
        await pumpEventQueue();

        final spawned = h.repo.createdWithId.single;
        expect(spawned.id, 'rec_rec_t1'); // keyed on the current task id
        expect(
          spawned.recurrenceRootId,
          't1',
        ); // lineage preserved down the chain
      },
    );

    test(
      'approval long after the source deadline spawns a future successor',
      () async {
        final h = _build();
        await h.cubit.load(manager);
        await pumpEventQueue();
        final beforeApprove = DateTime.now();

        await h.cubit.approveTask(
          recurring(
            id: 'stale',
            deadline: beforeApprove.subtract(const Duration(days: 10)),
          ),
        );
        await pumpEventQueue();

        final spawned = h.repo.createdWithId.single;
        expect(spawned.deadline, isNotNull);
        expect(spawned.deadline!.isAfter(beforeApprove), isTrue);
      },
    );
  });

  group('assignee picker', () {
    test('branchEmployees excludes deactivated accounts', () async {
      final active = UserEntity(
        uid: 'e_active',
        email: 'active@x.com',
        authProvider: 'password',
        role: UserRole.employee,
        branchId: 'branch1',
        displayName: 'Active',
      );
      final inactive = UserEntity(
        uid: 'e_inactive',
        email: 'inactive@x.com',
        authProvider: 'password',
        role: UserRole.employee,
        branchId: 'branch1',
        displayName: 'Inactive',
        isActive: false,
      );
      // A manager in the branch must never appear in the employee picker either.
      final harness = _build(branchUsers: [active, inactive, manager]);

      final pickable = await harness.cubit.branchEmployees('branch1');

      expect(pickable.map((u) => u.uid), ['e_active']);
    });
  });
}

// ─── Fakes (hand-written, matching the repo's test convention) ───────────────

Iterable<String> _errorMessages(List<TaskState> states) => states
    .map((s) => s.maybeWhen(error: (m) => m, orElse: () => null))
    .whereType<String>();

WeeklyScheduleEntity _rosterEveryShift(List<String> uids) =>
    WeeklyScheduleEntity(
      id: 'sched1',
      branchId: 'branch1',
      weekStart: DateTime(2026, 1, 4),
      assignments: {
        for (final d in ScheduleDay.values)
          d: {for (final s in ScheduleShift.values) s: uids},
      },
    );

class _Harness {
  _Harness(this.cubit, this.repo, this.schedule, this.notify);
  final TaskCubit cubit;
  final _RecordingTaskRepository repo;
  final _FakeSchedule schedule;
  final _RecordingNotify notify;
  void seed(List<TaskEntity> tasks) => repo.controller.add(tasks);
}

_Harness _build({EventTrackingService? audit, List<UserEntity> branchUsers = const []}) {
  final repo = _RecordingTaskRepository();
  final schedule = _FakeSchedule();
  final notify = _RecordingNotify();
  final cubit = TaskCubit(
    repository: repo,
    branchRepository: _FakeBranchRepository(),
    scheduleRepository: schedule,
    createTask: CreateTask(repo),
    updateTask: UpdateTask(repo),
    deleteTask: DeleteTask(repo),
    assignTask: AssignTask(repo),
    uploadTaskAttachment: UploadTaskAttachment(repo),
    getUsersByBranch: _FakeGetUsers(branchUsers),
    notifyTaskEvent: notify,
    eventTracking: audit,
  );
  addTearDown(() async {
    await cubit.close();
    await repo.controller.close();
  });
  return _Harness(cubit, repo, schedule, notify);
}

class _TransitionCall {
  _TransitionCall(this.taskId, this.expectedFrom, this.patch, this.appendLog);
  final String taskId;
  final Set<String> expectedFrom;
  final Map<String, Object?> patch;
  final List<ActivityEntry> appendLog;
}

class _RecordingTaskRepository implements TaskRepository {
  final controller = StreamController<List<TaskEntity>>.broadcast();
  final transitions = <_TransitionCall>[];
  final deleted = <String>[];
  final createdWithId = <TaskEntity>[];
  // When true, simulate the deterministic id already existing → the atomic
  // createTaskWithId returns null (a benign no-op) instead of a second task.
  bool createWithIdExists = false;
  Object? failTransitionWith;

  @override
  Future<TaskEntity?> createTaskWithId(TaskEntity task) async {
    createdWithId.add(task);
    return createWithIdExists ? null : task;
  }

  @override
  Stream<List<TaskEntity>> watchAllTasks() => controller.stream;
  @override
  Stream<List<TaskEntity>> watchTasksByBranch(String branchId) =>
      controller.stream;
  @override
  Stream<List<TaskEntity>> watchEmployeeTasks(String employeeId) =>
      controller.stream;
  @override
  Stream<List<TaskEntity>> watchShiftTasks({
    required String branchId,
    required ScheduleShift shift,
  }) => controller.stream;

  @override
  Future<void> transitionTask({
    required String taskId,
    required Set<String> expectedFrom,
    required Map<String, Object?> patch,
    required List<ActivityEntry> appendLog,
  }) async {
    transitions.add(_TransitionCall(taskId, expectedFrom, patch, appendLog));
    final err = failTransitionWith;
    if (err != null) throw err;
  }

  @override
  Future<void> deleteTask(String taskId) async => deleted.add(taskId);

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} not stubbed');
}

class _FakeBranchRepository implements BranchRepository {
  @override
  Future<List<BranchEntity>> getBranches({
    bool includeDeleted = false,
    bool forceRefresh = false,
  }) async => const [];
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class _FakeSchedule implements ScheduleRepository {
  WeeklyScheduleEntity? schedule;
  @override
  Future<WeeklyScheduleEntity?> getSchedule(
    String branchId,
    DateTime weekStart,
  ) async => schedule;

  /// The real cache-first read falls back to the same document on a miss, so
  /// the fake serves the same roster. Overridden explicitly (rather than left
  /// to `noSuchMethod`) because `TaskCubit` binds shift streams from *this*
  /// call — letting it throw would silently move every test onto the slower
  /// server-reconcile path and leave the fast path untested.
  @override
  Future<WeeklyScheduleEntity?> getScheduleCacheFirst(
    String branchId,
    DateTime weekStart,
  ) async => schedule;
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class _FakeGetUsers implements GetUsersByBranch {
  _FakeGetUsers([this.users = const []]);
  final List<UserEntity> users;
  @override
  Future<List<UserEntity>> call(String branchId) async => users;
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class _RecordingNotify extends NotifyTaskEvent {
  _RecordingNotify() : super(_NullNotificationRepo());
  final calls = <({NotificationType type, List<String>? recipients})>[];

  @override
  Future<void> call({
    required TaskEntity task,
    required NotificationType type,
    required UserEntity actor,
    List<String>? recipientOverride,
  }) async {
    calls.add((type: type, recipients: recipientOverride));
  }
}

class _NullNotificationRepo implements NotificationRepository {
  @override
  Future<void> createMany(List<NotificationEntity> notifications) async {}
  @override
  dynamic noSuchMethod(Invocation invocation) => Future<void>.value();
}

class _RecordingAudit implements AuditRepository {
  final events = <AuditEventType>[];
  @override
  Future<void> record(AuditLogEntry entry) async => events.add(entry.eventType);
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}
