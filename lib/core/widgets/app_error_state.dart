import 'package:flutter/material.dart';
import 'package:opshub/core/theme/app_colors.dart';
import 'package:opshub/core/theme/app_spacing.dart';
import 'package:opshub/core/theme/app_typography.dart';
import 'package:opshub/core/widgets/app_empty_state.dart';
import 'package:opshub/core/widgets/empty_state_medallion.dart';
import 'package:opshub/core/widgets/glass_container.dart';
import 'package:opshub/core/widgets/premium_button.dart';

/// **AppErrorState** — a whole surface failed to load.
///
/// Deliberately *not* an empty state. Before this, screens rendered failures
/// through `AppEmptyState` with an error glyph, so "the server rejected your
/// request" and "you have no tasks" were the same picture — and neither offered
/// a way out. This one is tinted with the semantic error tone (status colour
/// expressing status, per ADR-004) and, when [onRetry] is supplied, gives the
/// user the one control they actually want.
///
/// Use [AppProblemPanel] instead when the surface still has content to show and
/// the failure is partial — a stale section, a report that would not refresh.
class AppErrorState extends StatelessWidget {
  const AppErrorState({
    super.key,
    required this.message,
    this.title = 'Something went wrong',
    this.onRetry,
    this.retryLabel = 'Try again',
    this.icon = Icons.error_outline_rounded,
  });

  final String message;
  final String title;
  final VoidCallback? onRetry;
  final String retryLabel;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: ConstrainedBox(
          // Same bounded/unbounded dance as the empty states: fills the viewport
          // as a RefreshIndicator child, sizes to content inside a list.
          constraints: BoxConstraints(
              minHeight:
                  constraints.maxHeight.isFinite ? constraints.maxHeight : 0),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.pagePadding),
              child: EmptyStateBody(
                mark: EmptyStateMedallion(
                  tone: AppColors.error,
                  child: Icon(icon, size: 26, color: AppColors.error),
                ),
                title: title,
                message: message,
                action: onRetry == null
                    ? null
                    : PremiumButton(
                        label: retryLabel,
                        icon: Icons.refresh_rounded,
                        onPressed: onRetry,
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// **AppProblemPanel** — an inline "this part is not right" banner, for when the
/// screen still has content around it.
///
/// This shape existed as three byte-identical private `_ProblemPanel` copies in
/// the attendance screens; it lives here now so a fourth screen doesn't grow a
/// fourth copy. [onRetry] is the addition — the copies had no way out at all.
class AppProblemPanel extends StatelessWidget {
  const AppProblemPanel({
    super.key,
    required this.title,
    required this.message,
    this.icon = Icons.error_outline_rounded,
    this.tone = AppColors.warning,
    this.onRetry,
    this.retryLabel = 'Try again',
  });

  final String title;
  final String message;
  final IconData icon;
  final Color tone;
  final VoidCallback? onRetry;
  final String retryLabel;

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      highlight: true,
      accent: tone,
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: tone),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTypography.h3),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  message,
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                if (onRetry != null) ...[
                  const SizedBox(height: AppSpacing.lg),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: PremiumButton(
                      label: retryLabel,
                      icon: Icons.refresh_rounded,
                      style: PremiumButtonStyle.tonal,
                      onPressed: onRetry,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
