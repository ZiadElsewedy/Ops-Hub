import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opshub/core/enums/task_status.dart';
import 'package:opshub/core/enums/user_role.dart';
import 'package:opshub/core/theme/app_theme.dart';
import 'package:opshub/core/widgets/app_motion.dart';
import 'package:opshub/core/widgets/premium_button.dart';
import 'package:opshub/features/attendance/domain/attendance_config.dart';
import 'package:opshub/features/attendance/presentation/cubit/attendance_cubit.dart';
import 'package:opshub/features/attendance/presentation/cubit/attendance_state.dart';
import 'package:opshub/features/auth/domain/entities/user_entity.dart';
import 'package:opshub/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:opshub/features/auth/presentation/cubit/auth_state.dart';
import 'package:opshub/features/branch/domain/entities/branch_entity.dart';
import 'package:opshub/features/branch/presentation/cubit/branch_cubit.dart';
import 'package:opshub/features/branch/presentation/cubit/branch_state.dart';
import 'package:opshub/features/chat/presentation/cubit/chat_list_cubit.dart';
import 'package:opshub/features/chat/presentation/cubit/chat_list_state.dart';
import 'package:opshub/features/employee/presentation/pages/employee_home_screen.dart';
import 'package:opshub/features/sales/presentation/cubit/sales_month_cubit.dart';
import 'package:opshub/features/sales/presentation/cubit/sales_month_state.dart';
import 'package:opshub/features/schedule/presentation/cubit/shift_swap_cubit.dart';
import 'package:opshub/features/schedule/presentation/cubit/shift_swap_state.dart';
import 'package:opshub/features/statistics/domain/entities/statistics_entity.dart';
import 'package:opshub/features/statistics/presentation/cubit/statistics_cubit.dart';
import 'package:opshub/features/statistics/presentation/cubit/statistics_state.dart';
import 'package:opshub/features/task/domain/entities/task_entity.dart';
import 'package:opshub/features/task/presentation/cubit/task_cubit.dart';
import 'package:opshub/features/task/presentation/cubit/task_state.dart';

/// **The start of a task is a server round trip, and it must never look like a
/// fault.** Between the tap and the new status there are 100ms–1s in which the
/// old behaviour dimmed the button to the disabled 50% and then replaced
/// *Start task* with *Continue* in a single frame — reported as "it lags, then
/// it works".
///
/// What is pinned here:
///  - the press is acknowledged on the frame it happens (a ring inside the
///    button that is still named *Start task* — working, not disabled);
///  - a refused start clears the ring instead of spinning forever;
///  - [ActionSwap] hands one action to the next, and collapses to an instant
///    swap under reduced motion.
///
/// `pumpAndSettle` is deliberately avoided while a start is in flight: the ring
/// is a real, endless [CircularProgressIndicator] and would never settle.
const _employee = UserEntity(
  uid: 'emp1',
  email: 'emp1@drop.test',
  authProvider: 'password',
  role: UserRole.employee,
  branchId: 'branch1',
  displayName: 'Employee One',
);

TaskEntity _task({TaskStatus status = TaskStatus.pending}) => TaskEntity(
  id: 'task1',
  title: 'Open the cold case',
  status: status,
  branchId: 'branch1',
  assigneeIds: const ['emp1'],
  createdBy: 'mgr1',
);

Finder get _ringInButton => find.descendant(
  of: find.byType(PremiumButton),
  matching: find.byType(CircularProgressIndicator),
);

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

/// Mimics the real cubit's protocol precisely, because the UI's in-flight
/// treatment is derived from it: `busy: true` the instant the write starts,
/// then the **stream** delivers the new status while the write is still
/// finishing (`busy` is still true), then `busy: false`.
class _FakeTaskCubit extends Cubit<TaskState> implements TaskCubit {
  _FakeTaskCubit() : super(TaskState.loaded([_task()]));

  int starts = 0;

  @override
  Map<String, String> get branchNames => const {};

  @override
  Future<void> load(UserEntity user, {bool forceRefresh = false}) async {}

  @override
  Future<void> startTask(TaskEntity task) async {
    starts++;
    emit(TaskState.loaded([_task()], busy: true));
  }

  /// The write committed: the status arrives first, the busy flag drops after.
  void settle() {
    emit(TaskState.loaded([_task(status: TaskStatus.started)], busy: true));
    emit(TaskState.loaded([_task(status: TaskStatus.started)]));
  }

  /// The write was refused — the task is still pending and nothing else will
  /// arrive. This is the case that would strand a spinner forever.
  void refuse() {
    emit(const TaskState.error('Someone moved this task first.'));
    emit(TaskState.loaded([_task()]));
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

/// Loaded with no rostered shift — "Off today", no clock row. It must not be
/// `initial`: that card shimmers, and a repeating animation means
/// `pumpAndSettle` never returns.
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

/// Disabled — this branch does not run monthly targets, so Home renders no
/// sales card at all and these tests stay about the task footer.
class _FakeSalesMonthCubit extends Cubit<SalesMonthState>
    implements SalesMonthCubit {
  _FakeSalesMonthCubit() : super(const SalesMonthState.disabled());
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
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Widget _homeHost(_FakeTaskCubit taskCubit) => MultiBlocProvider(
  providers: [
    BlocProvider<AuthCubit>(create: (_) => _FakeAuthCubit()),
    BlocProvider<BranchCubit>(create: (_) => _FakeBranchCubit()),
    BlocProvider<StatisticsCubit>(create: (_) => _FakeStatisticsCubit()),
    BlocProvider<TaskCubit>.value(value: taskCubit),
    BlocProvider<ShiftSwapCubit>(create: (_) => _FakeShiftSwapCubit()),
    BlocProvider<AttendanceCubit>(create: (_) => _FakeAttendanceCubit()),
    BlocProvider<ChatListCubit>(create: (_) => _FakeChatListCubit()),
    BlocProvider<SalesMonthCubit>(create: (_) => _FakeSalesMonthCubit()),
  ],
  // Wrapped in a Scaffold because a refusal surfaces through AppSnackbar,
  // which needs one to present into (the app gets it from RoleScaffold).
  child: MaterialApp(
    theme: AppTheme.dark,
    home: const Scaffold(body: EmployeeHomeScreen()),
  ),
);

void main() {
  testWidgets('Start is acknowledged on the frame of the tap, then hands over '
      'to Continue', (tester) async {
    final cubit = _FakeTaskCubit();
    addTearDown(cubit.close);

    await tester.pumpWidget(_homeHost(cubit));
    await tester.pumpAndSettle();

    expect(find.text('Start task'), findsOneWidget);
    expect(_ringInButton, findsNothing);

    await tester.tap(find.text('Start task'));
    await tester.pump();

    // The round trip has not returned — but the button says so itself.
    expect(cubit.starts, 1);
    expect(_ringInButton, findsOneWidget);
    expect(find.text('Start task'), findsOneWidget);
    expect(find.text('Continue'), findsNothing);

    // A second tap while the first is in flight must not fire again.
    await tester.tap(find.text('Start task'));
    await tester.pump();
    expect(cubit.starts, 1);

    cubit.settle();
    await tester.pump();
    // Mid-swap the two actions overlap; that is the animation existing.
    await tester.pump(const Duration(milliseconds: 80));
    expect(find.text('Continue'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Start task'), findsNothing);
    expect(_ringInButton, findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });

  testWidgets('a refused start clears the in-flight ring and stays startable', (
    tester,
  ) async {
    final cubit = _FakeTaskCubit();
    addTearDown(cubit.close);

    await tester.pumpWidget(_homeHost(cubit));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Start task'));
    await tester.pump();
    expect(_ringInButton, findsOneWidget);

    cubit.refuse();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    // No status arrived, so the action is unchanged — but it is live again,
    // not a button spinning against nothing.
    expect(_ringInButton, findsNothing);
    expect(find.text('Start task'), findsOneWidget);
    await tester.tap(find.text('Start task'));
    await tester.pump();
    expect(cubit.starts, 2);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });

  group('ActionSwap', () {
    Widget host({required Widget child, bool reduceMotion = false}) =>
        MediaQuery(
          data: MediaQueryData(disableAnimations: reduceMotion),
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: Center(child: ActionSwap(child: child)),
          ),
        );

    testWidgets('cross-fades one action into the next', (tester) async {
      await tester.pumpWidget(
        host(child: const Text('Start', key: ValueKey('a'))),
      );
      await tester.pumpAndSettle();

      await tester.pumpWidget(
        host(child: const Text('Continue', key: ValueKey('b'))),
      );
      await tester.pump(const Duration(milliseconds: 60));

      // Both on screen at once: the old one leaving, the new one arriving.
      expect(find.text('Start'), findsOneWidget);
      expect(find.text('Continue'), findsOneWidget);

      await tester.pumpAndSettle();
      expect(find.text('Start'), findsNothing);
      expect(find.text('Continue'), findsOneWidget);
    });

    testWidgets('swaps instantly under reduced motion', (tester) async {
      await tester.pumpWidget(
        host(child: const Text('Start', key: ValueKey('a')), reduceMotion: true),
      );
      await tester.pumpAndSettle();

      await tester.pumpWidget(
        host(
          child: const Text('Continue', key: ValueKey('b')),
          reduceMotion: true,
        ),
      );
      await tester.pump();

      expect(find.text('Start'), findsNothing);
      expect(find.text('Continue'), findsOneWidget);
    });
  });
}
