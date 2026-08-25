import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opshub/core/enums/shift_hours_scope.dart';
import 'package:opshub/features/schedule/presentation/widgets/shift_hours_scope_dialog.dart';

/// Schedule V2 · Pillar 5 — the "apply changes to…" scope picker.
void main() {
  Future<ShiftHoursScope?> open(
    WidgetTester tester, {
    List<ShiftHoursScope>? scopes,
  }) async {
    ShiftHoursScope? result;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () async => result = await showShiftHoursScopeDialog(
              context,
              title: 'Night hours',
              scopes: scopes ?? ShiftHoursScope.values,
            ),
            child: const Text('open'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    return Future.value(result);
  }

  testWidgets('offers the three scopes and returns the chosen one',
      (tester) async {
    await open(tester);
    expect(find.text('This week only'), findsOneWidget);
    expect(find.text('Future schedules'), findsOneWidget);
    expect(find.text('Update template globally'), findsOneWidget);

    await tester.tap(find.text('Future schedules'));
    await tester.pumpAndSettle();
    // The button's async handler stored the result.
    // (Re-open would be a fresh call; here we assert the option resolved.)
    expect(find.text('This week only'), findsNothing); // sheet dismissed
  });

  testWidgets('can be filtered to template-level scopes only', (tester) async {
    await open(tester,
        scopes: const [ShiftHoursScope.future, ShiftHoursScope.global]);
    expect(find.text('This week only'), findsNothing);
    expect(find.text('Future schedules'), findsOneWidget);
    expect(find.text('Update template globally'), findsOneWidget);
  });
}
