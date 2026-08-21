import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:opshub/features/task/data/models/task_model.dart';
import 'package:opshub/features/task/domain/entities/task_entity.dart';
import 'package:opshub/features/task/domain/work_types/definitions/inventory_count_work_type.dart';
import 'package:opshub/features/task/domain/work_types/definitions/transfer_work_type.dart';
import 'package:opshub/features/task/domain/work_types/task_work_x.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('workType + data persistence', () {
    test('round-trips workType and typed data (incl. DateTime ↔ Timestamp)', () {
      final now = DateTime(2026, 7, 7, 9, 30);
      final entity = TaskEntity(
        id: 't1',
        title: 'Count back stock',
        workType: 'inventoryCount',
        data: {
          InventoryCountWorkType.kArea: 'Stockroom',
          InventoryCountWorkType.kExpectedQty: 20,
          InventoryCountWorkType.kCountedQty: 18,
          'neededBy': now, // a date/time work-field
        },
      );

      final map = TaskModel.fromEntity(entity).toMap();
      expect(map['workType'], 'inventoryCount');
      // DateTime is stored as a Firestore Timestamp, not a raw DateTime.
      expect((map['data'] as Map)['neededBy'], isA<Timestamp>());
      expect((map['data'] as Map)[InventoryCountWorkType.kExpectedQty], 20);

      final back = TaskModel.fromMap(map, id: 't1').toEntity();
      expect(back.workType, 'inventoryCount');
      expect(back.data[InventoryCountWorkType.kArea], 'Stockroom');
      expect(back.data['neededBy'], now); // Timestamp decoded back to DateTime
    });

    test('recurses into nested maps (an inspection results map)', () {
      final entity = TaskEntity(
        id: 't2',
        title: 'Morning inspection',
        workType: 'inspection',
        data: {
          'results': {'p1': 'pass', 'p2': 'fail'},
        },
      );
      final back =
          TaskModel.fromMap(TaskModel.fromEntity(entity).toMap(), id: 't2')
              .toEntity();
      expect((back.data['results'] as Map)['p2'], 'fail');
    });

    test('legacy doc without workType/data → general + empty (no migration)', () {
      final legacy = <String, dynamic>{
        'title': 'Old task',
        'status': 'pending',
        'type': 'daily',
      };
      final entity = TaskModel.fromMap(legacy, id: 'old').toEntity();
      expect(entity.workType, 'general');
      expect(entity.data, isEmpty);
      // The adapter resolves the fallback definition without crashing.
      expect(entity.workDefinition.id, 'general');
    });
  });

  group('TaskWorkX adapter', () {
    test('builds a WorkContext the definition can act on', () {
      final entity = TaskEntity(
        id: 't3',
        title: 'Transfer jackets',
        workType: 'transfer',
        data: {
          TransferWorkType.kGoods: 'Jackets',
          TransferWorkType.kDestination: 'Downtown',
        },
      );
      expect(entity.workSummary(), 'Jackets → Downtown');
      // No proof yet → cannot dispatch.
      expect(entity.workDefinition.validateSubmission(entity.workContext).ok, isFalse);
    });
  });
}
