import 'package:opshub/core/extensions/firestore_extensions.dart';
import 'package:opshub/core/enums/schedule_shift.dart';
import 'package:opshub/core/enums/task_priority.dart';
import 'package:opshub/core/enums/template_repeat_mode.dart';
import 'package:opshub/features/task/data/models/task_template_model.dart'
    show checklistTemplatesFromList, checklistTemplatesToList;
import 'package:opshub/features/task/domain/entities/checklist_item.dart';
import 'package:opshub/features/task/domain/entities/recurring_task_template_entity.dart';

/// Firestore (de)serialization for [RecurringTaskTemplateEntity] — collection
/// `recurringTaskTemplates/{id}`. Reuses the existing checklist-template
/// (de)serialization helpers from `task_template_model.dart` (same
/// `{id, title, isRequired}` shape) rather than duplicating them.
class RecurringTaskTemplateModel {
  final String id;
  final String title;
  final String? description;
  final TaskPriority priority;
  final List<ChecklistItemTemplate> checklistItems;
  final String branchId;
  final ScheduleShift shift;
  final TemplateRepeatMode repeat;
  final int weekday;
  final bool active;
  final String? createdBy;
  final String? updatedBy;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? lastRunAt;
  final DateTime? nextRunAt;
  final String? lastStatus;
  final String? lastGeneratedTaskId;
  final int failureCount;
  final int configVersion;
  final int runCount;
  final int successCount;
  final int failedCount;
  final int skippedCount;
  final int totalDurationMs;
  final DateTime? lastSuccessAt;
  final DateTime? lastFailureAt;

  const RecurringTaskTemplateModel({
    required this.id,
    required this.title,
    this.description,
    this.priority = TaskPriority.normal,
    this.checklistItems = const [],
    required this.branchId,
    required this.shift,
    this.repeat = TemplateRepeatMode.daily,
    this.weekday = 1,
    this.active = true,
    this.createdBy,
    this.updatedBy,
    this.createdAt,
    this.updatedAt,
    this.lastRunAt,
    this.nextRunAt,
    this.lastStatus,
    this.lastGeneratedTaskId,
    this.failureCount = 0,
    this.configVersion = 1,
    this.runCount = 0,
    this.successCount = 0,
    this.failedCount = 0,
    this.skippedCount = 0,
    this.totalDurationMs = 0,
    this.lastSuccessAt,
    this.lastFailureAt,
  });

  factory RecurringTaskTemplateModel.fromMap(Map<String, dynamic> map,
          {String? id}) =>
      RecurringTaskTemplateModel(
        id: id ?? map['id'] as String? ?? '',
        title: map['title'] as String? ?? '',
        description: map['description'] as String?,
        priority: TaskPriority.fromString(map['priority'] as String?),
        checklistItems: checklistTemplatesFromList(map['checklistItems']),
        branchId: map['branchId'] as String? ?? '',
        shift: ScheduleShift.fromString(map['shift'] as String?),
        repeat: TemplateRepeatMode.fromString(map['repeat'] as String?),
        weekday: (map['weekday'] as num?)?.toInt() ?? 1,
        active: map['active'] as bool? ?? true,
        createdBy: map['createdBy'] as String?,
        updatedBy: map['updatedBy'] as String?,
        createdAt: map.date('createdAt'),
        updatedAt: map.date('updatedAt'),
        lastRunAt: map.date('lastRunAt'),
        nextRunAt: map.date('nextRunAt'),
        lastStatus: map['lastStatus'] as String?,
        lastGeneratedTaskId: map['lastGeneratedTaskId'] as String?,
        failureCount: (map['failureCount'] as num?)?.toInt() ?? 0,
        configVersion: (map['configVersion'] as num?)?.toInt() ?? 1,
        runCount: (map['runCount'] as num?)?.toInt() ?? 0,
        successCount: (map['successCount'] as num?)?.toInt() ?? 0,
        failedCount: (map['failedCount'] as num?)?.toInt() ?? 0,
        skippedCount: (map['skippedCount'] as num?)?.toInt() ?? 0,
        totalDurationMs: (map['totalDurationMs'] as num?)?.toInt() ?? 0,
        lastSuccessAt: map.date('lastSuccessAt'),
        lastFailureAt: map.date('lastFailureAt'),
      );

  factory RecurringTaskTemplateModel.fromEntity(
          RecurringTaskTemplateEntity e) =>
      RecurringTaskTemplateModel(
        id: e.id,
        title: e.title,
        description: e.description,
        priority: e.priority,
        checklistItems: e.checklistItems,
        branchId: e.branchId,
        shift: e.shift,
        repeat: e.repeat,
        weekday: e.weekday,
        active: e.active,
        createdBy: e.createdBy,
        updatedBy: e.updatedBy,
        createdAt: e.createdAt,
        updatedAt: e.updatedAt,
        lastRunAt: e.lastRunAt,
        nextRunAt: e.nextRunAt,
        lastStatus: e.lastStatus,
        lastGeneratedTaskId: e.lastGeneratedTaskId,
        failureCount: e.failureCount,
        configVersion: e.configVersion,
        runCount: e.runCount,
        successCount: e.successCount,
        failedCount: e.failedCount,
        skippedCount: e.skippedCount,
        totalDurationMs: e.totalDurationMs,
        lastSuccessAt: e.lastSuccessAt,
        lastFailureAt: e.lastFailureAt,
      );

  /// Persisted fields. `createdAt`/`updatedAt` are written by the datasource as
  /// server timestamps, so they are intentionally not included here.
  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        'description': description,
        'priority': priority.value,
        'checklistItems': checklistTemplatesToList(checklistItems),
        'branchId': branchId,
        'shift': shift.value,
        'repeat': repeat.value,
        'weekday': weekday,
        'active': active,
        'createdBy': createdBy,
        // Client-written. The automation-health rollups (lastRunAt / nextRunAt /
        // lastStatus / lastGeneratedTaskId / failureCount) are Cloud-Function-owned
        // and deliberately omitted so a client save can never regress them (the
        // update path merges, so omission preserves the server's values).
        'updatedBy': updatedBy,
      };

  /// Returns a copy with the Firestore-generated [id] applied (used on create).
  RecurringTaskTemplateModel copyWithId(String id) => RecurringTaskTemplateModel(
        id: id,
        title: title,
        description: description,
        priority: priority,
        checklistItems: checklistItems,
        branchId: branchId,
        shift: shift,
        repeat: repeat,
        weekday: weekday,
        active: active,
        createdBy: createdBy,
        updatedBy: updatedBy,
        createdAt: createdAt,
        updatedAt: updatedAt,
        lastRunAt: lastRunAt,
        nextRunAt: nextRunAt,
        lastStatus: lastStatus,
        lastGeneratedTaskId: lastGeneratedTaskId,
        failureCount: failureCount,
        configVersion: configVersion,
        runCount: runCount,
        successCount: successCount,
        failedCount: failedCount,
        skippedCount: skippedCount,
        totalDurationMs: totalDurationMs,
        lastSuccessAt: lastSuccessAt,
        lastFailureAt: lastFailureAt,
      );

  RecurringTaskTemplateEntity toEntity() => RecurringTaskTemplateEntity(
        id: id,
        title: title,
        description: description,
        priority: priority,
        checklistItems: checklistItems,
        branchId: branchId,
        shift: shift,
        repeat: repeat,
        weekday: weekday,
        active: active,
        createdBy: createdBy,
        updatedBy: updatedBy,
        createdAt: createdAt,
        updatedAt: updatedAt,
        lastRunAt: lastRunAt,
        nextRunAt: nextRunAt,
        lastStatus: lastStatus,
        lastGeneratedTaskId: lastGeneratedTaskId,
        failureCount: failureCount,
        configVersion: configVersion,
        runCount: runCount,
        successCount: successCount,
        failedCount: failedCount,
        skippedCount: skippedCount,
        totalDurationMs: totalDurationMs,
        lastSuccessAt: lastSuccessAt,
        lastFailureAt: lastFailureAt,
      );
}
