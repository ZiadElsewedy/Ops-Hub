import 'dart:async';

import 'package:flutter/material.dart';
import 'package:opshub/core/theme/app_colors.dart';
import 'package:opshub/core/theme/app_typography.dart';

/// Relative "last synced" label for a dashboard [SyncButton]. Pure with an
/// injectable clock so the freshness copy is unit-testable without pumping a
/// widget tree.
String syncLabel(DateTime? lastSynced, {DateTime? now}) {
  if (lastSynced == null) return 'Sync';
  final d = (now ?? DateTime.now()).difference(lastSynced);
  if (d.inSeconds < 45) return 'Synced just now';
  if (d.inMinutes < 60) return 'Synced ${d.inMinutes}m ago';
  if (d.inHours < 24) return 'Synced ${d.inHours}h ago';
  return 'Synced ${d.inDays}d ago';
}

/// A premium **Sync** control for a dashboard header (DROP Design System V2).
/// Rotates while a refresh is in flight and otherwise shows how long ago the
/// live data was last pulled; tapping force-refreshes the caller's sources.
/// Desktop shows a labelled pill; [compact] shows an icon-only 40pt tap target
/// for the mobile hero.
///
/// The dashboards stay reactive without this — Sync is a manual escape hatch,
/// not the update mechanism.
class SyncButton extends StatefulWidget {
  const SyncButton({
    super.key,
    required this.syncing,
    required this.lastSynced,
    required this.onSync,
    this.compact = false,
  });

  final bool syncing;
  final DateTime? lastSynced;
  final VoidCallback onSync;
  final bool compact;

  @override
  State<SyncButton> createState() => _SyncButtonState();
}

class _SyncButtonState extends State<SyncButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _spin = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );
  Timer? _ticker;
  bool _hovered = false;

  @override
  void initState() {
    super.initState();
    if (widget.syncing) _spin.repeat();
    // Keep the "3m ago" label honest without leaning on a parent rebuild.
    _ticker = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void didUpdateWidget(covariant SyncButton old) {
    super.didUpdateWidget(old);
    if (widget.syncing == old.syncing) return;
    if (widget.syncing) {
      _spin.repeat();
    } else {
      // Let the current turn finish for a smooth stop, then settle to rest.
      _spin
          .animateTo(1, duration: const Duration(milliseconds: 220))
          .whenComplete(() {
            if (mounted) _spin.reset();
          });
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _spin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final label = widget.syncing ? 'Syncing…' : syncLabel(widget.lastSynced);
    final onTap = widget.syncing ? null : widget.onSync;
    final icon = RotationTransition(
      turns: _spin,
      child: Icon(
        Icons.sync_rounded,
        size: 15,
        color: widget.syncing ? AppColors.textPrimary : AppColors.textSecondary,
      ),
    );

    if (widget.compact) {
      return Semantics(
        button: true,
        label: label,
        child: GestureDetector(
          onTap: onTap,
          behavior: HitTestBehavior.opaque,
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.darkSurface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.darkBorder),
            ),
            child: Center(child: icon),
          ),
        ),
      );
    }

    return Semantics(
      button: true,
      label: label,
      child: MouseRegion(
        cursor: onTap == null
            ? SystemMouseCursors.basic
            : SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          onTap: onTap,
          behavior: HitTestBehavior.opaque,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.darkSurface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: _hovered ? AppColors.textTertiary : AppColors.darkBorder,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                icon,
                const SizedBox(width: 8),
                Text(
                  label,
                  style: AppTypography.caption.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
