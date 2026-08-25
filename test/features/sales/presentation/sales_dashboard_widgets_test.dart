import 'package:opshub/core/theme/app_colors.dart';
import 'package:opshub/core/theme/app_spacing.dart';
import 'package:opshub/core/widgets/rolling_number.dart';
import 'package:opshub/features/sales/domain/sales_calculator.dart';
import 'package:opshub/features/sales/domain/sales_trend.dart';
import 'package:opshub/features/sales/presentation/sales_outlook_tint.dart';
import 'package:opshub/features/sales/presentation/widgets/sales_month_overview.dart';
import 'package:opshub/features/sales/presentation/widgets/sales_pace_card.dart';
import 'package:opshub/features/sales/presentation/widgets/sales_progress_ring.dart';
import 'package:opshub/features/sales/presentation/widgets/sales_submissions_door.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Pumps [child] at a 375pt phone width inside the dashboard's page padding, so
/// any RenderFlex overflow in these custom layouts surfaces as a test failure.
Future<void> _pumpPhone(WidgetTester tester, Widget child) async {
  tester.view.physicalSize = const Size(375, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.pagePadding),
            child: child,
          ),
        ),
      ),
    ),
  );
}

SalesTrend _trend() => SalesTrend(
  days: [
    for (var i = 6; i >= 0; i--)
      SalesTrendDay(
        businessDateKey: '2026080${4 + (6 - i)}',
        approvedPiastres: (1420000 + (6 - i) * 200000),
        isToday: i == 0,
      ),
  ],
  averagePerDayPiastres: 1824000,
  previousAveragePerDayPiastres: 1600000,
);

void main() {
  testWidgets('month overview renders its three facts without overflow', (
    tester,
  ) async {
    await _pumpPhone(
      tester,
      const SalesMonthOverview(
        targetPiastres: 100000000, // 1,000,000 EGP
        achievedPiastres: 40133200, // 401,332 EGP
        remainingPiastres: 59866800, // 598,668 EGP
        progressRatio: 0.401,
      ),
    );
    expect(tester.takeException(), isNull);
    await tester.pumpAndSettle(); // reels + ring land on their final figures
    expect(find.text('ACHIEVED'), findsOneWidget);
    expect(find.text('REMAINING'), findsOneWidget);
    expect(find.text('TARGET'), findsOneWidget);
    // Progress reads in the ring; remaining carries the "% left" footnote.
    expect(find.text('40.1%'), findsOneWidget);
    expect(find.text('59.9% left'), findsOneWidget);
  });

  test('outlook tint is emerald ahead, gold behind, white too-early', () {
    expect(salesOutlookTint(SalesTargetOutlook.ahead), AppColors.salesEmerald);
    expect(salesOutlookTint(SalesTargetOutlook.behind), AppColors.salesAmber);
    expect(salesOutlookTint(SalesTargetOutlook.tooEarly), AppColors.primary);
  });

  testWidgets('the ahead tint reaches the ACHIEVED figure', (tester) async {
    await _pumpPhone(
      tester,
      SalesMonthOverview(
        targetPiastres: 100000000,
        achievedPiastres: 40133200,
        remainingPiastres: 59866800,
        progressRatio: 0.401,
        tint: salesOutlookTint(SalesTargetOutlook.ahead),
      ),
    );
    await tester.pumpAndSettle();
    // The ACHIEVED figure is the first rolling figure in the hero row (then
    // REMAINING, then TARGET); its style carries the outlook tint down to the
    // digit reels.
    final figures =
        tester.widgetList<RollingNumber>(find.byType(RollingNumber)).toList();
    expect(figures, isNotEmpty);
    expect(figures.first.style.color, AppColors.salesEmerald);
  });

  testWidgets('progress ring shows a capped whole at over-target', (
    tester,
  ) async {
    await _pumpPhone(tester, const SalesProgressRing(ratio: 1.4));
    expect(tester.takeException(), isNull);
    await tester.pumpAndSettle(); // the sweep lands on the capped value
    expect(find.text('100%'), findsOneWidget);
  });

  testWidgets('pace card leads with the ahead verdict and the chart', (
    tester,
  ) async {
    await _pumpPhone(
      tester,
      SalesPaceCard(
        trend: _trend(),
        outlook: SalesTargetOutlook.ahead,
        projectedDeltaPiastres: 5066800,
      ),
    );
    expect(tester.takeException(), isNull);
    expect(find.textContaining('ahead of target'), findsOneWidget);
    expect(find.text('Today'), findsOneWidget);
    // The +12% trend chip against the previous window.
    expect(find.textContaining('vs prev'), findsOneWidget);
  });

  testWidgets('submissions door is one tappable row with the breakdown', (
    tester,
  ) async {
    var tapped = false;
    await _pumpPhone(
      tester,
      SalesSubmissionsDoor(
        pending: 0,
        approved: 2,
        rejected: 0,
        total: 2,
        onTap: () => tapped = true,
      ),
    );
    expect(tester.takeException(), isNull);
    expect(find.text('All submissions'), findsOneWidget);
    await tester.tap(find.text('All submissions'));
    expect(tapped, isTrue);
  });
}
