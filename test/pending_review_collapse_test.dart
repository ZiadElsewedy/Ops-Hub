import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drop/core/enums/task_status.dart';
import 'package:drop/core/enums/user_role.dart';
import 'package:drop/features/auth/domain/entities/user_entity.dart';
import 'package:drop/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:drop/features/auth/presentation/cubit/auth_state.dart';
import 'package:drop/features/branch/domain/entities/branch_entity.dart';
import 'package:drop/features/branch/presentation/cubit/branch_cubit.dart';
import 'package:drop/features/branch/presentation/cubit/branch_state.dart';
import 'package:drop/features/task/domain/entities/task_entity.dart';
import 'package:drop/features/task/presentation/cubit/task_cubit.dart';
import 'package:drop/features/task/presentation/cubit/task_state.dart';
import 'package:drop/features/task/presentation/pages/pending_review_screen.dart';

/// The admin Pending Review drill-down (Summary → Branch → Employee → task)
/// must **collapse any level that offers a single choice** — a lone branch or a
/// lone employee is skipped on the way in, so "one task, one branch, one person"
/// lands straight on the task instead of costing three empty taps. The full
/// drill-down must return the moment a level has more than one row.
const _ziad = UserEntity(
  uid: 'u1',
  email: 'ziad@drop.test',
  authProvider: 'password',
  displayName: 'Ziad Elsewedy',
);
const _mona = UserEntity(
  uid: 'u2',
  email: 'mona@drop.test',
  authProvider: 'password',
  displayName: 'Mona Fahmy',
);
const _admin = UserEntity(
  uid: 'admin',
  email: 'admin@drop.test',
  authProvider: 'password',
  displayName: 'Admin',
  role: UserRole.admin,
);
const _arkan = BranchEntity(id: 'b1', name: 'Arkan');
const _zamalek = BranchEntity(id: 'b2', name: 'Zamalek');

class _FakeAuthCubit extends Cubit<AuthState> implements AuthCubit {
  _FakeAuthCubit() : super(const AuthState.authenticated(_admin));
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _FakeBranchCubit extends Cubit<BranchState> implements BranchCubit {
  _FakeBranchCubit() : super(const BranchState.loaded([_arkan, _zamalek]));
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _FakeTaskCubit extends Cubit<TaskState> implements TaskCubit {
  _FakeTaskCubit(List<TaskEntity> tasks)
    : super(
        TaskState.loaded(tasks, directory: {
          for (final u in [_ziad, _mona]) u.uid: u,
        }),
      );

  @override
  Map<String, UserEntity> get directory => {
    for (final u in [_ziad, _mona]) u.uid: u,
  };

  @override
  Map<String, String> get branchNames => {
    for (final b in [_arkan, _zamalek]) b.id: b.name,
  };

  @override
  Future<void> load(UserEntity user, {bool forceRefresh = false}) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

TaskEntity _review({
  required String id,
  String title = 'Task',
  String branchId = 'b1',
  List<String> assignees = const ['u1'],
}) => TaskEntity(
  id: id,
  title: title,
  status: TaskStatus.waitingReview,
  branchId: branchId,
  assigneeIds: assignees,
);

Widget _host(_FakeTaskCubit taskCubit) => MultiBlocProvider(
  providers: [
    BlocProvider<AuthCubit>(create: (_) => _FakeAuthCubit()),
    BlocProvider<BranchCubit>(create: (_) => _FakeBranchCubit()),
    BlocProvider<TaskCubit>.value(value: taskCubit),
  ],
  // Reduced motion collapses the perpetual status-border orbit on the leaf card
  // (and the entrance staggers), so the tree can settle in the test harness.
  child: MaterialApp(
    home: MediaQuery(
      data: const MediaQueryData(disableAnimations: true),
      child: const PendingReviewScreen(),
    ),
  ),
);

void main() {
  testWidgets(
    'one branch + one employee collapses straight to the task leaf',
    (tester) async {
      final cubit = _FakeTaskCubit([
        _review(id: 't1', title: 'Restock shelves'),
      ]);
      addTearDown(cubit.close);

      await tester.pumpWidget(_host(cubit));
      // The leaf card runs a repeating status-border ticker, so the tree never
      // "settles"; pump fixed frames instead (the lone leaf row schedules no
      // delayed Timer, so nothing is left pending).
      await tester.pump(); // run the post-frame load()
      await tester.pump(); // rebuild on the loaded state

      // Landed on the leaf: the task card itself is on screen, and neither the
      // branch summary nor the employee picker was shown on the way.
      expect(find.text('Restock shelves'), findsOneWidget);
      expect(find.text('BY BRANCH'), findsNothing);
      expect(find.textContaining('select an employee'), findsNothing);
    },
  );

  testWidgets(
    'one branch + two employees skips the branch, shows the employee picker',
    (tester) async {
      final cubit = _FakeTaskCubit([
        _review(id: 't1', assignees: ['u1']),
        _review(id: 't2', assignees: ['u2']),
      ]);
      addTearDown(cubit.close);

      await tester.pumpWidget(_host(cubit));
      await tester.pumpAndSettle();

      // Branch level skipped (only one branch), employee picker shown.
      expect(find.textContaining('select an employee'), findsOneWidget);
      expect(find.text('BY BRANCH'), findsNothing);
      expect(find.text('Ziad Elsewedy'), findsOneWidget);
      expect(find.text('Mona Fahmy'), findsOneWidget);
    },
  );

  testWidgets(
    'two branches keep the full branch summary',
    (tester) async {
      final cubit = _FakeTaskCubit([
        _review(id: 't1', branchId: 'b1'),
        _review(id: 't2', branchId: 'b2'),
      ]);
      addTearDown(cubit.close);

      await tester.pumpWidget(_host(cubit));
      await tester.pumpAndSettle();

      // Nothing collapsed: the by-branch summary is the entry level.
      expect(find.text('BY BRANCH'), findsOneWidget);
      expect(find.text('Arkan'), findsOneWidget);
      expect(find.text('Zamalek'), findsOneWidget);
    },
  );
}
