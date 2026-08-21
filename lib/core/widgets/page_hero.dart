import 'package:flutter/material.dart';
import 'package:opshub/core/theme/app_colors.dart';
import 'package:opshub/core/theme/app_spacing.dart';
import 'package:opshub/core/theme/app_typography.dart';

/// **PageHero** — the reusable header lockup that opens a module surface
/// (DROP Design System V2). An eyebrow (context/date), a strong title, an
/// optional subtitle line, an optional row of quiet [trailing] controls, and at
/// most **one** [primaryAction] — the single call-to-action the screen exists to
/// drive.
///
/// This is the V2 replacement for hand-rolled greeting rows. Every module home
/// (Admin, Branches, Requests, Cases, Communications, …) composes it so the
/// hero reads the same everywhere.
///
/// Responsive + accessible by construction: it collapses to a stacked layout
/// with a full-width primary action on narrow widths, marks itself a
/// [Semantics] header, and never clips under text scaling (the title block wraps
/// rather than ellipsizing the greeting).
class PageHero extends StatelessWidget {
  const PageHero({
    super.key,
    required this.title,
    this.eyebrow,
    this.subtitle,
    this.subtitleIcon,
    this.subtitleWidget,
    this.primaryAction,
    this.trailing = const <Widget>[],
    this.stackBelow = 640,
  });

  /// Uppercased, tracked context line (e.g. the date). Optional.
  final String? eyebrow;

  /// The headline (e.g. "Good morning, Ziad"). Rendered as [AppTypography.h1].
  final String title;

  /// A single supporting line under the title (e.g. "8 branches · 42 employees").
  final String? subtitle;

  /// Optional leading glyph for [subtitle].
  final IconData? subtitleIcon;

  /// Escape hatch for a richer subtitle (chips, live counts). Takes precedence
  /// over [subtitle]/[subtitleIcon] when provided.
  final Widget? subtitleWidget;

  /// The ONE primary action for this screen. Sits rightmost on wide layouts and
  /// full-width beneath the title block on narrow ones. Null for a headers-only
  /// hero.
  final Widget? primaryAction;

  /// Quiet secondary controls (sync, command hint, filters). Never compete with
  /// [primaryAction].
  final List<Widget> trailing;

  /// Below this width the hero stacks (title block → trailing → full-width CTA).
  final double stackBelow;

  Widget _titleBlock(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (eyebrow != null && eyebrow!.trim().isNotEmpty) ...[
          // The eyebrow is a date/context kicker (metadata) → medium grey, so it
          // reads a clear step below the white title and differs from the
          // light-grey subtitle beneath it.
          Text(
            eyebrow!.toUpperCase(),
            style: AppTypography.labelSmall.copyWith(
              color: AppColors.textTertiary,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
        ],
        Text(title, style: AppTypography.h1),
        if (subtitleWidget != null) ...[
          const SizedBox(height: AppSpacing.xs),
          subtitleWidget!,
        ] else if (subtitle != null && subtitle!.trim().isNotEmpty) ...[
          const SizedBox(height: AppSpacing.xs),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (subtitleIcon != null) ...[
                Padding(
                  padding: const EdgeInsets.only(top: 1.5),
                  child: Icon(
                    subtitleIcon,
                    size: 14,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(width: 6),
              ],
              Expanded(
                child: Text(
                  subtitle!,
                  style: AppTypography.caption.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      header: true,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final stacked = constraints.maxWidth < stackBelow;
          if (stacked) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: _titleBlock(context)),
                    if (trailing.isNotEmpty) ...[
                      const SizedBox(width: AppSpacing.sm),
                      ..._spaced(trailing),
                    ],
                  ],
                ),
                if (primaryAction != null) ...[
                  const SizedBox(height: AppSpacing.lg),
                  primaryAction!,
                ],
              ],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _titleBlock(context)),
              const SizedBox(width: AppSpacing.lg),
              ..._spaced(trailing),
              if (primaryAction != null) ...[
                if (trailing.isNotEmpty) const SizedBox(width: AppSpacing.sm),
                primaryAction!,
              ],
            ],
          );
        },
      ),
    );
  }

  /// Lay [widgets] out with a small gap between each.
  List<Widget> _spaced(List<Widget> widgets) {
    final out = <Widget>[];
    for (var i = 0; i < widgets.length; i++) {
      if (i > 0) out.add(const SizedBox(width: AppSpacing.sm));
      out.add(widgets[i]);
    }
    return out;
  }
}
