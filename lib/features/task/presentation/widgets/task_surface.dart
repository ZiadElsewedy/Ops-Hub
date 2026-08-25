import 'package:flutter/material.dart';
import 'package:opshub/core/theme/app_colors.dart';

/// The **single source** of the de-flashed task surface (2026-06-25 ruling —
/// *premium ≠ flashy*). A flat solid surface with a hairline border and a
/// *whisper* of depth: **no gradient, no glow, no pulse.**
///
/// Deliberately **distinct** from the shared `GlassContainer` / `AppGlassCard`
/// (richer gradient + depth) and intentionally **scoped to task surfaces only**,
/// so the calmer language can be validated in use before any global change. It
/// lives here — defined once — precisely to avoid the duplication / design-system
/// fragmentation of re-declaring the same `BoxDecoration` in every task card and
/// header. If we later decide to globalise this look, **this is the one place to
/// promote** (into the design system, or by folding `GlassContainer` toward it).
///
/// **Keep this intentionally minimal** (owner constraint): it is a single fixed
/// treatment, not a second generalized surface system. Resist adding
/// variants / options / flags — if a richer surface is needed, promote to the
/// shared design system rather than growing `TaskSurface` here.
class TaskSurface extends StatelessWidget {
  const TaskSurface({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.borderRadius = const BorderRadius.all(Radius.circular(14)),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final BorderRadius borderRadius;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: AppColors.darkSurface,
        borderRadius: borderRadius,
        border: Border.all(color: AppColors.darkBorder),
        boxShadow: [
          BoxShadow(
            color: AppColors.black.withAlpha(115),
            blurRadius: 3,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: child,
    );
  }
}
