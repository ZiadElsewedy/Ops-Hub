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
import 'package:drop/features/attendance/domain/reporting/attendance_period.dart';
import 'package:drop/features/attendance/domain/reporting/attendance_coverage_status.dart';
import 'package:drop/features/attendance/domain/reporting/attendance_weekly_report.dart';
import 'package:drop/features/attendance/presentation/reporting/attendance_report_cubit.dart';
import 'package:drop/features/attendance/presentation/reporting/attendance_report_state.dart';
import 'package:drop/features/attendance/presentation/reporting/widgets/attendance_weekly_kpis.dart';
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

  /// Five sections, fixed order (`ATTENDANCE_REPORTS_IA` §6.4, amended
  /// 2026-07-31). Section 1 carries the only verb on the page and is absent
  /// whenever nothing is open, which in a healthy week is most of the time.
  @override
  Widget build(BuildContext context) {
    final awaiting = report.coverage.awaitingClose;
    final blockingGroups = report.exceptionGroups
        .where((group) => group.blocksClose)
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _HeaderSection(branchName: branchName, period: period, report: report),
        const SizedBox(height: AppSpacing.xl),

        // 1 — Needs your attention.
        if (blockingGroups.isNotEmpty) ...[
          _NeedsAttention(report: report, groups: blockingGroups),
          const SizedBox(height: AppSpacing.xl),
        ],

        // 2 — The week in one line: the sentence, then the four numbers behind
        // it. One section, because the cards are the sentence's detail.
        _WeekInOneLine(
          branchName: branchName,
          period: period,
          report: report,
        ),
        const SizedBox(height: AppSpacing.md),
        if (awaiting)
          const _NoDataYetPanel()
        else
          AttendanceWeeklyKpis(summary: report.summary),
        const SizedBox(height: AppSpacing.xl),

        // 3 — By person, exceptions first.
        AttendanceWeeklyEmployeeRows(
          employees: report.employees,
          showStatus: true,
        ),
        const SizedBox(height: AppSpacing.xl),

        // 4 — By day. A day row opens Daily Review for that date, which is
        // where the day actually gets settled (IA §6.8).
        AttendanceWeeklyDailyTable(
          days: report.days,
          onOpenDay: (day) => context.push(
            RouteNames.attendanceDailyReview(period.branchId, day.dayKey),
          ),
        ),
        const SizedBox(height: AppSpacing.xl),

        // 5 — Share.
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

/// **Section 1 — the only part of this report with a verb.**
///
/// Renders only when something is genuinely open. In a week where Daily Close
/// and the Exception Queue have done their job it is absent entirely, and its
/// absence is the answer: nothing needs you. That is why it is first — not
/// because it is the most common state, but because when it exists it outranks
/// everything else on the page.
class _NeedsAttention extends StatelessWidget {
  const _NeedsAttention({required this.report, required this.groups});

  final WeeklyAttendanceReport report;
  final List<WeeklyAttendanceExceptionGroup> groups;

  @override
  Widget build(BuildContext context) {
    final count = report.coverage.ledgerCoverage.blockingExceptionRowCount;
    return GlassContainer(
      highlight: true,
      accent: AppColors.warning,
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final headline = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Needs your attention', style: AppTypography.h3),
              const SizedBox(height: AppSpacing.xs),
              Text(
                '$count ${count == 1 ? 'shift needs' : 'shifts need'} a '
                'decision before this week is done.',
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              for (final group in groups)
                _MiniFact(label: group.label, value: '${group.count}'),
            ],
          );
          // The queue itself is Phase 2. The affordance explains itself rather
          // than sitting inert — a disabled button tells a manager nothing
          // about why it cannot be used.
          final action = PremiumButton(
            label: 'Review these',
            icon: Icons.fact_check_outlined,
            onPressed: () => context.showInfo('Daily review is coming next.'),
          );
          if (constraints.maxWidth < 560) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                headline,
                const SizedBox(height: AppSpacing.lg),
                action,
              ],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: headline),
              const SizedBox(width: AppSpacing.lg),
              action,
            ],
          );
        },
      ),
    );
  }
}

/// **Section 2 — the sentence a manager repeats to their district manager.**
///
/// Counts, never a percentage: `42 of 45 shifts worked` is honest at every
/// volume, where `93%` stops meaning anything below about twenty shifts and
/// becomes actively alarming at one (`ATTENDANCE_REPORTS_IA` §6.5).
///
/// The second line is the week's status in plain language, including the honest
/// limit of what the report can currently tell — a day with no records is an
/// unknown, not a bad result.
class _WeekInOneLine extends StatelessWidget {
  const _WeekInOneLine({
    required this.branchName,
    required this.period,
    required this.report,
  });

  final String branchName;
  final WeeklyAttendancePeriodRef period;
  final WeeklyAttendanceReport report;

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$branchName · ${_HeaderSection._weekLabel(period.window)}',
            style: AppTypography.caption.copyWith(
              color: AppColors.textTertiary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(_summaryLine(report), style: AppTypography.h2),
          const SizedBox(height: AppSpacing.sm),
          Text(
            _statusLine(report.coverage),
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  static String _summaryLine(WeeklyAttendanceReport report) {
    if (report.coverage.awaitingClose) return 'Nothing recorded yet';
    final worked = report.shiftsWorked;
    final scheduled = report.shiftsScheduled;
    final parts = <String>[
      '$worked of $scheduled ${scheduled == 1 ? 'shift' : 'shifts'} worked',
      _hours(report.summary.workedMinutes),
    ];
    if (report.summary.overtimeMinutes > 0) {
      parts.add('${_hours(report.summary.overtimeMinutes)} overtime');
    }
    return parts.join(' · ');
  }

  static String _statusLine(WeeklyAttendanceCoverage coverage) =>
      switch (coverage.status) {
        AttendanceCoverageStatus.noData =>
          'No shifts have been recorded for this week yet. Percentages stay '
              'hidden until there is something to measure.',
        AttendanceCoverageStatus.needsAttention =>
          'Some shifts still need a decision — see above.',
        AttendanceCoverageStatus.dataGap =>
          'Nothing needs a decision. Some days have no shifts recorded, which '
              'usually means nobody was scheduled.',
        AttendanceCoverageStatus.settled =>
          'Every day of this week is recorded and nothing needs a decision.',
      };

  static String _hours(int minutes) {
    if (minutes <= 0) return '0h';
    final hours = minutes ~/ 60;
    final mins = minutes % 60;
    return mins == 0 ? '${hours}h' : '${hours}h ${mins}m';
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

// `_ExceptionSummary` (Blocking / Informational) and the shift evidence table
// used to live here. Both are removed from the manager surface by
// `ATTENDANCE_REPORTS_IA` §6.4 (amended 2026-07-31), not deleted from the
// product: exceptions belong in Daily Close / the Exception Queue where they
// are resolved, and row-level evidence is an audit need that Phase 3's Admin
// Workspace owns. A manager who needs one record reaches it through the person
// or through the attendance history ledger at `/attendance/review`.

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
