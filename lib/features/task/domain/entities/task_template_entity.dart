import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:opshub/core/enums/task_type.dart';
import 'package:opshub/core/enums/task_priority.dart';
import 'package:opshub/features/task/domain/entities/checklist_item.dart';

part 'task_template_entity.freezed.dart';

/// A reusable **checklist** blueprint (Phase 9) — e.g. "Open Shop", "Close
/// Shop". A manager/admin instantiates it into a real [TaskEntity] from the New
/// Task flow, so recurring daily work isn't retyped each shift and every step is
/// captured as a checklist item the employee must tick off.
///
/// A template carries only the task's *content* (title / description / type /
/// priority / [checklistItems]) — never an assignment or a status; those are
/// decided when a task is created from it. It is branch-scoped via [branchId]
/// exactly like a task (admin: any/global · manager: own branch); access is
/// enforced server-side in `firestore.rules` (`task_templates/{id}`).
@freezed
class TaskTemplateEntity with _$TaskTemplateEntity {
  const TaskTemplateEntity._();

  const factory TaskTemplateEntity({
    required String id,
    required String title,
    String? description,
    @Default(TaskType.daily) TaskType type,
    @Default(TaskPriority.normal) TaskPriority priority,

    /// The reusable checklist (e.g. Unlock entrance · Turn on lights · …).
    @Default(<ChecklistItemTemplate>[]) List<ChecklistItemTemplate> checklistItems,

    /// Owning branch. Empty/null = a GLOBAL template (admin-made), available to
    /// every branch; otherwise scoped to that branch's managers/admins.
    String? branchId,

    /// uid of the manager/admin who created the template.
    String? createdBy,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) = _TaskTemplateEntity;

  /// Builds the task-level checklist (all items uncompleted) when a task is
  /// created from this template.
  List<ChecklistItem> buildTaskChecklist() =>
      [for (final i in checklistItems) i.toTaskItem()];
}
