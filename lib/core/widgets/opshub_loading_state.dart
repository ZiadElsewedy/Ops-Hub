import 'package:flutter/material.dart';
import 'package:opshub/core/theme/app_colors.dart';
import 'package:opshub/core/theme/app_spacing.dart';
import 'package:opshub/core/theme/app_typography.dart';
import 'package:opshub/core/widgets/opshub_logo.dart';

/// **OpsHubLoadingState** — a **branded** full-area loading moment: the OpsHub mark
/// with a slow, calm opacity-pulse (the brand "breathing") and an optional
/// message. For whole-screen / whole-section waits where a logo reads better
/// than a bare spinner.
///
/// Use list **skeletons** for content placeholders; reach for this on a
/// full-screen gate (a route loader, a first paint). Strictly monochrome.
class OpsHubLoadingState extends StatefulWidget {
  const OpsHubLoadingState({super.key, this.message, this.logoHeight = 44});

  final String? message;
  final double logoHeight;

  @override
  State<OpsHubLoadingState> createState() => _OpsHubLoadingStateState();
}

class _OpsHubLoadingStateState extends State<OpsHubLoadingState>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat(reverse: true);

  late final Animation<double> _pulse =
      Tween<double>(begin: 0.35, end: 1.0).animate(
    CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FadeTransition(
            opacity: _pulse,
            child: OpsHubLogo(height: widget.logoHeight),
          ),
          if (widget.message != null) ...[
            const SizedBox(height: AppSpacing.lg),
            Text(
              widget.message!,
              style: AppTypography.caption.copyWith(color: AppColors.textTertiary),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }
}
