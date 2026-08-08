import 'package:flutter/material.dart';
import 'package:drop/core/theme/app_colors.dart';

/// **DropWordmark** — the DROP logotype rendered **typographically** (heavy
/// weight, tight tracking), the minimal-luxury-streetwear complement to the
/// PNG artwork [DropLogo]. Use it where the asset is overkill: inline headers,
/// empty/loading states, auth chrome — it's vector-crisp at any size, needs no
/// asset load, and tints to any [color].
///
/// Strictly monochrome (white on the dark UI by default).
class DropWordmark extends StatelessWidget {
  const DropWordmark({
    super.key,
    this.fontSize = 28,
    this.color,
    this.letterSpacing,
  });

  final double fontSize;
  final Color? color;

  /// Negative tracking gives the tight, premium set; defaults proportional to
  /// the size.
  final double? letterSpacing;

  @override
  Widget build(BuildContext context) {
    return Text(
      'Drop Operations',
      style: TextStyle(
        fontSize: fontSize,
        fontWeight: FontWeight.w800,
        letterSpacing: letterSpacing ?? -fontSize * 0.05,
        height: 1.0,
        color: color ?? AppColors.textPrimary,
      ),
    );
  }
}
