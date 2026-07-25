import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:drop/core/extensions/context_extensions.dart';
import 'package:drop/core/responsive/breakpoints.dart';
import 'package:drop/core/theme/app_colors.dart';
import 'package:drop/core/theme/app_radius.dart';
import 'package:drop/core/theme/app_spacing.dart';
import 'package:drop/core/theme/app_typography.dart';
import 'package:drop/core/utils/app_date_formatter.dart';
import 'package:drop/core/widgets/adaptive_scaffold.dart';
import 'package:drop/core/widgets/app_motion.dart';
import 'package:drop/core/widgets/responsive_card_grid.dart';
import 'package:drop/core/widgets/app_snackbar.dart';
import 'package:drop/core/widgets/brand_watermark.dart';
import 'package:drop/core/widgets/branch_avatar.dart';
import 'package:drop/core/widgets/glass_container.dart';
import 'package:drop/core/widgets/list_skeleton.dart';
import 'package:drop/features/auth/domain/entities/user_entity.dart';
import 'package:drop/features/branch/presentation/cubit/branch_cubit.dart';
import 'package:drop/features/branch/presentation/cubit/branch_state.dart';
import 'package:drop/features/operations/domain/branch_summary.dart';
import 'package:drop/features/operations/domain/branch_workload.dart';
import 'package:drop/features/operations/domain/shift_filter.dart';
import 'package:drop/features/operations/presentation/cubit/branch_operations_cubit.dart';
import 'package:drop/features/operations/presentation/cubit/branch_operations_state.dart';
import 'package:drop/features/operations/presentation/pages/employee_detail_screen.dart';
import 'package:drop/features/operations/presentation/pages/operations_metric_screen.dart';
import 'package:drop/features/operations/presentation/widgets/workload_card.dart';
import 'package:drop/features/task/domain/entities/recurring_task_template_entity.dart';
import 'package:drop/features/task/presentation/cubit/task_cubit.dart';
import 'package:drop/features/task/presentation/pages/branch_task_list_screen.dart';
import 'package:drop/features/task/presentation/widgets/recurring_shift_task_sheets.dart';
import 'package:drop/features/task/presentation/widgets/task_template_sheets.dart';

/// The Branch Operations cockpit — the heart of the task→operations redesign.
/// One scannable surface that answers a manager/admin's real questions about a
/// branch (who's overloaded? what's overdue? what's awaiting review?) in
/// seconds: a four-stat summary header, an instant shift lens, and
/// overload-first employee workload cards. Tasks live *inside* here (drill into
/// an employee, or "All tasks") — there is no standalone task list destination.
///
/// Shared by manager (their own branch — reached from the nav) and admin (any
/// branch — reached from the branch overview drill). Display is driven by
/// [BranchOperationsCubit] (read/derive); writes flow through [TaskCubit], which
/// is also loaded here so downstream task screens stay live.
class BranchOperationsScreen extends StatefulWidget {
  const BranchOperationsScreen({
    super.key,
    required this.branchId,
    this.branchName,
  });

  final String branchId;
  final String? branchName;

  @override
  State<BranchOperationsScreen> createState() => _BranchOperationsScreenState();
}

class _BranchOperationsScreenState extends State<BranchOperationsScreen> {
  Future<List<RecurringTaskTemplateEntity>>? _automationsFuture;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  void _load() {
    // Branch directory for the header logo (§8b) — cheap + cached.
    context.read<BranchCubit>().loadIfNeeded();
    context
        .read<BranchOperationsCubit>()
        .load(widget.branchId, branchName: widget.branchName);
    // Load the task workflow stream too, so the employee drill-down, Task
    // Details actions and the "All tasks" list are live + writable here.
    final user = context.currentUser;
    if (user != null) context.read<TaskCubit>().load(user);
    _refreshAutomationSummary();
  }

  void _refreshAutomationSummary() {
    if (!mounted) return;
    setState(() {
      _automationsFuture = context.read<TaskCubit>().recurringTemplates(
        widget.branchId,
      );
    });
  }

  Future<void> _refreshAll() {
    _refreshAutomationSummary();
    return context.read<BranchOperationsCubit>().refresh();
  }

  String get _branchLabel => widget.branchName ?? 'Branch operations';

  Future<void> _newTask() => startNewTaskFlow(
        context: context,
        cubit: context.read<TaskCubit>(),
        // Branch is fixed to this cockpit's branch for both roles.
        isAdmin: false,
        defaultBranchId: widget.branchId,
        templateBranchFilter: widget.branchId,
      );

  void _openAllTasks() => Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => BranchTaskListScreen(
          branchId: widget.branchId,
          branchName: widget.branchName ?? 'Branch',
          isAdmin: context.isAdmin,
        ),
      ));

  Future<void> _manageRecurringShiftTasks() async {
    await showManageRecurringShiftTasksSheet(
      context: context,
      cubit: context.read<TaskCubit>(),
      branchId: widget.branchId,
    );
    _refreshAutomationSummary();
  }

  void _openEmployee(UserEntity employee) =>
      Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => EmployeeDetailScreen(
          employee: employee,
          isAdmin: context.isAdmin,
          defaultBranchId: widget.branchId,
        ),
      ));

  void _openMetric(OperationsMetric metric) =>
      Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => OperationsMetricScreen(
          metric: metric,
          branchId: widget.branchId,
          branchName: _branchLabel,
          isAdmin: context.isAdmin,
        ),
      ));

  @override
  Widget build(BuildContext context) {
    final isDesktop = context.isDesktop;
    return AdaptiveScaffold(
      title: _branchLabel,
      titleWidget: BlocBuilder<BranchCubit, BranchState>(
        builder: (context, _) {
          final branch = context.read<BranchCubit>().branchById(widget.branchId);
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              BranchAvatar(
                logoUrl: branch?.logoUrl,
                name: branch?.name ?? _branchLabel,
                size: isDesktop ? 40 : 30,
                radius: isDesktop ? 12 : 9,
              ),
              const SizedBox(width: AppSpacing.sm),
              Flexible(
                child: Text(branch?.name ?? _branchLabel,
                    style: isDesktop ? AppTypography.h1 : AppTypography.h3,
                    overflow: TextOverflow.ellipsis),
              ),
            ],
          );
        },
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.checklist_rounded,
              color: AppColors.textSecondary),
          tooltip: 'All tasks',
          onPressed: _openAllTasks,
        ),
        IconButton(
          icon: const Icon(Icons.refresh_rounded,
              color: AppColors.textSecondary),
          tooltip: 'Refresh',
          onPressed: _refreshAll,
        ),
      ],
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _newTask,
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.onPrimary,
        icon: const Icon(Icons.add_rounded),
        label: Text('New Task',
            style: AppTypography.label.copyWith(color: AppColors.onPrimary)),
      ),
      body: BlocConsumer<BranchOperationsCubit, BranchOperationsState>(
        listener: (context, state) =>
            state.whenOrNull(error: (m) => AppSnackbar.error(context, m)),
        builder: (context, state) => state.maybeWhen(
          loading: () => const ListSkeleton(),
          loaded: (branchId, workload, filter, branchName, directory) =>
              _cockpit(workload, filter),
          error: (m) => _ErrorState(message: m, onRetry: _refreshAll),
          orElse: () => const SizedBox.shrink(),
        ),
      ),
    );
  }

  Widget _cockpit(BranchWorkload workload, ShiftFilter filter) {
    final employees = workload.employees;
    return RefreshIndicator(
      onRefresh: _refreshAll,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.pagePadding,
          AppSpacing.lg,
          AppSpacing.pagePadding,
          AppSpacing.xxxl * 2,
        ),
        children: [
          _BranchHero(
            branchId: widget.branchId,
            fallbackName: widget.branchName,
            employeeCount: employees.length,
            filter: filter,
          ),
          const SizedBox(height: AppSpacing.lg),
          OperationsSummaryHeader(
            summary: workload.summary,
            onSelect: _openMetric,
          ),
          const SizedBox(height: AppSpacing.xl),
          _AutomationOverview(
            future: _automationsFuture,
            onTap: _manageRecurringShiftTasks,
          ),
          const SizedBox(height: AppSpacing.xl),
          _ShiftToggle(
            value: filter,
            onChanged: (f) => context.read<BranchOperationsCubit>().setFilter(f),
          ),
          const SizedBox(height: AppSpacing.lg),
          _SectionLabel(filter: filter, count: employees.length),
          const SizedBox(height: AppSpacing.md),
          if (employees.isEmpty)
            _EmptyTeam(filter: filter)
          else
            ResponsiveCardGrid(
              runSpacing: 0, // WorkloadCard carries its own bottom margin
              maxItemWidth: 460,
              children: [
                for (var i = 0; i < employees.length; i++)
                  EntranceFade(
                    delay: staggerDelay(i),
                    child: WorkloadCard(
                      workload: employees[i],
                      onTap: () => _openEmployee(employees[i].user),
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

// ─── Branch hero (§8c — cover image · identity · shift) ───────────────────────

/// A premium 16:9 branch hero: the branch **cover** photo (dark-overlaid for
/// legibility) behind the logo, name, employee count and active-shift summary —
/// or a premium **monochrome** surface when no cover is set. Carries a subtle
/// [BrandWatermark] (§9b Wave 3, now unblocked). The cover/logo resolve from the
/// app-wide [BranchCubit] directory, so it works on any branch.
class _BranchHero extends StatelessWidget {
  const _BranchHero({
    required this.branchId,
    required this.fallbackName,
    required this.employeeCount,
    required this.filter,
  });

  final String branchId;
  final String? fallbackName;
  final int employeeCount;
  final ShiftFilter filter;

  (IconData, String) get _shift => switch (filter) {
        ShiftFilter.all => (Icons.schedule_rounded, 'All shifts'),
        ShiftFilter.morning => (Icons.wb_sunny_outlined, 'Morning shift'),
        ShiftFilter.night => (Icons.nightlight_outlined, 'Night shift'),
      };

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<BranchCubit, BranchState>(
      builder: (context, _) {
        final branch = context.read<BranchCubit>().branchById(branchId);
        final name = branch?.name ?? fallbackName ?? 'Branch';
        final cover = branch?.coverUrl ?? '';
        final hasCover = cover.isNotEmpty;
        final empLabel =
            employeeCount == 1 ? '1 employee' : '$employeeCount employees';
        final (shiftIcon, shiftLabel) = _shift;

        return Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            borderRadius: AppRadius.cardAll,
            border: Border.all(color: AppColors.darkBorder),
            boxShadow: [
              BoxShadow(
                color: AppColors.black.withAlpha(40),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          // A fixed banner height (not a 16:9 aspect ratio) so the cover stays a
          // slim premium hero on wide desktop windows instead of ballooning to
          // ~700px tall. The image fills it via BoxFit.cover.
          child: SizedBox(
            height: context.isDesktop ? 230 : 190,
            child: BrandWatermark(
              opacity: 0.03,
              fontSize: 64,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Background — cover photo (with a dark scrim) or premium mono.
                  if (hasCover) ...[
                    Image.network(
                      cover,
                      fit: BoxFit.cover,
                      cacheWidth: 1400,
                      errorBuilder: (_, _, _) => const _MonoHeroBg(),
                    ),
                    // ~70% dark overlay for text legibility (gradient = stronger
                    // at the bottom where the content sits).
                    const DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Color(0x59000000), Color(0xCC000000)],
                        ),
                      ),
                    ),
                  ] else
                    const _MonoHeroBg(),

                  // Content — identity + stats, bottom-left.
                  Padding(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            BranchAvatar(
                                logoUrl: branch?.logoUrl,
                                name: name,
                                size: 40,
                                radius: 11),
                            const SizedBox(width: AppSpacing.md),
                            Expanded(
                              child: Text(
                                name,
                                style: AppTypography.h2
                                    .copyWith(color: AppColors.textPrimary),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Row(
                          children: [
                            const Icon(Icons.groups_outlined,
                                size: 14, color: AppColors.textSecondary),
                            const SizedBox(width: 5),
                            Text(empLabel,
                                style: AppTypography.caption
                                    .copyWith(color: AppColors.textSecondary)),
                            const SizedBox(width: AppSpacing.sm),
                            const Text('·',
                                style: TextStyle(color: AppColors.textTertiary)),
                            const SizedBox(width: AppSpacing.sm),
                            Icon(shiftIcon,
                                size: 14, color: AppColors.textSecondary),
                            const SizedBox(width: 5),
                            Text(shiftLabel,
                                style: AppTypography.caption
                                    .copyWith(color: AppColors.textSecondary)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// The premium monochrome hero background — the cover fallback.
class _MonoHeroBg extends StatelessWidget {
  const _MonoHeroBg();

  @override
  Widget build(BuildContext context) => const DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [AppColors.darkSurfaceElevated, AppColors.darkSurface],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
      );
}

// ─── Summary header (branch health in 3 seconds) ──────────────────────────────

class OperationsSummaryHeader extends StatelessWidget {
  const OperationsSummaryHeader({
    super.key,
    required this.summary,
    required this.onSelect,
  });

  final BranchSummary summary;
  final ValueChanged<OperationsMetric> onSelect;

  @override
  Widget build(BuildContext context) {
    final tiles = <Widget>[
      _StatTile(
        value: summary.activeTasks,
        label: 'Active tasks',
        icon: Icons.bolt_rounded,
        onTap: () => onSelect(OperationsMetric.activeTasks),
      ),
      _StatTile(
        value: summary.overdueTasks,
        label: 'Overdue',
        icon: Icons.warning_amber_rounded,
        alert: summary.overdueTasks > 0,
        onTap: () => onSelect(OperationsMetric.overdue),
      ),
      _StatTile(
        value: summary.pendingReviews,
        label: 'Pending review',
        icon: Icons.fact_check_outlined,
        onTap: () => onSelect(OperationsMetric.pendingReview),
      ),
      _StatTile(
        value: summary.staffActive,
        label: 'Staff active',
        icon: Icons.groups_2_outlined,
        onTap: () => onSelect(OperationsMetric.staffActive),
      ),
    ];

    // Desktop: one tight row of four compact stat tiles (not 2×2 giant cards).
    if (context.isDesktop) {
      return Row(
        children: [
          for (var i = 0; i < tiles.length; i++) ...[
            if (i > 0) const SizedBox(width: AppSpacing.sm),
            Expanded(child: tiles[i]),
          ],
        ],
      );
    }

    // Mobile / tablet: 2×2.
    return Column(
      children: [
        Row(children: [
          Expanded(child: tiles[0]),
          const SizedBox(width: AppSpacing.sm),
          Expanded(child: tiles[1]),
        ]),
        const SizedBox(height: AppSpacing.sm),
        Row(children: [
          Expanded(child: tiles[2]),
          const SizedBox(width: AppSpacing.sm),
          Expanded(child: tiles[3]),
        ]),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.value,
    required this.label,
    required this.icon,
    required this.onTap,
    this.alert = false,
  });

  final int value;
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool alert;

  @override
  Widget build(BuildContext context) {
    final color = alert ? AppColors.error : AppColors.textPrimary;
    return Semantics(
      button: true,
      label: 'Open $label',
      child: GlassContainer(
        onTap: onTap,
        padding: const EdgeInsets.symmetric(
            vertical: AppSpacing.md, horizontal: AppSpacing.lg),
        borderRadius: AppRadius.lgAll,
        highlight: alert,
        accent: AppColors.error,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  '$value',
                  style: AppTypography.h1.copyWith(
                    fontSize: 26,
                    color: color,
                  ),
                ),
                const Spacer(),
                const Icon(Icons.arrow_outward_rounded,
                    size: 16, color: AppColors.textTertiary),
              ],
            ),
            const SizedBox(height: 2),
            Row(
              children: [
                Icon(icon, size: 13, color: color.withAlpha(180)),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(label,
                      style: AppTypography.caption,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Automation entrypoint (summary, never a second screen) ─────────────────

class _AutomationOverview extends StatelessWidget {
  const _AutomationOverview({required this.future, required this.onTap});

  final Future<List<RecurringTaskTemplateEntity>>? future;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<RecurringTaskTemplateEntity>>(
      future: future,
      builder: (context, snapshot) {
        final loading =
            future == null || snapshot.connectionState != ConnectionState.done;
        final unavailable = snapshot.hasError;
        final templates = snapshot.data ?? const [];
        final active = templates.where((template) => template.active).length;
        final paused = templates.length - active;
        final nextChecks =
            templates
                .where((template) => template.active)
                .map((template) => template.nextRunAt)
                .whereType<DateTime>()
                .toList()
              ..sort();
        final nextCheck = nextChecks.firstOrNull;
        final nextLabel = loading
            ? 'Loading…'
            : unavailable
            ? 'Summary unavailable'
            : nextCheck == null
            ? 'Not scheduled yet'
            : AppDateFormatter.relativeDayTime(nextCheck);
        final semanticsLabel = loading
            ? 'Open Automation Center. Automation summary loading.'
            : 'Open Automation Center. $active active, $paused paused. '
                  'Next automation check: $nextLabel.';

        return Semantics(
          button: true,
          label: semanticsLabel,
          child: GlassContainer(
            onTap: onTap,
            padding: EdgeInsets.all(
              context.isDesktop ? AppSpacing.xl : AppSpacing.lg,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: AppColors.darkSurfaceElevated,
                        borderRadius: AppRadius.mdAll,
                        border: Border.all(color: AppColors.darkBorder),
                      ),
                      child: const Icon(
                        Icons.event_repeat_rounded,
                        size: 20,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Automation', style: AppTypography.h3),
                          const SizedBox(height: 2),
                          Text(
                            'Manage recurring shift routines',
                            style: AppTypography.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    const Icon(
                      Icons.arrow_forward_rounded,
                      size: 18,
                      color: AppColors.textTertiary,
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.md,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.darkSurfaceElevated,
                    borderRadius: AppRadius.mdAll,
                    border: Border.all(color: AppColors.darkBorder),
                  ),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final counts = Wrap(
                        spacing: AppSpacing.sm,
                        runSpacing: AppSpacing.sm,
                        children: [
                          _AutomationCountChip(
                            count: loading || unavailable ? null : active,
                            label: 'Active',
                          ),
                          _AutomationCountChip(
                            count: loading || unavailable ? null : paused,
                            label: 'Paused',
                          ),
                        ],
                      );
                      final next = _AutomationNextCheck(label: nextLabel);

                      if (constraints.maxWidth >= 560) {
                        return Row(
                          children: [
                            Expanded(child: counts),
                            const SizedBox(width: AppSpacing.xl),
                            next,
                          ],
                        );
                      }
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          counts,
                          const SizedBox(height: AppSpacing.md),
                          next,
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _AutomationCountChip extends StatelessWidget {
  const _AutomationCountChip({required this.count, required this.label});

  final int? count;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: AppColors.darkSurface,
        borderRadius: AppRadius.fullAll,
        border: Border.all(color: AppColors.darkBorder),
      ),
      child: Text(
        '${count ?? '—'} $label',
        style: AppTypography.labelSmall.copyWith(
          color: AppColors.textSecondary,
        ),
      ),
    );
  }
}

class _AutomationNextCheck extends StatelessWidget {
  const _AutomationNextCheck({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 300),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'NEXT AUTOMATION CHECK',
            style: AppTypography.caption.copyWith(letterSpacing: 0.6),
          ),
          const SizedBox(height: AppSpacing.xs),
          Row(
            children: [
              const Icon(
                Icons.schedule_rounded,
                size: 15,
                color: AppColors.textSecondary,
              ),
              const SizedBox(width: AppSpacing.sm),
              Flexible(
                child: Text(
                  label,
                  style: AppTypography.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Shift lens (a toggle, never a screen) ────────────────────────────────────

class _ShiftToggle extends StatelessWidget {
  const _ShiftToggle({required this.value, required this.onChanged});
  final ShiftFilter value;
  final ValueChanged<ShiftFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.darkSurface,
        borderRadius: AppRadius.mdAll,
        border: Border.all(color: AppColors.darkBorder),
      ),
      child: Row(
        children: [
          for (final f in ShiftFilter.values)
            Expanded(
              child: GestureDetector(
                onTap: () => onChanged(f),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  curve: Curves.easeOut,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: value == f ? AppColors.primary : AppColors.transparent,
                    borderRadius: AppRadius.smAll,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    f.label,
                    style: AppTypography.label.copyWith(
                      color: value == f
                          ? AppColors.onPrimary
                          : AppColors.textSecondary,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.filter, required this.count});
  final ShiftFilter filter;
  final int count;

  @override
  Widget build(BuildContext context) {
    final text = filter == ShiftFilter.all
        ? 'TEAM · $count'
        : '${filter.label.toUpperCase()} · $count ON SHIFT';
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.caption.copyWith(
                  color: AppColors.textSecondary, letterSpacing: 0.6)),
        ),
        const SizedBox(width: AppSpacing.sm),
        const Text('overload first', style: AppTypography.caption),
      ],
    );
  }
}

// ─── Empty / error states ─────────────────────────────────────────────────────

class _EmptyTeam extends StatelessWidget {
  const _EmptyTeam({required this.filter});
  final ShiftFilter filter;

  @override
  Widget build(BuildContext context) {
    final msg = filter == ShiftFilter.all
        ? 'No active employees in this branch yet.'
        : 'No one is on the ${filter.label.toLowerCase()} shift today.';
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.xxl),
      child: Column(
        children: [
          const Icon(Icons.groups_outlined,
              color: AppColors.textTertiary, size: 36),
          const SizedBox(height: AppSpacing.md),
          Text(msg, style: AppTypography.body, textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded,
                color: AppColors.textTertiary, size: 40),
            const SizedBox(height: AppSpacing.md),
            Text(message,
                style: AppTypography.body, textAlign: TextAlign.center),
            const SizedBox(height: AppSpacing.lg),
            TextButton(
              onPressed: onRetry,
              child: Text('Retry',
                  style: AppTypography.label
                      .copyWith(color: AppColors.textPrimary)),
            ),
          ],
        ),
      ),
    );
  }
}
