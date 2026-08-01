import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:drop/core/enums/schedule_day.dart';
import 'package:drop/core/enums/schedule_shift.dart';
import 'package:drop/core/enums/task_status.dart';
import 'package:drop/core/enums/user_role.dart';
import 'package:drop/features/auth/domain/entities/user_entity.dart';
import 'package:drop/features/auth/domain/repositories/auth_repository.dart';
import 'package:drop/features/auth/domain/usecases/get_users_by_branch.dart';
import 'package:drop/features/branch/domain/repositories/branch_repository.dart';
import 'package:drop/features/notifications/domain/repositories/notification_repository.dart';
import 'package:drop/features/notifications/domain/usecases/notify_task_event.dart';
import 'package:drop/features/schedule/domain/entities/weekly_schedule_entity.dart';
import 'package:drop/features/schedule/domain/repositories/schedule_repository.dart';
import 'package:drop/features/task/domain/entities/task_entity.dart';
import 'package:drop/features/task/domain/repositories/task_repository.dart';
import 'package:drop/features/task/domain/usecases/assign_task.dart';
import 'package:drop/features/task/domain/usecases/create_task.dart';
import 'package:drop/features/task/domain/usecases/delete_task.dart';
import 'package:drop/features/task/domain/usecases/update_task.dart';
import 'package:drop/features/task/domain/usecases/upload_task_attachment.dart';
import 'package:drop/features/task/presentation/cubit/task_cubit.dart';

/// **How an employee's shift task streams get bound.**
///
/// A shift task carries no `assigneeIds`, so it reaches the employee only
/// through `watchShiftTasks` — and that stream cannot be opened until we know
/// which shift they are on today. Resolving the roster used to be an awaited
/// server read, so shift tasks (and the Late/Missed counts that include them)
/// landed about a second after the rest of the screen.
///
/// The roster is now read cache-first and reconciled against the server in the
/// background. These tests pin both halves of that bargain: the streams bind
/// without waiting for the network, **and** a roster that turns out to differ
/// still corrects itself — otherwise a cached roster would strand an employee
/// on the wrong shift's tasks for the whole session.
void main() {
  final employee = UserEntity(
    uid: 'emp1',
    email: 'e@x.com',
    authProvider: 'password',
    role: UserRole.employee,
    branchId: 'branch1',
    displayName: 'Employee',
  );

  WeeklyScheduleEntity rosterOn(List<ScheduleShift> shifts) =>
      WeeklyScheduleEntity(
        id: 'sched1',
        branchId: 'branch1',
        weekStart: DateTime(2026, 1, 4),
        assignments: {
          for (final d in ScheduleDay.values)
            d: {for (final s in shifts) s: const ['emp1']},
        },
      );

  TaskEntity shiftTask(String id) => TaskEntity(
    id: id,
    title: id,
    status: TaskStatus.pending,
    branchId: 'branch1',
  );

  ({TaskCubit cubit, _Repo repo, _Schedule schedule}) build(
    _Schedule schedule,
  ) {
    final repo = _Repo();
    final cubit = TaskCubit(
      repository: repo,
      branchRepository: _Branch(),
      scheduleRepository: schedule,
      createTask: CreateTask(repo),
      updateTask: UpdateTask(repo),
      deleteTask: DeleteTask(repo),
      assignTask: AssignTask(repo),
      uploadTaskAttachment: UploadTaskAttachment(repo),
      getUsersByBranch: GetUsersByBranch(_Auth()),
      notifyTaskEvent: NotifyTaskEvent(_Notifications()),
    );
    addTearDown(cubit.close);
    return (cubit: cubit, repo: repo, schedule: schedule);
  }

  test('shift streams bind from cache without waiting on the server', () async {
    // The server read never completes for the whole test — if binding still
    // waited on it, no shift stream would ever open.
    final schedule = _Schedule(
      cached: rosterOn([ScheduleShift.morning]),
      server: Completer<WeeklyScheduleEntity?>().future,
    );
    final h = build(schedule);

    await h.cubit.load(employee);
    await pumpEventQueue();

    expect(h.repo.subscribedShifts, [ScheduleShift.morning]);
    expect(schedule.cacheFirstCalls, 1);
  });

  test('a task from the cached shift reaches the list', () async {
    final schedule = _Schedule(
      cached: rosterOn([ScheduleShift.morning]),
      server: Completer<WeeklyScheduleEntity?>().future,
    );
    final h = build(schedule);
    await h.cubit.load(employee);
    await pumpEventQueue();

    h.repo.emitShift(ScheduleShift.morning, [shiftTask('open-shift')]);
    await pumpEventQueue();

    expect(
      h.cubit.state.maybeWhen(
        loaded: (tasks, _, _, _, _) => tasks.map((t) => t.id).toList(),
        orElse: () => const <String>[],
      ),
      ['open-shift'],
    );
  });

  test('an unchanged server roster causes no re-subscribe', () async {
    final roster = rosterOn([ScheduleShift.morning]);
    final schedule = _Schedule(cached: roster, server: Future.value(roster));
    final h = build(schedule);

    await h.cubit.load(employee);
    await pumpEventQueue();

    // Bound once from cache; the reconcile agreed and left the stream alone.
    expect(schedule.serverCalls, 1);
    expect(h.repo.shiftSubscribeCount, 1);
    expect(h.repo.subscribedShifts, [ScheduleShift.morning]);
  });

  test('a changed server roster re-binds onto the right shift', () async {
    // The cache says morning; the manager has since moved them to night.
    final schedule = _Schedule(
      cached: rosterOn([ScheduleShift.morning]),
      server: Future.value(rosterOn([ScheduleShift.night])),
    );
    final h = build(schedule);

    await h.cubit.load(employee);
    await pumpEventQueue();

    expect(h.repo.subscribedShifts, [ScheduleShift.night]);
    expect(h.repo.cancelledShifts, [ScheduleShift.morning]);
  });

  test('tasks from a stale shift are dropped when the roster corrects', () async {
    final schedule = _Schedule(
      cached: rosterOn([ScheduleShift.morning]),
      server: Future.value(rosterOn([ScheduleShift.night])),
    );
    final h = build(schedule);
    await h.cubit.load(employee);
    await pumpEventQueue();

    // Whatever the morning stream had delivered must not survive the re-bind —
    // otherwise the employee keeps seeing another shift's work.
    h.repo.emitShift(ScheduleShift.night, [shiftTask('night-task')]);
    await pumpEventQueue();

    expect(
      h.cubit.state.maybeWhen(
        loaded: (tasks, _, _, _, _) => tasks.map((t) => t.id).toList(),
        orElse: () => const <String>[],
      ),
      ['night-task'],
    );
  });

  test('an employee with no branch subscribes to no shift stream', () async {
    final schedule = _Schedule(
      cached: rosterOn([ScheduleShift.morning]),
      server: Future.value(rosterOn([ScheduleShift.morning])),
    );
    final h = build(schedule);

    await h.cubit.load(
      UserEntity(
        uid: 'emp2',
        email: 'e2@x.com',
        authProvider: 'password',
        role: UserRole.employee,
        displayName: 'No Branch',
      ),
    );
    await pumpEventQueue();

    expect(h.repo.subscribedShifts, isEmpty);
    expect(schedule.cacheFirstCalls, 0);
  });

  test('a roster read that throws leaves the employee stream intact', () async {
    final schedule = _Schedule.failing();
    final h = build(schedule);

    await h.cubit.load(employee);
    await pumpEventQueue();

    // Best-effort: no shift streams, but the assignee stream still loaded.
    expect(h.repo.subscribedShifts, isEmpty);
    h.repo.emitAssignee([shiftTask('mine')]);
    await pumpEventQueue();
    expect(
      h.cubit.state.maybeWhen(
        loaded: (tasks, _, _, _, _) => tasks.length,
        orElse: () => -1,
      ),
      1,
    );
  });
}

/// Serves a different roster to the cache-first and server reads so the two
/// paths can be told apart, and counts each.
class _Schedule implements ScheduleRepository {
  _Schedule({required this.cached, required this.server, this.throws = false});

  factory _Schedule.failing() =>
      _Schedule(cached: null, server: Future.value(null), throws: true);

  final WeeklyScheduleEntity? cached;
  final Future<WeeklyScheduleEntity?> server;
  final bool throws;

  int cacheFirstCalls = 0;
  int serverCalls = 0;

  @override
  Future<WeeklyScheduleEntity?> getScheduleCacheFirst(
    String branchId,
    DateTime weekStart,
  ) async {
    cacheFirstCalls++;
    if (throws) throw StateError('cache read failed');
    return cached;
  }

  @override
  Future<WeeklyScheduleEntity?> getSchedule(
    String branchId,
    DateTime weekStart,
  ) {
    serverCalls++;
    if (throws) return Future.error(StateError('server read failed'));
    return server;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} not stubbed');
}

/// Hands out a distinct controller per shift so the test can see exactly which
/// shift sources are live, and which were torn down.
class _Repo implements TaskRepository {
  final _assignee = StreamController<List<TaskEntity>>.broadcast();
  final Map<ScheduleShift, StreamController<List<TaskEntity>>> _shifts = {};

  final List<ScheduleShift> subscribedShifts = [];
  final List<ScheduleShift> cancelledShifts = [];
  int shiftSubscribeCount = 0;

  void emitAssignee(List<TaskEntity> tasks) => _assignee.add(tasks);
  void emitShift(ScheduleShift shift, List<TaskEntity> tasks) =>
      _shifts[shift]?.add(tasks);

  @override
  Stream<List<TaskEntity>> watchEmployeeTasks(String employeeId) =>
      _assignee.stream;

  /// A fresh controller per call, registered on listen and de-registered on
  /// cancel — so [subscribedShifts] is exactly the set of *live* shift sources
  /// at any moment, and [cancelledShifts] records what was torn down.
  @override
  Stream<List<TaskEntity>> watchShiftTasks({
    required String branchId,
    required ScheduleShift shift,
  }) {
    late final StreamController<List<TaskEntity>> controller;
    controller = StreamController<List<TaskEntity>>(
      onListen: () {
        shiftSubscribeCount++;
        subscribedShifts.add(shift);
        _shifts[shift] = controller;
      },
      onCancel: () {
        cancelledShifts.add(shift);
        subscribedShifts.remove(shift);
        if (identical(_shifts[shift], controller)) _shifts.remove(shift);
      },
    );
    return controller.stream;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} not stubbed');
}

class _Branch implements BranchRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} not stubbed');
}

class _Auth implements AuthRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} not stubbed');
}

class _Notifications implements NotificationRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} not stubbed');
}
