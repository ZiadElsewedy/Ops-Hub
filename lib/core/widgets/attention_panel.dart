import 'package:flutter/material.dart';
import 'package:drop/core/theme/app_colors.dart';
import 'package:drop/core/theme/app_radius.dart';
import 'package:drop/core/theme/app_spacing.dart';
import 'package:drop/core/theme/app_typography.dart';
import 'package:drop/core/widgets/animated_count.dart';
import 'package:drop/core/widgets/glass_container.dart';
import 'package:drop/core/widgets/live_list_item.dart';
import 'package:drop/core/widgets/live_status_border.dart';

/// One triage signal in an [AttentionPanel] — its live [count], semantic
/// [accent], glyph, copy, and the drill it opens. Callers pass signals in
/// **urgency order**; the panel keeps that order and never re-ranks them.
class AttentionSignal {
  const AttentionSignal({
    required this.id,
    required this.count,
    required this.accent,
    required this.icon,
    required this.label,
    required this.sublabel,
    required this.onTap,
  });

  /// Stable identity for keyed row reuse — a row must slide in, not re-mount,
  /// when a neighbouring signal clears.
  final String id;

  final int count;
  final Color accent;
  final IconData icon;

  /// The "what" (e.g. `Late`). Reads white.
  final String label;

  /// The one-line "so what" (e.g. `Past the deadline`). Reads medium grey.
  final String sublabel;

  final VoidCallback onTap;
}

/// **AttentionPanel** — the dominant "act on these first" layer of a DROP
/// dashboard (Design System V2), and the surface the Admin command center was
/// signed off on.
///
/// ONE grouped box that always sits in the same place:
/// * every queue empty → a calm **all-clear** summary (a success check, a
///   reassuring sentence, and the zeroed facts inline, so a healthy board reads
///   *under control* rather than merely blank);
/// * anything outstanding → the box of triage rows, most-urgent-first, each a
///   drill-down, with the cleared signals collapsed into a quiet footer.
///
/// A fresh signal slides in as a **row** rather than the whole surface
/// re-appearing, the box grows/shrinks smoothly, and a **single** living border
/// orbits the whole box (never one per row) reading the most-urgent signal's
/// tone. Every animation collapses under reduced motion.
class AttentionPanel extends StatelessWidget {
  const AttentionPanel({
    super.key,
    required this.signals,
    this.clearTitle = 'All clear',
    this.clearMessage = 'Nothing needs you right now — every queue is empty.',
  });

  /// Every signal this board watches, in urgency order (most urgent first).
  final List<AttentionSignal> signals;

  /// Headline of the all-clear state.
  final String clearTitle;

  /// Reassuring sentence under [clearTitle].
  final String clearMessage;

  /// The sum of every signal — the same total a hero's [DashboardMood] should
  /// switch off, so the sentence and this panel can never disagree.
  static int total(List<AttentionSignal> signals) =>
      signals.fold(0, (sum, s) => sum + s.count);

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    final active = signals.where((s) => s.count > 0).toList();

    final Widget child = active.isEmpty
        ? KeyedSubtree(
            key: const ValueKey('attn-clear'),
            child: _AllClearPanel(
              title: clearTitle,
              message: clearMessage,
              facts: signals,
            ),
          )
        : KeyedSubtree(
            key: const ValueKey('attn-active'),
            child: _box(context, active, reduceMotion),
          );

    if (reduceMotion) return child;
    // A quiet crossfade carries the rare clear ⇄ active flip.
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 260),
      switchInCurve: Curves.easeOut,
      switchOutCurve: Curves.easeIn,
      child: child,
    );
  }

  Widget _box(
    BuildContext context,
    List<AttentionSignal> active,
    bool reduceMotion,
  ) {
    final cleared = signals.where((s) => s.count == 0).toList();
    final overdueLead = active.first.accent == AppColors.error;

    final rows = <Widget>[
      for (final (i, s) in active.indexed)
        if (reduceMotion)
          KeyedSubtree(
            key: ValueKey('attn-row-${s.id}'),
            child: _Row(signal: s, first: i == 0),
          )
        else
          LiveListItem(
            key: ValueKey('attn-row-${s.id}'),
            entranceDelay: Duration(milliseconds: (i * 45).clamp(0, 180)),
            highlightRadius: 12,
            child: _Row(signal: s, first: i == 0),
          ),
    ];

    final box = GlassContainer(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Only the row set resizes when a signal arrives/clears, so the box
          // grows/shrinks smoothly instead of snapping.
          AnimatedSize(
            duration: reduceMotion
                ? Duration.zero
                : const Duration(milliseconds: 260),
            curve: Curves.easeOut,
            alignment: Alignment.topCenter,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: rows,
            ),
          ),
          if (cleared.isNotEmpty) _footer(cleared),
        ],
      ),
    );

    if (reduceMotion) return box;
    // One unified orbit around the whole box (not one per row), reading the
    // most-urgent signal's tone.
    return LiveStatusBorder(
      color: overdueLead ? const Color(0xFFFB923C) : kLivingBorderAccent,
      pulse: overdueLead,
      speed: 1.1,
      borderRadius: AppRadius.cardAll,
      child: box,
    );
  }

  /// The quiet footer naming the cleared signals ("sent back · unassigned —
  /// all clear"), so a healthy queue is visible without a row of empty tiles.
  Widget _footer(List<AttentionSignal> cleared) {
    final names = cleared.map((s) => s.label.toLowerCase()).join(' · ');
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Divider(
          height: 1,
          thickness: 1,
          color: AppColors.darkBorder,
          indent: AppSpacing.md,
          endIndent: AppSpacing.md,
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.md, 10, AppSpacing.md, 8),
          child: Row(
            children: [
              const Icon(
                Icons.check_rounded,
                size: 15,
                color: AppColors.textTertiary,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  '$names — all clear',
                  // Two lines: with four or five cleared signals this footer is
                  // long, and truncating it to "…swap requests — a…" hides the
                  // very word that makes it reassuring.
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.caption.copyWith(
                    color: AppColors.textTertiary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// One triage row inside the grouped box: tinted glyph · label + sublabel ·
/// count (counts up) · chevron. Tapping drills to that signal's filtered view.
class _Row extends StatelessWidget {
  const _Row({required this.signal, required this.first});

  final AttentionSignal signal;
  final bool first;

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (!first)
          const Divider(
            height: 1,
            thickness: 1,
            color: AppColors.darkBorder,
            indent: AppSpacing.md,
            endIndent: AppSpacing.md,
          ),
        Semantics(
          button: true,
          label: '${signal.count} ${signal.label}',
          child: InkWell(
            onTap: signal.onTap,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: 12,
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: signal.accent.withAlpha(34),
                      borderRadius: BorderRadius.circular(11),
                      border: Border.all(color: signal.accent.withAlpha(60)),
                    ),
                    child: Icon(signal.icon, size: 20, color: signal.accent),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Row title reads white (the "what"); its sublabel steps
                        // down to medium grey.
                        Text(
                          signal.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.label.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 1),
                        Text(
                          signal.sublabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.caption.copyWith(
                            color: AppColors.textTertiary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  AnimatedCount(
                    value: signal.count,
                    duration: reduceMotion
                        ? Duration.zero
                        : const Duration(milliseconds: 650),
                    style: AppTypography.h2.copyWith(
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.5,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  const Icon(
                    Icons.chevron_right_rounded,
                    size: 20,
                    color: AppColors.textTertiary,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// The attention layer when **every** queue is empty — one reassuring summary
/// instead of a grid of switched-off tiles. A large success check, a positive
/// sentence, and a muted inline row of the zeroed facts, so a healthy board
/// reads *under control* rather than like a failed load.
class _AllClearPanel extends StatelessWidget {
  const _AllClearPanel({
    required this.title,
    required this.message,
    required this.facts,
  });

  final String title;
  final String message;
  final List<AttentionSignal> facts;

  @override
  Widget build(BuildContext context) {
    // Derived, never hardcoded: the zeroed facts are exactly the signals this
    // board watches, so the proof line can't drift from the panel above it.
    final zeroes = facts.map((s) => '0 ${s.label.toLowerCase()}').join(' · ');
    return Semantics(
      label: '$title. $message',
      child: GlassContainer(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // A large, calm success check — the board's own state is "healthy",
            // the one place a status colour earns its place on this screen.
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: AppColors.success.withAlpha(28),
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: AppColors.success.withAlpha(60)),
              ),
              child: const Icon(
                Icons.check_rounded,
                size: 28,
                color: AppColors.success,
              ),
            ),
            const SizedBox(width: AppSpacing.lg),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(title, style: AppTypography.h3),
                  const SizedBox(height: 3),
                  // Reassuring sentence → light grey, a clear step under the title.
                  Text(
                    message,
                    style: AppTypography.body.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  if (zeroes.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.md),
                    // The zeroed facts, quiet and inline (medium grey) — proof
                    // the calm state is real, not a failed load.
                    Text(
                      zeroes,
                      style: AppTypography.caption.copyWith(
                        color: AppColors.textTertiary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
