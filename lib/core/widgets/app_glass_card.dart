import 'package:flutter/material.dart';
import 'package:opshub/core/enums/task_status.dart';
import 'package:opshub/core/theme/app_radius.dart';
import 'package:opshub/core/theme/app_spacing.dart';
import 'package:opshub/core/widgets/glass_container.dart';
import 'package:opshub/core/widgets/status_badge.dart';

/// **AppGlassCard** — the canonical premium surface of the DROP component
/// system. A rounded, gradient, depth-shadowed "glass" card that can carry a
/// **subtle semantic glow** (a status colour) without breaking the strictly
/// monochrome design: the surface + chrome stay greyscale, and only a soft
/// emerald / amber / red halo signals an approved / in-review / rejected task.
///
/// It delegates to the shared [GlassContainer] (one decoration implementation —
/// no duplicate "glass" treatment); this widget adds the **semantic** layer:
/// map a [TaskStatus] → glow via [glowStatus], or pass an explicit [glow].
///
/// Per the owner ruling (2026-06-25): **no indigo, status glows only.** An
/// `active` task (started) deliberately gets **no** glow (stays monochrome) —
/// the prompt's "indigo active glow" was rejected.
class AppGlassCard extends StatelessWidget {
  const AppGlassCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(AppSpacing.lg),
    this.borderRadius = AppRadius.cardAll,
    this.glow,
    this.glowStatus,
    this.highlight = false,
    this.accent,
    this.elevated = true,
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  final BorderRadius borderRadius;

  /// Explicit glow colour (wins over [glowStatus]). Null = monochrome.
  final Color? glow;

  /// A task status whose **subtle** glow this card should carry. Resolved via
  /// [glowForTaskStatus] — only approved / waitingReview / rejected glow.
  final TaskStatus? glowStatus;

  final bool highlight;
  final Color? accent;
  final bool elevated;

  /// Maps a task status to its subtle glow colour, or null for "no glow"
  /// (monochrome). Reuses [taskStatusColor] so the colour mapping lives in one
  /// place. Only the **reviewed/awaiting** states glow; pending / started /
  /// completed / missed / cancelled stay monochrome (no indigo "active" glow —
  /// owner ruling). A missed or cancelled task is closed, so it does not carry a
  /// live-state glow.
  static Color? glowForTaskStatus(TaskStatus status) => switch (status) {
    TaskStatus.approved ||
    TaskStatus.waitingReview ||
    TaskStatus.rejected => taskStatusColor(status),
    TaskStatus.pending ||
    TaskStatus.started ||
    TaskStatus.completed ||
    TaskStatus.missed ||
    TaskStatus.cancelled => null,
  };

  @override
  Widget build(BuildContext context) {
    final resolvedGlow =
        glow ?? (glowStatus != null ? glowForTaskStatus(glowStatus!) : null);
    return GlassContainer(
      onTap: onTap,
      padding: padding,
      borderRadius: borderRadius,
      highlight: highlight,
      accent: accent,
      elevated: elevated,
      glow: resolvedGlow,
      child: child,
    );
  }
}
