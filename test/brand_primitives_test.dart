import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drop/core/widgets/brand_watermark.dart';
import 'package:drop/core/widgets/drop_auth_mark.dart';
import 'package:drop/core/widgets/drop_empty_state.dart';
import 'package:drop/core/widgets/drop_loading_state.dart';
import 'package:drop/core/widgets/drop_logo.dart';
import 'package:drop/core/widgets/drop_wordmark.dart';

void main() {
  Widget host(Widget child) =>
      MaterialApp(home: Scaffold(body: child));

  testWidgets('DropWordmark renders the Drop Operations logotype', (tester) async {
    await tester.pumpWidget(host(const DropWordmark()));
    expect(find.text('Drop Operations'), findsOneWidget);
  });

  testWidgets('DropEmptyState shows title + message (+ optional action)',
      (tester) async {
    await tester.pumpWidget(host(const DropEmptyState(
      title: 'All caught up',
      message: 'Nothing needs your attention.',
      action: Text('Do something'),
    )));
    expect(find.text('All caught up'), findsOneWidget);
    expect(find.text('Nothing needs your attention.'), findsOneWidget);
    expect(find.text('Do something'), findsOneWidget);
  });

  testWidgets('DropLoadingState renders its message and animates', (tester) async {
    await tester.pumpWidget(host(const DropLoadingState(message: 'Loading…')));
    expect(find.text('Loading…'), findsOneWidget);
    // Advance the pulse; the repeating controller is disposed at teardown. The
    // loader keeps rendering through the animation frame without error.
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Loading…'), findsOneWidget);
  });

  testWidgets('DropAuthMark shows the brand mark + tagline', (tester) async {
    await tester.pumpWidget(host(const DropAuthMark()));
    expect(find.text('DROP OPERATIONS SYSTEM'), findsOneWidget);
  });

  testWidgets('BrandWatermark renders its child + a faint wordmark',
      (tester) async {
    await tester.pumpWidget(host(
      const BrandWatermark(child: Text('hero content')),
    ));
    expect(find.text('hero content'), findsOneWidget);
    expect(find.text('Drop Operations'), findsOneWidget); // the watermark mark
  });

  testWidgets('BrandWatermark can use the real asset-backed DROP logo',
      (tester) async {
    await tester.pumpWidget(host(
      const BrandWatermark(
        assetLogo: true,
        child: Text('asset hero'),
      ),
    ));
    expect(find.text('asset hero'), findsOneWidget);
    expect(find.byType(DropLogo), findsOneWidget);
    expect(find.byType(DropWordmark), findsNothing);
  });

  test('BrandWatermark rejects an over-loud opacity', () {
    expect(() => BrandWatermark(opacity: 0.2, child: const SizedBox()),
        throwsA(isA<AssertionError>()));
  });
}
