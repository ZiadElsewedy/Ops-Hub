import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:drop/core/theme/app_colors.dart';
import 'package:drop/core/theme/app_radius.dart';
import 'package:drop/core/theme/app_spacing.dart';
import 'package:drop/core/theme/app_typography.dart';
import 'package:drop/core/widgets/glass_container.dart';
import 'package:drop/features/sales/domain/entities/sales_record_result.dart';
import 'package:drop/features/sales/presentation/sales_format.dart';

/// The celebratory "+59,000 EGP added to the branch total" confirmation shown
/// once, after a manager/admin records a day directly.
///
/// It counts the figure up from zero, then rests. Strictly monochrome
/// (ADR-004): the amount is white, and the only chromatic pixel is the
/// **success** tint that appears **exclusively** when this record is the one
/// that reached the monthly target — colour as status, never decoration.
/// Reduced motion collapses every transition to a still frame.
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
      return Opacity(
        opacity: animation.value.clamp(0.0, 1.0),
        child: Transform.scale(
          scale: scale,
          child: Center(
            child: _SalesRecordAddedCard(result: result),
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

class _SalesRecordAddedCardState extends State<_SalesRecordAddedCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  Timer? _autoDismiss;
  var _started = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    // A gentle tick to acknowledge the money landing.
    HapticFeedback.mediumImpact();
    // Auto-dismiss so the celebration never traps the screen; a tap still closes.
    _autoDismiss = Timer(const Duration(milliseconds: 2600), () {
      if (mounted && Navigator.of(context).canPop()) Navigator.of(context).pop();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    // Only animate the count-up when motion is allowed; under reduced motion the
    // figure rests at its final value from the first frame (never a frozen 0).
    final reduceMotion = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (reduceMotion) {
      _controller.value = 1;
    } else {
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _autoDismiss?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final result = widget.result;
    final crossed = result.crossedTarget;
    final accent = crossed ? AppColors.success : AppColors.primary;

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.pagePadding),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: GestureDetector(
          onTap: () {
            if (Navigator.of(context).canPop()) Navigator.of(context).pop();
          },
          child: GlassContainer(
            glow: crossed ? AppColors.success : null,
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.xl,
              vertical: AppSpacing.xxl,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _Medallion(crossed: crossed, accent: accent),
                const SizedBox(height: AppSpacing.lg),
                AnimatedBuilder(
                  animation: _controller,
                  builder: (context, _) {
                    final shown =
                        (result.amountPiastres * _controller.value).round();
                    return Text(
                      '+ ${formatEgp(shown, withSuffix: true)}',
                      textAlign: TextAlign.center,
                      style: AppTypography.displayMedium.copyWith(color: accent),
                    );
                  },
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  crossed
                      ? 'Monthly target reached 🎉'
                      : 'added to the branch total',
                  textAlign: TextAlign.center,
                  style: AppTypography.body.copyWith(
                    color: crossed ? AppColors.success : AppColors.textSecondary,
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
        Text(
          '${formatEgp(achievedPiastres, withSuffix: true)} of ${formatEgp(targetPiastres, withSuffix: true)}',
          textAlign: TextAlign.center,
          style: AppTypography.caption.copyWith(color: AppColors.textTertiary),
        ),
      ],
    );
  }
}
