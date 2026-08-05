import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drop/core/enums/task_status.dart';
import 'package:drop/core/enums/user_role.dart';
import 'package:drop/core/theme/app_theme.dart';
import 'package:drop/features/auth/domain/entities/user_entity.dart';
import 'package:drop/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:drop/features/auth/presentation/cubit/auth_state.dart';
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

/// **Employee Home — the stat strip** and the empty bordered bar it used to
/// leave behind.
///
/// Every cell of the strip is gated on a non-zero count, so the container could
/// paint its surface and border with nothing inside it. Users read that as a
/// component that failed to load, not as "you are clear".
///
/// Testing note inherited from the other Home tests: `EntranceFade` schedules an
/// uncancelled `Future.delayed`, so every mount must settle before teardown or
/// the suite reports a pending timer — hence the unmount at the end of each case.
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
  DateTime? approvedAt,
}) => TaskEntity(
  id: id,
  title: 'Open the cold case',
  status: status,
  branchId: 'branch1',
  assigneeIds: const ['emp1'],
  startsAt: startsAt,
  deadline: deadline,
  approvedAt: approvedAt,
  createdBy: 'mgr1',
);

class _FakeAuthCubit extends Cubit<AuthState> implements AuthCubit {
  _FakeAuthCubit() : super(const AuthState.authenticated(_employee));
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
  child: MaterialApp(
    theme: AppTheme.dark,
    home: const Material(color: Color(0xFF0A0A0B), child: EmployeeHomeScreen()),
  ),
);


/// The strip is a private widget, so it is matched by runtime type name. Worth
/// the indirection: asserting on *text* alone cannot catch this bug — the broken
/// strip rendered no text either. Its presence is the thing under test.
final _statStrip = find.byWidgetPredicate(
  (w) => w.runtimeType.toString() == '_StatStrip',
);

void main() {
  // Regression pin for the empty bordered bar on Employee Home.
  //
  // Every cell of the stat strip is gated on a non-zero count, so the container
  // could paint its surface and border with nothing inside it — which reads to
  // a user as a component that failed to load. Two inputs produced it: an
  // employee with no tasks at all, and one whose only open item was *rejected*
  // (rework had no chip of its own, and the "Nothing to do" phrase is suppressed
  // while anything is open).

  testWidgets('no tasks at all: the strip is gone, not empty', (tester) async {
    final cubit = _FakeTaskCubit(const []);
    addTearDown(cubit.close);

    await tester.pumpWidget(_homeHost(cubit));
    await tester.pumpAndSettle();

    // The empty-state card speaks for the screen…
    expect(find.text('No tasks yet'), findsOneWidget);
    // …and the strip is not built at all. This is the assertion that fails on
    // the old code: it built an empty bordered container, taking up space and
    // its own leading gap while saying nothing.
    expect(_statStrip, findsNothing);
    expect(find.text('Nothing to do'), findsNothing);
    for (final label in ['Rework', 'To do', 'Active', 'In review', 'Done']) {
      expect(find.text(label), findsNothing, reason: '$label should not render');
    }

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });

  testWidgets('rework alone still fills the strip', (tester) async {
    final cubit = _FakeTaskCubit([_task(status: TaskStatus.rejected)]);
    addTearDown(cubit.close);

    await tester.pumpWidget(_homeHost(cubit));
    await tester.pumpAndSettle();

    // Rework is open work, so the strip must be present and must show it — the
    // old code had no rework chip, which left this case rendering an empty bar.
    expect(_statStrip, findsOneWidget);
    expect(find.text('Rework'), findsOneWidget);
    // Work is open, so the strip must not claim otherwise.
    expect(find.text('Nothing to do'), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });

  testWidgets('history with nothing open collapses to the phrase',
      (tester) async {
    final cubit = _FakeTaskCubit([
      _task(status: TaskStatus.approved, approvedAt: DateTime.now()),
    ]);
    addTearDown(cubit.close);

    await tester.pumpWidget(_homeHost(cubit));
    await tester.pumpAndSettle();

    expect(find.text('Nothing to do'), findsOneWidget);
    expect(find.text('Done'), findsOneWidget);
    expect(find.text('Rework'), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });
}
