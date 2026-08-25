import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opshub/core/widgets/action_card.dart';

void main() {
  Widget host(Widget child, {double width = 150}) => MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(width: width, child: child),
          ),
        ),
      );

  testWidgets('primary action labels wrap instead of ellipsizing', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        ActionCard(
          icon: Icons.person_add_alt_1_outlined,
          title: 'Create Account',
          onTap: () {},
        ),
        width: 105,
      ),
    );

    final label = tester.widget<Text>(find.text('Create Account'));
    expect(label.maxLines, isNull);
    expect(label.overflow, isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('secondary treatment keeps title and subtitle readable', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        ActionCard(
          icon: Icons.settings_outlined,
          title: 'Settings',
          subtitle: 'App & account',
          secondary: true,
          onTap: () {},
        ),
        width: 145,
      ),
    );

    expect(find.text('Settings'), findsOneWidget);
    final subtitle = tester.widget<Text>(find.text('App & account'));
    expect(subtitle.maxLines, isNull);
    expect(subtitle.overflow, isNull);
    expect(find.byIcon(Icons.chevron_right_rounded), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
