import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opshub/features/auth/presentation/pages/splash_page.dart';

/// Proves the cold-start splash lockup is TRUE-CENTERED — the logo/wordmark/
/// bar column shares the window's horizontal centre — at a macOS window size.
/// This is a layout assertion against the real widget, not a claim.
void main() {
  Future<void> pumpSplashAt(WidgetTester tester, Size size) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        home: SplashPage(onAnimationComplete: () {}, isBootstrapping: true),
      ),
    );
    // The desktop lockup is a static OpsHubLogo (no Lottie, no asset load to
    // wait on) — one frame is enough to lay it all out.
    await tester.pump();
  }

  testWidgets('column stays horizontally centered on a 1440×900 macOS window',
      (tester) async {
    await pumpSplashAt(tester, const Size(1440, 900));
    final column = tester.getRect(find.byType(Column).first);
    expect(column.center.dx, moreOrLessEquals(1440 / 2, epsilon: 0.5));
  });

  testWidgets('OPERATIONS glyphs (not the text box) are horizontally centered', (
    tester,
  ) async {
    await pumpSplashAt(tester, const Size(1440, 900));

    // This engine appends letterSpacing (12) after the LAST glyph too
    // (verified by TextPainter: width('AB', ls:12) - width('AB', ls:0) == 24),
    // so the glyph run sits 6px left of the text box centre. The page
    // compensates with a 12px leading pad; net: glyph centre == text box
    // centre − 6 == window centre.
    final textRect = tester.getRect(find.text('OPERATIONS'));
    final glyphCentreX = textRect.center.dx - 12 / 2;
    expect(
      glyphCentreX,
      moreOrLessEquals(1440 / 2, epsilon: 0.5),
      reason: 'OPERATIONS glyph run must be centred on the window',
    );
  });

  testWidgets('column stays horizontally centered at the minimum window', (
    tester,
  ) async {
    await pumpSplashAt(tester, const Size(1024, 720));
    final column = tester.getRect(find.byType(Column).first);
    expect(column.center.dx, moreOrLessEquals(1024 / 2, epsilon: 0.5));
  });
}
