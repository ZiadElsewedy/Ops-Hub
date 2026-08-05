import 'package:flutter/material.dart';
import 'package:drop/core/theme/app_colors.dart';
import 'package:drop/core/theme/app_spacing.dart';
import 'package:drop/core/theme/app_typography.dart';
import 'package:drop/features/sales/presentation/sales_format.dart';

/// The three money facts, in the same order, everywhere sales appears:
/// **Target · Achieved · Remaining**.
///
/// One component so Home, the employee page, the branch dashboard and the admin
/// overview cannot drift apart — and so "simplify the card" means deleting a
/// call site's extras, never re-deciding the typography. Achieved is the only
/// emphasised figure: it is the number that moves.
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
                  value: formatEgp(targetPiastres),
                  compact: compact,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: _Figure(
                  label: 'Achieved',
                  value: formatEgp(achievedPiastres),
                  compact: compact,
                  emphasised: true,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: _Figure(
                  label: 'Remaining',
                  value: formatEgp(remainingPiastres),
                  compact: compact,
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
    required this.value,
    required this.compact,
    this.emphasised = false,
  });

  final String label;
  final String value;
  final bool compact;
  final bool emphasised;

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
        child: Text(
          value,
          maxLines: 1,
          style: (compact ? AppTypography.label : AppTypography.h3).copyWith(
            color: emphasised
                ? AppColors.textPrimary
                : AppColors.textSecondary,
          ),
        ),
      ),
    ],
  );
}
