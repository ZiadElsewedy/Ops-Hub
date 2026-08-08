import 'dart:async';

import 'package:flutter/material.dart';

/// The house count-up easing — `cubic-bezier(0.16, 1, 0.3, 1)`, a deep
/// "ease-out-expo" that leaps early then settles almost imperceptibly. The one
/// curve every rolling figure shares so the dashboard moves with one hand.
const Curve kPremiumSettle = Cubic(0.16, 1.0, 0.3, 1.0);

/// A number that **rolls** smoothly from its previous value to a new one
/// whenever [value] changes — the count-up you see when a sale lands or a
/// target is edited. [formatter] runs every frame, so grouping separators and
/// suffixes stay correct the whole way up (e.g. `98,500` → `155,000 EGP`).
///
/// On a *change* it rolls from wherever it currently is to the new value, so a
/// second edit mid-roll continues smoothly instead of snapping. With
/// [animateOnMount] it also counts up from zero the first time it appears — the
/// premium reveal when the dashboard finishes loading; leave it off for a
/// figure that should simply be present.
///
/// The motion is layered for a premium feel: as it counts, the figure **rises**
/// (scales up with a soft overshoot) and **brightens** (fades from dim to full),
/// so it *materializes* into place rather than ticking. A [delay] staggers the
/// start so a row of figures resolves as a cascade, and [shimmer] sweeps a band
/// of light across the figure as it settles.
///
/// Honours the platform "reduce motion" setting: when animations are disabled
/// it shows the exact value with no roll.
class AnimatedCountText extends StatefulWidget {
  const AnimatedCountText({
    super.key,
    required this.value,
    required this.formatter,
    required this.style,
    this.duration = const Duration(milliseconds: 3200),
    this.curve = kPremiumSettle,
    this.textAlign,
    this.maxLines,
    this.overflow,
    this.animateOnMount = false,
    this.pulse = true,
    this.pulseAlignment = Alignment.centerLeft,
    this.delay = Duration.zero,
    this.shimmer = false,
  });

  /// The target value. Ints or doubles both work; [formatter] decides how the
  /// interpolated (fractional) value is rendered — money formatters round it.
  final num value;

  /// Turns the live, possibly-fractional value into the string on screen.
  final String Function(num value) formatter;

  final TextStyle style;
  final Duration duration;
  final Curve curve;
  final TextAlign? textAlign;
  final int? maxLines;
  final TextOverflow? overflow;

  /// Count up from zero the first time the widget is shown (not just on change).
  final bool animateOnMount;

  /// Also **rise + brighten** into place: the figure scales up from small to
  /// full with a slight overshoot and fades from dim to full as it counts, so a
  /// change reads as a lively arrival rather than a flat tick. The scale peaks
  /// at ~1.0, so it never overflows its box.
  final bool pulse;

  /// The anchor the rise scales about — keep it on the side the figure is
  /// aligned to (left for Achieved, right for Remaining) so it grows in place.
  final Alignment pulseAlignment;

  /// Hold before the roll starts. Give the figures in a row increasing delays to
  /// make them resolve as a cascade instead of all at once. During the hold the
  /// figure sits in its dimmed start state, then charges up into the new value.
  final Duration delay;

  /// Sweep a band of light across the figure as it settles — most visible on a
  /// tinted (non-white) figure. Reserve it for the one hero number in a group.
  final bool shimmer;

  @override
  State<AnimatedCountText> createState() => _AnimatedCountTextState();
}

class _AnimatedCountTextState extends State<AnimatedCountText>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late num _from;
  late num _to;
  Timer? _delayTimer;

  @override
  void initState() {
    super.initState();
    _from = widget.animateOnMount ? 0 : widget.value;
    _to = widget.value;
    _controller = AnimationController(vsync: this, duration: widget.duration);
    if (widget.animateOnMount && widget.value != 0) {
      _start();
    } else {
      _controller.value = 1;
    }
  }

  @override
  void didUpdateWidget(AnimatedCountText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != _to) {
      // Roll from wherever we are right now so back-to-back changes stay smooth.
      _from = _liveValue();
      _to = widget.value;
      _controller.duration = widget.duration;
      _start();
    }
  }

  /// Drop to the dimmed start state, then (after [AnimatedCountText.delay]) run
  /// the roll. The hold leaves the figure sitting in its charge-up state so the
  /// cascade has no flash between waiting and animating.
  void _start() {
    _delayTimer?.cancel();
    _controller.value = 0;
    if (widget.delay == Duration.zero) {
      _controller.forward(from: 0);
      return;
    }
    _delayTimer = Timer(widget.delay, () {
      if (mounted) _controller.forward(from: 0);
    });
  }

  num _liveValue() {
    final t = widget.curve.transform(_controller.value);
    return _from + (_to - _from) * t;
  }

  @override
  void dispose() {
    _delayTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Respect "reduce motion": show the settled value, skip the roll.
    if (MediaQuery.maybeOf(context)?.disableAnimations ?? false) {
      return _text(widget.value);
    }
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        Widget out = _text(_liveValue());
        if (widget.shimmer) out = _shimmered(out);
        if (!widget.pulse) return out;
        // Rise from ~0.88 to 1.0 with a soft overshoot, and brighten from a dim
        // 0.4 to full — the figure materializes into place. During a stagger
        // hold the controller sits at 0, so the figure waits in this same dimmed
        // start state (no flash when the roll begins).
        final rise = Curves.easeOutBack.transform(_controller.value);
        final scale = 0.88 + 0.12 * rise;
        final opacity = (0.4 + 1.1 * Curves.easeOut.transform(_controller.value))
            .clamp(0.0, 1.0);
        return Opacity(
          opacity: opacity,
          child: Transform.scale(
            scale: scale,
            alignment: widget.pulseAlignment,
            child: out,
          ),
        );
      },
    );
  }

  /// A single band of light travelling left→right across the figure, driven by
  /// the roll's progress. At rest (progress 1) the band has left the frame, so
  /// the figure reads in its plain colour.
  Widget _shimmered(Widget child) {
    final base = widget.style.color ?? Colors.white;
    final highlight = Color.lerp(base, Colors.white, 0.9)!;
    return ShaderMask(
      blendMode: BlendMode.srcIn,
      shaderCallback: (rect) => LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: [base, highlight, base],
        stops: const [0.35, 0.5, 0.65],
        transform: _SweepTransform(_controller.value),
      ).createShader(rect),
      child: child,
    );
  }

  Text _text(num value) => Text(
    widget.formatter(value),
    style: widget.style,
    textAlign: widget.textAlign,
    maxLines: widget.maxLines,
    overflow: widget.overflow,
  );
}

/// Slides a gradient across its bounds as [t] goes 0→1: fully off the left edge
/// at 0, fully off the right at 1. Lets the shimmer band travel without touching
/// the gradient stops (so they never need clamping).
class _SweepTransform extends GradientTransform {
  const _SweepTransform(this.t);
  final double t;

  @override
  Matrix4 transform(Rect bounds, {TextDirection? textDirection}) {
    return Matrix4.translationValues((t * 2 - 1) * bounds.width, 0, 0);
  }
}
