import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drop/features/sales/domain/entities/sales_record_result.dart';
import 'package:drop/features/sales/presentation/widgets/sales_record_added_overlay.dart';

void main() {
  Future<void> pumpOverlay(WidgetTester tester, SalesRecordResult result) async {
    await tester.pumpWidget(
      MaterialApp(
        // Reduced motion so the count-up jumps straight to the final figure.
        home: MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () => showSalesRecordAddedOverlay(context, result),
                  child: const Text('go'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('go'));
    await tester.pump(); // open the dialog route
    // Let the count-up finish (900ms) but stay well under the 2.6s auto-dismiss.
    await tester.pump(const Duration(milliseconds: 1500));
  }

  testWidgets('shows the amount added and the achieved-of-target line', (tester) async {
    await pumpOverlay(
      tester,
      const SalesRecordResult(
        amountPiastres: 5900000, // 59,000 EGP
        achievedPiastres: 35900000,
        targetPiastres: 100000000,
        crossedTarget: false,
      ),
    );

    expect(find.text('+ 59,000 EGP'), findsOneWidget);
    expect(find.text('added to the branch total'), findsOneWidget);
    expect(find.textContaining('359,000 EGP of 1,000,000 EGP'), findsOneWidget);
    expect(find.text('Monthly target reached 🎉'), findsNothing);

    // Tap to dismiss so no auto-dismiss timer is left pending.
    await tester.tapAt(const Offset(5, 5));
    await tester.pumpAndSettle();
  });

  testWidgets('celebrates the target crossing when this record reached it', (tester) async {
    await pumpOverlay(
      tester,
      const SalesRecordResult(
        amountPiastres: 20000000,
        achievedPiastres: 100000000,
        targetPiastres: 100000000,
        crossedTarget: true,
      ),
    );

    expect(find.text('Monthly target reached 🎉'), findsOneWidget);

    await tester.tapAt(const Offset(5, 5));
    await tester.pumpAndSettle();
  });
}
