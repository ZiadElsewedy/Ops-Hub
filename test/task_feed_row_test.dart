import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drop/core/enums/task_status.dart';
import 'package:drop/core/widgets/user_avatar.dart';
import 'package:drop/features/auth/domain/entities/user_entity.dart';
import 'package:drop/features/task/domain/entities/checklist_item.dart';
import 'package:drop/features/task/domain/entities/task_entity.dart';
import 'package:drop/features/task/presentation/widgets/task_feed_row.dart';

void main() {
  Widget host(Widget child) => MaterialApp(
    home: Scaffold(body: SizedBox(width: 1000, child: child)),
  );

  testWidgets('renders status label, title, branch and due', (tester) async {
    await tester.pumpWidget(
      host(
        TaskFeedRow(
          task: TaskEntity(
            id: '1',
            title: 'Open the shop',
            status: TaskStatus.started,
            deadline: DateTime(
              2099,
              6,
              28,
            ), // future → not overdue, plain label
          ),
          branchName: 'Arkan',
        ),
      ),
    );

    expect(find.text('Open the shop'), findsOneWidget);
    expect(find.text('In progress'), findsOneWidget);
    expect(find.text('Arkan'), findsOneWidget);
    expect(find.text('28 Jun'), findsOneWidget);
  });

  testWidgets('an overdue task marks the due label late', (tester) async {
    await tester.pumpWidget(
      host(
        TaskFeedRow(
          task: TaskEntity(
            id: '1',
            title: 'Late task',
            status: TaskStatus.started,
            deadline: DateTime(2020, 1, 1), // safely in the past
          ),
        ),
      ),
    );
    expect(find.text('1 Jan · late'), findsOneWidget);
  });

  testWidgets('a missed task has a semantic status and is not labelled late', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        TaskFeedRow(
          task: TaskEntity(
            id: '1',
            title: 'Unfinished opening',
            status: TaskStatus.missed,
            deadline: DateTime(2020, 1, 1),
          ),
        ),
      ),
    );

    expect(find.text('Missed'), findsOneWidget);
    expect(find.text('1 Jan · late'), findsNothing);
  });

  testWidgets('shows the single assignee as an avatar (no name text)',
      (tester) async {
    // The compact feed row shows the assignee's avatar only — the name text was
    // a fixed-width space hog that overflowed the row on a phone. The full name
    // lives in the task detail; here the avatar's initials identify them.
    await tester.pumpWidget(
      host(
        TaskFeedRow(
          task: const TaskEntity(id: '1', title: 't', assigneeIds: ['u1']),
          directory: const {
            'u1': UserEntity(
              uid: 'u1',
              email: 'z@x.co',
              authProvider: 'password',
              displayName: 'Ziad',
            ),
          },
        ),
      ),
    );
    // The name is no longer rendered as its own row text…
    expect(find.text('Ziad'), findsNothing);
    // …but the assignee avatar is present (initials from the display name).
    expect(find.byType(UserAvatar), findsOneWidget);
  });

  testWidgets('tapping fires onTap', (tester) async {
    var tapped = false;
    await tester.pumpWidget(
      host(
        TaskFeedRow(
          task: const TaskEntity(id: '1', title: 't'),
          onTap: () => tapped = true,
        ),
      ),
    );
    await tester.tap(find.byType(TaskFeedRow));
    expect(tapped, isTrue);
  });

  testWidgets('renders a checklist progress track when present', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        TaskFeedRow(
          task: const TaskEntity(
            id: '1',
            title: 't',
            checklist: [
              ChecklistItem(id: 'a', title: 'one', completed: true),
              ChecklistItem(id: 'b', title: 'two'),
            ],
          ),
        ),
      ),
    );
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
  });
}
