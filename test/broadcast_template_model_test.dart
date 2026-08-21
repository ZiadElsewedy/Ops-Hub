import 'package:flutter_test/flutter_test.dart';
import 'package:opshub/core/enums/broadcast_category.dart';
import 'package:opshub/features/communications/data/models/broadcast_template_model.dart';
import 'package:opshub/features/communications/domain/entities/broadcast_template_entity.dart';

/// Phase 2 Commit 2 — broadcast template model round-trips, including the
/// global ('' branchId) convention and the derived getters.
void main() {
  group('BroadcastTemplateModel serialization', () {
    test('toMap writes enum values + fields (timestamps are server-side)', () {
      final map = const BroadcastTemplateModel(
        id: 't1',
        title: 'Stock count',
        message: 'Count the back room, {{employee_name}}.',
        category: BroadcastCategory.reminder,
        ownerId: 'mgr-1',
        branchId: 'branch-7',
        isFavorite: true,
        usageCount: 5,
      ).toMap();

      expect(map['title'], 'Stock count');
      expect(map['category'], 'reminder');
      expect(map['ownerId'], 'mgr-1');
      expect(map['branchId'], 'branch-7');
      expect(map['isFavorite'], true);
      expect(map['usageCount'], 5);
      expect(map.containsKey('createdAt'), isFalse);
    });

    test('fromEntity stores a global template with the "" branchId', () {
      final model = BroadcastTemplateModel.fromEntity(
        const BroadcastTemplateEntity(
          id: 't2',
          title: 'Holiday hours',
          message: 'All stores open late.',
          branchId: null,
        ),
      );
      expect(model.branchId, '');
      expect(model.toEntity().isGlobal, isTrue);
      expect(model.toEntity().branchId, isNull);
    });

    test('fromMap parses enums + defaults for a legacy/partial doc', () {
      final e = BroadcastTemplateModel.fromMap(const {
        'title': 't',
        'message': 'm',
      }).toEntity();
      expect(e.category, BroadcastCategory.announcement);
      expect(e.isFavorite, isFalse);
      expect(e.usageCount, 0);
      expect(e.isGlobal, isTrue);
    });

    test('round-trip preserves a branch-scoped template + placeholders getter',
        () {
      const entity = BroadcastTemplateEntity(
        id: 't3',
        title: 'Welcome',
        message: 'Hi {{employee_name}}, welcome to {{branch_name}}.',
        category: BroadcastCategory.announcement,
        ownerId: 'admin',
        branchId: 'branch-2',
        usageCount: 2,
      );
      final back = BroadcastTemplateModel.fromEntity(entity).toEntity();
      expect(back.branchId, 'branch-2');
      expect(back.isGlobal, isFalse);
      expect(back.placeholders, ['employee_name', 'branch_name']);
    });

    test('copyWithId assigns the generated id', () {
      final m = const BroadcastTemplateModel(id: '', title: 't', message: 'm')
          .copyWithId('gen-1');
      expect(m.id, 'gen-1');
    });
  });
}
