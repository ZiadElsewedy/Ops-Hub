import 'package:flutter/material.dart';
import 'package:drop/core/theme/app_colors.dart';
import 'package:drop/core/theme/app_radius.dart';
import 'package:drop/core/theme/app_spacing.dart';
import 'package:drop/core/theme/app_typography.dart';
import 'package:drop/features/schedule/presentation/widgets/sheet_chrome.dart';
import 'package:drop/features/schedule/presentation/widgets/swap_view.dart';

/// Floating alert that surfaces pending swap requests inside the schedule
/// workflow (Phase 7 redesign) — replacing the separate "Swap Requests" tab.
/// Swaps are part of schedule operations, so they live here as a glanceable
/// pill: tap to open the review queue or settled-request history.
class SwapAlertCard extends StatelessWidget {
  const SwapAlertCard({super.key, required this.count, required this.onReview});

  final int count;
  final VoidCallback onReview;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.pagePadding,
        0,
        AppSpacing.pagePadding,
        AppSpacing.md,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onReview,
          borderRadius: AppRadius.cardAll,
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.md,
            ),
            decoration: BoxDecoration(
              color: AppColors.darkSurfaceElevated,
              borderRadius: AppRadius.cardAll,
              border: Border.all(color: AppColors.darkBorder),
            ),
            child: Row(
              children: [
                _CountBadge(count: count),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        count == 0
                            ? 'Swap history'
                            : count == 1
                            ? '1 swap request pending'
                            : '$count swap requests pending',
                        style: AppTypography.label,
                      ),
                      const SizedBox(height: 1),
                      Text(
                        count == 0
                            ? 'Review previous requests and decisions'
                            : 'Tap to review and approve',
                        style: AppTypography.caption,
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: 6,
                  ),
                  decoration: const BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: AppRadius.fullAll,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        count == 0 ? 'History' : 'Review',
                        style: AppTypography.labelSmall.copyWith(
                          color: AppColors.onPrimary,
                        ),
                      ),
                      const Icon(
                        Icons.arrow_forward_rounded,
                        size: 15,
                        color: AppColors.onPrimary,
                      ),
                    ],
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

class _CountBadge extends StatelessWidget {
  const _CountBadge({required this.count});
  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        color: AppColors.primarySurface,
        shape: BoxShape.circle,
      ),
      child: Icon(
        Icons.swap_horiz_rounded,
        size: 20,
        color: AppColors.primary.withAlpha(230),
      ),
    );
  }
}

/// Opens the swap review queue as a modal sheet — reusing the shared
/// [SwapListView] (with its existing approve / reject actions) so the swap
/// workflow lives in exactly one place.
Future<void> showSwapQueueSheet({
  required BuildContext context,
  required String currentUid,
  required bool showBranch,
}) {
  // Capture inherited data while the caller is alive. The schedule rebuilds
  // while this route is opening; reading the caller context inside `builder`
  // can then hit a deactivated Element (the reported MediaQuery crash).
  final sheetHeight = MediaQuery.sizeOf(context).height * 0.8;
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.darkSurface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (sheetContext) => SizedBox(
      height: sheetHeight,
      child: Column(
        children: [
          const SizedBox(height: AppSpacing.md),
          const SheetHandle(),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.pagePadding,
              AppSpacing.md,
              AppSpacing.pagePadding,
              AppSpacing.sm,
            ),
            child: Row(
              children: [
                const Text('Swap requests & history', style: AppTypography.h3),
                const Spacer(),
                IconButton(
                  icon: const Icon(
                    Icons.close_rounded,
                    color: AppColors.textSecondary,
                  ),
                  onPressed: () => Navigator.of(sheetContext).pop(),
                ),
              ],
            ),
          ),
          Expanded(
            child: SwapListView(
              isManager: true,
              currentUid: currentUid,
              showBranch: showBranch,
            ),
          ),
        ],
      ),
    ),
  );
}
