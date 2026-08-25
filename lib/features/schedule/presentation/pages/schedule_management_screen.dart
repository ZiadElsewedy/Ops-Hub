import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:opshub/core/theme/app_colors.dart';
import 'package:opshub/core/theme/app_spacing.dart';
import 'package:opshub/core/theme/app_typography.dart';
import 'package:opshub/core/responsive/breakpoints.dart';
import 'package:opshub/core/widgets/admin_section_header.dart';
import 'package:opshub/core/widgets/app_error_state.dart';
import 'package:opshub/core/widgets/branch_avatar.dart';
import 'package:opshub/core/widgets/glass_container.dart';
import 'package:opshub/core/widgets/list_skeleton.dart';
import 'package:opshub/core/widgets/segmented_tab_bar.dart';
import 'package:opshub/core/widgets/adaptive_scaffold.dart';
import 'package:opshub/features/branch/presentation/cubit/branch_cubit.dart';
import 'package:opshub/features/branch/presentation/cubit/branch_state.dart';
import 'package:opshub/features/branch/domain/entities/branch_entity.dart';
import 'package:opshub/features/schedule/domain/today_coverage.dart';
import 'package:opshub/features/schedule/presentation/cubit/schedule_cubit.dart';
import 'package:opshub/features/schedule/presentation/cubit/shift_swap_cubit.dart';
import 'package:opshub/features/schedule/presentation/cubit/today_coverage_cubit.dart';
import 'package:opshub/features/schedule/presentation/cubit/today_coverage_state.dart';
import 'package:opshub/features/schedule/presentation/pages/schedule_final_view.dart';
import 'package:opshub/features/schedule/presentation/widgets/manager_schedule_view.dart';
import 'package:opshub/features/schedule/presentation/widgets/today_roster_sheet.dart';

/// Admin schedule landing: today's multi-branch coverage first; the unchanged
/// weekly editor remains one deliberate tap away.
class ScheduleManagementScreen extends StatefulWidget {
  const ScheduleManagementScreen({super.key});

  @override
  State<ScheduleManagementScreen> createState() =>
      _ScheduleManagementScreenState();
}

class _ScheduleManagementScreenState extends State<ScheduleManagementScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  var _mode = 0;

  /// Set by [_edit] so the weekly editor opens on that branch. See [_edit].
  String? _editBranchId;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this)..addListener(_onTabChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _tabs
      ..removeListener(_onTabChanged)
      ..dispose();
    super.dispose();
  }

  void _onTabChanged() {
    if (!_tabs.indexIsChanging && _mode != _tabs.index) {
      setState(() => _mode = _tabs.index);
      // Coming BACK to Today: re-derive it. The editor is where coverage gets
      // fixed, so the most likely reason to return is having just assigned
      // somebody — and a Today list still reporting "Nobody is on night" for a
      // shift you just filled is worse than no list at all. Cheap: the reads
      // are cache-first and capped.
      if (_mode == 0) _reloadCoverage();
    }
  }

  /// Returning to Today after using the editor **must** re-derive: a board still
  /// reporting "Nobody is on night" for a shift just filled is worse than no
  /// board at all. This is the one entry that bypasses the freshness window.
  void _reloadCoverage() {
    context.read<BranchCubit>().state.maybeWhen(
      loaded: (branches, _) => _loadCoverage(branches, force: true),
      orElse: () {},
    );
  }

  /// Screen entry. Both cubits are app-wide and self-guarding: the branch
  /// directory is fetched only if it isn't already loaded, and the swap stream
  /// is idempotent per scope. An unconditional `load()` here was refetching the
  /// whole branch directory — and emitting `loading()`, which blanked every
  /// branch-identity surface in the app — on every single visit to Schedule.
  void _load() {
    context.read<BranchCubit>().loadIfNeeded();
    context.read<ShiftSwapCubit>().loadAll();
    // If the branch directory is **already** loaded (common — the admin opened
    // Dashboard/Branches first this session), `loadIfNeeded()` is a no-op and
    // emits nothing, so the branch listener — which reacts to a state *change* —
    // never fires and Today coverage would sit on its skeletons forever. Kick
    // coverage off here for that case. When the directory isn't loaded yet,
    // `loadIfNeeded()` emits `loaded` and the listener takes it; the coverage
    // cubit's freshness window makes the double-trigger a no-op either way.
    context.read<BranchCubit>().state.maybeWhen(
      loaded: (branches, _) => _loadCoverage(branches),
      orElse: () {},
    );
  }

  /// Today's coverage is only meaningful for branches that are **operating**.
  /// An inactive branch (e.g. a closed or paused location) has no shift to
  /// cover today, so loading it is pure first-entry cost — one schedule + one
  /// roster read each — and an extra "nobody on" row nobody acts on. The full
  /// directory (inactive included) still drives the Week editor, which can edit
  /// any branch.
  void _loadCoverage(List<BranchEntity> branches, {bool force = false}) {
    final active = [for (final b in branches) if (b.isActive) b];
    context.read<TodayCoverageCubit>().load(active, force: force);
  }

  /// The explicit Refresh action — everything refetches, freshness windows and
  /// all. The branch listener re-derives Today off the reloaded directory.
  void _refresh() {
    context.read<ScheduleCubit>().refresh();
    context.read<ShiftSwapCubit>().refresh();
    context.read<BranchCubit>().load(forceRefresh: true);
    _reloadCoverage();
  }

  /// Open the weekly editor **on the branch whose row was tapped**.
  ///
  /// The branch is handed to [ManagerScheduleView] as `initialBranchId` rather
  /// than pushed into `ScheduleCubit` from here. Selecting from the outside
  /// cannot work: the editor mounts only after the tab animation settles, and
  /// its own init then loads the default branch — so a selection made before
  /// that is silently overwritten and Edit lands on the wrong branch. It stays
  /// set afterwards, so returning to Week later reopens the branch last edited.
  void _edit(TodayCoverage coverage) {
    setState(() => _editBranchId = coverage.branch.id);
    _tabs.animateTo(1);
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<BranchCubit, BranchState>(
      listenWhen: (_, state) => state.maybeWhen(
        loaded: (_, _) => true,
        orElse: () => false,
      ),
      listener: (context, state) {
        state.maybeWhen(
          loaded: (branches, _) => _loadCoverage(branches),
          orElse: () {},
        );
      },
      child: AdaptiveScaffold(
        title: 'Branch Schedules',
        constrainContent: false,
        actions: [
          // Final view in the app bar on mobile, and only on the Week tab where
          // the weekly editor (and a loaded schedule) actually lives.
          if (!context.isDesktop && _mode == 1) const ScheduleFinalViewAction(),
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: AppColors.textSecondary),
            tooltip: 'Refresh',
            onPressed: _refresh,
          ),
        ],
        body: Column(
          children: [
            SegmentedTabBar(controller: _tabs, tabs: const ['Today', 'Week']),
            Expanded(
              child: _mode == 0
                  ? _TodayCoverageList(onEdit: _edit)
                  : ManagerScheduleView(
                      isAdmin: true,
                      initialBranchId: _editBranchId,
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TodayCoverageList extends StatelessWidget {
  const _TodayCoverageList({required this.onEdit});

  final ValueChanged<TodayCoverage> onEdit;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<BranchCubit, BranchState>(
      builder: (context, branchState) => branchState.maybeWhen(
        loading: () => const ListSkeleton(cardHeight: 126),
        error: (message) => AppErrorState(
          title: 'Branches could not load',
          message: message,
          onRetry: () => context.read<BranchCubit>().load(),
        ),
        loaded: (_, _) => BlocBuilder<TodayCoverageCubit, TodayCoverageState>(
          builder: (context, state) => switch (state) {
            TodayCoverageLoading() || TodayCoverageInitial() =>
              const ListSkeleton(cardHeight: 126),
            TodayCoverageError(:final message) => AppErrorState(
              title: 'Today\'s coverage could not load',
              message: message,
              onRetry: () => context.read<BranchCubit>().load(),
            ),
            TodayCoverageLoaded(:final coverage) => _CoverageRows(
              coverage: coverage,
              onEdit: onEdit,
            ),
          },
        ),
        orElse: () => const ListSkeleton(cardHeight: 126),
      ),
    );
  }
}

class _CoverageRows extends StatelessWidget {
  const _CoverageRows({required this.coverage, required this.onEdit});

  final List<TodayCoverage> coverage;
  final ValueChanged<TodayCoverage> onEdit;

  @override
  Widget build(BuildContext context) {
    final covered = fullyCoveredBranches(coverage);
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.pagePadding,
        AppSpacing.lg,
        AppSpacing.pagePadding,
        AppSpacing.xxxl,
      ),
      itemCount: coverage.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) {
          return Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.lg),
            child: AdminSectionHeader(
              title: 'Today\'s coverage',
              subtitle: '$covered of ${coverage.length} branches fully covered today',
              icon: Icons.today_outlined,
            ),
          );
        }
        final row = coverage[index - 1];
        return Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.md),
          child: _CoverageRow(coverage: row, onEdit: () => onEdit(row)),
        );
      },
    );
  }
}

class _CoverageRow extends StatelessWidget {
  const _CoverageRow({required this.coverage, required this.onEdit});

  final TodayCoverage coverage;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final warning = coverage.hasUncoveredShift;
    final noSchedule = !coverage.hasSchedule && coverage.loadError == null;
    final summary = coverage.loadError ??
        (noSchedule
            ? 'No schedule created for this week'
            : coverage.roster.shifts
                .map((shift) => '${shift.shift.label} ${shift.people.length}')
                .join(' · '));
    final uncovered = coverage.roster.shifts
        .where((shift) => shift.isEmpty)
        .map((shift) => shift.shift.label.toLowerCase())
        .join(' and ');
    return GlassContainer(
      onTap: () => showTodayRosterSheet(
        context: context,
        branchId: coverage.branch.id,
        branchName: coverage.branch.name,
        // Hand over the roster this row is already drawn from: no second read
        // of what we just loaded, no displacement of the editor's selection,
        // and the sheet can't contradict the row that opened it.
        roster: coverage.roster,
        // We ARE the schedule screen — switch tabs instead of pushing our own
        // route on top of ourselves.
        onOpenSchedule: onEdit,
      ),
      highlight: warning,
      accent: AppColors.warning,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          BranchAvatar.fromBranch(coverage.branch),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(coverage.branch.name, style: AppTypography.label),
                if ((coverage.branch.location ?? '').trim().isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(coverage.branch.location!, style: AppTypography.caption.copyWith(color: AppColors.textTertiary)),
                ],
                const SizedBox(height: AppSpacing.sm),
                Text(
                  summary,
                  style: AppTypography.caption.copyWith(
                    color: warning ? AppColors.warning : AppColors.textSecondary,
                    fontWeight: warning ? FontWeight.w700 : null,
                  ),
                ),
                if (warning) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'Nobody is on $uncovered',
                    style: AppTypography.labelSmall.copyWith(
                      color: AppColors.warning,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          // Two affordances, two destinations. The chevron is NOT a second way
          // to open the roster — the whole row already does that; a button that
          // repeats its own container's tap is noise. It marks the row as
          // openable, and Edit is the one control that goes somewhere else.
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.textTertiary,
              ),
              TextButton.icon(
                onPressed: onEdit,
                icon: const Icon(Icons.edit_outlined, size: 16),
                label: const Text('Edit'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
