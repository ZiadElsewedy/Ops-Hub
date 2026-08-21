import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opshub/core/enums/task_status.dart';
import 'package:opshub/core/enums/user_role.dart';
import 'package:opshub/core/theme/app_theme.dart';
import 'package:opshub/features/auth/domain/entities/user_entity.dart';
import 'package:opshub/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:opshub/features/auth/presentation/cubit/auth_state.dart';
import 'package:opshub/features/branch/domain/entities/branch_entity.dart';
import 'package:opshub/features/operations/presentation/pages/employee_detail_screen.dart';
import 'package:opshub/features/task/domain/entities/task_entity.dart';
import 'package:opshub/features/task/presentation/cubit/task_cubit.dart';
import 'package:opshub/features/task/presentation/cubit/task_state.dart';
import 'package:opshub/features/task/presentation/widgets/manager_task_card.dart';
import 'package:opshub/features/task/presentation/widgets/task_browser.dart';

/// The employee drill-down used to render every task — including a dozen
/// approved ones — as a full-size [ManagerTaskCard], which is what made the
/// screen unreadable on a phone. It is now the shared [TaskBrowser]: compact
/// rows, searchable, grouped by date. These tests lock that shape.
const _admin = UserEntity(
  uid: 'admin1',
  email: 'admin@drop.test',
  authProvider: 'password',
  role: UserRole.admin,
  displayName: 'Admin One',
);
const _employee = UserEntity(
  uid: 'u1',
  email: 'ziad@drop.test',
  authProvider: 'password',
  displayName: 'Ziad Elsewedy',
);
const _branch = BranchEntity(id: 'b1', name: 'Arkan');

class _FakeAuthCubit extends Cubit<AuthState> implements AuthCubit {
  _FakeAuthCubit() : super(const AuthState.authenticated(_admin));
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeTaskCubit extends Cubit<TaskState> implements TaskCubit {
  _FakeTaskCubit(List<TaskEntity> tasks)
    : super(TaskState.loaded(tasks, directory: const {'u1': _employee}));

  @override
  Map<String, String> get branchNames => {_branch.id: _branch.name};

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Widget _host(_FakeTaskCubit cubit) => MultiBlocProvider(
  providers: [
    BlocProvider<AuthCubit>(create: (_) => _FakeAuthCubit()),
    BlocProvider<TaskCubit>.value(value: cubit),
  ],
  child: MaterialApp(
    theme: AppTheme.dark,
    home: const EmployeeDetailScreen(
      employee: _employee,
      isAdmin: true,
      defaultBranchId: 'b1',
    ),
  ),
);

TaskEntity _task(String id, String title, TaskStatus status) => TaskEntity(
  id: id,
  title: title,
  status: status,
  branchId: 'b1',
  assigneeIds: const ['u1'],
  deadline: DateTime.now(),
);

void main() {
  testWidgets('approved work renders as compact rows, not manager cards', (
    tester,
  ) async {
    final cubit = _FakeTaskCubit([
      for (var i = 0; i < 4; i++)
        _task('a$i', 'Approved $i', TaskStatus.approved),
    ]);
    addTearDown(cubit.close);

    await tester.pumpWidget(_host(cubit));
    await tester.pump();

    expect(find.byType(TaskBrowser), findsOneWidget);
    // The regression this screen existed to fix: twelve ~200pt action cards.
    expect(find.byType(ManagerTaskCard), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('the head summarises the employee record', (tester) async {
    final cubit = _FakeTaskCubit([
      _task('t1', 'Open the shop', TaskStatus.started),
      _task('t2', 'Stock count', TaskStatus.waitingReview),
      _task('t3', 'Closing checks', TaskStatus.approved),
      _task('t4', 'Fridge log', TaskStatus.missed),
    ]);
    addTearDown(cubit.close);

    await tester.pumpWidget(_host(cubit));
    await tester.pump();

    // `findsWidgets`: "Active" and "In review" are also lens chip labels in the
    // browser below, so an exact-count assertion would be about the chips as
    // much as the summary.
    expect(find.text('Active'), findsWidgets);
    expect(find.text('In review'), findsWidgets);
    expect(find.text('Done'), findsOneWidget); // summary only — the lens is "Closed"
    // Reliability is stated with its basis, on its own line — a bare percentage
    // is not interpretable, and a fifth Expanded cell ellipsised the basis away.
    expect(
      find.textContaining('approved ÷ (approved + missed)'),
      findsOneWidget,
    );

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('the role subtitle is capitalised', (tester) async {
    final cubit = _FakeTaskCubit([]);
    addTearDown(cubit.close);

    await tester.pumpWidget(_host(cubit));
    await tester.pump();

    expect(find.text('Employee'), findsOneWidget);
    expect(find.text('employee'), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
  });
}
