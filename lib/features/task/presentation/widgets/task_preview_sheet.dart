import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:opshub/core/routes/app_page_route.dart';
import 'package:opshub/core/enums/attachment_type.dart';
import 'package:opshub/core/enums/task_assignment_type.dart';
import 'package:opshub/core/enums/task_status.dart';
import 'package:opshub/core/theme/app_colors.dart';
import 'package:opshub/core/theme/app_radius.dart';
import 'package:opshub/core/theme/app_spacing.dart';
import 'package:opshub/core/theme/app_typography.dart';
import 'package:opshub/core/utils/app_date_formatter.dart';
import 'package:opshub/core/widgets/status_badge.dart';
import 'package:opshub/core/widgets/user_avatar.dart';
import 'package:opshub/features/auth/domain/entities/user_entity.dart';
import 'package:opshub/features/task/domain/entities/activity_entry.dart';
import 'package:opshub/features/task/domain/entities/task_attachment.dart';
import 'package:opshub/features/task/domain/entities/task_entity.dart';
import 'package:opshub/features/task/domain/task_feed.dart';
import 'package:opshub/features/task/domain/task_outcomes.dart';
import 'package:opshub/features/task/presentation/activity_format.dart';
import 'package:opshub/features/task/presentation/cubit/task_cubit.dart';
import 'package:opshub/features/task/presentation/pages/task_details_screen.dart';
import 'package:opshub/features/task/presentation/widgets/task_card.dart' show resolveAssignees;
import 'package:opshub/features/task/presentation/widgets/task_feed_expansion.dart' show TaskFeedActions;

/// The shared **task preview → optional full details** navigation pattern (OpsHub
/// Design System V2). Tapping a task anywhere on the dashboard opens a draggable
/// preview sheet — a read of the task plus its quick actions and a sticky footer
/// — so the admin can triage without ever leaving the dashboard (scroll + state
/// preserved). "Open full details" is a deliberate second step, not the default.
///
/// **Redesigned 2026-08-01** ("the answer first"): the sheet used to stack
/// [TaskFeedRow] + [TaskFeedExpansion] — a dense monitoring row followed by a
/// flat label/value grid, reading like a debug dump. This build is local to
/// this file rather than reused from those two widgets, because they are
/// **shared with the dashboard feed** (`TaskFeedSection`'s accordion) and must
/// not change shape there. Presentation only — the quick-action wiring
/// ([TaskFeedActions]) is unchanged and still owns every mutation.
void openTaskDetails(
  BuildContext context,
  TaskEntity task,
  Map<String, UserEntity> directory,
) {
  Navigator.of(context).push(
    appPageRoute<void>(
      transitionDuration: const Duration(milliseconds: 260),
      builder: (_) => TaskDetailsScreen(task: task, directory: directory),
    ),
  );
}

/// Open the draggable task preview sheet for [task]. [branchName] is resolved
/// from the live [TaskCubit] directory when omitted. "Open full details" pops the
/// sheet and pushes [TaskDetailsScreen] on the caller's navigator.
void showTaskPreviewSheet(
  BuildContext context, {
  required TaskEntity task,
  required Map<String, UserEntity> directory,
  String? branchName,
}) {
  final resolvedBranch =
      branchName ?? context.read<TaskCubit>().branchNames[task.branchId];
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.darkSurface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (ctx) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.94,
      // Scrollable body + a PINNED action footer (stays visible as content
      // grows) — the triage surface's sticky-footer requirement.
      builder: (ctx, scroll) => Column(
        children: [
          Container(
            width: 36,
            height: 4,
            margin: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
            decoration: BoxDecoration(
              color: AppColors.darkBorder,
              borderRadius: BorderRadius.circular(99),
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              controller: scroll,
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.pagePadding,
                AppSpacing.xs,
                AppSpacing.pagePadding,
                AppSpacing.md,
              ),
              child: _PreviewBody(
                task: task,
                directory: directory,
                branchName: resolvedBranch,
              ),
            ),
          ),
          Container(
            width: double.infinity,
            padding: EdgeInsets.fromLTRB(
              AppSpacing.pagePadding,
              AppSpacing.md,
              AppSpacing.pagePadding,
              MediaQuery.of(ctx).padding.bottom + AppSpacing.md,
            ),
            decoration: const BoxDecoration(
              color: AppColors.darkSurface,
              border: Border(top: BorderSide(color: AppColors.darkBorder)),
            ),
            child: TaskFeedActions(
              task: task,
              onOpenDetails: () {
                Navigator.of(ctx).pop();
                openTaskDetails(context, task, directory);
              },
              onClose: () => Navigator.of(ctx).maybePop(),
            ),
          ),
        ],
      ),
    ),
  );
}

/// The sheet's whole scrollable read: situation → facts → checklist/proof →
/// timeline. Grouped top to bottom by *how much a manager acts on it* — the
/// situation is the thing to read; the timeline is the thing to check.
class _PreviewBody extends StatelessWidget {
  const _PreviewBody({
    required this.task,
    required this.directory,
    required this.branchName,
  });

  final TaskEntity task;
  final Map<String, UserEntity> directory;
  final String? branchName;

  @override
  Widget build(BuildContext context) {
    final description = (task.description ?? '').trim();
    final attachments = <TaskAttachment>[
      ...task.referenceAttachments,
      for (final e in task.activityLog) ...e.attachments,
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SituationHeader(task: task, directory: directory),
        if (description.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.md),
          // A left-accent quote block so the brief reads as intentional copy
          // rather than raw text floating under the header.
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.md, AppSpacing.sm + 2, AppSpacing.md, AppSpacing.sm + 2),
            decoration: const BoxDecoration(
              border: Border(
                left: BorderSide(color: AppColors.accent, width: 2.5),
              ),
            ),
            child: Text(
              description,
              style: AppTypography.body.copyWith(
                color: AppColors.textSecondary,
                height: 1.5,
              ),
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.lg),
        _FactsCard(task: task, directory: directory, branchName: branchName),
        if (task.hasChecklist) ...[
          const SizedBox(height: AppSpacing.md),
          _ChecklistSummary(task: task),
        ],
        if (attachments.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.lg),
          _sectionLabel('Proof & attachments'),
          const SizedBox(height: AppSpacing.sm),
          _AttachmentStrip(attachments: attachments),
        ],
        if (task.activityLog.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.lg),
          _sectionLabel('Timeline'),
          const SizedBox(height: AppSpacing.sm),
          _TimelineSection(task: task, directory: directory),
        ],
      ],
    );
  }
}

Text _sectionLabel(String s) => Text(
  s.toUpperCase(),
  style: AppTypography.caption.copyWith(
    color: AppColors.textTertiary,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.5,
  ),
);

// ─── The answer, first ─────────────────────────────────────────────

/// The headline **situation**: a status glyph, the title, and one plain-
/// language sentence stating the state *and its consequence* — "Approved by
/// Ziad · 1m late", "Missed · deadline passed 21h ago, closed automatically".
/// This is read before any field grid; the grid underneath is reference
/// material, not the answer.
class _SituationHeader extends StatelessWidget {
  const _SituationHeader({required this.task, required this.directory});
  final TaskEntity task;
  final Map<String, UserEntity> directory;

  @override
  Widget build(BuildContext context) {
    // The single canonical status→colour source (`taskStatusColor`) — never a
    // fourth status→colour map. Approved's green is the same quiet accent it
    // already wears on the status pill everywhere else, not a new hue; the
    // sentence's *legibility* comes from hierarchy and the glyph shape, not
    // from leaning harder on colour (ADR-004).
    final color = taskStatusColor(task.status);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            // A soft top-lit fill + a low glow gives the status glyph real depth
            // instead of a flat tinted disc — the premium touch, still monochrome
            // per status (ADR-004: colour expresses status only).
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [color.withAlpha(48), color.withAlpha(18)],
            ),
            border: Border.all(color: color.withAlpha(110)),
            boxShadow: [
              BoxShadow(
                color: color.withAlpha(28),
                blurRadius: 16,
                spreadRadius: -3,
              ),
            ],
          ),
          // The activity icon set already gives every status a distinct glyph
          // shape (check / hourglass / replay / event-busy / block …) — reused
          // rather than forking a fifth icon map for one header.
          child: Icon(activityIcon(task.status.value), size: 20, color: color),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                task.title,
                style: AppTypography.h3,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 3),
              Text(
                _situation(task, directory, DateTime.now()),
                style: AppTypography.body,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Composes the situation sentence — see [_SituationHeader]. Verified against
/// the code, not assumed: mirrors `isTaskOverdue` (`task_feed.dart`) for "past
/// its deadline and still open", and `taskLateness` (`task_outcomes.dart`) for
/// "finished after its deadline" — the two are deliberately different
/// questions (Automated Tasks spec §10.4) and this function never conflates
/// them into one "late" flag.
String _situation(
  TaskEntity task,
  Map<String, UserEntity> directory,
  DateTime now,
) {
  switch (task.status) {
    case TaskStatus.approved:
      final decider = resolveDeciderName(task.approvedBy, directory);
      final late = taskLateness(task);
      return late == null
          ? 'Approved by $decider'
          : 'Approved by $decider · ${formatLateness(late)}';
    case TaskStatus.rejected:
      final decider = resolveDeciderName(task.rejectedBy, directory);
      final d = task.deadline;
      if (d != null && isTaskOverdue(task, now)) {
        return 'Rejected by $decider · deadline passed '
            '${AppDateFormatter.relative(d, now: now)}';
      }
      return 'Rejected by $decider';
    case TaskStatus.cancelled:
      final decider = resolveDeciderName(task.cancelledBy, directory);
      final reason = task.cancelReason?.label;
      return reason == null
          ? 'Cancelled by $decider'
          : 'Cancelled by $decider · $reason';
    case TaskStatus.missed:
      final d = task.deadline;
      // Closed by the automated sweep — nobody decided this, so nobody is
      // named (the exact "by Creator" bug the card footer fix exists for).
      return d == null
          ? 'Missed · closed automatically'
          : 'Missed · deadline passed '
                '${AppDateFormatter.relative(d, now: now)}, closed automatically';
    case TaskStatus.waitingReview:
      return 'Submitted, waiting on a decision';
    case TaskStatus.completed:
      return 'Marked done · not yet submitted for review';
    case TaskStatus.pending:
    case TaskStatus.started:
      final base = task.status == TaskStatus.pending
          ? 'Not started yet'
          : 'In progress';
      final d = task.deadline;
      if (d == null) return base;
      if (isTaskOverdue(task, now)) {
        return '$base · deadline passed ${AppDateFormatter.relative(d, now: now)}';
      }
      return '$base · due ${AppDateFormatter.dayMonth(d)}';
  }
}

// ─── Facts — fewer, better grouped ──────────────────────────────────

/// Reference material under the situation sentence: **branch + shift merged**
/// onto one line, **due + lateness merged** onto one line, and the assignee —
/// three rows in place of the former four-row label/value grid.
class _FactsCard extends StatelessWidget {
  const _FactsCard({
    required this.task,
    required this.directory,
    required this.branchName,
  });

  final TaskEntity task;
  final Map<String, UserEntity> directory;
  final String? branchName;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final overdue = isTaskOverdue(task, now);
    final lateness = taskLateness(task);
    final due = task.deadline;

    final branchShift = [
      if ((branchName ?? '').isNotEmpty) branchName!,
      if (task.shift != null) '${task.shift!.label} shift',
    ].join(' · ');

    String? dueLabel;
    Color? dueTone;
    if (due != null) {
      final day = AppDateFormatter.dayMonth(due);
      if (lateness != null) {
        dueLabel = 'Due $day · ${formatLateness(lateness)}';
      } else if (overdue) {
        dueLabel = 'Due $day · Late';
        dueTone = AppColors.error;
      } else {
        dueLabel = 'Due $day';
      }
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: AppColors.darkBg,
        borderRadius: AppRadius.lgAll,
        border: Border.all(color: AppColors.darkBorder),
      ),
      child: Column(
        children: [
          if (branchShift.isNotEmpty)
            _FactRow(
              icon: Icons.store_mall_directory_outlined,
              child: Text(branchShift, style: _factStyle),
            ),
          if (dueLabel != null)
            _FactRow(
              icon: overdue ? Icons.event_busy_outlined : Icons.event_outlined,
              child: Text(
                dueLabel,
                style: _factStyle.copyWith(color: dueTone),
              ),
            ),
          _FactRow(
            icon: Icons.person_outline_rounded,
            last: true,
            child: _AssigneeFact(task: task, directory: directory),
          ),
        ],
      ),
    );
  }
}

final _factStyle = AppTypography.bodySmall.copyWith(color: AppColors.textPrimary);

class _FactRow extends StatelessWidget {
  const _FactRow({required this.icon, required this.child, this.last = false});
  final IconData icon;
  final Widget child;
  final bool last;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: last
          ? null
          : const BoxDecoration(
              border: Border(
                bottom: BorderSide(color: AppColors.darkBorder, width: 0.6),
              ),
            ),
      child: Row(
        children: [
          // The leading glyph sits in its own soft tile — the same premium
          // settings-row language used across the app, in place of a bare
          // low-contrast icon.
          Container(
            width: 28,
            height: 28,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.darkSurfaceElevated,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.darkBorder),
            ),
            child: Icon(icon, size: 15, color: AppColors.textSecondary),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(child: child),
        ],
      ),
    );
  }
}

class _AssigneeFact extends StatelessWidget {
  const _AssigneeFact({required this.task, required this.directory});
  final TaskEntity task;
  final Map<String, UserEntity> directory;

  @override
  Widget build(BuildContext context) {
    if (task.assignmentType == TaskAssignmentType.shift) {
      return Text(
        task.shift == null ? 'Shift task' : '${task.shift!.label} shift',
        style: _factStyle,
      );
    }
    final resolved = resolveAssignees(task, directory);
    if (task.assigneeIds.isEmpty) return Text('Unassigned', style: _factStyle);
    if (resolved.length == 1 && task.assigneeIds.length == 1) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          UserAvatar.fromUser(resolved.first, size: 20),
          const SizedBox(width: AppSpacing.sm),
          Flexible(
            child: Text(
              _name(resolved.first),
              style: _factStyle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      );
    }
    if (resolved.isNotEmpty) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AvatarStack(users: resolved, size: 20),
          const SizedBox(width: AppSpacing.sm),
          Text('${task.assigneeIds.length} assigned', style: _factStyle),
        ],
      );
    }
    return Text('${task.assigneeIds.length} assigned', style: _factStyle);
  }

  static String _name(UserEntity u) =>
      (u.displayName?.isNotEmpty ?? false) ? u.displayName! : u.email;
}

// ─── Checklist (one line — the itemised list lives in Full Details) ──

class _ChecklistSummary extends StatelessWidget {
  const _ChecklistSummary({required this.task});
  final TaskEntity task;

  @override
  Widget build(BuildContext context) {
    final complete = task.checklistDone == task.checklistTotal;
    final tint = complete ? AppColors.success : AppColors.textPrimary;
    return Row(
      children: [
        Icon(
          complete
              ? Icons.check_circle_outline_rounded
              : Icons.checklist_rounded,
          size: 15,
          color: complete ? AppColors.success : AppColors.textTertiary,
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: task.checklistProgress,
              minHeight: 4,
              backgroundColor: AppColors.darkSurfaceElevated,
              valueColor: AlwaysStoppedAnimation(tint),
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Text(
          '${task.checklistDone}/${task.checklistTotal}',
          style: AppTypography.caption.copyWith(
            color: tint,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

// ─── Attachments ───────────────────────────────────────────────────

class _AttachmentStrip extends StatelessWidget {
  const _AttachmentStrip({required this.attachments});
  final List<TaskAttachment> attachments;

  static const double _tile = 76;
  static const int _max = 6;

  @override
  Widget build(BuildContext context) {
    final shown = attachments.take(_max).toList();
    final overflow = attachments.length - shown.length;
    return SizedBox(
      height: _tile,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: shown.length + (overflow > 0 ? 1 : 0),
        separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.sm),
        itemBuilder: (context, i) {
          if (i >= shown.length) return _OverflowTile(count: overflow);
          return _Thumb(attachment: shown[i]);
        },
      ),
    );
  }
}

/// One rounded, bordered attachment thumbnail — larger than the old 52px chips
/// so the proof actually reads, with a proper play affordance for video.
class _Thumb extends StatelessWidget {
  const _Thumb({required this.attachment});
  final TaskAttachment attachment;

  @override
  Widget build(BuildContext context) {
    final isVideo = attachment.type == AttachmentType.video;
    return Container(
      width: _AttachmentStrip._tile,
      height: _AttachmentStrip._tile,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.darkSurfaceElevated,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.darkBorder),
      ),
      child: isVideo
          ? const Center(
              child: Icon(
                Icons.play_circle_fill_rounded,
                size: 26,
                color: AppColors.textSecondary,
              ),
            )
          : Image.network(
              attachment.url,
              fit: BoxFit.cover,
              cacheWidth: 160,
              errorBuilder: (_, _, _) => const Center(
                child: Icon(
                  Icons.broken_image_outlined,
                  size: 18,
                  color: AppColors.textTertiary,
                ),
              ),
            ),
    );
  }
}

/// The trailing "+N" tile when there are more attachments than fit the strip.
class _OverflowTile extends StatelessWidget {
  const _OverflowTile({required this.count});
  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: _AttachmentStrip._tile,
      height: _AttachmentStrip._tile,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.darkSurfaceElevated,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.darkBorder),
      ),
      child: Text(
        '+$count',
        style: AppTypography.label.copyWith(color: AppColors.textSecondary),
      ),
    );
  }
}

// ─── Timeline — hierarchy, not three equal rows ─────────────────────

/// The newest event reads as the **head**: bigger node, full weight title,
/// the exact clock time. Everything older is a compact, muted ledger row —
/// present for context, not competing for the same glance. Capped at 4 minor
/// rows; the complete history is one tap away in Full Details.
class _TimelineSection extends StatelessWidget {
  const _TimelineSection({required this.task, required this.directory});
  final TaskEntity task;
  final Map<String, UserEntity> directory;

  static const _maxMinorRows = 4;

  static const double _railWidth = 26;

  @override
  Widget build(BuildContext context) {
    final entries = [...task.activityLog]
      ..sort((a, b) => b.at.compareTo(a.at));
    final head = entries.first;
    final minor = entries.skip(1).take(_maxMinorRows).toList();
    final hidden = entries.length - 1 - minor.length;
    final lastIndex = minor.length; // head is 0; minor rows follow

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _TimelineRailRow(
          entry: head,
          actorName: _actor(head),
          isFirst: true,
          // Keep the rail running if anything (minor rows or the "+N" note)
          // follows, so the connector never dead-ends into empty space.
          isLast: minor.isEmpty && hidden <= 0,
          head: true,
          railWidth: _railWidth,
        ),
        for (var i = 0; i < minor.length; i++)
          _TimelineRailRow(
            entry: minor[i],
            actorName: _actor(minor[i]),
            isFirst: false,
            isLast: i == lastIndex - 1 && hidden <= 0,
            head: false,
            railWidth: _railWidth,
          ),
        if (hidden > 0)
          Padding(
            padding: const EdgeInsets.only(
                left: _railWidth + AppSpacing.sm, top: 2),
            child: Text(
              '+$hidden earlier · see Full Details',
              style: AppTypography.caption.copyWith(
                color: AppColors.textTertiary,
              ),
            ),
          ),
      ],
    );
  }

  String? _actor(ActivityEntry e) =>
      e.actorName ?? directory[e.actorId]?.displayName;
}

/// One event on the connected timeline: a left rail (node + the vertical line
/// that stitches consecutive events together) beside the event's content. The
/// **head** (newest) reads as a full node with the exact clock time; older
/// events are compact rows on the same rail.
class _TimelineRailRow extends StatelessWidget {
  const _TimelineRailRow({
    required this.entry,
    required this.actorName,
    required this.isFirst,
    required this.isLast,
    required this.head,
    required this.railWidth,
  });

  final ActivityEntry entry;
  final String? actorName;
  final bool isFirst;
  final bool isLast;
  final bool head;
  final double railWidth;

  @override
  Widget build(BuildContext context) {
    final color = activityColor(entry.status);
    final node = head
        ? Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withAlpha(30),
              border: Border.all(color: color.withAlpha(120)),
            ),
            child: Icon(activityIcon(entry.status), size: 12, color: color),
          )
        : Container(
            width: 9,
            height: 9,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color,
              border: Border.all(color: AppColors.darkSurface, width: 2),
            ),
          );

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: railWidth,
            child: Column(
              children: [
                // Top connector — absent on the first (newest) node.
                Container(
                  width: 2,
                  height: head ? 4 : 6,
                  color: isFirst ? Colors.transparent : AppColors.darkBorder,
                ),
                node,
                // Bottom connector fills the rest of the row height, so the line
                // is continuous down to the next node regardless of content
                // height. Absent on the last node.
                Expanded(
                  child: Container(
                    width: 2,
                    color: isLast ? Colors.transparent : AppColors.darkBorder,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : AppSpacing.md),
              child: head ? _headContent(color) : _minorContent(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _headContent(Color color) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  activityTitle(entry.status),
                  style: AppTypography.label.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                '${relativeTime(entry.at)} · ${clockTime(entry.at)}',
                style: AppTypography.caption
                    .copyWith(color: AppColors.textSecondary),
              ),
            ],
          ),
          if ((actorName ?? '').isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(actorName!, style: AppTypography.bodySmall),
          ],
        ],
      );

  Widget _minorContent() => Row(
        children: [
          Expanded(
            child: Text(
              (actorName ?? '').isEmpty
                  ? activityTitle(entry.status)
                  : '${actorName!} · ${activityTitle(entry.status)}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style:
                  AppTypography.caption.copyWith(color: AppColors.textSecondary),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Text(
            relativeTime(entry.at),
            style: AppTypography.caption.copyWith(color: AppColors.textTertiary),
          ),
        ],
      );
}
