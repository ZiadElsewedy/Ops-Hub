import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:opshub/core/enums/task_assignment_type.dart';
import 'package:opshub/core/enums/task_status.dart';
import 'package:opshub/core/responsive/breakpoints.dart';
import 'package:opshub/core/services/usage_tracker.dart';
import 'package:opshub/core/theme/app_colors.dart';
import 'package:opshub/core/theme/app_spacing.dart';
import 'package:opshub/core/theme/app_typography.dart';
import 'package:opshub/core/widgets/animated_count.dart';
import 'package:opshub/core/widgets/app_search_field.dart';
import 'package:opshub/core/widgets/live_list_item.dart';
import 'package:opshub/features/auth/domain/entities/user_entity.dart';
import 'package:opshub/features/task/domain/active_window.dart';
import 'package:opshub/features/task/domain/entities/task_entity.dart';
import 'package:opshub/features/task/domain/task_feed.dart';
import 'package:opshub/features/task/presentation/cubit/task_cubit.dart';
import 'package:opshub/features/task/presentation/cubit/task_state.dart';
import 'package:opshub/features/task/presentation/widgets/task_feed_expansion.dart';
import 'package:opshub/features/task/presentation/widgets/task_feed_row.dart';
import 'package:opshub/features/task/presentation/widgets/task_preview_sheet.dart';

/// The **global active-task feed** on the homepage (Home Dashboard redesign,
/// P2). A self-contained widget over the app-wide [TaskCubit] stream — no new
/// cubit / query. It owns an ephemeral [TaskFeedFilter], renders a sticky
/// preset/search/group bar, and lays out the tasks as dense [TaskFeedRow]s in
/// collapsible urgency/branch/employee/priority groups. A row taps straight
/// through to the task (reach any task in 2 taps).
///
/// Designed to sit inside a scrolling page (it does not scroll itself), so the
/// dashboard owns the scroll. Admin sees an all-branches scope; a manager passes
/// [branchLocked] + [branchId] to pin their branch (no scope switcher).
class TaskFeedSection extends StatefulWidget {
  const TaskFeedSection({
    super.key,
    this.branchLocked = false,
    this.branchId,
    this.initialFilter = const TaskFeedFilter(),
  });

  /// Manager mode — pin to [branchId], hide the branch scope + branch grouping.
  final bool branchLocked;
  final String? branchId;
  final TaskFeedFilter initialFilter;

  @override
  State<TaskFeedSection> createState() => TaskFeedSectionState();
}

class TaskFeedSectionState extends State<TaskFeedSection> {
  late TaskFeedFilter _filter = widget.initialFilter;
  final Set<String> _collapsed = {};

  /// The one inline-expanded row on desktop (accordion — one at a time). Null on
  /// mobile (rows open a bottom sheet instead).
  String? _expandedId;

  /// Lets the KPI cards drive the feed (tap "Overdue" → preset). Public so the
  /// dashboard can call it via a `GlobalKey<TaskFeedSectionState>`.
  void applyPreset(FeedPreset? preset) =>
      setState(() => _filter = _filter.copyWith(preset: preset));

  /// Desktop → toggle the inline accordion (one open at a time). Mobile → open
  /// the shared surface as a bottom sheet.
  void _onRowTap(TaskEntity task, Map<String, UserEntity> directory) {
    if (context.isDesktop) {
      final opening = _expandedId != task.id;
      setState(() => _expandedId = opening ? task.id : null);
      if (opening) UsageTracker.track('expansion_open');
    } else {
      UsageTracker.track('expansion_open');
      showTaskPreviewSheet(context, task: task, directory: directory);
    }
  }

  String? branchNameFor(TaskEntity task) =>
      context.read<TaskCubit>().branchNames[task.branchId];

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<TaskCubit, TaskState>(
      builder: (context, state) {
        return state.maybeWhen(
          loaded: (tasks, busy, directory, isSubmitting, submissionProgress) {
            final branchNames = context.read<TaskCubit>().branchNames;
            final now = DateTime.now();
            final effective = widget.branchLocked
                ? _filter.copyWith(branchId: widget.branchId)
                : _filter;
            final filtered = applyFeed(tasks, effective, now,
                directory: directory, branchNames: branchNames);
            final groups = groupFeed(filtered, _filter.grouping, now,
                directory: directory, branchNames: branchNames);

            // Attention counts come from the SCOPE-only active set (not the
            // user's preset/query), so the strip stays a stable triage summary.
            final scoped = [
              for (final t in tasks)
                if (isTaskInActiveWindow(t, now) &&
                    (!widget.branchLocked || t.branchId == widget.branchId))
                  t
            ];
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _AttentionStrip(
                  overdue: scoped.where((t) => isTaskOverdue(t, now)).length,
                  review: scoped
                      .where((t) => t.status == TaskStatus.waitingReview)
                      .length,
                  // "Blocked" = can't progress for lack of an owner → unassigned
                  // individual/team tasks (shift tasks target a shift, not a
                  // person, so they're never "unassigned").
                  unassigned: scoped
                      .where((t) =>
                          t.assignmentType != TaskAssignmentType.shift &&
                          t.assigneeIds.isEmpty)
                      .length,
                  filter: _filter,
                  onChanged: (f) => setState(() => _filter = f),
                ),
                const SizedBox(height: AppSpacing.md),
                _FeedBar(
                  filter: _filter,
                  branchLocked: widget.branchLocked,
                  branchNames: branchNames,
                  onChanged: (f) => setState(() => _filter = f),
                ),
                const SizedBox(height: AppSpacing.md),
                if (filtered.isEmpty)
                  _empty()
                // Smart Queue is a single ranked list — no group headers.
                else if (_filter.sort == FeedSort.smart)
                  for (final t in filtered) _rowTile(t, directory)
                else
                  for (final g in groups) ..._group(g, directory),
              ],
            );
          },
          orElse: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: 40),
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          ),
        );
      },
    );
  }

  List<Widget> _group(FeedGroup g, Map<String, UserEntity> directory) {
    final collapsed = _collapsed.contains(g.key);
    return [
      _GroupHeader(
        label: g.label,
        count: g.tasks.length,
        collapsed: collapsed,
        onTap: () => setState(() {
          collapsed ? _collapsed.remove(g.key) : _collapsed.add(g.key);
        }),
      ),
      if (!collapsed)
        for (final t in g.tasks) _rowTile(t, directory),
    ];
  }

  /// A feed row + its (desktop) inline expansion, keyed for stable scroll.
  Widget _rowTile(TaskEntity t, Map<String, UserEntity> directory) =>
      LiveListItem(
        key: ValueKey('feed:${t.id}'),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TaskFeedRow(
              task: t,
              directory: directory,
              branchName: branchNameFor(t),
              selected: _expandedId == t.id,
              onTap: () => _onRowTap(t, directory),
            ),
            _inlineExpansion(t, directory),
          ],
        ),
      );

  /// The desktop accordion body under a row — animates height (AnimatedSize) and
  /// fades in (TweenAnimationBuilder). Collapsed / mobile → a zero-height box.
  Widget _inlineExpansion(TaskEntity t, Map<String, UserEntity> directory) {
    final expanded = context.isDesktop && _expandedId == t.id;
    return AnimatedSize(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      alignment: Alignment.topCenter,
      child: expanded
          ? Padding(
              padding: const EdgeInsets.only(
                  top: AppSpacing.sm, bottom: AppSpacing.md),
              child: TweenAnimationBuilder<double>(
                key: ValueKey('exp:${t.id}'),
                tween: Tween(begin: 0, end: 1),
                duration: const Duration(milliseconds: 200),
                builder: (_, v, child) => Opacity(opacity: v, child: child),
                child: TaskFeedExpansion(
                  task: t,
                  directory: directory,
                  branchName: branchNameFor(t),
                  onOpenDetails: () => openTaskDetails(context, t, directory),
                  onClose: () => setState(() => _expandedId = null),
                ),
              ),
            )
          : const SizedBox(width: double.infinity),
    );
  }

  Widget _empty() => Padding(
        padding: const EdgeInsets.symmetric(vertical: 44),
        child: Column(
          children: [
            const Icon(Icons.check_circle_outline_rounded,
                size: 34, color: AppColors.textTertiary),
            const SizedBox(height: AppSpacing.sm),
            Text(
              _filter.hasActiveFilters ? 'No matching tasks' : 'All clear',
              style: AppTypography.label.copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 4),
            Text(
              _filter.hasActiveFilters
                  ? 'Try clearing a filter.'
                  : 'No active tasks right now.',
              style: AppTypography.caption,
            ),
          ],
        ),
      );
}

// ─── Filter / preset / group bar ────────────────────────────────────

class _FeedBar extends StatelessWidget {
  const _FeedBar({
    required this.filter,
    required this.branchLocked,
    required this.branchNames,
    required this.onChanged,
  });

  final TaskFeedFilter filter;
  final bool branchLocked;
  final Map<String, String> branchNames;
  final ValueChanged<TaskFeedFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Preset chips.
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final p in FeedPreset.values)
              _PresetChip(
                label: p.label,
                active: filter.preset == p,
                onTap: () {
                  if (filter.preset != p) UsageTracker.track('preset_${p.name}');
                  onChanged(filter.togglePreset(p));
                },
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        // Search + group + sort (+ branch scope for admin).
        Row(
          children: [
            Expanded(
              child: AppSearchField(
                hint: 'Search tasks, people, branches',
                onChanged: (v) => onChanged(filter.copyWith(query: v)),
              ),
            ),
            const SizedBox(width: 8),
            if (!branchLocked && branchNames.isNotEmpty)
              _ScopeMenu(
                filter: filter,
                branchNames: branchNames,
                onChanged: onChanged,
              ),
            // Smart Queue is a flat ranked list, so grouping doesn't apply.
            if (filter.sort != FeedSort.smart)
              _MenuButton<FeedGrouping>(
                icon: Icons.layers_outlined,
                value: filter.grouping,
                label: filter.grouping.label,
                items: [
                  for (final g in FeedGrouping.values)
                    if (!(branchLocked && g == FeedGrouping.branch)) (g, g.label),
                ],
                onSelected: (g) => onChanged(filter.copyWith(grouping: g)),
              ),
            _MenuButton<FeedSort>(
              icon: Icons.swap_vert_rounded,
              value: filter.sort,
              label: filter.sort.label,
              items: [for (final s in FeedSort.values) (s, s.label)],
              onSelected: (s) {
                UsageTracker.track('sort_${s.name}');
                onChanged(filter.copyWith(sort: s));
              },
            ),
          ],
        ),
      ],
    );
  }
}

class _PresetChip extends StatelessWidget {
  const _PresetChip(
      {required this.label, required this.active, required this.onTap});
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
        decoration: BoxDecoration(
          color: active ? AppColors.primary : AppColors.darkSurface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
              color: active ? AppColors.primary : AppColors.darkBorder),
        ),
        child: Text(
          label,
          style: AppTypography.caption.copyWith(
            color: active ? AppColors.onPrimary : AppColors.textSecondary,
            fontWeight: active ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ),
    );
  }
}

class _ScopeMenu extends StatelessWidget {
  const _ScopeMenu(
      {required this.filter, required this.branchNames, required this.onChanged});
  final TaskFeedFilter filter;
  final Map<String, String> branchNames;
  final ValueChanged<TaskFeedFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    final label = filter.branchId == null
        ? 'All branches'
        : (branchNames[filter.branchId] ?? 'Branch');
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: PopupMenuButton<String?>(
        tooltip: 'Branch',
        color: AppColors.darkSurfaceElevated,
        onSelected: (v) => onChanged(filter.copyWith(branchId: v)),
        itemBuilder: (context) => [
          const PopupMenuItem(value: null, child: Text('All branches')),
          for (final e in branchNames.entries)
            PopupMenuItem(value: e.key, child: Text(e.value)),
        ],
        child: _barButton(Icons.store_mall_directory_outlined, label),
      ),
    );
  }
}

class _MenuButton<T> extends StatelessWidget {
  const _MenuButton({
    required this.icon,
    required this.value,
    required this.label,
    required this.items,
    required this.onSelected,
  });
  final IconData icon;
  final T value;
  final String label;
  final List<(T, String)> items;
  final ValueChanged<T> onSelected;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 8),
      child: PopupMenuButton<T>(
        tooltip: label,
        color: AppColors.darkSurfaceElevated,
        initialValue: value,
        onSelected: onSelected,
        itemBuilder: (context) => [
          for (final (v, l) in items) PopupMenuItem(value: v, child: Text(l)),
        ],
        child: _barButton(icon, label),
      ),
    );
  }
}

Widget _barButton(IconData icon, String label) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: AppColors.darkSurface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.darkBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: AppColors.textSecondary),
          const SizedBox(width: 6),
          Text(label,
              style: AppTypography.caption
                  .copyWith(color: AppColors.textSecondary)),
          const Icon(Icons.expand_more_rounded,
              size: 15, color: AppColors.textTertiary),
        ],
      ),
    );

class _GroupHeader extends StatelessWidget {
  const _GroupHeader({
    required this.label,
    required this.count,
    required this.collapsed,
    required this.onTap,
  });
  final String label;
  final int count;
  final bool collapsed;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.only(top: AppSpacing.md, bottom: 4),
        child: Row(
          children: [
            Icon(
              collapsed ? Icons.chevron_right_rounded : Icons.expand_more_rounded,
              size: 17,
              color: AppColors.textSecondary,
            ),
            const SizedBox(width: 4),
            Text(
              label.toUpperCase(),
              style: AppTypography.caption.copyWith(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(width: 8),
            AnimatedCount(
              value: count,
              style: AppTypography.caption.copyWith(color: AppColors.textTertiary),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Attention Needed strip ─────────────────────────────────────────

/// A stable triage bar above the feed — overdue · pending review · blocked
/// (`rejected` / rework) counts over the scope's active set. Each is tappable
/// to filter the feed. Shows an "all clear" state when nothing needs attention.
class _AttentionStrip extends StatelessWidget {
  const _AttentionStrip({
    required this.overdue,
    required this.review,
    required this.unassigned,
    required this.filter,
    required this.onChanged,
  });

  final int overdue;
  final int review;
  final int unassigned;
  final TaskFeedFilter filter;
  final ValueChanged<TaskFeedFilter> onChanged;

  // Always renders the three pills (even at zero, muted) so each pill's
  // AnimatedCount persists in the tree and tweens smoothly through any change —
  // including to/from zero (no all-clear layout swap that would reset it).
  void _toggle(FeedPreset p) {
    if (filter.preset != p) UsageTracker.track('preset_${p.name}');
    onChanged(filter.copyWith(preset: filter.preset == p ? null : p, status: null));
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _AttentionPill(
            icon: Icons.event_busy_outlined,
            label: 'Late',
            count: overdue,
            color: AppColors.error,
            active: filter.preset == FeedPreset.overdue,
            onTap: () => _toggle(FeedPreset.overdue),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: _AttentionPill(
            icon: Icons.rate_review_outlined,
            label: 'Pending review',
            count: review,
            color: AppColors.warning,
            active: filter.preset == FeedPreset.needsReview,
            onTap: () => _toggle(FeedPreset.needsReview),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: _AttentionPill(
            icon: Icons.person_off_outlined,
            label: 'Unassigned',
            count: unassigned,
            color: AppColors.warning,
            active: filter.preset == FeedPreset.unassigned,
            onTap: () => _toggle(FeedPreset.unassigned),
          ),
        ),
      ],
    );
  }
}

class _AttentionPill extends StatelessWidget {
  const _AttentionPill({
    required this.icon,
    required this.label,
    required this.count,
    required this.color,
    required this.active,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final int count;
  final Color color;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final on = count > 0;
    final tint = on ? color : AppColors.textTertiary;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md, vertical: AppSpacing.sm),
        decoration: BoxDecoration(
          color: active ? color.withAlpha(28) : AppColors.darkSurface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: active
                ? color.withAlpha(130)
                : (on ? color.withAlpha(60) : AppColors.darkBorder),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 15, color: tint),
                const Spacer(),
                if (active)
                  Icon(Icons.check_rounded, size: 14, color: color),
              ],
            ),
            const SizedBox(height: 6),
            AnimatedCount(
              value: count,
              style: AppTypography.label.copyWith(
                fontSize: 22,
                fontWeight: FontWeight.w600,
                color: on ? AppColors.textPrimary : AppColors.textTertiary,
              ),
            ),
            Text(label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style:
                    AppTypography.caption.copyWith(color: AppColors.textSecondary)),
          ],
        ),
      ),
    );
  }
}
