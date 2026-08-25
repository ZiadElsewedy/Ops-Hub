import 'package:flutter/material.dart';
import 'package:opshub/core/theme/app_colors.dart';

/// A lightweight shimmering placeholder block for loading states.
/// No external package — uses a single looping gradient sweep.
class Skeleton extends StatefulWidget {
  final double width;
  final double height;
  final BorderRadius borderRadius;
  final bool circle;

  const Skeleton({
    super.key,
    this.width = double.infinity,
    this.height = 16,
    this.borderRadius = const BorderRadius.all(Radius.circular(8)),
    this.circle = false,
  });

  @override
  State<Skeleton> createState() => _SkeletonState();
}

/// The crest of the sweep — the elevated surface lifted toward white. Kept as a
/// single constant so every skeleton in the app shimmers at the same intensity.
final Color _highlight =
    Color.alphaBlend(AppColors.textPrimary.withValues(alpha: 0.07),
        AppColors.darkSurfaceElevated);

class _SkeletonState extends State<Skeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            shape: widget.circle ? BoxShape.circle : BoxShape.rectangle,
            borderRadius: widget.circle ? null : widget.borderRadius,
            // The old sweep ran darkSurface → darkSurfaceElevated, a 6-value
            // step that was invisible on a card already painted darkSurface —
            // the "loading" state looked like a dead grey slab. The block now
            // rests one surface above its card and the sweep carries a real
            // highlight, so the shimmer is legible while staying calm.
            gradient: LinearGradient(
              begin: Alignment(-1 - 2 * _controller.value, 0),
              end: Alignment(1 - 2 * _controller.value, 0),
              colors: [
                AppColors.darkSurfaceElevated,
                _highlight,
                AppColors.darkSurfaceElevated,
              ],
              stops: const [0.3, 0.5, 0.7],
            ),
          ),
        );
      },
    );
  }
}
