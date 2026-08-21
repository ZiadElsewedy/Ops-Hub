import 'package:flutter/material.dart';
import 'package:drop/core/theme/app_colors.dart';

/// **EmptyStateMedallion** — the shared "nothing here" mark.
///
/// One crafted object instead of a bare grey glyph: a soft radial halo, two
/// concentric hairlines, and a gently lit disc holding the glyph or the brand
/// mark. It is the difference between a screen that looks *unfinished* and one
/// that looks *finished and quiet* — which is what an empty state actually is.
///
/// Strictly monochrome, per the owner-locked stance: the craft comes from
/// light, radius and hairline weight, never from colour.
///
/// Both [AppEmptyState] (glyph-led) and [OpsHubEmptyState] (brand-led) render
/// their mark through this, so every empty surface in the app shares one
/// silhouette. [size] shrinks the whole assembly proportionally for in-card
/// use, where a full-page medallion would overwhelm the card.
class EmptyStateMedallion extends StatelessWidget {
  const EmptyStateMedallion({
    super.key,
    required this.child,
    this.size = 104,
    this.tone,
  });

  /// The glyph or brand mark at the centre. Sized by the caller.
  final Widget child;

  /// Outer diameter of the halo. The rings and disc scale from it.
  final double size;

  /// Optional semantic tint for the halo and rings. Left null the medallion is
  /// pure monochrome, which is the default and the right choice for "nothing
  /// here". A failure passes `AppColors.error` so the same silhouette reads as
  /// *wrong* at a glance — status colour expressing status, per ADR-004. The
  /// glyph's own colour stays the caller's business.
  final Color? tone;

  @override
  Widget build(BuildContext context) {
    final ringOuter = size * 0.78;
    final disc = size * 0.52;
    final accent = tone ?? AppColors.textPrimary;

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Halo — a barely-there bloom that lifts the mark off the page
          // without introducing a second surface colour.
          DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  accent.withValues(alpha: tone == null ? 0.05 : 0.10),
                  accent.withValues(alpha: tone == null ? 0.015 : 0.03),
                  AppColors.transparent,
                ],
                stops: const [0, 0.55, 1],
              ),
            ),
            child: SizedBox(width: size, height: size),
          ),

          // Outer hairline — the widest, faintest ring.
          _Ring(
            diameter: ringOuter,
            color: accent.withValues(alpha: tone == null ? 0.05 : 0.14),
          ),

          // Inner hairline, drawn just off the disc edge so the two read as
          // deliberate concentric craft rather than one thick border.
          _Ring(
            diameter: disc + 14,
            color: accent.withValues(alpha: tone == null ? 0.08 : 0.24),
          ),

          // The lit disc. A top-down gradient reads as a light source above,
          // which is what makes it feel like an object instead of a circle.
          Container(
            width: disc,
            height: disc,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  AppColors.darkSurfaceElevated,
                  AppColors.darkSurface,
                ],
              ),
              border: Border.all(
                color: accent.withValues(alpha: tone == null ? 0.09 : 0.28),
              ),
            ),
            alignment: Alignment.center,
            child: child,
          ),
        ],
      ),
    );
  }
}

class _Ring extends StatelessWidget {
  const _Ring({required this.diameter, required this.color});

  final double diameter;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: diameter,
      height: diameter,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: color),
      ),
    );
  }
}
