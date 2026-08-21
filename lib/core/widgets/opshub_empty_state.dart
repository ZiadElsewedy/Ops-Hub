import 'package:flutter/material.dart';
import 'package:opshub/core/theme/app_colors.dart';
import 'package:opshub/core/theme/app_spacing.dart';
import 'package:opshub/core/widgets/app_empty_state.dart';
import 'package:opshub/core/widgets/opshub_logo.dart';
import 'package:opshub/core/widgets/empty_state_medallion.dart';

/// **OpsHubEmptyState** — a **brand-led** empty state: the DROP mark, quietly lit
/// inside the shared medallion, instead of a generic grey glyph — then the
/// message + optional action. The branded sibling of `AppEmptyState` (same
/// centered, always-scrollable layout so it works as a `RefreshIndicator`
/// child), for the moments where the brand should be felt — a fresh inbox, a
/// cleared queue, a first-run list.
///
/// Use `AppEmptyState` for routine "nothing here" placeholders; reach for this
/// where the empty moment is a brand touchpoint. Strictly monochrome.
class OpsHubEmptyState extends StatelessWidget {
  const OpsHubEmptyState({
    super.key,
    required this.message,
    this.title,
    this.action,
  });

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
                mark: const EmptyStateMedallion(
                  // The mark sits inside the disc, so it needs less fade than
                  // it did standing alone on the page — the medallion is doing
                  // the quieting now.
                  child: Opacity(
                    opacity: 0.55,
                    child: OpsHubLogo(height: 17, color: AppColors.textPrimary),
                  ),
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
