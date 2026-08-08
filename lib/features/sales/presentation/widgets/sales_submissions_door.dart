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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header: icon · title · the total · chevron.
            Row(
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
                  child: Text(
                    'All submissions',
                    style: AppTypography.labelLarge,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text('$total', style: AppTypography.h3.copyWith(height: 1)),
                    const SizedBox(width: 4),
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
            const SizedBox(height: AppSpacing.lg),
            // A clean, evenly-split status breakdown that never truncates.
            Row(
              children: [
                Expanded(
                  child: _Stat(
                    value: pending,
                    label: 'Pending',
                    tone: AppColors.salesAmber,
                  ),
                ),
                const _StatDivider(),
                Expanded(
                  child: _Stat(
                    value: approved,
                    label: 'Approved',
                    tone: AppColors.salesEmerald,
                  ),
                ),
                const _StatDivider(),
                Expanded(
                  child: _Stat(
                    value: rejected,
                    label: 'Rejected',
                    tone: AppColors.salesCoral,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

/// One status segment: the count (in its status tint when there's something to
/// show, faint grey at zero) over a small grey label.
class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label, required this.tone});

  final int value;
  final String label;
  final Color tone;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(
        '$value',
        style: AppTypography.h3.copyWith(
          height: 1,
          color: value > 0 ? tone : AppColors.textQuaternary,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
      const SizedBox(height: 3),
      Text(
        label.toUpperCase(),
        style: AppTypography.caption.copyWith(
          color: AppColors.textTertiary,
          letterSpacing: 0.6,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    ],
  );
}

/// A hairline between two [_Stat] segments.
class _StatDivider extends StatelessWidget {
  const _StatDivider();

  @override
  Widget build(BuildContext context) => Container(
    width: 1,
    height: 30,
    margin: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
    color: AppColors.darkBorder,
  );
}
