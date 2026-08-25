import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:opshub/core/theme/app_colors.dart';
import 'package:opshub/core/theme/app_radius.dart';
import 'package:opshub/core/theme/app_spacing.dart';
import 'package:opshub/core/theme/app_typography.dart';
import 'package:opshub/core/widgets/glass_container.dart';
import 'package:opshub/core/widgets/rolling_number.dart';
import 'package:opshub/features/sales/domain/entities/sales_record_result.dart';
import 'package:opshub/features/sales/presentation/sales_format.dart';

/// The celebratory "+59,000 EGP added to the branch total" confirmation shown
/// once, after a manager/admin records a day directly.
///
/// The amount **rolls in** on the slot-machine odometer, in the muted sales
/// [AppColors.salesEmerald] (money landing is positive); when this record is the
/// one that reaches the monthly target it warms to a glowing celebration. Reduced
/// motion collapses every transition to a still frame.
Future<void> showSalesRecordAddedOverlay(
  BuildContext context,
  SalesRecordResult result,
) {
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Dismiss',
    barrierColor: Colors.black.withValues(alpha: 0.72),
    transitionDuration: const Duration(milliseconds: 260),
    pageBuilder: (_, _, _) => const SizedBox.shrink(),
    transitionBuilder: (dialogContext, animation, _, _) {
      final reduceMotion = MediaQuery.maybeOf(dialogContext)?.disableAnimations ?? false;
      final curved = CurvedAnimation(parent: animation, curve: Curves.easeOutBack);
      final scale = reduceMotion ? 1.0 : (0.9 + 0.1 * curved.value);
      // A transparent Material ancestor: without it, Text in a raw dialog route
      // renders with the framework's yellow "no Material" debug underline.
      return Material(
        type: MaterialType.transparency,
        child: Opacity(
          opacity: animation.value.clamp(0.0, 1.0),
          child: Transform.scale(
            scale: scale,
            child: Center(
              child: _SalesRecordAddedCard(result: result),
            ),
          ),
        ),
      );
    },
  );
}

class _SalesRecordAddedCard extends StatefulWidget {
  const _SalesRecordAddedCard({required this.result});
  final SalesRecordResult result;

  @override
  State<_SalesRecordAddedCard> createState() => _SalesRecordAddedCardState();
}

class _SalesRecordAddedCardState extends State<_SalesRecordAddedCard> {
  Timer? _autoDismiss;

  @override
  void initState() {
    super.initState();
    // A gentle tick to acknowledge the money landing.
    HapticFeedback.mediumImpact();
    // Auto-dismiss so the celebration never traps the screen; a tap still closes.
    _autoDismiss = Timer(const Duration(milliseconds: 2600), () {
      if (mounted && Navigator.of(context).canPop()) Navigator.of(context).pop();
    });
  }

  @override
  void dispose() {
    _autoDismiss?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final result = widget.result;
    final crossed = result.crossedTarget;
    // Money added is positive → emerald throughout; crossing the target warms it
    // to a glowing celebration rather than a second colour.
    const accent = AppColors.salesEmerald;

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.pagePadding),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: GestureDetector(
          onTap: () {
            if (Navigator.of(context).canPop()) Navigator.of(context).pop();
          },
          child: GlassContainer(
            glow: crossed ? accent : null,
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.xl,
              vertical: AppSpacing.xxl,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _Medallion(crossed: crossed, accent: accent),
                const SizedBox(height: AppSpacing.lg),
                // Rolls in briefly (settles well before the 2.6 s auto-dismiss).
                // FittedBox guards narrow phones: a long figure at display size
                // must shrink as one unit, never overflow the card.
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: RollingNumber(
                    value: result.amountPiastres,
                    formatter: (v) =>
                        '+ ${formatEgp(v.round(), withSuffix: true)}',
                    animateOnMount: true,
                    duration: const Duration(milliseconds: 850),
                    perPlaceStep: const Duration(milliseconds: 55),
                    maxExtra: const Duration(milliseconds: 380),
                    style: AppTypography.displayMedium.copyWith(color: accent),
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  crossed
                      ? 'Monthly target reached 🎉'
                      : 'added to the branch total',
                  textAlign: TextAlign.center,
                  style: AppTypography.body.copyWith(
                    color: crossed ? accent : AppColors.textSecondary,
                  ),
                ),
                if (result.targetPiastres > 0) ...[
                  const SizedBox(height: AppSpacing.lg),
                  _AchievedLine(
                    achievedPiastres: result.achievedPiastres,
                    targetPiastres: result.targetPiastres,
                    accent: accent,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Medallion extends StatelessWidget {
  const _Medallion({required this.crossed, required this.accent});
  final bool crossed;
  final Color accent;

  @override
  Widget build(BuildContext context) => Container(
    width: 64,
    height: 64,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: accent.withValues(alpha: 0.12),
      border: Border.all(color: accent.withValues(alpha: 0.4)),
    ),
    child: Icon(
      crossed ? Icons.emoji_events_outlined : Icons.trending_up,
      color: accent,
      size: 30,
    ),
  );
}

/// A slim monochrome progress bar with the new achieved / target beneath it —
/// grounds the celebration in where the month now stands.
class _AchievedLine extends StatelessWidget {
  const _AchievedLine({
    required this.achievedPiastres,
    required this.targetPiastres,
    required this.accent,
  });
  final int achievedPiastres;
  final int targetPiastres;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final ratio = targetPiastres <= 0
        ? 0.0
        : (achievedPiastres / targetPiastres).clamp(0.0, 1.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ClipRRect(
          borderRadius: AppRadius.smAll,
          child: LinearProgressIndicator(
            value: ratio,
            minHeight: 6,
            backgroundColor: AppColors.darkBorder,
            valueColor: AlwaysStoppedAnimation<Color>(accent),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        // Scale down as one unit — "359,000 EGP of 1,000,000 EGP" can exceed a
        // narrow card, and the row must never overflow.
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.center,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              RollingNumber(
                value: achievedPiastres,
                formatter: (v) => formatEgp(v.round(), withSuffix: true),
                animateOnMount: true,
                duration: const Duration(milliseconds: 850),
                perPlaceStep: const Duration(milliseconds: 45),
                maxExtra: const Duration(milliseconds: 340),
                style: AppTypography.caption.copyWith(
                  color: accent,
                  fontWeight: FontWeight.w700,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              Text(
                ' of ${formatEgp(targetPiastres, withSuffix: true)}',
                style: AppTypography.caption.copyWith(
                  color: AppColors.textTertiary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
