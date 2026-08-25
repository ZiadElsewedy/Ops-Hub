import 'package:flutter_test/flutter_test.dart';
import 'package:opshub/features/task/data/models/task_model.dart';
import 'package:opshub/features/task/domain/entities/task_entity.dart';

/// Verifies the rework-distinction fields (`revisionNumber` / `requiresRework` /
/// `rejectionReason`, Notification System Phase 1 — Part 2) round-trip through
/// serialization and are back-compatible (a legacy doc without them defaults to
/// 0 / false / null).
void main() {
  group('TaskModel rework fields', () {
    test('writes the rework fields', () {
      final map = const TaskModel(
        id: '1',
        title: 't',
        revisionNumber: 2,
        requiresRework: true,
        rejectionReason: 'Missing stock photo',
      ).toMap();
      expect(map['revisionNumber'], 2);
      expect(map['requiresRework'], true);
      expect(map['rejectionReason'], 'Missing stock photo');
    });

    test('a legacy doc without the fields defaults safely', () {
      final m = TaskModel.fromMap(const {'title': 't'});
      expect(m.revisionNumber, 0);
      expect(m.requiresRework, false);
      expect(m.rejectionReason, isNull);
    });

    test('reads the fields when present', () {
      final m = TaskModel.fromMap(const {
        'title': 't',
        'revisionNumber': 3,
        'requiresRework': true,
        'rejectionReason': 'Redo the count',
      });
      expect(m.revisionNumber, 3);
      expect(m.requiresRework, true);
      expect(m.rejectionReason, 'Redo the count');
    });

    test('round-trips through the entity boundary', () {
      const e = TaskEntity(
        id: '1',
        title: 't',
        revisionNumber: 1,
        requiresRework: true,
        rejectionReason: 'Fix it',
      );
      final back = TaskModel.fromEntity(e).toEntity();
      expect(back.revisionNumber, 1);
      expect(back.requiresRework, true);
      expect(back.rejectionReason, 'Fix it');
    });

    test('TaskEntity.isNew is true only for a fresh pending task', () {
      const fresh = TaskEntity(id: '1', title: 't');
      expect(fresh.isNew, true);
      // A reworked task (even if pending again) is not "new".
      expect(
        fresh.copyWith(revisionNumber: 1, requiresRework: true).isNew,
        false,
      );
    });
  });
}
