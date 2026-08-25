import 'package:flutter_test/flutter_test.dart';
import 'package:opshub/features/task/data/models/task_model.dart';
import 'package:opshub/features/task/domain/entities/checklist_item.dart';
import 'package:opshub/features/task/domain/entities/task_entity.dart';
import 'package:opshub/features/task/domain/entities/task_template_entity.dart';

/// Pure-logic verification for the Phase 9 task changes (no Firebase needed):
/// checklist completion rules, multi-assignee, and (de)serialization.
void main() {
  group('checklist completion rule', () {
    test('no checklist → required items are trivially complete', () {
      const task = TaskEntity(id: '1', title: 'Open shop');
      expect(task.requiredChecklistComplete, isTrue);
      expect(task.hasChecklist, isFalse);
      expect(task.checklistProgress, 1.0);
    });

    test('blocks completion until all required items are done', () {
      const task = TaskEntity(id: '1', title: 'Open shop', checklist: [
        ChecklistItem(id: 'a', title: 'Unlock', completed: true),
        ChecklistItem(id: 'b', title: 'Lights'), // required, not done
        ChecklistItem(id: 'c', title: 'Music', isRequired: false),
      ]);
      expect(task.requiredChecklistComplete, isFalse);
      expect(task.checklistDone, 1);
      expect(task.checklistTotal, 3);
    });

    test('optional items left undone do not block completion', () {
      const task = TaskEntity(id: '1', title: 'Open shop', checklist: [
        ChecklistItem(id: 'a', title: 'Unlock', completed: true),
        ChecklistItem(id: 'b', title: 'Music', isRequired: false),
      ]);
      expect(task.requiredChecklistComplete, isTrue);
    });
  });

  group('multi-assignee model', () {
    test('round-trips assigneeIds and mirrors the primary assignee', () {
      const task = TaskEntity(
        id: '1',
        title: 'Restock',
        assigneeIds: ['u1', 'u2', 'u3'],
      );
      final map = TaskModel.fromEntity(task).toMap();
      expect(map['assigneeIds'], ['u1', 'u2', 'u3']);
      // Legacy mirror = primary assignee.
      expect(map['assignedEmployeeId'], 'u1');

      final back = TaskModel.fromMap(map, id: '1').toEntity();
      expect(back.assigneeIds, ['u1', 'u2', 'u3']);
      expect(back.isAssigned, isTrue);
    });

    test('falls back to legacy assignedEmployeeId when no array present', () {
      final back = TaskModel.fromMap({
        'id': '1',
        'title': 'Legacy task',
        'assignedEmployeeId': 'legacy-uid',
      }, id: '1').toEntity();
      expect(back.assigneeIds, ['legacy-uid']);
    });
  });

  group('checklist serialization', () {
    test('round-trips checklist items', () {
      final task = TaskEntity(
        id: '1',
        title: 'Close shop',
        checklist: [
          ChecklistItem(
              id: 'a',
              title: 'Count cash',
              completed: true,
              completedAt: DateTime(2026, 6, 16, 22)),
          const ChecklistItem(id: 'b', title: 'Lock up', isRequired: false),
        ],
      );
      final back = TaskModel.fromMap(
        TaskModel.fromEntity(task).toMap(),
        id: '1',
      ).toEntity();
      expect(back.checklist.length, 2);
      expect(back.checklist[0].completed, isTrue);
      expect(back.checklist[0].completedAt, DateTime(2026, 6, 16, 22));
      expect(back.checklist[1].isRequired, isFalse);
    });
  });

  group('template → task checklist', () {
    test('builds an uncompleted task checklist from template items', () {
      const template = TaskTemplateEntity(
        id: 't1',
        title: 'Open Shop',
        checklistItems: [
          ChecklistItemTemplate(id: 'a', title: 'Unlock entrance'),
          ChecklistItemTemplate(id: 'b', title: 'Turn on lights'),
          ChecklistItemTemplate(id: 'c', title: 'Music', isRequired: false),
        ],
      );
      final items = template.buildTaskChecklist();
      expect(items.length, 3);
      expect(items.every((i) => !i.completed), isTrue);
      expect(items[2].isRequired, isFalse);
    });
  });
}
