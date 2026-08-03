import 'package:flutter/material.dart';
import 'package:drop/core/theme/app_colors.dart';
import 'package:drop/core/theme/app_spacing.dart';
import 'package:drop/core/theme/app_typography.dart';
import 'package:drop/core/widgets/glass_container.dart';

/// One row in a [DigestPanel] — a module's live headline figure and the door
/// into it.
class DigestEntry {
  const DigestEntry({
    required this.icon,
    required this.label,
    required this.onTap,
    this.value,
    this.accent,
  });

  final IconData icon;
  final String label;

  /// A ready-made string ("3", "2/5") — a digest reports, it doesn't count up;
  /// the counting-up numbers live in the attention panel and stat strip. Null
  /// for a row that is purely a **door** (no figure to report), which renders
  /// label + chevron rather than a placeholder dash.
  final String? value;

  final VoidCallback onTap;

  /// Semantic tint for the glyph chip. Null reads as inert medium grey — the
  /// calm default when this module has nothing outstanding.
  final Color? accent;
}

/// **DigestPanel** — the quiet "everything else, at a glance" layer of a DROP
/// dashboard (Design System V2): one grouped surface of module rows
/// (requests · cases · schedule · attendance), each a door rather than a
/// destination in the nav.
///
/// Deliberately *not* an attention layer: rows here report a number, they never
/// count up, pulse, or wear a living border. Anything that actually needs a
/// decision belongs in the `AttentionPanel` above it.
class DigestPanel extends StatelessWidget {
  const DigestPanel({super.key, required this.entries});

  final List<DigestEntry> entries;

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) return const SizedBox.shrink();
    return GlassContainer(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.xs,
      ),
      child: Column(
        children: [
          for (final (i, e) in entries.indexed) ...[
            if (i > 0) const Divider(color: AppColors.darkBorder, height: 1),
            _DigestRow(entry: e),
          ],
        ],
      ),
    );
  }
}

class _DigestRow extends StatelessWidget {
  const _DigestRow({required this.entry});

  final DigestEntry entry;

  @override
  Widget build(BuildContext context) {
    final accent = entry.accent ?? AppColors.textTertiary;
    return Semantics(
      button: true,
      label: [entry.value, entry.label].nonNulls.join(' '),
      child: InkWell(
        onTap: entry.onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: accent.withAlpha(28),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(entry.icon, size: 18, color: accent),
              ),
              const SizedBox(width: AppSpacing.md),
              // Row label is a supporting label (light grey); the value is the
              // metric and reads white when there's work to do.
              Expanded(
                child: Text(
                  entry.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.label.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              if (entry.value != null) ...[
                const SizedBox(width: AppSpacing.sm),
                Text(
                  entry.value!,
                  style: AppTypography.label.copyWith(
                    fontWeight: FontWeight.w700,
                    color: entry.accent == null
                        ? AppColors.textSecondary
                        : AppColors.textPrimary,
                  ),
                ),
              ],
              const SizedBox(width: AppSpacing.sm),
              // Decorative affordance → medium grey (a step below the label).
              const Icon(
                Icons.chevron_right_rounded,
                size: 20,
                color: AppColors.textTertiary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
