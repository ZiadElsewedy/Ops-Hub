import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drop/core/enums/schedule_shift.dart';
import 'package:drop/core/enums/task_status.dart';
import 'package:drop/features/auth/domain/entities/user_entity.dart';
import 'package:drop/features/operations/domain/employee_workload.dart';
import 'package:drop/features/operations/presentation/widgets/workload_card.dart';
import 'package:drop/features/task/domain/entities/task_entity.dart';

/// Headless render test for the Branch Operations employee row — proves it
/// surfaces identity, the workload figures, the shift and the current task
/// without a Firebase connection.
///
/// The card was compressed from a ~160pt card to a ~64–78pt row: role and shift
/// now share one line, and the four-up bordered metric strip became a single
/// caption built from **non-zero figures only**. These tests assert the
/// compressed shape, and that a zero never reaches the screen.
void main() {
  const user = UserEntity(
    uid: 'u1',
    email: 'a@x.com',
    authProvider: 'password',
    displayName: 'Ahmed Hassan',
  );

  Future<void> pump(WidgetTester tester, EmployeeWorkload w) => tester
      .pumpWidget(MaterialApp(home: Scaffold(body: WorkloadCard(workload: w))));

  testWidgets('renders identity, figures, shift and current task', (
    tester,
  ) async {
    final w = EmployeeWorkload(
      user: user,
      shiftsToday: const [ScheduleShift.morning],
      active: 3,
      overdue: 2,
      submitted: 1,
      completedToday: 4,
      currentTask: const TaskEntity(
        id: 't',
        title: 'Store opening',
        status: TaskStatus.started,
      ),
    );
    await pump(tester, w);

    expect(find.text('Ahmed Hassan'), findsOneWidget);
    // Role and shift share one line in the compressed row.
    expect(find.text('Employee · Morning'), findsOneWidget);
    expect(find.text('3 active · 2 late · 1 in review · 4 done'), findsOneWidget);
    expect(find.textContaining('Now: Store opening'), findsOneWidget);
  });

  testWidgets('an off-shift employee with no work is a bare identity row', (
    tester,
  ) async {
    await pump(tester, const EmployeeWorkload(user: user));

    expect(find.text('Employee · Off'), findsOneWidget);
    // No metric line at all rather than a row of zeros.
    expect(find.textContaining('active'), findsNothing);
    expect(find.textContaining('Now:'), findsNothing);
    expect(find.textContaining('Next:'), findsNothing);
  });

  testWidgets('submitted work shows as an in-review figure', (tester) async {
    await pump(
      tester,
      const EmployeeWorkload(
        user: user,
        shiftsToday: [ScheduleShift.night],
        submitted: 2,
      ),
    );

    expect(find.text('Employee · Night'), findsOneWidget);
    expect(find.text('2 in review'), findsOneWidget);
  });

  testWidgets('someone who only finished work today never renders zeros', (
    tester,
  ) async {
    // Regression: `hasFigures` counts completedToday, so gating the line on it
    // while omitting Done from the line printed "0 active · 0 late · 0 in
    // review" — three zeros for a person who had a productive day.
    await pump(tester, const EmployeeWorkload(user: user, completedToday: 4));

    expect(find.text('4 done'), findsOneWidget);
    expect(find.textContaining('0'), findsNothing);
  });
}
