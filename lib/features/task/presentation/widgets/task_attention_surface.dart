import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:drop/core/enums/task_status.dart';
import 'package:drop/core/theme/app_colors.dart';
import 'package:drop/core/theme/app_radius.dart';

/// The **1px edge is the state**. One hairline per task status — soft,
/// desaturated, and completely still. Colour never shouts: it is read
/// peripherally while scanning a list, not looked at.
///
/// A `pending` task the viewer has never opened is the one exception: it gets
/// the white edge *and* the attention treatment in [TaskAttentionSurface]. The
/// moment it is opened or started, [unseen] goes false and it drops to the same
/// quiet hairline every other resting card wears.
Color taskAttentionTone(TaskStatus status, {required bool unseen}) {
  if (status == TaskStatus.pending) {
    // NEW — the only state that is ever brighter than its neighbours.
    return unseen ? AppColors.primary.withAlpha(77) : AppColors.darkBorder;
  }
  return switch (status) {
    TaskStatus.started => AppColors.info.withAlpha(82),
    TaskStatus.waitingReview => AppColors.warning.withAlpha(77),
    TaskStatus.approved || TaskStatus.completed => AppColors.success.withAlpha(77),
    TaskStatus.rejected || TaskStatus.missed => AppColors.error.withAlpha(77),
    // Neither success nor failure — never the error tint (spec §8).
    TaskStatus.cancelled => AppColors.textQuaternary,
    TaskStatus.pending => AppColors.darkBorder, // unreachable, kept exhaustive
  };
}

/// A premium, Apple-quiet **attention treatment** for a genuinely new task.
///
/// Four layers, three of them completely static, and one that moves so little
/// most people never consciously register it:
///
///  1. **Ambient light** — a barely-there white bloom around the card. Not a
///     glow; the card simply looks like it is sitting nearer the light.
///  2. **Bevel highlight** — white at 3% falling to nothing over the top ~46%
///     of the surface, so the top edge reads as *lit* rather than drawn.
///  3. **Specular edge** — the hairline itself varies along its length, peaking
///     near the top-left. Polished aluminium, not neon.
///  4. **Shimmer** — one slow pass of light across a *short section* of the top
///     edge, every 9 seconds. It never reaches a corner, which is precisely
///     what stops it reading as an orbit or a progress spinner.
///
/// Setting [attention] false eases all four to nothing in 200ms — perceptually
/// instant, without the harshness of a snap — and stops the 9s controller
/// outright, so a settled card costs nothing per frame.
///
/// Honours reduced motion by dropping layer 4 and keeping layers 1–3: the card
/// still reads as new, it simply never moves.
///
/// Performance: the shimmer drives a [CustomPainter] through `repaint` over a
/// child held in its own [RepaintBoundary]. **No per-frame widget rebuilds** —
/// the only rebuilds are the handful of frames inside a 200ms attention fade.
class TaskAttentionSurface extends StatefulWidget {
  const TaskAttentionSurface({
    super.key,
    required this.child,
    required this.tone,
    required this.attention,
    this.borderRadius = AppRadius.cardAll,
  });

  final Widget child;

  /// The per-state hairline colour — see [taskAttentionTone].
  final Color tone;

  /// Whether this card is a new, unacknowledged task. Only ever true for an
  /// unseen `pending` task.
  final bool attention;

  /// Must match the wrapped surface's radius so the edge rides its border.
  final BorderRadius borderRadius;

  @override
  State<TaskAttentionSurface> createState() => _TaskAttentionSurfaceState();
}

class _TaskAttentionSurfaceState extends State<TaskAttentionSurface>
    with TickerProviderStateMixin {
  /// One full shimmer cycle — the light travels for ~2.3s of this, then the
  /// edge is completely still until the cycle comes round again.
  static const _cycle = Duration(seconds: 9);

  /// Long enough not to snap, short enough to read as "gone the instant I
  /// touched it".
  static const _clear = Duration(milliseconds: 200);

  late final AnimationController _shimmer = AnimationController(
    vsync: this,
    duration: _cycle,
  );
  late final AnimationController _fade = AnimationController(
    vsync: this,
    duration: _clear,
    value: widget.attention ? 1 : 0,
  );

  bool _reduceMotion = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Reduced motion drops the shimmer entirely and keeps the three *static*
    // layers — the card is still legibly new, it just never moves. A shortened
    // sweep would be the wrong fallback: the objection is to the movement.
    _reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    _apply(animate: false);
  }

  @override
  void didUpdateWidget(TaskAttentionSurface old) {
    super.didUpdateWidget(old);
    if (widget.attention != old.attention) _apply();
  }

  /// Brings both controllers in line with [attention] + the reduced-motion
  /// setting. The 9s controller is **stopped**, not merely hidden, whenever the
  /// card is settled — a resting surface must cost nothing per frame.
  void _apply({bool animate = true}) {
    if (widget.attention && !_reduceMotion) {
      if (!_shimmer.isAnimating) _shimmer.repeat();
    } else {
      _shimmer.stop();
    }

    final target = widget.attention ? 1.0 : 0.0;
    if (!animate || _reduceMotion) {
      _fade.value = target;
    } else if (widget.attention) {
      _fade.forward();
    } else {
      _fade.reverse();
    }
  }

  @override
  void dispose() {
    _shimmer.dispose();
    _fade.dispose();
    super.dispose();
  }

  /// The white bloom. Nothing at all when settled — a resting card keeps
  /// exactly the (shadowless) surface it has always had.
  List<BoxShadow>? _ambient(double a) {
    if (a <= 0.001) return null;
    return [
      BoxShadow(
        color: AppColors.white.withAlpha((14 * a).round()),
        blurRadius: 26,
        spreadRadius: -6,
      ),
      BoxShadow(
        color: AppColors.white.withAlpha((9 * a).round()),
        blurRadius: 60,
        spreadRadius: -18,
      ),
    ];
  }

  /// Long enough to read as a transition, short enough that the card has
  /// settled before the action button finishing its own swap.
  static const _toneShift = Duration(milliseconds: 240);

  @override
  Widget build(BuildContext context) {
    // The painted edge + the card itself never rebuild — they are handed to the
    // AnimatedBuilder as a pre-built child.
    final surface = RepaintBoundary(
      child: _tonedPaint(
        child: ClipRRect(
          borderRadius: widget.borderRadius,
          child: Stack(
            children: [
              widget.child,
              Positioned.fill(
                child: IgnorePointer(
                  child: AnimatedBuilder(
                    animation: _fade,
                    builder: (context, _) => DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: _bevel(_fade.value),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    return AnimatedBuilder(
      animation: _fade,
      builder: (context, child) => DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: widget.borderRadius,
          boxShadow: _ambient(_fade.value),
        ),
        child: child,
      ),
      child: surface,
    );
  }

  /// The hairline **is** the state, so a state change must not cut it. The
  /// edge eases from the old tone to the new one over [_toneShift], in step
  /// with the card's action button swapping. Only the painter rebuilds during
  /// the shift — [child] is passed through untouched — and once settled the
  /// tween is idle, so a resting card still costs nothing per frame.
  Widget _tonedPaint({required Widget child}) => TweenAnimationBuilder<Color?>(
    tween: ColorTween(end: widget.tone),
    duration: _reduceMotion ? Duration.zero : _toneShift,
    curve: Curves.easeOut,
    child: child,
    builder: (context, tone, child) => CustomPaint(
      foregroundPainter: _EdgePainter(
        borderRadius: widget.borderRadius,
        tone: tone ?? widget.tone,
        attention: _fade,
        phase: _shimmer,
      ),
      child: child,
    ),
  );

  /// Light sitting on the top bevel — 3% at the very top, gone by 46% down.
  LinearGradient? _bevel(double a) {
    if (a <= 0.001) return null;
    return LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        AppColors.white.withAlpha((8 * a).round()),
        AppColors.white.withAlpha((3 * a).round()),
        AppColors.transparent,
      ],
      stops: const [0, 0.18, 0.46],
    );
  }
}

class _EdgePainter extends CustomPainter {
  _EdgePainter({
    required this.borderRadius,
    required this.tone,
    required this.attention,
    required this.phase,
  }) : super(repaint: Listenable.merge([attention, phase]));

  final BorderRadius borderRadius;
  final Color tone;
  final Animation<double> attention;
  final Animation<double> phase;

  /// The shimmer occupies only the first ~26% of the cycle; the rest of the
  /// nine seconds the edge is perfectly still.
  static const _travelWindow = 0.26;

  /// The section of the top edge the light crosses. Deliberately nowhere near a
  /// corner — that is what keeps it from reading as an orbit.
  static const _spanStart = 0.20;
  static const _spanEnd = 0.66;

  static double _envelope(double v) {
    if (v <= 0 || v >= _travelWindow) return 0;
    if (v < 0.08) return v / 0.08;
    if (v < 0.18) return 1;
    return (_travelWindow - v) / 0.08;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final rrect = borderRadius.toRRect(Offset.zero & size).deflate(0.5);

    // 1 · the hairline that IS the state.
    canvas.drawRRect(
      rrect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = tone,
    );

    final a = attention.value;
    if (a <= 0.001) return;

    // 2 · specular variation along the edge — brightest near the top-left,
    // falling to nothing across the body, with a faint catch on the far side.
    canvas.drawRRect(
      rrect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..shader = ui.Gradient.linear(
          Offset.zero,
          Offset(size.width, size.height),
          [
            AppColors.transparent,
            AppColors.white.withAlpha((66 * a).round()),
            AppColors.white.withAlpha((140 * a).round()),
            AppColors.white.withAlpha((36 * a).round()),
            AppColors.transparent,
            AppColors.transparent,
            AppColors.white.withAlpha((26 * a).round()),
            AppColors.transparent,
          ],
          const [0, 0.12, 0.21, 0.33, 0.52, 0.72, 0.88, 1],
        ),
    );

    // 3 · the shimmer.
    final p = phase.value;
    final op = _envelope(p) * a;
    if (op <= 0.001) return;

    final startX = size.width * _spanStart;
    final endX = size.width * _spanEnd;
    final span = endX - startX;
    final bandW = span * 0.46;
    final travel = Curves.easeInOutCubic.transform(
      (p / _travelWindow).clamp(0.0, 1.0),
    );
    final x = ui.lerpDouble(startX - bandW, endX + bandW, travel)!;

    canvas.save();
    canvas.clipRect(Rect.fromLTWH(startX, 0, span, 14));

    // A soft bloom travelling under the band — the light catching the surface,
    // not just the edge.
    canvas.drawRect(
      Rect.fromLTWH(x - bandW, 0, bandW * 2, 14),
      Paint()
        ..shader = ui.Gradient.radial(
          Offset(x, 0),
          bandW * 0.75,
          [
            AppColors.white.withAlpha((13 * op).round()),
            AppColors.transparent,
          ],
        ),
    );

    // The highlight itself, riding the 1px border line.
    canvas.drawLine(
      Offset(x - bandW, 0.5),
      Offset(x + bandW, 0.5),
      Paint()
        ..strokeWidth = 1
        ..shader = ui.Gradient.linear(
          Offset(x - bandW, 0),
          Offset(x + bandW, 0),
          [
            AppColors.transparent,
            AppColors.white.withAlpha((179 * op).round()),
            AppColors.transparent,
          ],
          const [0, 0.5, 1],
        ),
    );

    canvas.restore();
  }

  @override
  bool shouldRepaint(_EdgePainter old) =>
      old.tone != tone || old.borderRadius != borderRadius;
}
