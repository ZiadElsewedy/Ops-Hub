import 'package:flutter/material.dart';
import 'package:opshub/core/theme/app_colors.dart';
import 'package:opshub/core/theme/app_spacing.dart';
import 'package:opshub/core/theme/app_typography.dart';
import 'package:opshub/core/widgets/rolling_number.dart';
import 'package:opshub/core/widgets/app_error_state.dart';
import 'package:opshub/core/widgets/glass_container.dart';
import 'package:opshub/core/widgets/skeleton.dart';
import 'package:opshub/features/sales/presentation/cubit/sales_month_state.dart';
import 'package:opshub/features/sales/presentation/sales_format.dart';
import 'package:opshub/features/sales/presentation/widgets/sales_progress_ring.dart';

/// The employee Home sales module: the **branch's** month at a glance — a small
/// progress ring, the achieved figure over the target, and the remainder — with
/// a tap into the full page. Nothing else.
///
/// Labelled "branch" deliberately — the monthly target is a team number every
/// colleague's approved day feeds, not a personal quota.
///
/// A Home module is one row in a dashboard: the ring answers "how far?" at a
/// glance, `achieved / target` states it in figures, and everything heavier
/// (pace, history, the DROP mark) lives one tap away on `/sales/mine`. The
/// achieved figure and the ring read [AppColors.salesEmerald]; the achieved
/// figure is a [RollingNumber] odometer because it is the number that moves.
class SalesTargetCard extends StatelessWidget {
  const SalesTargetCard.loading({super.key})
    : state = null,
      errorMessage = null,
      onRetry = null,
      onOpen = null;

  const SalesTargetCard.error({
    super.key,
    required this.errorMessage,
    required this.onRetry,
  }) : state = null,
       onOpen = null;

  const SalesTargetCard({super.key, required this.state, required this.onOpen})
    : errorMessage = null,
      onRetry = null;

  final SalesMonthLoaded? state;
  final String? errorMessage;
  final VoidCallback? onRetry;
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    if (errorMessage != null) {
      return AppProblemPanel(
        title: 'Sales unavailable',
        message: errorMessage!,
        onRetry: onRetry,
      );
    }
    final loaded = state;
    if (loaded == null) {
      return const GlassContainer(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Skeleton(height: 12, width: 110),
            SizedBox(height: AppSpacing.lg),
            Skeleton(height: 40),
          ],
        ),
      );
    }

    final snapshot = loaded.snapshot;
    if (!snapshot.hasTarget) {
      return Semantics(
        button: true,
        label: 'Branch monthly sales',
        child: GlassContainer(
          onTap: onOpen,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _Header(),
              const SizedBox(height: AppSpacing.md),
              Text(
                'No branch target set for this month yet.',
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final achieved = snapshot.approvedTotalPiastres;
    final target = snapshot.target!.targetPiastres;
    final remaining = snapshot.remainingPiastres;
    return Semantics(
      button: true,
      label:
          'Branch monthly sales. Achieved '
          '${formatEgp(achieved, withSuffix: true)} of '
          '${formatEgp(target, withSuffix: true)}, '
          '${formatEgp(remaining, withSuffix: true)} remaining.',
      child: ExcludeSemantics(
        child: GlassContainer(
          onTap: onOpen,
          child: Row(
            children: [
              _MiniRing(ratio: snapshot.progressRatioCapped),
              const SizedBox(width: AppSpacing.lg),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _Header(),
                    const SizedBox(height: AppSpacing.sm),
                    // achieved (white, rolling) / target (grey, static)
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          RollingNumber(
                            value: achieved,
                            formatter: (v) => formatEgp(v.round()),
                            animateOnMount: true,
                            style: AppTypography.h2.copyWith(
                              color: AppColors.salesEmerald,
                              fontWeight: FontWeight.w700,
                              fontFeatures: const [
                                FontFeature.tabularFigures(),
                              ],
                            ),
                          ),
                          Text(
                            ' / ${formatEgp(target)}',
                            maxLines: 1,
                            style: AppTypography.h3.copyWith(
                              color: AppColors.textTertiary,
                              fontFeatures: const [
                                FontFeature.tabularFigures(),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 2),
                    RollingNumber(
                      value: remaining,
                      formatter: (v) => '${formatEgp(v.round())} EGP remaining',
                      animateOnMount: true,
                      delay: const Duration(milliseconds: 220),
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.textTertiary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The card's title row: the label and the tap-through chevron.
class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: Text(
          'BRANCH MONTHLY SALES',
          style: AppTypography.labelSmall.copyWith(
            color: AppColors.textTertiary,
            letterSpacing: 1,
          ),
        ),
      ),
      const Icon(
        Icons.chevron_right_rounded,
        size: 18,
        color: AppColors.textTertiary,
      ),
    ],
  );
}

/// A compact, empty-centred gauge — the arc sweeps in on the shared premium
/// curve, no figure inside (the figures live beside it).
class _MiniRing extends StatelessWidget {
  const _MiniRing({required this.ratio});

  final double ratio;

  @override
  Widget build(BuildContext context) {
    final capped = ratio.isNaN ? 0.0 : ratio.clamp(0.0, 1.0).toDouble();
    return SizedBox(
      width: 58,
      height: 58,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: capped),
        duration: const Duration(milliseconds: 2800),
        curve: kReelSettle,
        builder: (context, value, _) => CustomPaint(
          painter: SalesRingPainter(
            ratio: value,
            stroke: 7,
            // The same premium emerald arc as the hero — soft sweep + halo.
            arcColor: AppColors.salesEmerald,
            arcColorEnd: AppColors.salesEmeraldGlow,
            glow: true,
          ),
        ),
      ),
    );
  }
}
