import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drop/core/enums/task_status.dart';
import 'package:drop/core/enums/user_role.dart';
import 'package:drop/core/theme/app_theme.dart';
import 'package:drop/core/utils/app_date_formatter.dart';
import 'package:drop/features/auth/domain/entities/user_entity.dart';
import 'package:drop/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:drop/features/auth/presentation/cubit/auth_state.dart';
import 'package:drop/features/branch/domain/entities/branch_entity.dart';
import 'package:drop/features/branch/presentation/cubit/branch_cubit.dart';
import 'package:drop/features/branch/presentation/cubit/branch_state.dart';
import 'package:drop/features/chat/presentation/cubit/chat_list_cubit.dart';
import 'package:drop/features/chat/presentation/cubit/chat_list_state.dart';
import 'package:drop/features/employee/presentation/pages/employee_home_screen.dart';
import 'package:drop/features/schedule/presentation/cubit/shift_swap_cubit.dart';
import 'package:drop/features/schedule/presentation/cubit/shift_swap_state.dart';
import 'package:drop/features/statistics/domain/entities/statistics_entity.dart';
import 'package:drop/features/statistics/presentation/cubit/statistics_cubit.dart';
import 'package:drop/features/statistics/presentation/cubit/statistics_state.dart';
import 'package:drop/features/attendance/domain/attendance_config.dart';
import 'package:drop/features/attendance/presentation/cubit/attendance_cubit.dart';
import 'package:drop/features/attendance/presentation/cubit/attendance_state.dart';
import 'package:drop/features/task/domain/entities/task_entity.dart';
import 'package:drop/features/task/presentation/cubit/task_cubit.dart';
import 'package:drop/features/task/presentation/cubit/task_state.dart';
import 'package:drop/features/sales/domain/entities/sales_month_snapshot.dart';
import 'package:drop/features/sales/presentation/cubit/sales_month_cubit.dart';
import 'package:drop/features/sales/presentation/cubit/sales_month_state.dart';
import 'package:drop/features/task/presentation/pages/task_details_screen.dart';

/// The start gate ([ADR-016]) as the employee experiences it: the Start control
/// stays **visible but inert** until `startsAt`, says when it opens, and comes
/// alive on its own — on both surfaces that can start work, and for rework
/// exactly as for a fresh task (the gate has no exceptions).
///
/// Two testing notes, both learned the hard way here:
///  - the widget compares against the **real** clock, so a test that wants the
///    gate to open must let real time pass ([_crossRealTime]); advancing fake
///    time alone fires the timer but does not move `DateTime.now()`.
///  - `EntranceFade` schedules an uncancelled `Future.delayed`, so every mount
///    must settle before it is torn down or the suite reports a pending timer.
const _employee = UserEntity(
  uid: 'emp1',
  email: 'emp1@drop.test',
  authProvider: 'password',
  role: UserRole.employee,
  branchId: 'branch1',
  displayName: 'Employee One',
);

TaskEntity _task({
  String id = 'task1',
  TaskStatus status = TaskStatus.pending,
  DateTime? startsAt,
  DateTime? deadline,
}) => TaskEntity(
  id: id,
  title: 'Open the cold case',
  status: status,
  branchId: 'branch1',
  assigneeIds: const ['emp1'],
  startsAt: startsAt,
  deadline: deadline,
  createdBy: 'mgr1',
);

String _reason(DateTime startsAt) =>
    'Starts at ${AppDateFormatter.time24(startsAt)}';

/// Lets [d] of **real** wall-clock time elapse, then pumps a frame so the
/// widget's armed one-shot timer fires and it rebuilds against the new `now`.
/// No tap, no remount — that is the point of the assertion.
Future<void> _crossRealTime(WidgetTester tester, Duration d) async {
  await tester.runAsync(() => Future<void>.delayed(d));
  await tester.pump(d);
}

class _FakeAuthCubit extends Cubit<AuthState> implements AuthCubit {
  _FakeAuthCubit() : super(const AuthState.authenticated(_employee));
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeBranchCubit extends Cubit<BranchState> implements BranchCubit {
  _FakeBranchCubit() : super(const BranchState.loaded([]));
  @override
  BranchEntity? branchById(String? id) => null;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeTaskCubit extends Cubit<TaskState> implements TaskCubit {
  _FakeTaskCubit(TaskEntity task) : super(TaskState.loaded([task]));

  final started = <String>[];

  @override
  Map<String, String> get branchNames => const {};

  @override
  Future<void> load(UserEntity user, {bool forceRefresh = false}) async {}

  @override
  Future<void> startTask(TaskEntity task) async {
    started.add(task.id);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeStatisticsCubit extends Cubit<StatisticsState>
    implements StatisticsCubit {
  _FakeStatisticsCubit()
    : super(const StatisticsState.loaded(StatisticsEntity()));
  @override
  Future<void> load(UserEntity user, {bool forceRefresh = false}) async {}
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeShiftSwapCubit extends Cubit<ShiftSwapState>
    implements ShiftSwapCubit {
  _FakeShiftSwapCubit() : super(const ShiftSwapState.loaded([]));
  @override
  Future<void> loadMine(String uid, {bool force = false}) async {}
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Employee Home reads the clock state for its shift card. Loaded with no
/// rostered shift — the card then renders "Off today" and no clock row, which
/// is all these start-gate tests need from it.
///
/// It must be **loaded**, not `initial`: the unloaded card shows a shimmering
/// skeleton, and a repeating animation means `pumpAndSettle` never returns.
class _FakeAttendanceCubit extends Cubit<AttendanceState>
    implements AttendanceCubit {
  _FakeAttendanceCubit()
    : super(
        AttendanceState.loaded(
          config: AttendanceConfig.defaults,
          tick: DateTime.now(),
        ),
      );
  @override
  Future<void> load(UserEntity user, {bool forceRefresh = false}) async {}
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeChatListCubit extends Cubit<ChatListState> implements ChatListCubit {
  _FakeChatListCubit() : super(const ChatListState.loaded([]));
  @override
  Future<void> load({bool forceRefresh = false}) async {}
  @override
  void clearUnread(String conversationId) {}
  @override
  int get totalUnread => 0;
  @override
  Stream<ChatIncomingMessage> get incoming => const Stream.empty();
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Widget _detailsHost(_FakeTaskCubit taskCubit, TaskEntity task) =>
    MultiBlocProvider(
      providers: [
        BlocProvider<AuthCubit>(create: (_) => _FakeAuthCubit()),
        BlocProvider<BranchCubit>(create: (_) => _FakeBranchCubit()),
        BlocProvider<TaskCubit>.value(value: taskCubit),
      ],
      child: MaterialApp(
        theme: AppTheme.dark,
        home: TaskDetailsScreen(task: task),
      ),
    );

class _FakeSalesMonthCubit extends Cubit<SalesMonthState>
    implements SalesMonthCubit {
  _FakeSalesMonthCubit()
    : super(
        const SalesMonthState.loaded(
          snapshot: SalesMonthSnapshot(),
          todayDateKey: '20260815',
        ),
      );
  @override
  Future<void> loadForEmployee({
    required String branchId,
    required String uid,
    DateTime? now,
    bool force = false,
  }) async {}
  @override
  Future<void> loadForBranch({
    required String branchId,
    DateTime? now,
    bool force = false,
  }) async {}
  @override
  Future<void> submitToday({
    required int amountPiastres,
    required UserEntity user,
  }) async {}
  @override
  Future<void> resubmitCorrection({
    required String submissionId,
    required int amountPiastres,
  }) async {}
}

Widget _homeHost(_FakeTaskCubit taskCubit) => MultiBlocProvider(
  providers: [
    BlocProvider<AuthCubit>(create: (_) => _FakeAuthCubit()),
    BlocProvider<StatisticsCubit>(create: (_) => _FakeStatisticsCubit()),
    BlocProvider<TaskCubit>.value(value: taskCubit),
    BlocProvider<ShiftSwapCubit>(create: (_) => _FakeShiftSwapCubit()),
    BlocProvider<AttendanceCubit>(create: (_) => _FakeAttendanceCubit()),
    BlocProvider<ChatListCubit>(create: (_) => _FakeChatListCubit()),
    BlocProvider<SalesMonthCubit>(create: (_) => _FakeSalesMonthCubit()),
  ],
  child: MaterialApp(theme: AppTheme.dark, home: const EmployeeHomeScreen()),
);

void main() {
  testWidgets('Task Details keeps Start Task visible but inert before startsAt', (
    tester,
  ) async {
    final startsAt = DateTime.now().add(const Duration(hours: 1));
    final task = _task(startsAt: startsAt);
    final taskCubit = _FakeTaskCubit(task);
    addTearDown(taskCubit.close);

    await tester.pumpWidget(_detailsHost(taskCubit, task));
    await tester.pumpAndSettle();

    // Visible, named, and explained — never hidden. The title now renders
    // twice on Task Details: the app-bar label and, since 2026-08-03, the
    // body headline — the page used to open on a status pill and a wall of
    // metadata chips without ever saying what the task was.
    expect(find.text('Open the cold case'), findsNWidgets(2));
    expect(find.text('Start Task'), findsOneWidget);
    expect(find.text(_reason(startsAt)), findsOneWidget);
    // An upcoming task is not a failing one.
    expect(find.text('Overdue'), findsNothing);
    expect(find.text('Missed'), findsNothing);

    await tester.tap(find.text('Start Task'));
    await tester.pump();
    expect(taskCubit.started, isEmpty);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });

  testWidgets('Task Details applies the same gate to Start Rework', (
    tester,
  ) async {
    final startsAt = DateTime.now().add(const Duration(hours: 1));
    final task = _task(status: TaskStatus.rejected, startsAt: startsAt);
    final taskCubit = _FakeTaskCubit(task);
    addTearDown(taskCubit.close);

    await tester.pumpWidget(_detailsHost(taskCubit, task));
    await tester.pumpAndSettle();

    expect(find.text('Start Rework'), findsOneWidget);
    expect(find.text(_reason(startsAt)), findsOneWidget);

    await tester.tap(find.text('Start Rework'));
    await tester.pump();
    expect(taskCubit.started, isEmpty);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });

  testWidgets('Task Details enables Start Task on its own at startsAt', (
    tester,
  ) async {
    final startsAt = DateTime.now().add(const Duration(milliseconds: 250));
    final task = _task(startsAt: startsAt);
    final taskCubit = _FakeTaskCubit(task);
    addTearDown(taskCubit.close);

    await tester.pumpWidget(_detailsHost(taskCubit, task));
    await tester.pump();
    expect(find.text(_reason(startsAt)), findsOneWidget);

    // No interaction and no rebuild request — only the clock moving.
    await _crossRealTime(tester, const Duration(milliseconds: 400));

    expect(find.text(_reason(startsAt)), findsNothing);
    await tester.tap(find.text('Start Task'));
    await tester.pump();
    expect(taskCubit.started, ['task1']);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });

  testWidgets('Employee Home shows an upcoming task with the muted footer', (
    tester,
  ) async {
    final startsAt = DateTime.now().add(const Duration(hours: 1));
    final task = _task(
      startsAt: startsAt,
      deadline: startsAt.add(const Duration(hours: 2)),
    );
    final taskCubit = _FakeTaskCubit(task);
    addTearDown(taskCubit.close);

    await tester.pumpWidget(_homeHost(taskCubit));
    await tester.pumpAndSettle();

    // Present in the list, with the reason in place of the CTA.
    expect(find.text('Open the cold case'), findsOneWidget);
    expect(find.text(_reason(startsAt)), findsOneWidget);
    expect(find.text('Start task'), findsNothing);
    // Upcoming is not one of the closed/failed readings.
    expect(find.text('Missed — task closed'), findsNothing);
    expect(find.text('Overdue'), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });

  testWidgets('Employee Home keeps Start task live once startsAt has passed', (
    tester,
  ) async {
    final startsAt = DateTime.now().subtract(const Duration(seconds: 1));
    final task = _task(startsAt: startsAt);
    final taskCubit = _FakeTaskCubit(task);
    addTearDown(taskCubit.close);

    await tester.pumpWidget(_homeHost(taskCubit));
    await tester.pumpAndSettle();

    expect(find.text('Start task'), findsOneWidget);
    expect(find.text(_reason(startsAt)), findsNothing);

    await tester.tap(find.text('Start task'));
    await tester.pump();
    expect(taskCubit.started, ['task1']);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });
}
