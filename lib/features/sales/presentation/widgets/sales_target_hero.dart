import 'package:flutter/material.dart';
import 'package:opshub/core/theme/app_colors.dart';
import 'package:opshub/core/theme/app_spacing.dart';
import 'package:opshub/core/theme/app_typography.dart';
import 'package:opshub/core/widgets/rolling_number.dart';
import 'package:opshub/features/sales/presentation/sales_format.dart';
import 'package:opshub/features/sales/presentation/widgets/sales_progress_ring.dart';

/// The employee month **hero**: a big centred progress ring — the arc sweeps in
/// and the percentage counts up together — over **Target · Achieved · Remaining**
/// read as three labelled columns.
///
/// This is the one screen that leads with the ring rather than the flat
/// [SalesMoneyRow]: the employee's question is "how far is the team?", and the
/// gauge answers it before the figures do.
///
/// Colour, by owner ruling, softens the strict-monochrome default (ADR-004)
/// **here only**, using the muted sales accents so the palette stays refined:
/// the gauge and **Achieved** read [AppColors.salesEmerald] (the progress that
/// has landed), **Remaining** reads [AppColors.salesAmber] gold (the work still
/// owed), and **Target** stays on the neutral grey ramp (the fixed goal).
///
/// Every figure is a [RollingNumber] — a per-digit odometer that rolls each
/// wheel to its new value — so a sale landing or a target edit reads as a
/// mechanical count, not a fade.
class SalesTargetHero extends StatelessWidget {
  const SalesTargetHero({
    super.key,
    required this.targetPiastres,
    required this.achievedPiastres,
    required this.remainingPiastres,
    required this.progressRatio,
  });

  final int targetPiastres;
  final int achievedPiastres;
  final int remainingPiastres;

  /// Capped `0..1` progress toward target — the ring's fill.
  final double progressRatio;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label:
          'Achieved ${formatEgp(achievedPiastres, withSuffix: true)}, '
          'target ${formatEgp(targetPiastres, withSuffix: true)}, '
          'remaining ${formatEgp(remainingPiastres, withSuffix: true)}.',
      child: ExcludeSemantics(
        child: Column(
          children: [
            Center(child: _HeroRing(ratio: progressRatio)),
            const SizedBox(height: AppSpacing.xl),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _HeroFigure(
                    label: 'TARGET',
                    valuePiastres: targetPiastres,
                    align: CrossAxisAlignment.start,
                    delay: const Duration(milliseconds: 120),
                  ),
                ),
                Expanded(
                  child: _HeroFigure(
                    label: 'ACHIEVED',
                    valuePiastres: achievedPiastres,
                    align: CrossAxisAlignment.center,
                    color: AppColors.salesEmerald,
                  ),
                ),
                Expanded(
                  child: _HeroFigure(
                    label: 'REMAINING',
                    valuePiastres: remainingPiastres,
                    align: CrossAxisAlignment.end,
                    color: AppColors.salesAmber,
                    delay: const Duration(milliseconds: 220),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// The large centred gauge: an emerald arc (deep → mint, with a restrained halo)
/// that sweeps to the fill, over a rolling percentage. The sweep and the
/// odometer settle in the same quick window so the gauge reads as one motion.
class _HeroRing extends StatelessWidget {
  const _HeroRing({required this.ratio});

  final double ratio;

  @override
  Widget build(BuildContext context) {
    final capped = ratio.isNaN ? 0.0 : ratio.clamp(0.0, 1.0).toDouble();
    return SizedBox(
      width: 208,
      height: 208,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // The arc sweeps on its own tween; the percentage rolls independently
          // so it never re-parses per frame.
          Positioned.fill(
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: capped),
              duration: const Duration(milliseconds: 2800),
              curve: kReelSettle,
              builder: (context, value, _) => CustomPaint(
                painter: SalesRingPainter(
                  ratio: value,
                  stroke: 14,
                  arcColor: AppColors.salesEmerald,
                  arcColorEnd: AppColors.salesEmeraldGlow,
                  glow: true,
                ),
              ),
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              RollingNumber(
                value: capped,
                formatter: (v) => v >= 0.9995
                    ? '100%'
                    : '${(v * 100).toStringAsFixed(1)}%',
                animateOnMount: true,
                style: AppTypography.display.copyWith(
                  color: AppColors.salesEmerald,
                  letterSpacing: -0.5,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'of target',
                style: AppTypography.caption.copyWith(
                  color: AppColors.textTertiary,
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// One labelled column beneath the ring — the caption, then the rolling figure.
class _HeroFigure extends StatelessWidget {
  const _HeroFigure({
    required this.label,
    required this.valuePiastres,
    required this.align,
    this.color,
    this.delay = Duration.zero,
  });

  final String label;
  final int valuePiastres;
  final CrossAxisAlignment align;
  final Color? color;
  final Duration delay;

  @override
  Widget build(BuildContext context) {
    final boxAlign = switch (align) {
      CrossAxisAlignment.end => Alignment.centerRight,
      CrossAxisAlignment.center => Alignment.center,
      _ => Alignment.centerLeft,
    };
    return Column(
      crossAxisAlignment: align,
      children: [
        Text(
          label,
          style: AppTypography.caption.copyWith(
            color: AppColors.textTertiary,
            letterSpacing: 0.8,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: AppSpacing.xs),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: boxAlign,
          child: RollingNumber(
            value: valuePiastres,
            formatter: (v) => formatEgp(v.round()),
            animateOnMount: true,
            delay: delay,
            style: AppTypography.h3.copyWith(
              color: color ?? AppColors.textSecondary,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ),
      ],
    );
  }
}
