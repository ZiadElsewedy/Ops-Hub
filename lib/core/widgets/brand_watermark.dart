import 'package:flutter/material.dart';
import 'package:opshub/core/theme/app_colors.dart';
import 'package:opshub/core/widgets/opshub_logo.dart';
import 'package:opshub/core/widgets/opshub_wordmark.dart';

/// Overlays a **barely-there** OpsHub wordmark in the corner of a premium hero —
/// a quiet brand presence, never decoration (§9b Wave 3, "selective header
/// branding"). Opacity is capped low (0.02–0.05); the mark is non-interactive
/// and clipped to the content bounds, so it can't obscure text or break layout.
///
/// Wrap a hero's content `Column`, typically inside the card surface:
/// `GlassContainer(child: BrandWatermark(child: ...))`. Strictly monochrome.
class BrandWatermark extends StatelessWidget {
  const BrandWatermark({
    super.key,
    required this.child,
    this.opacity = 0.04,
    this.fontSize = 88,
    this.assetLogo = false,
    this.assetHeight = 92,
    this.corner = Alignment.bottomRight,
  }) : assert(opacity <= 0.05, 'Keep the watermark subtle (≤ 0.05).');

  final Widget child;
  final double opacity;
  final double fontSize;

  /// Uses the real `assets/opshub_logo.png` artwork instead of the typographic
  /// [OpsHubWordmark]. Opt-in so established hero compositions do not change.
  final bool assetLogo;
  final double assetHeight;

  /// Which corner the mark tucks into (bleeding a few px off that edge). Only
  /// the four corners are meaningful; defaults to bottom-right so existing
  /// heroes are unchanged. Move it when a corner would sit behind live figures.
  final Alignment corner;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.hardEdge,
      children: [
        child,
        Positioned(
          left: corner.x < 0 ? -6 : null,
          right: corner.x > 0 ? -6 : null,
          top: corner.y < 0 ? -10 : null,
          bottom: corner.y > 0 ? -10 : null,
          child: IgnorePointer(
            child: Opacity(
              opacity: opacity,
              child: assetLogo
                  ? OpsHubLogo(
                      height: assetHeight,
                      color: AppColors.textPrimary,
                    )
                  : OpsHubWordmark(
                      fontSize: fontSize,
                      color: AppColors.textPrimary,
                    ),
            ),
          ),
        ),
      ],
    );
  }
}
