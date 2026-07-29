import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drop/core/theme/app_theme.dart';
import 'package:drop/core/widgets/app_search_field.dart';

/// Regression test for the "search box looks like a field-inside-a-field" bug.
///
/// The global [InputDecorationTheme] sets `filled: true` + outline
/// `enabledBorder`/`focusedBorder`; the search field must neutralise ALL of them
/// so it renders as one clean surface. This locks those overrides in.
void main() {
  testWidgets(
    'AppSearchField neutralises the global input theme (no inner box)',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          home: Scaffold(
            body: AppSearchField(hint: 'Search branches', onChanged: (_) {}),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.text('Search branches'), findsOneWidget);

      final field = tester.widget<TextField>(find.byType(TextField));
      final d = field.decoration!;
      expect(d.filled, isFalse, reason: 'must not inherit the theme fill');
      expect(d.border, InputBorder.none);
      expect(d.enabledBorder, InputBorder.none);
      expect(d.focusedBorder, InputBorder.none);
      expect(d.isCollapsed, isTrue, reason: 'no default 48px min-height box');
    },
  );

  testWidgets('supports compact header sizing with caller-owned focus', (
    tester,
  ) async {
    final focus = FocusNode();
    addTearDown(focus.dispose);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: Scaffold(
          body: AppSearchField(
            hint: 'Search conversations...',
            focusNode: focus,
            height: 40,
            onChanged: (_) {},
          ),
        ),
      ),
    );

    expect(tester.getSize(find.byType(AppSearchField)), const Size(800, 40));
    await tester.tap(find.byType(TextField));
    await tester.pump();
    expect(focus.hasFocus, isTrue);
  });
}
