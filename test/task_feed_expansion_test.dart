import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opshub/core/enums/attachment_type.dart';
import 'package:opshub/core/enums/task_assignment_type.dart';
import 'package:opshub/core/enums/task_status.dart';
import 'package:opshub/features/task/domain/entities/activity_entry.dart';
import 'package:opshub/features/task/domain/entities/checklist_item.dart';
import 'package:opshub/features/task/domain/entities/task_attachment.dart';
import 'package:opshub/features/task/domain/entities/task_entity.dart';
import 'package:opshub/features/task/presentation/widgets/task_feed_expansion.dart';

/// The shared R1 triage surface. Rendering only (actions read the cubit lazily
/// on tap, so no provider is needed to render).
void main() {
  Widget host(Widget child) => MaterialApp(
    home: Scaffold(
      body: SingleChildScrollView(child: SizedBox(width: 520, child: child)),
    ),
  );

  testWidgets('waitingReview → Approve, Reject, Reassign, Open full details', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        TaskFeedExpansion(
          task: const TaskEntity(
            id: '1',
            title: 't',
            description: 'Unlock and count the till',
            status: TaskStatus.waitingReview,
            assigneeIds: ['u1'],
          ),
          directory: const {},
          onOpenDetails: () {},
        ),
      ),
    );

    expect(find.text('Unlock and count the till'), findsOneWidget);
    expect(find.text('Approve'), findsOneWidget);
    expect(find.text('Reject'), findsOneWidget);
    expect(find.text('Reassign'), findsOneWidget);
    expect(find.text('Note'), findsOneWidget);
    expect(find.text('Open full details'), findsOneWidget);
  });

  testWidgets('showActions: false omits the action row (for a pinned footer)', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        const TaskFeedExpansion(
          task: TaskEntity(
            id: '1',
            title: 't',
            description: 'body still renders',
            status: TaskStatus.waitingReview,
          ),
          directory: {},
          onOpenDetails: _noop,
          showActions: false,
        ),
      ),
    );
    expect(find.text('body still renders'), findsOneWidget);
    expect(find.text('Approve'), findsNothing);
    expect(find.text('Open full details'), findsNothing);
  });

  testWidgets('TaskFeedActions renders standalone (mobile sticky footer)', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        TaskFeedActions(
          task: const TaskEntity(
            id: '1',
            title: 't',
            status: TaskStatus.waitingReview,
          ),
          onOpenDetails: () {},
        ),
      ),
    );
    expect(find.text('Approve'), findsOneWidget);
    expect(find.text('Note'), findsOneWidget);
  });

  testWidgets('a pending task shows Reassign but not Approve/Reject', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        const TaskFeedExpansion(
          task: TaskEntity(id: '1', title: 't', assigneeIds: ['u1']),
          directory: {},
          onOpenDetails: _noop,
        ),
      ),
    );
    expect(find.text('Approve'), findsNothing);
    expect(find.text('Reject'), findsNothing);
    expect(find.text('Reassign'), findsOneWidget);
    expect(find.text('Open full details'), findsOneWidget);
  });

  testWidgets('a missed task is read-only in the quick-action surface', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        const TaskFeedExpansion(
          task: TaskEntity(
            id: '1',
            title: 'Opening routine',
            status: TaskStatus.missed,
            assigneeIds: ['u1'],
          ),
          directory: {},
          onOpenDetails: _noop,
        ),
      ),
    );

    expect(find.text('Approve'), findsNothing);
    expect(find.text('Reject'), findsNothing);
    expect(find.text('Reassign'), findsNothing);
    expect(find.text('Note'), findsNothing);
    expect(find.text('Open full details'), findsOneWidget);
  });

  testWidgets('a shift task hides Reassign (targets a shift, not a person)', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        const TaskFeedExpansion(
          task: TaskEntity(
            id: '1',
            title: 't',
            assignmentType: TaskAssignmentType.shift,
          ),
          directory: {},
          onOpenDetails: _noop,
        ),
      ),
    );
    expect(find.text('Reassign'), findsNothing);
    expect(find.text('Open full details'), findsOneWidget);
  });

  testWidgets('renders checklist preview + progress', (tester) async {
    await tester.pumpWidget(
      host(
        const TaskFeedExpansion(
          task: TaskEntity(
            id: '1',
            title: 't',
            checklist: [
              ChecklistItem(id: 'a', title: 'Unlock door', completed: true),
              ChecklistItem(id: 'b', title: 'Lights on'),
            ],
          ),
          directory: {},
          onOpenDetails: _noop,
        ),
      ),
    );
    expect(find.text('Checklist'), findsOneWidget);
    expect(find.text('1 of 2'), findsOneWidget);
    expect(find.text('Unlock door'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
  });

  testWidgets('renders the status timeline newest-first', (tester) async {
    await tester.pumpWidget(
      host(
        TaskFeedExpansion(
          task: TaskEntity(
            id: '1',
            title: 't',
            activityLog: [
              ActivityEntry(
                status: 'started',
                actorId: 'u1',
                actorName: 'Ziad',
                at: DateTime(2026, 7, 1),
              ),
            ],
          ),
          directory: const {},
          onOpenDetails: () {},
        ),
      ),
    );
    expect(find.text('TIMELINE'), findsOneWidget);
    expect(find.textContaining('Ziad'), findsOneWidget);
  });

  testWidgets('shows an attachment thumbnail (video → play glyph)', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        TaskFeedExpansion(
          task: TaskEntity(
            id: '1',
            title: 't',
            activityLog: [
              ActivityEntry(
                status: 'waitingReview',
                actorId: 'u1',
                at: DateTime(2026, 7, 1),
                attachments: [
                  TaskAttachment(
                    id: 'v1',
                    url: 'https://example.com/v.mp4',
                    type: AttachmentType.video,
                    uploadedAt: DateTime(2026, 7, 1),
                    uploadedBy: 'u1',
                  ),
                ],
              ),
            ],
          ),
          directory: const {},
          onOpenDetails: () {},
        ),
      ),
    );
    expect(find.text('ATTACHMENTS'), findsOneWidget);
    expect(find.byIcon(Icons.play_circle_outline_rounded), findsOneWidget);
  });
}

void _noop() {}
