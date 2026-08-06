import 'package:flutter/material.dart';

/// Tasteful, performance-conscious motion primitives used across the app
/// (Phase 9). Deliberately minimal — a single controller per widget, short
/// durations, standard easing — so list scrolling stays smooth and nothing
/// feels like a "demo". Reuse these instead of hand-rolling animations.

/// Fades + lifts a widget in on first build. Used for card / list-item
/// appearance. Pass a [delay] (see [staggerDelay]) for a gentle stagger.
class EntranceFade extends StatefulWidget {
  const EntranceFade({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.offset = 14,
    this.duration = const Duration(milliseconds: 320),
  });

  final Widget child;
  final Duration delay;

  /// Vertical travel (px) the child rises through as it fades in.
  final double offset;
  final Duration duration;

  @override
  State<EntranceFade> createState() => _EntranceFadeState();
}

class _EntranceFadeState extends State<EntranceFade>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: widget.duration);
  late final Animation<double> _curve =
      CurvedAnimation(parent: _c, curve: Curves.easeOutCubic);

  @override
  void initState() {
    super.initState();
    if (widget.delay == Duration.zero) {
      _c.forward();
    } else {
      Future<void>.delayed(widget.delay, () {
        if (mounted) _c.forward();
      });
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _curve,
      builder: (context, child) => Opacity(
        opacity: _curve.value,
        child: Transform.translate(
          offset: Offset(0, (1 - _curve.value) * widget.offset),
          child: child,
        ),
      ),
      child: widget.child,
    );
  }
}

/// A capped per-index delay for staggering list entrances. Capped so a long
/// list never waits seconds for the last item.
Duration staggerDelay(int index) =>
    Duration(milliseconds: (index * 45).clamp(0, 270));

/// Replaces one action affordance with the next **in place** — the button a
/// task's current state entitles the user to (Start → Continue → Complete).
///
/// Every lifecycle move is a server round trip: the old action goes inert for
/// 100–1000ms and the new one then appears where it stood. Unanimated, that
/// reads as a freeze followed by a jump — the app looks like it lagged even
/// though it worked. This is the single primitive for that moment: a fast
/// cross-fade with a short rise, over an [AnimatedSize] so a taller or shorter
/// replacement grows into place instead of snapping the surface around it.
///
/// Deliberately quicker in than out (200ms / 130ms): the arriving action is
/// what the user is waiting for, the leaving one must not linger under it.
///
/// **The [child] must carry a [Key] that changes when the action changes** —
/// otherwise Flutter updates the existing widget in place and nothing
/// animates.
///
/// Honours reduced motion by swapping instantly.
class ActionSwap extends StatelessWidget {
  const ActionSwap({
    super.key,
    required this.child,
    this.alignment = Alignment.center,
  });

  final Widget child;

  /// Where the outgoing and incoming actions are pinned while they overlap,
  /// and the edge [AnimatedSize] grows from. Use `centerRight` for a
  /// right-aligned card action so it grows leftwards, not from its middle.
  final Alignment alignment;

  static const _enter = Duration(milliseconds: 200);
  static const _exit = Duration(milliseconds: 130);

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) return child;
    return AnimatedSize(
      duration: _enter,
      curve: Curves.easeOutCubic,
      alignment: alignment,
      child: AnimatedSwitcher(
        duration: _enter,
        reverseDuration: _exit,
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeIn,
        layoutBuilder: (current, previous) => Stack(
          alignment: alignment,
          children: [...previous, ?current],
        ),
        transitionBuilder: (child, anim) => FadeTransition(
          opacity: anim,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.18),
              end: Offset.zero,
            ).animate(anim),
            child: child,
          ),
        ),
        child: child,
      ),
    );
  }
}
