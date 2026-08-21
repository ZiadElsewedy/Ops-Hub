import 'package:flutter/material.dart';
import 'package:opshub/core/theme/app_colors.dart';
import 'package:opshub/core/theme/app_radius.dart';
import 'package:opshub/core/theme/app_spacing.dart';

/// Reusable surface card: dark surface, large radius (24), light border, and
/// consistent padding — with an optional press-scale when [onTap] is provided.
/// The shared shell that task / employee / manager / branch cards can build on
/// so every card feels the same. Wrap your content; the card owns the chrome.
class AppCard extends StatefulWidget {
  const AppCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(AppSpacing.lg),
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;

  @override
  State<AppCard> createState() => _AppCardState();
}

class _AppCardState extends State<AppCard> {
  bool _pressed = false;
  bool _hovered = false;

  void _setPressed(bool v) {
    if (widget.onTap != null) setState(() => _pressed = v);
  }

  @override
  Widget build(BuildContext context) {
    final tappable = widget.onTap != null;
    final card = AnimatedScale(
      scale: _pressed ? 0.98 : 1.0,
      duration: const Duration(milliseconds: 100),
      curve: Curves.easeOut,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        padding: widget.padding,
        decoration: BoxDecoration(
          color: AppColors.darkSurface,
          borderRadius: AppRadius.xxlAll,
          // Subtle hover: the border brightens (no-op on touch devices).
          border: Border.all(
            color: _hovered ? AppColors.textTertiary : AppColors.darkBorder,
          ),
        ),
        child: widget.child,
      ),
    );
    if (!tappable) return card;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        onTapDown: (_) => _setPressed(true),
        onTapUp: (_) => _setPressed(false),
        onTapCancel: () => _setPressed(false),
        child: card,
      ),
    );
  }
}
