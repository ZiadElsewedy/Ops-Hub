import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:drop/core/enums/attachment_type.dart';
import 'package:drop/core/enums/task_assignment_type.dart';
import 'package:drop/core/enums/task_status.dart';
import 'package:drop/core/services/usage_tracker.dart';
import 'package:drop/core/theme/app_colors.dart';
import 'package:drop/core/theme/app_spacing.dart';
import 'package:drop/core/theme/app_typography.dart';
import 'package:drop/core/utils/app_date_formatter.dart';
import 'package:drop/core/widgets/user_avatar.dart';
import 'package:drop/core/widgets/connectivity_scope.dart';
import 'package:drop/features/auth/domain/entities/user_entity.dart';
import 'package:drop/features/task/domain/entities/activity_entry.dart';
import 'package:drop/features/task/domain/entities/task_attachment.dart';
import 'package:drop/features/task/domain/entities/task_entity.dart';
import 'package:drop/features/task/domain/note_category.dart';
import 'package:drop/features/task/presentation/activity_format.dart';
import 'package:drop/features/task/presentation/cubit/task_cubit.dart';
import 'package:drop/features/task/domain/task_feed.dart';
import 'package:drop/features/task/presentation/widgets/task_action_sheets.dart';
import 'package:drop/features/task/presentation/widgets/task_card.dart'
    show TaskActionButton, resolveAssignees;

/// The **shared** expanded triage surface for a feed row (Home Dashboard
/// redesign, R1). Rendered two ways from the SAME widget:
///   * desktop → inline under the row (accordion),
///   * mobile  → inside a bottom sheet.
///
/// Shows the routine-triage essentials (description · checklist + progress ·
/// attachments · assignee/branch/shift/due · a compact status timeline) and the
/// quick actions (Approve · Reject · Reassign · Open full details) wired to the
/// app-wide [TaskCubit] — **no new cubit**. [onClose] collapses the accordion
/// (desktop) or pops the sheet (mobile); [onOpenDetails] pushes the full screen.
class TaskFeedExpansion extends StatelessWidget {
  const TaskFeedExpansion({
    super.key,
    required this.task,
    required this.directory,
    required this.onOpenDetails,
    this.branchName,
    this.onClose,
    this.showActions = true,
  });

  final TaskEntity task;
  final Map<String, UserEntity> directory;
  final VoidCallback onOpenDetails;
  final String? branchName;
  final VoidCallback? onClose;

  /// Inline the action row at the bottom (desktop accordion). Set false when a
  /// caller pins [TaskFeedActions] as a sticky footer (the mobile bottom sheet).
  final bool showActions;

  @override
  Widget build(BuildContext context) {
    final overdue = isTaskOverdue(task, DateTime.now());
    final description = (task.description ?? '').trim();
    final attachments = <TaskAttachment>[
      ...task.referenceAttachments,
      for (final e in task.activityLog) ...e.attachments,
    ];
    final timeline = [...task.activityLog]
      ..sort((a, b) => b.at.compareTo(a.at));

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.darkBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.darkBorder),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (description.isNotEmpty) ...[
            Text(
              description,
              style: AppTypography.bodySmall.copyWith(height: 1.5),
            ),
            const SizedBox(height: AppSpacing.md),
          ],

          // ── Facts (branch · shift · due · assignee) ──
          _info('Branch', Text(branchName ?? '—', style: _valueStyle)),
          if (task.shift != null)
            _info(
              'Shift',
              Text('${task.shift!.label} shift', style: _valueStyle),
            ),
          _info(
            'Due',
            Text(
              task.deadline == null
                  ? 'No due date'
                  : AppDateFormatter.dayMonth(task.deadline!),
              style: _valueStyle.copyWith(
                color: overdue ? AppColors.error : AppColors.textPrimary,
              ),
            ),
          ),
          _info('Assignee', _assignee()),

          // ── Checklist preview + progress ──
          if (task.hasChecklist) ...[
            const SizedBox(height: AppSpacing.md),
            _ChecklistPreview(task: task),
          ],

          // ── Attachments / proof thumbnails ──
          if (attachments.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            _sectionLabel('Attachments'),
            const SizedBox(height: 6),
            _Thumbs(attachments: attachments),
          ],

          // ── Status timeline (compact, newest-first) ──
          if (timeline.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            _sectionLabel('Timeline'),
            const SizedBox(height: 6),
            for (final e in timeline.take(3))
              _TimelineRow(task: task, entry: e),
          ],

          // ── Quick actions (inline on desktop; pinned footer on mobile) ──
          if (showActions) ...[
            const SizedBox(height: AppSpacing.md),
            TaskFeedActions(
              task: task,
              onOpenDetails: onOpenDetails,
              onClose: onClose,
            ),
          ],
        ],
      ),
    );
  }

  Widget _assignee() {
    if (task.assignmentType == TaskAssignmentType.shift) {
      return Text(
        task.shift == null ? 'Shift task' : '${task.shift!.label} shift',
        style: _valueStyle,
      );
    }
    final resolved = resolveAssignees(task, directory);
    if (resolved.isEmpty) return Text('Unassigned', style: _valueStyle);
    if (resolved.length == 1) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          UserAvatar.fromUser(resolved.first, size: 20),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              _name(resolved.first),
              style: _valueStyle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      );
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        AvatarStack(users: resolved, size: 20),
        const SizedBox(width: 6),
        Text('${resolved.length} assigned', style: _valueStyle),
      ],
    );
  }

  static Widget _info(String label, Widget value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 76,
          child: Text(
            label,
            style: AppTypography.caption.copyWith(
              color: AppColors.textTertiary,
            ),
          ),
        ),
        Expanded(child: value),
      ],
    ),
  );

  static Widget _sectionLabel(String s) => Text(
    s.toUpperCase(),
    style: AppTypography.caption.copyWith(
      color: AppColors.textTertiary,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.5,
    ),
  );

  static String _name(UserEntity u) =>
      (u.displayName?.isNotEmpty ?? false) ? u.displayName! : u.email;

  static final _valueStyle = AppTypography.bodySmall.copyWith(
    color: AppColors.textPrimary,
  );
}

/// The feed's quick-action row — shared by the desktop inline surface and the
/// mobile sticky footer. **Approve is proof-safe** (a submission carrying proof
/// gets a lightweight confirm sheet first); **Note** appends a timeline comment
/// with no status change; Reject/Reassign reuse the canonical sheets.
class TaskFeedActions extends StatelessWidget {
  const TaskFeedActions({
    super.key,
    required this.task,
    required this.onOpenDetails,
    this.onClose,
  });

  final TaskEntity task;
  final VoidCallback onOpenDetails;
  final VoidCallback? onClose;

  bool get _hasProof =>
      task.activityLog.any((e) => e.attachments.isNotEmpty) ||
      (task.proofImageUrl?.isNotEmpty ?? false);

  @override
  Widget build(BuildContext context) {
    // Missed and cancelled are both closed records: no reassigning, no notes.
    // (Approved is handled separately below — it has an admin reopen path.)
    final isClosed =
        task.status == TaskStatus.missed ||
        task.status == TaskStatus.cancelled;
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.xs,
      children: [
        if (task.status == TaskStatus.waitingReview) ...[
          TaskActionButton(
            label: 'Approve',
            icon: Icons.check_circle_outline_rounded,
            onPressed: () => _approve(context),
          ),
          TaskActionButton(
            label: 'Reject',
            icon: Icons.replay_rounded,
            color: AppColors.error,
            onPressed: () => _reject(context),
          ),
        ],
        if (task.status != TaskStatus.approved &&
            !isClosed &&
            task.assignmentType != TaskAssignmentType.shift)
          TaskActionButton(
            label: 'Reassign',
            icon: Icons.person_add_alt_1_outlined,
            onPressed: () => _reassign(context),
          ),
        if (!isClosed)
          TaskActionButton(
            label: 'Note',
            icon: Icons.chat_bubble_outline_rounded,
            onPressed: () => _note(context),
          ),
        TaskActionButton(
          label: 'Open full details',
          icon: Icons.open_in_full_rounded,
          onPressed: onOpenDetails,
        ),
      ],
    );
  }

  Future<void> _approve(BuildContext context) async {
    if (!requireOnline(context, action: 'approving work')) return;
    final cubit = context.read<TaskCubit>();
    // Proof-safety: never one-tap approve evidence you haven't looked at.
    if (_hasProof && await _showApproveConfirm(context, task) != true) return;
    cubit.approveTask(task);
    UsageTracker.track('quick_approve');
    onClose?.call();
  }

  Future<void> _reject(BuildContext context) async {
    await showReviewSheet(
      context: context,
      cubit: context.read<TaskCubit>(),
      task: task,
    );
    onClose?.call();
  }

  Future<void> _reassign(BuildContext context) async {
    await showAssignSheet(
      context: context,
      cubit: context.read<TaskCubit>(),
      task: task,
    );
    onClose?.call();
  }

  Future<void> _note(BuildContext context) async {
    final cubit = context.read<TaskCubit>();
    final result = await _showNoteSheet(context);
    if (result != null && result.text.trim().isNotEmpty) {
      await cubit.addNote(task, result.text, category: result.category);
      UsageTracker.track('note_create');
    }
  }
}

/// Lightweight approve-with-proof confirmation — shows the submitted evidence,
/// then Approve / Cancel. Returns true only on explicit approve.
Future<bool?> _showApproveConfirm(BuildContext context, TaskEntity task) {
  final proof = <TaskAttachment>[
    for (final e in task.activityLog) ...e.attachments,
  ];
  return showModalBottomSheet<bool>(
    context: context,
    backgroundColor: AppColors.darkSurface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (ctx) => Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.pagePadding,
        AppSpacing.lg,
        AppSpacing.pagePadding,
        MediaQuery.of(ctx).viewInsets.bottom + AppSpacing.xl,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.verified_outlined,
                size: 20,
                color: AppColors.success,
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                'Approve this task?',
                style: AppTypography.label.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            '"${task.title}" — review the submitted proof before you approve.',
            style: AppTypography.bodySmall,
          ),
          if (proof.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            _Thumbs(attachments: proof),
          ],
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              Expanded(
                child: _SheetButton(
                  label: 'Cancel',
                  onTap: () => Navigator.of(ctx).pop(false),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: _SheetButton(
                  label: 'Approve',
                  filled: true,
                  onTap: () => Navigator.of(ctx).pop(true),
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

/// A quick operational note input (bottom sheet) — text + a category (info /
/// warning / issue). Returns the pair, or null on dismiss.
Future<({String text, NoteCategory category})?> _showNoteSheet(
  BuildContext context,
) {
  return showModalBottomSheet<({String text, NoteCategory category})>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.darkSurface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (ctx) => const _NoteSheet(),
  );
}

class _NoteSheet extends StatefulWidget {
  const _NoteSheet();
  @override
  State<_NoteSheet> createState() => _NoteSheetState();
}

class _NoteSheetState extends State<_NoteSheet> {
  final _controller = TextEditingController();
  NoteCategory _category = NoteCategory.info;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() =>
      Navigator.of(context).pop((text: _controller.text, category: _category));

  Color _categoryColor(NoteCategory c) => switch (c) {
    NoteCategory.info => AppColors.textSecondary,
    NoteCategory.warning => AppColors.warning,
    NoteCategory.issue => AppColors.error,
  };

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.pagePadding,
        AppSpacing.lg,
        AppSpacing.pagePadding,
        MediaQuery.of(context).viewInsets.bottom + AppSpacing.xl,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Add a note',
            style: AppTypography.label.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          // Category selector.
          Row(
            children: [
              for (final c in NoteCategory.values) ...[
                _CategoryChip(
                  label: c.label,
                  color: _categoryColor(c),
                  selected: _category == c,
                  onTap: () => setState(() => _category = c),
                ),
                const SizedBox(width: AppSpacing.sm),
              ],
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _controller,
            autofocus: true,
            maxLines: 3,
            minLines: 1,
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.textPrimary,
            ),
            decoration: InputDecoration(
              hintText: 'e.g. Front shelf still needs restocking',
              hintStyle: AppTypography.bodySmall.copyWith(
                color: AppColors.textTertiary,
              ),
              filled: true,
              fillColor: AppColors.darkSurfaceElevated,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.darkBorder),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.darkBorder),
              ),
            ),
            onSubmitted: (_) => _submit(),
          ),
          const SizedBox(height: AppSpacing.md),
          _SheetButton(label: 'Add note', filled: true, onTap: _submit),
        ],
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
    required this.label,
    required this.color,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? color.withAlpha(30) : AppColors.darkSurfaceElevated,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected ? color.withAlpha(140) : AppColors.darkBorder,
          ),
        ),
        child: Text(
          label,
          style: AppTypography.caption.copyWith(
            color: selected ? color : AppColors.textSecondary,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ),
    );
  }
}

class _SheetButton extends StatelessWidget {
  const _SheetButton({
    required this.label,
    required this.onTap,
    this.filled = false,
  });
  final String label;
  final VoidCallback onTap;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        height: 44,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: filled ? AppColors.primary : AppColors.darkSurfaceElevated,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: filled ? AppColors.primary : AppColors.darkBorder,
          ),
        ),
        child: Text(
          label,
          style: AppTypography.label.copyWith(
            color: filled ? AppColors.onPrimary : AppColors.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _ChecklistPreview extends StatelessWidget {
  const _ChecklistPreview({required this.task});
  final TaskEntity task;

  @override
  Widget build(BuildContext context) {
    final complete = task.checklistDone == task.checklistTotal;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Checklist',
              style: AppTypography.caption.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            Text(
              '${task.checklistDone} of ${task.checklistTotal}',
              style: AppTypography.caption.copyWith(
                color: complete ? AppColors.success : AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(99),
          child: LinearProgressIndicator(
            value: task.checklistProgress,
            minHeight: 3,
            backgroundColor: AppColors.darkSurfaceElevated,
            valueColor: AlwaysStoppedAnimation(
              complete ? AppColors.success : AppColors.textPrimary,
            ),
          ),
        ),
        const SizedBox(height: 8),
        for (final item in task.checklist.take(4))
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              children: [
                Icon(
                  item.completed
                      ? Icons.check_circle_rounded
                      : Icons.radio_button_unchecked_rounded,
                  size: 15,
                  color: item.completed
                      ? AppColors.success
                      : AppColors.textTertiary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    item.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.caption.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        if (task.checklistTotal > 4)
          Padding(
            padding: const EdgeInsets.only(top: 2, left: 23),
            child: Text(
              '+${task.checklistTotal - 4} more',
              style: AppTypography.caption.copyWith(
                color: AppColors.textTertiary,
              ),
            ),
          ),
      ],
    );
  }
}

class _Thumbs extends StatelessWidget {
  const _Thumbs({required this.attachments});
  final List<TaskAttachment> attachments;

  @override
  Widget build(BuildContext context) {
    final shown = attachments.take(8).toList();
    return SizedBox(
      height: 56,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: shown.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final a = shown[i];
          return ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Container(
              width: 56,
              height: 56,
              color: AppColors.darkSurfaceElevated,
              child: a.type == AttachmentType.video
                  ? const Icon(
                      Icons.play_circle_outline_rounded,
                      size: 22,
                      color: AppColors.textSecondary,
                    )
                  : Image.network(
                      a.url,
                      fit: BoxFit.cover,
                      cacheWidth: 120,
                      errorBuilder: (_, _, _) => const Icon(
                        Icons.broken_image_outlined,
                        size: 18,
                        color: AppColors.textTertiary,
                      ),
                    ),
            ),
          );
        },
      ),
    );
  }
}

class _TimelineRow extends StatelessWidget {
  const _TimelineRow({required this.task, required this.entry});
  final TaskEntity task;
  final ActivityEntry entry;

  @override
  Widget build(BuildContext context) {
    final color = activityColor(entry.status);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(activityIcon(entry.status), size: 14, color: color),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '${entry.actorName ?? 'Someone'} · ${activityTitle(entry.status)}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.caption.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            relativeTime(entry.at),
            style: AppTypography.caption.copyWith(
              color: AppColors.textTertiary,
            ),
          ),
        ],
      ),
    );
  }
}
