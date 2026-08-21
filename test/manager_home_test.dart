import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opshub/core/enums/task_status.dart';
import 'package:opshub/core/enums/user_role.dart';
import 'package:opshub/core/theme/app_theme.dart';
import 'package:opshub/core/widgets/attention_panel.dart';
import 'package:opshub/core/widgets/digest_panel.dart';
import 'package:opshub/core/widgets/metric_tile.dart';
import 'package:opshub/features/auth/domain/entities/user_entity.dart';
import 'package:opshub/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:opshub/features/auth/presentation/cubit/auth_state.dart';
import 'package:opshub/features/branch/domain/entities/branch_entity.dart';
import 'package:opshub/features/branch/presentation/cubit/branch_cubit.dart';
import 'package:opshub/features/branch/presentation/cubit/branch_state.dart';
import 'package:opshub/features/cases/presentation/cubit/case_list_cubit.dart';
import 'package:opshub/features/cases/presentation/cubit/case_list_state.dart';
import 'package:opshub/features/chat/presentation/cubit/chat_list_cubit.dart';
import 'package:opshub/features/chat/presentation/cubit/chat_list_state.dart';
import 'package:opshub/features/manager/presentation/pages/manager_home_screen.dart';
import 'package:opshub/features/requests/presentation/cubit/requests_list_cubit.dart';
import 'package:opshub/features/requests/presentation/cubit/requests_list_state.dart';
import 'package:opshub/features/sales/domain/entities/branch_sales_month_entity.dart';
import 'package:opshub/features/sales/domain/entities/sales_month_snapshot.dart';
import 'package:opshub/features/sales/presentation/cubit/sales_month_cubit.dart';
import 'package:opshub/features/sales/presentation/cubit/sales_month_state.dart';
import 'package:opshub/features/sales/presentation/widgets/sales_target_card.dart';
import 'package:opshub/features/schedule/presentation/cubit/shift_swap_cubit.dart';
import 'package:opshub/features/schedule/presentation/cubit/shift_swap_state.dart';
import 'package:opshub/features/statistics/domain/entities/statistics_entity.dart';
import 'package:opshub/features/statistics/presentation/cubit/statistics_cubit.dart';
import 'package:opshub/features/statistics/presentation/cubit/statistics_state.dart';
import 'package:opshub/features/task/domain/entities/task_entity.dart';
import 'package:opshub/features/task/presentation/cubit/task_cubit.dart';
import 'package:opshub/features/task/presentation/cubit/task_state.dart';
import 'package:opshub/features/task/presentation/pages/filtered_tasks_screen.dart';

/// Manager Home — the branch command center (rebuilt 2026-08-03).
///
/// The screen it replaced was a flat wall of ten equal-weight stat cards where
/// nothing was ranked and the hero's `Active tasks` disagreed with the feed
/// strip beneath it. These tests lock what the rebuild is actually *for*:
///
/// * the ranked ladder renders on **both** tiers (mobile stack, desktop rail);
/// * `Needs attention` is one grouped panel driven by live counts, and drills
///   into a branch-pinned list;
/// * the hero sentence and that panel read the **same** total, so they cannot
///   disagree the way the old surface did;
/// * `Late` appears exactly once on the screen.
const _branch = BranchEntity(id: 'arkan', name: 'Drop The shop | Arkan');

const _manager = UserEntity(
  uid: 'mgr1',
  email: 'mgr@drop.test',
  authProvider: 'password',
  role: UserRole.manager,
  displayName: 'Ziad Elsewedy',
  branchId: 'arkan',
);

class _FakeAuthCubit extends Cubit<AuthState> implements AuthCubit {
  _FakeAuthCubit() : super(const AuthState.authenticated(_manager));
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeStatisticsCubit extends Cubit<StatisticsState>
    implements StatisticsCubit {
  _FakeStatisticsCubit()
    : super(
        const StatisticsState.loaded(
          StatisticsEntity(
            employeesInBranch: 8,
            scheduledToday: 2,
            morningShiftEmployees: 1,
            nightShiftEmployees: 1,
          ),
        ),
      );
  @override
  Future<void> load(UserEntity user, {bool forceRefresh = false}) async {}
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeTaskCubit extends Cubit<TaskState> implements TaskCubit {
  _FakeTaskCubit(List<TaskEntity> tasks) : super(TaskState.loaded(tasks));
  @override
  Map<String, String> get branchNames => const {'arkan': 'Drop The shop | Arkan'};
  @override
  Future<void> load(UserEntity user, {bool forceRefresh = false}) async {}
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeShiftSwapCubit extends Cubit<ShiftSwapState>
    implements ShiftSwapCubit {
  _FakeShiftSwapCubit() : super(const ShiftSwapState.loaded([]));
  String? loadedBranchId;
  @override
  Future<void> loadBranch(String branchId, {bool force = false}) async {
    loadedBranchId = branchId;
  }

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

class _FakeBranchCubit extends Cubit<BranchState> implements BranchCubit {
  _FakeBranchCubit() : super(const BranchState.loaded([_branch]));
  @override
  BranchEntity? branchById(String? id) => id == _branch.id ? _branch : null;
  @override
  Future<void> loadIfNeeded() async {}
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeChatListCubit extends Cubit<ChatListState> implements ChatListCubit {
  _FakeChatListCubit() : super(const ChatListState.loaded([]));
  @override
  Future<void> load({bool forceRefresh = false}) async {}
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeSalesMonthCubit extends Cubit<SalesMonthState>
    implements SalesMonthCubit {
  _FakeSalesMonthCubit(super.initial);
  @override
  Future<void> loadForBranch({
    required String branchId,
    DateTime? now,
    bool force = false,
  }) async {}
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Defaults to **disabled** — the branch in these fixtures does not run sales
/// targets, so the module renders nothing and every pre-existing expectation
/// about this page still describes it.
Widget _host(
  _FakeTaskCubit taskCubit, {
  _FakeShiftSwapCubit? swaps,
  SalesMonthState sales = const SalesMonthState.disabled(),
}) => MultiBlocProvider(
      providers: [
        BlocProvider<AuthCubit>(create: (_) => _FakeAuthCubit()),
        BlocProvider<StatisticsCubit>(create: (_) => _FakeStatisticsCubit()),
        BlocProvider<TaskCubit>.value(value: taskCubit),
        BlocProvider<ShiftSwapCubit>(
          create: (_) => swaps ?? _FakeShiftSwapCubit(),
        ),
        BlocProvider<RequestsListCubit>(create: (_) => _FakeRequestsListCubit()),
        BlocProvider<CaseListCubit>(create: (_) => _FakeCaseListCubit()),
        BlocProvider<BranchCubit>(create: (_) => _FakeBranchCubit()),
        BlocProvider<ChatListCubit>(create: (_) => _FakeChatListCubit()),
        BlocProvider<SalesMonthCubit>(create: (_) => _FakeSalesMonthCubit(sales)),
      ],
      // ManagerHomeScreen is a RoleScaffold child and builds no Scaffold of its
      // own — the shell is what puts a Material ancestor above it in the real
      // tree, and without one its InkWell rows assert.
      child: MaterialApp(
        theme: AppTheme.dark,
        home: const Scaffold(body: ManagerHomeScreen()),
      ),
    );

/// A task past its deadline in every sense the feed cares about.
TaskEntity _late() => TaskEntity(
  id: 't-late',
  title: 'Restock the front shelf',
  status: TaskStatus.pending,
  branchId: 'arkan',
  assigneeIds: const ['emp1'],
  deadline: DateTime.now().subtract(const Duration(days: 1)),
);

TaskEntity _rejected() => TaskEntity(
  id: 't-rejected',
  title: 'Redo the window display',
  status: TaskStatus.rejected,
  branchId: 'arkan',
  assigneeIds: const ['emp1'],
  deadline: DateTime.now().add(const Duration(days: 1)),
);

void _mobile(WidgetTester tester) {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void _desktop(WidgetTester tester) {
  tester.view.physicalSize = const Size(1440, 1000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Future<void> _settle(WidgetTester tester) async {
  await tester.pump(); // postFrameCallback → _load()
  await tester.pump(const Duration(milliseconds: 600));
}

/// Unmount the tree. The hero's `SyncButton` drives a 30s `Timer.periodic` to
/// keep its "3m ago" label honest, and a pending timer fails the test binding's
/// teardown invariant — every test here must tear the screen down explicitly.
Future<void> _unmount(WidgetTester tester) =>
    tester.pumpWidget(const SizedBox.shrink());

void main() {
  testWidgets('mobile renders the ranked ladder, not a wall of stat cards', (
    tester,
  ) async {
    _mobile(tester);
    final taskCubit = _FakeTaskCubit([_late(), _rejected()]);
    addTearDown(taskCubit.close);

    await tester.pumpWidget(_host(taskCubit));
    await _settle(tester);

    // The hero greets by name and names the branch it covers. The branch rides
    // the eyebrow now (one fewer text line), and `PageHero` uppercases that —
    // so match the uppercased form, not the source string.
    expect(find.textContaining('Ziad'), findsWidgets);
    expect(find.textContaining('DROP THE SHOP | ARKAN'), findsOneWidget);

    // One attention panel leads; the Today doors follow. (The page is a lazy
    // ListView, so only the built range is asserted here.)
    expect(find.byType(AttentionPanel), findsOneWidget);
    expect(find.byType(MetricTile), findsNWidgets(4));

    // The ladder, in order.
    expect(find.text('Needs attention'), findsOneWidget);
    expect(find.text('Today'), findsOneWidget);
    // Coverage names itself on the card, so there is no section label above it.
    expect(find.textContaining('on shift today'), findsOneWidget);
    // The launch surfaces further down the mobile stack (Operations · Quick
    // actions) are asserted on the desktop tier, where the rail mounts them
    // without a scroll — a fling here would leave a ballistic simulation
    // pending, and `pumpAndSettle` can't be used to drain it because the hero's
    // live pulse dot repeats forever by design.
    await _unmount(tester);
  });

  testWidgets('the hero sentence reads the same total as the panel', (
    tester,
  ) async {
    _mobile(tester);
    // One late + one sent back = two signals needing a decision.
    final taskCubit = _FakeTaskCubit([_late(), _rejected()]);
    addTearDown(taskCubit.close);

    await tester.pumpWidget(_host(taskCubit));
    await _settle(tester);

    expect(find.text('2 tasks need your attention'), findsOneWidget);
    expect(find.text('Late'), findsOneWidget);
    expect(find.text('Sent back'), findsOneWidget);
    // The cleared signals collapse into one quiet footer rather than three
    // switched-off rows.
    expect(
      find.textContaining('pending review · unassigned · swap requests'),
      findsOneWidget,
    );
    await _unmount(tester);
  });

  testWidgets('an empty branch reads as all clear, never as a failed load', (
    tester,
  ) async {
    _mobile(tester);
    final taskCubit = _FakeTaskCubit(const []);
    addTearDown(taskCubit.close);

    await tester.pumpWidget(_host(taskCubit));
    await _settle(tester);

    // Scoped to the panel: the activity feed's own empty state uses the same
    // two words further down the page.
    expect(
      find.descendant(
        of: find.byType(AttentionPanel),
        matching: find.text('All clear'),
      ),
      findsOneWidget,
    );
    // The panel is one compact row: a check, the title, and the derived list of
    // what was checked. The old reassuring sentence is gone — on a calm board
    // "nothing to do" was the tallest thing on the screen, and the hero says
    // "All caught up" three lines above it anyway.
    expect(find.text('All caught up'), findsOneWidget);
    expect(
      find.text('late · pending review · sent back · unassigned · swap requests'),
      findsOneWidget,
    );
    expect(find.textContaining('is on top of it'), findsNothing);
    await _unmount(tester);
  });

  testWidgets('Late is drawn exactly once — it never repeats in Today', (
    tester,
  ) async {
    _mobile(tester);
    final taskCubit = _FakeTaskCubit([_late()]);
    addTearDown(taskCubit.close);

    await tester.pumpWidget(_host(taskCubit));
    await _settle(tester);

    // The old surface printed the same overdue figure in a hero card and again
    // in the feed strip, from two different sources. It now lives only in the
    // attention panel.
    expect(find.text('Late'), findsOneWidget);
    await _unmount(tester);
  });

  testWidgets('tapping a signal drills into a branch-pinned filtered list', (
    tester,
  ) async {
    _mobile(tester);
    final taskCubit = _FakeTaskCubit([_late()]);
    addTearDown(taskCubit.close);

    await tester.pumpWidget(_host(taskCubit));
    await _settle(tester);

    await tester.tap(find.text('Late'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    final pushed = find.byType(FilteredTasksScreen);
    expect(pushed, findsOneWidget);
    expect(
      tester.widget<FilteredTasksScreen>(pushed).filter.branchId,
      'arkan',
      reason: 'a drill-down must state its own branch scope, not inherit it',
    );
    expect(
      find.descendant(
        of: pushed,
        matching: find.text('Restock the front shelf'),
      ),
      findsOneWidget,
    );

    await _unmount(tester);
  });

  testWidgets('every Today tile is a door — none is inert text', (tester) async {
    _mobile(tester);
    final taskCubit = _FakeTaskCubit([_late(), _rejected()]);
    addTearDown(taskCubit.close);

    await tester.pumpWidget(_host(taskCubit));
    await _settle(tester);

    // The row used to be a `StatStrip` whose `Due soon` cell looked identical
    // to its tappable neighbours and did nothing. Every tile now opens a list.
    final tiles = tester.widgetList<MetricTile>(find.byType(MetricTile));
    expect(tiles, hasLength(4));
    expect(
      tiles.map((t) => t.label),
      containsAll(<String>['Open', 'Running now', 'Due today', 'Done today']),
    );
    await _unmount(tester);
  });

  testWidgets('On shift today is one card that opens the schedule', (
    tester,
  ) async {
    _mobile(tester);
    final taskCubit = _FakeTaskCubit(const []);
    addTearDown(taskCubit.close);

    await tester.pumpWidget(_host(taskCubit));
    await _settle(tester);

    // Was four unclickable cells (Team · On today · Morning · Night) — eight
    // strings for one fact, on the half of the job that is all roster.
    expect(find.text('2'), findsWidgets);
    expect(find.text('of 8 on shift today'), findsOneWidget);
    expect(find.text('1 morning'), findsOneWidget);
    expect(find.text('1 night'), findsOneWidget);
    expect(find.text('Team'), findsNothing);
    expect(find.text('On today'), findsNothing);

    // And it is a real tap target.
    expect(
      tester
          .widget<Semantics>(
            find
                .ancestor(
                  of: find.text('of 8 on shift today'),
                  matching: find.byType(Semantics),
                )
                .first,
          )
          .properties
          .button,
      isTrue,
    );
    await _unmount(tester);
  });

  testWidgets('the hero carries one supporting line, not two', (tester) async {
    _mobile(tester);
    final taskCubit = _FakeTaskCubit([_late(), _rejected()]);
    addTearDown(taskCubit.close);

    await tester.pumpWidget(_host(taskCubit));
    await _settle(tester);

    // The scope line ("… · 8 employees · 0 running") is gone: the branch moved
    // into the eyebrow and the rest is what the Today row is for. Freshness is
    // gone from the eyebrow too — the Sync control already carries it.
    expect(find.textContaining('employees'), findsNothing);
    expect(find.textContaining('running'), findsNothing);
    expect(find.textContaining('Synced'), findsNothing);
    await _unmount(tester);
  });

  testWidgets('the swap queue is loaded for this branch only', (tester) async {
    _mobile(tester);
    final taskCubit = _FakeTaskCubit(const []);
    final swaps = _FakeShiftSwapCubit();
    addTearDown(taskCubit.close);

    await tester.pumpWidget(_host(taskCubit, swaps: swaps));
    await _settle(tester);

    // A manager runs one branch — loading every branch's swaps would be both
    // wrong and wasteful here.
    expect(swaps.loadedBranchId, 'arkan');
    await _unmount(tester);
  });

  testWidgets('desktop lays the story out beside a launch rail', (
    tester,
  ) async {
    _desktop(tester);
    final taskCubit = _FakeTaskCubit([_late()]);
    addTearDown(taskCubit.close);

    await tester.pumpWidget(_host(taskCubit));
    await _settle(tester);

    // Both columns are mounted at once: the operational story on the left, the
    // digest + quick actions rail on the right.
    expect(find.byType(AttentionPanel), findsOneWidget);
    expect(find.byType(DigestPanel), findsOneWidget);
    expect(find.text('Recent activity'), findsOneWidget);
    expect(find.text('Operations'), findsOneWidget);
    // Deleted: Branch tasks + Weekly schedule are bottom-nav/sidebar
    // destinations and Broadcast is the app-bar megaphone, so the section was
    // duplicated navigation.
    expect(find.text('Quick actions'), findsNothing);

    // The rail is a fixed 360 beside a flexible main column, so the story does
    // not stretch edge-to-edge on a wide window.
    final rail = tester.widget<SizedBox>(
      find
          .ancestor(
            of: find.text('Operations'),
            matching: find.byType(SizedBox),
          )
          .last,
    );
    expect(rail.width, 360);
    await _unmount(tester);
  });

  // ── Branch monthly sales ─────────────────────────────────────────
  testWidgets('an opted-in branch states its month on Home', (tester) async {
    final taskCubit = _FakeTaskCubit(const []);
    addTearDown(taskCubit.close);

    await tester.pumpWidget(
      _host(
        taskCubit,
        sales: const SalesMonthState.loaded(
          snapshot: SalesMonthSnapshot(
            target: BranchSalesMonthEntity(
              id: 'arkan_202608',
              branchId: 'arkan',
              monthKey: '202608',
              targetPiastres: 100000000,
            ),
          ),
          todayDateKey: '20260805',
        ),
      ),
    );
    await _settle(tester);

    // The manager sets this target and approves every day that moves it — Home
    // must state the figure, not just offer a door labelled "Branch sales".
    expect(find.byType(SalesTargetCard), findsOneWidget);
    expect(find.text('BRANCH MONTHLY SALES'), findsOneWidget);
    await _unmount(tester);
  });

  testWidgets('an opted-out branch renders no sales module at all', (
    tester,
  ) async {
    // Desktop, so the Operations rail is mounted rather than lazily built far
    // below the fold — the point of this test is that sales is gone *and*
    // nothing else in Operations went with it.
    _desktop(tester);
    final taskCubit = _FakeTaskCubit(const []);
    addTearDown(taskCubit.close);

    await tester.pumpWidget(_host(taskCubit));
    await _settle(tester);

    // Not a disabled card, and not the row that used to sit in the digest
    // ignoring the opt-in and landing on a "not enabled" screen.
    expect(find.byType(SalesTargetCard), findsNothing);
    expect(find.text('Branch sales'), findsNothing);
    // The rest of Operations is untouched.
    expect(find.byType(DigestPanel), findsOneWidget);
    expect(find.text('Branch attendance'), findsOneWidget);
    await _unmount(tester);
  });
}
