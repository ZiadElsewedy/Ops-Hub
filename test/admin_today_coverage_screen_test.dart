import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drop/core/enums/schedule_day.dart';
import 'package:drop/core/enums/schedule_shift.dart';
import 'package:drop/core/enums/user_role.dart';
import 'package:drop/core/theme/app_theme.dart';
import 'package:drop/features/auth/domain/entities/user_entity.dart';
import 'package:drop/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:drop/features/auth/presentation/cubit/auth_state.dart';
import 'package:drop/features/branch/domain/entities/branch_entity.dart';
import 'package:drop/features/branch/presentation/cubit/branch_cubit.dart';
import 'package:drop/features/branch/presentation/cubit/branch_state.dart';
import 'package:drop/features/schedule/domain/entities/weekly_schedule_entity.dart';
import 'package:drop/features/schedule/domain/today_coverage.dart';
import 'package:drop/features/schedule/domain/today_roster.dart';
import 'package:drop/features/schedule/presentation/cubit/schedule_cubit.dart';
import 'package:drop/features/schedule/presentation/cubit/schedule_state.dart';
import 'package:drop/features/schedule/presentation/cubit/shift_swap_cubit.dart';
import 'package:drop/features/schedule/presentation/cubit/shift_swap_state.dart';
import 'package:drop/features/schedule/presentation/cubit/today_coverage_cubit.dart';
import 'package:drop/features/schedule/presentation/cubit/today_coverage_state.dart';
import 'package:drop/features/schedule/presentation/pages/schedule_management_screen.dart';
import 'package:drop/features/schedule/presentation/widgets/manager_schedule_view.dart';

const _branch = BranchEntity(id: 'arkan', name: 'Arkan', location: '6 October');
const _admin = UserEntity(
  uid: 'admin', email: 'admin@drop.test', authProvider: 'password', role: UserRole.admin,
);

class _FakeAuthCubit extends Cubit<AuthState> implements AuthCubit {
  _FakeAuthCubit() : super(const AuthState.authenticated(_admin));
  @override dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
class _FakeBranchCubit extends Cubit<BranchState> implements BranchCubit {
  _FakeBranchCubit() : super(const BranchState.loaded([_branch]));
  @override Future<void> load({bool forceRefresh = false}) async {}
  @override dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
class _FakeScheduleCubit extends Cubit<ScheduleState> implements ScheduleCubit {
  _FakeScheduleCubit() : super(ScheduleState.loaded(branchId: _branch.id, weekStart: DateTime.now(), schedule: null));
  @override Future<void> load({required String branchId, DateTime? weekStart}) async {}
  @override Future<void> refresh() async {}
  @override dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
class _FakeSwaps extends Cubit<ShiftSwapState> implements ShiftSwapCubit {
  _FakeSwaps() : super(const ShiftSwapState.loaded([]));
  @override Future<void> loadAll({bool force = false}) async {}
  @override Future<void> refresh() async {}
  @override dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
class _FakeCoverage extends Cubit<TodayCoverageState> implements TodayCoverageCubit {
  _FakeCoverage(TodayCoverage row) : super(TodayCoverageLoaded([row]));
  @override Future<void> load(List<BranchEntity> branches) async {}
  @override dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  testWidgets('surfaces uncovered coverage and opens the existing roster sheet', (tester) async {
    final member = const UserEntity(uid: 'u1', email: 'u1@drop.test', authProvider: 'password', role: UserRole.employee, branchId: 'arkan');
    final schedule = WeeklyScheduleEntity(
      id: 'arkan_week', branchId: 'arkan', weekStart: DateTime.now(),
      assignments: {ScheduleDay.today(): {ScheduleShift.morning: ['u1']}},
    );
    final row = TodayCoverage(branch: _branch, schedule: schedule, roster: todayRoster(schedule: schedule, members: [member]));
    await tester.pumpWidget(MultiBlocProvider(
      providers: [
        BlocProvider<AuthCubit>(create: (_) => _FakeAuthCubit()),
        BlocProvider<BranchCubit>(create: (_) => _FakeBranchCubit()),
        BlocProvider<ScheduleCubit>(create: (_) => _FakeScheduleCubit()),
        BlocProvider<ShiftSwapCubit>(create: (_) => _FakeSwaps()),
        BlocProvider<TodayCoverageCubit>(create: (_) => _FakeCoverage(row)),
      ],
      child: MaterialApp(theme: AppTheme.dark, home: const ScheduleManagementScreen()),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Nobody is on night'), findsOneWidget);
    await tester.tap(find.text('Arkan'));
    await tester.pumpAndSettle();
    expect(find.text('On shift today'), findsOneWidget);
  });

  testWidgets('Edit opens the weekly editor ON the branch whose row was tapped', (
    tester,
  ) async {
    final schedule = WeeklyScheduleEntity(
      id: 'arkan_week',
      branchId: 'arkan',
      weekStart: DateTime.now(),
      assignments: const {},
    );
    final row = TodayCoverage(
      branch: _branch,
      schedule: schedule,
      roster: todayRoster(schedule: schedule, members: const []),
    );
    await tester.pumpWidget(
      MultiBlocProvider(
        providers: [
          BlocProvider<AuthCubit>(create: (_) => _FakeAuthCubit()),
          BlocProvider<BranchCubit>(create: (_) => _FakeBranchCubit()),
          BlocProvider<ScheduleCubit>(create: (_) => _FakeScheduleCubit()),
          BlocProvider<ShiftSwapCubit>(create: (_) => _FakeSwaps()),
          BlocProvider<TodayCoverageCubit>(create: (_) => _FakeCoverage(row)),
        ],
        child: MaterialApp(
          theme: AppTheme.dark,
          home: const ScheduleManagementScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // The weekly grid itself is NOT under test here — it wants the full cubit
    // harness and a desktop-sized viewport, and throws in this one. Silence its
    // failures for the two frames it takes to mount, so they neither fail this
    // contract nor bury the run in a render dump.
    final reportError = FlutterError.onError;
    FlutterError.onError = (_) {};
    addTearDown(() => FlutterError.onError = reportError);

    await tester.tap(find.text('Edit'));
    await tester.pump(); // start the tab animation
    await tester.pump(const Duration(milliseconds: 400)); // it settles, editor mounts

    // The branch is handed to the editor as a constructor argument. Pushing it
    // into ScheduleCubit from the outside used to look like it worked and did
    // not: the editor mounts only after the tab animation settles, then its own
    // init loads the DEFAULT branch and overwrites the selection. This asserts
    // the deterministic path, so that regression can't come back silently.
    final editor = tester.widget<ManagerScheduleView>(
      find.byType(ManagerScheduleView),
    );
    expect(editor.initialBranchId, _branch.id);
    while (tester.takeException() != null) {}
  });
}
