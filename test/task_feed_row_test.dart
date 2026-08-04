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
    // Branch, assignee and checklist share ONE meta line so it can ellipsize
    // from its tail; they are no longer separate chips competing for width.
    expect(find.textContaining('Arkan'), findsOneWidget);
    expect(find.text('28 Jun'), findsOneWidget);
  });

  testWidgets('the title is on its own line and only the date sits beside it', (
    tester,
  ) async {
    // The row exists so a manager can read *what the work is*. On a phone the
    // old single-line layout let the branch chip, the avatar and the date all
    // take width from the title, so the title was the first thing to truncate.
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 360,
            child: TaskFeedRow(
              task: TaskEntity(
                id: '1',
                title: 'Check the walk-in fridge temperature log',
                status: TaskStatus.pending,
                deadline: DateTime(2099, 6, 28),
              ),
              branchName: 'Arkan New Cairo',
              directory: const {
                'u1': UserEntity(
                  uid: 'u1',
                  email: 'z@x.co',
                  authProvider: 'password',
                  displayName: 'Ziad Elsewedy',
                ),
              },
            ),
          ),
        ),
      ),
    );

    final title = tester.getRect(
      find.text('Check the walk-in fridge temperature log'),
    );
    final meta = tester.getRect(find.textContaining('Arkan New Cairo'));
    // Two lines, not one: the meta sits strictly below the title.
    expect(meta.top, greaterThan(title.bottom - 1));
    // …and the title keeps most of the row's width for itself.
    expect(title.width, greaterThan(240));
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

  testWidgets('a record is dated by when it closed, not by its deadline', (
    tester,
  ) async {
    // Under a section headed "Closed today", every row must show the date that
    // section just promised. Showing the deadline instead put `4:30 PM` next to
    // `5 Aug` in the same section — two clocks, neither of them the section's.
    await tester.pumpWidget(
      host(
        TaskFeedRow(
          task: TaskEntity(
            id: '1',
            title: 'Closing checks',
            status: TaskStatus.approved,
            deadline: DateTime(2020, 1, 1),
            approvedAt: DateTime(2024, 3, 9, 16, 30),
          ),
        ),
      ),
    );

    expect(find.text('9 Mar'), findsOneWidget);
    expect(find.text('1 Jan'), findsNothing);
  });

  testWidgets('there is no per-row chevron', (tester) async {
    // Thirty rows meant thirty identical glyphs restating what the tappable row
    // already says, each one taking width from the title.
    await tester.pumpWidget(
      host(const TaskFeedRow(task: TaskEntity(id: '1', title: 't'))),
    );
    expect(find.byIcon(Icons.chevron_right_rounded), findsNothing);
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

  testWidgets('names the assignee on the meta line', (tester) async {
    // The row used to show initials in a 22px avatar disc, because on the old
    // single-line layout a name was a fixed-width space hog. On its own meta
    // line the name fits, and a name is what someone scanning for one person's
    // work is actually reading — initials make them decode every row.
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
    expect(find.textContaining('Ziad'), findsOneWidget);
    // No avatar disc: in a branch- or person-scoped list every row carried the
    // same face, which is chrome, not information.
    expect(find.byType(UserAvatar), findsNothing);
  });

  testWidgets('a person-scoped list can drop the repeated assignee', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        TaskFeedRow(
          task: const TaskEntity(id: '1', title: 't', assigneeIds: ['u1']),
          showAssignee: false,
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
    expect(find.textContaining('Ziad'), findsNothing);
  });

  testWidgets('an unassigned task says so rather than showing a placeholder', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(const TaskFeedRow(task: TaskEntity(id: '1', title: 't'))),
    );
    expect(find.textContaining('Unassigned'), findsOneWidget);
  });

  testWidgets('survives a small phone with every field at its longest', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 320,
            child: TaskFeedRow(
              task: TaskEntity(
                id: '1',
                title:
                    'Verify the cold chain log for every unit in the back room',
                status: TaskStatus.waitingReview,
                deadline: DateTime(2020, 1, 1),
                assigneeIds: const ['u1'],
                checklist: const [
                  ChecklistItem(id: 'a', title: 'one', completed: true),
                  ChecklistItem(id: 'b', title: 'two'),
                ],
              ),
              branchName: 'Arkan Plaza — New Cairo Fifth Settlement',
              directory: const {
                'u1': UserEntity(
                  uid: 'u1',
                  email: 'z@x.co',
                  authProvider: 'password',
                  displayName: 'Abdelrahman Mohamed Elsewedy',
                ),
              },
            ),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
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

  testWidgets('checklist progress is stated, not drawn as a 2px track', (
    tester,
  ) async {
    // A 2px bar at 50% under a dense row is nearly invisible and only ever
    // conveys "roughly". The same space in the meta line carries the exact
    // figure — and removes a whole visual layer from the row.
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
    expect(find.textContaining('1/2 steps'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsNothing);
  });
}
