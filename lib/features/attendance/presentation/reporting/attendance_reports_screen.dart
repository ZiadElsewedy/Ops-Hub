import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:drop/core/di/injection.dart';
import 'package:drop/core/enums/user_role.dart';
import 'package:drop/core/extensions/context_extensions.dart';
import 'package:drop/core/routes/route_names.dart';
import 'package:drop/core/responsive/breakpoints.dart';
import 'package:drop/core/theme/app_colors.dart';
import 'package:drop/core/theme/app_radius.dart';
import 'package:drop/core/theme/app_spacing.dart';
import 'package:drop/core/theme/app_typography.dart';
import 'package:drop/core/widgets/adaptive_scaffold.dart';
import 'package:drop/core/widgets/attention_tile.dart';
import 'package:drop/core/widgets/glass_container.dart';
import 'package:drop/core/widgets/page_hero.dart';
import 'package:drop/core/widgets/skeleton.dart';
import 'package:drop/features/attendance/domain/reporting/attendance_period.dart';
import 'package:drop/features/attendance/domain/reporting/attendance_report.dart';
import 'package:drop/features/attendance/presentation/reporting/attendance_report_cubit.dart';
import 'package:drop/features/attendance/presentation/reporting/attendance_report_state.dart';
import 'package:drop/features/attendance/presentation/reporting/widgets/attendance_report_coverage.dart';
import 'package:drop/features/attendance/presentation/reporting/widgets/attendance_report_metrics.dart';
import 'package:drop/features/attendance/presentation/reporting/widgets/attendance_report_scope_bar.dart';
import 'package:drop/features/branch/domain/entities/branch_entity.dart';
import 'package:drop/features/branch/presentation/cubit/branch_cubit.dart';
import 'package:drop/features/branch/presentation/cubit/branch_state.dart';

class AttendanceReportsScreen extends StatelessWidget {
  const AttendanceReportsScreen({super.key, this.cubit, this.now});

  final AttendanceReportCubit? cubit;
  final DateTime? now;

  @override
  Widget build(BuildContext context) {
    final view = _AttendanceReportsView(now: now);
    final provided = cubit;
    if (provided != null) {
      return BlocProvider<AttendanceReportCubit>.value(
        value: provided,
        child: view,
      );
    }
    return BlocProvider<AttendanceReportCubit>(
      create: (_) => AppDependencies.createAttendanceReportCubit(),
      child: view,
    );
  }
}

class _AttendanceReportsView extends StatefulWidget {
  const _AttendanceReportsView({this.now});

  final DateTime? now;

  @override
  State<_AttendanceReportsView> createState() => _AttendanceReportsViewState();
}

class _AttendanceReportsViewState extends State<_AttendanceReportsView> {
  late AttendancePeriodType _periodType = AttendancePeriodType.weekly;
  late AttendancePeriodWindow _window = _windowFor(_periodType, _now);
  String? _selectedBranchId;
  bool _bootstrapped = false;

  DateTime get _now => widget.now ?? DateTime.now();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_bootstrapped) return;
    _bootstrapped = true;
    final user = context.currentUser;
    if (user?.role.isManager ?? false) {
      _selectedBranchId = user?.branchId;
    }
    context.read<BranchCubit>().loadIfNeeded();
    WidgetsBinding.instance.addPostFrameCallback((_) => _syncReport());
  }

  void _syncReport() {
    if (!mounted) return;
    final branchId = _selectedBranchId;
    if (branchId == null || branchId.trim().isEmpty) return;
    context.read<AttendanceReportCubit>().watchBranchWindow(
      branchId: branchId,
      window: _window,
    );
  }

  void _setBranch(String? branchId) {
    setState(() => _selectedBranchId = branchId);
    WidgetsBinding.instance.addPostFrameCallback((_) => _syncReport());
  }

  void _setPeriodType(AttendancePeriodType type) {
    setState(() {
      _periodType = type;
      _window = _windowFor(type, _now);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _syncReport());
  }

  void _previousPeriod() {
    setState(() => _window = _shiftWindow(_periodType, _window, -1));
    WidgetsBinding.instance.addPostFrameCallback((_) => _syncReport());
  }

  void _nextPeriod() {
    final next = _shiftWindow(_periodType, _window, 1);
    final current = _windowFor(_periodType, _now);
    if (next.startDate.isAfter(current.startDate)) return;
    setState(() => _window = next);
    WidgetsBinding.instance.addPostFrameCallback((_) => _syncReport());
  }

  @override
  Widget build(BuildContext context) {
    final user = context.currentUser;
    final role = user?.role ?? UserRole.employee;
    return AdaptiveScaffold(
      title: 'Attendance & Reports',
      subtitle: 'Reporting ledger hub',
      compactDesktopHeader: true,
      actions: [
        IconButton(
          tooltip: 'Refresh report',
          onPressed: _selectedBranchId == null
              ? null
              : () => context.read<AttendanceReportCubit>().refresh(),
          icon: const Icon(Icons.refresh_rounded),
        ),
      ],
      body: BlocBuilder<BranchCubit, BranchState>(
        builder: (context, branchState) {
          final branches = branchState.maybeWhen(
            loaded: (items, _) => items,
            orElse: () => const <BranchEntity>[],
          );
          final selectedBranch = _branchById(branches, _selectedBranchId);
          final branchLabel =
              selectedBranch?.name ?? _selectedBranchId ?? 'No branch selected';

          return BlocBuilder<AttendanceReportCubit, AttendanceReportState>(
            builder: (context, reportState) {
              return RefreshIndicator(
                onRefresh: () =>
                    context.read<AttendanceReportCubit>().refresh(),
                child: ListView(
                  key: const PageStorageKey('attendance-reports-dashboard'),
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: EdgeInsets.fromLTRB(
                    AppSpacing.pagePadding,
                    AppSpacing.lg,
                    AppSpacing.pagePadding,
                    context.isDesktop ? AppSpacing.xxxl : AppSpacing.xxxl * 2,
                  ),
                  children: [
                    PageHero(
                      eyebrow: 'Attendance reporting ledger',
                      title: 'Attendance & Reports',
                      subtitle:
                          'Which periods and branches need attention before payroll, and can you trust these numbers yet?',
                      // No primaryAction: PageHero leaves the action slot too
                      // little width beside this title/subtitle, and a disabled
                      // button overflowed PremiumButton's Row by 175px. The
                      // period-close affordance lives in the "coming next"
                      // tiles below, where it lays out safely at every width.
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    AttendanceReportScopeBar(
                      role: role,
                      branches: branches,
                      selectedBranchId: _selectedBranchId,
                      periodType: _periodType,
                      window: _window,
                      now: _now,
                      onBranchChanged: _setBranch,
                      onPeriodTypeChanged: _setPeriodType,
                      onPrevious: _previousPeriod,
                      onNext: _nextPeriod,
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    if (_selectedBranchId == null ||
                        _selectedBranchId!.trim().isEmpty)
                      _NoBranchSelected(role: role)
                    else
                      _ReportBody(
                        state: reportState,
                        branchLabel: branchLabel,
                        branchId: _selectedBranchId!,
                        window: _window,
                      ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  static BranchEntity? _branchById(List<BranchEntity> branches, String? id) {
    if (id == null) return null;
    for (final branch in branches) {
      if (branch.id == id) return branch;
    }
    return null;
  }

  static AttendancePeriodWindow _windowFor(
    AttendancePeriodType type,
    DateTime anchor,
  ) {
    return switch (type) {
      AttendancePeriodType.monthly => monthlyWindow(anchor.year, anchor.month),
      _ => weeklyWindow(anchor),
    };
  }

  static AttendancePeriodWindow _shiftWindow(
    AttendancePeriodType type,
    AttendancePeriodWindow window,
    int delta,
  ) {
    return switch (type) {
      AttendancePeriodType.monthly => monthlyWindow(
        window.startDate.year,
        window.startDate.month + delta,
      ),
      _ => weeklyWindow(window.startDate.add(Duration(days: 7 * delta))),
    };
  }
}

class _ReportBody extends StatelessWidget {
  const _ReportBody({
    required this.state,
    required this.branchLabel,
    required this.branchId,
    required this.window,
  });

  final AttendanceReportState state;
  final String branchLabel;
  final String branchId;
  final AttendancePeriodWindow window;

  @override
  Widget build(BuildContext context) {
    if (state.status == AttendanceReportStatus.error) {
      return _ErrorPanel(message: _actionableError(state.message));
    }
    if (state.status == AttendanceReportStatus.initial) {
      return const _LoadingDashboard();
    }
    if (state.status == AttendanceReportStatus.loading &&
        !state.coverage.hasRows) {
      return const _LoadingDashboard();
    }
    if (state.coverage.awaitingClose) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AttendanceReportCoverage(
            coverage: state.coverage,
            totalRows: state.rows.length,
          ),
          const SizedBox(height: AppSpacing.xl),
          _ComingNextGrid(
            branchLabel: branchLabel,
            branchId: branchId,
            window: window,
          ),
        ],
      );
    }

    final blockers = state.coverage.blockingExceptionRowCount;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _NeedsAttention(blockers: blockers, branchLabel: branchLabel),
        const SizedBox(height: AppSpacing.xl),
        AttendanceReportCoverage(
          coverage: state.coverage,
          totalRows: state.rows.length,
        ),
        const SizedBox(height: AppSpacing.xl),
        AttendanceReportMetrics(summary: state.summary),
        const SizedBox(height: AppSpacing.xl),
        _BranchPeriodPreview(
          branchLabel: branchLabel,
          status: blockers > 0 ? 'Partially closed' : 'Fully closed',
          blockers: blockers,
          showUp: _rateValue(state.summary.showUpRate),
          expected: state.summary.expectedWorkShifts,
        ),
        const SizedBox(height: AppSpacing.xl),
        _ComingNextGrid(
          branchLabel: branchLabel,
          branchId: branchId,
          window: window,
        ),
      ],
    );
  }

  static String _rateValue(AttendanceRate rate) {
    final percent = rate.percent;
    return percent == null ? '--' : '${percent.round()}%';
  }

  static String _actionableError(String? message) {
    final raw = message ?? 'Failed to load attendance report.';
    final lower = raw.toLowerCase();
    if (lower.contains('failed-precondition') ||
        lower.contains('requires an index') ||
        lower.contains('composite index')) {
      return 'Attendance report query requires the attendance_expectations branch/dayKey or user/dayKey composite index. Deploy firestore.indexes.json, then reload. $raw';
    }
    return raw;
  }
}

class _NeedsAttention extends StatelessWidget {
  const _NeedsAttention({required this.blockers, required this.branchLabel});

  final int blockers;
  final String branchLabel;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 840 ? 3 : 1;
        final children = [
          AttentionTile(
            icon: Icons.block_outlined,
            label: 'Payroll blockers',
            count: blockers,
            sublabel: 'Rows preventing a trustworthy report',
            clearedMessage: 'No payroll blockers',
            onTap: () => context.showInfo('Exception queue is coming next.'),
          ),
          AttentionTile(
            icon: Icons.verified_outlined,
            label: 'Ready periods',
            count: blockers == 0 ? 1 : 0,
            sublabel: branchLabel,
            clearedMessage: 'Not ready yet',
            onTap: () => context.showInfo('Period lock is coming next.'),
          ),
          AttentionTile(
            icon: Icons.history_toggle_off_rounded,
            label: 'Restatements',
            count: 0,
            clearedMessage: 'No restatements',
            onTap: () =>
                context.showInfo('Restatement history is coming next.'),
          ),
        ];
        // Natural height, no fixed aspect ratio. AttentionTile's content varies
        // with its sublabel, so any childAspectRatio is a guess that clips at
        // some width — it overflowed by 45px at 390pt. This mirrors the
        // no-fixed-card-extent pattern the Employees directory already uses.
        if (columns == 1) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < children.length; i++) ...[
                if (i > 0) const SizedBox(height: AppSpacing.md),
                children[i],
              ],
            ],
          );
        }
        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < children.length; i++) ...[
                if (i > 0) const SizedBox(width: AppSpacing.md),
                Expanded(child: children[i]),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _BranchPeriodPreview extends StatelessWidget {
  const _BranchPeriodPreview({
    required this.branchLabel,
    required this.status,
    required this.blockers,
    required this.showUp,
    required this.expected,
  });

  final String branchLabel;
  final String status;
  final int blockers;
  final String showUp;
  final int expected;

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Branch periods', style: AppTypography.h3),
          const SizedBox(height: AppSpacing.md),
          Container(
            decoration: BoxDecoration(
              borderRadius: AppRadius.lgAll,
              border: Border.all(color: AppColors.darkBorder),
            ),
            child: Column(
              children: [
                _PeriodRow(
                  cells: const [
                    'Branch',
                    'Status',
                    'Blockers',
                    'Show-up',
                    'Expected',
                  ],
                  header: true,
                ),
                _PeriodRow(
                  cells: [
                    branchLabel,
                    status,
                    '$blockers',
                    showUp,
                    '$expected',
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PeriodRow extends StatelessWidget {
  const _PeriodRow({required this.cells, this.header = false});

  final List<String> cells;
  final bool header;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: header ? AppColors.darkBorder : AppColors.transparent,
          ),
        ),
      ),
      child: Row(
        children: [
          for (final cell in cells)
            Expanded(
              child: Text(
                cell,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: (header ? AppTypography.caption : AppTypography.label)
                    .copyWith(
                      color: header
                          ? AppColors.textTertiary
                          : AppColors.textSecondary,
                      fontWeight: header ? FontWeight.w600 : FontWeight.w500,
                    ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ComingNextGrid extends StatelessWidget {
  const _ComingNextGrid({
    required this.branchLabel,
    required this.branchId,
    required this.window,
  });

  final String branchLabel;
  final String branchId;
  final AttendancePeriodWindow window;

  @override
  Widget build(BuildContext context) {
    final weeklyPeriodId = attendancePeriodId(
      type: AttendancePeriodType.weekly,
      scopeKey: branchId,
      window: window,
    );
    final items = [
      _NextItem(
        'Weekly report',
        'Open report',
        Icons.calendar_view_week,
        onTap: () => context.push(RouteNames.attendanceWeekly(weeklyPeriodId)),
      ),
      _NextItem('Monthly report', 'Coming next', Icons.calendar_month),
      _NextItem('Per-employee report', 'Coming next', Icons.badge_outlined),
      _NextItem('Period close', 'Coming next', Icons.lock_clock_outlined),
      _NextItem('Export ledger', 'Coming next', Icons.file_download_outlined),
    ];
    return GlassContainer(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Next reporting surfaces', style: AppTypography.h3),
          const SizedBox(height: AppSpacing.xs),
          Text(
            '$branchLabel stays on this hub until the later report slices ship.',
            style: AppTypography.caption.copyWith(
              color: AppColors.textTertiary,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth >= 780 ? 4 : 2;
              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: items.length,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: columns,
                  crossAxisSpacing: AppSpacing.md,
                  mainAxisSpacing: AppSpacing.md,
                  // Fits AppSpacing.md padding + a one-line title + the
                  // sublabel. 92 left ~6px too little and the tile clipped its
                  // own sublabel; see the same class of bug in
                  // attendance_report_metrics.dart.
                  mainAxisExtent: 104,
                ),
                itemBuilder: (context, index) => _NextTile(item: items[index]),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _NextTile extends StatelessWidget {
  const _NextTile({required this.item});

  final _NextItem item;

  @override
  Widget build(BuildContext context) {
    final enabled = item.onTap != null;
    return Opacity(
      opacity: enabled ? 1 : 0.62,
      child: Material(
        color: AppColors.transparent,
        child: InkWell(
          borderRadius: AppRadius.lgAll,
          onTap: item.onTap,
          child: Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              borderRadius: AppRadius.lgAll,
              border: Border.all(
                color: enabled ? AppColors.accentBorder : AppColors.darkBorder,
              ),
              color: AppColors.darkSurfaceElevated,
            ),
            child: Row(
              children: [
                Icon(
                  item.icon,
                  color: enabled
                      ? AppColors.textSecondary
                      : AppColors.textTertiary,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        item.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.label.copyWith(
                          color: enabled
                              ? AppColors.textPrimary
                              : AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        item.subtitle,
                        style: AppTypography.caption.copyWith(
                          color: enabled
                              ? AppColors.textTertiary
                              : AppColors.textQuaternary,
                        ),
                      ),
                    ],
                  ),
                ),
                if (enabled)
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: AppColors.textTertiary,
                    size: 18,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NextItem {
  const _NextItem(this.title, this.subtitle, this.icon, {this.onTap});

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback? onTap;
}

class _NoBranchSelected extends StatelessWidget {
  const _NoBranchSelected({required this.role});

  final UserRole role;

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            role.isAdmin ? Icons.account_tree_outlined : Icons.store_outlined,
            color: AppColors.textSecondary,
          ),
          const SizedBox(height: AppSpacing.md),
          Text('Choose a branch to load the ledger', style: AppTypography.h3),
          const SizedBox(height: AppSpacing.xs),
          Text(
            role.isAdmin
                ? 'Admins are global and may not have a branch on their profile. Pick an explicit branch above.'
                : 'This manager account has no branch scope available.',
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _LoadingDashboard extends StatelessWidget {
  const _LoadingDashboard();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _SkeletonPanel(height: 164),
        const SizedBox(height: AppSpacing.xl),
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth >= 960 ? 3 : 1;
            return GridView.count(
              crossAxisCount: columns,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: AppSpacing.md,
              mainAxisSpacing: AppSpacing.md,
              childAspectRatio: columns == 1 ? 2.6 : 1.7,
              children: const [
                _SkeletonPanel(),
                _SkeletonPanel(),
                _SkeletonPanel(),
              ],
            );
          },
        ),
        const SizedBox(height: AppSpacing.xl),
        const _SkeletonPanel(height: 220),
      ],
    );
  }
}

class _SkeletonPanel extends StatelessWidget {
  const _SkeletonPanel({this.height = 132});

  final double height;

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      elevated: false,
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: SizedBox(
        height: height,
        child: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Skeleton(width: 140, height: 16, borderRadius: AppRadius.smAll),
            SizedBox(height: AppSpacing.lg),
            Skeleton(width: double.infinity, height: 28),
            SizedBox(height: AppSpacing.sm),
            Skeleton(width: 220, height: 12),
          ],
        ),
      ),
    );
  }
}

class _ErrorPanel extends StatelessWidget {
  const _ErrorPanel({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      highlight: true,
      accent: AppColors.error,
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline_rounded, color: AppColors.error),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Attendance report unavailable', style: AppTypography.h3),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  message,
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
