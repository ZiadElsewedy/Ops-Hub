import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:drop/core/routes/route_names.dart';
import 'package:drop/core/enums/schedule_day.dart';
import 'package:drop/core/enums/schedule_shift.dart';
import 'package:drop/core/enums/task_priority.dart';
import 'package:drop/core/enums/template_repeat_mode.dart';
import 'package:drop/core/theme/app_theme.dart';
import 'package:drop/features/auth/domain/repositories/auth_repository.dart';
import 'package:drop/features/auth/domain/usecases/get_users_by_branch.dart';
import 'package:drop/features/branch/domain/repositories/branch_repository.dart';
import 'package:drop/features/notifications/domain/repositories/notification_repository.dart';
import 'package:drop/features/notifications/domain/usecases/notify_task_event.dart';
import 'package:drop/features/schedule/domain/entities/weekly_schedule_entity.dart';
import 'package:drop/features/schedule/domain/repositories/schedule_repository.dart';
import 'package:drop/features/schedule/domain/schedule_week.dart';
import 'package:drop/features/schedule/domain/shift_hours.dart';
import 'package:drop/features/task/domain/entities/recurring_task_template_entity.dart';
import 'package:drop/features/task/domain/task_schedule.dart';
import 'package:drop/features/task/domain/entities/task_entity.dart';
import 'package:drop/features/task/domain/repositories/task_repository.dart';
import 'package:drop/features/task/domain/usecases/assign_task.dart';
import 'package:drop/features/task/domain/usecases/create_task.dart';
import 'package:drop/features/task/domain/usecases/delete_task.dart';
import 'package:drop/features/task/domain/usecases/update_task.dart';
import 'package:drop/features/task/domain/usecases/upload_task_attachment.dart';
import 'package:drop/features/task/presentation/cubit/task_cubit.dart';
import 'package:drop/features/task/presentation/widgets/recurring_shift_task_sheets.dart';

void main() {
  test(
    'recurring-template save does not wait for today-instance follow-up I/O',
    () async {
      final repository = _TaskRepository();
      final cubit = _createCubit(repository);
      addTearDown(cubit.close);

      await cubit
          .createRecurringShiftTemplate(
            title: 'Open Store',
            priority: TaskPriority.normal,
            branchId: 'branch-1',
            shift: ScheduleShift.morning,
            repeat: TemplateRepeatMode.daily,
          )
          .timeout(const Duration(milliseconds: 200));

      expect(
        repository.instanceWrite.isCompleted,
        isFalse,
        reason: 'the best-effort instance write is still pending',
      );

      repository.instanceWrite.complete(null);
      await Future<void>.delayed(Duration.zero);
    },
  );

  test('today instance persists the weekly schedule shift deadline', () async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final scheduleDay = ScheduleDay.fromDate(today);
    final weekStart = ScheduleWeek.startOf(today);
    final hours = _liveWindowFor(now);
    final repository = _TaskRepository();
    final cubit = _createCubit(
      repository,
      scheduleRepository: _ScheduleRepository(
        schedule: WeeklyScheduleEntity(
          id: 'branch-1_week',
          branchId: 'branch-1',
          weekStart: weekStart,
          shiftHours: {
            scheduleDay: {ScheduleShift.morning: hours},
          },
        ),
      ),
    );
    addTearDown(cubit.close);

    await cubit.createRecurringShiftTemplate(
      title: 'Open Store',
      priority: TaskPriority.normal,
      branchId: 'branch-1',
      shift: ScheduleShift.morning,
      repeat: TemplateRepeatMode.daily,
    );
    await Future<void>.delayed(Duration.zero);

    final instance = repository.lastInstance;
    expect(instance, isNotNull);
    final slotDay = DateTime(
      weekStart.year,
      weekStart.month,
      weekStart.day + scheduleDay.index,
    );
    expect(instance!.instanceDate, slotDay);
    // Wall-clock, mirroring the materializer (and the server), so the
    // expectation holds on a DST-transition day too.
    DateTime civil(int minutes) => DateTime(
      slotDay.year,
      slotDay.month,
      slotDay.day + minutes ~/ 1440,
      minutes % 1440 ~/ 60,
      minutes % 60,
    );
    expect(instance.startsAt, civil(hours.startMinutes));
    expect(instance.deadline, civil(hours.endMinutes));

    repository.instanceWrite.complete(null);
    await Future<void>.delayed(Duration.zero);
  });

  test(
    'saving after the resolved shift window ended creates no instance',
    () async {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final scheduleDay = ScheduleDay.fromDate(today);
      final weekStart = ScheduleWeek.startOf(today);
      final repository = _TaskRepository();
      final cubit = _createCubit(
        repository,
        scheduleRepository: _ScheduleRepository(
          schedule: WeeklyScheduleEntity(
            id: 'branch-1_week',
            branchId: 'branch-1',
            weekStart: weekStart,
            shiftHours: {
              scheduleDay: {ScheduleShift.morning: _closedWindowFor(now)},
            },
          ),
        ),
      );
      addTearDown(cubit.close);

      await cubit.createRecurringShiftTemplate(
        title: 'Closed Window',
        priority: TaskPriority.normal,
        branchId: 'branch-1',
        shift: ScheduleShift.morning,
        repeat: TemplateRepeatMode.daily,
      );
      await Future<void>.delayed(Duration.zero);

      expect(repository.createdInstances, isEmpty);
    },
  );

  test(
    'saving inside the resolved shift window creates one local-date instance',
    () async {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final scheduleDay = ScheduleDay.fromDate(today);
      final weekStart = ScheduleWeek.startOf(today);
      final hours = _liveWindowFor(now);
      final repository = _TaskRepository();
      final cubit = _createCubit(
        repository,
        scheduleRepository: _ScheduleRepository(
          schedule: WeeklyScheduleEntity(
            id: 'branch-1_week',
            branchId: 'branch-1',
            weekStart: weekStart,
            shiftHours: {
              scheduleDay: {ScheduleShift.morning: hours},
            },
          ),
        ),
      );
      addTearDown(cubit.close);

      await cubit.createRecurringShiftTemplate(
        title: 'Live Window',
        priority: TaskPriority.normal,
        branchId: 'branch-1',
        shift: ScheduleShift.morning,
        repeat: TemplateRepeatMode.daily,
      );
      await Future<void>.delayed(Duration.zero);

      expect(repository.createdInstances, hasLength(1));
      expect(
        repository.createdInstances.single.id,
        'rt_template-1_${_dateKey(today)}',
      );

      repository.instanceWrite.complete(null);
      await Future<void>.delayed(Duration.zero);
    },
  );

  testWidgets('Automation Center empty state stays usable on a phone', (
    tester,
  ) async {
    await _usePhoneViewport(tester);
    final repository = _TaskRepository();
    final cubit = _createCubit(repository);
    addTearDown(cubit.close);

    await _openAutomationCenter(tester, cubit);

    expect(find.text('Automation Center'), findsOneWidget);
    expect(
      find.text('Manage recurring shift routines for this branch.'),
      findsOneWidget,
    );
    expect(find.text('Automate repetitive branch tasks.'), findsOneWidget);
    expect(find.text('Create Automation'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Create Automation'));
    await tester.pumpAndSettle();

    expect(find.text('New Automation'), findsOneWidget);
    expect(find.text('Create Automation'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Automation Center distinguishes load failure from empty', (
    tester,
  ) async {
    await _usePhoneViewport(tester);
    final repository = _TaskRepository(recurringError: StateError('offline'));
    final cubit = _createCubit(repository);
    addTearDown(cubit.close);

    await _openAutomationCenter(tester, cubit);

    expect(
      find.text('Automation details could not be loaded.'),
      findsOneWidget,
    );
    expect(find.text('Automate repetitive branch tasks.'), findsNothing);
    expect(find.text('Try again'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('card summarizes a routine and details sheet shows the rest', (
    tester,
  ) async {
    await _usePhoneViewport(tester);
    final nextRun = DateTime.now().add(const Duration(days: 2, hours: 1));
    final lastRun = DateTime.now().subtract(const Duration(hours: 2));
    final repository = _TaskRepository(
      templates: [
        RecurringTaskTemplateEntity(
          id: 'open-shift',
          title: 'Open Shift Checklist',
          branchId: 'branch-1',
          shift: ScheduleShift.morning,
          repeat: TemplateRepeatMode.daily,
          nextRunAt: nextRun,
          lastRunAt: lastRun,
          lastStatus: 'completed',
          lastGeneratedTaskId: 'task-42',
        ),
      ],
    );
    final cubit = _createCubit(repository);
    addTearDown(cubit.close);

    await _openAutomationCenter(tester, cubit);

    // Card surfaces the glanceable essentials.
    expect(find.text('Active'), findsWidgets);
    expect(find.text('Daily · Morning shift'), findsOneWidget);
    expect(find.text('Generated successfully'), findsOneWidget);
    expect(find.text('Next automation check'), findsOneWidget);

    // Details button opens the per-routine details sheet.
    await tester.ensureVisible(
      find.byKey(const ValueKey('automation-details-open-shift')),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('automation-details-open-shift')),
    );
    await tester.pumpAndSettle();

    expect(find.text('AUTOMATION'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('automation-details-close-open-shift')),
      findsOneWidget,
    );
    expect(find.byTooltip('Close automation details'), findsOneWidget);
    expect(find.text('Schedule'), findsOneWidget);
    expect(find.text('08:30 – 16:30'), findsOneWidget);
    expect(find.text('Next check'), findsOneWidget);
    expect(find.text('Latest outcome'), findsOneWidget);
    expect(find.text('More details'), findsOneWidget);
    expect(find.text('Missed policy · Enabled'), findsNothing);

    await tester.tap(find.text('More details'));
    await tester.pumpAndSettle();

    expect(find.text('Priority'), findsOneWidget);
    expect(find.text('Checklist'), findsOneWidget);
    expect(find.text('Assigned to'), findsOneWidget);
    expect(find.text('Shift timing'), findsOneWidget);
    expect(find.text('Missed policy · Enabled'), findsOneWidget);
    // The copy states the grace period explicitly (ADR-013) — a manager judging
    // a Missed record has to know it already allowed for finishing a little
    // over. Asserted against the constant so the two can never drift.
    //
    // It also names rework (ruled 2026-08-05): a manager who sends a generated
    // instance back is starting a clock they cannot otherwise see, since the
    // same sweep now closes `rejected` as Missed.
    expect(
      find.text(
        'Generated tasks are due at shift end. Unfinished tasks — including any '
        'sent back for rework — end as Missed '
        '${kTaskGracePeriod.inMinutes} minutes after that.',
      ),
      findsOneWidget,
    );
    expect(find.text('Last task'), findsOneWidget);
    expect(find.text('Tap to open'), findsOneWidget);

    await tester.tap(
      find.byKey(const ValueKey('automation-details-close-open-shift')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Automation Center'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('automation-details-close-open-shift')),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'paused and failed routines keep distinct status and outcome labels',
    (tester) async {
      await _usePhoneViewport(tester);
      final repository = _TaskRepository(
        templates: [
          const RecurringTaskTemplateEntity(
            id: 'paused',
            title: 'Paused routine',
            branchId: 'branch-1',
            shift: ScheduleShift.night,
            repeat: TemplateRepeatMode.weekly,
            weekday: DateTime.friday,
            active: false,
            lastStatus: 'failed',
            failureCount: 2,
          ),
          const RecurringTaskTemplateEntity(
            id: 'failed',
            title: 'Failed routine',
            branchId: 'branch-1',
            shift: ScheduleShift.morning,
            repeat: TemplateRepeatMode.daily,
            lastStatus: 'failed',
            failureCount: 1,
          ),
        ],
      );
      final cubit = _createCubit(repository);
      addTearDown(cubit.close);

      await _openAutomationCenter(tester, cubit);

      expect(find.text('Paused'), findsWidgets);
      expect(find.textContaining('Every Friday'), findsOneWidget);
      expect(find.text('Last generation failed'), findsWidgets);

      await tester.fling(find.byType(ListView), const Offset(0, -1200), 1000);
      await tester.pumpAndSettle();
      expect(find.text('Error'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'details sheet surfaces failure information for a failing routine',
    (tester) async {
      await _usePhoneViewport(tester);
      final repository = _TaskRepository(
        templates: [
          const RecurringTaskTemplateEntity(
            id: 'failing',
            title: 'Nightly Close',
            branchId: 'branch-1',
            shift: ScheduleShift.night,
            repeat: TemplateRepeatMode.daily,
            lastStatus: 'failed',
            failureCount: 3,
          ),
        ],
      );
      final cubit = _createCubit(repository);
      addTearDown(cubit.close);

      await _openAutomationCenter(tester, cubit);
      await tester.ensureVisible(
        find.byKey(const ValueKey('automation-details-failing')),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('automation-details-failing')),
      );
      await tester.pumpAndSettle();

      expect(find.text('Latest outcome'), findsOneWidget);
      expect(find.text('Last generation failed'), findsOneWidget);
      expect(find.textContaining('3 consecutive failures'), findsOneWidget);
      // The night-daily window carries its weekend qualifier.
      expect(find.textContaining('later on weekends'), findsNothing);
      await tester.tap(find.text('More details'));
      await tester.pumpAndSettle();
      expect(find.textContaining('later on weekends'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('toggle, delete confirmation, and last-task link work', (
    tester,
  ) async {
    await _usePhoneViewport(tester);
    final repository = _TaskRepository(
      templates: [
        RecurringTaskTemplateEntity(
          id: 'routine-1',
          title: 'Opening Checklist',
          branchId: 'branch-1',
          shift: ScheduleShift.morning,
          lastRunAt: DateTime.now(),
          lastStatus: 'completed',
          lastGeneratedTaskId: 'generated-7',
        ),
      ],
    );
    final cubit = _createCubit(repository);
    addTearDown(cubit.close);
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => _AutomationLauncher(cubit: cubit),
        ),
        GoRoute(
          path: RouteNames.taskDetailPattern,
          builder: (_, state) =>
              Scaffold(body: Text('Opened ${state.pathParameters['taskId']}')),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      MaterialApp.router(theme: AppTheme.dark, routerConfig: router),
    );
    await tester.tap(find.text('Open automation'));
    await tester.pumpAndSettle();

    // Inline switch pauses the routine.
    await tester.tap(find.byKey(const ValueKey('automation-toggle-routine-1')));
    await tester.pumpAndSettle();
    expect(repository.lastUpdated?.active, isFalse);

    // Last generated task opens from the details sheet.
    await tester.tap(
      find.byKey(const ValueKey('automation-details-routine-1')),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.byKey(const ValueKey('automation-last-task-routine-1')),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('automation-last-task-routine-1')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Opened generated-7'), findsOneWidget);

    router.pop();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Open automation'));
    await tester.pumpAndSettle();

    // The details sheet keeps its own actions reachable inside the new compact
    // scroll hierarchy. Resume updates in place rather than closing the sheet.
    await tester.tap(
      find.byKey(const ValueKey('automation-details-routine-1')),
    );
    await tester.pumpAndSettle();
    expect(find.byTooltip('Close automation details'), findsOneWidget);
    await tester.ensureVisible(find.text('Resume automation'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Resume automation'));
    await tester.pumpAndSettle();
    expect(repository.lastUpdated?.active, isTrue);
    expect(find.text('Pause automation'), findsOneWidget);

    // Delete from details asks for confirmation before removing the routine.
    await tester.ensureVisible(
      find.byKey(const ValueKey('automation-details-delete-routine-1')),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('automation-details-delete-routine-1')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Delete automation?'), findsOneWidget);
    expect(repository.lastDeletedId, isNull);

    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.widgetWithText(TextButton, 'Delete'),
      ),
    );
    await tester.pumpAndSettle();
    expect(repository.lastDeletedId, 'routine-1');
    expect(tester.takeException(), isNull);
  });
}

TaskCubit _createCubit(
  _TaskRepository repository, {
  ScheduleRepository? scheduleRepository,
}) => TaskCubit(
  repository: repository,
  branchRepository: _BranchRepository(),
  scheduleRepository: scheduleRepository ?? _ScheduleRepository(),
  createTask: CreateTask(repository),
  updateTask: UpdateTask(repository),
  deleteTask: DeleteTask(repository),
  assignTask: AssignTask(repository),
  uploadTaskAttachment: UploadTaskAttachment(repository),
  getUsersByBranch: GetUsersByBranch(_AuthRepository()),
  notifyTaskEvent: NotifyTaskEvent(_NotificationRepository()),
);

Future<void> _usePhoneViewport(WidgetTester tester) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(390, 844);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
}

Future<void> _openAutomationCenter(WidgetTester tester, TaskCubit cubit) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.dark,
      home: _AutomationLauncher(cubit: cubit),
    ),
  );
  await tester.tap(find.text('Open automation'));
  await tester.pumpAndSettle();
}

String _dateKey(DateTime date) {
  String two(int n) => n.toString().padLeft(2, '0');
  return '${date.year}-${two(date.month)}-${two(date.day)}';
}

/// A window that is unambiguously still open at [now] — it always has at least
/// an hour left to run, so the materializer's deadline guard must let it through
/// whatever time of day the suite runs.
ShiftHours _liveWindowFor(DateTime now) =>
    ShiftHours(0, now.hour * 60 + now.minute + 60);

/// A window that has already closed at [now]: it ends on the minute [now] falls
/// in, so `DateTime.now()` is past it by however many seconds have elapsed. The
/// one moment this cannot express is the first minute of the local day, when no
/// earlier minute exists to end on — a run started inside 00:00:00.000 would see
/// a deadline one minute ahead instead.
ShiftHours _closedWindowFor(DateTime now) {
  final minute = now.hour * 60 + now.minute;
  return ShiftHours(0, minute < 1 ? 1 : minute);
}

class _AutomationLauncher extends StatelessWidget {
  const _AutomationLauncher({required this.cubit});

  final TaskCubit cubit;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: TextButton(
          onPressed: () => showManageRecurringShiftTasksSheet(
            context: context,
            cubit: cubit,
            branchId: 'branch-1',
          ),
          child: const Text('Open automation'),
        ),
      ),
    );
  }
}

class _TaskRepository implements TaskRepository {
  _TaskRepository({
    List<RecurringTaskTemplateEntity> templates = const [],
    this.recurringError,
  }) : templates = [...templates];

  final Completer<TaskEntity?> instanceWrite = Completer<TaskEntity?>();
  final List<RecurringTaskTemplateEntity> templates;
  final Object? recurringError;
  RecurringTaskTemplateEntity? lastUpdated;
  TaskEntity? lastInstance;
  final createdInstances = <TaskEntity>[];
  String? lastDeletedId;

  @override
  Future<List<RecurringTaskTemplateEntity>> getRecurringTemplates(
    String branchId,
  ) async {
    if (recurringError case final error?) throw error;
    return List.unmodifiable(
      templates.where((template) => template.branchId == branchId),
    );
  }

  @override
  Future<RecurringTaskTemplateEntity> createRecurringTemplate(
    RecurringTaskTemplateEntity template,
  ) async => template.copyWith(id: 'template-1');

  @override
  Future<TaskEntity?> createTaskWithId(TaskEntity task) {
    lastInstance = task;
    createdInstances.add(task);
    return instanceWrite.future;
  }

  @override
  Future<void> updateRecurringTemplate(
    RecurringTaskTemplateEntity template,
  ) async {
    lastUpdated = template;
    final index = templates.indexWhere((item) => item.id == template.id);
    if (index >= 0) templates[index] = template;
  }

  @override
  Future<void> deleteRecurringTemplate(String templateId) async {
    lastDeletedId = templateId;
    templates.removeWhere((template) => template.id == templateId);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _BranchRepository implements BranchRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _ScheduleRepository implements ScheduleRepository {
  _ScheduleRepository({this.schedule});

  final WeeklyScheduleEntity? schedule;

  @override
  Future<WeeklyScheduleEntity?> getSchedule(
    String branchId,
    DateTime weekStart,
  ) async => schedule;

  /// The real cache-first read falls back to the same document on a miss, so
  /// the fake serves the same roster. Overridden explicitly (rather than left
  /// to `noSuchMethod`) because `TaskCubit` binds shift streams from *this*
  /// call — letting it throw would silently move every test onto the slower
  /// server-reconcile path and leave the fast path untested.
  @override
  Future<WeeklyScheduleEntity?> getScheduleCacheFirst(
    String branchId,
    DateTime weekStart,
  ) async => schedule;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _AuthRepository implements AuthRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _NotificationRepository implements NotificationRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
