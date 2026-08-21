import 'package:flutter/material.dart';
import 'package:opshub/core/theme/app_colors.dart';
import 'package:opshub/core/theme/app_spacing.dart';
import 'package:opshub/core/theme/app_typography.dart';
import 'package:opshub/core/widgets/glass_container.dart';
import 'package:opshub/features/attendance/domain/reporting/attendance_report.dart';

/// **The numbers** — one headline plus its supporting detail, for the reports
/// hub only.
///
/// This is deliberately *not* a variant of `AttendanceReportMetrics`. That
/// widget is shared with the Weekly and Monthly reports, which are per-period
/// destinations where a flat grid of equal metrics is the right shape and is
/// owner-approved as it stands. The hub answers a different question and needs a
/// ranked answer, so it owns its own presentation and leaves the shared widget
/// untouched.
///
/// Hierarchy, top to bottom:
/// * **Primary** — show-up rate, with its denominator inline. Never a bare
///   percentage: an undisclosed rate is precisely the bug this feature exists to
///   fix (the old surface showed `Rate 100%` beside `Late 2`).
/// * **Supporting** — Expected · Present · Absent, the *components* of that
///   rate, rendered visibly smaller so they never read as its peers.
/// * **Conditional** — punctual arrivals and worked time need at least one
///   present shift to have a denominator. With none they collapse to a single
///   muted line rather than showing `--` over `0 / 0` at full tile weight.
///
/// The caller renders this only when there are recorded shifts. A scope with
/// none is missing data, shown by the verdict card as **No data yet** — never as
/// `0%` and never as zero-valued totals.
class AttendanceReportHeadline extends StatelessWidget {
  const AttendanceReportHeadline({super.key, required this.summary});

  final AttendanceReportSummary summary;

  @override
  Widget build(BuildContext context) {
    final showUp = summary.showUpRate;
    final punctual = summary.punctualArrivalRate;
    final hasPresentRows = summary.present > 0;

    return GlassContainer(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Show-up rate',
            style: AppTypography.caption.copyWith(
              color: AppColors.textTertiary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Semantics(
            label: 'Show-up rate: ${_rateValue(showUp)}. '
                '${_rateDenominator(showUp)}',
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(_rateValue(showUp), style: AppTypography.display),
                const SizedBox(width: AppSpacing.md),
                Text(
                  '·',
                  style: AppTypography.label.copyWith(
                    color: AppColors.textQuaternary,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                // Flexible, never a bare Text: the denominator must survive a
                // narrow window by wrapping, not by being clipped. It is the one
                // thing this figure exists to disclose.
                Flexible(
                  child: Text(
                    _rateDenominator(showUp),
                    maxLines: 2,
                    style: AppTypography.label.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const _Rule(),
          _ComponentRow(summary: summary),
          const SizedBox(height: AppSpacing.sm),
          Text(_componentsFootnote(summary), style: AppTypography.caption),
          if (hasPresentRows) ...[
            const _Rule(),
            _SecondaryFacts(
              facts: [
                _Fact(
                  value: _rateValue(punctual),
                  label: 'Punctual arrivals',
                  detail: _rateDenominator(punctual),
                ),
                _Fact(
                  value: _worked(summary.workedMinutes),
                  label: 'Worked time',
                  detail: 'Across ${summary.present} shifts worked',
                ),
              ],
            ),
          ] else ...[
            const SizedBox(height: AppSpacing.md),
            Text(
              'Nobody has worked a shift in this period yet, so there is no '
              'punctuality or worked time to show.',
              style: AppTypography.caption,
            ),
          ],
        ],
      ),
    );
  }

  static String _componentsFootnote(AttendanceReportSummary summary) {
    final excluded = summary.excused + summary.onLeave;
    if (excluded == 0) {
      return 'Scheduled shifts count the roster, after leave and excused days.';
    }
    return 'Scheduled shifts count the roster, after leave and excused days — '
        '${summary.excused} excused · ${summary.onLeave} on leave.';
  }

  static String _rateValue(AttendanceRate rate) {
    final percent = rate.percent;
    return percent == null ? '--' : '${percent.round()}%';
  }

  static String _rateDenominator(AttendanceRate rate) {
    return '${rate.numerator} / ${rate.denominator} ${rate.denominatorLabel}';
  }

  // Duplicated from the shared metrics widget on purpose: pulling it out would
  // mean editing that widget, which Weekly and Monthly render and which must
  // stay byte-for-byte unchanged.
  static String _worked(int minutes) {
    if (minutes <= 0) return '0h';
    final hours = minutes ~/ 60;
    final mins = minutes % 60;
    return mins == 0 ? '${hours}h' : '${hours}h ${mins}m';
  }
}

/// The components of the headline rate. Smaller values and a hairline above
/// them so the eye reads "these add up to the number above", not "here are
/// three more metrics".
class _ComponentRow extends StatelessWidget {
  const _ComponentRow({required this.summary});

  final AttendanceReportSummary summary;

  @override
  Widget build(BuildContext context) {
    final cells = <Widget>[
      _ComponentCell(
        value: '${summary.expectedWorkShifts}',
        label: 'Scheduled',
      ),
      _ComponentCell(value: '${summary.present}', label: 'Worked'),
      _ComponentCell(
        value: '${summary.absent}',
        label: 'Absent',
        tone: summary.absent > 0 ? AppColors.error : null,
      ),
    ];
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        for (var i = 0; i < cells.length; i++) ...[
          if (i > 0)
            Container(
              width: 1,
              height: 30,
              margin: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              color: AppColors.darkBorder,
            ),
          Expanded(child: cells[i]),
        ],
      ],
    );
  }
}

class _ComponentCell extends StatelessWidget {
  const _ComponentCell({required this.value, required this.label, this.tone});

  final String value;
  final String label;
  final Color? tone;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$label: $value',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: AppTypography.h2.copyWith(
                color: tone ?? AppColors.textPrimary,
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.caption.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _Fact {
  const _Fact({
    required this.value,
    required this.label,
    required this.detail,
  });

  final String value;
  final String label;
  final String detail;
}

/// The conditional pair. Same 3-step ramp as every other DROP metric cell —
/// white value → light-grey label → medium-grey denominator — but at supporting
/// weight, because they inform rather than lead.
class _SecondaryFacts extends StatelessWidget {
  const _SecondaryFacts({required this.facts});

  final List<_Fact> facts;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 420) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < facts.length; i++) ...[
                if (i > 0) const SizedBox(height: AppSpacing.lg),
                _FactCell(fact: facts[i]),
              ],
            ],
          );
        }
        // Top-aligned and naturally sized — no IntrinsicHeight and no fixed
        // extent, so a wrapped denominator grows the row instead of clipping.
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < facts.length; i++) ...[
              if (i > 0) const SizedBox(width: AppSpacing.xl),
              Expanded(child: _FactCell(fact: facts[i])),
            ],
          ],
        );
      },
    );
  }
}

class _FactCell extends StatelessWidget {
  const _FactCell({required this.fact});

  final _Fact fact;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '${fact.label}: ${fact.value}. ${fact.detail}',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(fact.value, style: AppTypography.h3),
          ),
          const SizedBox(height: 2),
          Text(
            fact.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.caption.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          Text(fact.detail, maxLines: 2, style: AppTypography.caption),
        ],
      ),
    );
  }
}

/// A hairline group separator. Grouping inside one card, rather than another
/// card — the uniform card-then-gap-then-card rhythm is what made the old page
/// read as a list of unrelated panels.
class _Rule extends StatelessWidget {
  const _Rule();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 1,
      color: AppColors.darkBorder,
      margin: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
    );
  }
}
