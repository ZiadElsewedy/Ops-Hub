import 'package:flutter/material.dart';
import 'package:drop/core/theme/app_colors.dart';
import 'package:drop/core/theme/app_radius.dart';
import 'package:drop/core/theme/app_spacing.dart';
import 'package:drop/core/theme/app_typography.dart';
import 'package:drop/core/widgets/glass_container.dart';
import 'package:drop/features/attendance/domain/reporting/attendance_report.dart';

/// The four numbers a store manager is accountable for
/// (`ATTENDANCE_REPORTS_IA` §6.5, amended 2026-07-31).
///
/// This is deliberately **not** a variant of `AttendanceReportMetrics`. That
/// widget renders the six-metric period grid and is still what Monthly uses;
/// Weekly needs a different *set*, not a different style, so it owns its own —
/// the same reasoning that gave the hub `AttendanceReportHeadline`.
///
/// What is not here, and why:
/// * **Show-up rate.** At one expected shift `0%` is meaningless and alarming —
///   the exact figure that made a real manager read a week where almost nobody
///   was rostered as a catastrophe. Percentages need volume, so the rate stays
///   at admin/multi-branch level where a denominator exists.
/// * **Punctual arrival rate.** Rendered `--` in that same week, and duplicates
///   late arrivals with worse behaviour at low volume.
/// * **Late minutes.** Nobody manages to a weekly minute total. The count is the
///   coaching signal; the minutes stay in the per-person table, where they
///   describe one person's week and can be acted on.
/// * **Exception count.** An internal integrity measure, not an outcome.
///
/// Each surviving metric names its formula, denominator, and the decision it
/// changes, per ADR-017's metric bar.
class AttendanceWeeklyKpis extends StatelessWidget {
  const AttendanceWeeklyKpis({super.key, required this.summary});

  final AttendanceReportSummary summary;

  @override
  Widget build(BuildContext context) {
    final metrics = <_Kpi>[
      _Kpi(
        label: 'Hours worked',
        value: _hours(summary.workedMinutes),
        detail: 'Across ${summary.present} shifts worked',
        icon: Icons.timer_outlined,
      ),
      _Kpi(
        label: 'Overtime',
        value: _hours(summary.overtimeMinutes),
        detail: 'Across ${summary.present} shifts worked',
        icon: Icons.more_time_rounded,
        // Overtime costs money, so it is called out once it exists — but it is
        // a cost to authorise, not a failure, so it never wears the error red
        // that an unworked shift does.
        tone: summary.overtimeMinutes > 0 ? AppColors.warning : null,
      ),
      _Kpi(
        label: 'Unexcused absences',
        value: '${summary.absent}',
        detail: '${summary.absent} of ${summary.expectedWorkShifts} '
            'scheduled shifts',
        icon: Icons.person_off_outlined,
        tone: summary.absent > 0 ? AppColors.error : null,
      ),
      _Kpi(
        label: 'Late arrivals',
        value: '${summary.lateArrivals}',
        detail: '${summary.lateArrivals} of ${summary.present} shifts worked',
        icon: Icons.schedule_rounded,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final columns = width >= 1120
            ? 4
            : width >= 720
            ? 2
            : 1;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: metrics.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            crossAxisSpacing: AppSpacing.md,
            mainAxisSpacing: AppSpacing.md,
            // Must fit a 34px icon row, the display value, and a two-line
            // denominator caption inside AppSpacing.lg padding — the same
            // constraint documented on AttendanceReportMetrics. Do not lower it
            // without shortening the denominator line: the denominator is the
            // one thing every metric card exists to disclose.
            mainAxisExtent: 152,
          ),
          itemBuilder: (context, index) => _KpiCard(kpi: metrics[index]),
        );
      },
    );
  }

  static String _hours(int minutes) {
    if (minutes <= 0) return '0h';
    final hours = minutes ~/ 60;
    final mins = minutes % 60;
    return mins == 0 ? '${hours}h' : '${hours}h ${mins}m';
  }
}

class _Kpi {
  const _Kpi({
    required this.label,
    required this.value,
    required this.detail,
    required this.icon,
    this.tone,
  });

  final String label;
  final String value;
  final String detail;
  final IconData icon;
  final Color? tone;
}

class _KpiCard extends StatelessWidget {
  const _KpiCard({required this.kpi});

  final _Kpi kpi;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '${kpi.label}: ${kpi.value}. ${kpi.detail}',
      child: GlassContainer(
        elevated: false,
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    borderRadius: AppRadius.mdAll,
                    border: Border.all(color: AppColors.darkBorder),
                    color: AppColors.primarySurface.withValues(alpha: 0.08),
                  ),
                  child: Icon(
                    kpi.icon,
                    size: 18,
                    color: kpi.tone ?? AppColors.textSecondary,
                  ),
                ),
                const Spacer(),
                // Flexible, never a bare Text beside a Spacer: maxLines only
                // engages once the text is constrained, otherwise a long label
                // sizes to its natural width and overflows the card.
                Flexible(
                  child: Text(
                    kpi.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.end,
                    style: AppTypography.caption.copyWith(
                      color: AppColors.textTertiary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const Spacer(),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                kpi.value,
                style: AppTypography.displayMedium.copyWith(
                  color: kpi.tone ?? AppColors.textPrimary,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              kpi.detail,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.caption.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
