import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opshub/core/widgets/segmented_tab_bar.dart';

void main() {
  Widget host({
    required TabController controller,
    required List<String> tabs,
    List<int>? counts,
  }) =>
      MaterialApp(
        home: Scaffold(
          appBar: AppBar(
            bottom: SegmentedTabBar(
              controller: controller,
              tabs: tabs,
              counts: counts,
            ),
          ),
          body: TabBarView(
            controller: controller,
            children: [for (final t in tabs) Center(child: Text('$t page'))],
          ),
        ),
      );

  testWidgets('renders every segment label', (tester) async {
    final controller = TabController(length: 2, vsync: const TestVSync());
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      host(controller: controller, tabs: const ['Active', 'Done']),
    );

    expect(find.text('Active'), findsOneWidget);
    expect(find.text('Done'), findsOneWidget);
  });

  testWidgets('reports a 44px preferred height for the app bar slot', (
    tester,
  ) async {
    final controller = TabController(length: 2, vsync: const TestVSync());
    addTearDown(controller.dispose);
    final bar = SegmentedTabBar(controller: controller, tabs: const ['A', 'B']);
    expect(bar.preferredSize.height, 44);
  });

  testWidgets('tapping a segment drives the paired TabBarView', (tester) async {
    final controller = TabController(length: 2, vsync: const TestVSync());
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      host(controller: controller, tabs: const ['Active', 'Done']),
    );
    expect(controller.index, 0);
    expect(find.text('Active page'), findsOneWidget);

    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();

    expect(controller.index, 1);
    expect(find.text('Done page'), findsOneWidget);
  });

  testWidgets('draws a count only for segments with work in them', (
    tester,
  ) async {
    final controller = TabController(length: 4, vsync: const TestVSync());
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      host(
        controller: controller,
        tabs: const ['Active', 'Late', 'Missed', 'Done'],
        counts: const [0, 2, 1, 0],
      ),
    );

    // Every label still renders …
    for (final label in const ['Active', 'Late', 'Missed', 'Done']) {
      expect(find.text(label), findsOneWidget);
    }
    // … and only the non-zero counts appear beside them. A zero segment stays
    // a plain word rather than wearing a "0".
    expect(find.text('2'), findsOneWidget);
    expect(find.text('1'), findsOneWidget);
    expect(find.text('0'), findsNothing);
  });

  testWidgets('four counted segments fit a small phone without overflowing', (
    tester,
  ) async {
    // The narrowest phone DROP targets. Four segments plus counts is the
    // densest the control ever gets — if it fits here it fits everywhere.
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final controller = TabController(length: 4, vsync: const TestVSync());
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      host(
        controller: controller,
        tabs: const ['Active', 'Late', 'Missed', 'Done'],
        counts: const [0, 12, 34, 0],
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });
}
