import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opshub/core/enums/broadcast_audience.dart';
import 'package:opshub/core/enums/user_role.dart';
import 'package:opshub/features/communications/domain/entities/broadcast_entity.dart';
import 'package:opshub/features/communications/presentation/widgets/broadcast_card.dart';

/// Headless render test for the Communications Center feed item — proves it
/// surfaces the required fields (title, body preview, sender, audience, category,
/// delivery status) and is tappable, without a Firebase connection.
void main() {
  Future<void> pump(WidgetTester tester, BroadcastEntity b,
          {VoidCallback? onTap}) =>
      tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: BroadcastCard(broadcast: b, onTap: onTap ?? () {}),
        ),
      ));

  testWidgets('shows title, body, sender, audience, category and delivery',
      (tester) async {
    final b = BroadcastEntity(
      id: 'b1',
      title: 'Stock count tonight',
      message: 'Please count the back room before you close up.',
      senderId: 'mgr-1',
      senderName: 'Ziad',
      senderRole: UserRole.manager,
      audience: BroadcastAudience.branch,
      branchId: 'branch-7',
      category: 'reminder',
      recipientCount: 24,
      deliveredCount: 21,
      createdAt: DateTime.now(),
    );
    await pump(tester, b);

    expect(find.text('Stock count tonight'), findsOneWidget);
    expect(
        find.textContaining('count the back room'), findsOneWidget); // body
    expect(find.text('Ziad'), findsOneWidget); // sender
    expect(find.text('Branch'), findsOneWidget); // audience pill
    expect(find.text('Reminder'), findsOneWidget); // category
    expect(find.text('Delivered 21/24'), findsOneWidget); // delivery status
  });

  testWidgets('tapping the card fires onTap', (tester) async {
    var tapped = false;
    final b = BroadcastEntity(
      id: 'b2',
      title: 'Welcome',
      message: 'Hello team',
      senderId: 'admin-1',
      senderName: 'HQ',
      audience: BroadcastAudience.allBranches,
      category: 'announcement',
      recipientCount: 100,
      createdAt: DateTime.now(),
    );
    await pump(tester, b, onTap: () => tapped = true);

    expect(find.text('Everyone'), findsOneWidget); // all-branches audience
    // No deliveredCount yet → falls back to the recipient count.
    expect(find.text('100 recipients'), findsOneWidget);

    await tester.tap(find.byType(BroadcastCard));
    await tester.pump();
    expect(tapped, isTrue);
  });

  testWidgets('selection checkbox reports changes and highlights the card',
      (tester) async {
    var selected = false;
    final b = BroadcastEntity(
      id: 'select-me',
      title: 'Selectable broadcast',
      message: 'Bulk actions use this selection.',
      senderId: 'admin-1',
      senderName: 'Admin',
      audience: BroadcastAudience.allBranches,
      category: 'announcement',
      createdAt: DateTime.now(),
    );

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: StatefulBuilder(builder: (context, setState) {
          return BroadcastCard(
            broadcast: b,
            selected: selected,
            onSelected: (value) => setState(() => selected = value),
            onTap: () {},
          );
        }),
      ),
    ));

    final checkbox = find.byKey(const ValueKey('select-select-me'));
    expect(checkbox, findsOneWidget);
    expect(tester.widget<Checkbox>(checkbox).value, isFalse);

    await tester.tap(checkbox);
    await tester.pump();

    expect(selected, isTrue);
    expect(tester.widget<Checkbox>(checkbox).value, isTrue);
  });
}
