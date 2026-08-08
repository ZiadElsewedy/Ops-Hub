import 'dart:async';

import 'package:drop/core/enums/notification_type.dart';
import 'package:drop/core/enums/schedule_shift.dart';
import 'package:drop/core/enums/task_status.dart';
import 'package:drop/core/enums/user_role.dart';
import 'package:drop/features/auth/domain/entities/user_entity.dart';
import 'package:drop/features/auth/domain/repositories/auth_repository.dart';
import 'package:drop/features/branch/domain/entities/branch_entity.dart';
import 'package:drop/features/branch/domain/repositories/branch_repository.dart';
import 'package:drop/features/notifications/domain/entities/notification_entity.dart';
import 'package:drop/features/notifications/domain/repositories/notification_repository.dart';
import 'package:drop/features/notifications/domain/usecases/notify_task_event.dart';
import 'package:drop/features/task/domain/entities/activity_entry.dart';
import 'package:drop/features/task/domain/entities/task_entity.dart';
import 'package:drop/features/task/domain/repositories/task_repository.dart';
import 'package:drop/features/task/domain/usecases/assign_task.dart';
import 'package:drop/features/task/domain/usecases/create_task.dart';
import 'package:drop/features/task/domain/usecases/delete_task.dart';
import 'package:drop/features/auth/domain/usecases/get_users_by_branch.dart';
import 'package:drop/features/schedule/domain/repositories/schedule_repository.dart';
import 'package:drop/features/task/domain/usecases/resolve_task_reviewers.dart';
import 'package:drop/features/task/domain/usecases/update_task.dart';
import 'package:drop/features/task/domain/usecases/upload_task_attachment.dart';
import 'package:drop/features/task/presentation/cubit/task_cubit.dart';
import 'package:flutter_test/flutter_test.dart';

/// The **wired** reviewer ladder: `TaskCubit.submitForReview` must hand
/// `NotifyTaskEvent` the resolved recipients rather than letting it fall back to
/// `[task.createdBy]`.
///
/// `task_review_routing_test.dart` pins the rule itself; this pins that the
/// cubit actually consults it, which is the half a pure test cannot see.
void main() {
  const employee = UserEntity(
    uid: 'emp1',
    email: 'sara@drop.test',
    displayName: 'Sara',
    authProvider: 'password',
    role: UserRole.employee,
    branchId: 'branchA',
  );

  UserEntity user(
    String uid, {
    UserRole role = UserRole.manager,
    String? branchId = 'branchA',
    bool isActive = true,
  }) =>
      UserEntity(
        uid: uid,
        email: '$uid@drop.test',
        authProvider: 'password',
        role: role,
        branchId: branchId,
        isActive: isActive,
      );

  TaskEntity task({String? createdBy = 'mgrA'}) => TaskEntity(
        id: 't1',
        title: 'Restock the cold case',
        status: TaskStatus.started,
        branchId: 'branchA',
        assigneeIds: const ['emp1'],
        createdBy: createdBy,
      );

  Future<List<String>?> recipientsFor(
    _FakeAuthRepository auth, {
    String? createdBy = 'mgrA',
  }) async {
    final h = _build(auth);
    await h.cubit.load(employee);
    await pumpEventQueue();
    await h.cubit.submitForReview(task(createdBy: createdBy));
    await pumpEventQueue();

    final submitted = h.notify.calls
        .where((c) => c.type == NotificationType.taskSubmitted)
        .toList();
    expect(submitted, hasLength(1));
    return submitted.single.recipients;
  }

  test('a live manager creator is still the only recipient', () async {
    final recipients = await recipientsFor(_FakeAuthRepository(
      byBranch: {
        'branchA': [user('mgrA'), user('mgrA2'), employee],
      },
    ));
    expect(recipients, ['mgrA']);
  });

  test('a live ADMIN creator is resolved via the targeted read', () async {
    // Admins are branchless, so they never appear in the branch directory —
    // this is the path that needs the individual lookup, and the one the
    // `sendNotification` reachability fix unblocked.
    final recipients = await recipientsFor(_FakeAuthRepository(
      byBranch: {
        'branchA': [user('mgrA2'), employee],
      },
      users: {
        'admin1': user('admin1', role: UserRole.admin, branchId: null),
      },
    ), createdBy: 'admin1');
    expect(recipients, ['admin1']);
  });

  test('a DEACTIVATED ADMIN creator falls through to the branch managers',
      () async {
    final recipients = await recipientsFor(_FakeAuthRepository(
      byBranch: {
        'branchA': [user('mgrA2'), employee],
      },
      users: {
        'admin1': user('admin1',
            role: UserRole.admin, branchId: null, isActive: false),
      },
    ), createdBy: 'admin1');
    expect(recipients, ['mgrA2']);
  });

  test('a DEACTIVATED creator routes to the branch managers instead', () async {
    // Before the ladder this notified `mgrA` — an account that cannot sign in —
    // and the task sat in review with nobody told.
    final recipients = await recipientsFor(_FakeAuthRepository(
      byBranch: {
        'branchA': [user('mgrA', isActive: false), user('mgrA2'), employee],
      },
    ));
    expect(recipients, ['mgrA2']);
  });

  test('a DELETED creator routes to the branch managers instead', () async {
    final recipients = await recipientsFor(_FakeAuthRepository(
      byBranch: {
        'branchA': [user('mgrA2'), employee],
      },
      // `mgrA` resolves to nothing at all.
    ));
    expect(recipients, ['mgrA2']);
  });

  test('a branch with no live manager escalates to admins', () async {
    final recipients = await recipientsFor(_FakeAuthRepository(
      byBranch: {
        'branchA': [employee],
      },
      all: [user('admin1', role: UserRole.admin, branchId: null)],
    ));
    expect(recipients, ['admin1']);
  });

  test('nobody at all is an EMPTY override, not a fallback to the assignees',
      () async {
    // The distinction that matters: `NotifyTaskEvent` reads a non-null empty
    // list as "we looked and there is nobody". A null would fall back to
    // `[createdBy]`, and an assignee fallback would tell the person who just
    // submitted the work that it had been submitted.
    final h = _build(_FakeAuthRepository(byBranch: {'branchA': []}));
    await h.cubit.load(employee);
    await pumpEventQueue();
    await h.cubit.submitForReview(task());
    await pumpEventQueue();

    final call = h.notify.calls
        .singleWhere((c) => c.type == NotificationType.taskSubmitted);
    expect(call.recipients, isNotNull);
    expect(call.recipients, isEmpty);
    // Nothing was sent — and crucially not to `emp1`, who submitted it.
    expect(h.notify.sent, isEmpty);
  });

  test('without the resolver wired it degrades to the old [createdBy]',
      () async {
    // The optional dependency's documented degradation, so a test harness that
    // omits it behaves exactly as the app did before the ladder existed.
    final h = _build(_FakeAuthRepository(byBranch: const {}), resolver: false);
    await h.cubit.load(employee);
    await pumpEventQueue();
    await h.cubit.submitForReview(task());
    await pumpEventQueue();

    final call = h.notify.calls
        .singleWhere((c) => c.type == NotificationType.taskSubmitted);
    expect(call.recipients, isNull);
    expect(h.notify.sent.single.recipientUid, 'mgrA');
  });
}

// ─── Harness ───────────────────────────────────────────────────────────

class _Harness {
  _Harness(this.cubit, this.repo, this.notify);
  final TaskCubit cubit;
  final _FakeTaskRepository repo;
  final _RecordingNotify notify;
}

_Harness _build(_FakeAuthRepository auth, {bool resolver = true}) {
  final repo = _FakeTaskRepository();
  final notify = _RecordingNotify();
  final cubit = TaskCubit(
    repository: repo,
    branchRepository: _FakeBranchRepository(),
    scheduleRepository: _FakeScheduleRepository(),
    createTask: CreateTask(repo),
    updateTask: UpdateTask(repo),
    deleteTask: DeleteTask(repo),
    assignTask: AssignTask(repo),
    uploadTaskAttachment: UploadTaskAttachment(repo),
    getUsersByBranch: GetUsersByBranch(auth),
    notifyTaskEvent: notify,
    resolveTaskReviewers: resolver ? ResolveTaskReviewers(auth) : null,
  );
  addTearDown(() async {
    await cubit.close();
    await repo.controller.close();
  });
  return _Harness(cubit, repo, notify);
}

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

class _FakeTaskRepository implements TaskRepository {
  final controller = StreamController<List<TaskEntity>>.broadcast();

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
  }) =>
      const Stream.empty();

  @override
  Future<void> transitionTask({
    required String taskId,
    required Set<String> expectedFrom,
    required Map<String, Object?> patch,
    required List<ActivityEntry> appendLog,
  }) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => Future<void>.value();
}

class _FakeBranchRepository implements BranchRepository {
  @override
  Future<List<BranchEntity>> getBranches({
    bool includeDeleted = false,
    bool forceRefresh = false,
  }) async =>
      const [];

  @override
  dynamic noSuchMethod(Invocation invocation) => Future<void>.value();
}

class _FakeScheduleRepository implements ScheduleRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => Future<void>.value();
}

class _FakeAuthRepository implements AuthRepository {
  _FakeAuthRepository({
    this.byBranch = const {},
    this.users = const {},
    this.all = const [],
  });

  final Map<String, List<UserEntity>> byBranch;
  final Map<String, UserEntity> users;
  final List<UserEntity> all;

  @override
  Future<List<UserEntity>> getUsersByBranch(String branchId) async =>
      byBranch[branchId] ?? const [];

  @override
  Future<UserEntity?> getUser(String uid) async => users[uid];

  @override
  Future<List<UserEntity>> getAllUsers() async => all;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
