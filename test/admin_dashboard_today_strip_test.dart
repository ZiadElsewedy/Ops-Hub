import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opshub/core/enums/task_status.dart';
import 'package:opshub/core/enums/user_role.dart';
import 'package:opshub/core/theme/app_theme.dart';
import 'package:opshub/features/admin/presentation/pages/admin_dashboard_screen.dart';
import 'package:opshub/features/auth/domain/entities/user_entity.dart';
import 'package:opshub/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:opshub/features/auth/presentation/cubit/auth_state.dart';
import 'package:opshub/features/cases/presentation/cubit/case_list_cubit.dart';
import 'package:opshub/features/cases/presentation/cubit/case_list_state.dart';
import 'package:opshub/features/requests/presentation/cubit/requests_list_cubit.dart';
import 'package:opshub/features/requests/presentation/cubit/requests_list_state.dart';
import 'package:opshub/features/schedule/presentation/cubit/shift_swap_cubit.dart';
import 'package:opshub/features/schedule/presentation/cubit/shift_swap_state.dart';
import 'package:opshub/features/statistics/domain/entities/statistics_entity.dart';
import 'package:opshub/features/statistics/presentation/cubit/statistics_cubit.dart';
import 'package:opshub/features/statistics/presentation/cubit/statistics_state.dart';
import 'package:opshub/features/branch/presentation/cubit/branch_cubit.dart';
import 'package:opshub/features/branch/presentation/cubit/branch_state.dart';
import 'package:opshub/features/task/domain/entities/task_entity.dart';
import 'package:opshub/features/task/presentation/cubit/task_cubit.dart';
import 'package:opshub/features/task/presentation/cubit/task_state.dart';
import 'package:opshub/features/task/presentation/pages/filtered_tasks_screen.dart';

/// The Today metric doors: every figure derives from the same task
/// stream `applyFeed` reads, so a tap's count and its drill-down list agree by
/// construction. This locks the case that motivated the whole change — an
/// `Open` stat that actually counts a pending (not-yet-started) task, and a
/// tap that lists exactly that task and nothing already closed.
const _admin = UserEntity(
  uid: 'admin1',
  email: 'admin@drop.test',
  authProvider: 'password',
  role: UserRole.admin,
  displayName: 'Admin One',
);

class _FakeAuthCubit extends Cubit<AuthState> implements AuthCubit {
  _FakeAuthCubit() : super(const AuthState.authenticated(_admin));
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

class _FakeTaskCubit extends Cubit<TaskState> implements TaskCubit {
  _FakeTaskCubit(List<TaskEntity> tasks) : super(TaskState.loaded(tasks));
  @override
  Map<String, String> get branchNames => const {};
  @override
  Future<void> load(UserEntity user, {bool forceRefresh = false}) async {}
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeShiftSwapCubit extends Cubit<ShiftSwapState>
    implements ShiftSwapCubit {
  _FakeShiftSwapCubit() : super(const ShiftSwapState.loaded([]));
  @override
  Future<void> loadAll({bool force = false}) async {}
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeRequestsListCubit extends Cubit<RequestsListState>
    implements RequestsListCubit {
  _FakeRequestsListCubit() : super(const RequestsListState.loaded([]));
  @override
  Future<void> load(UserEntity user, {bool forceRefresh = false}) async {}
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeCaseListCubit extends Cubit<CaseListState> implements CaseListCubit {
  _FakeCaseListCubit() : super(const CaseListState.loaded([]));
  @override
  Future<void> load(UserEntity user, {bool forceRefresh = false}) async {}
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// No branch opts in to sales targets here, so the Branch sales module on Admin
/// Home renders nothing — and, deliberately, never builds its own cubit. That is
/// what keeps this host free of the sales dependency graph.
class _FakeBranchCubit extends Cubit<BranchState> implements BranchCubit {
  _FakeBranchCubit() : super(const BranchState.loaded([]));
  @override
  Future<void> loadIfNeeded() async {}
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Widget _host(_FakeTaskCubit taskCubit) => MultiBlocProvider(
  providers: [
    BlocProvider<BranchCubit>(create: (_) => _FakeBranchCubit()),
    BlocProvider<AuthCubit>(create: (_) => _FakeAuthCubit()),
    BlocProvider<StatisticsCubit>(create: (_) => _FakeStatisticsCubit()),
    BlocProvider<TaskCubit>.value(value: taskCubit),
    BlocProvider<ShiftSwapCubit>(create: (_) => _FakeShiftSwapCubit()),
    BlocProvider<RequestsListCubit>(create: (_) => _FakeRequestsListCubit()),
    BlocProvider<CaseListCubit>(create: (_) => _FakeCaseListCubit()),
  ],
  // AdminDashboardScreen is a ShellRoute child and builds no Scaffold of its
  // own — the app shell is what puts a Material ancestor above it in the real
  // tree, and without one the screen's (pre-existing) InkWell rows assert.
  child: MaterialApp(
    theme: AppTheme.dark,
    home: const Scaffold(body: AdminDashboardScreen()),
  ),
);

void main() {
  testWidgets(
    'tapping the Open stat pushes FilteredTasksScreen listing exactly the open task',
    (tester) async {
      // Force the mobile layout (single-column, no desktop right rail).
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final open = TaskEntity(
        id: 't-open',
        title: 'Open the shop',
        status: TaskStatus.pending,
      );
      final closed = TaskEntity(
        id: 't-approved',
        title: 'Closed already',
        status: TaskStatus.approved,
        approvedAt: DateTime.now(),
      );
      final taskCubit = _FakeTaskCubit([open, closed]);
      addTearDown(taskCubit.close);

      await tester.pumpWidget(_host(taskCubit));
      await tester.pump(); // postFrameCallback → _load()
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('Open'), findsOneWidget);

      await tester.tap(find.text('Open'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      final pushed = find.byType(FilteredTasksScreen);
      expect(pushed, findsOneWidget);
      // Scoped to the pushed screen — the dashboard underneath stays mounted
      // (Recent activity may show the same tasks), so a bare `find.text`
      // could match twice.
      expect(
        find.descendant(of: pushed, matching: find.text('Open the shop')),
        findsOneWidget,
      );
      // Not the already-approved task — count and list agree by construction.
      expect(
        find.descendant(of: pushed, matching: find.text('Closed already')),
        findsNothing,
      );

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 400));
    },
  );

  testWidgets(
    'tapping Done today lists only work approved today, not the lifetime total',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final approvedToday = TaskEntity(
        id: 't-today',
        title: 'Restocked shelves',
        status: TaskStatus.approved,
        approvedAt: DateTime.now(),
      );
      final approvedLastMonth = TaskEntity(
        id: 't-old',
        title: 'Old closed task',
        status: TaskStatus.approved,
        approvedAt: DateTime.now().subtract(const Duration(days: 30)),
      );
      final taskCubit = _FakeTaskCubit([approvedToday, approvedLastMonth]);
      addTearDown(taskCubit.close);

      await tester.pumpWidget(_host(taskCubit));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      // The tile sits below the hero + Needs-attention panel, whose height
      // varies with copy — scroll the cell into view so this test asserts the
      // count↔list agreement, not a pixel position.
      await tester.ensureVisible(find.text('Done today'));
      await tester.pump();
      await tester.tap(find.text('Done today'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      final pushed = find.byType(FilteredTasksScreen);
      expect(pushed, findsOneWidget);
      expect(
        find.descendant(of: pushed, matching: find.text('Restocked shelves')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: pushed, matching: find.text('Old closed task')),
        findsNothing,
      );

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 400));
    },
  );

  testWidgets('the Due today tile opens its matching filtered list', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final dueToday = TaskEntity(
      id: 't-due-today',
      title: 'Count the till',
      status: TaskStatus.pending,
      deadline: DateTime.now(),
    );
    final taskCubit = _FakeTaskCubit([dueToday]);
    addTearDown(taskCubit.close);

    await tester.pumpWidget(_host(taskCubit));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Due today'), findsOneWidget);
    await tester.ensureVisible(find.text('Due today'));
    await tester.tap(find.text('Due today'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byType(FilteredTasksScreen), findsOneWidget);
    expect(find.text('Count the till'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 400));
  });

  testWidgets('Admin Home is the phone\'s only door to attendance', (
    tester,
  ) async {
    // Phone WIDTH (so this is the mobile layout, where the row matters) but a
    // tall viewport, so the whole page builds. Operations sits near the foot of
    // a ListView, which doesn't build children that far off-screen — and
    // scrolling there with a fling leaves a ballistic simulation pending that
    // the test can't drain.
    tester.view.physicalSize = const Size(390, 2600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final taskCubit = _FakeTaskCubit(const []);
    addTearDown(taskCubit.close);

    await tester.pumpWidget(_host(taskCubit));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    // `/attendance/reports` is the root of the whole attendance module (the
    // workspace, the review ledger, the weekly/monthly reports all hang off
    // it). For an admin it is otherwise reachable ONLY from the desktop
    // sidebar, and the phone's bottom nav is Home · Tasks · Schedule · Chat —
    // so deleting this row silently strands the entire module on mobile.
    expect(find.text('Attendance & reports'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 400));
  });
}
