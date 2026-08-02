import 'package:flutter/material.dart';
import 'package:drop/features/attendance/domain/attendance_review_link.dart';
import 'package:drop/features/attendance/domain/reporting/attendance_timesheet_csv.dart';
import 'package:drop/features/attendance/domain/reporting/attendance_weekly_pdf.dart';
import 'package:open_filex/open_filex.dart';
import 'package:drop/core/widgets/app_snackbar.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
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
import 'package:drop/features/attendance/domain/reporting/attendance_export_gate.dart';
import 'package:drop/features/attendance/domain/reporting/attendance_weekly_report.dart';
import 'package:drop/features/attendance/domain/repositories/attendance_week_review_repository.dart';
import 'package:drop/features/attendance/domain/reporting/attendance_week_review.dart';
import 'package:drop/features/attendance/domain/attendance_id.dart';
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
    this.weekReviewRepository,
  });

  final String periodId;
  final AttendanceReportCubit? cubit;

  /// Injectable for tests, exactly like [cubit]. Null falls back to DI — a
  /// widget reaching straight into a `late final` singleton is what made this
  /// screen untestable in the first place.
  final AttendanceWeekReviewRepository? weekReviewRepository;

  @override
  Widget build(BuildContext context) {
    final parsed = WeeklyAttendancePeriodRef.tryParse(periodId);
    final view = _AttendanceWeeklyReportView(
      period: parsed,
      rawPeriodId: periodId,
      weekReviewRepository: weekReviewRepository,
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
    this.weekReviewRepository,
  });

  final WeeklyAttendancePeriodRef? period;
  final String rawPeriodId;
  final AttendanceWeekReviewRepository? weekReviewRepository;

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
            _WeeklyReportLoader(
              period: period,
              weekReviewRepository: widget.weekReviewRepository,
            ),
        ],
      ),
    );
  }
}

class _WeeklyReportLoader extends StatelessWidget {
  const _WeeklyReportLoader({
    required this.period,
    this.weekReviewRepository,
  });

  final WeeklyAttendancePeriodRef period;
  final AttendanceWeekReviewRepository? weekReviewRepository;

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
              weekReviewRepository: weekReviewRepository,
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
    this.weekReviewRepository,
  });

  final WeeklyAttendancePeriodRef period;
  final String branchName;
  final WeeklyAttendanceReport report;
  final AttendanceWeekReviewRepository? weekReviewRepository;

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
          _NeedsAttention(
            report: report,
            groups: blockingGroups,
            period: period,
          ),
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

        // 3 — By person, exceptions first. A row opens that person's own
        // records, pinned to this branch and this week, so the ledger answers
        // the question the row raised instead of a differently-scoped one.
        AttendanceWeeklyEmployeeRows(
          employees: report.employees,
          showStatus: true,
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
        _SharePanel(report: report, branchName: branchName),
        const SizedBox(height: AppSpacing.xl),

        // 6 — Week review: an assertion, kept visually apart from the derived
        // status in the header so neither can be read as implying the other.
        _WeekReview(
          period: period,
          report: report,
          repository: weekReviewRepository,
        ),
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
      // No "Close week" here. It was the most prominent control on the report,
      // wore a padlock, and was hardcoded `onPressed: null` — it could never do
      // anything. Worse, it promised the one thing the product deliberately
      // refuses: [ADR-019](docs/decisions/ADR-019-operational-exports-and-week-review.md)
      // decides a week is **reviewed, never locked** — "no write is rejected, no
      // rule enforces it, no period becomes immutable". The real mechanism is the
      // Week review section at the foot of this report, which records who looked
      // and when, and is reversible.
      //
      // Only the status pill travels in the hero. A third action here overflowed
      // PageHero's stacked Row by 155px at mobile width, and the share panel at
      // the foot already carries the PDF/CSV affordances.
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
  const _NeedsAttention({
    required this.report,
    required this.groups,
    required this.period,
  });

  final WeeklyAttendanceReport report;
  final List<WeeklyAttendanceExceptionGroup> groups;

  /// Carries the branch id — the report itself does not, and Daily Review is
  /// addressed by branch + day.
  final WeeklyAttendancePeriodRef period;

  /// The earliest day this week that still has a blocking decision, as a
  /// `yyyyMMdd` key. Null when nothing is open, which disables the action rather
  /// than sending a manager to an already-settled day.
  static String? _firstDayNeedingAttention(WeeklyAttendanceReport report) {
    for (final day in report.days) {
      if (day.blockingExceptionCount > 0) return day.dayKey;
    }
    return null;
  }

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
          // This said "Daily review is coming next" long after Daily Review
          // shipped — the day table directly below already opens it. It now goes
          // where the decisions are actually made: the earliest day in this week
          // that still has something open.
          final openDay = _firstDayNeedingAttention(report);
          final action = PremiumButton(
            label: 'Review these',
            icon: Icons.fact_check_outlined,
            onPressed: openDay == null
                ? null
                : () => context.push(
                    RouteNames.attendanceDailyReview(
                      period.branchId,
                      openDay,
                    ),
                  ),
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

/// **Payroll export is deliberately absent here.** It lives in the Admin
/// Workspace behind a period lock, so it can never be pressed by someone who
/// meant to print a summary (`ATTENDANCE_PRODUCT_REDESIGN_PLAN` §9.2). The word
/// *restatement* went with it: it is an accounting term for correcting a
/// published financial statement and had no business on a store screen.
class _SharePanel extends StatelessWidget {
  const _SharePanel({required this.report, required this.branchName});

  final WeeklyAttendanceReport report;
  final String branchName;

  @override
  Widget build(BuildContext context) {
    final role = context.currentUser?.role ?? UserRole.employee;
    // Both manager artifacts share one gate, so a single lookup answers both.
    final availability = attendanceExportAvailability(
      kind: AttendanceExportKind.summaryPdf,
      role: role,
      hasRows: report.rows.isNotEmpty,
      blockingRows: report.coverage.ledgerCoverage.blockingExceptionRowCount,
    );

    return GlassContainer(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.ios_share_rounded, color: AppColors.textTertiary),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Share this week', style: AppTypography.h3),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  availability.message ??
                      'A printable summary and a timesheet spreadsheet of this '
                          'week.',
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: [
                    PremiumButton(
                      label: AttendanceExportKind.summaryPdf.label,
                      icon: Icons.picture_as_pdf_outlined,
                      onPressed: availability.isAllowed
                          ? () => _saveWeeklyPdf(context, report, branchName)
                          : null,
                    ),
                    PremiumButton(
                      label: AttendanceExportKind.timesheetCsv.label,
                      icon: Icons.table_view_outlined,
                      onPressed: availability.isAllowed
                          ? () => _saveTimesheetCsv(context, report, branchName)
                          : null,
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

/// Write the weekly PDF beside the timesheet and open it.
///
/// Opening matters more than saving on mobile: `getDownloadsDirectory()` is
/// desktop-only, so on a phone the file lands in the app's sandbox where nobody
/// would ever find it. Handing it to the system viewer is what lets a manager
/// actually send it on — the same reason `chat_document_service` opens what it
/// downloads.
Future<void> _saveWeeklyPdf(
  BuildContext context,
  WeeklyAttendanceReport report,
  String branchName,
) async {
  try {
    final bytes = await buildWeeklyAttendancePdf(
      report: report,
      branchName: branchName,
    );
    final file = await _writeExport(
      attendanceWeeklyPdfFilename(branchName, report.window.startDate),
      (f) => f.writeAsBytes(bytes, flush: true),
    );
    if (context.mounted) {
      AppSnackbar.success(context, 'Saved · ${file.uri.pathSegments.last}');
    }
    await _openExport(file);
  } catch (_) {
    if (context.mounted) {
      AppSnackbar.error(context, 'Could not create the PDF.');
    }
  }
}

Future<File> _writeExport(
  String filename,
  Future<void> Function(File) write,
) async {
  final directory =
      await getDownloadsDirectory() ?? await getApplicationDocumentsDirectory();
  final file = File('${directory.path}${Platform.pathSeparator}$filename');
  await write(file);
  return file;
}

/// Mobile gets the system opener; desktop already reveals the Downloads folder,
/// so a viewer would be noise there.
Future<void> _openExport(File file) async {
  if (Platform.isAndroid || Platform.isIOS) {
    await OpenFilex.open(file.path);
  }
}

/// Write the timesheet next to where the Schedule PNG export puts its file, so
/// a manager looks in one place for anything this app produces ([ADR-019]).
///
/// Client-side by design now that the artifact is operational rather than a
/// payroll hand-off — no Cloud Function, no Storage, no deploy dependency.
Future<void> _saveTimesheetCsv(
  BuildContext context,
  WeeklyAttendanceReport report,
  String branchName,
) async {
  try {
    final csv = buildAttendanceTimesheetCsv(report.rows);
    final file = await _writeExport(
      attendanceTimesheetFilename(branchName, report.window.startDate),
      (f) => f.writeAsString(csv, flush: true),
    );
    if (context.mounted) {
      AppSnackbar.success(context, 'Saved · ${file.uri.pathSegments.last}');
    }
    await _openExport(file);
  } catch (_) {
    if (context.mounted) {
      AppSnackbar.error(context, 'Could not save the timesheet.');
    }
  }
}

/// **Week review** — a manager's statement that they looked ([ADR-019]).
///
/// Deliberately its own section, and deliberately *not* merged into the header
/// status pill. The pill answers "is the record complete?" and is computed; this
/// answers "has a person signed off?" and cannot be. Merging them is how
/// "Fully closed" once appeared over a week that was 86% empty.
class _WeekReview extends StatefulWidget {
  const _WeekReview({
    required this.period,
    required this.report,
    this.repository,
  });

  final WeeklyAttendancePeriodRef period;
  final WeeklyAttendanceReport report;
  final AttendanceWeekReviewRepository? repository;

  @override
  State<_WeekReview> createState() => _WeekReviewState();
}

class _WeekReviewState extends State<_WeekReview> {
  bool _busy = false;

  AttendanceWeekReviewRepository get _repo =>
      widget.repository ?? AppDependencies.weekReviewRepository;

  Future<void> _mark(BuildContext context) async {
    final user = context.currentUser;
    if (user == null || _busy) return;
    setState(() => _busy = true);
    try {
      await _repo.markReviewed(
        AttendanceWeekReview(
          branchId: widget.period.branchId,
          weekStartKey: attendanceDayKey(widget.period.window.startDate),
          reviewedBy: user.uid,
          reviewedByName: user.displayName,
          // Overwritten by the server stamp; a device clock must not be able to
          // place a sign-off before a change it actually followed.
          reviewedAt: DateTime.now(),
        ),
      );
      if (context.mounted) AppSnackbar.success(context, 'Week marked reviewed.');
    } catch (_) {
      if (context.mounted) {
        AppSnackbar.error(context, 'Could not save the review.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _reopen(BuildContext context) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await _repo.reopen(
        branchId: widget.period.branchId,
        weekStart: widget.period.window.startDate,
      );
      if (context.mounted) AppSnackbar.info(context, 'Week reopened.');
    } catch (_) {
      if (context.mounted) AppSnackbar.error(context, 'Could not reopen.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AttendanceWeekReview?>(
      stream: _repo.watchWeekReview(
        branchId: widget.period.branchId,
        weekStart: widget.period.window.startDate,
      ),
      builder: (context, snapshot) {
        final state = AttendanceWeekReviewState.resolve(
          review: snapshot.data,
          rows: widget.report.rows,
        );
        final open =
            widget.report.coverage.ledgerCoverage.blockingExceptionRowCount;
        return GlassContainer(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Week review', style: AppTypography.h3),
              const SizedBox(height: AppSpacing.xs),
              Text(
                state.label,
                style: AppTypography.bodySmall.copyWith(
                  color: state.hasChangedSince
                      ? AppColors.warning
                      : AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                _note(state, open),
                style: AppTypography.caption.copyWith(
                  color: AppColors.textTertiary,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              if (state.isReviewed)
                PremiumButton(
                  label: 'Reopen',
                  icon: Icons.lock_open_rounded,
                  style: PremiumButtonStyle.tonal,
                  onPressed: _busy ? null : () => _reopen(context),
                )
              else
                PremiumButton(
                  label: 'Mark week reviewed',
                  icon: Icons.check_rounded,
                  style: PremiumButtonStyle.filled,
                  onPressed: _busy ? null : () => _mark(context),
                ),
            ],
          ),
        );
      },
    );
  }

  /// A week with open items is still reviewable, and says so. Blocking the
  /// button would read as broken, and "a person looked" is true whether or not
  /// everything could be resolved.
  static String _note(AttendanceWeekReviewState state, int open) {
    if (!state.isReviewed) {
      return open > 0
          ? 'Marking it reviewed records that you looked. It does not lock '
                'anything, and $open item${open == 1 ? '' : 's'} would stay open.'
          : 'Marking it reviewed records that you looked. It does not lock '
                'anything — later changes stay possible, and show up here.';
    }
    if (state.hasChangedSince) {
      return 'Attendance changed after you reviewed this week. Nothing was '
          'blocked — this is here so the change is visible.';
    }
    return 'Nothing has changed since you reviewed it.';
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
