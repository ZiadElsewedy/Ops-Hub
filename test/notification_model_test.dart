import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drop/core/enums/notification_type.dart';
import 'package:drop/features/notifications/data/models/notification_model.dart';
import 'package:drop/features/notifications/domain/entities/notification_entity.dart';

/// Verifies the notification model (Notification System Phase 1 — Part 1)
/// serializes/deserializes cleanly, including the typed payload reads.
void main() {
  group('NotificationModel serialization', () {
    test('toMap writes the type name + payload (createdAt is server-side)', () {
      final map = NotificationModel.fromEntity(NotificationEntity(
        id: 'n1',
        recipientUid: 'u1',
        senderUid: 'mgr',
        type: NotificationType.taskRework,
        title: 'Task Needs Rework',
        body: 'Missing stock photo',
        createdAt: DateTime(2026, 6, 22),
        payload: const {
          'taskId': 't1',
          'revisionNumber': 2,
          'route': 'task_details',
        },
      )).toMap();

      expect(map['type'], 'taskRework');
      expect(map['recipientUid'], 'u1');
      expect(map['senderUid'], 'mgr');
      expect((map['payload'] as Map)['taskId'], 't1');
      expect((map['payload'] as Map)['revisionNumber'], 2);
      // createdAt is written by the datasource as a server timestamp.
      expect(map.containsKey('createdAt'), false);
    });

    test('fromMap reads type, timestamps and payload', () {
      final m = NotificationModel.fromMap({
        'recipientUid': 'u1',
        'type': 'broadcastEmergency',
        'title': 'Evacuate',
        'body': 'Leave now',
        'createdAt': Timestamp.fromDate(DateTime(2026, 6, 22, 8, 30)),
        'readAt': null,
        'payload': const {
          'broadcastId': 'b1',
          'category': 'emergency',
          'priority': 'high',
          'route': 'broadcast_detail',
        },
      }, id: 'n9');

      expect(m.id, 'n9');
      expect(m.type, NotificationType.broadcastEmergency);
      expect(m.readAt, isNull);
      final e = m.toEntity();
      expect(e.broadcastId, 'b1');
      expect(e.category, 'emergency');
      expect(e.route, 'broadcast_detail');
      expect(e.isUnread, true);
    });

    test('typed payload getters on the entity', () {
      final e = NotificationEntity(
        id: 'n1',
        recipientUid: 'u1',
        type: NotificationType.taskRework,
        title: 'x',
        body: 'y',
        createdAt: DateTime(2026),
        payload: const {
          'taskId': 't1',
          'revisionNumber': 3,
          'route': 'task_details',
        },
      );
      expect(e.taskId, 't1');
      expect(e.revisionNumber, 3);
      expect(e.route, 'task_details');
      expect(e.broadcastId, isNull);
    });

    test('an unknown type lands as `unknown`, never as a real type', () {
      // This test previously asserted the fallback was `taskAssigned`, which is
      // what SHIPPED the branch-sales defect: `type` drives the glyph, the
      // category pill and the priority ordering, so "degrade to a known type"
      // meant every unrecognised notification arrived wearing a clipboard,
      // filed under Tasks, ranked `high` above genuinely overdue work.
      // Degrading gracefully means not throwing — it does not mean claiming to
      // be something else.
      final m = NotificationModel.fromMap(const {
        'recipientUid': 'u1',
        'type': 'somethingNew',
        'title': 'x',
        'body': 'y',
      });
      expect(m.type, NotificationType.unknown);
    });

    test('a missing type also lands as `unknown`', () {
      final m = NotificationModel.fromMap(const {
        'recipientUid': 'u1',
        'title': 'x',
        'body': 'y',
      });
      expect(m.type, NotificationType.unknown);
    });

    test('an unknown type still deep-links — routing keys off `route`', () {
      // The reason `unknown` is safe to ship: navigation never consulted `type`
      // in the first place. A notification from a newer server build still
      // opens the right screen; it just stops impersonating a task on the way.
      final m = NotificationModel.fromMap(const {
        'recipientUid': 'u1',
        'type': 'somethingTheServerAddedLater',
        'title': 'x',
        'body': 'y',
        'payload': {'route': 'task_details', 'taskId': 't9'},
      });
      expect(m.type, NotificationType.unknown);
      expect(m.toEntity().route, 'task_details');
      expect(m.toEntity().taskId, 't9');
    });

    test('a sales notification parses as itself, not as the task fallback', () {
      // `writeSalesNotifications` (functions/index.js) stamps exactly this
      // string. While the enum lacked the value, all five sales events took the
      // `taskAssigned` fallback above and impersonated a task in the inbox.
      final m = NotificationModel.fromMap(const {
        'recipientUid': 'u1',
        'type': 'salesSubmission',
        'title': 'Sales target updated',
        'body': 'Your branch monthly sales target was updated.',
        'payload': {'route': 'sales_target', 'monthKey': '202608'},
      });
      expect(m.type, NotificationType.salesSubmission);
      expect(m.toEntity().route, 'sales_target');
    });

    test('archivedAt / pinnedAt round-trip + getters (Phase 2)', () {
      final at = DateTime(2026, 6, 22, 10);
      final map = NotificationModel.fromEntity(NotificationEntity(
        id: 'n1',
        recipientUid: 'u1',
        type: NotificationType.taskAssigned,
        title: 'x',
        body: 'y',
        createdAt: at,
        archivedAt: at,
        pinnedAt: at,
      )).toMap();

      expect(map['archivedAt'], isA<Timestamp>());
      expect(map['pinnedAt'], isA<Timestamp>());

      final e = NotificationModel.fromMap({
        'recipientUid': 'u1',
        'type': 'taskAssigned',
        'title': 'x',
        'body': 'y',
        'createdAt': Timestamp.fromDate(at),
        'archivedAt': Timestamp.fromDate(at),
        'pinnedAt': Timestamp.fromDate(at),
      }).toEntity();
      expect(e.isArchived, isTrue);
      expect(e.isPinned, isTrue);

      // Legacy doc → neither archived nor pinned.
      final legacy = NotificationModel.fromMap(const {
        'recipientUid': 'u1',
        'type': 'taskAssigned',
        'title': 'x',
        'body': 'y',
      }).toEntity();
      expect(legacy.isArchived, isFalse);
      expect(legacy.isPinned, isFalse);
    });

    test('NotificationType.fromBroadcastCategory maps categories', () {
      expect(NotificationType.fromBroadcastCategory('reminder'),
          NotificationType.broadcastReminder);
      expect(NotificationType.fromBroadcastCategory('emergency'),
          NotificationType.broadcastEmergency);
      expect(NotificationType.fromBroadcastCategory('announcement'),
          NotificationType.broadcastAnnouncement);
      expect(NotificationType.fromBroadcastCategory('???'),
          NotificationType.broadcastAnnouncement);
    });
  });
}
