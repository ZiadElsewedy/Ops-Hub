import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opshub/core/enums/broadcast_audience.dart';
import 'package:opshub/core/enums/user_role.dart';
import 'package:opshub/features/communications/data/models/broadcast_model.dart';
import 'package:opshub/features/communications/domain/entities/broadcast_entity.dart';

/// Broadcast lifecycle + delivery fields (archivedAt) round-trip cleanly and the
/// derived getters (isActive / isArchived / failedCount) behave, with safe
/// back-compat defaults for legacy docs. (Priority + channel were removed
/// 2026-06-24 — delivery is derived from the category.)
void main() {
  group('BroadcastModel — lifecycle fields', () {
    test('archivedAt parse from a doc', () {
      final entity = BroadcastModel.fromMap({
        'title': 't',
        'message': 'm',
        'senderId': 'u',
        'senderName': 'n',
        'audience': 'branch',
        'branchId': 'b1',
        'category': 'reminder',
        'recipientCount': 30,
        'deliveredCount': 27,
        'archivedAt': Timestamp.fromDate(DateTime(2026, 6, 22, 9)),
      }).toEntity();

      expect(entity.category, 'reminder');
      expect(entity.isArchived, isTrue);
      expect(entity.isActive, isFalse); // archived ⇒ not active
    });

    test('legacy doc (no lifecycle fields) → active', () {
      final entity = BroadcastModel.fromMap(const {
        'title': 't',
        'message': 'm',
        'senderId': 'u',
        'senderName': 'n',
      }).toEntity();

      expect(entity.isActive, isTrue);
      expect(entity.isArchived, isFalse);
    });
  });

  group('BroadcastEntity derived getters', () {
    test('failedCount = recipients − delivered (clamped, null until known)', () {
      const sent = BroadcastEntity(
        id: 'b',
        title: 't',
        message: 'm',
        senderId: 'u',
        senderName: 'n',
        recipientCount: 30,
        deliveredCount: 27,
      );
      expect(sent.failedCount, 3);

      const pending = BroadcastEntity(
        id: 'b',
        title: 't',
        message: 'm',
        senderId: 'u',
        senderName: 'n',
        recipientCount: 30,
      );
      expect(pending.failedCount, isNull);

      // Never negative even if delivered somehow exceeds recipients.
      const odd = BroadcastEntity(
        id: 'b',
        title: 't',
        message: 'm',
        senderId: 'u',
        senderName: 'n',
        recipientCount: 5,
        deliveredCount: 7,
      );
      expect(odd.failedCount, 0);
    });

    test('custom (multi-recipient) audience uses its own branch marker', () {
      expect(BroadcastAudience.fromString('custom'), BroadcastAudience.custom);
      expect(BroadcastAudience.custom.isCustom, isTrue);

      final model = BroadcastModel.fromEntity(const BroadcastEntity(
        id: 'c1',
        title: 't',
        message: 'm',
        senderId: 'mgr',
        senderName: 'Mgr',
        senderRole: UserRole.manager,
        audience: BroadcastAudience.custom,
      ));
      // Custom keeps the doc out of every branch/all feed (own marker).
      expect(model.branchId, BroadcastModel.customBranchMarker);
      expect(model.branchId, isNot(''));
      expect(model.branchId, isNot(BroadcastModel.directBranchMarker));

      // The marker maps back to a null entity branch on read.
      final back = model.toEntity();
      expect(back.audience, BroadcastAudience.custom);
      expect(back.branchId, isNull);
    });

    test('isActive only when not archived', () {
      final base = DateTime(2026, 6, 22);
      const active = BroadcastEntity(
          id: 'b', title: 't', message: 'm', senderId: 'u', senderName: 'n');
      expect(active.isActive, isTrue);

      final archived = active.copyWith(archivedAt: base);
      expect(archived.isActive, isFalse);
      expect(archived.isArchived, isTrue);
    });
  });
}
