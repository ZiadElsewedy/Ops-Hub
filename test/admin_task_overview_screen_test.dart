import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drop/core/enums/task_status.dart';
import 'package:drop/core/enums/user_role.dart';
import 'package:drop/core/theme/app_theme.dart';
import 'package:drop/features/auth/domain/entities/user_entity.dart';
import 'package:drop/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:drop/features/auth/presentation/cubit/auth_state.dart';
import 'package:drop/features/branch/domain/entities/branch_entity.dart';
import 'package:drop/features/task/domain/entities/task_entity.dart';
import 'package:drop/features/task/presentation/cubit/task_cubit.dart';
import 'package:drop/features/task/presentation/cubit/task_state.dart';
import 'package:drop/features/task/presentation/pages/admin_task_overview_screen.dart';
import 'package:drop/features/task/presentation/pages/filtered_tasks_screen.dart';

/// The admin overview's stat row is exactly the tap surface the owner asked
/// for ("I want to click on missed to see all missed tasks"). This locks two
/// things: a stat tap actually pushes [FilteredTasksScreen], and the pushed
/// page lists the matching task rather than an empty "All clear" — the
/// `isTaskInActiveWindow` trap a naive `status: missed` filter falls into
/// (see `task_feed.dart`'s `activeWindowOnly`).
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

class _FakeTaskCubit extends Cubit<TaskState> implements TaskCubit {
  _FakeTaskCubit(List<TaskEntity> tasks, this._branches)
    : super(TaskState.loaded(tasks));

  final List<BranchEntity> _branches;

  @override
  Map<String, String> get branchNames => {
    for (final b in _branches) b.id: b.name,
  };

  @override
  Future<void> load(UserEntity user, {bool forceRefresh = false}) async {}

  @override
  Future<List<BranchEntity>> branches() async => _branches;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Widget _host(_FakeTaskCubit taskCubit) => MultiBlocProvider(
  providers: [
    BlocProvider<AuthCubit>(create: (_) => _FakeAuthCubit()),
    BlocProvider<TaskCubit>.value(value: taskCubit),
  ],
  child: MaterialApp(
    theme: AppTheme.dark,
    home: const AdminTaskOverviewScreen(),
  ),
);

void main() {
  testWidgets(
    'tapping the Missed stat pushes FilteredTasksScreen listing the missed task',
    (tester) async {
      const branch = BranchEntity(id: 'b1', name: 'Arkan');
      final missed = TaskEntity(
        id: 't-missed',
        title: 'Close the register',
        status: TaskStatus.missed,
        branchId: 'b1',
        deadline: DateTime.now().subtract(const Duration(days: 1)),
      );
      final open = TaskEntity(
        id: 't-open',
        title: 'Open the shop',
        branchId: 'b1',
      );
      final taskCubit = _FakeTaskCubit([missed, open], const [branch]);
      addTearDown(taskCubit.close);

      await tester.pumpWidget(_host(taskCubit));
      await tester.pump(); // postFrameCallback → _load()
      await tester.pump(); // branches() future resolves
      await tester.pump(const Duration(milliseconds: 400));

      // Missed is a full `MetricTile` door beside Active / In review / Late,
      // not an 11px record line under the reliability panel — it is the
      // company's only failure figure. Still hidden entirely at zero, and it is
      // drawn exactly once, so the count below the panel is gone.
      expect(find.text('Missed'), findsOneWidget);

      await tester.tap(find.text('Missed'));
      // `pumpAndSettle` is safe on THIS screen (unlike the role homes, which run
      // a periodic `SyncButton` timer that never settles) and is what lets the
      // pushed route finish its transition before we assert on it.
      await tester.pumpAndSettle();

      expect(find.byType(FilteredTasksScreen), findsOneWidget);
      expect(find.text('Close the register'), findsOneWidget);
      // Not the un-missed task, and not the naive-filter "All clear" trap.
      expect(find.text('Open the shop'), findsNothing);
      expect(find.text('All clear'), findsNothing);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 400));
    },
  );

  testWidgets('the Missed stat is hidden when there is nothing missed', (
    tester,
  ) async {
    const branch = BranchEntity(id: 'b1', name: 'Arkan');
    final open = TaskEntity(
      id: 't-open',
      title: 'Open the shop',
      branchId: 'b1',
    );
    final taskCubit = _FakeTaskCubit([open], const [branch]);
    addTearDown(taskCubit.close);

    await tester.pumpWidget(_host(taskCubit));
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    // `textContaining`, not `find.text('Missed')`: the door is labelled with its
    // count, so an exact-match finder would pass here even if the door were
    // rendered — which is the very regression this test exists to catch.
    expect(find.textContaining('Missed'), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 400));
  });
}
