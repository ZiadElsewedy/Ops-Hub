import 'package:flutter/material.dart';
import 'package:drop/core/enums/task_assignment_type.dart';
import 'package:drop/core/enums/task_priority.dart';
import 'package:drop/core/enums/task_status.dart';
import 'package:drop/core/theme/app_colors.dart';
import 'package:drop/core/theme/app_radius.dart';
import 'package:drop/core/theme/app_spacing.dart';
import 'package:drop/core/theme/app_typography.dart';
import 'package:drop/core/utils/app_date_formatter.dart';
import 'package:drop/core/widgets/status_badge.dart';
import 'package:drop/features/auth/domain/entities/user_entity.dart';
import 'package:drop/features/task/domain/entities/task_entity.dart';
import 'package:drop/features/task/domain/task_feed.dart';
import 'package:drop/features/task/presentation/widgets/task_browser_groups.dart';

/// The scannable task row — **two lines, one job each**:
///
/// ```
///   Open the shop                                   6:00 PM
///   ● In progress · Arkan · Ziad Elsewedy · 3/5 steps      ›
/// ```
///
/// The redesign (2026-08-04) replaced a single line that gave the title, a
/// status label, a bordered branch chip, an avatar and a date roughly equal
/// weight, all competing for the same 390pt. Every element there could steal
/// width from the title, so the one thing a reader is actually looking for —
/// *what is this task* — was the first thing to ellipsize.
///
/// Now the title owns the full first line and truncates only against the date,
/// and everything secondary drops to one quiet meta line that ellipsizes from
/// the end as a single string, so it can never fragment into three half-words.
///
/// Colour comes from the canonical [taskStatusColor] (no third status→colour
/// map) and is spent only on the status dot + word and on a genuinely late date.
/// Priority shows **only when High**.
///
/// The row is one soft, rounded touch surface with the separator underneath it,
/// inset to the same [kTaskRowInset] — never a square-cornered band bleeding to
/// both edges of the screen.
/// How far the row's content sits inside its own touch surface. Shared with the
/// section header and the separator so the label, every title and the rule all
/// hang off **one** vertical line — while the rounded highlight breathes past
/// it on both sides.
const double kTaskRowInset = AppSpacing.md;

class TaskFeedRow extends StatelessWidget {
  const TaskFeedRow({
    super.key,
    required this.task,
    this.directory = const {},
    this.branchName,
    this.onTap,
    this.selected = false,
    this.showBranch = true,
    this.showAssignee = true,
    this.showDivider = true,
  });

  final TaskEntity task;
  final Map<String, UserEntity> directory;
  final String? branchName;
  final VoidCallback? onTap;

  /// Name the branch on the meta line. Pass false when the surrounding list is
  /// **already branch-scoped** — every row would repeat the same word.
  final bool showBranch;

  /// Name the assignee on the meta line. Pass false when the surrounding list is
  /// **already scoped to one person** (their detail screen), where repeating
  /// their name on every row is pure noise.
  final bool showAssignee;

  /// When true the row is the currently-expanded one (subtle highlight).
  final bool selected;

  /// Draw the hairline under the row. False for the last row of a section,
  /// where the next section header brings its own rule.
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    final color = taskStatusColor(task.status);
    final overdue = isTaskOverdue(task, DateTime.now());
    final meta = _meta();

    return Semantics(
      button: onTap != null,
      label: '${taskRowStatusLabel(task.status)} task: ${task.title}',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // The press / hover surface is a **rounded, inset** rectangle, not a
          // square-cornered band running the full width of the screen. A sharp
          // full-bleed slab is the single cheapest-looking thing a dark list can
          // do; a soft contained highlight is what makes a row feel like an
          // object you are touching.
          InkWell(
            onTap: onTap,
            borderRadius: AppRadius.mdAll,
            // A translucent lift, not a fixed grey: the row sits on the page
            // background in one place and on a card's own elevated surface in
            // another, and an opaque hover colour is invisible against the
            // second.
            hoverColor: AppColors.white.withAlpha(12),
            child: Container(
              decoration: BoxDecoration(
                color: selected ? AppColors.darkSurfaceElevated : null,
                borderRadius: AppRadius.mdAll,
              ),
              padding: const EdgeInsets.symmetric(
                horizontal: kTaskRowInset,
                vertical: AppSpacing.md,
              ),
              child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── line 1 · the title, and only the date beside it ──
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Expanded(
                          child: Text(
                            task.title,
                            style: AppTypography.label.copyWith(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              height: 1.25,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        _DueLabel(task: task, overdue: overdue),
                      ],
                    ),
                    const SizedBox(height: 5),

                    // ── line 2 · state first, then everything supporting ──
                    Row(
                      children: [
                        if (task.priority == TaskPriority.high) ...[
                          const Icon(
                            Icons.flag_rounded,
                            size: 12,
                            color: AppColors.error,
                          ),
                          const SizedBox(width: 6),
                        ],
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          taskRowStatusLabel(task.status),
                          style: AppTypography.caption.copyWith(
                            color: color,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        if (meta.isNotEmpty) ...[
                          const _MetaDot(),
                          // One string, one ellipsis: the meta line shortens
                          // from its tail instead of every part shrinking into
                          // a row of unreadable stubs.
                          Expanded(
                            child: Text(
                              meta,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTypography.caption.copyWith(
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              // No per-row chevron. Thirty rows meant thirty identical glyphs
              // saying the same thing the whole tappable row already says, and
              // each one took width from the title. The collapse affordance is
              // drawn only where it carries information: on the expanded row of
              // the desktop accordion.
                  if (selected) ...[
                    const SizedBox(width: AppSpacing.sm),
                    const Icon(
                      Icons.expand_less_rounded,
                      size: 16,
                      color: AppColors.textTertiary,
                    ),
                  ],
                ],
              ),
            ),
          ),
          // The rule sits **under** the highlight and stops short of the row's
          // ends, so it separates two rows instead of drawing a hard line right
          // through the soft rectangle above it.
          if (showDivider)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: kTaskRowInset),
              child: SizedBox(
                height: 1,
                child: ColoredBox(color: AppColors.darkBorder),
              ),
            ),
        ],
      ),
    );
  }

  /// The supporting facts, in decreasing usefulness, joined into one line.
  /// Anything that would repeat the surrounding list's own scope is omitted by
  /// the caller rather than drawn and then ignored.
  String _meta() {
    final assignee = showAssignee ? _assignee() : null;
    return [
      if (showBranch && (branchName ?? '').isNotEmpty) branchName!,
      ?assignee,
      if (task.hasChecklist)
        '${task.checklistDone}/${task.checklistTotal} steps',
    ].join(' · ');
  }

  String? _assignee() {
    if (task.assignmentType == TaskAssignmentType.shift) {
      final shift = task.shift;
      return shift == null ? 'Shift task' : '${shift.label} shift';
    }
    if (task.assigneeIds.isEmpty) return 'Unassigned';
    final resolved = [for (final uid in task.assigneeIds) ?directory[uid]];
    if (resolved.isEmpty) return '${task.assigneeIds.length} assigned';
    if (resolved.length == 1) {
      final user = resolved.first;
      return (user.displayName?.isNotEmpty ?? false)
          ? user.displayName!
          : user.email;
    }
    return '${resolved.length} people';
  }
}

/// The row's friendly status label, kept local (like `TaskCard`) so the row
/// doesn't fork a third status→colour map — only the short label is row-local.
/// Public so the browser's lens rail names a status exactly the way the rows
/// under it do.
String taskRowStatusLabel(TaskStatus s) => switch (s) {
  TaskStatus.pending => 'To do',
  TaskStatus.started => 'In progress',
  TaskStatus.completed => 'Completed',
  TaskStatus.waitingReview => 'In review',
  TaskStatus.approved => 'Approved',
  TaskStatus.rejected => 'Rejected',
  TaskStatus.missed => 'Missed',
  TaskStatus.cancelled => 'Cancelled',
};

/// The separator between meta facts — dim enough that the eye reads the facts,
/// not the punctuation.
class _MetaDot extends StatelessWidget {
  const _MetaDot();

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 6),
    child: Text(
      '·',
      style: AppTypography.caption.copyWith(color: AppColors.textQuaternary),
    ),
  );
}

/// The one date on the row — and it answers the question the row's *section* is
/// asking. Open work is stamped with its deadline; a **record** is stamped with
/// when it actually closed.
///
/// Before this, a list section headed "Closed today" showed each row's deadline,
/// so one row read `4:30 PM` (its deadline happened to be today) and the row
/// under it read `5 Aug` — two different clocks in one section, neither of them
/// the date the section had just promised.
class _DueLabel extends StatelessWidget {
  const _DueLabel({required this.task, required this.overdue});
  final TaskEntity task;
  final bool overdue;

  @override
  Widget build(BuildContext context) {
    final record = isTaskRecord(task);
    final d = record ? taskRecordDate(task) : task.deadline;
    if (d == null) {
      return Text(
        '—',
        style: AppTypography.caption.copyWith(color: AppColors.textQuaternary),
      );
    }
    // A date landing today is a time, not a date: "6:00 PM" is the fact a shift
    // manager needs, and "5 Aug" on the 5th of August tells them nothing.
    final now = DateTime.now();
    final isToday =
        d.year == now.year && d.month == now.month && d.day == now.day;
    final label = isToday
        ? AppDateFormatter.time(d)
        : AppDateFormatter.dayMonth(d);
    return Text(
      overdue ? '$label · late' : label,
      textAlign: TextAlign.right,
      style: AppTypography.caption.copyWith(
        color: overdue ? AppColors.error : AppColors.textTertiary,
        fontWeight: overdue ? FontWeight.w600 : FontWeight.w400,
      ),
    );
  }
}
