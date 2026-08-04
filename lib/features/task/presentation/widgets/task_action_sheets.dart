import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:drop/core/enums/recurrence_frequency.dart';
import 'package:drop/core/enums/schedule_day.dart';
import 'package:drop/core/enums/schedule_shift.dart';
import 'package:drop/core/enums/task_assignment_type.dart';
import 'package:drop/core/enums/task_cancel_reason.dart';
import 'package:drop/core/enums/task_priority.dart';
import 'package:drop/core/enums/task_status.dart';
import 'package:drop/core/enums/task_type.dart';
import 'package:drop/core/enums/template_repeat_mode.dart';
import 'package:drop/core/theme/app_colors.dart';
import 'package:drop/core/theme/app_radius.dart';
import 'package:drop/core/theme/app_spacing.dart';
import 'package:drop/core/theme/app_typography.dart';
import 'package:drop/core/utils/app_date_formatter.dart';
import 'package:drop/core/widgets/app_motion.dart';
import 'package:drop/core/widgets/user_avatar.dart';
import 'package:drop/features/auth/domain/entities/user_entity.dart';
import 'package:drop/features/auth/presentation/widgets/app_button.dart';
import 'package:drop/features/auth/presentation/widgets/app_text_field.dart';
import 'package:drop/features/branch/domain/entities/branch_entity.dart';
import 'package:drop/features/schedule/domain/shift_hours.dart';
import 'package:drop/features/task/domain/entities/checklist_item.dart';
import 'package:drop/features/task/domain/entities/recurrence_config.dart';
import 'package:drop/features/task/domain/entities/task_attachment.dart';
import 'package:drop/features/task/domain/entities/task_entity.dart';
import 'package:drop/features/task/domain/entities/task_template_entity.dart';
import 'package:drop/features/task/domain/task_schedule.dart';
import 'package:drop/features/task/presentation/attachment_format.dart';
import 'package:drop/features/task/domain/work_types/work_draft.dart';
import 'package:drop/features/task/domain/work_types/work_type_registry.dart';
import 'package:drop/core/media/picked_attachment.dart';
import 'package:drop/core/widgets/connectivity_scope.dart';
import 'package:drop/features/task/presentation/cubit/task_cubit.dart';
import 'package:drop/features/task/presentation/widgets/attachment_gallery.dart';
import 'package:drop/features/task/presentation/widgets/attachment_picker.dart';
import 'package:drop/features/task/presentation/widgets/dynamic_work_form.dart';

// ─── Split into part files (one library; private widgets stay shared). ───
part 'task_action_sheets/task_form_sheet.dart';
part 'task_action_sheets/branch_picker_sheet.dart';
part 'task_action_sheets/checklist_builder.dart';
part 'task_action_sheets/assignee_picker_sheet.dart';
part 'task_action_sheets/assign_sheet.dart';
part 'task_action_sheets/review_sheet.dart';
part 'task_action_sheets/cancel_sheet.dart';
part 'task_action_sheets/shared/form_primitives.dart';
part 'task_action_sheets/shift_pickers.dart';

// TODO(create-task-v2): deferred to a future release (owner-agreed, out of the
// V1 ship-polish scope). Track as issues when scheduled:
//   • Create & Add Another — keep the form open, reset for rapid batch entry.
//   • Smart Templates — a work type auto-populates a default checklist + field
//     defaults on selection (extend WorkTypeRegistry / WorkTypeDefinition).
//   • Draft Recovery — persist an in-progress task and restore on reopen.
//   • AI Suggestions — suggest title/checklist/assignee from context.
//   • Create from Template — surface "start from template" in this flow.
//   • Better Schedule Presets — richer, configurable quick-deadline presets.

/// Create or edit a task (manager/admin). For a manager the branch is fixed to
/// [defaultBranchId]; an admin **picks** an existing branch from a dropdown
/// (loaded from Firestore — never free text, so a task can't be orphaned on a
/// branch that doesn't exist). Pass [prefill] to seed the form from a template.
///
/// Creating a task is a **core, daily workflow**, so it is a first-class
/// full-screen route — not a modal bottom sheet. It opens with a Cupertino
/// bottom-up modal transition ([CupertinoPageRoute] with `fullscreenDialog`),
/// gets its own back stack (sub-pickers push cleanly), and pins its primary
/// action to the bottom. The form's state + business logic are unchanged; only
/// the container and presentation were elevated.
Future<void> showTaskFormSheet({
  required BuildContext context,
  required TaskCubit cubit,
  TaskEntity? existing,
  TaskTemplateEntity? prefill,
  required bool isAdmin,
  required String defaultBranchId,
}) => Navigator.of(context).push<void>(
  CupertinoPageRoute<void>(
    fullscreenDialog: true,
    builder: (_) => _TaskFormSheet(
      cubit: cubit,
      existing: existing,
      prefill: prefill,
      isAdmin: isAdmin,
      defaultBranchId: defaultBranchId,
    ),
  ),
);

/// Pick one or more employees in the task's branch to assign (or the whole
/// team), or clear the assignment.
Future<void> showAssignSheet({
  required BuildContext context,
  required TaskCubit cubit,
  required TaskEntity task,
}) => showSheet(context, _AssignSheet(cubit: cubit, task: task));

/// Approve or reject a task with an optional review note (manager/admin).
Future<void> showReviewSheet({
  required BuildContext context,
  required TaskCubit cubit,
  required TaskEntity task,
}) => showSheet(context, _ReviewSheet(cubit: cubit, task: task));

/// Cancel a task with a mandatory structured reason (manager/admin, and only
/// from `pending` / `started` — see [TaskStatus.isCancellable]). Callers gate
/// the affordance; the cubit and `firestore.rules` both re-check.
Future<void> showCancelSheet({
  required BuildContext context,
  required TaskCubit cubit,
  required TaskEntity task,
}) => showSheet(context, _CancelSheet(cubit: cubit, task: task));

/// An employee reports a task as incorrect, routing it to their branch's
/// managers to decide. The employee never cancels — this is the release valve
/// that makes manager-only cancellation workable.
Future<void> showReportIncorrectSheet({
  required BuildContext context,
  required TaskCubit cubit,
  required TaskEntity task,
}) => showSheet(context, _ReportIncorrectSheet(cubit: cubit, task: task));

/// Shared bottom-sheet chrome (rounded top, drag handle, keyboard-aware
/// padding). Reused by the task + template sheets so they all feel the same.
Future<T?> showSheet<T>(BuildContext context, Widget child) =>
    showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.darkSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: AppSpacing.pagePadding,
          right: AppSpacing.pagePadding,
          top: AppSpacing.sm,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + AppSpacing.xl,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SheetHandle(),
            Flexible(child: child),
          ],
        ),
      ),
    );

/// A small centered drag handle shown at the top of every bottom sheet.
class SheetHandle extends StatelessWidget {
  const SheetHandle({super.key});
  @override
  Widget build(BuildContext context) => Container(
    width: 36,
    height: 4,
    margin: const EdgeInsets.only(bottom: AppSpacing.md),
    decoration: BoxDecoration(
      color: AppColors.darkBorder,
      borderRadius: BorderRadius.circular(2),
    ),
  );
}

class SheetTitle extends StatelessWidget {
  const SheetTitle(this.text, {super.key});
  final String text;
  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.centerLeft,
    child: Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: Text(text, style: AppTypography.h3),
    ),
  );
}
