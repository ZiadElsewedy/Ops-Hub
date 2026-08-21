import 'package:flutter/material.dart';
import 'package:opshub/core/theme/app_colors.dart';
import 'package:opshub/core/theme/app_radius.dart';
import 'package:opshub/core/theme/app_spacing.dart';
import 'package:opshub/core/theme/app_typography.dart';
import 'package:opshub/core/widgets/animated_count.dart';
import 'package:opshub/core/widgets/glass_container.dart';

/// **AttentionTile** — a priority triage cell for the "Needs Attention" layer
/// (DROP Design System V2). A soft-accent glyph, a big live [count], and a
/// label; tapping it opens the filtered view for that signal. This is the
/// generalisation of the old bespoke dashboard pending-action pills, built to be
/// reused by any module (tasks pending review, requests awaiting a decision,
/// active cases, …).
///
/// Calm by construction: it stays monochrome when the count is **zero** and only
/// picks up its semantic [accent] on the number/glyph when there is real work to
/// do — so a quiet dashboard reads quiet.
///
/// The tile is a pure core widget (the [borderRadius] matches its surface) so a
/// feature that wants the single most-urgent tile to carry the living-border
/// orbit can wrap it in `LiveStatusBorder(borderRadius: AttentionTile.radius, …)`
/// without this primitive depending on the task feature.
///
/// Accessibility: a [Semantics] button label ("N label"), a ≥44px tap target,
/// and it honours reduced-motion (`MediaQuery.disableAnimations`) by dropping the
/// count-up tween.
class AttentionTile extends StatelessWidget {
  const AttentionTile({
    super.key,
    required this.icon,
    required this.label,
    required this.count,
    required this.onTap,
    this.sublabel,
    this.accent,
    this.clearedMessage,
  });

  /// The tile's corner radius — exposed so a caller can match a wrapping
  /// `LiveStatusBorder` to the surface.
  static const BorderRadius radius = AppRadius.cardAll;

  final IconData icon;
  final String label;
  final int count;
  final VoidCallback onTap;

  /// Optional second line under the label (e.g. "Past the deadline").
  final String? sublabel;

  /// Semantic tint applied to the glyph + number **only when [count] > 0**
  /// (default [AppColors.warning]). Null falls back to warning.
  final Color? accent;

  /// The positive line shown **when [count] is zero** (e.g. "No overdue tasks",
  /// "Everything reviewed"). A cleared tile should reward the healthy state, not
  /// print a switched-off "0" — so instead of the big number it shows a check +
  /// this reassurance. Falls back to "All clear".
  final String? clearedMessage;

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    final active = count > 0;
    final tint = accent ?? AppColors.warning;
    final glyphTint = active ? tint : AppColors.textTertiary;

    return Semantics(
      button: true,
      label: active ? '$count $label' : '$label, all clear',
      child: GlassContainer(
        onTap: onTap,
        highlight: active,
        accent: tint,
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 116),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: glyphTint.withAlpha(active ? 34 : 18),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: active
                            ? glyphTint.withAlpha(60)
                            : AppColors.transparent,
                      ),
                    ),
                    child: Icon(icon, size: 21, color: glyphTint),
                  ),
                  const Spacer(),
                  // The top-right affordance: an "open me" arrow when there's
                  // work, a quiet check when the category is clear.
                  Icon(
                    active
                        ? Icons.arrow_outward_rounded
                        : Icons.check_rounded,
                    size: 18,
                    color: AppColors.textTertiary,
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              if (active)
                ..._active(reduceMotion)
              else
                ..._cleared(),
            ],
          ),
        ),
      ),
    );
  }

  /// The working state — the count is the metric (white), its label a supporting
  /// label (light grey), the sublabel helper text (medium grey): a clean 3-step
  /// ramp so the eye lands on the number first.
  List<Widget> _active(bool reduceMotion) => [
        AnimatedCount(
          value: count,
          duration: reduceMotion
              ? Duration.zero
              : const Duration(milliseconds: 650),
          style: AppTypography.display.copyWith(
            fontSize: 38,
            height: 1.0,
            letterSpacing: -1.2,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTypography.label.copyWith(
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w600,
          ),
        ),
        if (sublabel != null) ...[
          const SizedBox(height: 2),
          Text(
            sublabel!,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.caption.copyWith(
              color: AppColors.textTertiary,
            ),
          ),
        ],
      ];

  /// The cleared state — a positive, reassuring line in place of a bare "0", so
  /// a healthy board feels under control rather than switched off.
  List<Widget> _cleared() => [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.only(top: 1),
              child: Icon(
                Icons.check_circle_rounded,
                size: 22,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                clearedMessage ?? 'All clear',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.label.copyWith(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
                  height: 1.25,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTypography.caption.copyWith(
            color: AppColors.textQuaternary,
          ),
        ),
      ];
}
