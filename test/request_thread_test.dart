import 'package:flutter_test/flutter_test.dart';
import 'package:opshub/core/enums/attachment_type.dart';
import 'package:opshub/core/enums/request_type.dart';
import 'package:opshub/features/requests/domain/entities/request_entity.dart';
import 'package:opshub/features/requests/domain/entities/request_event.dart';
import 'package:opshub/features/requests/domain/request_thread.dart';
import 'package:opshub/features/task/domain/entities/task_attachment.dart';

void main() {
  final created = DateTime(2026, 7, 7, 9);

  RequestEntity request({List<TaskAttachment> attachments = const []}) =>
      RequestEntity(
        id: 'req1',
        type: RequestType.maintenance,
        requesterId: 'u1',
        requesterName: 'Sara',
        details: const {'message': 'Lock jammed'},
        attachments: attachments,
        createdAt: created,
      );

  RequestEvent comment(String id, {required DateTime at}) => RequestEvent(
        id: id,
        authorId: 'mgr',
        kind: RequestEventKind.comment,
        text: 'looking into it',
        createdAt: at,
      );

  group('requestThread', () {
    test('synthesizes a submitted opening when none is present', () {
      final events = [comment('c1', at: DateTime(2026, 7, 7, 10))];
      final thread = requestThread(events, request());
      expect(thread.first.id, kSyntheticSubmittedId);
      expect(thread.first.kind, RequestEventKind.submitted);
      expect(thread.first.actor, RequestEventActor.requester);
      // summary = the message the requester wrote.
      expect(thread.first.text, 'Lock jammed');
      expect(thread.length, 2);
    });

    test('carries the opening attachments into the synthesized event', () {
      final att = TaskAttachment(
        id: 'a1',
        url: 'https://x/a.jpg',
        type: AttachmentType.image,
        uploadedAt: created,
        uploadedBy: 'u1',
      );
      final thread = requestThread(const [], request(attachments: [att]));
      expect(thread.single.attachments.single.id, 'a1');
    });

    test('does NOT synthesize when a real submitted event exists', () {
      final real = RequestEvent(
        id: 'server-open',
        kind: RequestEventKind.submitted,
        text: 'Lock jammed',
        createdAt: created,
      );
      final thread = requestThread([real], request());
      expect(thread.every((e) => e.id != kSyntheticSubmittedId), isTrue);
      expect(thread.length, 1);
    });
  });
}
