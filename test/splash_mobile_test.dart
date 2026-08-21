import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opshub/core/widgets/animated_opshub_logo.dart';
import 'package:opshub/core/widgets/opshub_logo.dart';
import 'package:opshub/features/auth/presentation/pages/splash_page.dart';

/// The mobile cold-start splash (phone widths < 600) — the local, Lottie-free
/// intro. These prove the premium mobile treatment: the animated light-sweep
/// hero logo (matching the desktop splash + login panel), the OPERATIONS
/// wordmark, the completion hand-off, and that the animation-gated startup
/// error still shows through the staggered entrance.
void main() {
  const phone = Size(390, 844);

  Future<void> pumpMobileSplash(
    WidgetTester tester, {
    required Widget Function(BuildContext) build,
  }) async {
    tester.view.physicalSize = phone;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(home: Builder(builder: build)));
    await tester.pump();
  }

  testWidgets(
    'mobile splash leads with the animated (light-sweep) hero logo + OPERATIONS',
    (tester) async {
      await pumpMobileSplash(
        tester,
        build: (_) =>
            SplashPage(onAnimationComplete: () {}, isBootstrapping: true),
      );

      // AnimatedOpsHubLogo is the hero (desktop-consistent premium treatment);
      // the desktop splash uses the Lottie instead, so its presence also proves
      // the mobile branch was taken.
      expect(find.byType(AnimatedOpsHubLogo), findsOneWidget);
      // AnimatedOpsHubLogo renders a OpsHubLogo internally.
      expect(find.byType(OpsHubLogo), findsWidgets);
      expect(find.text('OPERATIONS'), findsOneWidget);

      // Let the intro + ambient controllers settle for a clean teardown.
      await tester.pump(const Duration(seconds: 2));
    },
  );

  testWidgets('mobile splash reports completion after the ~1.8s intro', (
    tester,
  ) async {
    var completed = false;
    await pumpMobileSplash(
      tester,
      build: (_) => SplashPage(
        onAnimationComplete: () => completed = true,
        isBootstrapping: true,
      ),
    );

    expect(completed, isFalse, reason: 'must not fire before the intro ends');
    await tester.pump(const Duration(milliseconds: 1900));
    expect(completed, isTrue, reason: 'intro completion hands off to the parent');
  });

  testWidgets(
    'startup error stays visible through the staggered entrance + Retry works',
    (tester) async {
      var retried = false;
      // A host that can flip the bootstrap error in after the intro, exactly
      // as LaunchApp does once bootstrap resolves.
      Object? error;
      late StateSetter setHost;

      tester.view.physicalSize = phone;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
          home: StatefulBuilder(
            builder: (context, setState) {
              setHost = setState;
              return SplashPage(
                onAnimationComplete: () {},
                isBootstrapping: false,
                bootstrapError: error,
                onRetry: () => retried = true,
              );
            },
          ),
        ),
      );
      await tester.pump();

      // Intro plays out; the error is animation-gated so nothing shows yet.
      await tester.pump(const Duration(milliseconds: 1900));
      expect(find.textContaining('could not start'), findsNothing);

      // Bootstrap resolves with a failure → parent rebuilds with the error.
      setHost(() => error = Exception('boom'));
      await tester.pump();

      expect(find.textContaining('could not start'), findsOneWidget);
      await tester.tap(find.text('Try again'));
      expect(retried, isTrue);

      await tester.pump(const Duration(seconds: 1));
    },
  );
}
