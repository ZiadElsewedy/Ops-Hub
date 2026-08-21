import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:opshub/core/theme/app_colors.dart';

/// The OpsHub brand logo — the white vector hub mark at `assets/opshub_icon.svg`.
///
/// It's tinted to [color] (white on the dark UI by default) via
/// [BlendMode.srcIn] to stay crisp on the near-black background. Size it with
/// [height]; the width follows the artwork's aspect ratio. Used app-wide:
/// splash/loading, login, the role-home app bars, the desktop sidebar lockup,
/// and the quiet mark on every mobile app bar (`AdaptiveScaffold.showBrandMark`).
class OpsHubLogo extends StatelessWidget {
  final double height;
  final Color? color;

  const OpsHubLogo({super.key, this.height = 80, this.color});

  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset(
      'assets/opshub_icon.svg',
      height: height,
      fit: BoxFit.contain,
      colorFilter: ColorFilter.mode(color ?? AppColors.textPrimary, BlendMode.srcIn),
    );
  }
}
