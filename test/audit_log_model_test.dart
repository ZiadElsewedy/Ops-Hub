import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opshub/core/enums/audit_entity_type.dart';
import 'package:opshub/core/enums/audit_event_type.dart';
import 'package:opshub/core/enums/user_role.dart';
import 'package:opshub/features/audit/data/models/audit_log_model.dart';
import 'package:opshub/features/audit/domain/entities/audit_log_entry.dart';

void main() {
  group('AuditLogModel serialization', () {
    test('toCreateMap carries the record + is born live, omits the timestamp',
        () {
      const model = AuditLogModel(
        id: '',
        eventType: AuditEventType.taskApproved,
        entityType: AuditEntityType.task,
        entityId: 'task-1',
        actorId: 'u-9',
        actorName: 'Ziad',
        actorRole: UserRole.manager,
        branchId: 'branch-A',
        metadata: {'priority': 'high'},
      );

      final map = model.toCreateMap();

      expect(map['eventType'], 'task.approved'); // the wire id, not the name
      expect(map['entityType'], 'task');
      expect(map['entityId'], 'task-1');
      expect(map['actorId'], 'u-9');
      expect(map['actorName'], 'Ziad');
      expect(map['actorRole'], 'manager');
      expect(map['branchId'], 'branch-A');
      expect(map['schemaVersion'], kAuditSchemaVersion);
      // A new record is always live; the delete fields are absent until deletion.
      expect(map['isDeleted'], false);
      expect(map.containsKey('deletedAt'), isFalse);
      // The trusted server clock stamps the time — never the client.
      expect(map.containsKey('timestamp'), isFalse);
      expect((map['metadata'] as Map)['priority'], 'high');
    });

    test('fromMap reads a persisted doc (Timestamp → DateTime)', () {
      final ts = Timestamp.fromDate(DateTime.utc(2026, 7, 10, 9, 30));
      final model = AuditLogModel.fromMap({
        'eventType': 'request.rejected',
        'entityType': 'request',
        'entityId': 'req-3',
        'actorId': 'admin-1',
        'actorName': 'Admin',
        'actorRole': 'admin',
        'branchId': 'branch-B',
        'timestamp': ts,
        'metadata': {'requestType': 'leave'},
        'schemaVersion': 1,
        'isDeleted': false,
      }, id: 'doc-1');

      expect(model.id, 'doc-1');
      expect(model.eventType, AuditEventType.requestRejected);
      expect(model.entityType, AuditEntityType.request);
      expect(model.entityId, 'req-3');
      expect(model.actorRole, UserRole.admin);
      expect(model.timestamp, ts.toDate());
      expect(model.metadata['requestType'], 'leave');
      expect(model.isDeleted, isFalse);
    });

    test('entity ⇄ model ⇄ map round-trip preserves the record', () {
      const entry = AuditLogEntry(
        id: 'x1',
        eventType: AuditEventType.taskCompleted,
        entityType: AuditEntityType.task,
        entityId: 't-7',
        actorId: 'emp-2',
        actorName: 'Sara',
        actorRole: UserRole.employee,
        branchId: 'b-1',
        metadata: {'attachments': 2},
      );

      final back = AuditLogModel.fromMap(
        AuditLogModel.fromEntity(entry).toCreateMap(),
        id: 'x1',
      ).toEntity();

      expect(back.eventType, entry.eventType);
      expect(back.entityType, entry.entityType);
      expect(back.entityId, entry.entityId);
      expect(back.actorId, entry.actorId);
      expect(back.actorRole, entry.actorRole);
      expect(back.branchId, entry.branchId);
      expect(back.metadata['attachments'], 2);
    });

    test('metadata normalizes DateTime ⇄ Timestamp, recursively', () {
      final when = DateTime.utc(2026, 1, 2, 3, 4, 5);
      final model = AuditLogModel(
        id: '',
        eventType: AuditEventType.taskAssigned,
        entityType: AuditEntityType.task,
        entityId: 't-1',
        actorId: 'u-1',
        metadata: {
          'due': when,
          'nested': {'at': when},
          'list': [when],
        },
      );

      final encoded = model.toCreateMap()['metadata'] as Map;
      expect(encoded['due'], isA<Timestamp>());
      expect((encoded['nested'] as Map)['at'], isA<Timestamp>());
      expect((encoded['list'] as List).first, isA<Timestamp>());

      // …and back again on read. (Firestore's Timestamp.toDate() returns the
      // same instant in local time, so compare moments, not the zone flag.)
      final decoded =
          AuditLogModel.fromMap({...model.toCreateMap(), 'metadata': encoded})
              .metadata;
      expect((decoded['due'] as DateTime).isAtSameMomentAs(when), isTrue);
      expect(((decoded['nested'] as Map)['at'] as DateTime).isAtSameMomentAs(when),
          isTrue);
      expect(((decoded['list'] as List).first as DateTime).isAtSameMomentAs(when),
          isTrue);
    });

    test('forward-compatible: an unknown stored event id → unknown', () {
      final model = AuditLogModel.fromMap({
        'eventType': 'billing.invoice_paid', // written by a newer client
        'entityType': 'invoice',
        'entityId': 'inv-1',
        'actorId': 'u-1',
        'schemaVersion': 2, // a future schema version coexists
      });
      expect(model.eventType, AuditEventType.unknown);
      expect(model.entityType, AuditEntityType.other);
      expect(model.schemaVersion, 2);
    });

    test('legacy doc without schemaVersion defaults to 1', () {
      final model = AuditLogModel.fromMap({
        'eventType': 'task.started',
        'entityType': 'task',
        'entityId': 't-1',
        'actorId': 'u-1',
      });
      expect(model.schemaVersion, 1);
    });

    test('reads the soft-delete fields when present', () {
      final deletedAt = Timestamp.fromDate(DateTime.utc(2026, 7, 11));
      final model = AuditLogModel.fromMap({
        'eventType': 'task.approved',
        'entityType': 'task',
        'entityId': 't-1',
        'actorId': 'u-1',
        'isDeleted': true,
        'deletedAt': deletedAt,
        'deletedBy': 'admin-9',
      });
      expect(model.isDeleted, isTrue);
      expect(model.deletedAt, deletedAt.toDate());
      expect(model.deletedBy, 'admin-9');
    });
  });
}
