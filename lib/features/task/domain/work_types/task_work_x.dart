import 'package:opshub/features/task/domain/entities/task_entity.dart';
import 'package:opshub/features/task/domain/work_types/work_context.dart';
import 'package:opshub/features/task/domain/work_types/work_draft.dart';
import 'package:opshub/features/task/domain/work_types/work_type_definition.dart';
import 'package:opshub/features/task/domain/work_types/work_type_registry.dart';

/// The **single seam** between a `TaskEntity` and the work-type kernel.
///
/// Everything above (screens, cubit) reaches a task's behaviour through these
/// three getters; everything inside the kernel stays decoupled from the 40-field
/// entity. Keeping the adapter here (an extension, not entity methods) means the
/// entity file carries no dependency on the registry, and this mapping is the
/// one place that knows how a `TaskEntity`'s shape feeds a [WorkContext].
extension TaskWorkX on TaskEntity {
  /// The behaviour definition for this task's [TaskEntity.workType] (unknown /
  /// legacy ids resolve to `general`).
  WorkTypeDefinition get workDefinition =>
      WorkTypeRegistry.instance.byId(workType);

  /// A decoupled snapshot of this *live* task for the definition to reason over.
  ///
  /// Proof media = employee-uploaded attachments across the activity log plus the
  /// legacy single `proofImageUrl`. Logged milestones = the set of activity-log
  /// status strings (a per-type [WorkEvent] rides `ActivityEntry.status`).
  WorkContext get workContext {
    final proofCount = activityLog.fold<int>(0, (n, e) => n + e.attachments.length) +
        (proofImageUrl != null && proofImageUrl!.isNotEmpty ? 1 : 0);
    return WorkContext(
      data: data,
      status: status,
      checklistTotal: checklistTotal,
      checklistDone: checklistDone,
      checklistRequired: checklist.where((c) => c.isRequired).length,
      checklistRequiredDone:
          checklist.where((c) => c.isRequired && c.completed).length,
      checklistItemIds: [for (final c in checklist) c.id],
      loggedEvents: {for (final e in activityLog) e.status},
      proofCount: proofCount,
      assigneeCount: assigneeIds.length,
      hasDeadline: deadline != null,
    );
  }

  /// A create-time draft view for setup validation (before the task exists).
  WorkDraft workDraft() => WorkDraft(
        data: data,
        checklistCount: checklist.length,
        assigneeCount: assigneeIds.length,
      );

  // ─── Convenience pass-throughs (screens read these directly) ──────────────
  double get workProgress => workDefinition.progress(workContext);
  bool get workRequiresProof => workDefinition.requiresProof(workContext);
  String workSummary() => workDefinition.summarize(workContext, title: title);
}
