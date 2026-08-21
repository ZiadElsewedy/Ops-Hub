import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opshub/core/widgets/responsive_card_grid.dart';

void main() {
  // Host the grid at a chosen logical width so the breakpoint-based column count
  // (mobile < 600 → 1 col; desktop ≥ 1024 → 2 cols) can be exercised.
  Widget hostAtWidth(double width, Widget child) => MediaQuery(
        data: MediaQueryData(size: Size(width, 900)),
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(width: width, child: child),
          ),
        ),
      );

  const children = [
    Text('a'),
    Text('b'),
    Text('c'),
  ];

  testWidgets('renders every child', (tester) async {
    await tester.pumpWidget(
        hostAtWidth(1400, const ResponsiveCardGrid(children: children)));
    expect(find.text('a'), findsOneWidget);
    expect(find.text('b'), findsOneWidget);
    expect(find.text('c'), findsOneWidget);
  });

  testWidgets('mobile width stays a single column (no row grid)',
      (tester) async {
    await tester.pumpWidget(
        hostAtWidth(500, const ResponsiveCardGrid(children: children)));
    expect(find.byType(IntrinsicHeight), findsNothing);
  });

  testWidgets(
      'desktop width lays out in row-chunked columns that stretch to match',
      (tester) async {
    await tester.pumpWidget(
        hostAtWidth(1400, const ResponsiveCardGrid(children: children)));
    // 3 children, 2 desktop columns → 2 rows, each an IntrinsicHeight-wrapped
    // Row so shorter cards stretch to match a taller row sibling.
    expect(find.byType(IntrinsicHeight), findsNWidgets(2));
  });

  testWidgets('empty children collapse to nothing', (tester) async {
    await tester.pumpWidget(
        hostAtWidth(1400, const ResponsiveCardGrid(children: [])));
    expect(find.byType(IntrinsicHeight), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('maxItemWidth caps card width (no card wider than the limit)',
      (tester) async {
    await tester.pumpWidget(hostAtWidth(
        1200, const ResponsiveCardGrid(maxItemWidth: 400, children: children)));
    // 1200 / 400 = 3 columns → each card well under 400 wide.
    for (final w in tester.widgetList<SizedBox>(find.descendant(
        of: find.byType(IntrinsicHeight), matching: find.byType(SizedBox)))) {
      if (w.width != null) expect(w.width, lessThanOrEqualTo(400));
    }
  });

  testWidgets('maxItemWidth stays single column when width is small',
      (tester) async {
    await tester.pumpWidget(hostAtWidth(
        380, const ResponsiveCardGrid(maxItemWidth: 480, children: children)));
    expect(find.byType(IntrinsicHeight), findsNothing);
  });
}
