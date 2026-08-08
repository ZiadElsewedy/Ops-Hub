import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:drop/core/theme/app_colors.dart';
import 'package:drop/core/theme/app_typography.dart';
import 'package:drop/core/widgets/rolling_number.dart' show kReelSettle;

/// The month's progress toward target as a ring — a [tint]ed arc (a soft sweep
/// toward white with a restrained halo) over a hairline track, the percentage
/// read in the middle.
///
/// The one figure that answers "how far are we?" at a glance. It sits beside the
/// pace card's "how fast are we?" verdict, which are deliberately different
/// questions: a month can be 40% of the way there and still projected to beat
/// target. Colour is *status* (ADR-004, softened on sales surfaces by owner
/// ruling): the manager passes the outlook tint (emerald ahead / gold behind /
/// white early); the default white keeps it neutral elsewhere.
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
  /// passes the outlook status tint (emerald ahead / gold behind / white early).
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
            duration: const Duration(milliseconds: 2800),
            curve: kReelSettle,
            builder: (context, value, _) {
              final percent = value >= 0.9995
                  ? '100%'
                  : '${(value * 100).toStringAsFixed(1)}%';
              return CustomPaint(
                painter: SalesRingPainter(
                  ratio: value,
                  stroke: stroke,
                  // The same premium arc as the employee hero — a soft sweep
                  // toward white with a restrained halo, in the status tint.
                  arcColor: tint,
                  arcColorEnd: Color.lerp(tint, AppColors.white, 0.45),
                  glow: true,
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

class SalesRingPainter extends CustomPainter {
  const SalesRingPainter({
    required this.ratio,
    required this.stroke,
    required this.arcColor,
    this.arcColorEnd,
    this.glow = false,
  });

  final double ratio;
  final double stroke;
  final Color arcColor;

  /// When set, the arc is painted as a sweep gradient [arcColor] → [arcColorEnd]
  /// that follows the fill, giving the hero gauge a soft metallic depth instead
  /// of one flat tone. Null keeps the plain single-colour arc used by the small
  /// rings elsewhere.
  final Color? arcColorEnd;

  /// A soft outer halo under the arc, in the arc's own colour — the premium
  /// glow reserved for the large hero gauge. Off for the compact rings.
  final bool glow;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = (math.min(size.width, size.height) - stroke) / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);
    const startAngle = -math.pi / 2; // 12 o'clock
    final sweep = 2 * math.pi * ratio; // clockwise

    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..color = AppColors.darkBorder;
    canvas.drawCircle(center, radius, track);

    if (ratio <= 0) return;

    // Soft halo first, so the crisp arc sits on top of its own glow.
    if (glow) {
      final halo = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round
        ..color = arcColor.withValues(alpha: 0.22)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
      canvas.drawArc(rect, startAngle, sweep, false, halo);
    }

    final progress = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    if (arcColorEnd != null) {
      progress.shader = SweepGradient(
        startAngle: 0,
        endAngle: 2 * math.pi,
        colors: [arcColor, arcColorEnd!],
        transform: const GradientRotation(startAngle),
      ).createShader(rect);
    } else {
      progress.color = arcColor;
    }
    canvas.drawArc(rect, startAngle, sweep, false, progress);
  }

  @override
  bool shouldRepaint(SalesRingPainter old) =>
      old.ratio != ratio ||
      old.stroke != stroke ||
      old.arcColor != arcColor ||
      old.arcColorEnd != arcColorEnd ||
      old.glow != glow;
}
