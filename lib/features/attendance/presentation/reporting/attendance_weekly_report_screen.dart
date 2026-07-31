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
import 'package:drop/features/attendance/domain/reporting/attendance_coverage_status.dart';
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
      subtitle: 'Who worked this week',
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
              namesByUid: state.namesByUid,
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
    // PP8: a section with nothing in it renders nothing. With Daily Review not
    // built yet these two can both be empty on a healthy week, and an empty
    // "Blocking / Informational" pair was pure furniture.
    final hasExceptions = report.exceptionGroups.isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _HeaderSection(branchName: branchName, period: period, report: report),
        const SizedBox(height: AppSpacing.xl),
        _WeekStatusCard(report: report),
        const SizedBox(height: AppSpacing.xl),
        if (awaiting)
          const _NoDataYetPanel()
        else
          AttendanceReportMetrics(
            summary: report.summary,
            weekly: true,
            exceptionCount: report.exceptionCount,
            exceptionDenominator:
                '${report.exceptionCount} of ${report.rows.length} shifts',
          ),
        const SizedBox(height: AppSpacing.xl),
        AttendanceWeeklyDailyTable(days: report.days),
        const SizedBox(height: AppSpacing.xl),
        if (hasExceptions) ...[
          _ExceptionSummary(groups: report.exceptionGroups),
          const SizedBox(height: AppSpacing.xl),
        ],
        AttendanceWeeklyEmployeeRows(employees: report.employees),
        const SizedBox(height: AppSpacing.xl),
        _ShiftDetailTable(rows: report.rows),
        const SizedBox(height: AppSpacing.xl),
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
  final WeeklyAttendancePeriodRef period;
  final WeeklyAttendanceReport report;

  @override
  Widget build(BuildContext context) {
    final coverage = report.coverage;
    return PageHero(
      eyebrow: 'Attendance & Reports / Weekly',
      title: branchName,
      // Timezone and report version were provenance, not information: a store
      // manager has one timezone and no decision to make about `v1`. Both move
      // to the admin audit surface in Phase 3.
      subtitle: '${_weekLabel(period.window)} · ${coverage.statusLabel}',
      primaryAction: PremiumButton(
        label: 'Close week',
        icon: Icons.lock_outline_rounded,
        onPressed: null,
        style: PremiumButtonStyle.filled,
      ),
      // Only the status pill travels in the hero. A third disabled action here
      // overflowed PageHero's stacked Row by 155px at mobile width, and the
      // share panel at the foot of the report already carries the PDF/CSV
      // affordances — so this was redundant as well as too wide.
      trailing: [_StatusPill(status: coverage.status)],
    );
  }

  static String _weekLabel(AttendancePeriodWindow window) =>
      'Sun ${AppDateFormatter.dayMonth(window.startDate)} - Sat ${AppDateFormatter.dayMonth(window.endDate)}';
}

class _WeekStatusCard extends StatelessWidget {
  const _WeekStatusCard({required this.report});

  final WeeklyAttendanceReport report;

  @override
  Widget build(BuildContext context) {
    final blockingGroups = report.exceptionGroups
        .where((group) => group.blocksClose)
        .toList();
    final actionable = report.coverage.status.isActionable;
    return GlassContainer(
      highlight: actionable,
      accent: actionable ? AppColors.warning : AppColors.textPrimary,
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 820;
          final status = _WeekStatusCopy(report: report);
          // PP8 again: the "what needs attention" panel is the answer to a
          // question nobody asked when the answer is "nothing".
          if (blockingGroups.isEmpty) return status;
          final attention = _AttentionCounts(groups: blockingGroups);
          if (!wide) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                status,
                const SizedBox(height: AppSpacing.lg),
                attention,
              ],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 3, child: status),
              const SizedBox(width: AppSpacing.xl),
              Expanded(flex: 2, child: attention),
            ],
          );
        },
      ),
    );
  }
}

class _WeekStatusCopy extends StatelessWidget {
  const _WeekStatusCopy({required this.report});

  final WeeklyAttendanceReport report;

  @override
  Widget build(BuildContext context) {
    final coverage = report.coverage;
    final blockers = coverage.ledgerCoverage.blockingExceptionRowCount;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Week status', style: AppTypography.h3),
        const SizedBox(height: AppSpacing.xs),
        Text(
          _headline(coverage, blockers),
          style: AppTypography.bodySmall.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          _detail(coverage),
          style: AppTypography.caption.copyWith(color: AppColors.textTertiary),
        ),
        if (blockers > 0) ...[
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

  static String _headline(WeeklyAttendanceCoverage coverage, int blockers) =>
      switch (coverage.status) {
        AttendanceCoverageStatus.noData =>
          'Nothing has been recorded for this week yet.',
        AttendanceCoverageStatus.needsAttention =>
          '$blockers ${blockers == 1 ? 'shift needs' : 'shifts need'} a decision '
              'before this week is settled.',
        AttendanceCoverageStatus.dataGap =>
          'Nothing needs a decision. Some days of the week have no shifts '
              'recorded.',
        AttendanceCoverageStatus.settled =>
          'Every day of this week is recorded and nothing needs a decision.',
      };

  /// The honest limit of what this report can currently tell a manager.
  ///
  /// The report reads only materialised shift records, so a day with no records
  /// is genuinely ambiguous: nobody was scheduled, or somebody was and it was
  /// never captured. Saying "no data" is true for both; the old copy picked the
  /// alarming reading and coloured it amber. Splitting the two needs the roster,
  /// which arrives with the Phase 1 rebuild.
  static String _detail(WeeklyAttendanceCoverage coverage) {
    return switch (coverage.status) {
      AttendanceCoverageStatus.noData =>
        'Percentages stay hidden until there is something to measure — this is '
            'missing data, not a zero attendance result.',
      AttendanceCoverageStatus.needsAttention =>
        'Numbers below cover the shifts already recorded.',
      AttendanceCoverageStatus.dataGap =>
        'Days shown as No data had no shifts recorded. That usually means '
            'nobody was scheduled.',
      AttendanceCoverageStatus.settled => 'Numbers below cover the whole week.',
    };
  }
}

class _AttentionCounts extends StatelessWidget {
  const _AttentionCounts({required this.groups});

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

class _NoDataYetPanel extends StatelessWidget {
  const _NoDataYetPanel();

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
                  'Once shifts are recorded for this week, the numbers appear '
                  'here.',
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

class _ShiftDetailTable extends StatelessWidget {
  const _ShiftDetailTable({required this.rows});

  final List<AttendanceLedgerRow> rows;

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Every shift', style: AppTypography.h3),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'One line per shift this week, with what was recorded against it.',
            style: AppTypography.caption.copyWith(
              color: AppColors.textTertiary,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          if (rows.isEmpty)
            Text(
              'No shifts recorded yet.',
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
                        const _ShiftDetailRow(
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
                        for (final row in rows) _ShiftDetailRow.forLedger(row),
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

class _ShiftDetailRow extends StatelessWidget {
  const _ShiftDetailRow({
    required this.cells,
    this.header = false,
    this.recordId,
  });

  factory _ShiftDetailRow.forLedger(AttendanceLedgerRow row) => _ShiftDetailRow(
    cells: [
      row.businessDate,
      row.userName?.trim().isNotEmpty ?? false
          ? row.userName!.trim()
          : row.userId,
      row.shift.label,
      // `outcome.label`, never `wireValue`: the persisted contract is not
      // English and a manager was reading `workedLate` / `noRecordYet`.
      row.outcome.label,
      '${row.workedMinutes}',
      '${row.lateMinutes}',
      // "Phantom row" was an engineering term for a shift nobody clocked into.
      // It said nothing true to a manager and everything about our data model.
      row.recordId == null ? 'No clock-in recorded' : 'Open record',
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
                                    : i == 6 && cells[i].startsWith('No clock-in')
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

/// *Restatement* is an accounting term for correcting a published financial
/// statement. It had no business on a store manager's screen; the panel now says
/// what a manager would say — share the week.
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
                Text('Share this week', style: AppTypography.h3),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'A printable summary and a timesheet spreadsheet are coming '
                  'next.',
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
    // Only a status with work behind it is toned. "No data yet" and "In
    // progress" used to be amber, which is how a week where nobody was
    // scheduled came to look like a week that went badly.
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
        ? 'Attendance reports are not switched on yet — an administrator needs '
              'to finish setting them up. Details: $raw'
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
