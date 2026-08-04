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
import 'package:drop/core/widgets/admin_section_header.dart';
import 'package:drop/core/widgets/app_empty_state.dart';
import 'package:drop/core/widgets/app_error_state.dart';
import 'package:drop/core/widgets/app_motion.dart';
import 'package:drop/core/widgets/responsive_card_grid.dart';
import 'package:drop/core/widgets/app_snackbar.dart';
import 'package:drop/core/widgets/brand_watermark.dart';
import 'package:drop/core/widgets/primary_cta.dart';
import 'package:drop/core/widgets/branch_avatar.dart';
import 'package:drop/core/widgets/glass_container.dart';
import 'package:drop/core/widgets/list_skeleton.dart';
import 'package:drop/core/widgets/metric_tile.dart';
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
import 'package:drop/features/task/domain/task_feed.dart';
import 'package:drop/features/task/presentation/cubit/task_cubit.dart';
import 'package:drop/features/task/presentation/pages/branch_task_list_screen.dart';
import 'package:drop/features/task/presentation/widgets/recurring_shift_task_sheets.dart';
import 'package:drop/features/task/presentation/widgets/task_template_sheets.dart';
import 'package:drop/features/task/presentation/widgets/task_browser.dart';
import 'package:drop/features/task/presentation/widgets/task_feed_row.dart';

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
    context.read<BranchOperationsCubit>().load(
      widget.branchId,
      branchName: widget.branchName,
    );
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

  void _openAllTasks() => Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => BranchTaskListScreen(
        branchId: widget.branchId,
        branchName: widget.branchName ?? 'Branch',
        isAdmin: context.isAdmin,
      ),
    ),
  );

  Future<void> _manageRecurringShiftTasks() async {
    await showManageRecurringShiftTasksSheet(
      context: context,
      cubit: context.read<TaskCubit>(),
      branchId: widget.branchId,
    );
    _refreshAutomationSummary();
  }

  void _openEmployee(UserEntity employee) => Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => EmployeeDetailScreen(
        employee: employee,
        isAdmin: context.isAdmin,
        defaultBranchId: widget.branchId,
      ),
    ),
  );

  void _openMetric(OperationsMetric metric) => Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => OperationsMetricScreen(
        metric: metric,
        branchId: widget.branchId,
        branchName: _branchLabel,
        isAdmin: context.isAdmin,
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final isDesktop = context.isDesktop;
    return AdaptiveScaffold(
      title: _branchLabel,
      titleWidget: BlocBuilder<BranchCubit, BranchState>(
        builder: (context, _) {
          final branch = context.read<BranchCubit>().branchById(
            widget.branchId,
          );
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
                child: Text(
                  branch?.name ?? _branchLabel,
                  style: isDesktop ? AppTypography.h1 : AppTypography.h3,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          );
        },
      ),
      // "All tasks" moved out of this unlabelled glyph and into the labelled
      // action row under the hero, which left the branch name room to breathe.
      actions: [
        IconButton(
          icon: const Icon(
            Icons.refresh_rounded,
            color: AppColors.textSecondary,
          ),
          tooltip: 'Refresh',
          onPressed: _refreshAll,
        ),
      ],
      // No FAB. An extended FAB parked over this page's **shift toggle**, so on
      // a phone the "Night" lens was permanently unreachable — a floating
      // control covering a real one. New Task is now the screen's single
      // primary CTA in the action row under the hero (V2: one primary action
      // per screen, in the header lockup), which cannot collide with anything.
      body: BlocConsumer<BranchOperationsCubit, BranchOperationsState>(
        listener: (context, state) =>
            state.whenOrNull(error: (m) => AppSnackbar.error(context, m)),
        builder: (context, state) => state.maybeWhen(
          loading: () => const ListSkeleton(),
          loaded: (branchId, workload, filter, branchName, directory) =>
              _cockpit(workload, filter),
          // The shared error surface, not a hand-rolled one: a failed load must
          // not look like an empty branch, and it must offer the retry.
          error: (m) => AppErrorState(message: m, onRetry: _refreshAll),
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
          // No FAB to clear any more — the tail is just breathing room.
          AppSpacing.xxxl,
        ),
        // One vertical rhythm for the whole cockpit: `xl` between sections,
        // `md` between a section's head and its body (owned by
        // `AdminSectionHeader`). Before this the page mixed lg/xl/md gaps, which
        // is what made five related blocks read as five unrelated widgets.
        children: [
          _BranchHero(
            branchId: widget.branchId,
            fallbackName: widget.branchName,
            employeeCount: employees.length,
            filter: filter,
          ),
          const SizedBox(height: AppSpacing.lg),
          _HeroActions(onNewTask: _newTask, onAllTasks: _openAllTasks),
          const SizedBox(height: AppSpacing.xl),
          OperationsSummaryHeader(
            summary: workload.summary,
            onSelect: _openMetric,
          ),
          const SizedBox(height: AppSpacing.xl),
          _BranchTasksPreview(
            branchId: widget.branchId,
            onViewAll: _openAllTasks,
          ),
          const SizedBox(height: AppSpacing.xl),
          // Automation sits with Tasks, not with Team: it is where this
          // branch's recurring *work* comes from.
          _AutomationOverview(
            future: _automationsFuture,
            onTap: _manageRecurringShiftTasks,
          ),
          const SizedBox(height: AppSpacing.xl),
          const AdminSectionHeader(
            title: 'Team',
            subtitle: 'Heaviest workload first',
          ),
          _ShiftToggle(
            value: filter,
            onChanged: (f) =>
                context.read<BranchOperationsCubit>().setFilter(f),
          ),
          const SizedBox(height: AppSpacing.md),
          _TeamCount(filter: filter, count: employees.length),
          const SizedBox(height: AppSpacing.sm),
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

/// The branch's most urgent work, inline. Six rows and one door — the section
/// head is the shared [AdminSectionHeader] every other section on this page
/// uses, so the block reads as part of the branch rather than as a bolted-on
/// task widget with its own title treatment and its own `TextButton`.
class _BranchTasksPreview extends StatelessWidget {
  const _BranchTasksPreview({required this.branchId, required this.onViewAll});
  final String branchId;
  final VoidCallback onViewAll;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      AdminSectionHeader(
        title: 'Tasks',
        subtitle: 'Open work, soonest first',
        actionLabel: 'View all',
        onAction: onViewAll,
      ),
      // Held in the page's own card surface, so the preview has a visible
      // beginning and end. Bare rows on the page background let a row's touch
      // highlight run edge to edge as a hard-cornered grey band — the one thing
      // on this screen that looked unfinished.
      //
      // The **active window**, not the whole archive. Browsing closed records
      // is what "View all" is for; a cockpit whose Tasks section filled up with
      // six approved tasks from a fortnight ago was answering a question nobody
      // standing in the branch was asking.
      GlassContainer(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
        child: TaskBrowser(
          compact: true,
          maxItems: 6,
          // Flush to the card: the row's own inset becomes the cell padding.
          horizontalPadding: kTaskRowInset,
          initialFilter: TaskFeedFilter(branchId: branchId),
          emptyMessage: 'Nothing open in this branch right now.',
        ),
      ),
    ],
  );
}

// ─── Hero actions (the screen's one primary CTA + its list door) ─────────────

/// The action row under the branch hero: the screen's single [PrimaryCta]
/// (**New Task**) beside the quiet door into the full branch task list.
///
/// Replaced a floating extended FAB (2026-08-03) that sat on top of the shift
/// toggle, making the "Night" lens unreachable on a phone. In the header the
/// CTA is labelled, always visible, and can never cover a real control.
class _HeroActions extends StatelessWidget {
  const _HeroActions({required this.onNewTask, required this.onAllTasks});

  final VoidCallback onNewTask;
  final VoidCallback onAllTasks;

  @override
  Widget build(BuildContext context) {
    // `IntrinsicHeight` + `stretch`, not a hard-coded 50: the secondary button
    // was two pixels taller than the CTA beside it, which is exactly the kind of
    // mismatch that reads as "unfinished" without anyone being able to name it.
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: PrimaryCta(
              icon: Icons.add_rounded,
              label: 'New Task',
              onTap: onNewTask,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Semantics(
            button: true,
            label: 'All tasks',
            child: InkWell(
              onTap: onAllTasks,
              borderRadius: AppRadius.buttonAll,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                decoration: BoxDecoration(
                  borderRadius: AppRadius.buttonAll,
                  border: Border.all(color: AppColors.darkBorder),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.checklist_rounded,
                      size: 18,
                      color: AppColors.textSecondary,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Text(
                      'All tasks',
                      style: AppTypography.label.copyWith(
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
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
        final empLabel = employeeCount == 1
            ? '1 employee'
            : '$employeeCount employees';
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
                              radius: 11,
                            ),
                            const SizedBox(width: AppSpacing.md),
                            Expanded(
                              child: Text(
                                name,
                                style: AppTypography.h2.copyWith(
                                  color: AppColors.textPrimary,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Row(
                          children: [
                            const Icon(
                              Icons.groups_outlined,
                              size: 14,
                              color: AppColors.textSecondary,
                            ),
                            const SizedBox(width: 5),
                            Text(
                              empLabel,
                              style: AppTypography.caption.copyWith(
                                color: AppColors.textSecondary,
                              ),
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            const Text(
                              '·',
                              style: TextStyle(color: AppColors.textTertiary),
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Icon(
                              shiftIcon,
                              size: 14,
                              color: AppColors.textSecondary,
                            ),
                            const SizedBox(width: 5),
                            Text(
                              shiftLabel,
                              style: AppTypography.caption.copyWith(
                                color: AppColors.textSecondary,
                              ),
                            ),
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
    // The shared `MetricTile` — this header's own private tile was extracted to
    // `core/widgets/` when Manager Home's Today row wanted the same cell, so the
    // two surfaces cannot drift into two dialects of the same metric.
    return MetricTileRow(
      tiles: [
        MetricTile(
          value: summary.activeTasks,
          label: 'Active tasks',
          icon: Icons.bolt_rounded,
          onTap: () => onSelect(OperationsMetric.activeTasks),
        ),
        MetricTile(
          value: summary.overdueTasks,
          label: 'Late',
          icon: Icons.warning_amber_rounded,
          alert: summary.overdueTasks > 0,
          onTap: () => onSelect(OperationsMetric.overdue),
        ),
        MetricTile(
          value: summary.pendingReviews,
          label: 'Pending review',
          icon: Icons.fact_check_outlined,
          onTap: () => onSelect(OperationsMetric.pendingReview),
        ),
        MetricTile(
          value: summary.staffActive,
          label: 'Staff active',
          icon: Icons.groups_2_outlined,
          onTap: () => onSelect(OperationsMetric.staffActive),
        ),
      ],
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
        // The displayed sentence, so a transient state never renders as the
        // nonsense "Next check Loading…".
        final nextSentence = loading
            ? 'Checking schedule…'
            : unavailable
            ? 'Summary unavailable'
            : nextCheck == null
            ? 'No check scheduled'
            : 'Next check $nextLabel';
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
                const SizedBox(height: AppSpacing.md),
                // A hairline, not a nested bordered box. The summary used to
                // sit inside a bordered container inside a bordered card, with
                // two more bordered pills inside that — four frames around two
                // numbers, and the single loudest block on the page.
                const Divider(
                  height: AppSpacing.lg,
                  thickness: 1,
                  color: AppColors.darkBorder,
                ),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final routines = Text(
                      loading || unavailable
                          ? '—'
                          : '$active active · $paused paused',
                      style: AppTypography.labelSmall,
                    );
                    final next = _AutomationNextCheck(label: nextSentence);

                    if (constraints.maxWidth >= 420) {
                      return Row(
                        children: [
                          routines,
                          const Spacer(),
                          Flexible(child: next),
                        ],
                      );
                    }
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        routines,
                        const SizedBox(height: AppSpacing.sm),
                        next,
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// When the generator next runs — one line, because it is one fact. It was an
/// 11px all-caps eyebrow stacked over a 14px value, which gave a scheduling
/// detail the shape of a section heading.
class _AutomationNextCheck extends StatelessWidget {
  const _AutomationNextCheck({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(
          Icons.schedule_rounded,
          size: 14,
          color: AppColors.textTertiary,
        ),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            label,
            style: AppTypography.caption.copyWith(
              color: AppColors.textSecondary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
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
                    color: value == f
                        ? AppColors.primary
                        : AppColors.transparent,
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

/// What the shift toggle currently resolves to, in words. The section's title
/// and its "heaviest workload first" rule moved up into the shared header, so
/// this line now says one thing — *who you are looking at* — instead of
/// carrying a title, a count and a sort rule in 11px caps.
class _TeamCount extends StatelessWidget {
  const _TeamCount({required this.filter, required this.count});
  final ShiftFilter filter;
  final int count;

  @override
  Widget build(BuildContext context) {
    final people = count == 1 ? '1 person' : '$count people';
    final text = filter == ShiftFilter.all
        ? '$people in this branch'
        : '$people on the ${filter.label.toLowerCase()} shift';
    return Text(
      text,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: AppTypography.caption.copyWith(color: AppColors.textSecondary),
    );
  }
}

// ─── Empty / error states ─────────────────────────────────────────────────────

/// Nobody to show. Uses the shared empty surface (the same medallion every
/// cleared list in the app draws) instead of a local icon-over-text stack, and
/// names *which* nothing it is — an empty branch and an empty night shift are
/// different facts with different answers.
class _EmptyTeam extends StatelessWidget {
  const _EmptyTeam({required this.filter});
  final ShiftFilter filter;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: AppSpacing.lg),
    child: AppEmptyState(
      icon: Icons.groups_outlined,
      title: filter == ShiftFilter.all
          ? 'No one in this branch yet'
          : 'No one on the ${filter.label.toLowerCase()} shift',
      message: filter == ShiftFilter.all
          ? 'Employees assigned to this branch will appear here with their '
                'workload.'
          : 'Switch the shift lens above, or check this week\'s schedule.',
    ),
  );
}
