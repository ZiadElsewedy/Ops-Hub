import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opshub/core/enums/user_role.dart';
import 'package:opshub/core/services/notification_preferences_store.dart';
import 'package:opshub/features/auth/domain/entities/user_entity.dart';
import 'package:opshub/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:opshub/features/auth/presentation/cubit/auth_state.dart';
import 'package:opshub/features/settings/presentation/pages/notifications_settings_screen.dart';

class _FakeAuthCubit extends Cubit<AuthState> implements AuthCubit {
  _FakeAuthCubit()
    : super(
        const AuthState.authenticated(
          UserEntity(
            uid: 'employee-1',
            email: 'ziad@drop.test',
            displayName: 'Ziad Elsewedy',
            authProvider: 'password',
            role: UserRole.employee,
          ),
        ),
      );

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Widget _harness(_FakeAuthCubit auth, NotificationPreferencesStore store) =>
    BlocProvider<AuthCubit>.value(
      value: auth,
      child: MaterialApp(home: NotificationsSettingsScreen(store: store)),
    );

/// The switch belonging to [label] — each row merges its label and control into
/// one subtree, so scoping by the row's `Column` finds exactly one.
Finder _switchFor(String label) => find.ancestor(
  of: find.text(label),
  matching: find.byType(MergeSemantics),
);

Switch _switchWidget(WidgetTester tester, String label) => tester.widget<Switch>(
  find.descendant(of: _switchFor(label), matching: find.byType(Switch)),
);

void main() {
  late _FakeAuthCubit auth;
  late NotificationPreferencesStore store;

  setUp(() {
    auth = _FakeAuthCubit();
    store = NotificationPreferencesStore();
  });
  tearDown(() => auth.close());

  Future<void> pumpScreen(WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_harness(auth, store));
    await tester.pumpAndSettle();
  }

  testWidgets('renders the six switches, all on by default', (tester) async {
    await pumpScreen(tester);

    for (final label in const [
      'Enable Notifications',
      'Task Reminders',
      'Schedule Updates',
      'Case Messages',
      'Announcements',
      'Sound',
    ]) {
      expect(find.text(label), findsOneWidget, reason: label);
      expect(_switchWidget(tester, label).value, isTrue, reason: label);
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('a toggle persists to the store', (tester) async {
    await pumpScreen(tester);

    await tester.tap(find.text('Task Reminders'));
    await tester.pumpAndSettle();

    expect(_switchWidget(tester, 'Task Reminders').value, isFalse);
    expect(store.preferences.taskReminders, isFalse);
  });

  testWidgets(
    'turning the master off disables the rest without clearing them',
    (tester) async {
      await pumpScreen(tester);

      await tester.tap(find.text('Enable Notifications'));
      await tester.pumpAndSettle();

      // Functionally disabled: a null onChanged is what makes a Material or a
      // Cupertino switch reject input.
      for (final label in const [
        'Task Reminders',
        'Schedule Updates',
        'Case Messages',
        'Announcements',
        'Sound',
      ]) {
        expect(_switchWidget(tester, label).onChanged, isNull, reason: label);
      }
      // The master itself stays operable.
      expect(_switchWidget(tester, 'Enable Notifications').onChanged, isNotNull);

      // Tapping a disabled row changes nothing.
      await tester.tap(find.text('Case Messages'));
      await tester.pumpAndSettle();
      expect(store.preferences.caseMessages, isTrue);

      // Turning the master back on restores the user's exact set.
      await tester.tap(find.text('Enable Notifications'));
      await tester.pumpAndSettle();
      expect(_switchWidget(tester, 'Case Messages').onChanged, isNotNull);
      expect(_switchWidget(tester, 'Case Messages').value, isTrue);
    },
  );

  testWidgets('reopening the screen shows the stored values', (tester) async {
    await pumpScreen(tester);
    await tester.tap(find.text('Sound'));
    await tester.pumpAndSettle();
    expect(store.preferences.sound, isFalse);

    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
    await pumpScreen(tester);

    expect(_switchWidget(tester, 'Sound').value, isFalse);
  });
}
