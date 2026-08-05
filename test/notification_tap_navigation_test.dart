import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:drop/core/enums/user_role.dart';
import 'package:drop/core/routes/route_names.dart';
import 'package:drop/core/routes/router_extensions.dart';
import 'package:drop/features/notifications/presentation/notification_navigation.dart';

/// **What happens when a push notification is tapped.**
///
/// Three reported symptoms, one root area: the tap opened the notifications
/// page with no way back to Home, sometimes threw, and sometimes did nothing
/// at all. All three came from navigating a router that has no stack yet:
///
/// * `router.state` throws `Bad state: No element` on an empty match list —
///   inside the tap handler, so nothing navigated ("it errors / does nothing");
/// * `push` onto an unattached router is dropped ("it doesn't open");
/// * `go` *does* work there, so the unresolved-tap fallback
///   `go('/notifications')` was the one path that landed — and it replaced the
///   whole stack, leaving the inbox with nothing underneath it. The inbox
///   carries no bottom nav (only the three role shells do) and could not pop,
///   so there was no back button on any platform and, since the iOS chevron
///   was dropped, no back gesture either. A hard dead end.
///
/// A cold start sits squarely in that window: DROP holds the routed app behind
/// the bootstrap *and* the ~2s splash intro, while `getInitialMessage()`
/// resolves in milliseconds.
///
/// These use a stand-in router with the app's real path shapes so the
/// navigation policy is tested on its own, without every app-wide cubit a role
/// shell needs. The real routes are covered in
/// `notification_tap_flow_probe_test.dart`.
void main() {
  Widget page(String label) =>
      Scaffold(body: Center(child: Text(label, textDirection: TextDirection.ltr)));

  GoRouter buildRouter({String initialLocation = RouteNames.home}) => GoRouter(
    initialLocation: initialLocation,
    routes: [
      GoRoute(path: RouteNames.home, builder: (_, _) => page('home')),
      GoRoute(
        path: RouteNames.notifications,
        builder: (_, _) => page('inbox'),
      ),
      GoRoute(
        path: RouteNames.mySchedule,
        builder: (_, _) => page('schedule'),
      ),
    ],
  );

  Future<GoRouter> attached(
    WidgetTester tester, {
    String initialLocation = RouteNames.home,
  }) async {
    final router = buildRouter(initialLocation: initialLocation);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();
    return router;
  }

  group('an attached router (foreground / background tap)', () {
    testWidgets('an unresolved tap opens the inbox ON TOP of Home', (
      tester,
    ) async {
      final router = await attached(tester);

      // `destination: null` — a stale payload, an unknown route, or a recipient
      // with nothing safe to open.
      openNotificationDeepLink(
        router,
        destination: null,
        role: UserRole.employee,
      );
      await tester.pumpAndSettle();

      expect(find.text('inbox'), findsOneWidget);
      expect(router.canPop(), isTrue, reason: 'Home must sit underneath');
      router.pop();
      await tester.pumpAndSettle();
      expect(find.text('home'), findsOneWidget);
    });

    testWidgets('a resolved tap also lands on top of Home', (tester) async {
      final router = await attached(tester);

      openNotificationDeepLink(
        router,
        destination: RouteNames.mySchedule,
        role: UserRole.employee,
      );
      await tester.pumpAndSettle();

      expect(find.text('schedule'), findsOneWidget);
      expect(router.canPop(), isTrue);
      router.pop();
      await tester.pumpAndSettle();
      expect(find.text('home'), findsOneWidget);
    });

    testWidgets('a second tap replaces the first instead of stacking on it', (
      tester,
    ) async {
      final router = await attached(tester);

      openNotificationDeepLink(
        router,
        destination: RouteNames.notifications,
        role: UserRole.employee,
      );
      await tester.pumpAndSettle();
      openNotificationDeepLink(
        router,
        destination: RouteNames.mySchedule,
        role: UserRole.employee,
      );
      await tester.pumpAndSettle();

      // Back walks to Home, not backwards through every notification ever
      // tapped — which is the stack a bare `push` per tap used to build.
      expect(find.text('schedule'), findsOneWidget);
      router.pop();
      await tester.pumpAndSettle();
      expect(find.text('home'), findsOneWidget);
    });

    testWidgets('re-tapping the notification for the open page is a no-op', (
      tester,
    ) async {
      final router = await attached(
        tester,
        initialLocation: RouteNames.notifications,
      );

      openNotificationDeepLink(
        router,
        destination: RouteNames.notifications,
        role: UserRole.employee,
      );
      await tester.pumpAndSettle();

      expect(find.text('inbox'), findsOneWidget);
      expect(
        router.canPop(),
        isFalse,
        reason: 'no duplicate of the page already on screen',
      );
    });

    testWidgets('a tap with no restored session navigates nowhere', (
      tester,
    ) async {
      final router = await attached(tester);

      // Role is null until the session is restored. Anything pushed here would
      // only be bounced to Login by the redirect gate, so the tap is a
      // deliberate no-op rather than a flicker.
      openNotificationDeepLink(
        router,
        destination: RouteNames.notifications,
        role: null,
      );
      await tester.pumpAndSettle();

      expect(find.text('home'), findsOneWidget);
      expect(router.canPop(), isFalse);
    });
  });

  group('an unattached router (cold start from a killed app)', () {
    testWidgets('the tap survives until the routed app mounts', (tester) async {
      final router = buildRouter();

      // The tap handler runs BEFORE the routed app is built — the ordinary
      // cold-start ordering. This used to throw here and lose the destination.
      openNotificationDeepLink(
        router,
        destination: RouteNames.mySchedule,
        role: UserRole.employee,
      );
      expect(tester.takeException(), isNull);
      expect(router.currentLocationOrNull, isNull, reason: 'no stack yet');

      // The splash finishes and the routed app mounts.
      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();

      expect(find.text('schedule'), findsOneWidget);
      expect(router.canPop(), isTrue, reason: 'and Home is still underneath');
    });

    testWidgets('an unresolved cold-start tap is not a dead end either', (
      tester,
    ) async {
      final router = buildRouter();

      openNotificationDeepLink(
        router,
        destination: null,
        role: UserRole.employee,
      );
      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();

      expect(find.text('inbox'), findsOneWidget);
      expect(router.canPop(), isTrue);
      router.pop();
      await tester.pumpAndSettle();
      expect(find.text('home'), findsOneWidget);
    });

    testWidgets('the retry gives up rather than waiting forever', (
      tester,
    ) async {
      final router = buildRouter();
      var ran = false;
      // A tap is not worth leaking a permanent per-frame callback if the app
      // never finishes mounting.
      router.whenReady(() => ran = true, maxFrames: 2);
      await tester.pump();
      await tester.pump();
      await tester.pump();
      expect(ran, isFalse);
      expect(tester.takeException(), isNull);
    });
  });
}
