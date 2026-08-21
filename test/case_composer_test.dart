import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opshub/features/cases/presentation/widgets/case_composer.dart';
import 'package:opshub/core/media/picked_attachment.dart';

void main() {
  Widget host({
    required Future<bool> Function(String, List<PickedAttachment>) onSend,
    bool closed = false,
    bool canReopen = false,
    VoidCallback? onReopen,
  }) =>
      MaterialApp(
        home: Scaffold(
          body: CaseComposer(
            onSend: onSend,
            sending: false,
            closed: closed,
            canReopen: canReopen,
            onReopen: onReopen,
          ),
        ),
      );

  testWidgets('keeps the typed text when the send fails', (tester) async {
    await tester.pumpWidget(host(onSend: (_, _) async => false));
    await tester.enterText(find.byType(TextField), 'my reply');
    await tester.tap(find.byIcon(Icons.arrow_upward_rounded));
    await tester.pumpAndSettle();

    // The message must survive a failed send so the user can retry, not retype.
    expect(find.text('my reply'), findsOneWidget);
  });

  testWidgets('clears the input after a successful send', (tester) async {
    await tester.pumpWidget(host(onSend: (_, _) async => true));
    await tester.enterText(find.byType(TextField), 'my reply');
    await tester.tap(find.byIcon(Icons.arrow_upward_rounded));
    await tester.pumpAndSettle();

    expect(find.text('my reply'), findsNothing);
  });

  testWidgets('does not call onSend for an empty message', (tester) async {
    var calls = 0;
    await tester.pumpWidget(host(onSend: (_, _) async {
      calls++;
      return true;
    }));
    await tester.tap(find.byIcon(Icons.arrow_upward_rounded));
    await tester.pumpAndSettle();
    expect(calls, 0);
  });

  testWidgets('closed case shows a read-only bar with an optional Reopen',
      (tester) async {
    var reopened = false;
    await tester.pumpWidget(host(
      onSend: (_, _) async => true,
      closed: true,
      canReopen: true,
      onReopen: () => reopened = true,
    ));
    expect(find.textContaining('read-only'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
    await tester.tap(find.text('Reopen'));
    expect(reopened, isTrue);
  });
}
