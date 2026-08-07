import 'package:flutter/material.dart';
import 'package:drop/core/theme/app_colors.dart';
import 'package:drop/core/theme/app_radius.dart';
import 'package:drop/core/theme/app_spacing.dart';
import 'package:drop/core/theme/app_typography.dart';
import 'package:drop/core/widgets/glass_container.dart';

/// One door into the sales ledger, replacing the four Pending / Approved /
/// Rejected / History tiles.
///
/// Those four opened the **same** list screen with a different status filter,
/// so as separate tappable cards they read as four destinations that were
/// really one. This is a single row into all submissions; the counts survive as
/// an inline breakdown so the at-a-glance figures are not lost — but pending
/// work is acted on in the *Waiting on you* queue above, so this row is
/// reference, not the primary action.
class SalesSubmissionsDoor extends StatelessWidget {
  const SalesSubmissionsDoor({
    super.key,
    required this.pending,
    required this.approved,
    required this.rejected,
    required this.total,
    required this.onTap,
  });

  final int pending;
  final int approved;
  final int rejected;
  final int total;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label:
        'All submissions, $total total. '
        '$pending pending, $approved approved, $rejected rejected.',
    child: ExcludeSemantics(
      child: GlassContainer(
        onTap: onTap,
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: AppColors.darkSurfaceElevated,
                borderRadius: AppRadius.mdAll,
                border: Border.all(color: AppColors.darkBorder),
              ),
              child: const Icon(
                Icons.history_rounded,
                size: 20,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('All submissions', style: AppTypography.labelLarge),
                  const SizedBox(height: 5),
                  _Breakdown(
                    pending: pending,
                    approved: approved,
                    rejected: rejected,
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '$total',
                  style: AppTypography.h2.copyWith(height: 1),
                ),
                Text(
                  'total',
                  style: AppTypography.caption.copyWith(
                    color: AppColors.textTertiary,
                  ),
                ),
              ],
            ),
            const SizedBox(width: AppSpacing.xs),
            const Icon(
              Icons.chevron_right_rounded,
              color: AppColors.textQuaternary,
            ),
          ],
        ),
      ),
    ),
  );
}

class _Breakdown extends StatelessWidget {
  const _Breakdown({
    required this.pending,
    required this.approved,
    required this.rejected,
  });

  final int pending;
  final int approved;
  final int rejected;

  @override
  Widget build(BuildContext context) {
    TextSpan cell(String label, int value) => TextSpan(
      children: [
        TextSpan(
          text: '$value ',
          style: AppTypography.caption.copyWith(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        TextSpan(text: label, style: AppTypography.caption),
      ],
    );
    const dot = TextSpan(
      text: '  ·  ',
      style: TextStyle(color: AppColors.textQuaternary),
    );
    return Text.rich(
      TextSpan(
        children: [
          cell('Pending', pending),
          dot,
          cell('Approved', approved),
          dot,
          cell('Rejected', rejected),
        ],
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}
