import 'package:drop/core/theme/app_colors.dart';
import 'package:drop/core/theme/app_spacing.dart';
import 'package:drop/features/sales/domain/sales_calculator.dart';
import 'package:drop/features/sales/domain/sales_trend.dart';
import 'package:drop/features/sales/presentation/sales_outlook_tint.dart';
import 'package:drop/features/sales/presentation/widgets/sales_month_overview.dart';
import 'package:drop/features/sales/presentation/widgets/sales_pace_card.dart';
import 'package:drop/features/sales/presentation/widgets/sales_progress_ring.dart';
import 'package:drop/features/sales/presentation/widgets/sales_submissions_door.dart';
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
    expect(find.text('ACHIEVED'), findsOneWidget);
    expect(find.text('REMAINING'), findsOneWidget);
    expect(find.text('TARGET'), findsOneWidget);
    expect(find.text('40.1%'), findsOneWidget);
  });

  test('outlook tint is green ahead, amber behind, white too-early', () {
    expect(salesOutlookTint(SalesTargetOutlook.ahead), AppColors.success);
    expect(salesOutlookTint(SalesTargetOutlook.behind), AppColors.warning);
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
    final achieved = tester.widget<Text>(find.text('401,332'));
    expect(achieved.style?.color, AppColors.success);
  });

  testWidgets('progress ring shows a capped whole at over-target', (
    tester,
  ) async {
    await _pumpPhone(tester, const SalesProgressRing(ratio: 1.4));
    expect(tester.takeException(), isNull);
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
