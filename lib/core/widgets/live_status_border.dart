import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';

/// A neutral amber accent kept for surfaces (e.g. dashboard cards) that want the
/// living border without a task state — soft amber/gold that blends with the
/// dark dashboard.
const Color kLivingBorderAccent = Color(0xFFF59E0B);

/// Soft, desaturated blue for a "syncing" state (`#93C5FD`).
const Color kLivingBorderSyncing = Color(0xFF93C5FD);

/// A premium **full-border orbit** "living edge" for actionable cards: a soft
/// light (rounded head → long soft comet tail + a subtle inner bloom) travels
/// continuously around the *entire* rounded-rect border with **premium,
/// non-constant motion** — it eases slightly into each rounded corner and
/// accelerates back out on the straights, with a very subtle brightness bump as
/// it rounds a corner. Elegant, **not** a loading spinner.
///
/// **Colour model:** [color] is the orbit's colour — a **per-state** accent held
/// persistently while that state lasts. `null` disables the orbit (a settled /
/// non-actionable card). On a **state change** ([color] changes) the orbit does
/// not snap: it eases from the colour on screen to the new one over
/// [transitionDuration] and keeps looping in it. [speed] scales the lap time per
/// state; [pulse] adds a very subtle glow-intensity breathing (for overdue),
/// never a speed change. Reaching a terminal state ([color] → `null`) does one
/// graceful final orbit fading out, then leaves only the card's static border.
///
/// Performance (unchanged strategy): pass-through when inactive; the orbit +
/// transition drive a [CustomPainter] via a merged `repaint` listenable over a
/// child in its own [RepaintBoundary]. **No per-frame rebuilds** (only on the
/// rare discrete state change); the two controllers are created once and reused;
/// the painter caches its path metric, corner map and motion-warp LUT by size,
/// reuses its `Paint`s and precomputes the tail falloff, so `paint()` allocates
/// nothing heavy.
class LiveStatusBorder extends StatefulWidget {
  const LiveStatusBorder({
    super.key,
    required this.child,
    required this.color,
    this.speed = 1,
    this.pulse = false,
    this.borderRadius = const BorderRadius.all(Radius.circular(14)),
    this.strokeWidth = 2,
    this.period = const Duration(milliseconds: 4200),
    this.maxOpacity = 0.6,
    this.transitionDuration = const Duration(milliseconds: 320),
  });

  final Widget child;

  /// The per-state orbit colour, or `null` to disable the orbit — the widget
  /// then eases out any orbit in flight and becomes a pure pass-through.
  final Color? color;

  /// Per-state lap-speed multiplier (period = [period] / [speed]).
  final double speed;

  /// Very subtle glow-intensity breathing (e.g. overdue) — never a speed change.
  final bool pulse;

  /// Must match the wrapped surface's radius so the orbit rides its border.
  final BorderRadius borderRadius;

  /// Hairline thickness (premium band ~1.8–2.2 px).
  final double strokeWidth;

  /// Base lap time at [speed] == 1.
  final Duration period;

  /// Peak opacity at the head of the comet — kept subtle on purpose.
  final double maxOpacity;

  /// How long a state-change colour ease takes.
  final Duration transitionDuration;

  @override
  State<LiveStatusBorder> createState() => _LiveStatusBorderState();
}

enum _Phase { steady, changing, exiting }

class _LiveStatusBorderState extends State<LiveStatusBorder>
    with TickerProviderStateMixin {
  // Two controllers, both created lazily and reused for the State's life:
  //  * [_orbit]  repeats continuously → the head's position around the border.
  //  * [_seq]    one-shot 0→1 → drives a colour ease or a terminal fade-out.
  AnimationController? _orbit;
  AnimationController? _seq;

  _Phase _phase = _Phase.steady;
  Color _from = const Color(0x00000000);
  Color _to = const Color(0x00000000);

  Duration get _lapDuration =>
      widget.period * (1 / math.max(0.1, widget.speed));

  @override
  void initState() {
    super.initState();
    if (widget.color != null) {
      _from = _to = widget.color!;
      _startOrbit();
    }
  }

  void _startOrbit() {
    final o = _orbit ??= AnimationController(
      vsync: this,
      duration: _lapDuration,
    );
    o.duration = _lapDuration;
    if (!o.isAnimating) o.repeat();
  }

  AnimationController _seq4(Duration d) {
    final s = _seq ??= AnimationController(vsync: this)
      ..addStatusListener(_onSeqDone);
    s.duration = d;
    return s;
  }

  void _onSeqDone(AnimationStatus status) {
    if (status != AnimationStatus.completed) return;
    if (_phase == _Phase.changing) {
      setState(() {
        _phase = _Phase.steady;
        _from = _to;
      });
    } else if (_phase == _Phase.exiting) {
      _orbit?.stop();
      setState(() => _phase = _Phase.steady); // inactive → pass-through
    }
  }

  @override
  void didUpdateWidget(LiveStatusBorder old) {
    super.didUpdateWidget(old);
    if (widget.speed != old.speed || widget.period != old.period) {
      _orbit?.duration = _lapDuration;
      if (_orbit?.isAnimating ?? false) _orbit!.repeat();
    }

    final next = widget.color;
    if (next != null && old.color == null) {
      // Off → on: begin orbiting immediately in the new colour.
      _seq?.stop();
      _startOrbit();
      setState(() {
        _phase = _Phase.steady;
        _from = _to = next;
      });
    } else if (next == null && old.color != null) {
      // On → terminal: one graceful final orbit fading out, then static border.
      _startOrbit();
      setState(() {
        _phase = _Phase.exiting;
        _from = _displayColour();
      });
      _seq4(_lapDuration).forward(from: 0);
    } else if (next != null && next != old.color) {
      // State change → smoothly ease from the colour on screen now to the new
      // state colour (never a snap), then keep looping in it.
      _startOrbit();
      final start = _displayColour();
      setState(() {
        _phase = _Phase.changing;
        _from = start;
        _to = next;
      });
      _seq4(widget.transitionDuration).forward(from: 0);
    }
  }

  /// The colour on screen right now, so a mid-transition change never snaps.
  Color _displayColour() {
    if (_phase == _Phase.changing && _seq != null) {
      return Color.lerp(_from, _to, _seq!.value) ?? _to;
    }
    return _phase == _Phase.exiting ? _from : _to;
  }

  @override
  void dispose() {
    _orbit?.dispose();
    _seq?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final orbit = _orbit;
    final active = widget.color != null || _phase == _Phase.exiting;
    // Inactive → pure pass-through: no painter, no repaint, no cost.
    if (!active || orbit == null) return widget.child;

    return RepaintBoundary(
      child: CustomPaint(
        foregroundPainter: _OrbitPainter(
          orbit: orbit,
          seq: _seq ?? kAlwaysDismissedAnimation,
          phase: _phase,
          from: _from,
          to: _to,
          pulse: widget.pulse,
          radius: widget.borderRadius.topLeft.x,
          strokeWidth: widget.strokeWidth,
          maxOpacity: widget.maxOpacity,
        ),
        // The card body is cached as its own layer, so a tick only re-rasters
        // the foreground stroke — never the (static) card content.
        child: RepaintBoundary(child: widget.child),
      ),
    );
  }
}

/// Cached, size-dependent geometry: the border metric, the four corner-arc
/// distance ranges, and a phase→distance warp LUT for the premium corner motion.
class _Geo {
  _Geo(this.metric, this.total, this.arcs, this.lut);
  final ui.PathMetric metric;
  final double total;
  final List<double> arcs; // flat [s0,e0, s1,e1, s2,e2, s3,e3]
  final List<double> lut; // phase(k/_lutN) → distance
}

/// Paints the orbiting comet around the full rounded-rect border with premium,
/// corner-eased motion, a corner highlight, an optional intensity pulse, and the
/// live colour (steady / eased / fading) resolved from the sequence each frame.
class _OrbitPainter extends CustomPainter {
  _OrbitPainter({
    required this.orbit,
    required this.seq,
    required this.phase,
    required this.from,
    required this.to,
    required this.pulse,
    required this.radius,
    required this.strokeWidth,
    required this.maxOpacity,
  }) : super(repaint: Listenable.merge([orbit, seq])) {
    _stroke
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = strokeWidth;
    _bloom
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = strokeWidth * 2.4
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.5);
  }

  final Animation<double> orbit;
  final Animation<double> seq;
  final _Phase phase;
  final Color from;
  final Color to;
  final bool pulse;
  final double radius;
  final double strokeWidth;
  final double maxOpacity;

  static const int _steps = 30;
  static const double _segFraction = 0.34;
  static const double _segMin = 80;
  static const double _segMax = 120;
  static const int _lutN = 360;
  static const double _cornerSlow = 0.62; // speed dip factor at a corner middle
  static const double _cornerBright = 0.08; // +8% brightness rounding a corner

  static final List<double> _falloff = List<double>.generate(
    _steps,
    (i) => math.pow((i + 1) / _steps, 1.6).toDouble(),
  );

  final Paint _stroke = Paint();
  final Paint _bloom = Paint();

  Size? _geoSize;
  _Geo? _geo;

  _Geo? _geoFor(Size size, Rect rect, double rr) {
    if (_geoSize == size && _geo != null) return _geo;
    // Manual full rounded-rect (clockwise, dist 0 = top-edge left end) so the
    // four corner-arc ranges are known exactly for the motion warp + highlight.
    final path = Path()
      ..moveTo(rect.left + rr, rect.top)
      ..lineTo(rect.right - rr, rect.top)
      ..arcToPoint(
        Offset(rect.right, rect.top + rr),
        radius: Radius.circular(rr),
      )
      ..lineTo(rect.right, rect.bottom - rr)
      ..arcToPoint(
        Offset(rect.right - rr, rect.bottom),
        radius: Radius.circular(rr),
      )
      ..lineTo(rect.left + rr, rect.bottom)
      ..arcToPoint(
        Offset(rect.left, rect.bottom - rr),
        radius: Radius.circular(rr),
      )
      ..lineTo(rect.left, rect.top + rr)
      ..arcToPoint(
        Offset(rect.left + rr, rect.top),
        radius: Radius.circular(rr),
      )
      ..close();
    final metrics = path.computeMetrics().toList();
    if (metrics.isEmpty) return null;
    final metric = metrics.first;
    final total = metric.length;

    final hLen = rect.width - 2 * rr;
    final vLen = rect.height - 2 * rr;
    final arc = (math.pi / 2) * rr;
    // TR, BR, BL, TL arc ranges along the perimeter.
    final a0 = hLen,
        a1 = a0 + arc + vLen,
        a2 = a1 + arc + hLen,
        a3 = a2 + arc + vLen;
    final arcs = <double>[
      a0,
      a0 + arc,
      a1,
      a1 + arc,
      a2,
      a2 + arc,
      a3,
      a3 + arc,
    ];

    _geo = _Geo(metric, total, arcs, _buildLut(total, arcs));
    _geoSize = size;
    return _geo;
  }

  /// Speed profile along the border: 1.0 on the straights, dipping toward
  /// [_cornerSlow] through each arc (smooth, peaking at the arc middle).
  double _speedAt(double d, List<double> arcs) {
    for (var i = 0; i < arcs.length; i += 2) {
      final s = arcs[i], e = arcs[i + 1];
      if (d >= s && d <= e) {
        final pos = (d - s) / (e - s);
        return 1 + (_cornerSlow - 1) * math.sin(math.pi * pos);
      }
    }
    return 1;
  }

  /// Integrate 1/speed over distance, then invert to a phase→distance table so a
  /// uniform-time controller yields corner-eased motion. Built once per size.
  List<double> _buildLut(double total, List<double> arcs) {
    final times = List<double>.filled(_lutN + 1, 0);
    var prev = 0.0, cum = 0.0;
    for (var i = 1; i <= _lutN; i++) {
      final d = i / _lutN * total;
      cum += (d - prev) / _speedAt((d + prev) / 2, arcs);
      times[i] = cum;
      prev = d;
    }
    final totalTime = times[_lutN] == 0 ? 1.0 : times[_lutN];
    final lut = List<double>.filled(_lutN + 1, 0);
    var j = 0;
    for (var k = 0; k <= _lutN; k++) {
      final target = k / _lutN * totalTime;
      while (j < _lutN && times[j + 1] < target) {
        j++;
      }
      final t0 = times[j], t1 = times[j + 1 > _lutN ? _lutN : j + 1];
      final f = (t1 - t0) == 0 ? 0.0 : (target - t0) / (t1 - t0);
      final d0 = j / _lutN * total,
          d1 = (j + 1 > _lutN ? _lutN : j + 1) / _lutN * total;
      lut[k] = d0 + (d1 - d0) * f;
    }
    return lut;
  }

  double _warp(List<double> lut, double phase) {
    final x = (phase % 1.0) * _lutN;
    final i = x.floor().clamp(0, _lutN - 1);
    return lut[i] + (lut[i + 1] - lut[i]) * (x - i);
  }

  double _cornerBoost(double head, List<double> arcs) {
    for (var i = 0; i < arcs.length; i += 2) {
      final s = arcs[i], e = arcs[i + 1];
      if (head >= s && head <= e) {
        return 1 + _cornerBright * math.sin(math.pi * (head - s) / (e - s));
      }
    }
    return 1;
  }

  @override
  void paint(Canvas canvas, Size size) {
    // Resolve the live colour + base opacity from the sequence phase.
    final Color color;
    var opacity = 1.0;
    switch (phase) {
      case _Phase.steady:
        color = to;
      case _Phase.changing:
        color = Color.lerp(from, to, _easeInOut(seq.value)) ?? to;
      case _Phase.exiting:
        color = from;
        opacity = 1 - _easeInOut(seq.value);
    }
    if (opacity <= 0) return;

    final inset = strokeWidth / 2;
    final rect = Rect.fromLTWH(
      inset,
      inset,
      size.width - strokeWidth,
      size.height - strokeWidth,
    );
    if (rect.width <= 0 || rect.height <= 0) return;
    final rr = math.min(radius, math.min(rect.width, rect.height) / 2);

    final geo = _geoFor(size, rect, rr);
    if (geo == null || geo.total <= 0) return;

    // Premium motion + corner highlight + optional pulse.
    final head = _warp(geo.lut, orbit.value);
    opacity *= _cornerBoost(head, geo.arcs);
    if (pulse) opacity *= 0.85 + 0.15 * math.sin(orbit.value * math.pi * 4);

    final segLen = (size.width * _segFraction)
        .clamp(_segMin, _segMax)
        .toDouble();
    final tail = head - segLen;

    // ── Inner bloom: soft blurred wash clipped to the interior → no outer glow.
    canvas.save();
    canvas.clipRRect(RRect.fromRectAndRadius(rect, Radius.circular(rr)));
    _bloom.color = color.withAlpha(_alpha(maxOpacity * opacity * 0.12));
    _drawArc(canvas, geo.metric, geo.total, tail, head, _bloom);
    canvas.restore();

    // ── Crisp comet: bright rounded head → long soft tail (wraps the seam). ───
    final stepLen = segLen / _steps;
    for (var i = 0; i < _steps; i++) {
      final from = tail + i * stepLen;
      final a = _alpha(maxOpacity * opacity * _falloff[i]);
      if (a == 0) continue;
      _stroke.color = color.withAlpha(a);
      _drawArc(canvas, geo.metric, geo.total, from, from + stepLen, _stroke);
    }
  }

  void _drawArc(
    Canvas canvas,
    ui.PathMetric metric,
    double total,
    double a,
    double b,
    Paint paint,
  ) {
    var s = a % total;
    var e = b % total;
    if (s < 0) s += total;
    if (e < 0) e += total;
    if (s <= e) {
      canvas.drawPath(metric.extractPath(s, e), paint);
    } else {
      canvas.drawPath(metric.extractPath(s, total), paint);
      canvas.drawPath(metric.extractPath(0, e), paint);
    }
  }

  int _alpha(double o) => (o * 255).round().clamp(0, 255);

  static double _easeInOut(double x) {
    if (x <= 0) return 0;
    if (x >= 1) return 1;
    if (x < 0.5) return 4 * x * x * x;
    final f = -2 * x + 2;
    return 1 - (f * f * f) / 2;
  }

  @override
  bool shouldRepaint(_OrbitPainter old) =>
      old.phase != phase ||
      old.from != from ||
      old.to != to ||
      old.pulse != pulse ||
      old.radius != radius ||
      old.strokeWidth != strokeWidth ||
      old.maxOpacity != maxOpacity;
}
