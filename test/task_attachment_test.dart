import 'package:flutter_test/flutter_test.dart';
import 'package:opshub/core/enums/attachment_type.dart';
import 'package:opshub/core/enums/task_status.dart';
import 'package:opshub/features/task/data/models/task_model.dart';
import 'package:opshub/features/task/domain/entities/activity_entry.dart';
import 'package:opshub/features/task/domain/entities/task_attachment.dart';
import 'package:opshub/features/task/domain/entities/task_entity.dart';
import 'package:opshub/features/task/presentation/attachment_format.dart';

ActivityEntry _event(
  String status, {
  List<TaskAttachment> attachments = const [],
}) =>
    ActivityEntry(
      status: status,
      actorId: 'u1',
      actorName: 'Ziad',
      at: DateTime(2026, 6, 20, 16, 32),
      attachments: attachments,
    );

TaskAttachment _img(String url) => TaskAttachment(
      id: url,
      url: url,
      type: AttachmentType.image,
      uploadedAt: DateTime(2026, 6, 20, 16, 32),
      uploadedBy: 'u1',
      uploadedByName: 'Ziad',
    );

TaskAttachment _vid(String url) => TaskAttachment(
      id: url,
      url: url,
      type: AttachmentType.video,
      uploadedAt: DateTime(2026, 6, 20, 16, 32),
      uploadedBy: 'u1',
      uploadedByName: 'Ziad',
    );

void main() {
  group('TaskModel attachment serialization', () {
    test('event attachments survive a toMap → fromMap round-trip', () {
      final model = TaskModel(
        id: 't1',
        title: 'Clean fridge',
        activityLog: [
          _event('completed', attachments: [_img('a.jpg'), _vid('b.mp4')]),
        ],
      );

      final restored = TaskModel.fromMap(model.toMap(), id: 't1');
      final media = restored.activityLog.single.attachments;

      expect(media, hasLength(2));
      expect(media[0].url, 'a.jpg');
      expect(media[0].type, AttachmentType.image);
      expect(media[1].type, AttachmentType.video);
      expect(media[0].uploadedByName, 'Ziad');
    });

    test('an old activity entry with no attachments decodes to an empty list',
        () {
      final restored = TaskModel.fromMap({
        'title': 'Legacy',
        'activityLog': [
          {'status': 'waitingReview', 'actorId': 'u1', 'at': null},
        ],
      }, id: 't1');
      // Entry has a null timestamp → skipped; the point is no crash + no media.
      expect(restored.activityLog.every((e) => e.attachments.isEmpty), isTrue);
    });
  });

  group('attachmentsForEvent', () {
    test('returns the event\'s own media when present', () {
      final entry = _event('completed', attachments: [_img('x.jpg')]);
      final task = TaskEntity(id: 't', title: 'T', activityLog: [entry]);
      expect(attachmentsForEvent(entry, task), hasLength(1));
    });

    test('synthesizes a legacy proof image on the submission event', () {
      final entry = _event('waitingReview');
      final task = TaskEntity(
        id: 't',
        title: 'T',
        status: TaskStatus.waitingReview,
        proofImageUrl: 'legacy.jpg',
        activityLog: [entry],
      );
      final media = attachmentsForEvent(entry, task);
      expect(media, hasLength(1));
      expect(media.first.url, 'legacy.jpg');
      expect(media.first.type, AttachmentType.image);
    });

    test('never double-shows legacy proof when an event already has media', () {
      final completed = _event('completed', attachments: [_img('real.jpg')]);
      final review = _event('waitingReview');
      final task = TaskEntity(
        id: 't',
        title: 'T',
        proofImageUrl: 'real.jpg', // mirror of the first image
        activityLog: [completed, review],
      );
      // The submission event carries the real media…
      expect(attachmentsForEvent(completed, task), hasLength(1));
      // …and the waitingReview event does NOT re-synthesize the proof.
      expect(attachmentsForEvent(review, task), isEmpty);
    });
  });

  group('latestAttachments', () {
    test('returns the newest event that carries media', () {
      final task = TaskEntity(id: 't', title: 'T', activityLog: [
        _event('completed', attachments: [_img('old.jpg')]),
        _event('completed', attachments: [_img('new.jpg'), _vid('new.mp4')]),
      ]);
      final media = latestAttachments(task);
      expect(media, hasLength(2));
      expect(media.first.url, 'new.jpg');
    });

    test('falls back to the legacy proof image', () {
      final task = TaskEntity(id: 't', title: 'T', proofImageUrl: 'p.jpg');
      expect(latestAttachments(task).single.url, 'p.jpg');
    });
  });

  group('attachmentSummary', () {
    test('counts photos and videos', () {
      expect(attachmentSummary([_img('a'), _img('b'), _vid('c')]),
          '2 photos · 1 video');
      expect(attachmentSummary([_img('a')]), '1 photo');
      expect(attachmentSummary([_vid('a')]), '1 video');
    });
  });

  group('attachmentTimestamp', () {
    test('formats as "20 Jun 2026 • 4:32 PM"', () {
      expect(attachmentTimestamp(DateTime(2026, 6, 20, 16, 32)),
          '20 Jun 2026 • 4:32 PM');
      expect(attachmentTimestamp(DateTime(2026, 1, 5, 0, 5)),
          '5 Jan 2026 • 12:05 AM');
    });
  });
}
