import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:opshub/core/theme/app_colors.dart';
import 'package:opshub/features/task/presentation/submission_progress.dart';

/// The single, state-driven submission overlay. Rendered by the Task Details
/// screen in a Stack whenever `TaskState.isSubmitting` — it fills the screen,
/// **absorbs all input**, and shows nothing but the animated Lottie loader
/// (`assets/submission_loading.json`). Because it's driven by cubit state (not a
/// dialog), exactly one ever exists and it survives rebuilds / navigation.
///
/// The Lottie is forced to DROP's monochrome white via [LottieDelegates] so it
/// stays on-brand (ADR-004); reduced motion collapses it to a still frame.
class SubmissionLoadingOverlay extends StatelessWidget {
  const SubmissionLoadingOverlay({
    super.key,
    required this.progress,
    this.onCancel,
  });

  /// Retained for the cubit-driven contract; the overlay is now purely visual.
  final SubmissionProgress progress;
  final VoidCallback? onCancel;

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    return Stack(
      children: [
        // Dim barrier — absorbs every tap so the screen underneath stays inert.
        Positioned.fill(
          child: GestureDetector(
            onTap: () {},
            behavior: HitTestBehavior.opaque,
            child: ColoredBox(color: Colors.black.withAlpha(175)),
          ),
        ),
        Center(
          child: Lottie.asset(
            'assets/submission_loading.json',
            width: 140,
            repeat: !reduceMotion,
            animate: !reduceMotion,
            delegates: LottieDelegates(
              values: [
                // Force every stroke/fill to the monochrome accent so the
                // loader can never introduce a brand colour (ADR-004).
                ValueDelegate.color(const ['**'], value: AppColors.primary),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
