import 'package:flutter/material.dart';
import 'package:opshub/core/enums/task_assignment_type.dart';
import 'package:opshub/core/enums/task_priority.dart';
import 'package:opshub/core/enums/task_status.dart';
import 'package:opshub/core/enums/user_role.dart';
import 'package:opshub/core/theme/app_colors.dart';
import 'package:opshub/core/theme/app_spacing.dart';
import 'package:opshub/core/theme/app_typography.dart';
import 'package:opshub/core/utils/app_date_formatter.dart';
import 'package:opshub/core/widgets/branch_avatar.dart';
import 'package:opshub/core/widgets/premium_button.dart';
import 'package:opshub/core/widgets/status_badge.dart';
import 'package:opshub/core/widgets/user_avatar.dart';
import 'package:opshub/features/auth/domain/entities/user_entity.dart';
import 'package:opshub/features/task/domain/entities/task_entity.dart';
import 'package:opshub/features/task/domain/task_outcomes.dart';
import 'package:opshub/features/task/presentation/activity_format.dart';
import 'package:opshub/core/widgets/live_status_border.dart';
import 'package:opshub/features/task/presentation/widgets/task_badge.dart';
import 'package:opshub/features/task/presentation/widgets/task_surface.dart';

/// The premium DROP task card — built for **scanning**, not for reading a record.
/// Metadata reads as glanceable *signals* (status pill · priority · branch ·
/// starts/due) rather than a label→value table.
///
/// Premium ≠ flashy: this is the **de-flashed** card (2026-06-25 design ruling) —
/// a flat solid surface with a hairline border and a *very subtle* depth shadow
/// (Linear / Notion / Stripe). **No glow, no gradient, no pulse.** It renders its
/// own surface rather than the shared `AppGlassCard` so this de-flash is scoped to task
/// surfaces only (the shared glass primitives are deliberately untouched).
/// Priority shows **only when High**; progress is a single thin checklist bar
/// shown **only when the task has a checklist** (status is otherwise carried by
/// the pill).
///
/// Layout:
///
///   [status pill] ⏱ 45m late ·········· [High]
///   Title
///   Description (one line)
///   [branch] [starts/due · overdue]            ← signal chips
///   ───────────────────── 3 of 5 · 60%         ← checklist bar (if any)
///   avatar · name · Approved by Ziad           ← minimal one-line footer
///
/// The status row carries the **outcome**, not just the status word — a
/// finished-late task's timeliness note sits right next to the pill, at the
/// same glance the state is read at (promoted up from the chip row 2026-08-01;
/// see `_LatenessNote`). The footer names **who decided** once a task has been
/// decided (approved/rejected/cancelled), not who created it — see
/// `_footerFact`.
class TaskCard extends StatelessWidget {
  const TaskCard({
    super.key,
    required this.task,
    this.directory = const {},
    this.actions = const [],
    this.onAssigneesTap,
    this.branchName,
    this.branchLogoUrl,
  });

  final TaskEntity task;

  /// uid → user, used to render real assignee + creator names/avatars.
  final Map<String, UserEntity> directory;
  final List<Widget> actions;

  /// Opens the assignee sheet when the assignee row is tapped.
  final VoidCallback? onAssigneesTap;

  /// Resolved branch name for the branch chip (null hides it).
  final String? branchName;

  /// Resolved branch logo URL — when present, the branch chip leads with the
  /// branch's actual logo (its identity) instead of the generic store glyph, so
  /// each task reads as belonging to its branch. Null/empty → the glyph.
  final String? branchLogoUrl;

  @override
  Widget build(BuildContext context) {
    final description = task.description ?? '';
    final footerFact = _footerFact(directory, task);
    final overdue = _isOverdue(task);
    final lateness = taskLateness(task);

    // Reference-attachment count was cut (2026-08-01) — it told you material
    // existed but gave you nothing to act on from the card itself (viewing it
    // means opening full details regardless), so it was pure noise on a
    // surface that's supposed to be scanned, not read.
    final chips = <Widget>[
      if ((branchName ?? '').isNotEmpty)
        _BranchChip(name: branchName!, logoUrl: branchLogoUrl),
      // Scheduling V2 — a future start reads as "Scheduled"; once it's underway
      // the start is implied, so only show it while still upcoming.
      if (task.startsAt != null && task.startsAt!.isAfter(DateTime.now()))
        _MetaChip(
          icon: Icons.schedule_outlined,
          label: 'Starts ${AppDateFormatter.dayMonth(task.startsAt!)}',
        ),
      if (task.deadline != null)
        _MetaChip(
          icon: overdue ? Icons.event_busy_outlined : Icons.event_outlined,
          label: overdue
              ? 'Due ${AppDateFormatter.dayMonth(task.deadline!)} · Late'
              : 'Due ${AppDateFormatter.dayMonth(task.deadline!)}',
          tone: overdue ? AppColors.error : null,
        ),
    ];

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      // Living-border orbit: a persistent amber accent circling the card border
      // for any active task; a state change flashes the state colour for one
      // orbit; overdue adds a subtle pulse; null (settled) → no orbit.
      child: LiveStatusBorder(
        color: liveActivityColor(task),
        speed: liveOrbitSpeed(task),
        pulse: taskOverdue(task),
        // Matches TaskSurface's default radius so the orbit rides its border.
        borderRadius: const BorderRadius.all(Radius.circular(14)),
        // The de-flashed task surface lives in one place (TaskSurface) so the card
        // + details header share it instead of re-declaring the decoration.
        child: TaskSurface(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Lifecycle badge (NEW / REWORK #n / Rejected / Approved) ──
              if (taskBadgeFor(task) != null) ...[
                TaskBadge(task: task),
                const SizedBox(height: AppSpacing.md),
              ],

              // ── Status + outcome + priority (High only) ─────────────
              // Lateness sits right beside the pill — the same glance the
              // state is read at — instead of a chip several rows down,
              // which is how "approved, but 3 days late" used to hide in
              // plain sight next to a clean "Approved".
              Row(
                children: [
                  _StatusPill(task.status),
                  if (lateness != null) ...[
                    const SizedBox(width: 8),
                    _LatenessNote(lateness: lateness),
                  ],
                  if (task.priority == TaskPriority.high) ...[
                    const Spacer(),
                    const _HighPriorityFlag(),
                  ],
                ],
              ),
              const SizedBox(height: AppSpacing.md),

              // ── Title + description ─────────────────────────────────
              Text(
                task.title,
                style: AppTypography.label.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                  height: 1.25,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              if (description.isNotEmpty) ...[
                const SizedBox(height: 5),
                Text(
                  description,
                  style: AppTypography.bodySmall.copyWith(height: 1.4),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],

              // ── Signal chips (branch · starts/due) ───────────────────
              if (chips.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.md),
                Wrap(spacing: 6, runSpacing: 6, children: chips),
              ],

              // ── Progress: a single thin bar, only with a checklist ──
              if (task.hasChecklist) ...[
                const SizedBox(height: AppSpacing.md),
                _ChecklistBar(task: task),
              ],

              // ── Minimal one-line footer (assignee · decider/creator) ─
              const SizedBox(height: AppSpacing.md),
              const Divider(height: 1, color: AppColors.darkBorder),
              const SizedBox(height: AppSpacing.md),
              _AssigneeFooter(
                task: task,
                directory: directory,
                fact: footerFact,
                onTap: onAssigneesTap,
              ),

              // ── Actions ─────────────────────────────────────────────
              if (actions.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.md),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.xs,
                  children: actions,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Helpers ───────────────────────────────────────────────────────

/// "Name · Role" for the task's creator, resolved from the directory. Creators
/// not in the branch directory are global admins, so we label them "Admin".
String? _assignedBy(Map<String, UserEntity> directory, TaskEntity task) {
  final by = task.createdBy ?? '';
  if (by.isEmpty) return null;
  final u = directory[by];
  if (u != null) return '${_bestName(u)} · ${_roleLabel(u.role)}';
  return 'Admin';
}

/// The footer's trailing fact. Once a task has been **decided**
/// (approved/rejected/cancelled) this names the **decider**, not the creator —
/// on an Approved card "by Admin" used to mean "created by Admin", which reads
/// as "Admin approved this" and is simply the wrong person answering a
/// question nobody asked. [TaskStatus.missed] has no decider at all: it was
/// closed by the automated deadline sweep, so naming anyone here would be a
/// fabricated attribution — the exact bug this function exists to fix.
/// Undecided statuses are unchanged: there is no decider yet, so the creator
/// remains the useful fact.
String? _footerFact(Map<String, UserEntity> directory, TaskEntity task) {
  switch (task.status) {
    case TaskStatus.approved:
      return _decidedBy('Approved by', task.approvedBy, directory);
    case TaskStatus.rejected:
      return _decidedBy('Rejected by', task.rejectedBy, directory);
    case TaskStatus.cancelled:
      return _decidedBy('Cancelled by', task.cancelledBy, directory);
    case TaskStatus.missed:
      return 'Missed — closed automatically';
    case TaskStatus.pending:
    case TaskStatus.started:
    case TaskStatus.completed:
    case TaskStatus.waitingReview:
      final by = _assignedBy(directory, task);
      return by == null ? null : 'by $by';
  }
}

/// Resolves [uid] through [directory] for a decided-state footer fact. Reuses
/// the single canonical decider-name resolver ([resolveDeciderName]) so this
/// footer fact and the preview sheet's situation sentence can never drift on
/// how they name (or fail to find) a decider.
String _decidedBy(
  String verb,
  String? uid,
  Map<String, UserEntity> directory,
) => '$verb ${resolveDeciderName(uid, directory)}';

String _roleLabel(UserRole r) => switch (r) {
  UserRole.admin => 'Admin',
  UserRole.manager => 'Manager',
  UserRole.employee => 'Employee',
};

bool _isOverdue(TaskEntity task) {
  final d = task.deadline;
  if (d == null) return false;
  final terminal =
      task.status.isTerminal ||
      task.status == TaskStatus.completed ||
      task.status == TaskStatus.waitingReview;
  return !terminal && d.isBefore(DateTime.now());
}

/// The per-state living-border orbit palette — soft, premium, slightly muted so
/// each colour blends naturally with the dark dashboard (no neon, no excess
/// saturation). Applied consistently wherever a task's live state is shown.
/// Canonical constants live in `activity_format.dart` (shared with the
/// activity timeline + feed dots) so the hues change in exactly one place.
const Color _statePending = kStatePending; // baby blue
const Color _stateInProgress = kStateInProgress; // purple
const Color _stateInReview = kStateInReview; // amber
const Color _stateRejected = kStateRejected; // soft red
const Color _stateOverdue = kStateOverdue; // orange

/// The **per-state** orbit colour for a task ([LiveStatusBorder.color]) — held
/// persistently while that state lasts, eased smoothly on a state change:
///
///   • pending    → baby blue `#7DD3FC`
///   • started    → purple    `#A78BFA`
///   • in review  → amber     `#F59E0B`
///   • rejected   → soft red  `#F87171`
///   • **overdue** → orange   `#FB923C` — *takes precedence*
///   • approved / completed / missed → `null` (no orbit; only the static card
///     border)
///
/// Overdue (time-critical) wins over the base status colour. Kept public so the
/// mapping is unit-tested in exactly one place.
Color? liveActivityColor(TaskEntity task) {
  if (task.status.isTerminal || task.status == TaskStatus.completed) {
    return null;
  }
  if (_isOverdue(task)) return _stateOverdue;
  return switch (task.status) {
    TaskStatus.pending => _statePending,
    TaskStatus.started => _stateInProgress,
    TaskStatus.waitingReview => _stateInReview,
    TaskStatus.rejected => _stateRejected,
    TaskStatus.approved ||
    TaskStatus.completed ||
    TaskStatus.missed ||
    TaskStatus.cancelled => null,
  };
}

/// Per-state orbit speed multiplier ([LiveStatusBorder.speed]) — subtle
/// differences so a card's motion hints at its state without changing colour.
double liveOrbitSpeed(TaskEntity task) {
  if (_isOverdue(task)) return 1.1; // medium (+ pulse, see [taskOverdue])
  return switch (task.status) {
    TaskStatus.pending => 1.0, // slow
    TaskStatus.started => 1.2, // medium
    TaskStatus.waitingReview => 0.9, // slightly slow
    TaskStatus.rejected => 1.3, // slightly fast
    TaskStatus.approved ||
    TaskStatus.completed ||
    TaskStatus.missed ||
    TaskStatus.cancelled => 1.0,
  };
}

/// Whether the task is overdue — drives the subtle glow-intensity pulse.
bool taskOverdue(TaskEntity task) => _isOverdue(task);

String _bestName(UserEntity u) =>
    (u.displayName != null && u.displayName!.isNotEmpty)
    ? u.displayName!
    : u.email;

/// Resolves a task's assignee uids to users from [directory].
List<UserEntity> resolveAssignees(
  TaskEntity task,
  Map<String, UserEntity> directory,
) => [
  for (final uid in task.assigneeIds)
    if (directory[uid] != null) directory[uid]!,
];

// ─── Status pill ────────────────────────────────────────────────────

/// A compact status pill — icon + label on a faintly tinted surface. The only
/// colour is the status accent (amber active, green approved, red rework);
/// pending / completed stay neutral grey.
class _StatusPill extends StatelessWidget {
  const _StatusPill(this.status);
  final TaskStatus status;

  @override
  Widget build(BuildContext context) {
    // Colour comes from the single canonical source ([taskStatusColor]) so the
    // pill never forks a third status→colour map; only the card's friendlier
    // label + icon are local.
    final color = taskStatusColor(status);
    final (label, icon) = _labelIcon(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color.withAlpha(28),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withAlpha(70)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: AppTypography.caption.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }

  (String, IconData) _labelIcon(TaskStatus s) => switch (s) {
    TaskStatus.pending => ('To do', Icons.circle_outlined),
    TaskStatus.started => ('In progress', Icons.autorenew_rounded),
    TaskStatus.completed => ('Completed', Icons.check_circle_outline_rounded),
    TaskStatus.waitingReview => ('In review', Icons.hourglass_empty_rounded),
    TaskStatus.approved => ('Approved', Icons.check_circle_rounded),
    TaskStatus.rejected => ('Needs rework', Icons.replay_rounded),
    TaskStatus.missed => ('Missed', Icons.event_busy_rounded),
    TaskStatus.cancelled => ('Cancelled', Icons.block_rounded),
  };
}

/// The only priority signal on the card — shown **only when High** (Medium/Low
/// add noise, per the design ruling). A small red flag + label.
class _HighPriorityFlag extends StatelessWidget {
  const _HighPriorityFlag();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.flag_rounded, size: 13, color: AppColors.error),
        const SizedBox(width: 4),
        Text(
          'High',
          style: AppTypography.caption.copyWith(
            color: AppColors.error,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

/// The **outcome** signal beside the status pill — a finished-late task's
/// timeliness note, promoted out of the chip row (2026-08-01) so it reads at
/// the same glance as the status itself. Neutral grey, never red or any other
/// hue: Late is timeliness on completed work, never pass/fail and never an
/// outcome in its own right (Automated Tasks spec §10.4) — it must not look
/// like a failure marker sitting next to a (still green) Approved pill.
class _LatenessNote extends StatelessWidget {
  const _LatenessNote({required this.lateness});
  final Duration lateness;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(
          Icons.timer_outlined,
          size: 13,
          color: AppColors.textTertiary,
        ),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            formatLateness(lateness),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.caption.copyWith(color: AppColors.textTertiary),
          ),
        ),
      ],
    );
  }
}

/// A glanceable `[icon] label` signal chip on the elevated surface.
class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.icon, required this.label, this.tone});
  final IconData icon;
  final String label;
  final Color? tone;

  @override
  Widget build(BuildContext context) {
    final color = tone ?? AppColors.textSecondary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: tone == null
            ? AppColors.darkSurfaceElevated
            : tone!.withAlpha(24),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: tone == null ? AppColors.darkBorder : tone!.withAlpha(60),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 5),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 180),
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.caption.copyWith(color: color),
            ),
          ),
        ],
      ),
    );
  }
}

/// The branch signal chip — like [_MetaChip] but it leads with the branch's
/// actual **logo** ([BranchAvatar]) when one is uploaded, so a task visibly
/// belongs to its branch (falls back to the store glyph / initials otherwise).
class _BranchChip extends StatelessWidget {
  const _BranchChip({required this.name, this.logoUrl});
  final String name;
  final String? logoUrl;

  @override
  Widget build(BuildContext context) {
    final hasLogo = (logoUrl ?? '').isNotEmpty;
    return Container(
      padding: EdgeInsets.fromLTRB(
        hasLogo ? 4 : 9,
        hasLogo ? 4 : 5,
        9,
        hasLogo ? 4 : 5,
      ),
      decoration: BoxDecoration(
        color: AppColors.darkSurfaceElevated,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.darkBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (hasLogo)
            BranchAvatar(logoUrl: logoUrl, name: name, size: 18, radius: 5)
          else
            const Icon(
              Icons.store_mall_directory_outlined,
              size: 13,
              color: AppColors.textSecondary,
            ),
          const SizedBox(width: 5),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 180),
            child: Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.caption.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Checklist progress ─────────────────────────────────────────────

/// A single thin checklist progress bar — shown **only when the task has a
/// checklist** (otherwise the status pill carries state, so most cards have no
/// bar at all). Calm and minimal: a right-aligned count + percent over a hair
/// track with a white fill (green at 100%). No segments, no stage label — the
/// pill already names the state.
class _ChecklistBar extends StatelessWidget {
  const _ChecklistBar({required this.task});
  final TaskEntity task;

  @override
  Widget build(BuildContext context) {
    final done = task.checklistDone;
    final total = task.checklistTotal;
    final complete = done == total;
    final fill = complete ? AppColors.success : AppColors.textPrimary;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: Alignment.centerRight,
          child: Text(
            '$done of $total · ${(task.checklistProgress * 100).round()}%',
            style: AppTypography.caption.copyWith(
              color: complete ? AppColors.success : AppColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(height: 5),
        ClipRRect(
          borderRadius: BorderRadius.circular(99),
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: task.checklistProgress),
            duration: const Duration(milliseconds: 360),
            curve: Curves.easeOutCubic,
            builder: (context, value, _) => LinearProgressIndicator(
              value: value,
              minHeight: 4,
              backgroundColor: AppColors.darkSurfaceElevated,
              valueColor: AlwaysStoppedAnimation(fill),
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Assignee footer ────────────────────────────────────────────────

/// The card's **single-line** footer: assignee identity (one avatar + name, a
/// stack + count for many, or an "Unassigned" affordance) with a quiet
/// trailing [fact] — the creator while a task is undecided, or **who decided
/// it** once it's approved/rejected/cancelled (see `_footerFact`) — kept to
/// one row so the card stays compact. Taps open the assignee sheet when
/// [onTap] is provided.
class _AssigneeFooter extends StatelessWidget {
  const _AssigneeFooter({
    required this.task,
    required this.directory,
    required this.fact,
    this.onTap,
  });

  final TaskEntity task;
  final Map<String, UserEntity> directory;
  final String? fact;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final resolved = resolveAssignees(task, directory);
    final total = task.assigneeIds.length;

    final Widget leading;
    final String primary;
    if (task.assignmentType == TaskAssignmentType.shift) {
      // Shift Assignment feature: no named assignee — the task targets
      // whoever is rostered on `task.shift`, so show that instead of the
      // otherwise-misleading "Unassigned" (assigneeIds is always empty here).
      leading = Container(
        width: 26,
        height: 26,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.darkSurfaceElevated,
          border: Border.all(color: AppColors.darkBorder),
        ),
        child: const Icon(
          Icons.schedule_rounded,
          size: 14,
          color: AppColors.textTertiary,
        ),
      );
      primary = task.shift == null
          ? 'Shift task'
          : '${task.shift!.label} Shift';
    } else if (total == 0) {
      leading = Container(
        width: 26,
        height: 26,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.darkSurfaceElevated,
          border: Border.all(color: AppColors.darkBorder),
        ),
        child: const Icon(
          Icons.person_add_alt_1_outlined,
          size: 14,
          color: AppColors.textTertiary,
        ),
      );
      primary = 'Unassigned';
    } else if (resolved.length == 1 && total == 1) {
      leading = UserAvatar.fromUser(resolved.first, size: 26);
      primary = _bestName(resolved.first);
    } else if (resolved.isNotEmpty) {
      leading = AvatarStack(users: resolved, size: 24);
      primary = '$total assigned';
    } else {
      leading = Container(
        width: 26,
        height: 26,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.darkSurfaceElevated,
        ),
        child: const Icon(
          Icons.groups_outlined,
          size: 14,
          color: AppColors.textTertiary,
        ),
      );
      primary = '$total assigned';
    }

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Row(
        children: [
          leading,
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: RichText(
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              text: TextSpan(
                style: AppTypography.label,
                children: [
                  TextSpan(text: primary),
                  if (fact != null)
                    TextSpan(
                      text: '  ·  $fact',
                      style: AppTypography.caption.copyWith(
                        color: AppColors.textTertiary,
                      ),
                    ),
                ],
              ),
            ),
          ),
          if (onTap != null)
            const Icon(
              Icons.chevron_right_rounded,
              size: 18,
              color: AppColors.textTertiary,
            ),
        ],
      ),
    );
  }
}

/// Compact, monochrome action button for task card actions — delegates to the
/// canonical [PremiumButton] so card actions share one button implementation.
class TaskActionButton extends StatelessWidget {
  const TaskActionButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.color,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;

  /// Reserved for destructive affordances (e.g. Delete); defaults to the
  /// monochrome foreground.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return PremiumButton(
      label: label,
      icon: icon ?? Icons.chevron_right_rounded,
      onPressed: onPressed,
      tone: color,
    );
  }
}
