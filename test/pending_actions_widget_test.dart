import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opshub/features/admin/presentation/widgets/pending_actions.dart';

/// Renders the Admin Home Pending Actions panel headlessly to prove it actually
/// shows up (the earlier `if (count > 0)` gate made it vanish on empty data) and
/// that each queue row is tappable and routes through its callback. (Employee
/// approvals were removed — OpsHub is admin-provisioned, so there's no queue.)
void main() {
  Widget host(PendingActions p) => MaterialApp(
        home: Scaffold(body: SingleChildScrollView(child: p)),
      );

  testWidgets('renders a row per non-empty queue with correct labels', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        PendingActions(
          swaps: 2,
          reviews: 3,
          overdue: 0,
          onSwaps: () {},
          onReviews: () {},
          onOverdue: () {},
        ),
      ),
    );

    expect(find.text('2 Swap Requests'), findsOneWidget);
    expect(find.text('3 Tasks Waiting Review'), findsOneWidget);
    // overdue == 0 → no row
    expect(find.textContaining('Overdue'), findsNothing);
  });

  testWidgets('tapping a queue invokes its callback', (tester) async {
    var swapsTapped = false;
    await tester.pumpWidget(
      host(
        PendingActions(
          swaps: 1,
          reviews: 0,
          overdue: 0,
          onSwaps: () => swapsTapped = true,
          onReviews: () {},
          onOverdue: () {},
        ),
      ),
    );

    await tester.tap(find.text('1 Swap Request'));
    await tester.pump();
    expect(swapsTapped, isTrue);
  });

  testWidgets('shows an explicit all-clear state when everything is zero', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        PendingActions(
          swaps: 0,
          reviews: 0,
          overdue: 0,
          onSwaps: () {},
          onReviews: () {},
          onOverdue: () {},
        ),
      ),
    );

    // The panel still renders — it does not disappear.
    expect(find.text('Nothing queued'), findsOneWidget);
  });
}
