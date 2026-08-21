import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opshub/core/enums/schedule_shift.dart';
import 'package:opshub/core/enums/task_assignment_type.dart';
import 'package:opshub/core/enums/task_status.dart';
import 'package:opshub/core/enums/user_role.dart';
import 'package:opshub/core/theme/app_theme.dart';
import 'package:opshub/core/utils/app_date_formatter.dart';
import 'package:opshub/features/auth/domain/entities/user_entity.dart';
import 'package:opshub/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:opshub/features/auth/presentation/cubit/auth_state.dart';
import 'package:opshub/features/branch/domain/entities/branch_entity.dart';
import 'package:opshub/features/branch/presentation/cubit/branch_cubit.dart';
import 'package:opshub/features/branch/presentation/cubit/branch_state.dart';
import 'package:opshub/features/task/domain/entities/activity_entry.dart';
import 'package:opshub/features/task/domain/entities/task_entity.dart';
import 'package:opshub/features/task/presentation/cubit/task_cubit.dart';
import 'package:opshub/features/task/presentation/cubit/task_state.dart';
import 'package:opshub/features/task/presentation/pages/task_details_screen.dart';

/// Task Details answers **"who put this here, and when does it run?"**
/// (2026-08-06, owner: *"i just want to add more detail like whos create the
/// task? if it automation task so write System - Automated task — and the
/// estimate time to be clear and start and end more clear as well"*).
///
/// Two faults, both visible on one generated shift task:
///  - the Assignment section printed `Morning Shift` and stopped, so the screen
///    never said the task was machine-generated — and the activity timeline
///    signed the creation event *"Someone"*, because the server writes
///    `actorId: "system"`, which is not a uid and never resolves;
///  - the window read `Starts 6 Aug 2026 · Due 6 Aug 2026 · Est. 8h` — two
///    identical-looking dates and a number mislabelled as an estimate.
const _employee = UserEntity(
  uid: 'emp1',
  email: 'emp1@drop.test',
  authProvider: 'password',
  role: UserRole.employee,
  branchId: 'branch1',
  displayName: 'Employee One',
);

const _manager = UserEntity(
  uid: 'mgr1',
  email: 'mgr1@drop.test',
  authProvider: 'password',
  role: UserRole.manager,
  branchId: 'branch1',
  displayName: 'Ziad',
);

/// The exact shape `generateShiftTaskInstances` writes: a shift assignment, the
/// template's owner copied into `createdBy`, and a `system`-actored creation
/// event. 09:00 → 17:00 on one day.
TaskEntity _generatedShiftTask({DateTime? day}) {
  final base = day ?? DateTime.now();
  final start = DateTime(base.year, base.month, base.day, 9);
  return TaskEntity(
    id: 'task1',
    title: 'Open Shift',
    status: TaskStatus.pending,
    branchId: 'branch1',
    assignmentType: TaskAssignmentType.shift,
    shift: ScheduleShift.morning,
    createdBy: 'mgr1',
    sourceTemplateId: 'tpl_1',
    correlationId: 'AUT-20260806-ab12',
    startsAt: start,
    deadline: start.add(const Duration(hours: 8)),
    activityLog: [
      ActivityEntry(
        status: TaskStatus.pending.value,
        actorId: 'system',
        at: start.subtract(const Duration(hours: 8)),
        note: 'Auto-generated (recurring shift task)',
      ),
    ],
  );
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
  _FakeTaskCubit(TaskEntity task, Map<String, UserEntity> directory)
    : super(TaskState.loaded([task], directory: directory));

  @override
  Map<String, String> get branchNames => const {};

  @override
  Future<void> load(UserEntity user, {bool forceRefresh = false}) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Widget _host(TaskEntity task, {Map<String, UserEntity> directory = const {}}) {
  final cubit = _FakeTaskCubit(task, directory);
  addTearDown(cubit.close);
  return MultiBlocProvider(
    providers: [
      BlocProvider<AuthCubit>(create: (_) => _FakeAuthCubit()),
      BlocProvider<BranchCubit>(create: (_) => _FakeBranchCubit()),
      BlocProvider<TaskCubit>.value(value: cubit),
    ],
    child: MaterialApp(
      theme: AppTheme.dark,
      home: TaskDetailsScreen(task: task, directory: directory),
    ),
  );
}

/// Builds and lets the staggered `EntranceFade`s land.
///
/// Deliberately **not** `pumpAndSettle`: an in-flight task's activity timeline
/// breathes forever by design (`_TimelineNode.breathing`), so settling never
/// returns. Pumping fixed durations is the documented way past a perpetual
/// animation in this suite.
Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 900));
  await tester.pump(const Duration(milliseconds: 900));
}

/// Unmounts the screen so `EntranceFade`'s uncancelled `Future.delayed` cannot
/// outlive the test (the convention every Task Details widget test follows).
Future<void> _teardown(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(const Duration(seconds: 2));
}

void main() {
  testWidgets('a generated shift task is credited to System, not to the '
      'manager who owns its template', (tester) async {
    await tester.pumpWidget(
      _host(_generatedShiftTask(), directory: const {'mgr1': _manager}),
    );
    await _settle(tester);

    // The assignment target is unchanged…
    expect(find.text('Morning Shift'), findsOneWidget);
    // …and now it says where the task came from.
    expect(
      find.textContaining(
        'Created by System · Automated task',
        findRichText: true,
      ),
      findsOneWidget,
    );
    // The human is not erased — demoted to the fact they actually own.
    expect(find.text('Set up by Ziad · Manager'), findsOneWidget);
    // They are never credited with creating this instance.
    expect(
      find.textContaining('Created by Ziad', findRichText: true),
      findsNothing,
    );
    expect(
      find.textContaining('Assigned by', findRichText: true),
      findsNothing,
    );

    await _teardown(tester);
  });

  testWidgets('the system signs its own activity event instead of "Someone"', (
    tester,
  ) async {
    await tester.pumpWidget(_host(_generatedShiftTask()));
    await _settle(tester);

    expect(find.text('Task created'), findsOneWidget);
    expect(find.text('System'), findsOneWidget);
    expect(find.text('AUTOMATED'), findsOneWidget); // the role chip, uppercased
    expect(find.text('Someone'), findsNothing);

    await _teardown(tester);
  });

  testWidgets('the schedule window shows both clock times and an honestly '
      'labelled duration', (tester) async {
    await tester.pumpWidget(_host(_generatedShiftTask()));
    await _settle(tester);

    expect(find.text('STARTS'), findsOneWidget);
    expect(find.text('09:00'), findsOneWidget);
    expect(find.text('DUE'), findsOneWidget);
    expect(find.text('17:00'), findsOneWidget);
    // "Window", not "Est." — it is dueAt − startsAt, not an estimate of effort.
    expect(find.text('WINDOW'), findsOneWidget);
    expect(find.text('8h'), findsOneWidget);
    // Both ends sit on the same day, and the band says so once per cell.
    expect(find.text('Today'), findsNWidgets(2));
    // The superseded chips are gone.
    expect(find.textContaining('Est. '), findsNothing);
    expect(find.textContaining('Starts '), findsNothing);

    await _teardown(tester);
  });

  testWidgets('a hand-created task keeps its Assigned by handover', (
    tester,
  ) async {
    final task = TaskEntity(
      id: 'task2',
      title: 'Count the fridge',
      status: TaskStatus.pending,
      branchId: 'branch1',
      assigneeIds: const ['emp1'],
      createdBy: 'mgr1',
      deadline: DateTime.now().add(const Duration(hours: 3)),
    );
    await tester.pumpWidget(
      _host(task, directory: const {'mgr1': _manager, 'emp1': _employee}),
    );
    await _settle(tester);

    expect(
      find.textContaining('Assigned by Ziad · Manager', findRichText: true),
      findsOneWidget,
    );
    expect(find.textContaining('System', findRichText: true), findsNothing);
    // No start time on this one, so the band draws the ends it has and no
    // duration cell — never a row of em-dashes.
    expect(find.text('DUE'), findsOneWidget);
    expect(find.text('STARTS'), findsNothing);
    expect(find.text('WINDOW'), findsNothing);

    await _teardown(tester);
  });

  testWidgets('the band survives a 320px phone with a far-off, non-relative '
      'window — no overflow, and the day is not truncated away', (tester) async {
    // The narrow worst case: three cells inside the header card leave ~80px
    // each at 320px. That is exactly why the detail line uses
    // `relativeDayShort` — `Thursday, 15 Sep` would ellipsize to
    // `Thursday, 15…`, which says less than `15 Sep`.
    //
    // The activity timeline is deliberately left out of this task: its head-row
    // eyebrow (`activity_timeline.dart:345`, "CURRENT STATUS" + `Spacer` + the
    // timestamp, neither side flexible) already overflows at 320px on its own,
    // and `takeException` is global — including a log here would assert on a
    // pre-existing bug this change did not touch.
    tester.view.physicalSize = const Size(320, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final far = DateTime.now().add(const Duration(days: 40));
    await tester.pumpWidget(
      _host(_generatedShiftTask(day: far).copyWith(activityLog: const [])),
    );
    await _settle(tester);

    expect(tester.takeException(), isNull); // no RenderFlex overflow
    expect(find.text('09:00'), findsOneWidget);
    expect(find.text('17:00'), findsOneWidget);
    expect(find.text('8h'), findsOneWidget);
    // The compact day, rendered in full — both cells sit on the same date.
    expect(
      find.text(AppDateFormatter.relativeDayShort(far)),
      findsNWidgets(2),
    );

    await _teardown(tester);
  });
}
