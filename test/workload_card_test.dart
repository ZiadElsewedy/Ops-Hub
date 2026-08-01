import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drop/core/enums/schedule_shift.dart';
import 'package:drop/core/enums/task_status.dart';
import 'package:drop/features/auth/domain/entities/user_entity.dart';
import 'package:drop/features/operations/domain/employee_workload.dart';
import 'package:drop/features/operations/presentation/widgets/workload_card.dart';
import 'package:drop/features/task/domain/entities/task_entity.dart';

/// Headless render test for the Branch Operations employee card — proves it
/// surfaces identity, the four workload counts, the shift badge and the
/// current-task preview without a Firebase connection.
void main() {
  const user = UserEntity(
      uid: 'u1',
      email: 'a@x.com',
      authProvider: 'password',
      displayName: 'Ahmed Hassan');

  Future<void> pump(WidgetTester tester, EmployeeWorkload w) =>
      tester.pumpWidget(MaterialApp(home: Scaffold(body: WorkloadCard(workload: w))));

  testWidgets('renders identity, metric counts, shift and current task',
      (tester) async {
    final w = EmployeeWorkload(
      user: user,
      shiftsToday: const [ScheduleShift.morning],
      active: 3,
      overdue: 2,
      submitted: 1,
      completedToday: 4,
      currentTask: const TaskEntity(
          id: 't', title: 'Store opening', status: TaskStatus.started),
    );
    await pump(tester, w);

    expect(find.text('Ahmed Hassan'), findsOneWidget);
    expect(find.text('Employee'), findsOneWidget); // role label
    expect(find.text('Morning'), findsOneWidget); // shift badge
    expect(find.text('3'), findsOneWidget); // active
    expect(find.text('2'), findsOneWidget); // overdue
    expect(find.text('4'), findsOneWidget); // completed today
    expect(find.text('Active'), findsOneWidget);
    expect(find.text('Late'), findsOneWidget);
    expect(find.text('Review'), findsOneWidget);
    expect(find.text('Done'), findsOneWidget);
    expect(find.textContaining('Now: Store opening'), findsOneWidget);
  });

  testWidgets('shows Off + idle when unscheduled with no work', (tester) async {
    await pump(tester, const EmployeeWorkload(user: user));
    expect(find.text('Off'), findsOneWidget);
    expect(find.text('Idle · all caught up'), findsOneWidget);
  });

  testWidgets('shows "waiting on review" when work is submitted', (tester) async {
    await pump(
        tester,
        const EmployeeWorkload(
            user: user, shiftsToday: [ScheduleShift.night], submitted: 2));
    expect(find.text('Night'), findsOneWidget);
    expect(find.text('Waiting on review'), findsOneWidget);
  });
}
