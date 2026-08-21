import 'package:flutter/material.dart';
import 'package:opshub/core/theme/app_colors.dart';
import 'package:opshub/core/theme/app_radius.dart';
import 'package:opshub/core/theme/app_typography.dart';

/// Visual weight of a [PremiumButton].
enum PremiumButtonStyle {
  /// Solid white fill (the single strong CTA) — `onPrimary` text.
  filled,

  /// Tonal surface chip — the default for in-card actions.
  tonal,

  /// Borderless text + icon.
  ghost,
}

/// **PremiumButton** — the canonical **compact, inline** action button of the
/// DROP component system (label + optional icon, press-scale feedback). It fills
/// the niche previously served by ad-hoc per-card buttons (`TaskActionButton`,
/// the employee-home `_ActionButton`, …) so card actions share one button
/// instead of re-declaring `TextButton.styleFrom` everywhere.
///
/// This is **not** a duplicate of the full-width 56px form `AppButton` (used for
/// auth / primary screen CTAs) — it's the small action affordance for rows,
/// cards and sheets. Strictly monochrome; pass [tone] for a destructive accent
/// (e.g. `AppColors.error` on Delete).
class PremiumButton extends StatefulWidget {
  const PremiumButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.style = PremiumButtonStyle.tonal,
    this.tone,
    this.isLoading = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final PremiumButtonStyle style;

  /// The button's own action is in flight (a server round trip). The icon
  /// becomes a progress ring and taps are ignored, but the button keeps its
  /// **full** weight — dimming it would read as "disabled", i.e. as the app
  /// having dropped the tap, which is the exact impression this removes.
  final bool isLoading;

  /// Optional semantic accent (e.g. `AppColors.error` for destructive). Ignored
  /// for [PremiumButtonStyle.filled] (which is always the white CTA).
  final Color? tone;

  @override
  State<PremiumButton> createState() => _PremiumButtonState();
}

class _PremiumButtonState extends State<PremiumButton> {
  bool _pressed = false;

  void _set(bool v) {
    if (widget.onPressed != null && !widget.isLoading && mounted) {
      setState(() => _pressed = v);
    }
  }

  @override
  Widget build(BuildContext context) {
    // "Working" is not "disabled": a loading button stays at full weight and
    // full colour, and only refuses the tap.
    final disabled = widget.onPressed == null && !widget.isLoading;
    final filled = widget.style == PremiumButtonStyle.filled;
    final accent = widget.tone ?? AppColors.textPrimary;

    final Color bg;
    final Color border;
    final Color fg;
    switch (widget.style) {
      case PremiumButtonStyle.filled:
        bg = AppColors.primary;
        border = AppColors.primary;
        fg = AppColors.onPrimary;
      case PremiumButtonStyle.tonal:
        bg = AppColors.darkSurfaceElevated;
        border = widget.tone != null ? accent.withAlpha(70) : AppColors.darkBorder;
        fg = accent;
      case PremiumButtonStyle.ghost:
        bg = AppColors.transparent;
        border = AppColors.transparent;
        fg = accent;
    }

    final iconColor = disabled ? AppColors.textTertiary : fg;
    final content = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.icon != null || widget.isLoading) ...[
          // A fixed 16px slot, so the ring replaces the glyph without the pill
          // changing width — the swap is the only thing that moves.
          SizedBox.square(
            dimension: 16,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 140),
              child: widget.isLoading
                  ? CircularProgressIndicator(
                      key: const ValueKey('working'),
                      strokeWidth: 2,
                      color: iconColor,
                    )
                  : Icon(
                      widget.icon,
                      key: const ValueKey('icon'),
                      size: 16,
                      color: iconColor,
                    ),
            ),
          ),
          const SizedBox(width: 6),
        ],
        // Flexible so a long label ellipsizes instead of overflowing the pill.
        // The Row is `MainAxisSize.min`, so this is inert whenever the label
        // fits — it only engages once the parent is narrower than the natural
        // width, which previously painted overflow stripes (a long label in a
        // narrow Wrap at 390pt width did exactly that).
        Flexible(
          child: Text(
            widget.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.caption.copyWith(
              color: disabled ? AppColors.textTertiary : fg,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );

    return GestureDetector(
      onTapDown: (_) => _set(true),
      onTapUp: (_) => _set(false),
      onTapCancel: () => _set(false),
      onTap: widget.isLoading ? null : widget.onPressed,
      child: AnimatedScale(
        scale: _pressed ? 0.96 : 1.0,
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeOut,
        child: AnimatedOpacity(
          opacity: disabled ? 0.5 : 1.0,
          duration: const Duration(milliseconds: 150),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            decoration: BoxDecoration(
              color: filled && disabled ? AppColors.darkSurfaceElevated : bg,
              borderRadius: BorderRadius.circular(AppRadius.full),
              border: Border.all(color: border),
            ),
            child: content,
          ),
        ),
      ),
    );
  }
}
