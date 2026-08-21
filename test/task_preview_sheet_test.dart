import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opshub/core/enums/task_status.dart';
import 'package:opshub/core/theme/app_theme.dart';
import 'package:opshub/features/auth/domain/entities/user_entity.dart';
import 'package:opshub/features/task/domain/entities/task_entity.dart';
import 'package:opshub/features/task/presentation/widgets/task_preview_sheet.dart';

/// The 2026-08-01 redesign: "the answer first" — a plain-language situation
/// sentence stating state + consequence, read before any field grid. These
/// mirror the task-card decider tests (`task_card_layout_test.dart`) for the
/// sheet surface, since both read the same `TaskEntity` fields.
void main() {
  const approver = UserEntity(
    uid: 'approver1',
    email: 'approver@drop.com',
    authProvider: 'password',
    displayName: 'Approver Amy',
  );
  const creator = UserEntity(
    uid: 'creator1',
    email: 'creator@drop.com',
    authProvider: 'password',
    displayName: 'Creator Carl',
  );
  const directory = {'approver1': approver, 'creator1': creator};

  Future<void> openSheet(WidgetTester tester, TaskEntity task) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => showTaskPreviewSheet(
                  context,
                  task: task,
                  directory: directory,
                  branchName: 'Arkan',
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets(
    'states the outcome before the field grid: approved and finished late',
    (tester) async {
      final task = TaskEntity(
        id: 't1',
        title: 'Close the register',
        status: TaskStatus.approved,
        createdBy: 'creator1',
        approvedBy: 'approver1',
        deadline: DateTime(2026, 8, 1, 18),
        submittedAt: DateTime(2026, 8, 1, 18, 1),
      );

      await openSheet(tester, task);

      expect(
        find.textContaining('Approved by Approver Amy · 1m late'),
        findsOneWidget,
      );
      expect(find.text('Open full details'), findsOneWidget);
    },
  );

  testWidgets(
    'a missed task explains the closure and never falls back to the creator',
    (tester) async {
      final task = TaskEntity(
        id: 't2',
        title: 'Open the shop',
        status: TaskStatus.missed,
        createdBy: 'creator1',
        deadline: DateTime.now().subtract(const Duration(hours: 21)),
      );

      await openSheet(tester, task);

      expect(find.textContaining('closed automatically'), findsOneWidget);
      expect(find.textContaining('Creator Carl'), findsNothing);
    },
  );

  testWidgets('a clean on-time approval carries no lateness note', (
    tester,
  ) async {
    final task = TaskEntity(
      id: 't3',
      title: 'Restock shelves',
      status: TaskStatus.approved,
      approvedBy: 'approver1',
      deadline: DateTime(2026, 8, 1, 18),
      submittedAt: DateTime(2026, 8, 1, 17, 30),
    );

    await openSheet(tester, task);

    expect(find.text('Approved by Approver Amy'), findsOneWidget);
    expect(find.textContaining('late'), findsNothing);
  });
}
