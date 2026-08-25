import 'package:flutter/material.dart';
import 'package:opshub/core/theme/app_colors.dart';

/// A realtime-list item wrapper: it **enters once** (fade + a slight rise) when
/// it first appears and never replays on a parent rebuild — so a stream emit that
/// re-renders the list does not re-animate the rows already on screen. Give it a
/// stable [key] (e.g. `ValueKey(id)`): that key is what lets Flutter reuse this
/// element across rebuilds, so only a genuinely new id mounts + animates — no
/// manual diffing or `AnimatedList` bookkeeping, and the scroll position is
/// preserved.
///
/// When [isNew] (a fresh arrival after the initial load), it also briefly frames
/// itself in a fading accent border — the "newly added" highlight. Intentionally
/// minimal: entrance + optional highlight, nothing else (do not grow this into a
/// general animation kit).
class LiveListItem extends StatefulWidget {
  const LiveListItem({
    super.key,
    required this.child,
    this.isNew = false,
    this.entranceDelay = Duration.zero,
    this.highlightRadius = 14,
  });

  final Widget child;

  /// Briefly highlight as a fresh arrival (entrance still plays regardless).
  final bool isNew;

  /// Stagger the entrance (e.g. `index * 40ms` on first load). New arrivals sort
  /// newest-first to the top (index 0 ⇒ no delay), so this needs no special case.
  final Duration entranceDelay;

  /// Corner radius of the transient highlight frame (match the child's radius).
  final double highlightRadius;

  @override
  State<LiveListItem> createState() => _LiveListItemState();
}

class _LiveListItemState extends State<LiveListItem>
    with TickerProviderStateMixin {
  late final AnimationController _enter = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 320),
  );
  late final Animation<double> _entered =
      CurvedAnimation(parent: _enter, curve: Curves.easeOutCubic);
  late final Animation<Offset> _rise = Tween<Offset>(
    begin: const Offset(0, 0.06),
    end: Offset.zero,
  ).animate(_entered);

  // 1 = full highlight, 0 = none. Created only for a new arrival (null otherwise).
  AnimationController? _highlight;

  @override
  void initState() {
    super.initState();
    if (widget.entranceDelay == Duration.zero) {
      _enter.forward();
    } else {
      Future.delayed(widget.entranceDelay, () {
        if (mounted) _enter.forward();
      });
    }
    if (widget.isNew) {
      final hl = _highlight = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 1300),
        value: 1,
      );
      // Hold briefly so the highlight registers, then fade it out.
      Future.delayed(const Duration(milliseconds: 700), () {
        if (mounted) hl.reverse();
      });
    }
  }

  @override
  void dispose() {
    _enter.dispose();
    _highlight?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Widget content = FadeTransition(
      opacity: _entered,
      child: SlideTransition(position: _rise, child: widget.child),
    );
    final hl = _highlight;
    if (hl == null) return content;
    return AnimatedBuilder(
      animation: hl,
      builder: (context, child) => DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(widget.highlightRadius),
          border: Border.all(
            color: AppColors.warning.withAlpha((hl.value * 110).round()),
            width: 1.4,
          ),
        ),
        child: child,
      ),
      child: content,
    );
  }
}
