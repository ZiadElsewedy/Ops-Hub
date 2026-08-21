import 'package:opshub/core/extensions/firestore_extensions.dart';
import 'package:opshub/core/enums/task_type.dart';
import 'package:opshub/core/enums/task_priority.dart';
import 'package:opshub/features/task/domain/entities/checklist_item.dart';
import 'package:opshub/features/task/domain/entities/task_template_entity.dart';

/// Firestore (de)serialization for [TaskTemplateEntity] — collection
/// `task_templates/{templateId}`. Stores the reusable checklist as a list of
/// `{id, title, isRequired}` maps under `checklistItems`.
class TaskTemplateModel {
  final String id;
  final String title;
  final String? description;
  final TaskType type;
  final TaskPriority priority;
  final List<ChecklistItemTemplate> checklistItems;
  final String? branchId;
  final String? createdBy;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const TaskTemplateModel({
    required this.id,
    required this.title,
    this.description,
    this.type = TaskType.daily,
    this.priority = TaskPriority.normal,
    this.checklistItems = const [],
    this.branchId,
    this.createdBy,
    this.createdAt,
    this.updatedAt,
  });

  factory TaskTemplateModel.fromMap(Map<String, dynamic> map, {String? id}) =>
      TaskTemplateModel(
        id: id ?? map['id'] as String? ?? '',
        title: map['title'] as String? ?? '',
        description: map['description'] as String?,
        type: TaskType.fromString(map['type'] as String?),
        priority: TaskPriority.fromString(map['priority'] as String?),
        checklistItems: checklistTemplatesFromList(map['checklistItems']),
        branchId: map['branchId'] as String?,
        createdBy: map['createdBy'] as String?,
        createdAt: map.date('createdAt'),
        updatedAt: map.date('updatedAt'),
      );

  factory TaskTemplateModel.fromEntity(TaskTemplateEntity e) =>
      TaskTemplateModel(
        id: e.id,
        title: e.title,
        description: e.description,
        type: e.type,
        priority: e.priority,
        checklistItems: e.checklistItems,
        branchId: e.branchId,
        createdBy: e.createdBy,
        createdAt: e.createdAt,
        updatedAt: e.updatedAt,
      );

  /// Persisted fields. `createdAt`/`updatedAt` are written by the datasource as
  /// server timestamps, so they are intentionally not included here.
  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        'description': description,
        'type': type.value,
        'priority': priority.value,
        'checklistItems': checklistTemplatesToList(checklistItems),
        'branchId': branchId,
        'createdBy': createdBy,
      };

  /// Returns a copy with the Firestore-generated [id] applied (used on create).
  TaskTemplateModel copyWithId(String id) => TaskTemplateModel(
        id: id,
        title: title,
        description: description,
        type: type,
        priority: priority,
        checklistItems: checklistItems,
        branchId: branchId,
        createdBy: createdBy,
        createdAt: createdAt,
        updatedAt: updatedAt,
      );

  TaskTemplateEntity toEntity() => TaskTemplateEntity(
        id: id,
        title: title,
        description: description,
        type: type,
        priority: priority,
        checklistItems: checklistItems,
        branchId: branchId,
        createdBy: createdBy,
        createdAt: createdAt,
        updatedAt: updatedAt,
      );
}

/// Parses a Firestore `checklistItems` array (list of maps) into template items.
/// Tolerates missing/malformed entries.
List<ChecklistItemTemplate> checklistTemplatesFromList(dynamic raw) {
  if (raw is! List) return const [];
  final items = <ChecklistItemTemplate>[];
  for (final e in raw) {
    if (e is Map) {
      final title = e['title'] as String? ?? '';
      if (title.isEmpty) continue;
      items.add(ChecklistItemTemplate(
        id: e['id'] as String? ?? '',
        title: title,
        isRequired: e['isRequired'] as bool? ?? true,
      ));
    }
  }
  return items;
}

/// Serializes template checklist items to a list of Firestore maps.
List<Map<String, dynamic>> checklistTemplatesToList(
        List<ChecklistItemTemplate> items) =>
    [
      for (final i in items)
        {'id': i.id, 'title': i.title, 'isRequired': i.isRequired},
    ];
