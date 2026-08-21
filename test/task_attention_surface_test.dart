import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opshub/core/enums/task_status.dart';
import 'package:opshub/core/theme/app_colors.dart';
import 'package:opshub/features/task/presentation/widgets/task_attention_surface.dart';

/// The standing rule these guard (see the design contract): **nothing on a
/// resting surface animates forever.** A card that has been acknowledged must
/// leave no controller running — otherwise every settled task on Home burns a
/// frame callback for the life of the screen.
void main() {
  Widget host({required bool attention, bool reduceMotion = false}) =>
      MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(disableAnimations: reduceMotion),
          child: Scaffold(
            backgroundColor: AppColors.darkBg,
            body: Center(
              child: SizedBox(
                width: 340,
                height: 160,
                child: TaskAttentionSurface(
                  tone: taskAttentionTone(
                    attention ? TaskStatus.pending : TaskStatus.started,
                    unseen: attention,
                  ),
                  attention: attention,
                  child: const ColoredBox(color: AppColors.darkSurface),
                ),
              ),
            ),
          ),
        ),
      );

  testWidgets('a resting card never starts the shimmer', (tester) async {
    await tester.pumpWidget(host(attention: false));
    // Settles immediately — nothing is animating.
    await tester.pumpAndSettle();
    expect(find.byType(TaskAttentionSurface), findsOneWidget);
  });

  testWidgets('acknowledging a card stops it animating', (tester) async {
    await tester.pumpWidget(host(attention: true));
    await tester.pump(const Duration(seconds: 1)); // mid-shimmer

    await tester.pumpWidget(host(attention: false));
    // Times out if the 9s loop were left running after the card settled.
    await tester.pumpAndSettle();
    expect(find.byType(TaskAttentionSurface), findsOneWidget);
  });

  testWidgets('reduced motion drops the shimmer, keeps the card new', (
    tester,
  ) async {
    await tester.pumpWidget(host(attention: true, reduceMotion: true));
    // The static layers still render; only the 9s sweep is withheld, so the
    // tree settles instead of animating forever.
    await tester.pumpAndSettle();
    expect(find.byType(TaskAttentionSurface), findsOneWidget);
  });

  testWidgets('an armed card tears down cleanly', (tester) async {
    await tester.pumpWidget(host(attention: true));
    await tester.pump(const Duration(seconds: 2));
    // Disposing mid-shimmer must not leave a controller behind.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    expect(find.byType(TaskAttentionSurface), findsNothing);
  });
}
