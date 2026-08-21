import 'package:flutter/material.dart';
import 'package:opshub/core/theme/app_colors.dart';
import 'package:opshub/core/theme/app_spacing.dart';
import 'package:opshub/core/theme/app_typography.dart';
import 'package:opshub/core/widgets/glass_container.dart';

/// **ActivityCard** — one clean, premium row in a vertical activity feed (DROP
/// Design System V2). The V2 replacement for the horizontal "spreadsheet" feed:
/// a `[leading] Title / subtitle …… trailing / meta` card the eye reads
/// top-to-bottom, not left-to-right across many columns.
///
/// Deliberately generic — leading avatar/glyph, a title, a supporting line, a
/// trailing status widget and a small meta line (e.g. relative time). Feature
/// code maps its entity onto these slots (a task → assignee glyph · title ·
/// "assignee · branch" · status pill · time), so the same card serves tasks,
/// requests, cases and any future module feed.
///
/// Built on [GlassContainer] for the shared press/hover feedback; exposes a
/// [Semantics] button label and never clips its title under text scaling.
class ActivityCard extends StatelessWidget {
  const ActivityCard({
    super.key,
    required this.title,
    this.leading,
    this.subtitle,
    this.subtitleIcon,
    this.trailing,
    this.meta,
    this.onTap,
    this.semanticLabel,
  });

  /// Optional leading visual (avatar / glyph chip).
  final Widget? leading;

  /// Primary line — the "what".
  final String title;

  /// Supporting line — the "who / where" (e.g. "Ahmed · Arkan branch").
  final String? subtitle;

  /// Optional leading glyph for [subtitle].
  final IconData? subtitleIcon;

  /// Trailing status widget (e.g. a `StatusBadge`).
  final Widget? trailing;

  /// Small trailing meta line under [trailing] (e.g. "5 min ago").
  final String? meta;

  final VoidCallback? onTap;

  /// Overrides the composed accessibility label when the slots alone would read
  /// awkwardly.
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final card = GlassContainer(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: 14,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (leading != null) ...[
            leading!,
            const SizedBox(width: AppSpacing.md),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.labelLarge.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (subtitle != null && subtitle!.trim().isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      if (subtitleIcon != null) ...[
                        Icon(
                          subtitleIcon,
                          size: 12,
                          color: AppColors.textQuaternary,
                        ),
                        const SizedBox(width: 4),
                      ],
                      Expanded(
                        child: Text(
                          subtitle!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.caption.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          if (trailing != null || meta != null) ...[
            const SizedBox(width: AppSpacing.md),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                ?trailing,
                if (meta != null) ...[
                  if (trailing != null) const SizedBox(height: 6),
                  // Relative timestamp = metadata → medium grey.
                  Text(
                    meta!,
                    style: AppTypography.caption.copyWith(
                      color: AppColors.textTertiary,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
    );

    if (semanticLabel == null) return card;
    return Semantics(button: onTap != null, label: semanticLabel, child: card);
  }
}
