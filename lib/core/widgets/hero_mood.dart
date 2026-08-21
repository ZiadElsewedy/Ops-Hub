import 'package:flutter/material.dart';
import 'package:opshub/core/theme/app_colors.dart';
import 'package:opshub/core/theme/app_spacing.dart';
import 'package:opshub/core/theme/app_typography.dart';
import 'package:opshub/core/utils/dashboard_mood.dart';

/// **HeroMood** — a dashboard hero's contextual subtitle (DROP Design System
/// V2): a breathing "system live" pulse dot, the [DashboardMood] sentence
/// (white + bold when it wants the eye, a relaxed light grey when the board is
/// calm), and the quiet operational [scope] beneath it.
///
/// Pass it to `PageHero.subtitleWidget`. Both the sentence and the surface's
/// Needs-attention layer switch off the **same** total, so they can never
/// disagree.
class HeroMood extends StatelessWidget {
  const HeroMood({super.key, required this.mood, required this.scope});

  final DashboardMood mood;

  /// The quiet second line — who/where this board covers (e.g.
  /// "8 branches · 42 employees · 2 running"). Pass an **empty string** when the
  /// hero's eyebrow already carries the scope: a single-branch board has so
  /// little of it that a whole second line is text for its own sake, and the
  /// line is then omitted rather than rendered blank.
  final String scope;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            _LivePulseDot(color: mood.pulseColor),
            const SizedBox(width: AppSpacing.sm),
            Flexible(
              child: Text(
                mood.headline,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.body.copyWith(
                  color: mood.emphasised
                      ? AppColors.textPrimary
                      : AppColors.textSecondary,
                  fontWeight: mood.emphasised
                      ? FontWeight.w600
                      : FontWeight.w500,
                  height: 1.2,
                ),
              ),
            ),
          ],
        ),
        if (scope.trim().isNotEmpty) ...[
          const SizedBox(height: 3),
          Text(
            scope,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.caption.copyWith(color: AppColors.textTertiary),
          ),
        ],
      ],
    );
  }
}

/// A small "the system is alive" indicator — a solid dot with a soft halo and a
/// slow expanding ring that fades outward (like a live/heartbeat pin). The ring
/// is purely reassuring motion; under reduced motion it collapses to a static
/// glowing dot so it never distracts or spins forever for no reason.
class _LivePulseDot extends StatefulWidget {
  const _LivePulseDot({required this.color});

  final Color color;

  @override
  State<_LivePulseDot> createState() => _LivePulseDotState();
}

class _LivePulseDotState extends State<_LivePulseDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2400),
  );
  bool _animating = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduce = MediaQuery.of(context).disableAnimations;
    if (!reduce && !_animating) {
      _animating = true;
      _c.repeat();
    } else if (reduce && _animating) {
      _animating = false;
      _c.stop();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  static const double _core = 8;

  Widget _dot() => Container(
    width: _core,
    height: _core,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: widget.color,
      boxShadow: [BoxShadow(color: widget.color.withAlpha(120), blurRadius: 6)],
    ),
  );

  @override
  Widget build(BuildContext context) {
    if (!_animating) return _dot();
    // Isolate the forever-running ring in its own layer so each frame repaints
    // only this 18px box, never the hero around it.
    return RepaintBoundary(
      child: SizedBox(
        width: 18,
        height: 18,
        child: AnimatedBuilder(
          animation: _c,
          builder: (context, _) {
            final t = Curves.easeOut.transform(_c.value);
            final ringSize = _core * (1 + t * 1.1);
            final ringAlpha = ((1 - t) * 80).round();
            return Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: ringSize,
                  height: ringSize,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: widget.color.withAlpha(ringAlpha),
                  ),
                ),
                _dot(),
              ],
            );
          },
        ),
      ),
    );
  }
}
