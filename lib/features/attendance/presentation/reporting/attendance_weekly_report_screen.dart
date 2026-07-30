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
import 'package:drop/features/attendance/domain/reporting/attendance_ledger_row.dart';
import 'package:drop/features/attendance/domain/reporting/attendance_period.dart';
import 'package:drop/features/attendance/domain/reporting/attendance_weekly_report.dart';
import 'package:drop/features/attendance/presentation/reporting/attendance_report_cubit.dart';
import 'package:drop/features/attendance/presentation/reporting/attendance_report_state.dart';
import 'package:drop/features/attendance/presentation/reporting/widgets/attendance_report_metrics.dart';
import 'package:drop/features/attendance/presentation/reporting/widgets/attendance_weekly_daily_table.dart';
import 'package:drop/features/attendance/presentation/reporting/widgets/attendance_weekly_employee_rows.dart';
import 'package:drop/features/branch/domain/entities/branch_entity.dart';
import 'package:drop/features/branch/presentation/cubit/branch_cubit.dart';
import 'package:drop/features/branch/presentation/cubit/branch_state.dart';

class AttendanceWeeklyReportScreen extends StatelessWidget {
  const AttendanceWeeklyReportScreen({
    super.key,
    required this.periodId,
    this.cubit,
  });

  final String periodId;
  final AttendanceReportCubit? cubit;

  @override
  Widget build(BuildContext context) {
    final parsed = WeeklyAttendancePeriodRef.tryParse(periodId);
    final view = _AttendanceWeeklyReportView(
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

class _AttendanceWeeklyReportView extends StatefulWidget {
  const _AttendanceWeeklyReportView({
    required this.period,
    required this.rawPeriodId,
  });

  final WeeklyAttendancePeriodRef? period;
  final String rawPeriodId;

  @override
  State<_AttendanceWeeklyReportView> createState() =>
      _AttendanceWeeklyReportViewState();
}

class _AttendanceWeeklyReportViewState
    extends State<_AttendanceWeeklyReportView> {
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
        context.read<AttendanceReportCubit>().watchBranchWindow(
          branchId: period.branchId,
          window: period.window,
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final period = widget.period;
    return AdaptiveScaffold(
      title: 'Weekly attendance',
      subtitle: 'Reporting ledger',
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
        key: const PageStorageKey('attendance-weekly-report'),
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
            _WeeklyReportLoader(period: period),
        ],
      ),
    );
  }
}

class _WeeklyReportLoader extends StatelessWidget {
  const _WeeklyReportLoader({required this.period});

  final WeeklyAttendancePeriodRef period;

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
              return _LoadingWeekly(branchName: branchName, period: period);
            }
            final report = WeeklyAttendanceReport.fromLedger(
              rows: state.rows,
              window: period.window,
            );
            return _WeeklyReportContent(
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

class _WeeklyReportContent extends StatelessWidget {
  const _WeeklyReportContent({
    required this.period,
    required this.branchName,
    required this.report,
  });

  final WeeklyAttendancePeriodRef period;
  final String branchName;
  final WeeklyAttendanceReport report;

  @override
  Widget build(BuildContext context) {
    final awaiting = report.coverage.awaitingClose;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _HeaderSection(branchName: branchName, period: period, report: report),
        const SizedBox(height: AppSpacing.xl),
        _CloseReadiness(report: report),
        const SizedBox(height: AppSpacing.xl),
        if (awaiting)
          const _AwaitingClosePanel()
        else
          AttendanceReportMetrics(
            summary: report.summary,
            weekly: true,
            exceptionCount: report.exceptionCount,
            exceptionDenominator:
                '${report.exceptionCount} / ${report.rows.length} ledger rows',
          ),
        const SizedBox(height: AppSpacing.xl),
        AttendanceWeeklyDailyTable(days: report.days),
        const SizedBox(height: AppSpacing.xl),
        _ExceptionSummary(groups: report.exceptionGroups),
        const SizedBox(height: AppSpacing.xl),
        AttendanceWeeklyEmployeeRows(employees: report.employees),
        const SizedBox(height: AppSpacing.xl),
        _EvidenceTable(rows: report.rows),
        const SizedBox(height: AppSpacing.xl),
        const _ExportRestatementPanel(),
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
  final WeeklyAttendancePeriodRef period;
  final WeeklyAttendanceReport report;

  @override
  Widget build(BuildContext context) {
    final coverage = report.coverage;
    return PageHero(
      eyebrow: 'Attendance & Reports / Weekly',
      title: branchName,
      subtitle:
          '${_weekLabel(period.window)} · ${coverage.statusLabel} · Africa/Cairo · v${period.version}',
      primaryAction: PremiumButton(
        label: 'Close week',
        icon: Icons.lock_outline_rounded,
        onPressed: null,
        style: PremiumButtonStyle.filled,
      ),
      // Only the status pill travels in the hero. A third disabled action here
      // overflowed PageHero's stacked Row by 155px at mobile width, and the
      // Export/restatement panel at the foot of the report already carries the
      // PDF/CSV affordances — so this was redundant as well as too wide.
      trailing: [_StatusPill(label: coverage.statusLabel)],
    );
  }

  static String _weekLabel(AttendancePeriodWindow window) =>
      'Sun ${AppDateFormatter.dayMonth(window.startDate)} - Sat ${AppDateFormatter.dayMonth(window.endDate)}';
}

class _CloseReadiness extends StatelessWidget {
  const _CloseReadiness({required this.report});

  final WeeklyAttendanceReport report;

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

  final WeeklyAttendanceReport report;

  @override
  Widget build(BuildContext context) {
    final coverage = report.coverage;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Close readiness', style: AppTypography.h3),
        const SizedBox(height: AppSpacing.xs),
        Text(
          coverage.awaitingClose
              ? 'Awaiting close: attendance_expectations has no rows for this branch-week.'
              : coverage.isFullyClosed
              ? 'Every business date has ledger rows and no blocking exception rows.'
              : 'Partially closed: ${coverage.closedDayCount} of ${coverage.totalDayCount} business dates have ledger rows.',
          style: AppTypography.bodySmall.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          coverage.awaitingClose
              ? 'Rates are hidden because unknown coverage is not zero attendance.'
              : coverage.isFullyClosed
              ? 'Export and lock still wait for the later close/export slice.'
              : '${coverage.totalDayCount - coverage.closedDayCount} business dates are not closed in the ledger, so this is not a settled weekly result.',
          style: AppTypography.caption.copyWith(color: AppColors.textTertiary),
        ),
        const SizedBox(height: AppSpacing.lg),
        PremiumButton(
          label: 'Open exception queue',
          icon: Icons.fact_check_outlined,
          onPressed: null,
        ),
      ],
    );
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
            'Blockers by type',
            style: AppTypography.label.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.md),
          if (groups.isEmpty)
            Text(
              'No blocking exception rows.',
              style: AppTypography.caption.copyWith(
                color: AppColors.textTertiary,
              ),
            )
          else
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
          const Icon(Icons.hourglass_empty_rounded, color: AppColors.warning),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Awaiting close', style: AppTypography.h3),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'No weekly rates, percentages, or zero-valued metric cards are rendered until ledger rows exist.',
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
          final children = [
            Expanded(
              child: _ExceptionColumn(
                title: 'Blocking',
                empty: 'No blocking exception rows.',
                groups: blocking,
              ),
            ),
            const SizedBox(width: AppSpacing.xl),
            Expanded(
              child: _ExceptionColumn(
                title: 'Informational',
                empty: 'No informational exception rows.',
                groups: informational,
              ),
            ),
          ];
          if (wide) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: children,
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _ExceptionColumn(
                title: 'Blocking',
                empty: 'No blocking exception rows.',
                groups: blocking,
              ),
              const SizedBox(height: AppSpacing.lg),
              _ExceptionColumn(
                title: 'Informational',
                empty: 'No informational exception rows.',
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

class _EvidenceTable extends StatelessWidget {
  const _EvidenceTable({required this.rows});

  final List<AttendanceLedgerRow> rows;

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Shift evidence table', style: AppTypography.h3),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'One row per materialized attendance_expectations ledger fact.',
            style: AppTypography.caption.copyWith(
              color: AppColors.textTertiary,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          if (rows.isEmpty)
            Text(
              'No ledger evidence rows yet.',
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.textSecondary,
              ),
            )
          else
            ClipRRect(
              borderRadius: AppRadius.lgAll,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.darkBorder),
                  borderRadius: AppRadius.lgAll,
                ),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minWidth: 920),
                    child: Column(
                      children: [
                        const _EvidenceRow(
                          cells: [
                            'Date',
                            'Employee',
                            'Shift',
                            'Outcome',
                            'Worked',
                            'Late',
                            'Record',
                          ],
                          header: true,
                        ),
                        for (final row in rows) _EvidenceRow.forLedger(row),
                      ],
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

class _EvidenceRow extends StatelessWidget {
  const _EvidenceRow({required this.cells, this.header = false, this.recordId});

  factory _EvidenceRow.forLedger(AttendanceLedgerRow row) => _EvidenceRow(
    cells: [
      row.businessDate,
      row.userName?.trim().isNotEmpty ?? false
          ? row.userName!.trim()
          : row.userId,
      row.shift.label,
      row.outcome.wireValue,
      '${row.workedMinutes}',
      '${row.lateMinutes}',
      row.recordId == null ? 'No record - phantom row' : 'Open record',
    ],
    recordId: row.recordId,
  );

  final List<String> cells;
  final bool header;
  final String? recordId;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 50),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: header
            ? AppColors.darkSurfaceElevated
            : AppColors.darkSurface.withValues(alpha: 0.72),
        border: const Border(bottom: BorderSide(color: AppColors.darkBorder)),
      ),
      child: Row(
        children: [
          for (var i = 0; i < cells.length; i++)
            SizedBox(
              width: i == 1
                  ? 190
                  : i == 6
                  ? 180
                  : 108,
              child: i == 6 && recordId != null && !header
                  ? Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton(
                        onPressed: () => context.push(
                          RouteNames.attendanceRecord(recordId!),
                        ),
                        child: const Text('Open record'),
                      ),
                    )
                  : Text(
                      cells[i],
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style:
                          (header ? AppTypography.caption : AppTypography.label)
                              .copyWith(
                                color: header
                                    ? AppColors.textTertiary
                                    : i == 6 && cells[i].startsWith('No record')
                                    ? AppColors.warning
                                    : AppColors.textSecondary,
                                fontWeight: header
                                    ? FontWeight.w600
                                    : FontWeight.w500,
                              ),
                    ),
            ),
        ],
      ),
    );
  }
}

class _ExportRestatementPanel extends StatelessWidget {
  const _ExportRestatementPanel();

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
                Text('Export and restatement', style: AppTypography.h3),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'PDF, CSV, close week, lock week, and restatement history are coming next.',
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
                      label: 'CSV',
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
  const _StatusPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final isPartial = label == 'Partially closed';
    final isAwaiting = label == 'Awaiting close';
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        borderRadius: AppRadius.fullAll,
        border: Border.all(
          color: isPartial || isAwaiting
              ? AppColors.warning.withValues(alpha: 0.46)
              : AppColors.darkBorder,
        ),
        color: AppColors.darkSurfaceElevated,
      ),
      child: Text(
        label,
        style: AppTypography.caption.copyWith(
          color: isPartial || isAwaiting
              ? AppColors.warning
              : AppColors.textSecondary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _LoadingWeekly extends StatelessWidget {
  const _LoadingWeekly({required this.branchName, required this.period});

  final String branchName;
  final WeeklyAttendancePeriodRef period;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PageHero(
          eyebrow: 'Attendance & Reports / Weekly',
          title: branchName,
          subtitle: '${_HeaderSection._weekLabel(period.window)} · Loading',
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
    return _ProblemPanel(
      title: 'Invalid weekly report link',
      message:
          'The period id "$rawPeriodId" is not parseable. Expected branch_weekly_YYYYMMDD_YYYYMMDD_vN.',
      icon: Icons.link_off_rounded,
    );
  }
}

class _ScopeDeniedPanel extends StatelessWidget {
  const _ScopeDeniedPanel();

  @override
  Widget build(BuildContext context) {
    return const _ProblemPanel(
      title: 'Weekly report unavailable',
      message:
          'This manager account cannot open a weekly report for another branch.',
      icon: Icons.lock_outline_rounded,
    );
  }
}

class _ErrorPanel extends StatelessWidget {
  const _ErrorPanel({required this.message});

  final String? message;

  @override
  Widget build(BuildContext context) {
    final raw = message ?? 'Failed to load weekly attendance report.';
    final lower = raw.toLowerCase();
    final actionable =
        lower.contains('failed-precondition') ||
            lower.contains('requires an index') ||
            lower.contains('composite index')
        ? 'Attendance weekly report requires the deployed attendance_expectations branchId/dayKey composite index. Deploy firestore.indexes.json, then reload. $raw'
        : raw;
    return _ProblemPanel(
      title: 'Weekly attendance unavailable',
      message: actionable,
      icon: Icons.error_outline_rounded,
      tone: AppColors.error,
    );
  }
}

class _ProblemPanel extends StatelessWidget {
  const _ProblemPanel({
    required this.title,
    required this.message,
    required this.icon,
    this.tone = AppColors.warning,
  });

  final String title;
  final String message;
  final IconData icon;
  final Color tone;

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      highlight: true,
      accent: tone,
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: tone),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTypography.h3),
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

class WeeklyAttendancePeriodRef {
  const WeeklyAttendancePeriodRef({
    required this.branchId,
    required this.window,
    required this.version,
  });

  final String branchId;
  final AttendancePeriodWindow window;
  final int version;

  static WeeklyAttendancePeriodRef? tryParse(String periodId) {
    final parts = periodId.split('_');
    if (parts.length < 5) return null;
    final typeIndex = parts.length - 4;
    if (parts[typeIndex] != AttendancePeriodType.weekly.name) return null;
    final branchId = parts.sublist(0, typeIndex).join('_').trim();
    if (branchId.isEmpty) return null;
    final start = _parseDayKey(parts[typeIndex + 1]);
    final end = _parseDayKey(parts[typeIndex + 2]);
    final versionPart = parts[typeIndex + 3];
    if (start == null ||
        end == null ||
        !versionPart.startsWith('v') ||
        end.difference(start).inDays != 6) {
      return null;
    }
    final version = int.tryParse(versionPart.substring(1));
    if (version == null || version < 1) return null;
    final window = AttendancePeriodWindow(startDate: start, endDate: end);
    final canonicalStart = weeklyWindow(start).startDate;
    if (window.startDate != canonicalStart) return null;
    return WeeklyAttendancePeriodRef(
      branchId: branchId,
      window: window,
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
