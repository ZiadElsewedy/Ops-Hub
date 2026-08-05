import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:drop/core/enums/user_role.dart';
import 'package:drop/core/routes/route_names.dart';
import 'package:drop/features/auth/domain/entities/user_entity.dart';
import 'package:drop/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:drop/features/auth/presentation/cubit/auth_state.dart';
import 'package:drop/features/settings/presentation/pages/settings_page.dart';

class _FakeAuthCubit extends Cubit<AuthState> implements AuthCubit {
  _FakeAuthCubit()
    : super(
        const AuthState.authenticated(
          UserEntity(
            uid: 'admin-1',
            email: 'ziad@drop.test',
            displayName: 'Ziad Elsewedy',
            authProvider: 'password',
            role: UserRole.admin,
          ),
        ),
      );

  bool didSignOut = false;

  @override
  Future<void> signOut() async => didSignOut = true;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Widget _harness(_FakeAuthCubit auth) {
  final router = GoRouter(
    initialLocation: RouteNames.settings,
    routes: [
      GoRoute(
        path: RouteNames.settings,
        builder: (_, _) => const SettingsPage(),
      ),
      GoRoute(
        path: RouteNames.profile,
        builder: (_, _) => const Scaffold(body: Text('PROFILE DESTINATION')),
      ),
      GoRoute(
        path: RouteNames.changePassword,
        builder: (_, _) => const Scaffold(body: Text('PASSWORD DESTINATION')),
      ),
      GoRoute(
        path: RouteNames.cases,
        builder: (_, _) => const Scaffold(body: Text('CASES DESTINATION')),
      ),
      GoRoute(
        path: RouteNames.about,
        builder: (_, _) => const Scaffold(body: Text('ABOUT DESTINATION')),
      ),
    ],
  );
  return BlocProvider<AuthCubit>.value(
    value: auth,
    child: MaterialApp.router(routerConfig: router),
  );
}

void main() {
  late _FakeAuthCubit auth;

  setUp(() => auth = _FakeAuthCubit());
  tearDown(() => auth.close());

  testWidgets(
    'premium account hub leads with real identity and keeps actions',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(_harness(auth));
      await tester.pumpAndSettle();

      expect(find.text('Ziad Elsewedy'), findsOneWidget);
      expect(find.text('ziad@drop.test'), findsOneWidget);
      expect(find.text('ADMIN'), findsOneWidget);
      expect(find.text('Change password'), findsOneWidget);
      expect(find.text('Cases'), findsOneWidget);
      expect(find.text('About Drop Operation'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.tap(find.text('View and edit profile'));
      await tester.pumpAndSettle();
      expect(find.text('PROFILE DESTINATION'), findsOneWidget);
    },
  );

  testWidgets('sign out remains available as a separate destructive action', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_harness(auth));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Sign out'), 300);
    await tester.tap(find.text('Sign out'));
    await tester.pump();

    expect(auth.didSignOut, isTrue);
    expect(tester.takeException(), isNull);
  });
}
