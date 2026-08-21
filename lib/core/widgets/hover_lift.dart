import 'package:flutter/material.dart';
import 'package:opshub/core/theme/app_colors.dart';

/// Unified desktop hover response for cards and rows: a 1px rise plus a
/// whisper of depth, 150 ms. Wrap any card whose child doesn't manage its own
/// hover state — pointer feedback is what separates a desktop app from a
/// projected mobile screen. No-ops on touch (no hover events fire).
class HoverLift extends StatefulWidget {
  const HoverLift({
    super.key,
    required this.child,
    this.borderRadius,
    this.onTap,
  });

  final Widget child;
  final BorderRadius? borderRadius;

  /// Optional tap handler — when set the cursor becomes a click hand.
  final VoidCallback? onTap;

  @override
  State<HoverLift> createState() => _HoverLiftState();
}

class _HoverLiftState extends State<HoverLift> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    Widget result = MouseRegion(
      cursor: widget.onTap != null
          ? SystemMouseCursors.click
          : MouseCursor.defer,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOut,
        transform: Matrix4.translationValues(0, _hovered ? -1 : 0, 0),
        decoration: BoxDecoration(
          borderRadius: widget.borderRadius,
          boxShadow: _hovered
              ? [
                  BoxShadow(
                    color: AppColors.black.withAlpha(90),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: widget.child,
      ),
    );
    if (widget.onTap != null) {
      result = GestureDetector(onTap: widget.onTap, child: result);
    }
    return result;
  }
}
