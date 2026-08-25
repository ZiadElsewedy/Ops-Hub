import 'package:flutter/material.dart';

/// OpsHub color system — strictly **monochrome**: black, white and
/// neutral greys. There is **no chromatic brand color**; the "accent"
/// ([primary]) is white on the near-black UI, used for primary actions, focus
/// states, the active bottom-nav tab, and small highlights. The only colored
/// values are the semantic [success] / [error] / [warning], used for status.
///
/// Design language: Apple / Linear — clean neutral surfaces, no blue tint.
class AppColors {
  AppColors._();

  // ─── Accent (monochrome) ─────────────────────────────────────────────────
  // On the near-black UI the "accent" is white. Primary buttons/FABs use a
  // white fill with dark [onPrimary] text — there is no chromatic color.
  static const Color primary = Color(0xFFFFFFFF);
  static const Color primaryLight = Color(0xFFE5E5EA);
  static const Color primaryDark = Color(0xFFC7C7CC);

  /// Text/icon color that sits ON the accent fill (buttons, FABs, active chips).
  /// Dark, because the accent fill is white.
  static const Color onPrimary = Color(0xFF0A0A0B);

  /// Low-opacity white wash for tinted icon tiles, selected chips, the active
  /// bottom-nav pill, and rails.
  static const Color primarySurface = Color(0x1FFFFFFF); // white ~12%

  // ─── Accent (interactive emphasis) — MONOCHROME ──────────────────────────
  // Per the locked owner ruling the product is **strictly monochrome**: there
  // is no chromatic accent. These [accent]* tokens (kept for call-site
  // stability) now resolve to the white-on-black accent — the active navigation
  // destination, primary CTAs, focus rings, links and selection all read as
  // white / a low-opacity white wash, never indigo. Used sparingly so the
  // emphasis stays meaningful (Stripe/Linear restraint), never as decoration.
  static const Color accent = Color(0xFFFFFFFF); // white accent (was indigo)
  static const Color accentHover = Color(0xFFE5E5EA);
  static const Color accentPressed = Color(0xFFC7C7CC);

  /// Text/icon color that sits ON the white accent fill (dark, like [onPrimary]).
  static const Color onAccent = Color(0xFF0A0A0B);

  /// Low-opacity white wash for the active nav pill, selected rows and focus
  /// backgrounds.
  static const Color accentSurface = Color(0x1FFFFFFF); // white ~12%
  static const Color accentSurfaceStrong = Color(0x33FFFFFF); // white ~20%
  static const Color accentBorder = Color(0x4DFFFFFF); // white ~30%

  // Monochrome gradient (white → light grey) — used sparingly on the accent.
  static const Color gradientStart = Color(0xFFFFFFFF);
  static const Color gradientEnd = Color(0xFFE5E5EA);

  // ─── Dark theme — true neutral near-black ────────────────────────────────
  static const Color darkBg = Color(0xFF0A0A0B);
  static const Color darkSurface = Color(0xFF141416);
  static const Color darkSurfaceElevated = Color(0xFF1C1C20);
  static const Color darkBorder = Color(0xFF26262B);

  // ─── Light theme — clean neutral white ───────────────────────────────────
  static const Color lightBg = Color(0xFFFAFAFA);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightSurfaceElevated = Color(0xFFF4F4F5);
  static const Color lightBorder = Color(0xFFEAEAEC);

  // ─── Text — a four-step neutral ramp ─────────────────────────────────────
  // A deliberate brightness ladder so the eye instantly ranks importance
  // (Design System V2 hierarchy). Each step is clearly darker than the last —
  // no two levels share a brightness, so a title never competes with its
  // supporting text:
  //   textPrimary    — pure white       · titles, the "what"
  //   textSecondary  — light grey        · secondary information
  //   textTertiary   — medium grey       · supporting text, captions
  //   textQuaternary — dark grey         · disabled / least-important meta
  static const Color textPrimary = Color(0xFFFFFFFF); // dark-mode heading
  static const Color textSecondary = Color(0xFFA7A7AF); // light grey
  static const Color textTertiary = Color(0xFF6E6E77); // medium grey
  static const Color textQuaternary = Color(0xFF48484E); // disabled / faint meta
  static const Color textDark = Color(0xFF0A0A0B); // light-mode heading
  static const Color textDarkSecondary = Color(0xFF5C5C63);

  // ─── Semantic (used sparingly, only for status) ──────────────────────────
  static const Color success = Color(0xFF22C55E);
  static const Color successSurface = Color(0xFF0D2E1A);
  static const Color error = Color(0xFFEF4444);
  static const Color errorSurface = Color(0xFF2E0D0D);
  static const Color warning = Color(0xFFF59E0B);

  /// Soft, desaturated blue for **work in flight** (started). The fourth and
  /// final semantic colour — used only as a low-alpha hairline on a task card's
  /// edge, never as a fill, so the monochrome ruling (ADR-004) holds.
  static const Color info = Color(0xFF64A0FF);

  // ─── Sales accents — premium, muted, branch-sales surfaces only ───────────
  // A restrained three-tone accent layered over the monochrome base by owner
  // ruling (softens ADR-004 on the sales surfaces only, never app-wide). These
  // are deliberately *desaturated* — a refined emerald, a deep gold and a warm
  // coral, not the neon `success`/`warning`/`error` used for status chips. Used
  // for the progress ring, the percentage and the Achieved/Remaining/pace
  // figures so the sales screen reads as one premium palette.
  static const Color salesEmerald = Color(0xFF3FC29A); // achieved · progress
  static const Color salesEmeraldGlow = Color(0xFF7FE0C4); // arc gradient tip
  static const Color salesAmber = Color(0xFFCFA457); // remaining (not a warning)
  static const Color salesCoral = Color(0xFFDC6E62); // below-pace (softened red)

  // ─── Utility ─────────────────────────────────────────────────────────────
  static const Color white = Color(0xFFFFFFFF);
  static const Color black = Color(0xFF000000);
  static const Color transparent = Colors.transparent;

  // Monochrome white→grey gradient (used sparingly on the accent).
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [gradientStart, gradientEnd],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // Very low-opacity neutral wash for subtle premium surfaces.
  static const LinearGradient subtleGradient = LinearGradient(
    colors: [Color(0x14FFFFFF), Color(0x08FFFFFF)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// Accent "glow" helper — kept monochrome and **flat** (no halo): the white
  /// accent reads cleanest with no shadow, so this returns no shadow. Retained
  /// so call sites (buttons) keep a single, consistent shadow source.
  static List<BoxShadow> primaryGlow({double opacity = 0, double blur = 0}) =>
      const <BoxShadow>[];
}
