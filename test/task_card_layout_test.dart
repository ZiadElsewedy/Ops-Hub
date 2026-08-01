import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drop/core/enums/task_priority.dart';
import 'package:drop/core/enums/task_status.dart';
import 'package:drop/core/enums/user_role.dart';
import 'package:drop/core/theme/app_theme.dart';
import 'package:drop/core/widgets/app_motion.dart';
import 'package:drop/features/auth/domain/entities/user_entity.dart';
import 'package:drop/features/task/domain/entities/checklist_item.dart';
import 'package:drop/features/task/domain/entities/task_entity.dart';
import 'package:drop/features/task/presentation/widgets/task_card.dart';

/// Regression test for the Tasks screen crash: a [TaskCard] inside a scrolling
/// [ListView] (unbounded vertical constraints, exactly how the task screens use
/// it) must lay out without throwing a RenderBox/size assertion.
void main() {
  const user = UserEntity(
    uid: 'u1',
    email: 'ziad@drop.com',
    authProvider: 'password',
    displayName: 'Ziad Mohamed',
    role: UserRole.employee,
  );

  final task = TaskEntity(
    id: 't1',
    title: 'Inventory Audit',
    description: 'Check all inventory items and ensure quantities are accurate.',
    status: TaskStatus.started,
    priority: TaskPriority.high,
    assigneeIds: const ['u1'],
    deadline: DateTime(2026, 6, 18, 18),
    checklist: const [
      ChecklistItem(id: 'c1', title: 'Check shelf #1', completed: true),
      ChecklistItem(id: 'c2', title: 'Check shelf #2'),
      ChecklistItem(id: 'c3', title: 'Verify damaged items', isRequired: false),
    ],
  );

  testWidgets('TaskCard lays out inside a ListView without a layout assertion',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: Scaffold(
          body: ListView(
            children: [
              EntranceFade(
                child: TaskCard(
                  task: task,
                  directory: const {'u1': user},
                  branchName: 'Maadi Branch',
                ),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 400));

    expect(tester.takeException(), isNull);
    expect(find.text('Inventory Audit'), findsOneWidget);
  });

  // ── Footer decider fact (2026-08-01 delta: the "by X" fix) ────────────
  //
  // Was: the footer always named the task's CREATOR, so an Approved card
  // read "by Admin" as if Admin had approved it. Now it names whoever
  // actually decided the task, once it has been decided — and Missed, which
  // nobody decided, names nobody at all.
  group('footer names the decider, not the creator, once decided', () {
    const creator = UserEntity(
      uid: 'creator1',
      email: 'creator@drop.com',
      authProvider: 'password',
      displayName: 'Creator Carl',
      role: UserRole.manager,
    );
    const approver = UserEntity(
      uid: 'approver1',
      email: 'approver@drop.com',
      authProvider: 'password',
      displayName: 'Approver Amy',
      role: UserRole.admin,
    );
    const directory = {'creator1': creator, 'approver1': approver};

    Future<void> pump(WidgetTester tester, TaskEntity task) => tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: Scaffold(
          body: ListView(
            children: [TaskCard(task: task, directory: directory)],
          ),
        ),
      ),
    );

    testWidgets('an approved card names the approver, not the creator', (
      tester,
    ) async {
      await pump(
        tester,
        const TaskEntity(
          id: 't1',
          title: 'Close the register',
          status: TaskStatus.approved,
          createdBy: 'creator1',
          approvedBy: 'approver1',
        ),
      );

      expect(
        find.textContaining('Approved by Approver Amy', findRichText: true),
        findsOneWidget,
      );
      expect(
        find.textContaining('Creator Carl', findRichText: true),
        findsNothing,
      );
    });

    testWidgets(
      'a missed card names nobody, and never falls back to the creator',
      (tester) async {
        await pump(
          tester,
          const TaskEntity(
            id: 't1',
            title: 'Open the shop',
            status: TaskStatus.missed,
            createdBy: 'creator1',
          ),
        );

        expect(
          find.textContaining(
            'Missed — closed automatically',
            findRichText: true,
          ),
          findsOneWidget,
        );
        expect(
          find.textContaining('Creator Carl', findRichText: true),
          findsNothing,
        );
        expect(
          find.textContaining('by Creator Carl', findRichText: true),
          findsNothing,
        );
      },
    );

    testWidgets('a rejected card names the rejecter', (tester) async {
      await pump(
        tester,
        const TaskEntity(
          id: 't1',
          title: 'Restock shelves',
          status: TaskStatus.rejected,
          createdBy: 'creator1',
          rejectedBy: 'approver1',
        ),
      );

      expect(
        find.textContaining('Rejected by Approver Amy', findRichText: true),
        findsOneWidget,
      );
    });

    testWidgets(
      'an undecided card still credits the creator, unchanged',
      (tester) async {
        await pump(
          tester,
          const TaskEntity(
            id: 't1',
            title: 'Open the shop',
            status: TaskStatus.pending,
            createdBy: 'creator1',
          ),
        );

        expect(
          find.textContaining('by Creator Carl · Manager', findRichText: true),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'an approver uid missing from the directory degrades to "Admin", never a raw uid',
      (tester) async {
        await pump(
          tester,
          const TaskEntity(
            id: 't1',
            title: 'Close the register',
            status: TaskStatus.approved,
            approvedBy: 'ghost-uid-not-in-directory',
          ),
        );

        expect(
          find.textContaining('Approved by Admin', findRichText: true),
          findsOneWidget,
        );
        expect(
          find.textContaining(
            'ghost-uid-not-in-directory',
            findRichText: true,
          ),
          findsNothing,
        );
      },
    );
  });
}
