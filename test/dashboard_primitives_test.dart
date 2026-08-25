import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opshub/core/widgets/activity_card.dart';
import 'package:opshub/core/widgets/attention_tile.dart';
import 'package:opshub/core/widgets/page_hero.dart';
import 'package:opshub/core/widgets/stat_strip.dart';

/// Widget tests for the reusable OpsHub Design System V2 primitives — the
/// building blocks every future module inherits. Rendered headlessly (no cubits,
/// no router) so they stay fast and stable.
void main() {
  Widget host(Widget child, {bool reduceMotion = false}) => MaterialApp(
        home: Scaffold(
          body: MediaQuery(
            data: MediaQueryData(disableAnimations: reduceMotion),
            child: SingleChildScrollView(child: child),
          ),
        ),
      );

  group('PageHero', () {
    testWidgets('renders eyebrow/title/subtitle and the single primary action',
        (tester) async {
      var tapped = false;
      await tester.pumpWidget(host(
        PageHero(
          eyebrow: 'Wed 8 Jul',
          title: 'Good morning, Ziad',
          subtitle: '8 branches · 42 employees · 3 running',
          subtitleIcon: Icons.public_rounded,
          primaryAction: ElevatedButton(
            key: const Key('cta'),
            onPressed: () => tapped = true,
            child: const Text('Create Task'),
          ),
        ),
      ));

      expect(find.text('WED 8 JUL'), findsOneWidget); // eyebrow is uppercased
      expect(find.text('Good morning, Ziad'), findsOneWidget);
      expect(find.text('8 branches · 42 employees · 3 running'), findsOneWidget);

      await tester.tap(find.byKey(const Key('cta')));
      expect(tapped, isTrue);
    });
  });

  group('AttentionTile', () {
    testWidgets('shows the count + label and fires onTap', (tester) async {
      var tapped = false;
      await tester.pumpWidget(host(
        AttentionTile(
          icon: Icons.event_busy_outlined,
          label: 'Overdue',
          sublabel: 'Past the deadline',
          count: 3,
          accent: Colors.red,
          onTap: () => tapped = true,
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('3'), findsOneWidget);
      expect(find.text('Overdue'), findsOneWidget);
      expect(find.text('Past the deadline'), findsOneWidget);
      // Accessible: exposes a composed "N label" button semantics.
      expect(
        find.byWidgetPredicate((w) =>
            w is Semantics &&
            w.properties.button == true &&
            w.properties.label == '3 Overdue'),
        findsOneWidget,
      );

      await tester.tap(find.byType(AttentionTile));
      expect(tapped, isTrue);
    });

    testWidgets('renders the count immediately under reduced motion',
        (tester) async {
      await tester.pumpWidget(host(
        AttentionTile(
          icon: Icons.rate_review_outlined,
          label: 'Pending review',
          count: 7,
          onTap: () {},
        ),
        reduceMotion: true,
      ));
      // No pumpAndSettle: with disableAnimations the AnimatedCount has zero
      // duration, so the final value is on screen on the first frame.
      await tester.pump();
      expect(find.text('7'), findsOneWidget);
    });

    testWidgets('a cleared tile rewards the healthy state (no bare "0")',
        (tester) async {
      await tester.pumpWidget(host(
        AttentionTile(
          icon: Icons.event_busy_outlined,
          label: 'Overdue',
          sublabel: 'Past the deadline',
          clearedMessage: 'No overdue tasks',
          count: 0,
          onTap: () {},
        ),
      ));
      await tester.pumpAndSettle();

      // The positive message shows instead of a switched-off "0".
      expect(find.text('No overdue tasks'), findsOneWidget);
      expect(find.text('0'), findsNothing);
      // Still an accessible button that announces the cleared state.
      expect(
        find.byWidgetPredicate((w) =>
            w is Semantics &&
            w.properties.button == true &&
            (w.properties.label?.contains('all clear') ?? false)),
        findsOneWidget,
      );
    });
  });

  group('StatStrip', () {
    testWidgets('renders each stat value + label', (tester) async {
      await tester.pumpWidget(host(
        const StatStrip(
          stats: [
            Stat(label: 'Completed today', value: '5'),
            Stat(label: 'Running now', value: '2'),
            Stat(label: 'Delayed', value: '1'),
            Stat(label: 'Approval rate', value: '96%'),
          ],
        ),
      ));

      expect(find.text('Completed today'), findsOneWidget);
      expect(find.text('96%'), findsOneWidget);
      expect(find.text('Delayed'), findsOneWidget);
    });

    testWidgets('a count stat renders its number (+suffix) via count-up',
        (tester) async {
      await tester.pumpWidget(host(
        const StatStrip(
          stats: [
            Stat(label: 'Running now', count: 4),
            Stat(label: 'Approval rate', count: 96, suffix: '%'),
          ],
        ),
        // Reduced motion → AnimatedCount has zero duration, so the final figure
        // is on screen on the first frame (no pumpAndSettle needed).
        reduceMotion: true,
      ));
      await tester.pump();

      expect(find.text('4'), findsOneWidget);
      expect(find.text('96%'), findsOneWidget);
    });
  });

  group('ActivityCard', () {
    testWidgets('renders slots and fires onTap', (tester) async {
      var tapped = false;
      await tester.pumpWidget(host(
        ActivityCard(
          leading: const Icon(Icons.person_outline),
          title: 'Open the shop',
          subtitle: 'Ahmed · Arkan branch',
          trailing: const Text('Waiting Review'),
          meta: '5 min ago',
          onTap: () => tapped = true,
        ),
      ));

      expect(find.text('Open the shop'), findsOneWidget);
      expect(find.text('Ahmed · Arkan branch'), findsOneWidget);
      expect(find.text('Waiting Review'), findsOneWidget);
      expect(find.text('5 min ago'), findsOneWidget);

      await tester.tap(find.byType(ActivityCard));
      expect(tapped, isTrue);
    });
  });
}
