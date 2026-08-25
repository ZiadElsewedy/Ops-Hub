import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:opshub/core/routes/route_names.dart';
import 'package:opshub/features/auth/presentation/pages/landing_page.dart';

Widget _harness() {
  final router = GoRouter(
    initialLocation: RouteNames.landing,
    routes: [
      GoRoute(
        path: RouteNames.landing,
        builder: (_, _) => const LandingPage(),
      ),
      GoRoute(
        path: RouteNames.login,
        builder: (_, _) => const Scaffold(body: Text('LOGIN DESTINATION')),
      ),
    ],
  );
  return MaterialApp.router(routerConfig: router);
}

void main() {
  testWidgets(
    'landing leads with the brand, the positioning line and what is inside',
    (tester) async {
      await tester.pumpWidget(_harness());
      // Let the staggered entrance play (delays run to ~800 ms).
      await tester.pump(const Duration(milliseconds: 1200));

      expect(find.text('OpsHub'), findsWidgets); // lockup + hero mark semantics
      expect(find.text('OPERATIONS'), findsOneWidget);
      expect(find.text('Every branch.\nOne hub.'), findsOneWidget);
      expect(find.text('Sign in'), findsOneWidget);

      // The feature grid names the product's pillars.
      expect(find.text('Tasks with proof'), findsOneWidget);
      expect(find.text('GPS attendance'), findsOneWidget);
      expect(find.text('Schedules & swaps'), findsOneWidget);
      expect(find.text('Sales targets'), findsOneWidget);

      // Unmount so the page's animators and timers are disposed cleanly.
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('the only way forward is signing in', (tester) async {
    await tester.pumpWidget(_harness());
    await tester.pump(const Duration(milliseconds: 1200));

    await tester.ensureVisible(find.text('Sign in'));
    await tester.pump();
    await tester.tap(find.text('Sign in'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('LOGIN DESTINATION'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
  });
}
