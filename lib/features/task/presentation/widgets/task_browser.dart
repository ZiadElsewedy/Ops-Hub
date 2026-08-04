import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:drop/core/enums/task_status.dart';
import 'package:drop/core/theme/app_colors.dart';
import 'package:drop/core/theme/app_radius.dart';
import 'package:drop/core/theme/app_spacing.dart';
import 'package:drop/core/theme/app_typography.dart';
import 'package:drop/core/widgets/app_empty_state.dart';
import 'package:drop/core/widgets/app_search_field.dart';
import 'package:drop/core/widgets/drop_empty_state.dart';
import 'package:drop/core/widgets/skeleton.dart';
import 'package:drop/features/auth/domain/entities/user_entity.dart';
import 'package:drop/features/task/domain/entities/task_entity.dart';
import 'package:drop/features/task/domain/task_feed.dart';
import 'package:drop/features/task/presentation/cubit/task_cubit.dart';
import 'package:drop/features/task/presentation/cubit/task_state.dart';
import 'package:drop/features/task/presentation/widgets/task_feed_row.dart';
import 'package:drop/features/task/presentation/widgets/task_preview_sheet.dart';
import 'package:drop/features/task/presentation/widgets/task_section_list.dart';

/// The shared manager/admin task browser. It filters the already-live task
/// stream in memory; no list surface is allowed to issue its own task read.
///
/// The page reads top-down in one order everywhere it appears — **search →
/// lenses → sections → rows** — so a manager who learns it on the branch list
/// already knows the employee drill-down.
///
/// Two shapes, one component:
/// * **full** (default) — the searchable, lens-filtered, date-sectioned list;
/// * **compact** — a fixed-length preview embedded in another page's scroll
///   (Branch Operations). It drops the controls *and the section headers*: six
///   rows under one "Tasks" heading do not need a date scaffold, and the header
///   the engine gave them was the loudest thing in that block.
class TaskBrowser extends StatefulWidget {
  const TaskBrowser({
    super.key,
    required this.initialFilter,
    this.maxItems,
    this.compact = false,
    this.emptyTitle = 'No matching tasks',
    this.emptyMessage = 'Try another search or status.',
    this.bottomInset = AppSpacing.xxxl,
    this.horizontalPadding = AppSpacing.pagePadding,
  });

  final TaskFeedFilter initialFilter;
  final int? maxItems;
  final bool compact;
  final String emptyTitle;
  final String emptyMessage;

  /// Tail padding under the last row. A host page with a floating action button
  /// passes more, so the FAB never comes to rest on top of a real task.
  final double bottomInset;

  /// The browser owns its own horizontal rhythm — **host pages must not wrap it
  /// in page padding.** The controls sit at this margin; the rows are pulled
  /// [kTaskRowInset] wider so their rounded touch surface breathes past the text
  /// on both sides while every title still lines up with the search field above.
  final double horizontalPadding;

  @override
  State<TaskBrowser> createState() => _TaskBrowserState();
}

class _TaskBrowserState extends State<TaskBrowser> {
  late TaskFeedFilter _filter = widget.initialFilter;
  final TextEditingController _search = TextEditingController();

  /// The selected lens is tracked by identity rather than inferred by comparing
  /// [TaskFeedFilter.statuses] back to the lens. Dart `Set` has no value
  /// equality, so `{approved} == {approved}` is **false** for two separately
  /// built literals — inferring selection that way left every multi-status chip
  /// permanently unhighlighted.
  _Lens _selected = _Lens.all;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  /// The filter this lens would produce. Used both to *apply* a lens and to
  /// **count** it, so a chip's number is by construction the length of the list
  /// tapping it opens — the two can never disagree.
  TaskFeedFilter _filterFor(_Lens lens) => _filter.copyWith(
    statuses: lens.statuses,
    preset: lens.preset,
    activeWindowOnly: lens.closed
        ? false
        : widget.initialFilter.activeWindowOnly,
  );

  void _select(_Lens lens) => setState(() {
    _selected = lens;
    _filter = _filterFor(lens);
  });

  void _onQuery(String query) =>
      setState(() => _filter = _filter.copyWith(query: query));

  void _clearSearch() {
    _search.clear();
    _onQuery('');
  }

  @override
  Widget build(BuildContext context) => BlocBuilder<TaskCubit, TaskState>(
    builder: (context, state) => state.maybeWhen(
      loading: () => _loading(),
      loaded: (tasks, _, directory, _, _) {
        final names = context.read<TaskCubit>().branchNames;
        final now = DateTime.now();

        // One pass per lens, reused for both the rail's counts and the list.
        final byLens = {
          for (final lens in _Lens.values)
            lens: applyFeed(
              tasks,
              _filterFor(lens),
              now,
              directory: directory,
              branchNames: names,
            ),
        };
        final filtered = byLens[_selected]!;
        final visible = widget.maxItems == null
            ? filtered
            : filtered.take(widget.maxItems!).toList();
        final query = _filter.query.trim();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: widget.compact ? MainAxisSize.min : MainAxisSize.max,
          children: [
            if (!widget.compact) ...[
              _pad(
                AppSearchField(
                  controller: _search,
                  hint: 'Search tasks, branches or people',
                  onChanged: _onQuery,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              _pad(
                _LensRail(
                  selected: _selected,
                  counts: {
                    for (final entry in byLens.entries)
                      entry.key: entry.value.length,
                  },
                  onSelect: _select,
                ),
              ),
              if (query.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.md),
                _pad(
                  _SearchFeedback(
                    count: filtered.length,
                    query: query,
                    onClear: _clearSearch,
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.sm),
            ],
            if (visible.isEmpty)
              _empty(query)
            else if (widget.compact)
              for (final (i, task) in visible.indexed)
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: _rowMargin),
                  child: _row(
                    task,
                    directory,
                    names,
                    divider: i < visible.length - 1,
                  ),
                )
            else
              Expanded(
                // Switching lens replaces the whole list; a cross-fade keeps
                // that from reading as a flicker. Keyed on the lens alone, so
                // typing never re-animates the results underneath the cursor.
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 180),
                  switchInCurve: Curves.easeOut,
                  switchOutCurve: Curves.easeOut,
                  child: TaskSectionList(
                    key: ValueKey(_selected),
                    tasks: visible,
                    directory: directory,
                    branchNames: names,
                    showBranch: widget.initialFilter.branchId == null,
                    showAssignee: widget.initialFilter.assigneeUid == null,
                    padding: EdgeInsets.fromLTRB(
                      _rowMargin,
                      0,
                      _rowMargin,
                      widget.bottomInset,
                    ),
                  ),
                ),
              ),
          ],
        );
      },
      orElse: () => const SizedBox.shrink(),
    ),
  );

  /// The margin the *rows* hang off. Pulled back by [kTaskRowInset] from the
  /// controls' margin so a title lines up with the search field while its
  /// rounded highlight extends past it — clamped, so a browser that is already
  /// flush (inside a card) never asks for a negative padding.
  double get _rowMargin =>
      (widget.horizontalPadding - kTaskRowInset).clamp(0, double.infinity);

  /// Page-margin padding for the controls above the list.
  Widget _pad(Widget child) => Padding(
    padding: EdgeInsets.symmetric(horizontal: widget.horizontalPadding),
    child: child,
  );

  /// The compact preview's row. The full list goes through [TaskSectionList],
  /// which every other task list in the app also uses.
  Widget _row(
    TaskEntity task,
    Map<String, UserEntity> directory,
    Map<String, String> names, {
    bool divider = true,
  }) => TaskFeedRow(
    task: task,
    directory: directory,
    branchName: names[task.branchId],
    // A scoped list already answers "which branch" / "whose task"; repeating it
    // on every row only costs the title the width it needs.
    showBranch: widget.initialFilter.branchId == null,
    showAssignee: widget.initialFilter.assigneeUid == null,
    showDivider: divider,
    onTap: () => showTaskPreviewSheet(context, task: task, directory: directory),
  );

  /// A loading list that mirrors the real row rhythm, so the page doesn't jump
  /// when the stream arrives. Previously this state rendered nothing at all —
  /// the browser simply appeared blank until the first snapshot landed.
  Widget _loading() {
    final rows = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < (widget.compact ? 3 : 6); i++) const _RowSkeleton(),
      ],
    );
    if (widget.compact) return rows;
    return _pad(
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Skeleton(width: double.infinity, height: 52),
          const SizedBox(height: AppSpacing.md),
          const Skeleton(width: 240, height: 32),
          const SizedBox(height: AppSpacing.lg),
          Expanded(child: SingleChildScrollView(child: rows)),
        ],
      ),
    );
  }

  /// Four different nothings, four different answers. A generic "no tasks" told
  /// a manager who had just mistyped a name that the branch was empty.
  Widget _empty(String query) {
    if (widget.compact) {
      return Padding(
        padding: EdgeInsets.symmetric(
          horizontal: widget.horizontalPadding,
          vertical: AppSpacing.lg,
        ),
        child: Row(
          children: [
            const Icon(
              Icons.check_circle_outline_rounded,
              size: 16,
              color: AppColors.textQuaternary,
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(widget.emptyMessage, style: AppTypography.caption),
            ),
          ],
        ),
      );
    }

    if (query.isNotEmpty) {
      return Expanded(
        child: AppEmptyState(
          icon: Icons.search_off_rounded,
          title: 'Nothing matches “$query”',
          message:
              'Search reads task titles, descriptions, branch names and the '
              'people a task is assigned to.',
          action: _EmptyAction(label: 'Clear search', onTap: _clearSearch),
        ),
      );
    }

    if (_selected != _Lens.all) {
      return Expanded(
        child: AppEmptyState(
          icon: _selected.emptyIcon,
          title: _selected.emptyTitle,
          message: _selected.emptyMessage,
          action: _EmptyAction(
            label: 'Show all tasks',
            onTap: () => _select(_Lens.all),
          ),
        ),
      );
    }

    return Expanded(
      child: DropEmptyState(
        title: widget.emptyTitle,
        message: widget.emptyMessage,
      ),
    );
  }
}

// ─── Controls ────────────────────────────────────────────────────────────────

/// The status lenses. **Wrapped, never a horizontal scroller**: five short chips
/// fit two rows at worst, and this codebase has already shipped one bug where a
/// control the user could not see was a control they did not have.
class _LensRail extends StatelessWidget {
  const _LensRail({
    required this.selected,
    required this.counts,
    required this.onSelect,
  });

  final _Lens selected;
  final Map<_Lens, int> counts;
  final ValueChanged<_Lens> onSelect;

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: AppSpacing.sm,
    runSpacing: AppSpacing.sm,
    children: [
      for (final lens in _Lens.values)
        _LensChip(
          lens: lens,
          count: counts[lens] ?? 0,
          selected: selected == lens,
          onSelect: () => onSelect(lens),
        ),
    ],
  );
}

class _LensChip extends StatelessWidget {
  const _LensChip({
    required this.lens,
    required this.count,
    required this.selected,
    required this.onSelect,
  });

  final _Lens lens;
  final int count;
  final bool selected;
  final VoidCallback onSelect;

  @override
  Widget build(BuildContext context) {
    // An empty lens is drawn, not hidden: a rail whose items appear and vanish
    // as work moves is a rail you cannot learn. It just stops asking for
    // attention.
    final empty = count == 0 && !selected;
    final labelColor = selected
        ? AppColors.onPrimary
        : empty
        ? AppColors.textTertiary
        : AppColors.textSecondary;

    return Semantics(
      button: true,
      selected: selected,
      label: '${lens.label} tasks, $count',
      child: ChoiceChip(
        label: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(lens.label),
            // A zero is not a count worth printing. Three chips reading "0"
            // beside each other was noise, and it widened the rail enough to
            // push the last lens onto a second run for nothing.
            if (count > 0) ...[
              const SizedBox(width: 6),
              Text(
                '$count',
                style: AppTypography.labelSmall.copyWith(
                  fontSize: 11,
                  color: selected
                      ? AppColors.onPrimary.withAlpha(160)
                      : AppColors.textQuaternary,
                ),
              ),
            ],
          ],
        ),
        selected: selected,
        onSelected: (_) => onSelect(),
        showCheckmark: false,
        pressElevation: 0,
        backgroundColor: AppColors.darkSurface,
        selectedColor: AppColors.primary,
        side: BorderSide(
          color: selected ? AppColors.primary : AppColors.darkBorder,
        ),
        shape: const StadiumBorder(),
        labelPadding: EdgeInsets.zero,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        visualDensity: VisualDensity.compact,
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        labelStyle: AppTypography.labelSmall.copyWith(color: labelColor),
      ),
    );
  }
}

/// Live search feedback. Searching used to be silent: the list simply became
/// shorter, and a query that matched nothing looked identical to a branch that
/// held nothing.
class _SearchFeedback extends StatelessWidget {
  const _SearchFeedback({
    required this.count,
    required this.query,
    required this.onClear,
  });

  final int count;
  final String query;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: Text(
          '${count == 1 ? '1 match' : '$count matches'} for “$query”',
          style: AppTypography.caption.copyWith(color: AppColors.textSecondary),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      const SizedBox(width: AppSpacing.sm),
      Semantics(
        button: true,
        child: GestureDetector(
          onTap: onClear,
          behavior: HitTestBehavior.opaque,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
            child: Text(
              'Clear',
              style: AppTypography.caption.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    ],
  );
}

class _EmptyAction extends StatelessWidget {
  const _EmptyAction({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    child: GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          borderRadius: AppRadius.fullAll,
          border: Border.all(color: AppColors.darkBorder),
        ),
        child: Text(
          label,
          style: AppTypography.labelSmall.copyWith(
            color: AppColors.textPrimary,
          ),
        ),
      ),
    ),
  );
}

class _RowSkeleton extends StatelessWidget {
  const _RowSkeleton();

  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Skeleton(width: 190, height: 13),
        SizedBox(height: 8),
        Skeleton(width: 130, height: 10),
      ],
    ),
  );
}

// ─── Lenses ──────────────────────────────────────────────────────────────────

enum _Lens { all, active, review, late, closed }

extension on _Lens {
  /// The closed lens is labelled **Closed**, not "Done". It spans approved,
  /// missed and cancelled work, and a missed task is not a completed one — the
  /// spec forbids presenting Missed or Cancelled as Done, or summing them.
  /// Nothing here is summed: each row carries its own status badge, so the three
  /// outcomes stay individually readable inside one record view.
  String get label => switch (this) {
    _Lens.all => 'All',
    _Lens.active => 'Active',
    _Lens.review => 'In review',
    _Lens.late => 'Late',
    _Lens.closed => 'Closed',
  };

  Set<TaskStatus>? get statuses => switch (this) {
    _Lens.active => {
      TaskStatus.pending,
      TaskStatus.started,
      TaskStatus.completed,
      TaskStatus.rejected,
    },
    _Lens.review => {TaskStatus.waitingReview},
    _Lens.closed => {
      TaskStatus.approved,
      TaskStatus.missed,
      TaskStatus.cancelled,
    },
    _ => null,
  };

  FeedPreset? get preset => this == _Lens.late ? FeedPreset.overdue : null;

  /// Browsing a closed record set must switch off the active-window scope, or
  /// `applyFeed` filters out exactly the statuses being asked for and the list
  /// renders empty.
  bool get closed => this == _Lens.closed;

  IconData get emptyIcon => switch (this) {
    _Lens.late => Icons.check_circle_outline_rounded,
    _Lens.review => Icons.fact_check_outlined,
    _Lens.closed => Icons.inventory_2_outlined,
    _ => Icons.inbox_outlined,
  };

  String get emptyTitle => switch (this) {
    _Lens.active => 'No open work',
    _Lens.review => 'Nothing to review',
    _Lens.late => 'Nothing is late',
    _Lens.closed => 'No closed work yet',
    _Lens.all => 'No tasks',
  };

  String get emptyMessage => switch (this) {
    _Lens.active =>
      'Everything here is either finished or waiting on a decision.',
    _Lens.review => 'No one has submitted work that needs approving.',
    _Lens.late => 'Every task in this view is still inside its deadline.',
    _Lens.closed =>
      'Approved, missed and cancelled work will collect here as it closes.',
    _Lens.all => 'Nothing to show in this view.',
  };
}
