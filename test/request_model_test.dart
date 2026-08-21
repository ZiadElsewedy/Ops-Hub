import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opshub/core/enums/attachment_type.dart';
import 'package:opshub/core/enums/request_status.dart';
import 'package:opshub/core/enums/request_type.dart';
import 'package:opshub/core/enums/user_role.dart';
import 'package:opshub/features/requests/data/models/request_model.dart';
import 'package:opshub/features/requests/domain/entities/request_entity.dart';
import 'package:opshub/features/requests/domain/entities/request_event.dart';
import 'package:opshub/features/task/domain/entities/task_attachment.dart';

void main() {
  group('RequestModel serialization', () {
    test('entity → model → map preserves the core fields + enums', () {
      final entity = RequestEntity(
        id: 'r1',
        branchId: 'b1',
        type: RequestType.stockRequest,
        status: RequestStatus.pending,
        requesterId: 'u1',
        requesterName: 'Sara',
        requesterRole: UserRole.employee,
        details: const {'message': 'Need 3 boxes of Air Max'},
      );

      final map = RequestModel.fromEntity(entity).toMap();
      expect(map['type'], 'stockRequest');
      expect(map['status'], 'pending');
      expect(map['requesterId'], 'u1');
      expect(map['requesterRole'], 'employee');
      expect((map['details'] as Map)['message'], 'Need 3 boxes of Air Max');
    });

    test('fromMap restores enums and defaults leniently', () {
      final model = RequestModel.fromMap({
        'type': 'unknownType',
        'status': 'garbage',
        'requesterId': 'u9',
      }, id: 'r2');
      expect(model.type, RequestType.other);
      expect(model.status, RequestStatus.pending);
      expect(model.id, 'r2');
    });

    test('entity exposes the message + summary from details', () {
      final entity = RequestEntity(
        id: 'r1',
        type: RequestType.leaveStore,
        requesterId: 'u1',
        details: const {'message': 'Step out for lunch'},
      );
      expect(entity.message, 'Step out for lunch');
      expect(entity.summary, 'Step out for lunch');

      final empty = RequestEntity(
        id: 'r2',
        type: RequestType.leaveStore,
        requesterId: 'u1',
      );
      expect(empty.message, isEmpty);
      expect(empty.summary, RequestType.leaveStore.label);
    });

    test('details normalize Timestamp → DateTime on read', () {
      final ts = Timestamp.fromDate(DateTime(2026, 7, 7, 16, 30));
      final model = RequestModel.fromMap({
        'type': 'leaveStore',
        'requesterId': 'u1',
        'details': {'message': 'lunch', 'when': ts},
      }, id: 'r3');
      expect(model.details['when'], isA<DateTime>());
      expect((model.details['when'] as DateTime).hour, 16);
    });

    test('details normalize DateTime → Timestamp on write', () {
      final model = RequestModel(
        id: 'r4',
        type: RequestType.leaveStore,
        requesterId: 'u1',
        details: {'when': DateTime(2026, 7, 7, 16, 30)},
      );
      final map = model.toMap();
      expect((map['details'] as Map)['when'], isA<Timestamp>());
    });

    test('attachments round-trip through the embedded (de)serializer', () {
      final model = RequestModel(
        id: 'r5',
        type: RequestType.maintenance,
        requesterId: 'u1',
        attachments: [
          TaskAttachment(
            id: 'a1',
            url: 'https://x/a.jpg',
            type: AttachmentType.image,
            uploadedAt: DateTime(2026, 7, 7),
            uploadedBy: 'u1',
          ),
        ],
      );
      final restored =
          RequestModel.fromMap(model.toMap(), id: 'r5').attachments.single;
      expect(restored.id, 'a1');
      expect(restored.type, AttachmentType.image);
    });

    test('deletedAt marks a soft-deleted request', () {
      final live = RequestModel.fromMap({
        'type': 'other',
        'requesterId': 'u1',
      }, id: 'r6');
      expect(live.deletedAt, isNull);
      expect(live.toEntity().isDeleted, isFalse);

      final gone = RequestModel.fromMap({
        'type': 'other',
        'requesterId': 'u1',
        'deletedAt': Timestamp.fromDate(DateTime(2026, 7, 8)),
      }, id: 'r7');
      expect(gone.deletedAt, isNotNull);
      expect(gone.toEntity().isDeleted, isTrue);
    });

    test('reopened event kind parses (server-written)', () {
      expect(RequestEventKind.fromString('reopened'),
          RequestEventKind.reopened);
      expect(RequestEventKind.reopened.isSystem, isTrue);
    });

    test('event round-trips kind + actor', () {
      final event = RequestEvent(
        id: 'e1',
        authorId: 'mgr',
        authorName: 'Boss',
        actor: RequestEventActor.approver,
        kind: RequestEventKind.comment,
        text: 'please return by 4pm',
        createdAt: DateTime(2026, 7, 7),
      );
      final restored =
          RequestModel.eventFromMap(RequestModel.eventToMap(event), id: 'e1');
      expect(restored.kind, RequestEventKind.comment);
      expect(restored.actor, RequestEventActor.approver);
      expect(restored.text, 'please return by 4pm');
    });
  });
}
