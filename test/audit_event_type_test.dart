import 'package:flutter_test/flutter_test.dart';
import 'package:opshub/core/enums/audit_entity_type.dart';
import 'package:opshub/core/enums/audit_event_type.dart';

void main() {
  group('AuditEventType', () {
    test('parses its stable dotted id (never the enum name)', () {
      expect(AuditEventType.fromString('task.approved'),
          AuditEventType.taskApproved);
      expect(AuditEventType.fromString('request.created'),
          AuditEventType.requestCreated);
      expect(AuditEventType.fromString('shift_swap.requested'),
          AuditEventType.shiftSwapRequested);
      // The enum name is NOT the wire id — parsing it must fail to unknown.
      expect(AuditEventType.fromString('taskApproved'), AuditEventType.unknown);
    });

    test('unknown / missing id → unknown (forward-compatible, never crashes)',
        () {
      expect(AuditEventType.fromString('task.some_future_event'),
          AuditEventType.unknown);
      expect(AuditEventType.fromString(null), AuditEventType.unknown);
      expect(AuditEventType.fromString(''), AuditEventType.unknown);
    });

    test('every value round-trips through its wire id', () {
      for (final t in AuditEventType.values) {
        expect(AuditEventType.fromString(t.value), t,
            reason: '${t.name} (${t.value}) must round-trip');
      }
    });

    test('wire ids are unique', () {
      final ids = AuditEventType.values.map((t) => t.value).toList();
      expect(ids.toSet().length, ids.length, reason: 'duplicate event id');
    });

    test('carries a sensible default entity type', () {
      expect(AuditEventType.taskApproved.defaultEntityType,
          AuditEntityType.task);
      expect(AuditEventType.requestCreated.defaultEntityType,
          AuditEntityType.request);
      expect(AuditEventType.shiftSwapApproved.defaultEntityType,
          AuditEntityType.shiftSwap);
      expect(AuditEventType.authLogin.defaultEntityType,
          AuditEntityType.session);
      expect(AuditEventType.salesTargetChanged.defaultEntityType,
          AuditEntityType.salesMonth);
    });

    test('namespace is the segment before the dot', () {
      expect(AuditEventType.taskApproved.namespace, 'task');
      expect(AuditEventType.shiftSwapRequested.namespace, 'shift_swap');
      expect(AuditEventType.requestRejected.namespace, 'request');
      expect(AuditEventType.unknown.namespace, 'unknown');
    });
  });

  group('AuditEntityType', () {
    test('parses stored values; unknown / missing → other', () {
      expect(AuditEntityType.fromString('task'), AuditEntityType.task);
      expect(AuditEntityType.fromString('session'), AuditEntityType.session);
      expect(AuditEntityType.fromString('galaxy'), AuditEntityType.other);
      expect(AuditEntityType.fromString(null), AuditEntityType.other);
      expect(AuditEntityType.fromString('sales_month'), AuditEntityType.salesMonth);
      expect(AuditEntityType.fromString('daily_sales_submission'),
          AuditEntityType.dailySalesSubmission);
    });

    test('every value round-trips', () {
      for (final t in AuditEntityType.values) {
        expect(AuditEntityType.fromString(t.value), t);
      }
    });
  });
}
