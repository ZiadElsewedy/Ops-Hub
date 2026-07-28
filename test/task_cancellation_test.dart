import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drop/core/enums/audit_event_type.dart';
import 'package:drop/core/enums/notification_type.dart';
import 'package:drop/core/enums/schedule_day.dart';
import 'package:drop/core/enums/schedule_shift.dart';
import 'package:drop/core/enums/task_assignment_type.dart';
import 'package:drop/core/enums/task_cancel_reason.dart';
import 'package:drop/core/enums/task_status.dart';
import 'package:drop/core/enums/user_role.dart';
import 'package:drop/core/theme/app_colors.dart';
import 'package:drop/core/widgets/status_badge.dart';
import 'package:drop/features/audit/domain/entities/audit_log_entry.dart';
import 'package:drop/features/audit/domain/repositories/audit_repository.dart';
import 'package:drop/features/audit/domain/services/event_tracking_service.dart';
import 'package:drop/features/auth/domain/entities/user_entity.dart';
import 'package:drop/features/auth/domain/usecases/get_users_by_branch.dart';
import 'package:drop/features/branch/domain/entities/branch_entity.dart';
import 'package:drop/features/branch/domain/repositories/branch_repository.dart';
import 'package:drop/features/notifications/domain/entities/notification_entity.dart';
import 'package:drop/features/notifications/domain/repositories/notification_repository.dart';
import 'package:drop/features/notifications/domain/usecases/notify_task_event.dart';
import 'package:drop/features/schedule/domain/entities/weekly_schedule_entity.dart';
import 'package:drop/features/schedule/domain/repositories/schedule_repository.dart';
import 'package:drop/features/task/data/models/task_model.dart';
import 'package:drop/features/task/domain/active_window.dart';
import 'package:drop/features/task/domain/entities/activity_entry.dart';
import 'package:drop/features/task/domain/entities/automation_run_entity.dart';
import 'package:drop/features/task/domain/entities/recurring_task_template_entity.dart';
import 'package:drop/features/task/domain/entities/task_attachment.dart';
import 'package:drop/features/task/domain/entities/task_entity.dart';
import 'package:drop/features/task/domain/entities/task_template_entity.dart';
import 'package:drop/features/task/domain/repositories/task_repository.dart';
import 'package:drop/features/task/domain/task_feed.dart';
import 'package:drop/features/task/domain/task_metrics.dart';
import 'package:drop/features/task/domain/usecases/assign_task.dart';
import 'package:drop/features/task/domain/usecases/create_task.dart';
import 'package:drop/features/task/domain/usecases/delete_task.dart';
import 'package:drop/features/task/domain/usecases/update_task.dart';
import 'package:drop/features/task/domain/usecases/upload_task_attachment.dart';
import 'package:drop/features/task/presentation/cubit/task_cubit.dart';
import 'package:drop/features/task/presentation/cubit/task_state.dart';

/// **Cancelled** — the terminal business decision that work will not be done
/// (`docs/design/AUTOMATED_TASKS_PRODUCT_SPEC.md` Phase 1).
///
/// The contract under test is the part that is easy to get quietly wrong: a
/// cancellation must be *reachable only from Pending/Started*, must *always*
/// carry a structured reason, and must count **nowhere** — not as success, not
/// as failure, not as overdue, not as active work. The last property is the one
/// that keeps Cancel from becoming a way to launder work that simply was not
/// done, so it is asserted from every angle a number is derived.
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
  final employee = UserEntity(
    uid: 'emp1',
    email: 'e@x.com',
    authProvider: 'password',
    role: UserRole.employee,
    branchId: 'branch1',
    displayName: 'Employee',
  );

  TaskEntity task({
    required TaskStatus status,
    DateTime? deadline,
    DateTime? cancelledAt,
    TaskCancelReason? cancelReason,
    TaskAssignmentType assignmentType = TaskAssignmentType.individual,
    ScheduleShift? shift,
    List<String> assigneeIds = const ['emp1'],
  }) => TaskEntity(
    id: 't1',
    title: 'Restock the cold case',
    status: status,
    branchId: 'branch1',
    assignmentType: assignmentType,
    shift: shift,
    assigneeIds: assigneeIds,
    createdBy: 'mgr1',
    deadline: deadline,
    instanceDate: DateTime(2026, 7, 28),
    cancelledAt: cancelledAt,
    cancelReason: cancelReason,
  );

  group('TaskStatus.cancelled', () {
    test('is a closed, inactive, non-review outcome', () {
      expect(TaskStatus.fromString('cancelled'), TaskStatus.cancelled);
      expect(TaskStatus.cancelled.value, 'cancelled');
      expect(TaskStatus.cancelled.isCancelled, isTrue);
      expect(TaskStatus.cancelled.isTerminal, isTrue);
      expect(TaskStatus.cancelled.isActive, isFalse);
      // Not a review verdict — nobody approved or rejected the work.
      expect(TaskStatus.cancelled.isReviewed, isFalse);
      // …and distinctly NOT missed. Merging the two would destroy the whole
      // reporting distinction the spec is built on (§8).
      expect(TaskStatus.cancelled.isMissed, isFalse);
    });

    test('is cancellable only from pending or started (§5.4)', () {
      expect(TaskStatus.pending.isCancellable, isTrue);
      expect(TaskStatus.started.isCancellable, isTrue);
      // A submitted task must be reviewed, never voided.
      expect(TaskStatus.waitingReview.isCancellable, isFalse);
      expect(TaskStatus.completed.isCancellable, isFalse);
      expect(TaskStatus.rejected.isCancellable, isFalse);
      // Terminal is terminal.
      expect(TaskStatus.approved.isCancellable, isFalse);
      expect(TaskStatus.missed.isCancellable, isFalse);
      expect(TaskStatus.cancelled.isCancellable, isFalse);
    });

    test('an unknown stored status still falls back to pending', () {
      expect(TaskStatus.fromString('canceled'), TaskStatus.pending);
      expect(TaskStatus.fromString(null), TaskStatus.pending);
    });
  });

  group('TaskCancelReason', () {
    test('exposes exactly the five picklist options', () {
      expect(TaskCancelReason.selectable, hasLength(5));
      expect(
        TaskCancelReason.selectable.map((r) => r.label),
        containsAll([
          'Duplicate Task',
          'Wrong Task Generated',
          'No Longer Needed',
          'Shift Cancelled',
          'Management Decision',
        ]),
      );
      // `unknown` is a read fallback, never something a manager can pick.
      expect(
        TaskCancelReason.selectable.contains(TaskCancelReason.unknown),
        isFalse,
      );
    });

    test('the wire ids are frozen', () {
      // These strings are persisted on live records. Changing one silently
      // rewrites history — the label may be reworded, the id may not.
      expect(TaskCancelReason.duplicate.value, 'duplicate');
      expect(TaskCancelReason.wrongTaskGenerated.value, 'wrong_generated');
      expect(TaskCancelReason.noLongerNeeded.value, 'no_longer_needed');
      expect(TaskCancelReason.shiftCancelled.value, 'shift_cancelled');
      expect(TaskCancelReason.managementDecision.value, 'management_decision');
    });

    test('an unrecognised code reads as unknown, a missing one as null', () {
      // A newer build's code must never silently become a DIFFERENT reason —
      // that would corrupt the by-reason reporting on an older client.
      expect(
        TaskCancelReason.fromString('some_future_code'),
        TaskCancelReason.unknown,
      );
      // "No reason recorded" stays distinguishable from "reason I don't know".
      expect(TaskCancelReason.fromString(null), isNull);
      expect(TaskCancelReason.fromString(''), isNull);
    });
  });

  group('reporting exclusion (§8)', () {
    final now = DateTime(2026, 7, 28, 12);

    test('a cancelled task is never in the active window', () {
      // Even cancelled *today*: unlike an approved task it earns no same-day
      // credit, because the work never happened.
      expect(
        isTaskInActiveWindow(
          task(status: TaskStatus.cancelled, cancelledAt: now),
          now,
        ),
        isFalse,
      );
      expect(
        activeWindowTasks([
          task(status: TaskStatus.pending),
          task(status: TaskStatus.cancelled, cancelledAt: now),
        ], now),
        hasLength(1),
      );
    });

    test('a cancelled task past its deadline is not overdue', () {
      final overdueDeadline = now.subtract(const Duration(hours: 5));
      expect(
        isTaskOverdue(
          task(status: TaskStatus.pending, deadline: overdueDeadline),
          now,
        ),
        isTrue,
      );
      // Late is a visual on ACTIVE work and disappears the instant a task
      // reaches a terminal state (§3.1) — cancelling is one of those instants.
      expect(
        isTaskOverdue(
          task(status: TaskStatus.cancelled, deadline: overdueDeadline),
          now,
        ),
        isFalse,
      );
      expect(
        overdueCount([
          task(status: TaskStatus.pending, deadline: overdueDeadline),
          task(status: TaskStatus.cancelled, deadline: overdueDeadline),
        ], now),
        1,
      );
    });

    test('a cancelled task drops out of the feed entirely', () {
      final feed = applyFeed([
        task(status: TaskStatus.pending),
        task(status: TaskStatus.cancelled, cancelledAt: now),
      ], const TaskFeedFilter(), now);
      expect(feed, hasLength(1));
      expect(feed.single.status, TaskStatus.pending);
    });
  });

  group('TaskModel serialization', () {
    test('writes the cancellation record with the stable reason id', () {
      final map = TaskModel(
        id: '1',
        title: 't',
        status: TaskStatus.cancelled,
        cancelledAt: DateTime(2026, 7, 28, 9, 30),
        cancelledBy: 'mgr1',
        cancelReason: TaskCancelReason.noLongerNeeded,
        cancelNote: 'Supplier delivered early',
      ).toMap();

      expect(map['status'], 'cancelled');
      expect(map['cancelReason'], 'no_longer_needed');
      expect(map['cancelledBy'], 'mgr1');
      expect(map['cancelNote'], 'Supplier delivered early');
      expect(map['cancelledAt'], isNotNull);
    });

    test('a legacy doc without the fields defaults safely', () {
      final m = TaskModel.fromMap(const {'title': 't'});
      expect(m.cancelledAt, isNull);
      expect(m.cancelledBy, isNull);
      expect(m.cancelReason, isNull);
      expect(m.cancelNote, isNull);
    });

    test('round-trips through the entity', () {
      final entity = TaskModel.fromMap(const {
        'title': 't',
        'status': 'cancelled',
        'cancelledBy': 'mgr1',
        'cancelReason': 'wrong_generated',
        'cancelNote': 'Template targets the wrong shift',
      }).toEntity();

      expect(entity.status, TaskStatus.cancelled);
      expect(entity.cancelReason, TaskCancelReason.wrongTaskGenerated);
      expect(entity.cancelNote, 'Template targets the wrong shift');

      final back = TaskModel.fromEntity(entity).toMap();
      expect(back['cancelReason'], 'wrong_generated');
    });
  });

  group('TaskCubit.cancelTask', () {
    test('cancels from pending with the reason in the patch + log', () async {
      final audit = _RecordingAudit();
      final h = _build(audit: EventTrackingService(audit));
      await h.cubit.load(manager);
      await pumpEventQueue();

      await h.cubit.cancelTask(
        task(status: TaskStatus.pending),
        reason: TaskCancelReason.duplicate,
        note: '  Same as the morning routine  ',
      );
      await pumpEventQueue();

      final t = h.repo.transitions.single;
      expect(t.expectedFrom, {'pending', 'started'});
      expect(t.patch['status'], 'cancelled');
      expect(t.patch['cancelReason'], 'duplicate');
      expect(t.patch['cancelledBy'], 'mgr1');
      expect(t.patch['cancelledAt'], isA<DateTime>());
      expect(t.patch['cancelNote'], 'Same as the morning routine');

      // The reason reaches the timeline too, so the record reads honestly even
      // where the cancel fields aren't rendered.
      expect(t.appendLog, hasLength(1));
      expect(t.appendLog.single.status, 'cancelled');
      expect(
        t.appendLog.single.note,
        'Duplicate Task — Same as the morning routine',
      );

      expect(audit.events, contains(AuditEventType.taskCancelled));
    });

    test('cancels from started', () async {
      final h = _build();
      await h.cubit.load(manager);
      await pumpEventQueue();

      await h.cubit.cancelTask(
        task(status: TaskStatus.started),
        reason: TaskCancelReason.shiftCancelled,
      );

      final t = h.repo.transitions.single;
      expect(t.patch['status'], 'cancelled');
      // A blank note is stored as null, not an empty string.
      expect(t.patch['cancelNote'], isNull);
      expect(t.appendLog.single.note, 'Shift Cancelled');
    });

    test('refuses a submitted task — it must be reviewed (§5.4)', () async {
      final h = _build();
      await h.cubit.load(manager);
      await pumpEventQueue();
      final states = <TaskState>[];
      final sub = h.cubit.stream.listen(states.add);

      await h.cubit.cancelTask(
        task(status: TaskStatus.waitingReview),
        reason: TaskCancelReason.noLongerNeeded,
      );
      await sub.cancel();

      expect(h.repo.transitions, isEmpty);
      expect(_errorMessages(states), isNotEmpty);
    });

    test('refuses a task that is already terminal (§3.5)', () async {
      final h = _build();
      await h.cubit.load(manager);
      await pumpEventQueue();

      for (final status in [
        TaskStatus.approved,
        TaskStatus.missed,
        TaskStatus.cancelled,
      ]) {
        await h.cubit.cancelTask(
          task(status: status),
          reason: TaskCancelReason.managementDecision,
        );
      }

      expect(h.repo.transitions, isEmpty);
    });

    test('refuses the unknown reason — a code we may never write', () async {
      final h = _build();
      await h.cubit.load(manager);
      await pumpEventQueue();
      final states = <TaskState>[];
      final sub = h.cubit.stream.listen(states.add);

      await h.cubit.cancelTask(
        task(status: TaskStatus.pending),
        reason: TaskCancelReason.unknown,
      );
      await sub.cancel();

      expect(h.repo.transitions, isEmpty);
      expect(
        _errorMessages(states),
        contains('Choose a reason before cancelling this task.'),
      );
    });

    test('a cancelled task cannot be edited, deleted or reassigned', () async {
      final h = _build();
      await h.cubit.load(manager);
      await pumpEventQueue();
      h.seed([task(status: TaskStatus.cancelled)]);
      await pumpEventQueue();
      final states = <TaskState>[];
      final sub = h.cubit.stream.listen(states.add);

      await h.cubit.deleteTask('t1');
      await h.cubit.editTask(task(status: TaskStatus.cancelled));
      await h.cubit.assignEmployees(taskId: 't1', employeeIds: ['emp2']);
      await pumpEventQueue();
      await sub.cancel();

      expect(h.repo.deleted, isEmpty);
      expect(h.repo.updated, isEmpty);
      expect(h.repo.assigned, isEmpty);
      // …and it is reported as CANCELLED, never mislabelled "approved and
      // locked" — the two mean opposite things and only one is reopenable.
      final messages = _errorMessages(states).join(' | ');
      expect(messages, contains('Cancelled tasks are closed'));
      expect(messages, isNot(contains('Approved tasks are locked')));
    });
  });

  group('notify on cancel (§9.2/§9.3)', () {
    test('targets the assignees with the reason in the body', () async {
      final h = _build();
      await h.cubit.load(manager);
      await pumpEventQueue();

      await h.cubit.cancelTask(
        task(status: TaskStatus.pending),
        reason: TaskCancelReason.noLongerNeeded,
      );
      await pumpEventQueue();

      expect(h.notify.calls, hasLength(1));
      final call = h.notify.calls.single;
      expect(call.type, NotificationType.taskCancelled);
      // Null override => NotifyTaskEvent falls back to the task's assignees.
      expect(call.recipients, isNull);
      // The person losing the work is told WHY, not just that it's gone.
      expect(h.notify.sent.single.recipientUid, 'emp1');
      expect(h.notify.sent.single.body, contains('No Longer Needed'));
    });

    test('a shift-broadcast cancel resolves the rostered crew', () async {
      final h = _build();
      h.schedule.schedule = _rosterEveryShift(['emp7', 'emp8']);
      await h.cubit.load(manager);
      await pumpEventQueue();

      await h.cubit.cancelTask(
        task(
          status: TaskStatus.started,
          assignmentType: TaskAssignmentType.shift,
          shift: ScheduleShift.morning,
          assigneeIds: const [],
        ),
        reason: TaskCancelReason.shiftCancelled,
      );
      await pumpEventQueue();

      // A shift task has no named assignee, so without this nobody who was
      // actually going to do the work would ever hear about the cancel.
      expect(h.notify.calls.single.recipients, containsAll(['emp7', 'emp8']));
    });

    test('nobody rostered is a no-op, never a failure (§9.3)', () async {
      final h = _build();
      h.schedule.schedule = null; // no roster for the week
      await h.cubit.load(manager);
      await pumpEventQueue();

      await h.cubit.cancelTask(
        task(
          status: TaskStatus.pending,
          assignmentType: TaskAssignmentType.shift,
          shift: ScheduleShift.morning,
          assigneeIds: const [],
        ),
        reason: TaskCancelReason.duplicate,
      );
      await pumpEventQueue();

      // The cancel still committed — an empty assignee set must never break it.
      expect(h.repo.transitions, hasLength(1));
      expect(h.notify.calls.single.recipients, isEmpty);
    });
  });

  group('report incorrect (§5.2)', () {
    test('files under the reporter, notifies managers, keeps the status', () async {
      final audit = _RecordingAudit();
      final h = _build(audit: EventTrackingService(audit));
      h.users.users = [
        UserEntity(
          uid: 'mgr9',
          email: 'm9@x.com',
          authProvider: 'password',
          role: UserRole.manager,
          branchId: 'branch1',
        ),
        UserEntity(
          uid: 'emp1',
          email: 'e1@x.com',
          authProvider: 'password',
          role: UserRole.employee,
          branchId: 'branch1',
        ),
      ];
      await h.cubit.load(employee);
      await pumpEventQueue();

      await h.cubit.reportTaskIncorrect(
        task(status: TaskStatus.pending),
        note: '  This is the night routine, not ours  ',
      );
      await pumpEventQueue();

      final t = h.repo.transitions.single;
      // Reporting is NOT a lifecycle move — the work stays exactly where it was
      // until a manager decides.
      expect(t.patch.containsKey('status'), isFalse);
      expect(t.patch['reportedIncorrectBy'], 'emp1');
      expect(t.patch['reportedIncorrectNote'], 'This is the night routine, not ours');
      expect(t.appendLog.single.status, kActivityReportedIncorrect);

      // Routed to the branch's managers — never branch-wide, never to employees.
      expect(h.notify.calls.single.type, NotificationType.taskReportedIncorrect);
      expect(h.notify.calls.single.recipients, ['mgr9']);
      expect(audit.events, contains(AuditEventType.taskReportedIncorrect));
    });

    test('an empty explanation is refused', () async {
      final h = _build();
      await h.cubit.load(employee);
      await pumpEventQueue();
      final states = <TaskState>[];
      final sub = h.cubit.stream.listen(states.add);

      await h.cubit.reportTaskIncorrect(task(status: TaskStatus.pending), note: '   ');
      await sub.cancel();

      // A report with no explanation gives the manager nothing to decide on.
      expect(h.repo.transitions, isEmpty);
      expect(_errorMessages(states), isNotEmpty);
    });

    test('a closed task cannot be reported', () async {
      final h = _build();
      await h.cubit.load(employee);
      await pumpEventQueue();

      await h.cubit.reportTaskIncorrect(
        task(status: TaskStatus.cancelled),
        note: 'wrong task',
      );

      expect(h.repo.transitions, isEmpty);
    });

    test('a manager dismissal clears the report', () async {
      final audit = _RecordingAudit();
      final h = _build(audit: EventTrackingService(audit));
      await h.cubit.load(manager);
      await pumpEventQueue();

      await h.cubit.dismissIncorrectReport(
        task(status: TaskStatus.pending).copyWith(
          reportedIncorrectBy: 'emp1',
          reportedIncorrectAt: DateTime(2026, 7, 28),
          reportedIncorrectNote: 'wrong shift',
        ),
      );
      await pumpEventQueue();

      final t = h.repo.transitions.single;
      expect(t.patch['reportedIncorrectBy'], isNull);
      expect(t.patch['reportedIncorrectAt'], isNull);
      expect(t.appendLog.single.status, kActivityReportDismissed);
      expect(audit.events, contains(AuditEventType.taskReportDismissed));
    });

    test('cancelling answers an open report and clears it', () async {
      final h = _build();
      await h.cubit.load(manager);
      await pumpEventQueue();

      await h.cubit.cancelTask(
        task(status: TaskStatus.pending).copyWith(
          reportedIncorrectBy: 'emp1',
          reportedIncorrectAt: DateTime(2026, 7, 28),
        ),
        reason: TaskCancelReason.wrongTaskGenerated,
      );

      // A closed task must not keep asking for a decision already made.
      final t = h.repo.transitions.single;
      expect(t.patch['reportedIncorrectBy'], isNull);
      expect(t.patch['reportedIncorrectAt'], isNull);
    });
  });

  group('admin terminal correction (§6.4)', () {
    test('returns a cancelled task to pending, clearing the record', () async {
      final audit = _RecordingAudit();
      final h = _build(audit: EventTrackingService(audit));
      await h.cubit.load(admin);
      await pumpEventQueue();

      await h.cubit.correctTerminal(
        task(
          status: TaskStatus.cancelled,
          cancelledAt: DateTime(2026, 7, 28),
          cancelReason: TaskCancelReason.duplicate,
        ),
      );
      await pumpEventQueue();

      final t = h.repo.transitions.single;
      expect(t.expectedFrom, {'missed', 'cancelled'});
      expect(t.patch['status'], 'pending');
      // Every trace of the undone outcome goes, or the task would sit in
      // pending still carrying a cancellation reason.
      for (final key in [
        'missedAt',
        'cancelledAt',
        'cancelledBy',
        'cancelReason',
        'cancelNote',
        'archivedAt',
      ]) {
        expect(t.patch.containsKey(key), isTrue, reason: '$key must be cleared');
        expect(t.patch[key], isNull, reason: '$key must be cleared');
      }
      expect(t.appendLog.single.status, kActivityTerminalCorrected);
      expect(audit.events, contains(AuditEventType.taskTerminalCorrected));
    });

    test('returns a missed task to pending', () async {
      final h = _build();
      await h.cubit.load(admin);
      await pumpEventQueue();

      await h.cubit.correctTerminal(task(status: TaskStatus.missed));

      expect(h.repo.transitions.single.patch['status'], 'pending');
    });

    test('refuses anything that is not missed or cancelled', () async {
      final h = _build();
      await h.cubit.load(admin);
      await pumpEventQueue();
      final states = <TaskState>[];
      final sub = h.cubit.stream.listen(states.add);

      // Approved has its own, longer-standing reopen path (spec §6 lists them
      // as separate permissions); this valve is only for the other two.
      for (final status in [
        TaskStatus.approved,
        TaskStatus.pending,
        TaskStatus.waitingReview,
      ]) {
        await h.cubit.correctTerminal(task(status: status));
      }
      await sub.cancel();

      expect(h.repo.transitions, isEmpty);
      expect(_errorMessages(states), isNotEmpty);
    });
  });

  testWidgets('the status badge reads Cancelled, and is not an error tint', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: StatusBadge.task(TaskStatus.cancelled))),
    );

    expect(find.text('Cancelled'), findsOneWidget);
    // Neither success nor failure (§8) — Missed is the failure signal, and the
    // two must stay visually distinguishable.
    expect(taskStatusColor(TaskStatus.cancelled), isNot(AppColors.error));
    expect(taskStatusColor(TaskStatus.cancelled), isNot(AppColors.success));
    expect(
      taskStatusColor(TaskStatus.cancelled),
      isNot(taskStatusColor(TaskStatus.missed)),
    );
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
      weekStart: DateTime(2026, 7, 26),
      assignments: {
        for (final d in ScheduleDay.values)
          d: {for (final s in ScheduleShift.values) s: uids},
      },
    );

class _Harness {
  _Harness(this.cubit, this.repo, this.notify, this.schedule, this.users);
  final TaskCubit cubit;
  final _RecordingTaskRepository repo;
  final _RecordingNotify notify;
  final _FakeSchedule schedule;
  final _FakeGetUsers users;
  void seed(List<TaskEntity> tasks) => repo.controller.add(tasks);
}

_Harness _build({EventTrackingService? audit}) {
  final repo = _RecordingTaskRepository();
  final notify = _RecordingNotify();
  final schedule = _FakeSchedule();
  final users = _FakeGetUsers();
  final cubit = TaskCubit(
    repository: repo,
    branchRepository: _FakeBranchRepository(),
    scheduleRepository: schedule,
    createTask: CreateTask(repo),
    updateTask: UpdateTask(repo),
    deleteTask: DeleteTask(repo),
    assignTask: AssignTask(repo),
    uploadTaskAttachment: UploadTaskAttachment(repo),
    getUsersByBranch: users,
    notifyTaskEvent: notify,
    eventTracking: audit,
  );
  addTearDown(() async {
    await cubit.close();
    await repo.controller.close();
  });
  return _Harness(cubit, repo, notify, schedule, users);
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
  final updated = <String>[];
  final assigned = <String>[];

  @override
  Future<void> transitionTask({
    required String taskId,
    required Set<String> expectedFrom,
    required Map<String, Object?> patch,
    required List<ActivityEntry> appendLog,
  }) async {
    transitions.add(_TransitionCall(taskId, expectedFrom, patch, appendLog));
  }

  @override
  Future<void> deleteTask(String taskId) async => deleted.add(taskId);

  @override
  Future<void> updateTask(TaskEntity task) async => updated.add(task.id);

  @override
  Future<void> assignTask({
    required String taskId,
    required List<String> employeeIds,
    String? assignedShiftId,
  }) async => assigned.add(taskId);

  @override
  Stream<List<TaskEntity>> watchTasksByBranch(String branchId) =>
      controller.stream;

  @override
  Stream<List<TaskEntity>> watchAllTasks() => controller.stream;

  @override
  Stream<List<TaskEntity>> watchEmployeeTasks(String employeeId) =>
      controller.stream;

  @override
  Stream<List<TaskEntity>> watchShiftTasks({
    required String branchId,
    required ScheduleShift shift,
  }) => const Stream.empty();

  @override
  Future<List<TaskEntity>> getAllTasks() async => const [];
  @override
  Future<List<TaskEntity>> getTasksByBranch(String branchId) async => const [];
  @override
  Future<List<TaskEntity>> getEmployeeTasks(String employeeId) async => const [];
  @override
  Future<TaskEntity?> getTask(String taskId) async => null;
  @override
  Future<TaskEntity> createTask(TaskEntity task) async => task;
  @override
  Future<TaskEntity?> createTaskWithId(TaskEntity task) async => task;
  @override
  Future<TaskAttachment> uploadAttachment({
    required String taskId,
    required dynamic file,
    required dynamic type,
    required String uploadedBy,
    String? uploadedByName,
    int? durationMs,
    dynamic canceller,
    void Function(int, int)? onProgress,
  }) => throw UnimplementedError();
  @override
  Future<List<TaskTemplateEntity>> getTemplates({bool forceRefresh = false}) async =>
      const [];
  @override
  Future<TaskTemplateEntity> createTemplate(TaskTemplateEntity template) async =>
      template;
  @override
  Future<void> deleteTemplate(String templateId) async {}
  @override
  Future<List<RecurringTaskTemplateEntity>> getRecurringTemplates(
    String branchId,
  ) async => const [];
  @override
  Future<RecurringTaskTemplateEntity> createRecurringTemplate(
    RecurringTaskTemplateEntity template,
  ) async => template;
  @override
  Future<void> updateRecurringTemplate(
    RecurringTaskTemplateEntity template,
  ) async {}
  @override
  Future<void> deleteRecurringTemplate(String templateId) async {}
  @override
  Future<List<AutomationRunEntity>> getAutomationRuns(
    String templateId, {
    required String branchId,
    int limit = 20,
    DateTime? before,
  }) async => const [];
  @override
  Future<AutomationRunEntity?> getAutomationRunByCorrelationId(
    String correlationId, {
    required String branchId,
  }) async => null;
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
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class _FakeGetUsers implements GetUsersByBranch {
  List<UserEntity> users = const [];
  @override
  Future<List<UserEntity>> call(String branchId) async => users;
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

/// Records the *invocation* (so an empty recipient list is still observable as
/// "we tried and there was nobody"), while delegating to the real
/// [NotifyTaskEvent] so the actual title/body copy is exercised rather than
/// stubbed — the reason text on a cancel notice is part of the contract.
class _RecordingNotify extends NotifyTaskEvent {
  _RecordingNotify._(this._repo) : super(_repo);
  factory _RecordingNotify() => _RecordingNotify._(_RecordingNotificationRepo());

  final _RecordingNotificationRepo _repo;
  final calls = <({NotificationType type, List<String>? recipients})>[];

  List<NotificationEntity> get sent => _repo.sent;

  @override
  Future<void> call({
    required TaskEntity task,
    required NotificationType type,
    required UserEntity actor,
    List<String>? recipientOverride,
  }) async {
    calls.add((type: type, recipients: recipientOverride));
    await super.call(
      task: task,
      type: type,
      actor: actor,
      recipientOverride: recipientOverride,
    );
  }
}

class _RecordingNotificationRepo implements NotificationRepository {
  final sent = <NotificationEntity>[];
  @override
  Future<void> createMany(List<NotificationEntity> notifications) async =>
      sent.addAll(notifications);
  @override
  dynamic noSuchMethod(Invocation invocation) => Future<void>.value();
}

class _RecordingAudit implements AuditRepository {
  final events = <AuditEventType>[];
  @override
  Future<void> record(AuditLogEntry entry) async => events.add(entry.eventType);
  @override
  dynamic noSuchMethod(Invocation invocation) => Future<void>.value();
}
