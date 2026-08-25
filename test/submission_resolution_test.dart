import 'package:flutter_test/flutter_test.dart';
import 'package:opshub/core/enums/attachment_type.dart';
import 'package:opshub/core/enums/task_status.dart';
import 'package:opshub/features/task/domain/entities/activity_entry.dart';
import 'package:opshub/features/task/domain/entities/task_attachment.dart';
import 'package:opshub/features/task/domain/entities/task_entity.dart';
import 'package:opshub/features/task/presentation/attachment_format.dart';

TaskAttachment _img(String url) => TaskAttachment(
      id: url,
      url: url,
      type: AttachmentType.image,
      uploadedAt: DateTime(2026, 6, 21),
      uploadedBy: 'u1',
    );

ActivityEntry _e(String status,
        {String? note, List<TaskAttachment> attachments = const []}) =>
    ActivityEntry(
      status: status,
      actorId: 'u1',
      actorName: 'Ziad',
      at: DateTime(2026, 6, 21),
      note: note,
      attachments: attachments,
    );

void main() {
  group('resolveSubmission', () {
    test('tapping "Submitted for review" resolves the cycle\'s completed event',
        () {
      final task = TaskEntity(
        id: 't',
        title: 'T',
        status: TaskStatus.waitingReview,
        activityLog: [
          _e('pending'),
          _e('started'),
          _e('completed', note: 'done', attachments: [_img('a.jpg')]),
          _e('waitingReview'),
        ],
      );
      // index 3 = waitingReview → should walk back to the completed event.
      final s = resolveSubmission(task, 3);
      expect(s.content.status, 'completed');
      expect(s.content.note, 'done');
      expect(s.attachments, hasLength(1));
      expect(s.feedback, isNull);
      expect(s.awaiting, isTrue); // task is waitingReview, no decision yet
    });

    test('feedback resolves to the decision that followed the submission', () {
      final task = TaskEntity(
        id: 't',
        title: 'T',
        status: TaskStatus.approved,
        activityLog: [
          _e('completed', note: 'v1', attachments: [_img('a.jpg')]),
          _e('waitingReview'),
          _e('approved', note: 'looks good'),
        ],
      );
      final s = resolveSubmission(task, 0);
      expect(s.feedback?.status, 'approved');
      expect(s.feedback?.note, 'looks good');
      expect(s.awaiting, isFalse);
    });

    test('each rework cycle resolves to its own content + feedback', () {
      final task = TaskEntity(
        id: 't',
        title: 'T',
        status: TaskStatus.waitingReview,
        activityLog: [
          _e('completed', note: 'first try', attachments: [_img('1.jpg')]), // 0
          _e('waitingReview'), // 1
          _e('rejected', note: 'redo the shelves'), // 2
          _e('started'), // 3
          _e('completed', note: 'second try', attachments: [_img('2.jpg')]), // 4
          _e('waitingReview'), // 5
        ],
      );

      // First cycle → its rejection feedback, not awaiting.
      final first = resolveSubmission(task, 0);
      expect(first.content.note, 'first try');
      expect(first.feedback?.status, 'rejected');
      expect(first.feedback?.note, 'redo the shelves');
      expect(first.awaiting, isFalse);

      // Second cycle (tap its waitingReview at index 5) → no feedback, awaiting.
      final second = resolveSubmission(task, 5);
      expect(second.content.note, 'second try');
      expect(second.attachments.first.url, '2.jpg');
      expect(second.feedback, isNull);
      expect(second.awaiting, isTrue);
    });
  });
}
