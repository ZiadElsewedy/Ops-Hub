import 'package:flutter/material.dart';
import 'package:drop/core/theme/app_colors.dart';
import 'package:drop/core/theme/app_spacing.dart';
import 'package:drop/core/theme/app_typography.dart';
import 'package:drop/core/widgets/activity_card.dart';
import 'package:drop/features/sales/domain/entities/sales_month_snapshot.dart';
import 'package:drop/features/sales/presentation/sales_format.dart';

/// A read-only, newest-first list of recent approved business days.
class SalesRecentApprovedTrend extends StatelessWidget {
  const SalesRecentApprovedTrend({super.key, required this.snapshot});

  final SalesMonthSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final approved = [...snapshot.approved]
      ..sort((a, b) => b.businessDateKey.compareTo(a.businessDateKey));
    if (approved.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Recent approved days', style: AppTypography.labelLarge),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'Review the latest closes before deciding where to follow up.',
          style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary),
        ),
        const SizedBox(height: AppSpacing.md),
        for (final sale in approved.take(5))
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: ActivityCard(
              title: formatEgp(sale.amountPiastres, withSuffix: true),
              subtitle: 'Business day ${sale.businessDateKey}',
              semanticLabel:
                  '${formatEgp(sale.amountPiastres, withSuffix: true)} approved for business day ${sale.businessDateKey}',
            ),
          ),
      ],
    );
  }
}
