import 'dart:async';

import 'package:flutter/material.dart';

/// The reel easing — a fast leap that decelerates to a **clean, precise stop**
/// with no overshoot or bounce, so a rolling digit settles mechanically on its
/// value. Deliberately not the count-up `kPremiumSettle`: a reel wants energy up
/// front and a hard, exact landing, not a long imperceptible tail.
const Curve kReelSettle = Cubic(0.19, 0.91, 0.28, 1.0);

/// A single **slot-machine / odometer reel** for one decimal digit `0..9`.
///
/// The reel is an infinite vertical strip of glyphs; the widget tracks a
/// `double` **position** whose whole part (mod 10) is the digit on screen and
/// whose fractional part is the scroll between two glyphs. On a change it rolls
/// **forward** (always upward, never reversing) to the next position congruent
/// to the new digit, so `9 → 0` spins up through the wrap exactly like a real
/// mechanical wheel. Only two glyphs are ever laid out (the one leaving and the
/// one arriving), and only their vertical offset animates — no opacity, no
/// scale, no whole-number rebuilds — so a row of these stays cheap and jank-free.
///
/// Compose these with [RollingNumber]; use one directly only for a lone digit.
class RollingDigit extends StatefulWidget {
  const RollingDigit({
    super.key,
    required this.digit,
    required this.style,
    this.duration = const Duration(milliseconds: 640),
    this.curve = kReelSettle,
    this.animateOnMount = true,
    this.delay = Duration.zero,
    this.extraTurns = 0,
  }) : assert(digit >= 0 && digit <= 9),
       assert(extraTurns >= 0);

  final int digit;
  final TextStyle style;
  final Duration duration;
  final Curve curve;

  /// Full `0→9` rotations the wheel spins *before* landing on [digit] — the
  /// slot-machine flourish. `0` rolls the shortest way; higher values spin the
  /// reel harder. The landing digit is unaffected, so the value stays exact.
  final int extraTurns;

  /// Roll up from `0` the first time the reel appears (a fresh leading digit, or
  /// the whole number's mount reveal). Off makes the digit simply present.
  final bool animateOnMount;

  /// Hold before this reel starts — used by [RollingNumber] to stagger a figure
  /// as one unit, not to stagger digits against each other.
  final Duration delay;

  @override
  State<RollingDigit> createState() => _RollingDigitState();
}

class _RollingDigitState extends State<RollingDigit>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  /// Reel position in glyph units — whole part (mod 10) is the visible digit.
  /// Monotonically increasing across a widget's life so motion never reverses.
  double _from = 0;
  double _to = 0;
  Timer? _delayTimer;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);
    if (widget.animateOnMount) {
      _from = 0;
      _to = _forwardFrom(0, widget.digit);
      _run();
    } else {
      _to = widget.digit.toDouble();
      _from = _to;
      _controller.value = 1;
    }
  }

  /// The position the wheel rolls *forward* to in order to show [digit] next:
  /// the smallest value `>= from` congruent to [digit] mod 10, plus any
  /// [RollingDigit.extraTurns] full rotations of flourish on top.
  double _forwardFrom(double from, int digit) {
    final current = ((from.round() % 10) + 10) % 10;
    final delta = ((digit - current) % 10 + 10) % 10;
    return from + delta + widget.extraTurns * 10;
  }

  @override
  void didUpdateWidget(RollingDigit old) {
    super.didUpdateWidget(old);
    if (widget.duration != old.duration) _controller.duration = widget.duration;
    if (widget.digit != old.digit) {
      // Continue forward from the previous *resting* target, but start the tween
      // from wherever we visually are so an interrupted roll stays smooth.
      _from = _live();
      _to = _forwardFrom(_to, widget.digit);
      _run();
    }
  }

  void _run() {
    _delayTimer?.cancel();
    _controller.value = 0;
    if (widget.delay == Duration.zero) {
      _controller.forward(from: 0);
    } else {
      _delayTimer = Timer(widget.delay, () {
        if (mounted) _controller.forward(from: 0);
      });
    }
  }

  double _live() =>
      _from + (_to - _from) * widget.curve.transform(_controller.value);

  @override
  void dispose() {
    _delayTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.maybeOf(context);
    final scaler = media?.textScaler ?? TextScaler.noScaling;
    final style = _tabular(widget.style);
    final cell = _measure(style, scaler);

    // Respect "reduce motion": render the exact digit, no reel.
    if (media?.disableAnimations ?? false) {
      return SizedBox.fromSize(
        size: cell,
        child: _glyph(widget.digit, style, scaler),
      );
    }

    return RepaintBoundary(
      child: SizedBox(
        width: cell.width,
        height: cell.height,
        child: ClipRect(
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              final p = _live();
              final base = p.floor();
              final frac = p - base;
              return Stack(
                clipBehavior: Clip.hardEdge,
                children: [
                  for (var k = 0; k <= 1; k++)
                    Positioned(
                      left: 0,
                      right: 0,
                      top: (k - frac) * cell.height,
                      child: _glyph(((base + k) % 10 + 10) % 10, style, scaler),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _glyph(int d, TextStyle style, TextScaler scaler) => Text(
    '$d',
    style: style,
    textScaler: scaler,
    textAlign: TextAlign.center,
    maxLines: 1,
    softWrap: false,
  );

  Size _measure(TextStyle style, TextScaler scaler) {
    final painter = TextPainter(
      text: TextSpan(text: '0', style: style),
      textDirection: Directionality.maybeOf(context) ?? TextDirection.ltr,
      textScaler: scaler,
      maxLines: 1,
    )..layout();
    // The exact line box: taller than the digit ink (there is leading above and
    // below), so clipping to it never shaves the glyph, and it matches a plain
    // separator [Text] of the same style so digits and commas share a baseline.
    return Size(painter.width, painter.height);
  }

  /// Tabular figures keep every digit the same width, so the row cannot jitter
  /// horizontally as reels land on different numbers.
  TextStyle _tabular(TextStyle style) {
    final hasTabular =
        style.fontFeatures?.any((f) => f.feature == 'tnum') ?? false;
    if (hasTabular) return style;
    return style.copyWith(
      fontFeatures: [
        ...?style.fontFeatures,
        const FontFeature.tabularFigures(),
      ],
    );
  }
}

/// A **rolling number** — a formatted figure whose digits are independent
/// [RollingDigit] reels, so `111,531` transitions toward `112,000` by each digit
/// wheel spinning to its new value while the commas and decimal point stay put.
///
/// The number stays exact and readable throughout: [formatter] runs **once** on
/// the final [value] to decide the target string, then digits are keyed by their
/// **place value** (units, tens, … and tenths, hundredths) so a given wheel
/// persists across changes and merely rolls. Growing past a thousands boundary
/// makes a new leading wheel roll in from `0`; shrinking retires it. There is no
/// opacity, scale, or per-frame string formatting — only vertical offset moves.
///
/// Reels settle **left → right** (higher places finish first, the units wheel
/// last) for a mechanical "reel stopping" feel, the whole figure landing inside
/// ~[duration]+[maxExtra]. Honours "reduce motion" by showing the value flat.
class RollingNumber extends StatefulWidget {
  const RollingNumber({
    super.key,
    required this.value,
    required this.formatter,
    required this.style,
    this.duration = const Duration(milliseconds: 2000),
    this.perPlaceStep = const Duration(milliseconds: 120),
    this.maxExtra = const Duration(milliseconds: 900),
    this.baseTurns = 1,
    this.maxTurns = 4,
    this.curve = kReelSettle,
    this.animateOnMount = true,
    this.delay = Duration.zero,
  });

  /// The exact underlying value. Int or double — [formatter] renders the final
  /// string; digits animate toward it and settle precisely on it.
  final num value;
  final String Function(num value) formatter;
  final TextStyle style;

  /// Base roll time for the fastest (left-most) wheel. Each place to its right
  /// adds [perPlaceStep], capped at +[maxExtra], so the figure settles L→R and
  /// stays inside roughly `duration + maxExtra` (~2.0–2.9 s at the defaults).
  final Duration duration;
  final Duration perPlaceStep;
  final Duration maxExtra;

  /// Slot-machine flourish: the left-most wheel spins [baseTurns] full rotations
  /// before landing, and each pair of places to the right adds one more, capped
  /// at [maxTurns]. Higher = livelier reels. The landing value is never affected.
  final int baseTurns;
  final int maxTurns;
  final Curve curve;

  /// Roll every wheel up from `0` on first appearance (the mount reveal).
  final bool animateOnMount;

  /// Hold the whole figure before it rolls — stagger figures in a row against
  /// each other by giving each an increasing delay.
  final Duration delay;

  @override
  State<RollingNumber> createState() => _RollingNumberState();
}

class _RollingNumberState extends State<RollingNumber> {
  bool _firstBuild = true;

  @override
  Widget build(BuildContext context) {
    final firstBuild = _firstBuild;
    _firstBuild = false;

    final tokens = _parse(widget.formatter(widget.value));
    final children = <Widget>[];
    var digitIndex = 0; // 0 for the left-most digit, increasing rightward

    for (final token in tokens) {
      if (token.isDigit) {
        // Left-most wheel is quickest; each step right lands a touch later, and
        // spins a little harder — so the figure settles left→right like a reel.
        final extra = widget.perPlaceStep * digitIndex;
        final capped = extra > widget.maxExtra ? widget.maxExtra : extra;
        final turns = widget.baseTurns + (digitIndex ~/ 2);
        children.add(
          RollingDigit(
            key: ValueKey('d${token.place}'),
            digit: token.value,
            style: widget.style,
            duration: widget.duration + capped,
            curve: widget.curve,
            extraTurns: turns > widget.maxTurns ? widget.maxTurns : turns,
            // On first build honour the caller; wheels that appear *later*
            // (the number grew) always roll in from 0, promptly.
            animateOnMount: firstBuild ? widget.animateOnMount : true,
            delay: firstBuild ? widget.delay : Duration.zero,
          ),
        );
        digitIndex++;
      } else {
        children.add(
          _Static(
            token.char,
            widget.style,
            // Comma keyed by the place on its right so it stays stable as the
            // number grows; the decimal point is unique.
            key: ValueKey(token.char == '.' ? 'dot' : 'sep${token.place}'),
          ),
        );
      }
    }

    final row = Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: children,
    );

    final prefix = tokens.isEmpty ? '' : tokens.first.prefix;
    final suffix = tokens.isEmpty ? '' : tokens.last.suffix;
    if (prefix.isEmpty && suffix.isEmpty) return row;
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (prefix.isNotEmpty) _Static(prefix, widget.style),
        row,
        if (suffix.isNotEmpty) _Static(suffix, widget.style),
      ],
    );
  }

  /// Splits the formatted string into a leading non-digit prefix (e.g. `-`), a
  /// trailing non-digit suffix (e.g. ` EGP`, `%`), and the numeric core, then
  /// tags each core digit with its place value so reels stay identity-stable.
  List<_Token> _parse(String text) {
    var start = 0;
    var end = text.length;
    while (start < end && !_isDigit(text.codeUnitAt(start))) {
      start++;
    }
    while (end > start && !_isDigit(text.codeUnitAt(end - 1))) {
      end--;
    }
    if (start >= end) return const [];

    final prefix = text.substring(0, start);
    final suffix = text.substring(end);
    final core = text.substring(start, end);

    final dot = core.indexOf('.');
    final intEnd = dot == -1 ? core.length : dot;
    final intDigits = _digitCount(core, 0, intEnd);

    final tokens = <_Token>[];
    var seenIntDigits = 0;
    var seenFracDigits = 0;
    for (var i = 0; i < core.length; i++) {
      final ch = core[i];
      if (_isDigit(core.codeUnitAt(i))) {
        final int place;
        if (i < intEnd) {
          place = intDigits - 1 - seenIntDigits;
          seenIntDigits++;
        } else {
          seenFracDigits++;
          place = -seenFracDigits;
        }
        tokens.add(_Token.digit(int.parse(ch), place, prefix, suffix));
      } else {
        // A comma's "place" is the place of the digit immediately to its right,
        // so its key is stable as the figure crosses thousands boundaries.
        final rightPlace = ch == '.'
            ? 0
            : intDigits - 1 - seenIntDigits; // next int digit's place
        tokens.add(_Token.sep(ch, rightPlace, prefix, suffix));
      }
    }
    return tokens;
  }

  int _digitCount(String s, int from, int to) {
    var n = 0;
    for (var i = from; i < to; i++) {
      if (_isDigit(s.codeUnitAt(i))) n++;
    }
    return n;
  }

  bool _isDigit(int codeUnit) => codeUnit >= 0x30 && codeUnit <= 0x39;
}

/// One parsed glyph of the numeric core: either a digit (with its place value)
/// or a static separator. Carries the figure's prefix/suffix for the row.
class _Token {
  const _Token.digit(this.value, this.place, this.prefix, this.suffix)
    : char = '',
      isDigit = true;
  const _Token.sep(this.char, this.place, this.prefix, this.suffix)
    : value = 0,
      isDigit = false;

  final bool isDigit;
  final int value;
  final String char;
  final int place;
  final String prefix;
  final String suffix;
}

/// A non-animating glyph — a prefix/suffix, a comma or the decimal point. Sized
/// by the same line box as a reel (identical style), so it shares the baseline.
class _Static extends StatelessWidget {
  const _Static(this.text, this.style, {super.key});

  final String text;
  final TextStyle style;

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: style,
    maxLines: 1,
    softWrap: false,
  );
}
