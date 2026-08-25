import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:opshub/core/enums/task_assignment_type.dart';
import 'package:opshub/core/enums/task_priority.dart';
import 'package:opshub/core/enums/task_status.dart';
import 'package:opshub/core/enums/user_role.dart';
import 'package:opshub/core/extensions/context_extensions.dart';
import 'package:opshub/core/responsive/breakpoints.dart';
import 'package:opshub/core/theme/app_colors.dart';
import 'package:opshub/core/utils/app_date_formatter.dart';
import 'package:opshub/core/theme/app_radius.dart';
import 'package:opshub/core/theme/app_spacing.dart';
import 'package:opshub/core/theme/app_typography.dart';
import 'package:opshub/core/widgets/adaptive_scaffold.dart';
import 'package:opshub/core/widgets/app_dialog.dart';
import 'package:opshub/core/widgets/app_motion.dart';
import 'package:opshub/core/widgets/app_snackbar.dart';
import 'package:opshub/core/widgets/branch_avatar.dart';
import 'package:opshub/core/widgets/premium_button.dart';
import 'package:opshub/core/widgets/user_avatar.dart';
import 'package:opshub/features/auth/domain/entities/user_entity.dart';
import 'package:opshub/features/branch/domain/entities/branch_entity.dart';
import 'package:opshub/features/branch/presentation/cubit/branch_cubit.dart';
import 'package:opshub/features/auth/presentation/widgets/app_button.dart';
import 'package:opshub/features/auth/presentation/widgets/app_text_field.dart';
import 'package:opshub/features/task/domain/entities/checklist_item.dart';
import 'package:opshub/features/task/domain/entities/task_entity.dart';
import 'package:opshub/features/task/domain/task_outcomes.dart';
import 'package:opshub/features/task/domain/task_origin.dart';
import 'package:opshub/features/task/domain/task_schedule.dart';
import 'package:opshub/features/task/domain/work_types/task_work_x.dart';
import 'package:opshub/features/task/presentation/activity_format.dart';
import 'package:opshub/features/task/presentation/attachment_format.dart';
import 'package:opshub/core/media/picked_attachment.dart';
import 'package:opshub/core/widgets/connectivity_scope.dart';
import 'package:opshub/features/task/presentation/cubit/task_cubit.dart';
import 'package:opshub/features/task/presentation/cubit/task_state.dart';
import 'package:opshub/features/task/presentation/submission_progress.dart';
import 'package:opshub/features/task/presentation/widgets/activity_timeline.dart';
import 'package:opshub/features/task/presentation/widgets/attachment_gallery.dart';
import 'package:opshub/features/task/presentation/widgets/attachment_picker.dart';
import 'package:opshub/features/task/presentation/widgets/submission_loading_overlay.dart';
import 'package:opshub/features/task/presentation/widgets/task_action_sheets.dart';
import 'package:opshub/features/task/presentation/widgets/task_card.dart';
import 'package:opshub/features/task/presentation/widgets/task_surface.dart';
import 'package:opshub/features/task/presentation/widgets/work_detail_sections.dart';
import 'package:opshub/features/task/presentation/widgets/work_type_panel.dart';
import 'package:opshub/features/task/presentation/work_type_presenter.dart';

/// Full-screen task details for all roles. Employees work through their
/// checklist and submit proof here. Managers see full context + review controls.
///
/// Keeps itself in sync with the [TaskCubit] stream by resolving the latest
/// snapshot of the same task id on every build (falls back to the initial [task]
/// if the cubit hasn't loaded yet or the task id isn't in the current list).
class TaskDetailsScreen extends StatefulWidget {
  const TaskDetailsScreen({
    super.key,
    required this.task,
    this.directory = const {},
  });

  final TaskEntity task;
  final Map<String, UserEntity> directory;

  @override
  State<TaskDetailsScreen> createState() => _TaskDetailsScreenState();
}

class _TaskDetailsScreenState extends State<TaskDetailsScreen> {
  Timer? _startGateTimer;
  DateTime? _startGateTimerAt;

  void _armStartGateTimer(TaskEntity task) {
    final start = task.startsAt;
    final now = DateTime.now();
    final needsGateTimer =
        (task.status == TaskStatus.pending ||
            task.status == TaskStatus.rejected) &&
        start != null &&
        start.isAfter(now);
    if (!needsGateTimer) {
      _startGateTimer?.cancel();
      _startGateTimer = null;
      _startGateTimerAt = null;
      return;
    }
    if (_startGateTimerAt == start && _startGateTimer?.isActive == true) return;
    _startGateTimer?.cancel();
    _startGateTimerAt = start;
    _startGateTimer = Timer(start.difference(now), () {
      _startGateTimer = null;
      _startGateTimerAt = null;
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _startGateTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<TaskCubit, TaskState>(
      listener: (context, state) =>
          state.whenOrNull(error: (m) => AppSnackbar.error(context, m)),
      builder: (context, state) {
        // Always show the freshest snapshot from the stream, plus the shared
        // submission state (drives the single loading overlay).
        final live = state.maybeWhen(
          loaded: (tasks, busy, directory, isSubmitting, submissionProgress) {
            final found = tasks.where((t) => t.id == widget.task.id).toList();
            return (
              task: found.isNotEmpty ? found.first : widget.task,
              directory: directory,
              busy: busy,
              submitting: isSubmitting,
              progress: submissionProgress,
            );
          },
          orElse: () => (
            task: widget.task,
            directory: widget.directory,
            busy: false,
            submitting: false,
            progress: null,
          ),
        );
        _armStartGateTimer(live.task);

        return PopScope(
          // Block back navigation while a submission is in flight.
          canPop: !live.submitting,
          child: Stack(
            children: [
              _DetailsView(
                task: live.task,
                directory: live.directory,
                busy: live.busy,
                cubit: context.read<TaskCubit>(),
              ),
              if (live.submitting)
                Positioned.fill(
                  child: SubmissionLoadingOverlay(
                    progress:
                        live.progress ??
                        const SubmissionProgress(SubmissionStage.preparing),
                    onCancel: () =>
                        context.read<TaskCubit>().cancelSubmission(),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

// ─── Main details view ──────────────────────────────────────────────

class _DetailsView extends StatelessWidget {
  const _DetailsView({
    required this.task,
    required this.directory,
    required this.busy,
    required this.cubit,
  });

  final TaskEntity task;
  final Map<String, UserEntity> directory;

  /// A lifecycle write is in flight somewhere in the cubit. Drives the
  /// primary action's in-flight treatment (see [_EmployeeActions]).
  final bool busy;
  final TaskCubit cubit;

  Future<void> _confirmReopen(BuildContext context) async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Reopen task?',
      message:
          'This moves the task back into the workflow so it can be edited. The approval will be cleared.',
      confirmLabel: 'Reopen',
    );
    if (confirmed && context.mounted) cubit.reopenTask(task);
  }

  /// The admin's §6.4 safety valve. Confirmed because it rewrites a closed
  /// outcome — the message names which one, so nobody undoes a Missed thinking
  /// they were undoing a Cancel.
  Future<void> _confirmCorrectTerminal(BuildContext context) async {
    final isMissed = task.status == TaskStatus.missed;
    final confirmed = await showConfirmDialog(
      context,
      title: isMissed ? 'Reopen this missed task?' : 'Undo this cancellation?',
      message: isMissed
          ? 'Use this only when the task was recorded as missed in error. It '
                'returns to Pending and the missed record is cleared.'
          : 'Use this only when the task was cancelled in error. It returns to '
                'Pending and the cancellation reason is cleared.',
      confirmLabel: 'Reopen',
    );
    if (confirmed && context.mounted) cubit.correctTerminal(task);
  }

  @override
  Widget build(BuildContext context) {
    final role = context.currentRole;
    final isEmployee = role?.isEmployee ?? true;
    final isManagerOrAdmin = !(role?.isEmployee ?? true);
    final isAdmin = role?.isAdmin ?? false;
    // Terminal records are read-only, with two narrow exits: a manager/admin
    // may reopen an APPROVED task, and an admin alone may correct a mistaken
    // missed/cancelled terminal (Automated Tasks spec §6.4).
    final isLocked = task.status.isTerminal;
    final canReopen = isManagerOrAdmin && task.status == TaskStatus.approved;
    final canCorrectTerminal =
        isAdmin &&
        (task.status == TaskStatus.missed ||
            task.status == TaskStatus.cancelled);
    // Branch identity from the app-wide directory (§8b) — drives the cover
    // banner + logo. Watched so it fills in once the directory preloads.
    final branch = context.watch<BranchCubit>().branchById(task.branchId);

    return AdaptiveScaffold(
      title: task.title,
      constrainContent: false,
      actions: [
        if (isManagerOrAdmin && !isLocked) ...[
          IconButton(
            icon: const Icon(
              Icons.person_add_alt_1_outlined,
              color: AppColors.textSecondary,
            ),
            tooltip: 'Assign',
            onPressed: () =>
                showAssignSheet(context: context, cubit: cubit, task: task),
          ),
          IconButton(
            icon: const Icon(
              Icons.edit_outlined,
              color: AppColors.textSecondary,
            ),
            tooltip: 'Edit',
            onPressed: () {
              final user = context.currentUser;
              showTaskFormSheet(
                context: context,
                cubit: cubit,
                existing: task,
                isAdmin: isAdmin,
                defaultBranchId: user?.branchId ?? '',
              );
            },
          ),
          // Cancel — the manager/admin early exit, offered from Pending or
          // Started only. A submitted task must be reviewed, never voided
          // (Automated Tasks spec §5.4), so the affordance disappears the
          // moment the employee sends it for review.
          if (task.status.isCancellable)
            IconButton(
              icon: const Icon(
                Icons.block_rounded,
                color: AppColors.textSecondary,
              ),
              tooltip: 'Cancel task',
              onPressed: () =>
                  showCancelSheet(context: context, cubit: cubit, task: task),
            ),
        ],
        // A terminal record is locked, but not beyond correction: an approved
        // task reopens, and an ADMIN may undo a mistaken missed/cancelled
        // terminal (§6.4) so a fat-fingered close doesn't become a permanent
        // lie in the reporting. A manager sees the padlock instead.
        if (isManagerOrAdmin && isLocked)
          if (canReopen || canCorrectTerminal)
            IconButton(
              icon: const Icon(
                Icons.lock_open_rounded,
                color: AppColors.textSecondary,
              ),
              tooltip: canReopen ? 'Reopen' : 'Correct this record',
              onPressed: () => canReopen
                  ? _confirmReopen(context)
                  : _confirmCorrectTerminal(context),
            )
          else
            const Padding(
              padding: EdgeInsets.only(right: AppSpacing.md),
              child: Icon(
                Icons.lock_outline_rounded,
                size: 20,
                color: AppColors.textTertiary,
              ),
            ),
      ],
      body: context.isDesktop
          ? _desktopBody(
              context,
              isEmployee,
              isManagerOrAdmin,
              canReopen,
              isLocked,
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.pagePadding,
                AppSpacing.sm,
                AppSpacing.pagePadding,
                AppSpacing.xxxl,
              ),
              children: [
                // ── Branch cover banner (identity) ──────────────────────
                // When the task's branch has an uploaded cover photo, lead with it so
                // the task visibly belongs to its branch (reuses the §8 branch media +
                // the §8b app-wide BranchCubit directory). Hidden when there's no cover.
                if (branch?.coverUrl != null &&
                    branch!.coverUrl!.isNotEmpty) ...[
                  _BranchBanner(branch: branch),
                  const SizedBox(height: AppSpacing.lg),
                ],

                // ── Status · title · description · facts ────────────────
                _StatusHeader(
                  task: task,
                  branchName: cubit.branchNames[task.branchId ?? ''],
                  // The banner above already names the branch when it renders.
                  showBranch: !(branch?.coverUrl?.isNotEmpty ?? false),
                ),
                const SizedBox(height: AppSpacing.xl),

                // ── Locked notice (approved · missed · cancelled) ───────
                if (isLocked) ...[
                  _LockedBanner(task: task, canReopen: canReopen),
                  const SizedBox(height: AppSpacing.xl),
                ],

                // ── An employee says this task is wrong ─────────────────
                // Sits directly under the status because it is the one thing a
                // manager opening this task most needs to act on.
                if (!isLocked && task.isReportedIncorrect) ...[
                  _ReportedIncorrectBanner(
                    task: task,
                    cubit: cubit,
                    directory: directory,
                    canDecide: isManagerOrAdmin,
                  ),
                  const SizedBox(height: AppSpacing.xl),
                ],

                // ── Work type (adaptive) — the metrics sit right under the
                // status so the whole job reads in seconds (Summary → Status →
                // Metrics → Details).
                if (WorkTypePanel.hasContentFor(task)) ...[
                  _Section(
                    icon: WorkTypePresenter.iconFor(task.workType),
                    title: task.workDefinition.label,
                    child: WorkTypePanel(
                      task: task,
                      cubit: cubit,
                      interactive:
                          isEmployee && task.status == TaskStatus.started,
                      showReviewHint: isManagerOrAdmin,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                ],

                // ── Assignment ─────────────────────────────────────────
                // "Assignment", not "Assigned to": the block now carries both
                // halves of the handover (who is doing it, who gave it), and
                // the old label only named one of them.
                _Section(
                  icon: Icons.people_alt_outlined,
                  title: 'Assignment',
                  child: _AssigneeBlock(task: task, directory: directory),
                ),
                const SizedBox(height: AppSpacing.xl),

                // No standalone Description section — the brief now sits
                // directly under the title in the header, where a task's own
                // words belong. It used to be a third section down, separated
                // from its title by the whole assignment block.

                // ── Reference images (manager-attached) ────────────────
                if (task.hasReferences) ...[
                  _Section(
                    icon: Icons.image_outlined,
                    title: 'Reference',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'What good looks like — attached by the manager.',
                          style: AppTypography.caption.copyWith(
                            color: AppColors.textTertiary,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        AttachmentGallery(
                          attachments: task.referenceAttachments,
                          columns: 2,
                          showDuration: true,
                          showCaption: false,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                ],

                // ── Checklist ──────────────────────────────────────────
                if (task.hasChecklist &&
                    !task.workDefinition.usesChecklistAsPoints) ...[
                  _Section(
                    icon: Icons.checklist_rounded,
                    title: 'Checklist',
                    trailing: _ChecklistBadge(task: task),
                    child: _ChecklistBlock(
                      task: task,
                      interactive:
                          isEmployee && task.status == TaskStatus.started,
                      onToggle: (item) =>
                          cubit.toggleChecklistItem(task, item.id),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                ],

                // ── Notes & media ─────────────────────────────────────
                if ((task.notes ?? '').isNotEmpty ||
                    latestAttachments(task).isNotEmpty) ...[
                  _Section(
                    icon: Icons.rate_review_outlined,
                    title: 'Submitted work',
                    child: _SubmittedBlock(task: task),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                ],

                // ── Review notes ───────────────────────────────────────
                if ((task.reviewNotes ?? '').isNotEmpty) ...[
                  _Section(
                    icon: Icons.feedback_outlined,
                    title: 'Review note',
                    child: Container(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      decoration: BoxDecoration(
                        color: task.status == TaskStatus.rejected
                            ? AppColors.errorSurface
                            : AppColors.darkSurfaceElevated,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: task.status == TaskStatus.rejected
                              ? AppColors.error.withAlpha(60)
                              : AppColors.darkBorder,
                        ),
                      ),
                      child: Text(
                        task.reviewNotes!,
                        style: AppTypography.body.copyWith(
                          color: AppColors.textSecondary,
                          height: 1.5,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                ],

                // ── Activity timeline ──────────────────────────────────
                if (task.activityLog.isNotEmpty) ...[
                  _Section(
                    icon: Icons.timeline_rounded,
                    title: 'Activity',
                    child: ActivityTimeline(
                      task: task,
                      directory: directory,
                      cubit: cubit,
                      canReview: isManagerOrAdmin,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                ],

                // ── Recurrence info ───────────────────────────────────
                if (task.recurrence != null &&
                    task.recurrence!.frequency.value != 'none') ...[
                  _Section(
                    icon: Icons.repeat_rounded,
                    title: 'Recurrence',
                    child: Text(
                      task.recurrence!.frequency.label,
                      style: AppTypography.body.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                ],

                // ── Employee action area ───────────────────────────────
                if (isEmployee && !isLocked) ...[
                  _EmployeeActions(task: task, cubit: cubit, busy: busy),
                ],

                // ── Manager / admin action area ────────────────────────
                if (isManagerOrAdmin &&
                    task.status == TaskStatus.waitingReview) ...[
                  _ReviewBlock(task: task, cubit: cubit),
                ],
              ],
            ),
    );
  }

  // ── Desktop: two-column ticket inspection (Linear/Jira style) ──────
  // Left = the ticket record (status, description, proof, activity); right =
  // a dedicated, sticky action panel (assignment + approve/rework/submit).
  Widget _desktopBody(
    BuildContext context,
    bool isEmployee,
    bool isManagerOrAdmin,
    bool canReopen,
    bool isLocked,
  ) {
    final branch = context.watch<BranchCubit>().branchById(task.branchId);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Main record ────────────────────────────────────────────
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(40, 24, 28, 48),
            children: [
              if (branch?.coverUrl != null && branch!.coverUrl!.isNotEmpty) ...[
                _BranchBanner(branch: branch),
                const SizedBox(height: AppSpacing.lg),
              ],
              _StatusHeader(
                task: task,
                branchName: cubit.branchNames[task.branchId ?? ''],
                showBranch: !(branch?.coverUrl?.isNotEmpty ?? false),
              ),
              const SizedBox(height: AppSpacing.xl),
              // Metrics first (Summary → Status → Metrics → Details).
              if (WorkTypePanel.hasContentFor(task)) ...[
                _Section(
                  icon: WorkTypePresenter.iconFor(task.workType),
                  title: task.workDefinition.label,
                  child: WorkTypePanel(
                    task: task,
                    cubit: cubit,
                    interactive:
                        isEmployee && task.status == TaskStatus.started,
                    showReviewHint: isManagerOrAdmin,
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
              ],
              // The brief lives under the title in the header now — see
              // `_StatusHeader`. No standalone Description section.
              if (task.hasReferences) ...[
                _Section(
                  icon: Icons.image_outlined,
                  title: 'Reference',
                  child: AttachmentGallery(
                    attachments: task.referenceAttachments,
                    columns: 3,
                    showDuration: true,
                    showCaption: false,
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
              ],
              if (task.hasChecklist &&
                  !task.workDefinition.usesChecklistAsPoints) ...[
                _Section(
                  icon: Icons.checklist_rounded,
                  title: 'Checklist',
                  trailing: _ChecklistBadge(task: task),
                  child: _ChecklistBlock(
                    task: task,
                    interactive:
                        isEmployee && task.status == TaskStatus.started,
                    onToggle: (item) =>
                        cubit.toggleChecklistItem(task, item.id),
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
              ],
              if ((task.notes ?? '').isNotEmpty ||
                  latestAttachments(task).isNotEmpty) ...[
                _Section(
                  icon: Icons.rate_review_outlined,
                  title: 'Submitted work',
                  child: _SubmittedBlock(task: task),
                ),
                const SizedBox(height: AppSpacing.xl),
              ],
              if ((task.reviewNotes ?? '').isNotEmpty) ...[
                _Section(
                  icon: Icons.feedback_outlined,
                  title: 'Review note',
                  child: Container(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                      color: task.status == TaskStatus.rejected
                          ? AppColors.errorSurface
                          : AppColors.darkSurfaceElevated,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: task.status == TaskStatus.rejected
                            ? AppColors.error.withAlpha(60)
                            : AppColors.darkBorder,
                      ),
                    ),
                    child: Text(
                      task.reviewNotes!,
                      style: AppTypography.body.copyWith(
                        color: AppColors.textSecondary,
                        height: 1.5,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
              ],
              if (task.activityLog.isNotEmpty)
                _Section(
                  icon: Icons.timeline_rounded,
                  title: 'Activity',
                  child: ActivityTimeline(
                    task: task,
                    directory: directory,
                    cubit: cubit,
                    canReview: isManagerOrAdmin,
                  ),
                ),
            ],
          ),
        ),
        const VerticalDivider(width: 1, color: AppColors.darkBorder),
        // ── Action / context panel ─────────────────────────────────
        SizedBox(
          width: 360,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 24, 40, 48),
            children: [
              if (isLocked) ...[
                _LockedBanner(task: task, canReopen: canReopen),
                const SizedBox(height: AppSpacing.xl),
              ],
              // The action panel is where a manager decides, so the open report
              // belongs at the top of it.
              if (!isLocked && task.isReportedIncorrect) ...[
                _ReportedIncorrectBanner(
                  task: task,
                  cubit: cubit,
                  directory: directory,
                  canDecide: isManagerOrAdmin,
                ),
                const SizedBox(height: AppSpacing.xl),
              ],
              _Section(
                icon: Icons.people_alt_outlined,
                title: 'Assignment',
                child: _AssigneeBlock(task: task, directory: directory),
              ),
              if (task.recurrence != null &&
                  task.recurrence!.frequency.value != 'none') ...[
                const SizedBox(height: AppSpacing.xl),
                _Section(
                  icon: Icons.repeat_rounded,
                  title: 'Recurrence',
                  child: Text(
                    task.recurrence!.frequency.label,
                    style: AppTypography.body.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
              if (!isLocked &&
                  (isEmployee ||
                      (isManagerOrAdmin &&
                          task.status == TaskStatus.waitingReview))) ...[
                const SizedBox(height: AppSpacing.xl),
                const Divider(color: AppColors.darkBorder),
                const SizedBox(height: AppSpacing.lg),
                if (isEmployee)
                  _EmployeeActions(task: task, cubit: cubit, busy: busy)
                else
                  _ReviewBlock(task: task, cubit: cubit),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

// ─── Status header ─────────────────────────────────────────────────

/// The task's status header — **de-flashed** (2026-06-25): a flat solid surface
/// with a hairline border and a whisper of depth. No breathing pulse, no glow,
/// no gradient (the status pill carries the state; it still cross-fades on a
/// status change, which is a one-shot transition, not a pulse).
/// A slim branch **cover** banner for the task details header — the branch's
/// uploaded cover photo (dark scrim for legibility) with its logo + name
/// overlaid. Reuses the §8 branch media + the Operations branch-hero pattern,
/// scaled down to a header strip so the task reads as belonging to its branch.
class _BranchBanner extends StatelessWidget {
  const _BranchBanner({required this.branch});
  final BranchEntity branch;

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: AppRadius.cardAll,
        border: Border.all(color: AppColors.darkBorder),
      ),
      child: AspectRatio(
        aspectRatio: 16 / 6,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.network(
              branch.coverUrl!,
              fit: BoxFit.cover,
              cacheWidth: 1200,
              errorBuilder: (_, _, _) =>
                  const ColoredBox(color: AppColors.darkSurface),
            ),
            // Dark scrim (stronger at the bottom, where the label sits).
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0x40000000), Color(0xCC000000)],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  BranchAvatar(
                    logoUrl: branch.logoUrl,
                    name: branch.name,
                    size: 34,
                    radius: 9,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          branch.name,
                          style: AppTypography.label.copyWith(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w700,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if ((branch.location ?? '').isNotEmpty)
                          Text(
                            branch.location!,
                            style: AppTypography.caption.copyWith(
                              color: AppColors.textSecondary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The task header — **what this task is**, above everything else.
///
/// Rebuilt 2026-08-03 (owner: *"the header or the description of the task not
/// clear … assignment from who? … too much things"*). Three faults:
///
/// * **The title was not on the page.** It lived only in the app bar, at app-bar
///   size, above a full-bleed branch cover photo. The first thing the body said
///   about a task was its status, then seven metadata chips — you could not read
///   what the work actually *was*.
/// * **The description was a separate section further down**, so a one-line task
///   brief was separated from its own title by the assignment block.
/// * **The meta row printed everything it had** — up to eleven chips of equal
///   weight, including the branch (already named by the banner directly above)
///   and the raw `type` string ("special"), and a `Normal` priority that is the
///   default and therefore says nothing.
///
/// Now: status → **title** → description → the facts that change what you do
/// (schedule · priority when it isn't normal · timeliness). Every chip left is
/// one a manager would act on.
class _StatusHeader extends StatelessWidget {
  const _StatusHeader({
    required this.task,
    this.branchName,
    this.showBranch = true,
  });

  final TaskEntity task;
  final String? branchName;

  /// False when a branch cover banner sits directly above this header — the
  /// chip would then be the branch name twice in ~80px.
  final bool showBranch;

  @override
  Widget build(BuildContext context) {
    final description = (task.description ?? '').trim();
    final phase = schedulePhase(task, DateTime.now());
    final pills = _pills(phase);
    final hasWindow = _ScheduleWindow.hasAnything(task);
    // Reuses the shared de-flashed [TaskSurface] (same flat surface + whisper
    // shadow as the task card) so the treatment is defined in one place.
    return TaskSurface(
      padding: const EdgeInsets.all(AppSpacing.lg),
      borderRadius: AppRadius.cardAll,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _StatusPill(task.status),
          const SizedBox(height: AppSpacing.md),

          // ── The task itself ────────────────────────────────────────
          // The headline of the whole screen. Wraps rather than ellipsizing:
          // this is the one string the page exists to communicate.
          Text(
            task.title,
            style: AppTypography.h2.copyWith(height: 1.25),
          ),
          if (description.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              description,
              style: AppTypography.body.copyWith(
                color: AppColors.textSecondary,
                height: 1.55,
              ),
            ),
          ],

          // The divider earns its keep only when something follows it. A task
          // with no window, no priority and no timeliness fact would otherwise
          // end on a hairline and a gap — a component that looks half-loaded.
          if (hasWindow || pills.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.lg),
            const Divider(color: AppColors.darkBorder, height: 1),
            const SizedBox(height: AppSpacing.md),
          ],

          // ── When the work happens ──────────────────────────────────
          // The window gets its own banded lockup rather than three loose
          // chips: as pills it read "Starts 6 Aug 2026 · Due 6 Aug 2026 ·
          // Est. 8h", three facts that never said the one thing an employee
          // needs — that the task runs 09:00 → 17:00 today.
          if (hasWindow) _ScheduleWindow(task: task),

          // ── The facts that change what you do ──────────────────────
          if (pills.isNotEmpty) ...[
            if (hasWindow) const SizedBox(height: AppSpacing.md),
            Wrap(
              spacing: AppSpacing.lg,
              runSpacing: AppSpacing.sm,
              children: pills,
            ),
          ],
        ],
      ),
    );
  }

  /// The meta chips this task actually has. Built as a list (not inline in the
  /// `Wrap`) so the header can gate its own divider and spacing on whether the
  /// row will render anything at all.
  List<Widget> _pills(TaskSchedulePhase phase) => [
    // Only when no cover banner named the branch already.
    if (showBranch && (branchName ?? '').isNotEmpty)
      _MetaPill(
        icon: Icons.store_mall_directory_outlined,
        label: branchName!,
      ),
    // Start · due · duration are NOT chips any more — they live in the
    // schedule band above, with their clock times.
    //
    // Finished work that missed its deadline — a timeliness signal (ADR-013),
    // never the error/highlight treatment Missed or an active overdue pill
    // wear.
    if (taskLateness(task) case final lateness?)
      _MetaPill(icon: Icons.timer_outlined, label: formatLateness(lateness)),
    // The live phase, but only when it says something the band above doesn't:
    // "Overdue" and "Due soon" are warnings, whereas "Active" merely restates
    // that an unfinished task with a future deadline is unfinished.
    if (phase.isActionable &&
        (phase == TaskSchedulePhase.overdue ||
            phase == TaskSchedulePhase.dueSoon))
      _MetaPill(
        icon: Icons.timelapse_outlined,
        label: phase.label,
        highlight: phase == TaskSchedulePhase.overdue,
      ),
    // Priority only when it is a decision: `normal` is the default every task
    // carries, so printing it is noise on every screen.
    if (task.priority != TaskPriority.normal)
      _MetaPill(
        icon: Icons.flag_outlined,
        label: _priorityLabel(task.priority),
        highlight: task.priority == TaskPriority.high,
      ),
    if (task.approvedAt != null)
      _MetaPill(
        icon: Icons.check_circle_outline_rounded,
        label: 'Completed ${_dateLabel(task.approvedAt!)}',
      ),
    if (task.missedAt != null)
      _MetaPill(
        icon: Icons.event_busy_rounded,
        label: 'Missed ${_dateLabel(task.missedAt!)}',
        highlight: true,
      ),
    if (task.recurrence != null && task.recurrence!.frequency.value != 'none')
      _MetaPill(
        icon: Icons.repeat_rounded,
        label: task.recurrence!.frequency.label,
      ),
  ];
}

/// **The schedule window** — start · due · duration, each with its clock time,
/// on one banded row.
///
/// Replaces the three chips this header used to print (2026-08-06, owner: *"the
/// estimate time to be clear and start and end more clear as well"*). Those
/// chips carried dates only, so a generated shift task read
/// `Starts 6 Aug 2026 · Due 6 Aug 2026 · Est. 8h` — the two ends looked
/// identical, and the one number that distinguished them ("8h") was labelled as
/// an *estimate* when it is nothing of the sort: it is `dueAt − startsAt`, the
/// length of the booked window, not a guess at how long the work takes.
///
/// So: **times lead** (`09:00`, the actionable fact), the day sits under them
/// through the shared [AppDateFormatter.relativeDayShort] (`Today` / `Tomorrow`
/// / `6 Aug` — the *short* variant because three cells leave ~80px each at
/// 320px), and the third cell is honestly labelled *Window*. A task that crosses
/// midnight needs no special case — its due cell simply says a different day.
///
/// 24-hour clock by the same rule as [startBlockedReason]: this sits beside
/// shift windows rendered `08:30 – 16:30`, and mixing clock formats on one
/// screen reads as a bug.
class _ScheduleWindow extends StatelessWidget {
  const _ScheduleWindow({required this.task});

  final TaskEntity task;

  /// Whether there is any window to draw. A task with neither end (a legacy
  /// row, or one created before scheduling) renders nothing rather than a band
  /// of em-dashes.
  static bool hasAnything(TaskEntity task) =>
      task.startsAt != null || task.dueAt != null;

  @override
  Widget build(BuildContext context) {
    final start = task.startsAt;
    final due = task.dueAt;
    final span = scheduledDuration(task);
    final spanLabel = span == null ? '' : formatScheduleDuration(span);
    final overdue = _isOverdue(task);

    final cells = <Widget>[
      if (start != null)
        _ScheduleCell(
          label: 'Starts',
          value: AppDateFormatter.time24(start),
          detail: AppDateFormatter.relativeDayShort(start),
        ),
      if (due != null)
        _ScheduleCell(
          label: 'Due',
          value: AppDateFormatter.time24(due),
          detail: AppDateFormatter.relativeDayShort(due),
          // The one cell that ever tints: a deadline already behind us.
          tone: overdue ? AppColors.error : null,
        ),
      if (spanLabel.isNotEmpty)
        _ScheduleCell(
          label: 'Window',
          value: spanLabel,
          detail: 'scheduled',
        ),
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.md,
      ),
      decoration: BoxDecoration(
        color: AppColors.darkBg.withAlpha(120),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.darkBorder),
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final (i, cell) in cells.indexed) ...[
              if (i > 0)
                const VerticalDivider(
                  color: AppColors.darkBorder,
                  width: AppSpacing.md,
                  thickness: 1,
                ),
              Expanded(child: cell),
            ],
          ],
        ),
      ),
    );
  }
}

/// One cell of the [_ScheduleWindow] band: a quiet uppercase label, the value,
/// and a grey detail line. Three steps of the ramp, no two adjacent the same.
class _ScheduleCell extends StatelessWidget {
  const _ScheduleCell({
    required this.label,
    required this.value,
    required this.detail,
    this.tone,
  });

  final String label;
  final String value;
  final String detail;

  /// Semantic tint for the value (overdue). Null keeps it monochrome.
  final Color? tone;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$label $value, $detail',
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label.toUpperCase(),
            style: AppTypography.caption.copyWith(
              fontSize: 9.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.9,
              color: AppColors.textTertiary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 5),
          Text(
            value,
            style: AppTypography.label.copyWith(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.2,
              color: tone ?? AppColors.textPrimary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 1),
          Text(
            detail,
            style: AppTypography.caption.copyWith(
              color: AppColors.textSecondary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill(this.status);
  final TaskStatus status;

  @override
  Widget build(BuildContext context) {
    // Cross-fade + scale the badge whenever the status changes (the screen
    // rebuilds from the live stream), giving a subtle icon scale/fade.
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 360),
      switchInCurve: Curves.easeOutBack,
      switchOutCurve: Curves.easeIn,
      transitionBuilder: (child, anim) => FadeTransition(
        opacity: anim,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.9, end: 1).animate(anim),
          child: child,
        ),
      ),
      child: _pill(),
    );
  }

  Widget _pill() {
    final (color, bg, label, icon) = _info(status);
    return Container(
      key: ValueKey(status),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs + 2,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withAlpha(60)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: AppTypography.caption.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }

  (Color, Color, String, IconData) _info(TaskStatus s) => switch (s) {
    TaskStatus.pending => (
      AppColors.textTertiary,
      AppColors.darkSurfaceElevated,
      'PENDING',
      Icons.circle_outlined,
    ),
    TaskStatus.started => (
      AppColors.textPrimary,
      AppColors.primarySurface,
      'IN PROGRESS',
      Icons.timelapse_rounded,
    ),
    TaskStatus.completed => (
      AppColors.textSecondary,
      AppColors.darkSurfaceElevated,
      'COMPLETED',
      Icons.check_circle_outline_rounded,
    ),
    TaskStatus.waitingReview => (
      AppColors.warning,
      AppColors.darkSurfaceElevated,
      'IN REVIEW',
      Icons.hourglass_empty_rounded,
    ),
    TaskStatus.approved => (
      AppColors.success,
      AppColors.successSurface,
      'APPROVED',
      Icons.check_circle_rounded,
    ),
    TaskStatus.rejected => (
      AppColors.error,
      AppColors.errorSurface,
      'NEEDS REWORK',
      Icons.replay_rounded,
    ),
    TaskStatus.missed => (
      AppColors.error,
      AppColors.errorSurface,
      'MISSED',
      Icons.event_busy_rounded,
    ),
    // A business decision, not a failure — neutral surface, never the error
    // treatment Missed carries (Automated Tasks spec §8).
    TaskStatus.cancelled => (
      AppColors.textSecondary,
      AppColors.darkSurfaceElevated,
      'CANCELLED',
      Icons.block_rounded,
    ),
  };
}

class _MetaPill extends StatelessWidget {
  const _MetaPill({
    required this.icon,
    required this.label,
    this.highlight = false,
  });
  final IconData icon;
  final String label;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final color = highlight ? AppColors.error : AppColors.textSecondary;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: color),
        const SizedBox(width: 5),
        Text(
          label,
          style: AppTypography.caption.copyWith(
            color: color,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

// ─── Section wrapper ────────────────────────────────────────────────

class _Section extends StatelessWidget {
  const _Section({
    required this.icon,
    required this.title,
    required this.child,
    this.trailing,
  });

  final IconData icon;
  final String title;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 14, color: AppColors.textTertiary),
            const SizedBox(width: AppSpacing.sm),
            Text(
              title.toUpperCase(),
              style: AppTypography.caption.copyWith(
                color: AppColors.textTertiary,
                letterSpacing: 0.8,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (trailing != null) ...[const Spacer(), trailing!],
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        child,
      ],
    );
  }
}

// ─── Assignee block ─────────────────────────────────────────────────

class _AssigneeBlock extends StatelessWidget {
  const _AssigneeBlock({required this.task, required this.directory});
  final TaskEntity task;
  final Map<String, UserEntity> directory;

  @override
  Widget build(BuildContext context) {
    final assignees = resolveAssignees(task, directory);
    final credit = _credit();
    if (task.assignmentType == TaskAssignmentType.shift) {
      // Shift Assignment feature: targets whoever's rostered on task.shift,
      // not a named assignee — assigneeIds is always empty here.
      //
      // This branch used to print the shift and stop, so a generated shift task
      // was the ONE screen in the app that never said where it came from: the
      // whole Assignment section read "Morning Shift" and nothing else.
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.schedule_rounded,
                size: 16,
                color: AppColors.textTertiary,
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                task.shift == null
                    ? 'Shift task'
                    : '${task.shift!.label} Shift',
                style: AppTypography.body,
              ),
            ],
          ),
          if (credit != null) ...[
            const SizedBox(height: AppSpacing.md),
            _OriginLine(credit: credit),
          ],
        ],
      );
    }
    if (task.assigneeIds.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Unassigned',
            style: AppTypography.body.copyWith(color: AppColors.textTertiary),
          ),
          if (credit != null) ...[
            const SizedBox(height: AppSpacing.md),
            _OriginLine(credit: credit),
          ],
        ],
      );
    }
    // One lockup, one relationship (2026-08-03, owner: *"assignment from
    // who?"*). It used to be a name + role, a hairline divider, and then an
    // orphan grey caption "Assigned by  Admin" — two separate facts stacked
    // with nothing tying them together, so the page never said who handed the
    // work to whom. The handover is now a single sentence directly under the
    // person doing the work, with the giver's name reading white.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final (i, u) in assignees.indexed) ...[
          if (i > 0) const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              UserAvatar.fromUser(u, size: 38),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _name(u),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.label.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      _roleLabel(u.role),
                      style: AppTypography.caption.copyWith(
                        color: AppColors.textTertiary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
        if (credit != null) ...[
          const SizedBox(height: AppSpacing.md),
          _OriginLine(credit: credit),
        ],
      ],
    );
  }

  String _name(UserEntity u) =>
      (u.displayName != null && u.displayName!.isNotEmpty)
      ? u.displayName!
      : u.email;

  String _roleLabel(UserRole r) => switch (r) {
    UserRole.admin => 'Admin',
    UserRole.manager => 'Manager',
    UserRole.employee => 'Employee',
  };

  /// Who this task is credited to, and under which verb — or null when the
  /// record simply doesn't say (a legacy row with no `createdBy`), because a
  /// guess is worse than a blank.
  ///
  /// **Automation is checked first** (2026-08-06, owner: *"whos create the
  /// task? if it automation task so write System - Automated task"*). A
  /// generated shift instance inherits its *template's* `createdBy`, so that
  /// field alone credits a manager for a task the server wrote at 01:00 —
  /// [taskOrigin] is the only honest signal. The human who set the automation
  /// up is not discarded; they move to the [_TaskCredit.footnote], which is
  /// where they actually belong.
  _TaskCredit? _credit() {
    final origin = taskOrigin(task);
    final uid = (task.createdBy ?? '').trim();
    final person = uid.isEmpty ? null : directory[uid];
    final personLabel = person == null
        ? (uid.isEmpty ? null : 'Admin') // known-but-unreachable, never a uid
        : '${_name(person)} · ${_roleLabel(person.role)}';

    // `label` is non-null exactly when the origin is automated, so the pattern
    // both branches and proves the interpolation below can't print "null".
    if (origin.label case final automation?) {
      return _TaskCredit(
        label: 'Created by',
        value: '$kSystemActorName · $automation',
        footnote: personLabel == null ? null : 'Set up by $personLabel',
      );
    }
    if (personLabel == null) return null;
    // A shift task has no named assignee, so nobody was "assigned by" anyone.
    return _TaskCredit(
      label: task.assignmentType == TaskAssignmentType.shift
          ? 'Created by'
          : 'Assigned by',
      value: personLabel,
    );
  }
}

/// The resolved "where did this task come from" attribution.
class _TaskCredit {
  const _TaskCredit({
    required this.label,
    required this.value,
    this.footnote,
  });

  /// The verb — `Assigned by` / `Created by`.
  final String label;

  /// Who to credit: `Ziad · Manager`, or `System · Automated task`.
  final String value;

  /// A second, quieter fact. Only automation has one today: the person who
  /// built the recurring template the server generated this from.
  final String? footnote;
}

/// The attribution row under the assignment. Indented and glyphed as a
/// handover — it reads as "…and it came from X", not as an unrelated second
/// row.
class _OriginLine extends StatelessWidget {
  const _OriginLine({required this.credit});

  final _TaskCredit credit;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.subdirectory_arrow_right_rounded,
            size: 15,
            color: AppColors.textTertiary,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                RichText(
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  text: TextSpan(
                    style: AppTypography.caption.copyWith(
                      color: AppColors.textTertiary,
                    ),
                    children: [
                      TextSpan(text: '${credit.label} '),
                      TextSpan(
                        text: credit.value,
                        style: AppTypography.caption.copyWith(
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                if (credit.footnote case final footnote?) ...[
                  const SizedBox(height: 2),
                  Text(
                    footnote,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.caption.copyWith(
                      color: AppColors.textQuaternary,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Checklist block ─────────────────────────────────────────────────

class _ChecklistBadge extends StatelessWidget {
  const _ChecklistBadge({required this.task});
  final TaskEntity task;

  @override
  Widget build(BuildContext context) {
    final done = task.checklistDone;
    final total = task.checklistTotal;
    final complete = done == total;
    return Text(
      '$done / $total',
      style: AppTypography.caption.copyWith(
        color: complete ? AppColors.success : AppColors.textSecondary,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

class _ChecklistBlock extends StatelessWidget {
  const _ChecklistBlock({
    required this.task,
    required this.interactive,
    required this.onToggle,
  });

  final TaskEntity task;
  final bool interactive;
  final void Function(ChecklistItem item) onToggle;

  @override
  Widget build(BuildContext context) {
    final done = task.checklistDone;
    final total = task.checklistTotal;
    final complete = total > 0 && done == total;
    return WorkCard(
      child: Column(
        children: [
          // Completion headline + progress — reads as work getting done.
          WorkProgressBar(
            value: task.checklistProgress,
            leading: complete ? 'All steps done' : '$done of $total done',
            trailing: complete
                ? '100%'
                : '${(task.checklistProgress * 100).round()}%',
            tone: complete ? WorkTone.positive : WorkTone.neutral,
          ),
          const SizedBox(height: AppSpacing.md),
          // Checklist items
          for (final item in task.checklist)
            _ChecklistRow(
              item: item,
              interactive: interactive,
              onTap: () => onToggle(item),
            ),
        ],
      ),
    );
  }
}

class _ChecklistRow extends StatelessWidget {
  const _ChecklistRow({
    required this.item,
    required this.interactive,
    required this.onTap,
  });

  final ChecklistItem item;
  final bool interactive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: interactive ? onTap : null,
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(
          vertical: AppSpacing.md,
          horizontal: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: item.completed
              ? AppColors.primarySurface
              : AppColors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutBack,
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: item.completed ? AppColors.white : AppColors.transparent,
                borderRadius: BorderRadius.circular(7),
                border: Border.all(
                  color: item.completed
                      ? AppColors.white
                      : AppColors.textTertiary,
                  width: 1.5,
                ),
              ),
              child: item.completed
                  ? const Icon(
                      Icons.check_rounded,
                      size: 14,
                      color: AppColors.black,
                    )
                  : null,
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(
                item.title,
                style: AppTypography.body.copyWith(
                  color: item.completed
                      ? AppColors.textTertiary
                      : AppColors.textPrimary,
                  decoration: item.completed
                      ? TextDecoration.lineThrough
                      : null,
                ),
              ),
            ),
            if (!item.isRequired)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: AppColors.darkBg,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.darkBorder),
                ),
                child: Text(
                  'optional',
                  style: AppTypography.caption.copyWith(
                    color: AppColors.textTertiary,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ─── Submitted block ────────────────────────────────────────────────

class _SubmittedBlock extends StatelessWidget {
  const _SubmittedBlock({required this.task});
  final TaskEntity task;

  @override
  Widget build(BuildContext context) {
    final notes = task.notes ?? '';
    final media = latestAttachments(task);

    return WorkCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (notes.isNotEmpty) ...[
            const WorkEyebrow('Notes', icon: Icons.notes_rounded),
            const SizedBox(height: AppSpacing.sm),
            Text(
              notes,
              style: AppTypography.body.copyWith(
                color: AppColors.textSecondary,
                height: 1.5,
              ),
            ),
          ],
          if (media.isNotEmpty) ...[
            if (notes.isNotEmpty) const SizedBox(height: AppSpacing.lg),
            const WorkEyebrow('Evidence', icon: Icons.photo_library_outlined),
            const SizedBox(height: AppSpacing.md),
            AttachmentGallery(attachments: media, tileSize: 84),
          ],
        ],
      ),
    );
  }
}

// ─── Employee action area ───────────────────────────────────────────

/// Shown at the top of a terminal task's details. Approved records can be
/// reopened by an admin; missed records are closed after their deadline; a
/// cancelled record additionally carries **why** — the mandatory reason code
/// (Automated Tasks spec §5.5), which is the part of the decision anyone
/// reading the task later actually needs.
class _LockedBanner extends StatelessWidget {
  const _LockedBanner({required this.task, required this.canReopen});
  final TaskEntity task;
  final bool canReopen;

  /// Glyph + tint + headline for each closed outcome. Cancelled is deliberately
  /// neutral: it is a business decision, not a failure (§8), so it must never
  /// wear the error treatment Missed carries.
  (IconData, Color, String) get _tone => switch (task.status) {
    TaskStatus.missed => (
      Icons.event_busy_rounded,
      AppColors.error,
      'Missed and closed. This task can no longer be changed.',
    ),
    TaskStatus.cancelled => (
      Icons.block_rounded,
      AppColors.textSecondary,
      'Cancelled. This work will not be done, and it does not count as '
          'completed or missed.',
    ),
    _ => (
      Icons.lock_outline_rounded,
      AppColors.textSecondary,
      canReopen
          ? 'Approved and locked. Reopen the task to make changes.'
          : 'Approved and locked. This task can no longer be changed.',
    ),
  };

  @override
  Widget build(BuildContext context) {
    final (icon, color, headline) = _tone;
    final reason = task.cancelReason;
    final note = task.cancelNote?.trim() ?? '';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.darkSurfaceElevated,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.darkBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  headline,
                  style: AppTypography.caption.copyWith(
                    color: AppColors.textSecondary,
                    height: 1.4,
                  ),
                ),
                // The reason is the record. It is shown even when the code is
                // one this build doesn't recognise, so a newer client's
                // cancellation never reads as "cancelled, no reason given".
                if (reason != null) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    reason.label,
                    style: AppTypography.labelSmall.copyWith(
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
                if (note.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    note,
                    style: AppTypography.caption.copyWith(
                      color: AppColors.textTertiary,
                      height: 1.4,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// An open "this task is wrong" report (Automated Tasks spec §5.2), shown to
/// everyone who can see the task — the reporter needs to know it landed, and the
/// manager needs to decide.
///
/// The decision lives **here**, next to the complaint, rather than sending the
/// manager off to find the cancel action: Cancel it, or dismiss the report and
/// say the task stands. Warning-tinted because it is an open question, not a
/// failure.
class _ReportedIncorrectBanner extends StatelessWidget {
  const _ReportedIncorrectBanner({
    required this.task,
    required this.cubit,
    required this.directory,
    required this.canDecide,
  });

  final TaskEntity task;
  final TaskCubit cubit;
  final Map<String, UserEntity> directory;
  final bool canDecide;

  String get _reporter {
    final u = directory[task.reportedIncorrectBy];
    if (u == null) return 'An employee';
    final name = u.displayName?.trim();
    return (name != null && name.isNotEmpty) ? name : u.email;
  }

  Future<void> _dismiss(BuildContext context) async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Dismiss this report?',
      message:
          'The task stands as issued and stays assigned. The report is cleared '
          'from the task.',
      confirmLabel: 'Dismiss',
    );
    if (confirmed && context.mounted) cubit.dismissIncorrectReport(task);
  }

  @override
  Widget build(BuildContext context) {
    final note = task.reportedIncorrectNote?.trim() ?? '';
    final at = task.reportedIncorrectAt;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.darkSurfaceElevated,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.warning.withAlpha(90)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.flag_outlined,
                size: 18,
                color: AppColors.warning,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      at == null
                          ? '$_reporter reported this task'
                          : '$_reporter reported this task · ${AppDateFormatter.relative(at)}',
                      style: AppTypography.labelSmall.copyWith(
                        color: AppColors.textPrimary,
                      ),
                    ),
                    if (note.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        note,
                        style: AppTypography.caption.copyWith(
                          color: AppColors.textSecondary,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          if (canDecide) ...[
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                if (task.status.isCancellable)
                  Expanded(
                    child: PremiumButton(
                      label: 'Cancel task',
                      icon: Icons.block_rounded,
                      onPressed: () => showCancelSheet(
                        context: context,
                        cubit: cubit,
                        task: task,
                      ),
                    ),
                  ),
                if (task.status.isCancellable)
                  const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: PremiumButton(
                    label: 'Task stands',
                    icon: Icons.check_rounded,
                    onPressed: () => _dismiss(context),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// The employee's single action for the task's current state, and the animated
/// seam between one state and the next.
///
/// Start / Start Rework are server round trips (100ms–1s). The button used to
/// dim to the disabled 50% for that whole time and then be replaced in one
/// frame — indistinguishable from the app having lagged. It now acknowledges
/// the press on the frame it happens (the CTA's own progress ring) and hands
/// over to the next action through [ActionSwap].
class _EmployeeActions extends StatefulWidget {
  const _EmployeeActions({
    required this.task,
    required this.cubit,
    required this.busy,
  });
  final TaskEntity task;
  final TaskCubit cubit;
  final bool busy;

  @override
  State<_EmployeeActions> createState() => _EmployeeActionsState();
}

class _EmployeeActionsState extends State<_EmployeeActions> {
  /// This screen's start is in flight. Local, because the cubit's `busy` is
  /// global — it says *a* write is running, not that this one is.
  bool _starting = false;

  static bool _isStartable(TaskStatus s) =>
      s == TaskStatus.pending || s == TaskStatus.rejected;

  @override
  void didUpdateWidget(_EmployeeActions old) {
    super.didUpdateWidget(old);
    // Settled — either the new status arrived (the stream carries it while the
    // write is still finishing) or the mutation ended without one, which is a
    // refusal. Both must clear the ring.
    if (_starting &&
        (!widget.busy || !_isStartable(widget.task.status))) {
      _starting = false;
    }
  }

  void _start() {
    setState(() => _starting = true);
    widget.cubit.startTask(widget.task);
  }

  @override
  Widget build(BuildContext context) {
    final task = widget.task;
    final cubit = widget.cubit;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // The action a state entitles the employee to is the one thing on this
        // screen that changes shape, so it is the one thing that animates.
        ActionSwap(child: _primaryAction(context)),
        // The release valve (Automated Tasks spec §5.2). An employee can never
        // cancel — but handing them wrong work with no way to say so is what
        // would make manager-only cancellation inhumane. Deliberately quiet: a
        // text link under the real action, not a competing button. Hidden once a
        // report is open (the banner above then owns the state).
        if (!task.isReportedIncorrect) ...[
          const SizedBox(height: AppSpacing.xs),
          TextButton(
            onPressed: () => showReportIncorrectSheet(
              context: context,
              cubit: cubit,
              task: task,
            ),
            child: Text(
              "Something's wrong with this task",
              style: AppTypography.labelSmall.copyWith(
                color: AppColors.textTertiary,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _primaryAction(BuildContext context) {
    final task = widget.task;
    final cubit = widget.cubit;

    Widget startButton({
      required Key key,
      required String label,
      required IconData icon,
      double iconSize = 20,
    }) {
      final blockedReason = startBlockedReason(task, DateTime.now());
      return Column(
        key: key,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppButton(
            label: label,
            icon: Icon(icon, size: iconSize, color: AppColors.textDark),
            // The ring lands on the frame of the tap and stays until the new
            // status arrives — the round trip is no longer a dead button.
            isLoading: _starting,
            onPressed: blockedReason == null ? _start : null,
          ),
          if (blockedReason != null) ...[
            const SizedBox(height: AppSpacing.xs),
            _StartGateReason(blockedReason),
          ],
        ],
      );
    }

    // Every branch is keyed: ActionSwap can only animate a swap it can see,
    // and two AppButtons without keys are the same widget to Flutter.
    return switch (task.status) {
      TaskStatus.pending => startButton(
        key: const ValueKey('start'),
        label: 'Start Task',
        icon: Icons.play_arrow_rounded,
      ),
      TaskStatus.started => _CompleteButton(
        key: const ValueKey('complete'),
        task: task,
        cubit: cubit,
      ),
      TaskStatus.completed => AppButton(
        key: const ValueKey('submit'),
        label: 'Submit for Review',
        icon: const Icon(
          Icons.send_rounded,
          size: 18,
          color: AppColors.textDark,
        ),
        onPressed: () {
          cubit.submitForReview(task);
          Navigator.of(context).pop();
        },
      ),
      TaskStatus.rejected => startButton(
        key: const ValueKey('rework'),
        label: 'Start Rework',
        icon: Icons.replay_rounded,
        iconSize: 18,
      ),
      TaskStatus.missed => const SizedBox.shrink(key: ValueKey('none')),
      _ => const SizedBox.shrink(key: ValueKey('none')),
    };
  }
}

class _StartGateReason extends StatelessWidget {
  const _StartGateReason(this.reason);

  final String reason;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(
          Icons.schedule_rounded,
          size: 14,
          color: AppColors.textTertiary,
        ),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            reason,
            style: AppTypography.labelSmall.copyWith(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }
}

class _CompleteButton extends StatefulWidget {
  const _CompleteButton({super.key, required this.task, required this.cubit});
  final TaskEntity task;
  final TaskCubit cubit;

  @override
  State<_CompleteButton> createState() => _CompleteButtonState();
}

class _CompleteButtonState extends State<_CompleteButton> {
  List<PickedAttachment> _attachments = [];
  final _notes = TextEditingController();
  bool _expanded = false;

  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final notes = _notes.text.trim();
    // The submission overlay is driven by TaskCubit/TaskState (rendered by the
    // screen), so the button just kicks off the work and leaves on success.
    final ok = await widget.cubit.completeAndSubmit(
      widget.task,
      notes: notes.isEmpty ? null : notes,
      attachments: _attachments,
    );
    // On failure the cubit already surfaced the real error and the selected
    // media is still attached here, so the employee can retry without losing it.
    if (ok && mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    // Opening the submission form is the same kind of moment as a status
    // change — one action giving way to another — so it uses the same seam
    // rather than snapping the page's whole lower half into existence.
    return ActionSwap(
      alignment: Alignment.topCenter,
      child: _expanded ? _form() : _collapsed(context),
    );
  }

  Widget _collapsed(BuildContext context) => AppButton(
    key: const ValueKey('mark-complete'),
    label: 'Mark Complete',
    icon: const Icon(Icons.check_rounded, size: 20, color: AppColors.textDark),
    onPressed: () {
      if (!widget.task.requiredChecklistComplete) {
        AppSnackbar.error(
          context,
          'Complete all required checklist items first.',
        );
        return;
      }
      setState(() => _expanded = true);
    },
  );

  Widget _form() => Column(
    key: const ValueKey('submit-form'),
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      AppTextField(
        controller: _notes,
        label: 'Notes (optional)',
        prefixIcon: Icons.notes_rounded,
      ),
      const SizedBox(height: AppSpacing.md),
      AttachmentPickerField(
        attachments: _attachments,
        onChanged: (list) => setState(() => _attachments = list),
      ),
      const SizedBox(height: AppSpacing.md),
      AppButton(
        label: 'Complete & Submit',
        icon: const Icon(
          Icons.send_rounded,
          size: 20,
          color: AppColors.textDark,
        ),
        onPressed: _submit,
      ),
      const SizedBox(height: AppSpacing.sm),
      AppButton.ghost(
        label: 'Cancel',
        onPressed: () => setState(() => _expanded = false),
      ),
    ],
  );
}

// ─── Manager / admin review block ──────────────────────────────────

class _ReviewBlock extends StatefulWidget {
  const _ReviewBlock({required this.task, required this.cubit});
  final TaskEntity task;
  final TaskCubit cubit;

  @override
  State<_ReviewBlock> createState() => _ReviewBlockState();
}

class _ReviewBlockState extends State<_ReviewBlock> {
  final _notes = TextEditingController();

  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
  }

  String? get _note => _notes.text.trim().isEmpty ? null : _notes.text.trim();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Divider(color: AppColors.darkBorder),
        const SizedBox(height: AppSpacing.md),
        const Text('Review submission', style: AppTypography.h3),
        const SizedBox(height: AppSpacing.lg),
        AppTextField(
          controller: _notes,
          label: 'What needs fixing? (optional)',
          prefixIcon: Icons.rate_review_outlined,
        ),
        const SizedBox(height: AppSpacing.md),
        AppButton(
          label: 'Approve',
          icon: const Icon(
            Icons.check_circle_outline_rounded,
            size: 20,
            color: AppColors.textDark,
          ),
          onPressed: () {
            // Server-authoritative decision — never taken against stale data.
            if (!requireOnline(context, action: 'approving work')) return;
            widget.cubit.approveTask(widget.task, reviewNotes: _note);
            Navigator.of(context).pop();
          },
        ),
        const SizedBox(height: AppSpacing.sm),
        // "Request rework" sends the task back for the employee to fix (bumps
        // the revision → REWORK #n) — a normal workflow step, not destructive.
        AppButton.secondary(
          label: 'Request Rework',
          onPressed: () async {
            if (!requireOnline(context, action: 'requesting rework')) return;
            final confirmed = await showConfirmDialog(
              context,
              title: 'Request rework?',
              message: 'The employee will be asked to fix and resubmit it.',
              confirmLabel: 'Request rework',
            );
            if (confirmed && context.mounted) {
              widget.cubit.reworkTask(widget.task, reviewNotes: _note);
              Navigator.of(context).pop();
            }
          },
        ),
        const SizedBox(height: AppSpacing.xs),
        // Terminal "Reject" — distinct from rework (no resubmit expected); red,
        // destructive confirm.
        TextButton(
          onPressed: () async {
            if (!requireOnline(context, action: 'rejecting work')) return;
            final confirmed = await showConfirmDialog(
              context,
              title: 'Reject task?',
              message:
                  'This rejects the submission. Use Request Rework instead if '
                  'the employee should fix and resubmit it.',
              confirmLabel: 'Reject',
              destructive: true,
            );
            if (confirmed && context.mounted) {
              widget.cubit.rejectTask(widget.task, reviewNotes: _note);
              Navigator.of(context).pop();
            }
          },
          child: Text(
            'Reject',
            style: AppTypography.label.copyWith(color: AppColors.error),
          ),
        ),
      ],
    );
  }
}

// ─── Helpers ─────────────────────────────────────────────────────────

bool _isOverdue(TaskEntity task) {
  final d = task.deadline;
  if (d == null) return false;
  final done =
      task.status.isTerminal ||
      task.status == TaskStatus.completed ||
      task.status == TaskStatus.waitingReview;
  return !done && d.isBefore(DateTime.now());
}

String _dateLabel(DateTime d) => AppDateFormatter.dayMonthYear(d);

String _priorityLabel(TaskPriority p) => switch (p) {
  TaskPriority.high => 'High priority',
  TaskPriority.normal => 'Medium priority',
  TaskPriority.low => 'Low priority',
};
