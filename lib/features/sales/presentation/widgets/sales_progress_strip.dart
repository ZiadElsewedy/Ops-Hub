import 'package:flutter/material.dart';
import 'package:drop/core/theme/app_colors.dart';
import 'package:drop/core/theme/app_radius.dart';
import 'package:drop/core/theme/app_spacing.dart';
import 'package:drop/core/theme/app_typography.dart';
import 'package:drop/features/sales/presentation/sales_format.dart';

class SalesProgressStrip extends StatelessWidget {
  const SalesProgressStrip({
    super.key,
    required this.ratioCapped,
    required this.ratioRaw,
    required this.remainingPiastres,
  });
  final double ratioCapped;
  final double ratioRaw;
  final int remainingPiastres;
  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Sales progress ${(ratioRaw * 100).round()} percent',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: AppRadius.fullAll,
          child: SizedBox(
            height: 8,
            child: Stack(
              children: [
                const Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(color: AppColors.darkBorder),
                  ),
                ),
                FractionallySizedBox(
                  widthFactor: ratioCapped,
                  child: const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [AppColors.primary, AppColors.primaryLight],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: [
            Text(
              '${(ratioRaw * 100).round()}%',
              style: AppTypography.label.copyWith(color: AppColors.textPrimary),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                '${formatEgp(remainingPiastres, withSuffix: true)} to target',
                textAlign: TextAlign.end,
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          ],
        ),
      ],
    ),
  );
}
