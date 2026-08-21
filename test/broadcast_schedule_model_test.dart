import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opshub/core/enums/broadcast_audience.dart';
import 'package:opshub/core/enums/broadcast_recurrence.dart';
import 'package:opshub/core/enums/user_role.dart';
import 'package:opshub/features/communications/data/models/broadcast_schedule_model.dart';
import 'package:opshub/features/communications/domain/entities/broadcast_schedule_entity.dart';

/// Phase 2 Commit 4 — the broadcast schedule model round-trips, including the
/// recurrence + targeting fields and the timestamp serialization.
void main() {
  group('BroadcastScheduleModel serialization', () {
    test('toMap writes enums, recurrence, timestamps and targetUserIds', () {
      final map = BroadcastScheduleModel(
        id: 's1',
        title: 'Daily standup',
        message: 'Standup in 10 minutes.',
        audience: BroadcastAudience.branch,
        branchId: 'branch-7',
        roleFilter: 'employee',
        targetUserIds: const [],
        senderId: 'mgr-1',
        senderRole: UserRole.manager,
        recurrenceType: BroadcastRecurrence.daily,
        interval: 1,
        startDate: DateTime(2026, 6, 23, 9),
        nextRunAt: DateTime(2026, 6, 23, 9),
        enabled: true,
      ).toMap();

      expect(map['audience'], 'branch');
      expect(map['roleFilter'], 'employee');
      expect(map['recurrenceType'], 'daily');
      expect(map['enabled'], true);
      expect(map['nextRunAt'], isA<Timestamp>());
      expect(map['targetUserIds'], isEmpty);
    });

    test('fromMap parses a doc, maps "" branch → null entity branch', () {
      final e = BroadcastScheduleModel.fromMap({
        'title': 't',
        'message': 'm',
        'audience': 'allBranches',
        'branchId': '',
        'recurrenceType': 'custom',
        'interval': 3,
        'enabled': false,
        'runCount': 5,
        'targetUserIds': const ['a', 'b'],
        'startDate': Timestamp.fromDate(DateTime(2026, 6, 1)),
        'nextRunAt': Timestamp.fromDate(DateTime(2026, 6, 25)),
      }, id: 's2').toEntity();

      expect(e.id, 's2');
      expect(e.audience, BroadcastAudience.allBranches);
      expect(e.branchId, isNull);
      expect(e.recurrenceType, BroadcastRecurrence.custom);
      expect(e.interval, 3);
      expect(e.enabled, isFalse);
      expect(e.runCount, 5);
      expect(e.isRecurring, isTrue);
    });

    test('legacy/partial doc defaults to a disabled-safe one-time schedule', () {
      final e = BroadcastScheduleModel.fromMap(const {
        'title': 't',
        'message': 'm',
      }).toEntity();
      expect(e.recurrenceType, BroadcastRecurrence.oneTime);
      expect(e.isRecurring, isFalse);
      expect(e.enabled, isTrue);
      expect(e.runCount, 0);
      expect(e.nextRunAt, isNull);
      expect(e.isCompleted, isTrue); // null nextRunAt ⇒ completed
    });

    test('fromEntity carries an explicit custom targetUserIds list', () {
      final model = BroadcastScheduleModel.fromEntity(
        const BroadcastScheduleEntity(
          id: 's3',
          title: 't',
          message: 'm',
          audience: BroadcastAudience.custom,
        ),
        targetUserIds: const ['u1', 'u2', 'u3'],
      );
      expect(model.targetUserIds, ['u1', 'u2', 'u3']);
      expect(model.toMap()['targetUserIds'], ['u1', 'u2', 'u3']);
    });
  });
}
