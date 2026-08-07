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
/// Honours the platform "reduce motion" setting: when animations are disabled
/// it shows the exact value with no roll.
class AnimatedCountText extends StatefulWidget {
  const AnimatedCountText({
    super.key,
    required this.value,
    required this.formatter,
    required this.style,
    this.duration = const Duration(milliseconds: 2600),
    this.curve = kPremiumSettle,
    this.textAlign,
    this.maxLines,
    this.overflow,
    this.animateOnMount = false,
    this.pulse = true,
    this.pulseAlignment = Alignment.centerLeft,
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

  /// Also **rise** into place: the figure scales up from small to full with a
  /// slight overshoot as it counts, so a change reads as a lively pop rather
  /// than a flat tick. The scale peaks at ~1.0, so it never overflows its box.
  final bool pulse;

  /// The anchor the rise scales about — keep it on the side the figure is
  /// aligned to (left for Achieved, right for Remaining) so it grows in place.
  final Alignment pulseAlignment;

  @override
  State<AnimatedCountText> createState() => _AnimatedCountTextState();
}

class _AnimatedCountTextState extends State<AnimatedCountText>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late num _from;
  late num _to;

  @override
  void initState() {
    super.initState();
    _from = widget.animateOnMount ? 0 : widget.value;
    _to = widget.value;
    _controller = AnimationController(vsync: this, duration: widget.duration);
    if (widget.animateOnMount && widget.value != 0) {
      _controller.forward();
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
      _controller
        ..duration = widget.duration
        ..forward(from: 0);
    }
  }

  num _liveValue() {
    final t = widget.curve.transform(_controller.value);
    return _from + (_to - _from) * t;
  }

  @override
  void dispose() {
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
        final text = _text(_liveValue());
        if (!widget.pulse) return text;
        // Rise from ~0.82 to 1.0 with a soft overshoot, and fade in from a low
        // opacity — the figure *materializes* into place rather than just
        // ticking. Anchored to the aligned edge so it never shifts or clips.
        final rise = Curves.easeOutBack.transform(_controller.value);
        final scale = 0.82 + 0.18 * rise;
        final opacity = (0.25 + 1.15 * Curves.easeOut.transform(_controller.value))
            .clamp(0.0, 1.0);
        return Opacity(
          opacity: opacity,
          child: Transform.scale(
            scale: scale,
            alignment: widget.pulseAlignment,
            child: text,
          ),
        );
      },
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
