import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drop/core/routes/app_page_route.dart';
import 'package:drop/core/theme/app_theme.dart';
import 'package:drop/core/widgets/adaptive_scaffold.dart';

/// **The back-navigation contract** (`core/routes/app_page_route.dart`).
///
/// On iOS a pushed page carries the native interactive left-edge swipe-back
/// **in addition to** the app bar's back button — both affordances, always,
/// exactly as in Apple's own apps. Every platform keeps its back button.
///
/// The half that silently rots is the gesture: it exists only on Cupertino
/// routes, so a screen pushed on a hand-rolled `PageRouteBuilder` loses it
/// without anything looking broken. Both halves are pinned here.
void main() {
  const phone = Size(390, 844);
  final iOS = TargetPlatformVariant.only(TargetPlatform.iOS);
  final android = TargetPlatformVariant.only(TargetPlatform.android);

  /// Pumps a first screen and pushes [child] through [appPageRoute] — the seam
  /// every imperative page push in the app goes through.
  Future<void> pushPage(
    WidgetTester tester,
    Widget child, {
    bool modal = false,
  }) async {
    tester.view.physicalSize = phone;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () => Navigator.of(context).push(
                  appPageRoute<void>(
                    builder: (_) => child,
                    fullscreenDialog: modal,
                  ),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  group('the chrome', () {
    testWidgets(
      'iOS: a pushed AdaptiveScaffold keeps its back button',
      (tester) async {
        await pushPage(
          tester,
          const AdaptiveScaffold(title: 'Detail', body: SizedBox.shrink()),
        );

        expect(find.text('Detail'), findsOneWidget);
        expect(find.byType(BackButton), findsOneWidget);
      },
      variant: iOS,
    );

    testWidgets(
      'Android: the same screen keeps its back button too',
      (tester) async {
        await pushPage(
          tester,
          const AdaptiveScaffold(title: 'Detail', body: SizedBox.shrink()),
        );

        expect(find.byType(BackButton), findsOneWidget);
      },
      variant: android,
    );

    testWidgets(
      'iOS: an explicit leading still overrides the automatic button',
      (tester) async {
        await pushPage(
          tester,
          AdaptiveScaffold(
            title: 'Drill-down',
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_rounded),
              onPressed: () {},
            ),
            body: const SizedBox.shrink(),
          ),
        );

        expect(find.byIcon(Icons.arrow_back_rounded), findsOneWidget);
      },
      variant: iOS,
    );

    testWidgets(
      'iOS: a full-screen modal keeps a close control — it has no back gesture',
      (tester) async {
        await pushPage(
          tester,
          const AdaptiveScaffold(title: 'Form', body: SizedBox.shrink()),
          modal: true,
        );

        expect(find.byType(CloseButton), findsOneWidget);
      },
      variant: iOS,
    );
  });

  group('the route', () {
    testWidgets(
      'iOS: a pushed page carries the interactive back gesture',
      (tester) async {
        await pushPage(
          tester,
          const AdaptiveScaffold(title: 'Detail', body: SizedBox.shrink()),
        );

        // Dragging from the left edge pops the route — the affordance the app
        // bar's button cannot provide, and the one that silently disappears if
        // a page is ever pushed on a plain PageRouteBuilder.
        await tester.dragFrom(const Offset(2, 400), const Offset(340, 0));
        await tester.pumpAndSettle();

        expect(find.text('Detail'), findsNothing);
        expect(find.text('open'), findsOneWidget);
      },
      variant: iOS,
    );

    testWidgets(
      'iOS: a full-screen modal is NOT swipe-dismissable',
      (tester) async {
        await pushPage(
          tester,
          const AdaptiveScaffold(title: 'Form', body: SizedBox.shrink()),
          modal: true,
        );

        await tester.dragFrom(const Offset(2, 400), const Offset(340, 0));
        await tester.pumpAndSettle();

        expect(find.text('Form'), findsOneWidget);
      },
      variant: iOS,
    );

    testWidgets(
      'iOS pushes land on a Cupertino route',
      (tester) async {
        expect(
          appPageRoute<void>(builder: (_) => const SizedBox()),
          isA<CupertinoPageRoute<void>>(),
        );
      },
      variant: iOS,
    );

    testWidgets(
      'Android pushes keep the app\'s own PageRouteBuilder motion',
      (tester) async {
        expect(
          appPageRoute<void>(builder: (_) => const SizedBox()),
          isA<PageRouteBuilder<void>>(),
        );
      },
      variant: android,
    );
  });

  group('the platform split', () {
    test('only iOS carries the edge-swipe gesture', () {
      expect(isGestureBackPlatform(TargetPlatform.iOS), isTrue);
      expect(isGestureBackPlatform(TargetPlatform.android), isFalse);
      // Desktop navigates back with AdaptiveScaffold's in-header control.
      expect(isGestureBackPlatform(TargetPlatform.macOS), isFalse);
    });

    test('iOS pushes use the only transition that carries the gesture', () {
      final builders = AppTheme.dark.pageTransitionsTheme.builders;
      expect(
        builders[TargetPlatform.iOS],
        isA<CupertinoPageTransitionsBuilder>(),
      );
      // Android is untouched: its own transition, its own back button.
      expect(
        builders[TargetPlatform.android],
        isA<ZoomPageTransitionsBuilder>(),
      );
    });
  });
}
