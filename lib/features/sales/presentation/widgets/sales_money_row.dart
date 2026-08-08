import 'package:flutter/material.dart';
import 'package:drop/core/theme/app_colors.dart';
import 'package:drop/core/theme/app_spacing.dart';
import 'package:drop/core/theme/app_typography.dart';
import 'package:drop/core/widgets/rolling_number.dart';
import 'package:drop/features/sales/presentation/sales_format.dart';

/// The three money facts, in the same order, everywhere sales appears:
/// **Target · Achieved · Remaining**.
///
/// One component so Home, the employee page, the branch dashboard and the admin
/// overview cannot drift apart — and so "simplify the card" means deleting a
/// call site's extras, never re-deciding the typography. Each figure is a
/// [RollingNumber] odometer in the muted sales palette — **Achieved** emerald
/// (the number that moves), **Remaining** gold, **Target** on the grey ramp.
///
/// The currency is named **once**, in the row's own caption, not three times.
/// Repeating "EGP" beside each figure pushed seven-digit amounts past their
/// column on a 375pt phone; each figure also scales down rather than clipping,
/// so a branch with a 10,000,000 target still reads cleanly.
class SalesMoneyRow extends StatelessWidget {
  const SalesMoneyRow({
    super.key,
    required this.targetPiastres,
    required this.achievedPiastres,
    required this.remainingPiastres,
    this.compact = false,
  });

  final int targetPiastres;
  final int achievedPiastres;
  final int remainingPiastres;

  /// Home-card density: smaller figures, tighter gaps.
  final bool compact;

  @override
  Widget build(BuildContext context) => Semantics(
    label:
        'Target ${formatEgp(targetPiastres, withSuffix: true)}, '
        'achieved ${formatEgp(achievedPiastres, withSuffix: true)}, '
        'remaining ${formatEgp(remainingPiastres, withSuffix: true)}',
    child: ExcludeSemantics(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _Figure(
                  label: 'Target',
                  valuePiastres: targetPiastres,
                  compact: compact,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: _Figure(
                  label: 'Achieved',
                  valuePiastres: achievedPiastres,
                  compact: compact,
                  color: AppColors.salesEmerald,
                  delay: const Duration(milliseconds: 120),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: _Figure(
                  label: 'Remaining',
                  valuePiastres: remainingPiastres,
                  compact: compact,
                  color: AppColors.salesAmber,
                  delay: const Duration(milliseconds: 240),
                ),
              ),
            ],
          ),
          SizedBox(height: compact ? AppSpacing.xs : AppSpacing.sm),
          Text(
            'EGP',
            style: AppTypography.caption.copyWith(
              color: AppColors.textQuaternary,
              letterSpacing: 0.8,
            ),
          ),
        ],
      ),
    ),
  );
}

class _Figure extends StatelessWidget {
  const _Figure({
    required this.label,
    required this.valuePiastres,
    required this.compact,
    this.color,
    this.delay = Duration.zero,
  });

  final String label;
  final int valuePiastres;
  final bool compact;

  /// The figure's colour — the sales accent for Achieved/Remaining, null for
  /// Target, which reads in the grey ramp.
  final Color? color;
  final Duration delay;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label.toUpperCase(),
        style: AppTypography.caption.copyWith(
          color: AppColors.textTertiary,
          letterSpacing: 0.8,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      SizedBox(height: compact ? 2 : AppSpacing.xs),
      // scaleDown keeps an unusually large amount inside its column instead of
      // ellipsising the digits that matter most.
      FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        child: RollingNumber(
          value: valuePiastres,
          formatter: (v) => formatEgp(v.round()),
          animateOnMount: true,
          delay: delay,
          // Snappier than the single-hero screens: this row appears in a
          // scrolling list of branches, so keep each roll brief.
          duration: const Duration(milliseconds: 700),
          perPlaceStep: const Duration(milliseconds: 40),
          maxExtra: const Duration(milliseconds: 320),
          style: (compact ? AppTypography.label : AppTypography.h3).copyWith(
            color: color ?? AppColors.textSecondary,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ),
    ],
  );
}
