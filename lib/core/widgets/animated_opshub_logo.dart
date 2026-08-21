import 'package:flutter/material.dart';
import 'package:drop/core/theme/app_colors.dart';
import 'package:drop/core/widgets/opshub_logo.dart';

/// [OpsHubLogo] with premium motion — a soft diagonal band of light sweeps
/// across the wordmark, then the logo rests until the next pass. Strictly
/// monochrome (the band is white light, no colour, no glow halo).
///
/// Use it where the brand is the hero — the splash lockup, the login brand
/// panel. Quiet chrome marks (app bars, hint rows) keep the static [OpsHubLogo].
class AnimatedOpsHubLogo extends StatefulWidget {
  const AnimatedOpsHubLogo({
    super.key,
    this.height = 80,
    this.period = const Duration(milliseconds: 3200),
  });

  final double height;

  /// Full cycle length — the sweep runs in the first ~45% of it, the rest of
  /// the cycle the logo is still (a beam every few seconds, not a strobe).
  final Duration period;

  @override
  State<AnimatedOpsHubLogo> createState() => _AnimatedOpsHubLogoState();
}

class _AnimatedOpsHubLogoState extends State<AnimatedOpsHubLogo>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl =
      AnimationController(vsync: this, duration: widget.period)..repeat();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, child) {
        // Band position: travels across during the first 45% of the cycle,
        // then parks off-canvas (all stops clamp to an edge → no overlay).
        final t = (_ctrl.value / 0.45).clamp(0.0, 1.0);
        final x = -0.4 + Curves.easeInOut.transform(t) * 1.8;
        return ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (rect) => LinearGradient(
            // A slight diagonal reads as light, not a scanline.
            begin: const Alignment(-1.0, -0.35),
            end: const Alignment(1.0, 0.35),
            colors: [
              Colors.transparent,
              AppColors.white.withAlpha(150),
              Colors.transparent,
            ],
            stops: [
              (x - 0.22).clamp(0.0, 1.0),
              x.clamp(0.0, 1.0),
              (x + 0.22).clamp(0.0, 1.0),
            ],
          ).createShader(rect),
          child: child,
        );
      },
      // The base sits just under full white so the passing band visibly
      // lights the letters up to 100%.
      child: OpsHubLogo(
        height: widget.height,
        color: AppColors.textPrimary.withAlpha(225),
      ),
    );
  }
}
