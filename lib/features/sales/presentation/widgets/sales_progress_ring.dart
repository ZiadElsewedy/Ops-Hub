import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:drop/core/theme/app_colors.dart';
import 'package:drop/core/theme/app_typography.dart';
import 'package:drop/core/widgets/animated_count_text.dart' show kPremiumSettle;

/// The month's progress toward target as a monochrome ring — a white arc over a
/// hairline track, the percentage read in the middle.
///
/// The one figure that answers "how far are we?" at a glance. It sits beside the
/// pace card's "how fast are we?" verdict, which are deliberately different
/// questions: a month can be 40% of the way there and still projected to beat
/// target. Strictly monochrome (ADR-004) — the fill is the white accent, never
/// a coloured gauge.
class SalesProgressRing extends StatelessWidget {
  const SalesProgressRing({
    super.key,
    required this.ratio,
    this.diameter = 104,
    this.stroke = 9,
    this.tint = AppColors.primary,
  });

  /// Progress in `0..1`. Values above 1 (over target) render a full ring.
  final double ratio;
  final double diameter;
  final double stroke;

  /// The arc + centre-percent colour. Defaults to white; the manager dashboard
  /// passes the outlook status tint (green ahead / amber behind / white early).
  final Color tint;

  @override
  Widget build(BuildContext context) {
    final capped = ratio.isNaN ? 0.0 : ratio.clamp(0.0, 1.0).toDouble();
    final settledPercent = capped >= 0.9995
        ? '100%'
        : '${(capped * 100).toStringAsFixed(1)}%';
    return Semantics(
      label: 'Progress $settledPercent of target',
      child: ExcludeSemantics(
        child: SizedBox(
          width: diameter,
          height: diameter,
          // The arc sweeps in and the percentage counts up together — the same
          // roll the money figures use, so the whole hero moves as one when a
          // sale lands or the target is edited.
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: capped),
            duration: const Duration(milliseconds: 2600),
            curve: kPremiumSettle,
            builder: (context, value, _) {
              final percent = value >= 0.9995
                  ? '100%'
                  : '${(value * 100).toStringAsFixed(1)}%';
              return CustomPaint(
                painter: _RingPainter(
                  ratio: value,
                  stroke: stroke,
                  arcColor: tint,
                ),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'PROGRESS',
                        style: AppTypography.caption.copyWith(
                          color: AppColors.textTertiary,
                          letterSpacing: 1.1,
                          fontSize: 9,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        percent,
                        style: AppTypography.h3.copyWith(
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.3,
                          color: tint,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  const _RingPainter({
    required this.ratio,
    required this.stroke,
    required this.arcColor,
  });

  final double ratio;
  final double stroke;
  final Color arcColor;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = (math.min(size.width, size.height) - stroke) / 2;

    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..color = AppColors.darkBorder;
    canvas.drawCircle(center, radius, track);

    if (ratio <= 0) return;
    final progress = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..color = arcColor;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2, // start at 12 o'clock
      2 * math.pi * ratio, // clockwise
      false,
      progress,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.ratio != ratio || old.stroke != stroke || old.arcColor != arcColor;
}
