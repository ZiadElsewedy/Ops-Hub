import 'package:flutter/material.dart';
import 'package:drop/core/theme/app_colors.dart';
import 'package:drop/core/theme/app_spacing.dart';
import 'package:drop/core/theme/app_typography.dart';
import 'package:drop/core/widgets/empty_state_medallion.dart';

/// Shared, centered empty-state placeholder for any list/section.
///
/// The glyph is carried by [EmptyStateMedallion] — the same silhouette every
/// empty surface in the app uses — so a cleared list reads as *finished*, not
/// as a screen that failed to load.
///
/// Wrapped in an always-scrollable view so it can be a [RefreshIndicator] child
/// (pull-to-refresh still works on an empty list). [title] and [action] are
/// optional — with both null this renders exactly like the original
/// `TaskEmptyState` (mark + message), which now delegates here.
class AppEmptyState extends StatelessWidget {
  const AppEmptyState({
    super.key,
    required this.icon,
    required this.message,
    this.title,
    this.action,
  });

  final IconData icon;
  final String message;
  final String? title;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: ConstrainedBox(
          // Fill the viewport when height is bounded (the normal
          // RefreshIndicator-child use). When nested inside another scrollable
          // (e.g. a ListView), height is unbounded — fall back to sizing to
          // content instead of forcing an infinite height (which crashes).
          constraints: BoxConstraints(
              minHeight:
                  constraints.maxHeight.isFinite ? constraints.maxHeight : 0),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.pagePadding),
              child: EmptyStateBody(
                mark: EmptyStateMedallion(
                  child: Icon(icon, size: 26, color: AppColors.textSecondary),
                ),
                title: title,
                message: message,
                action: action,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The shared text block under an empty-state mark: title, message on a
/// readable measure, then the optional action. Kept public so the two core
/// empty states — and any in-card variant — stay in exact typographic lockstep
/// instead of each re-inventing the spacing.
class EmptyStateBody extends StatelessWidget {
  const EmptyStateBody({
    super.key,
    required this.mark,
    required this.message,
    this.title,
    this.action,
  });

  final Widget mark;
  final String message;
  final String? title;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        mark,
        const SizedBox(height: AppSpacing.xl),
        if (title != null) ...[
          Text(
            title!,
            style: AppTypography.h3.copyWith(letterSpacing: -0.2),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
        // A hard measure: centered grey text past ~34 characters a line stops
        // being read and starts being skipped.
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 264),
          child: Text(
            message,
            style: AppTypography.bodySmall.copyWith(height: 1.55),
            textAlign: TextAlign.center,
          ),
        ),
        if (action != null) ...[
          const SizedBox(height: AppSpacing.xl),
          action!,
        ],
      ],
    );
  }
}
