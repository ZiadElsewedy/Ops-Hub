import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drop/core/enums/task_status.dart';
import 'package:drop/core/theme/app_theme.dart';
import 'package:drop/features/auth/domain/entities/user_entity.dart';
import 'package:drop/features/branch/domain/entities/branch_entity.dart';
import 'package:drop/features/task/domain/entities/task_entity.dart';
import 'package:drop/features/task/domain/task_feed.dart';
import 'package:drop/features/task/presentation/cubit/task_cubit.dart';
import 'package:drop/features/task/presentation/cubit/task_state.dart';
import 'package:drop/features/task/presentation/widgets/task_browser.dart';

/// [TaskBrowser] is the one searchable, date-grouped task surface behind the
/// branch list, the branch cockpit's Tasks preview and the employee drill-down.
/// These tests lock the three properties the redesign was asked for — search,
/// date organisation, and honest naming of closed work — plus the two bugs the
/// first implementation shipped with.
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
const _branch = BranchEntity(id: 'b1', name: 'Arkan');
const _other = BranchEntity(id: 'b2', name: 'Zamalek');

class _FakeTaskCubit extends Cubit<TaskState> implements TaskCubit {
  _FakeTaskCubit(List<TaskEntity> tasks)
    : super(
        TaskState.loaded(tasks, directory: {
          for (final u in [_ziad, _mona]) u.uid: u,
        }),
      );

  @override
  Map<String, String> get branchNames => {
    for (final b in [_branch, _other]) b.id: b.name,
  };

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Widget _host(_FakeTaskCubit cubit, {TaskFeedFilter? filter, double? width}) {
  final browser = TaskBrowser(
    initialFilter: filter ?? const TaskFeedFilter(activeWindowOnly: false),
  );
  return BlocProvider<TaskCubit>.value(
    value: cubit,
    child: MaterialApp(
      theme: AppTheme.dark,
      home: Scaffold(
        body: width == null
            ? browser
            : Align(
                alignment: Alignment.topLeft,
                child: SizedBox(width: width, height: 640, child: browser),
              ),
      ),
    ),
  );
}

TaskEntity _task({
  required String id,
  required String title,
  DateTime? deadline,
  TaskStatus status = TaskStatus.pending,
  String branchId = 'b1',
  List<String> assignees = const ['u1'],
}) => TaskEntity(
  id: id,
  title: title,
  status: status,
  branchId: branchId,
  assigneeIds: assignees,
  deadline: deadline,
);

void main() {
  final now = DateTime.now();

  testWidgets('tasks are organised into due-date sections', (tester) async {
    final cubit = _FakeTaskCubit([
      _task(
        id: 't1',
        title: 'Late delivery check',
        deadline: now.subtract(const Duration(days: 2)),
      ),
      _task(
        id: 't2',
        title: 'Open the shop',
        deadline: now.add(const Duration(hours: 3)),
      ),
      _task(id: 't3', title: 'Undated audit'),
    ]);
    addTearDown(cubit.close);

    await tester.pumpWidget(_host(cubit));
    await tester.pump();

    // Open work still uses the engine's own bucket labels, so there is never a
    // second forward-looking date scheme to keep in sync. The count is drawn
    // separately from the label (label · rule · count), not glued onto it.
    expect(find.text('LATE'), findsOneWidget);
    expect(find.text('TODAY'), findsOneWidget);
    expect(find.text('NO DUE DATE'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('closed work is sectioned by when it closed, not as "done today"',
      (tester) async {
    // The engine's dueTime grouping is built for the live feed: everything
    // finished lands in one bucket literally labelled "Done today". Browsing
    // the record set that way announced a task approved last month as having
    // closed today.
    final cubit = _FakeTaskCubit([
      TaskEntity(
        id: 't1',
        title: 'Approved long ago',
        status: TaskStatus.approved,
        branchId: 'b1',
        assigneeIds: const ['u1'],
        approvedAt: now.subtract(const Duration(days: 40)),
      ),
      TaskEntity(
        id: 't2',
        title: 'Approved just now',
        status: TaskStatus.approved,
        branchId: 'b1',
        assigneeIds: const ['u1'],
        approvedAt: now,
      ),
    ]);
    addTearDown(cubit.close);

    await tester.pumpWidget(_host(cubit));
    await tester.pump();

    expect(find.text('CLOSED TODAY'), findsOneWidget);
    expect(find.text('OLDER'), findsOneWidget);
    expect(find.text('DONE TODAY'), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('a search that matches nothing says so, and offers a way out', (
    tester,
  ) async {
    final cubit = _FakeTaskCubit([
      _task(id: 't1', title: 'Open the shop', deadline: now),
    ]);
    addTearDown(cubit.close);

    await tester.pumpWidget(_host(cubit));
    await tester.pump();

    await tester.enterText(find.byType(TextField), 'zzzz');
    await tester.pump();

    // Not a generic "no tasks" — that told a manager who had just mistyped a
    // name that the branch was empty.
    expect(find.textContaining('Nothing matches'), findsOneWidget);
    expect(find.text('Clear search'), findsOneWidget);

    await tester.tap(find.text('Clear search'));
    await tester.pump();

    expect(find.text('Open the shop'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('an active search reports how many matched', (tester) async {
    final cubit = _FakeTaskCubit([
      _task(id: 't1', title: 'Open the shop', deadline: now),
      _task(id: 't2', title: 'Open the store', deadline: now),
    ]);
    addTearDown(cubit.close);

    await tester.pumpWidget(_host(cubit));
    await tester.pump();

    await tester.enterText(find.byType(TextField), 'open');
    await tester.pump();

    expect(find.textContaining('2 matches'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('each lens carries the size of the list it opens', (
    tester,
  ) async {
    // A chip count and its list are derived from the same filter, so they
    // cannot disagree — the failure mode this codebase has hit before.
    final cubit = _FakeTaskCubit([
      _task(id: 't1', title: 'Open the shop', deadline: now),
      _task(
        id: 't2',
        title: 'Stock count',
        deadline: now,
        status: TaskStatus.waitingReview,
      ),
      _task(
        id: 't3',
        title: 'Fridge log',
        deadline: now,
        status: TaskStatus.waitingReview,
      ),
    ]);
    addTearDown(cubit.close);

    await tester.pumpWidget(_host(cubit));
    await tester.pump();

    expect(find.widgetWithText(ChoiceChip, '3'), findsOneWidget); // All
    expect(find.widgetWithText(ChoiceChip, '2'), findsOneWidget); // In review

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('an empty lens explains itself instead of showing a blank list', (
    tester,
  ) async {
    final cubit = _FakeTaskCubit([
      _task(id: 't1', title: 'Open the shop', deadline: now),
    ]);
    addTearDown(cubit.close);

    await tester.pumpWidget(_host(cubit));
    await tester.pump();

    await tester.tap(find.widgetWithText(ChoiceChip, 'In review'));
    await tester.pump();

    expect(find.text('Nothing to review'), findsOneWidget);
    expect(find.text('Show all tasks'), findsOneWidget);

    await tester.tap(find.text('Show all tasks'));
    await tester.pump();

    expect(find.text('Open the shop'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('search narrows by task title', (tester) async {
    final cubit = _FakeTaskCubit([
      _task(id: 't1', title: 'Open the shop', deadline: now),
      _task(id: 't2', title: 'Count the stock', deadline: now),
    ]);
    addTearDown(cubit.close);

    await tester.pumpWidget(_host(cubit));
    await tester.pump();
    expect(find.text('Count the stock'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'shop');
    await tester.pump();

    expect(find.text('Open the shop'), findsOneWidget);
    expect(find.text('Count the stock'), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('search matches an assignee name — "search on a special task '
      'for employee"', (tester) async {
    final cubit = _FakeTaskCubit([
      _task(id: 't1', title: 'Open the shop', deadline: now),
      _task(
        id: 't2',
        title: 'Count the stock',
        deadline: now,
        assignees: const ['u2'],
      ),
    ]);
    addTearDown(cubit.close);

    await tester.pumpWidget(_host(cubit));
    await tester.pump();

    await tester.enterText(find.byType(TextField), 'Mona');
    await tester.pump();

    expect(find.text('Count the stock'), findsOneWidget);
    expect(find.text('Open the shop'), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('search matches a branch name', (tester) async {
    final cubit = _FakeTaskCubit([
      _task(id: 't1', title: 'Open the shop', deadline: now),
      _task(
        id: 't2',
        title: 'Count the stock',
        deadline: now,
        branchId: 'b2',
      ),
    ]);
    addTearDown(cubit.close);

    await tester.pumpWidget(_host(cubit));
    await tester.pump();

    await tester.enterText(find.byType(TextField), 'Zamalek');
    await tester.pump();

    expect(find.text('Count the stock'), findsOneWidget);
    expect(find.text('Open the shop'), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('the closed lens is named Closed, never Done', (tester) async {
    // Missed and Cancelled work may be browsed alongside Approved, but the spec
    // forbids presenting either AS done — a missed task was never completed.
    // Each row keeps its own status badge, so nothing is summed or relabelled.
    final cubit = _FakeTaskCubit([
      _task(id: 't1', title: 'Approved work', status: TaskStatus.approved),
      _task(id: 't2', title: 'Missed work', status: TaskStatus.missed),
    ]);
    addTearDown(cubit.close);

    await tester.pumpWidget(_host(cubit));
    await tester.pump();

    expect(find.widgetWithText(ChoiceChip, 'Closed'), findsOneWidget);
    expect(find.widgetWithText(ChoiceChip, 'Done'), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('selecting a multi-status lens highlights that chip', (
    tester,
  ) async {
    // Regression: selection used to be inferred by comparing the filter's
    // status Set back to the lens's. Dart Set has no value equality, so
    // `{approved} == {approved}` is false for two separate literals and every
    // multi-status chip stayed visibly unselected after being tapped.
    final cubit = _FakeTaskCubit([
      _task(id: 't1', title: 'Waiting work', status: TaskStatus.waitingReview),
    ]);
    addTearDown(cubit.close);

    await tester.pumpWidget(_host(cubit));
    await tester.pump();

    ChoiceChip chip(String label) =>
        tester.widget<ChoiceChip>(find.widgetWithText(ChoiceChip, label));

    expect(chip('All').selected, isTrue);
    expect(chip('In review').selected, isFalse);

    await tester.tap(find.widgetWithText(ChoiceChip, 'In review'));
    await tester.pump();

    expect(chip('In review').selected, isTrue);
    expect(chip('All').selected, isFalse);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('the lens rail wraps rather than hiding a lens off-screen', (
    tester,
  ) async {
    // Five lenses on a 320pt phone. They wrap onto a second run; none of them
    // ends up in a horizontal scroller where a manager cannot see it exists —
    // this codebase has already shipped one bug where an unreachable control
    // was, in practice, a missing feature.
    final cubit = _FakeTaskCubit([
      _task(id: 't1', title: 'Open the shop', deadline: now),
    ]);
    addTearDown(cubit.close);

    await tester.pumpWidget(_host(cubit, width: 320));
    await tester.pump();

    expect(tester.takeException(), isNull);
    for (final lens in ['All', 'Active', 'In review', 'Late', 'Closed']) {
      expect(find.widgetWithText(ChoiceChip, lens), findsOneWidget);
      expect(tester.getRect(find.text(lens)).right, lessThanOrEqualTo(320));
    }

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('a scoped browser only shows that assignee\'s tasks', (
    tester,
  ) async {
    final cubit = _FakeTaskCubit([
      _task(id: 't1', title: 'Ziad task', deadline: now),
      _task(
        id: 't2',
        title: 'Mona task',
        deadline: now,
        assignees: const ['u2'],
      ),
    ]);
    addTearDown(cubit.close);

    await tester.pumpWidget(
      _host(
        cubit,
        filter: const TaskFeedFilter(
          assigneeUid: 'u1',
          activeWindowOnly: false,
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Ziad task'), findsOneWidget);
    expect(find.text('Mona task'), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
  });
}
