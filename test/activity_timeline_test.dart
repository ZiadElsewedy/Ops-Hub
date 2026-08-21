import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opshub/core/enums/task_status.dart';
import 'package:opshub/core/theme/app_colors.dart';
import 'package:opshub/features/task/domain/entities/activity_entry.dart';
import 'package:opshub/features/task/domain/entities/task_entity.dart';
import 'package:opshub/features/task/presentation/activity_format.dart';
import 'package:opshub/features/task/presentation/cubit/task_cubit.dart';
import 'package:opshub/features/task/presentation/widgets/activity_timeline.dart';

/// The reworked Task Details activity timeline (2026-07-06): hero head +
/// compact ledger rows + fold. Render-only — the cubit is touched lazily on
/// tap, so a [Fake] suffices.
class _FakeTaskCubit extends Fake implements TaskCubit {}

ActivityEntry _e(String status, int minutesAgo, {String? note}) =>
    ActivityEntry(
      status: status,
      actorId: 'u1',
      actorName: 'Ziad',
      at: DateTime.now().subtract(Duration(minutes: minutesAgo)),
      note: note,
    );

Widget _host(TaskEntity task) => MaterialApp(
  home: Scaffold(
    body: SingleChildScrollView(
      child: SizedBox(
        width: 520,
        child: ActivityTimeline(
          task: task,
          directory: const {},
          cubit: _FakeTaskCubit(),
          canReview: true,
        ),
      ),
    ),
  ),
);

void main() {
  test('activityColor wears the soft living-border state palette', () {
    expect(activityColor('pending'), kStatePending);
    expect(activityColor('assigned'), kStatePending);
    expect(activityColor('started'), kStateInProgress);
    expect(activityColor('waitingReview'), kStateInReview);
    expect(activityColor('rejected'), kStateRejected);
    expect(activityColor('approved'), AppColors.success);
    expect(activityColor('missed'), kStateRejected);
    expect(activityTitle('missed'), 'Missed deadline');
    expect(activityIcon('missed'), Icons.event_busy_rounded);
  });

  test('clockTime formats a 12-hour wall clock', () {
    expect(clockTime(DateTime(2026, 7, 6, 1, 43)), '1:43 AM');
    expect(clockTime(DateTime(2026, 7, 6, 0, 5)), '12:05 AM');
    expect(clockTime(DateTime(2026, 7, 6, 12, 0)), '12:00 PM');
    expect(clockTime(DateTime(2026, 7, 6, 23, 30)), '11:30 PM');
  });

  testWidgets('head hero + compact history rows render from the log', (
    tester,
  ) async {
    final task = TaskEntity(
      id: 't1',
      title: 'Till count',
      status: TaskStatus.waitingReview,
      activityLog: [
        _e('pending', 30),
        _e('started', 20, note: 'On it'),
        _e('waitingReview', 5),
      ],
    );
    await tester.pumpWidget(_host(task));
    await tester.pump(const Duration(milliseconds: 400)); // entrance staggers

    expect(find.text('CURRENT STATUS'), findsOneWidget);
    expect(find.text('Submitted for review'), findsOneWidget); // head title
    expect(find.text('Started'), findsOneWidget);
    expect(find.text('Task created'), findsOneWidget);
    expect(find.text('“On it”'), findsOneWidget); // note quote on a ledger row
  });

  testWidgets('long histories fold behind "Show earlier" and expand on tap', (
    tester,
  ) async {
    final task = TaskEntity(
      id: 't2',
      title: 'Long history',
      status: TaskStatus.started,
      activityLog: [
        for (var i = 0; i < 12; i++)
          _e(i.isEven ? 'started' : 'completed', 120 - i),
      ],
    );
    await tester.pumpWidget(_host(task));
    await tester.pump(const Duration(milliseconds: 400));

    // 12 events → hero head + 6 visible rows + 5 folded.
    expect(find.text('Show 5 earlier events'), findsOneWidget);

    await tester.tap(find.text('Show 5 earlier events'));
    await tester.pump(); // rebuild mounts the folded rows
    await tester.pump(const Duration(milliseconds: 400)); // elapse staggers
    expect(find.text('Show 5 earlier events'), findsNothing);
  });
}
