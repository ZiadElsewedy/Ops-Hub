import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:drop/core/di/injection.dart';
import 'package:drop/core/enums/user_role.dart';
import 'package:drop/core/extensions/context_extensions.dart';
import 'package:drop/core/responsive/breakpoints.dart';
import 'package:drop/core/routes/route_names.dart';
import 'package:drop/core/theme/app_colors.dart';
import 'package:drop/core/theme/app_radius.dart';
import 'package:drop/core/theme/app_spacing.dart';
import 'package:drop/core/theme/app_typography.dart';
import 'package:drop/core/utils/app_date_formatter.dart';
import 'package:drop/core/widgets/adaptive_scaffold.dart';
import 'package:drop/core/widgets/glass_container.dart';
import 'package:drop/core/widgets/page_hero.dart';
import 'package:drop/core/widgets/premium_button.dart';
import 'package:drop/core/widgets/skeleton.dart';
import 'package:drop/core/widgets/app_error_state.dart';
import 'package:drop/features/attendance/domain/attendance_review_link.dart';
import 'package:drop/features/attendance/domain/reporting/attendance_monthly_report.dart';
import 'package:drop/features/attendance/domain/reporting/attendance_period.dart';
import 'package:drop/features/attendance/domain/reporting/attendance_coverage_status.dart';
import 'package:drop/features/attendance/domain/reporting/attendance_weekly_report.dart';
import 'package:drop/features/attendance/presentation/reporting/attendance_report_cubit.dart';
import 'package:drop/features/attendance/presentation/reporting/attendance_report_state.dart';
import 'package:drop/features/attendance/presentation/reporting/widgets/attendance_monthly_week_buckets.dart';
import 'package:drop/features/attendance/presentation/reporting/widgets/attendance_report_metrics.dart';
import 'package:drop/features/attendance/presentation/reporting/widgets/attendance_weekly_employee_rows.dart';
import 'package:drop/features/branch/domain/entities/branch_entity.dart';
import 'package:drop/features/branch/presentation/cubit/branch_cubit.dart';
import 'package:drop/features/branch/presentation/cubit/branch_state.dart';

/// The Monthly report destination (`/attendance/reports/monthly/:periodId`).
///
/// Reads the `attendance_expectations` ledger only, for the calendar month named
/// by the period id. Month-over-month comparison, the restatement version log,
/// per-employee drill-down, and a working export are deliberately **not** here —
/// they are later slices, shown as disabled affordances.
class AttendanceMonthlyReportScreen extends StatelessWidget {
  const AttendanceMonthlyReportScreen({
    super.key,
    required this.periodId,
    this.cubit,
  });

  final String periodId;
  final AttendanceReportCubit? cubit;

  @override
  Widget build(BuildContext context) {
    final parsed = MonthlyAttendancePeriodRef.tryParse(periodId);
    final view = _AttendanceMonthlyReportView(
      period: parsed,
      rawPeriodId: periodId,
    );
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

class _AttendanceMonthlyReportView extends StatefulWidget {
  const _AttendanceMonthlyReportView({
    required this.period,
    required this.rawPeriodId,
  });

  final MonthlyAttendancePeriodRef? period;
  final String rawPeriodId;

  @override
  State<_AttendanceMonthlyReportView> createState() =>
      _AttendanceMonthlyReportViewState();
}

class _AttendanceMonthlyReportViewState
    extends State<_AttendanceMonthlyReportView> {
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    context.read<BranchCubit>().loadIfNeeded();
    final period = widget.period;
    if (period != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final me = context.currentUser;
        context.read<AttendanceReportCubit>().watchBranchWindow(
          branchId: period.branchId,
          window: period.window,
          viewerUid: me?.uid,
          employeesOnly: me?.role.isManager ?? false,
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final period = widget.period;
    return AdaptiveScaffold(
      title: 'Monthly attendance',
      subtitle: 'Who worked this month',
      compactDesktopHeader: true,
      actions: [
        IconButton(
          tooltip: 'Refresh report',
          onPressed: period == null
              ? null
              : () => context.read<AttendanceReportCubit>().refresh(),
          icon: const Icon(Icons.refresh_rounded),
        ),
      ],
      body: ListView(
        key: const PageStorageKey('attendance-monthly-report'),
        padding: EdgeInsets.fromLTRB(
          AppSpacing.pagePadding,
          AppSpacing.lg,
          AppSpacing.pagePadding,
          context.isDesktop ? AppSpacing.xxxl : AppSpacing.xxxl * 2,
        ),
        children: [
          if (period == null)
            _InvalidPeriodPanel(rawPeriodId: widget.rawPeriodId)
          else
            _MonthlyReportLoader(period: period),
        ],
      ),
    );
  }
}

class _MonthlyReportLoader extends StatelessWidget {
  const _MonthlyReportLoader({required this.period});

  final MonthlyAttendancePeriodRef period;

  @override
  Widget build(BuildContext context) {
    final user = context.currentUser;
    if ((user?.role ?? UserRole.employee).isManager &&
        user?.branchId != period.branchId) {
      return const _ScopeDeniedPanel();
    }

    return BlocBuilder<BranchCubit, BranchState>(
      builder: (context, branchState) {
        final branches = branchState.maybeWhen(
          loaded: (items, _) => items,
          orElse: () => const <BranchEntity>[],
        );
        final branchName = _branchName(branches, period.branchId);
        return BlocBuilder<AttendanceReportCubit, AttendanceReportState>(
          builder: (context, state) {
            if (state.status == AttendanceReportStatus.error) {
              return _ErrorPanel(message: state.message);
            }
            if (state.status == AttendanceReportStatus.initial ||
                (state.status == AttendanceReportStatus.loading &&
                    !state.coverage.hasRows)) {
              return _LoadingMonthly(branchName: branchName, period: period);
            }
            final report = MonthlyAttendanceReport.fromLedger(
              rows: state.rows,
              window: period.window,
              namesByUid: state.namesByUid,
            );
            return _MonthlyReportContent(
              period: period,
              branchName: branchName,
              report: report,
            );
          },
        );
      },
    );
  }

  static String _branchName(List<BranchEntity> branches, String branchId) {
    for (final branch in branches) {
      if (branch.id == branchId) return branch.name;
    }
    return branchId;
  }
}

class _MonthlyReportContent extends StatelessWidget {
  const _MonthlyReportContent({
    required this.period,
    required this.branchName,
    required this.report,
  });

  final MonthlyAttendancePeriodRef period;
  final String branchName;
  final MonthlyAttendanceReport report;

  @override
  Widget build(BuildContext context) {
    final awaiting = report.coverage.awaitingClose;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _HeaderSection(branchName: branchName, period: period, report: report),
        const SizedBox(height: AppSpacing.xl),
        _PayrollReadiness(report: report),
        const SizedBox(height: AppSpacing.xl),
        if (awaiting)
          const _AwaitingClosePanel()
        else
          AttendanceReportMetrics(
            summary: report.summary,
            // `weekly: true` selects the per-report metric set (rates first),
            // not a week window. The hub uses the dashboard set.
            weekly: true,
            exceptionCount: report.exceptionCount,
            exceptionDenominator:
                '${report.exceptionCount} of ${report.rows.length} shifts',
          ),
        const SizedBox(height: AppSpacing.xl),
        AttendanceMonthlyWeekBuckets(buckets: report.weekBuckets),
        const SizedBox(height: AppSpacing.xl),
        AttendanceWeeklyEmployeeRows(
          employees: report.employees,
          emptyMessage:
              'Nobody has a recorded shift this month yet.',
          onOpenEmployee: (employee) => context.push(
            RouteNames.attendanceReview,
            extra: AttendanceReviewLink(
              employeeName: employee.displayName,
              branchId: period.branchId,
              start: period.window.startDate,
              end: period.window.endDate,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        if (report.exceptionGroups.isNotEmpty) ...[
          _ExceptionSummary(groups: report.exceptionGroups),
          const SizedBox(height: AppSpacing.xl),
        ],
        const _SharePanel(),
      ],
    );
  }
}

class _HeaderSection extends StatelessWidget {
  const _HeaderSection({
    required this.branchName,
    required this.period,
    required this.report,
  });

  final String branchName;
  final MonthlyAttendancePeriodRef period;
  final MonthlyAttendanceReport report;

  @override
  Widget build(BuildContext context) {
    final coverage = report.coverage;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PageHero(
          eyebrow: 'Attendance & Reports / Monthly',
          title: branchName,
          subtitle: '${monthLabel(period.window)} · ${coverage.statusLabel}',
          // "Close month" removed for the same reason as the weekly twin: it was
          // permanently disabled and it promised locking, which ADR-019 refuses.
          // A month is a rollup of reviewed weeks; there is nothing here to close.
          trailing: [_StatusPill(status: coverage.status)],
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          'Every figure below comes from recorded shifts for this month.',
          style: AppTypography.caption.copyWith(color: AppColors.textTertiary),
        ),
      ],
    );
  }

  static String monthLabel(AttendancePeriodWindow window) =>
      '${AppDateFormatter.monthYear(window.startDate)} · '
      '${AppDateFormatter.dayMonth(window.startDate)} - ${AppDateFormatter.dayMonth(window.endDate)}';
}

class _PayrollReadiness extends StatelessWidget {
  const _PayrollReadiness({required this.report});

  final MonthlyAttendanceReport report;

  @override
  Widget build(BuildContext context) {
    final blockingGroups = report.exceptionGroups
        .where((group) => group.blocksClose)
        .toList();
    final blockerCount =
        report.coverage.ledgerCoverage.blockingExceptionRowCount;
    return GlassContainer(
      highlight: blockerCount > 0,
      accent: blockerCount > 0 ? AppColors.warning : AppColors.textPrimary,
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 820;
          final status = _ReadinessCopy(report: report);
          final blockers = _BlockerCounts(groups: blockingGroups);
          if (!wide) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                status,
                const SizedBox(height: AppSpacing.lg),
                blockers,
              ],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 3, child: status),
              const SizedBox(width: AppSpacing.xl),
              Expanded(flex: 2, child: blockers),
            ],
          );
        },
      ),
    );
  }
}

class _ReadinessCopy extends StatelessWidget {
  const _ReadinessCopy({required this.report});

  final MonthlyAttendanceReport report;

  @override
  Widget build(BuildContext context) {
    final coverage = report.coverage;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Month status', style: AppTypography.h3),
        const SizedBox(height: AppSpacing.xs),
        Text(
          coverage.awaitingClose
              ? 'Nothing has been recorded for this month yet.'
              : coverage.ledgerCoverage.blockingExceptionRowCount == 0
              ? 'Nothing needs a decision this month.'
              : '${coverage.ledgerCoverage.blockingExceptionRowCount} shifts need a decision before this month is settled.',
          style: AppTypography.bodySmall.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          coverage.awaitingClose
              ? 'Percentages stay hidden until there is something to measure — this is missing data, not a zero attendance result.'
              : _missingDatesNote(coverage),
          style: AppTypography.caption.copyWith(color: AppColors.textTertiary),
        ),
        if (coverage.ledgerCoverage.blockingExceptionRowCount > 0) ...[
          const SizedBox(height: AppSpacing.lg),
          PremiumButton(
            label: 'Review these',
            icon: Icons.fact_check_outlined,
            onPressed: null,
          ),
        ],
      ],
    );
  }

  static String _missingDatesNote(MonthlyAttendanceCoverage coverage) {
    final missing = coverage.notClosedDayKeys;
    if (missing.isEmpty) {
      return 'Every day this month has shifts recorded.';
    }
    const shown = 6;
    final head = missing.take(shown).map(_readableDayKey).join(', ');
    final rest = missing.length - shown;
    final tail = rest > 0 ? ' and $rest more' : '';
    return 'No shifts recorded on ${missing.length} of ${coverage.totalDayCount} days: $head$tail. That usually means nobody was scheduled.';
  }

  static String _readableDayKey(String dayKey) {
    if (dayKey.length != 8) return dayKey;
    final year = int.tryParse(dayKey.substring(0, 4));
    final month = int.tryParse(dayKey.substring(4, 6));
    final day = int.tryParse(dayKey.substring(6, 8));
    if (year == null || month == null || day == null) return dayKey;
    return AppDateFormatter.dayMonth(DateTime(year, month, day));
  }
}

class _BlockerCounts extends StatelessWidget {
  const _BlockerCounts({required this.groups});

  final List<WeeklyAttendanceExceptionGroup> groups;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        borderRadius: AppRadius.lgAll,
        border: Border.all(color: AppColors.darkBorder),
        color: AppColors.darkSurface.withValues(alpha: 0.72),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'What needs a decision',
            style: AppTypography.label.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.md),
          for (final group in groups)
            _MiniFact(label: group.label, value: '${group.count}'),
        ],
      ),
    );
  }
}

class _AwaitingClosePanel extends StatelessWidget {
  const _AwaitingClosePanel();

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.hourglass_empty_rounded,
            color: AppColors.textTertiary,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('No data yet', style: AppTypography.h3),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Once shifts are recorded for this month, the numbers appear here.',
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

class _ExceptionSummary extends StatelessWidget {
  const _ExceptionSummary({required this.groups});

  final List<WeeklyAttendanceExceptionGroup> groups;

  @override
  Widget build(BuildContext context) {
    final blocking = groups.where((group) => group.blocksClose).toList();
    final informational = groups.where((group) => !group.blocksClose).toList();
    return GlassContainer(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 760;
          if (wide) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _ExceptionColumn(
                    title: 'Needs a decision',
                    empty: 'Nothing needs a decision.',
                    groups: blocking,
                  ),
                ),
                const SizedBox(width: AppSpacing.xl),
                Expanded(
                  child: _ExceptionColumn(
                    title: 'Worth knowing',
                    empty: 'Nothing to note.',
                    groups: informational,
                  ),
                ),
              ],
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _ExceptionColumn(
                title: 'Needs a decision',
                empty: 'Nothing needs a decision.',
                groups: blocking,
              ),
              const SizedBox(height: AppSpacing.lg),
              _ExceptionColumn(
                title: 'Worth knowing',
                empty: 'Nothing to note.',
                groups: informational,
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ExceptionColumn extends StatelessWidget {
  const _ExceptionColumn({
    required this.title,
    required this.empty,
    required this.groups,
  });

  final String title;
  final String empty;
  final List<WeeklyAttendanceExceptionGroup> groups;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: AppTypography.h3),
        const SizedBox(height: AppSpacing.md),
        if (groups.isEmpty)
          Text(
            empty,
            style: AppTypography.caption.copyWith(
              color: AppColors.textTertiary,
            ),
          )
        else
          for (final group in groups)
            _MiniFact(label: group.label, value: '${group.count}'),
      ],
    );
  }
}

class _SharePanel extends StatelessWidget {
  const _SharePanel();

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.file_download_off_outlined,
            color: AppColors.textTertiary,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Share this month', style: AppTypography.h3),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'A printable summary and a timesheet spreadsheet are coming next.',
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: const [
                    PremiumButton(
                      label: 'PDF',
                      icon: Icons.picture_as_pdf_outlined,
                      onPressed: null,
                    ),
                    PremiumButton(
                      label: 'Spreadsheet',
                      icon: Icons.table_view_outlined,
                      onPressed: null,
                    ),
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

class _MiniFact extends StatelessWidget {
  const _MiniFact({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Text(
            value,
            style: AppTypography.label.copyWith(color: AppColors.textPrimary),
          ),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status});

  final AttendanceCoverageStatus status;

  @override
  Widget build(BuildContext context) {
    // Only a status with work behind it is toned — see the weekly report.
    final toned = status.isActionable;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        borderRadius: AppRadius.fullAll,
        border: Border.all(
          color: toned
              ? AppColors.warning.withValues(alpha: 0.46)
              : AppColors.darkBorder,
        ),
        color: AppColors.darkSurfaceElevated,
      ),
      child: Text(
        status.label,
        style: AppTypography.caption.copyWith(
          color: toned ? AppColors.warning : AppColors.textSecondary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _LoadingMonthly extends StatelessWidget {
  const _LoadingMonthly({required this.branchName, required this.period});

  final String branchName;
  final MonthlyAttendancePeriodRef period;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PageHero(
          eyebrow: 'Attendance & Reports / Monthly',
          title: branchName,
          subtitle: '${_HeaderSection.monthLabel(period.window)} · Loading',
        ),
        const SizedBox(height: AppSpacing.xl),
        const _SkeletonPanel(height: 168),
        const SizedBox(height: AppSpacing.xl),
        const _SkeletonPanel(height: 240),
        const SizedBox(height: AppSpacing.xl),
        const _SkeletonPanel(height: 280),
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
            Skeleton(width: 160, height: 16, borderRadius: AppRadius.smAll),
            SizedBox(height: AppSpacing.lg),
            Skeleton(width: double.infinity, height: 28),
            SizedBox(height: AppSpacing.sm),
            Skeleton(width: 240, height: 12),
          ],
        ),
      ),
    );
  }
}

class _InvalidPeriodPanel extends StatelessWidget {
  const _InvalidPeriodPanel({required this.rawPeriodId});

  final String rawPeriodId;

  @override
  Widget build(BuildContext context) {
    return AppProblemPanel(
      title: 'Invalid monthly report link',
      message:
          'The period id "$rawPeriodId" is not parseable. Expected branch_monthly_YYYYMMDD_YYYYMMDD_vN covering one whole calendar month.',
      icon: Icons.link_off_rounded,
    );
  }
}

class _ScopeDeniedPanel extends StatelessWidget {
  const _ScopeDeniedPanel();

  @override
  Widget build(BuildContext context) {
    return const AppProblemPanel(
      title: 'Monthly report unavailable',
      message:
          'This manager account cannot open a monthly report for another branch.',
      icon: Icons.lock_outline_rounded,
    );
  }
}

class _ErrorPanel extends StatelessWidget {
  const _ErrorPanel({required this.message});

  final String? message;

  @override
  Widget build(BuildContext context) {
    final raw = message ?? 'Failed to load monthly attendance report.';
    final lower = raw.toLowerCase();
    final actionable =
        lower.contains('failed-precondition') ||
            lower.contains('requires an index') ||
            lower.contains('composite index')
        ? 'Attendance reports are not switched on yet — an administrator needs '
              'to finish setting them up. Details: $raw'
        : raw;
    return AppProblemPanel(
      title: 'Monthly attendance unavailable',
      message: actionable,
      icon: Icons.error_outline_rounded,
      tone: AppColors.error,
    );
  }
}


/// The parsed `{branchId}_monthly_{startKey}_{endKey}_v{version}` route
/// parameter.
///
/// Unlike the weekly reference, the window must be exactly one calendar month:
/// the start is the first day of a month and the end is the last day of that
/// same month. A weekly window handed to this route is therefore rejected, so a
/// mis-built link shows the invalid-period panel instead of silently reporting a
/// seven-day "month".
class MonthlyAttendancePeriodRef {
  const MonthlyAttendancePeriodRef({
    required this.branchId,
    required this.window,
    required this.version,
  });

  final String branchId;
  final AttendancePeriodWindow window;
  final int version;

  static MonthlyAttendancePeriodRef? tryParse(String periodId) {
    final parts = periodId.split('_');
    if (parts.length < 5) return null;
    final typeIndex = parts.length - 4;
    if (parts[typeIndex] != AttendancePeriodType.monthly.name) return null;
    // A branch id may itself contain '_', so everything before the type segment
    // is the scope key.
    final branchId = parts.sublist(0, typeIndex).join('_').trim();
    if (branchId.isEmpty) return null;
    final start = _parseDayKey(parts[typeIndex + 1]);
    final end = _parseDayKey(parts[typeIndex + 2]);
    final versionPart = parts[typeIndex + 3];
    if (start == null || end == null || !versionPart.startsWith('v')) {
      return null;
    }
    if (start.day != 1) return null;
    if (end.year != start.year || end.month != start.month) return null;
    final lastDay = DateTime(start.year, start.month + 1, 0).day;
    if (end.day != lastDay) return null;
    final version = int.tryParse(versionPart.substring(1));
    if (version == null || version < 1) return null;
    return MonthlyAttendancePeriodRef(
      branchId: branchId,
      window: AttendancePeriodWindow(startDate: start, endDate: end),
      version: version,
    );
  }

  static DateTime? _parseDayKey(String key) {
    if (key.length != 8) return null;
    final year = int.tryParse(key.substring(0, 4));
    final month = int.tryParse(key.substring(4, 6));
    final day = int.tryParse(key.substring(6, 8));
    if (year == null || month == null || day == null) return null;
    final date = DateTime(year, month, day);
    if (date.year != year || date.month != month || date.day != day) {
      return null;
    }
    return date;
  }
}
