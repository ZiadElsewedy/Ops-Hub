import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opshub/core/enums/task_status.dart';
import 'package:opshub/core/theme/app_colors.dart';
import 'package:opshub/core/widgets/app_glass_card.dart';
import 'package:opshub/core/widgets/metric_pill.dart';
import 'package:opshub/core/widgets/premium_button.dart';

void main() {
  group('AppGlassCard.glowForTaskStatus (subtle semantic glow, no indigo)', () {
    test(
      'only reviewed/awaiting states glow; active/resting stay monochrome',
      () {
        expect(
          AppGlassCard.glowForTaskStatus(TaskStatus.approved),
          AppColors.success,
        );
        expect(
          AppGlassCard.glowForTaskStatus(TaskStatus.waitingReview),
          AppColors.warning,
        );
        expect(
          AppGlassCard.glowForTaskStatus(TaskStatus.rejected),
          AppColors.error,
        );
        // No indigo "active" glow — these are monochrome (null).
        expect(AppGlassCard.glowForTaskStatus(TaskStatus.pending), isNull);
        expect(AppGlassCard.glowForTaskStatus(TaskStatus.started), isNull);
        expect(AppGlassCard.glowForTaskStatus(TaskStatus.completed), isNull);
        expect(AppGlassCard.glowForTaskStatus(TaskStatus.missed), isNull);
      },
    );
  });

  Widget host(Widget child) => MaterialApp(
    home: Scaffold(body: Center(child: child)),
  );

  testWidgets('AppGlassCard renders its child', (tester) async {
    await tester.pumpWidget(host(const AppGlassCard(child: Text('inside'))));
    expect(find.text('inside'), findsOneWidget);
  });

  testWidgets('MetricPill shows value + label (+ optional icon)', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        const MetricPill(
          value: '3',
          label: 'reviews',
          icon: Icons.rate_review_rounded,
        ),
      ),
    );
    expect(find.text('3'), findsOneWidget);
    expect(find.text('reviews'), findsOneWidget);
    expect(find.byIcon(Icons.rate_review_rounded), findsOneWidget);
  });

  testWidgets('PremiumButton renders label + icon and fires onPressed', (
    tester,
  ) async {
    var tapped = false;
    await tester.pumpWidget(
      host(
        PremiumButton(
          label: 'Reopen',
          icon: Icons.lock_open_rounded,
          onPressed: () => tapped = true,
        ),
      ),
    );
    expect(find.text('Reopen'), findsOneWidget);
    expect(find.byIcon(Icons.lock_open_rounded), findsOneWidget);
    await tester.tap(find.text('Reopen'));
    expect(tapped, isTrue);
  });

  testWidgets('PremiumButton with null onPressed does not fire', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(const PremiumButton(label: 'Disabled', onPressed: null)),
    );
    // Tapping a disabled button is a no-op (no exception, nothing to assert
    // beyond it rendering).
    await tester.tap(find.text('Disabled'));
    expect(find.text('Disabled'), findsOneWidget);
  });
}
