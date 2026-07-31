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
import 'package:drop/core/widgets/glass_container.dart';
import 'package:drop/core/widgets/skeleton.dart';
import 'package:drop/features/attendance/domain/reporting/attendance_period.dart';
import 'package:drop/features/attendance/presentation/reporting/attendance_report_cubit.dart';
import 'package:drop/features/attendance/presentation/reporting/attendance_report_state.dart';
import 'package:drop/features/attendance/presentation/reporting/widgets/attendance_report_coverage.dart';
import 'package:drop/features/attendance/presentation/reporting/widgets/attendance_report_headline.dart';
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
      subtitle: 'Attendance reports',
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
                    // The chrome header (AdaptiveScaffold title + subtitle)
                    // already names this page. PageHero repeated that title and
                    // eyebrow verbatim, costing ~120px of the first screen and
                    // putting the word "ledger" on screen four times before any
                    // number. Only the question the page exists to answer
                    // survives, as the single lead-in.
                    //
                    // It also never carried a primaryAction: PageHero leaves the
                    // action slot too little width beside a title/subtitle, and a
                    // disabled button once overflowed PremiumButton's Row by
                    // 175px here. Nothing below reintroduces an action in a Row
                    // that cannot give it room.
                    Text(
                      'Which periods need attention before payroll, and can you '
                      'trust these numbers yet?',
                      style: AppTypography.body.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
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

/// The hub's reading order, derived from the one question the page answers:
/// *which periods need attention before payroll, and can you trust these
/// numbers yet?*
///
/// 1. **The verdict** — [AttendanceReportCoverage] (trust + blockers).
/// 2. **The numbers** — [AttendanceReportHeadline] (one headline + detail).
/// 3. **Go deeper** — [_GoDeeper] (Weekly · Monthly).
///
/// Rhythm carries the grouping. The verdict and the numbers are separated by a
/// tight [AppSpacing.md] because they are one answer read top to bottom; the
/// jump to navigation is a wide [AppSpacing.xxl]. The old page put an identical
/// [AppSpacing.xl] between five identical containers, so nothing read as
/// belonging to anything.
class _ReportBody extends StatelessWidget {
  const _ReportBody({
    required this.state,
    required this.branchId,
    required this.window,
  });

  final AttendanceReportState state;
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

    final verdict = AttendanceReportCoverage(
      coverage: state.coverage,
      totalRows: state.rows.length,
    );
    final deeper = _GoDeeper(branchId: branchId, window: window);

    // No rows is a data-completeness gap, not a result: the numbers section is
    // withheld entirely rather than rendered at zero.
    if (state.coverage.awaitingClose) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          verdict,
          const SizedBox(height: AppSpacing.xxl),
          deeper,
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        verdict,
        const SizedBox(height: AppSpacing.md),
        AttendanceReportHeadline(summary: state.summary),
        const SizedBox(height: AppSpacing.xxl),
        deeper,
      ],
    );
  }

  static String _actionableError(String? message) {
    final raw = message ?? 'Failed to load attendance report.';
    final lower = raw.toLowerCase();
    if (lower.contains('failed-precondition') ||
        lower.contains('requires an index') ||
        lower.contains('composite index')) {
      return 'Attendance reports are not switched on yet — an administrator '
          'needs to finish setting them up. Details: $raw';
    }
    return raw;
  }
}

// `_BranchPeriodPreview` (a "Branch periods" table) lived here and was removed.
// It came from the ATTENDANCE_REPORTS_IA §13.5 hub wireframe, which was drawn
// for a multi-branch estate view — the one that compares Cairo A / Cairo B /
// Giza. That view does not exist: managers are pinned to their own branch and a
// branchless admin must choose exactly one, so the table always rendered a
// single row and repeated the status, blocker count, show-up rate and expected
// count already stated above it.
//
// Bring a branch-comparison table back **only** if an explicit "All branches"
// scope is added to `AttendanceReportScopeBar`. Until there is more than one row
// to compare, a table is a duplicate, not a comparison.

/// **Go deeper.** The two report destinations that actually exist, as two
/// primary actions — not five tiles of which three were inert placeholders.
///
/// The unbuilt surfaces cost one muted line. A placeholder tile spends real
/// estate on something a manager cannot do, at the same visual weight as
/// something they can.
class _GoDeeper extends StatelessWidget {
  const _GoDeeper({required this.branchId, required this.window});

  final String branchId;
  final AttendancePeriodWindow window;

  @override
  Widget build(BuildContext context) {
    final weeklyPeriodId = attendancePeriodId(
      type: AttendancePeriodType.weekly,
      scopeKey: branchId,
      window: window,
    );
    // [window] is whatever period the hub has selected, so it may be a *weekly*
    // window. The monthly report parses its own id and rejects anything that is
    // not a whole calendar month, so the month is derived explicitly from the
    // selected period's start date rather than reused.
    final monthlyPeriodId = attendancePeriodId(
      type: AttendancePeriodType.monthly,
      scopeKey: branchId,
      window: monthlyWindow(window.startDate.year, window.startDate.month),
    );

    final weekly = _DeepLinkTile(
      icon: Icons.calendar_view_week,
      title: 'Weekly report',
      subtitle: 'Seven-day close detail',
      onTap: () => context.push(RouteNames.attendanceWeekly(weeklyPeriodId)),
    );
    final monthly = _DeepLinkTile(
      icon: Icons.calendar_month,
      title: 'Monthly report',
      subtitle: 'Calendar month, week by week',
      onTap: () => context.push(RouteNames.attendanceMonthly(monthlyPeriodId)),
    );

    // Admin-only. The workspace answers "is the record complete and
    // defensible?" — an auditor's question, asked deliberately. Putting it on a
    // manager's surface is exactly what this redesign was correcting.
    final isAdmin = (context.currentUser?.role ?? UserRole.employee).isAdmin;
    final workspace = _DeepLinkTile(
      icon: Icons.fact_check_outlined,
      title: 'Admin workspace',
      subtitle: 'Data completeness across branches',
      onTap: () => context.push(RouteNames.adminAttendanceWorkspace),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            // Natural height throughout: no childAspectRatio, no
            // mainAxisExtent. The previous grid pinned 104px after 92px clipped
            // a sublabel — a magic number is a guess that breaks at some width
            // or text scale.
            if (constraints.maxWidth < 560) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  weekly,
                  const SizedBox(height: AppSpacing.md),
                  monthly,
                  if (isAdmin) ...[
                    const SizedBox(height: AppSpacing.md),
                    workspace,
                  ],
                ],
              );
            }
            return IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(child: weekly),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(child: monthly),
                  if (isAdmin) ...[
                    const SizedBox(width: AppSpacing.md),
                    Expanded(child: workspace),
                  ],
                ],
              ),
            );
          },
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          'Per-employee, period close, and export are coming next.',
          style: AppTypography.caption,
        ),
      ],
    );
  }
}

class _DeepLinkTile extends StatelessWidget {
  const _DeepLinkTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '$title. $subtitle',
      child: GlassContainer(
        onTap: onTap,
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                borderRadius: AppRadius.mdAll,
                border: Border.all(color: AppColors.darkBorder),
                color: AppColors.primarySurface.withValues(alpha: 0.08),
              ),
              child: Icon(icon, size: 18, color: AppColors.textSecondary),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.labelLarge,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.caption.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            const Icon(
              Icons.chevron_right_rounded,
              color: AppColors.textTertiary,
              size: 18,
            ),
          ],
        ),
      ),
    );
  }
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
          Text('Choose a branch to see its attendance', style: AppTypography.h3),
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

/// Structure-suggesting skeleton: it mirrors the real reading order and rhythm
/// (verdict → numbers, tight; then the deep links, after a wide break) so the
/// page does not visibly reflow when the ledger arrives.
class _LoadingDashboard extends StatelessWidget {
  const _LoadingDashboard();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _SkeletonPanel(height: 92),
        const SizedBox(height: AppSpacing.md),
        const _SkeletonPanel(height: 148),
        const SizedBox(height: AppSpacing.xxl),
        LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth < 560) {
              return const Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _SkeletonTile(),
                  SizedBox(height: AppSpacing.md),
                  _SkeletonTile(),
                ],
              );
            }
            return const Row(
              children: [
                Expanded(child: _SkeletonTile()),
                SizedBox(width: AppSpacing.md),
                Expanded(child: _SkeletonTile()),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _SkeletonTile extends StatelessWidget {
  const _SkeletonTile();

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      elevated: false,
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Row(
        children: const [
          Skeleton(width: 36, height: 36, borderRadius: AppRadius.mdAll),
          SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Skeleton(width: 120, height: 14, borderRadius: AppRadius.smAll),
                SizedBox(height: AppSpacing.xs),
                Skeleton(width: 90, height: 10, borderRadius: AppRadius.smAll),
              ],
            ),
          ),
        ],
      ),
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
