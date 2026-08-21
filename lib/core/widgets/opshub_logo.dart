import 'package:flutter/material.dart';
import 'package:opshub/core/theme/app_colors.dart';

/// The OpsHub brand logo — the wordmark artwork at `assets/opshub_logo.png`.
///
/// The PNG is a transparent-background outline, so it's tinted to [color]
/// (white on the dark UI by default) via [BlendMode.srcIn] to stay crisp on the
/// near-black background. Size it with [height]; the width follows the artwork's
/// aspect ratio. Used app-wide: splash/loading, login, the role-home app bars,
/// the desktop sidebar lockup, and the quiet mark on every mobile app bar
/// (`AdaptiveScaffold.showBrandMark`).
class OpsHubLogo extends StatelessWidget {
  final double height;
  final Color? color;

  const OpsHubLogo({super.key, this.height = 80, this.color});

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/opshub_logo.png',
      height: height,
      fit: BoxFit.contain,
      color: color ?? AppColors.textPrimary,
      colorBlendMode: BlendMode.srcIn,
      filterQuality: FilterQuality.medium,
    );
  }
}
