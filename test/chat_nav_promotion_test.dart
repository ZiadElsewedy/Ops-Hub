import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:drop/core/routes/route_names.dart';
import 'package:drop/core/widgets/role_scaffold.dart';
import 'package:drop/core/widgets/user_avatar.dart';
import 'package:drop/features/auth/domain/entities/user_entity.dart';
import 'package:drop/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:drop/features/auth/presentation/cubit/auth_state.dart';
import 'package:drop/features/notifications/presentation/cubit/notification_cubit.dart';
import 'package:drop/features/notifications/presentation/cubit/notification_state.dart';

/// Navigation promotion (2026-07-22): Chat replaced Profile as the fourth
/// bottom-nav destination, and Profile moved into the More/Settings hub reached
/// by the app-bar avatar.

class _FakeAuthCubit extends Cubit<AuthState> implements AuthCubit {
  _FakeAuthCubit(UserEntity user) : super(AuthState.authenticated(user));
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeNotificationCubit extends Cubit<NotificationState>
    implements NotificationCubit {
  _FakeNotificationCubit() : super(const NotificationState.initial());
  @override
  int get unreadCount => 0;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

UserEntity _employee() => const UserEntity(
      uid: 'u1',
      email: 'u1@drop.test',
      displayName: 'Ziad Sewedy',
      authProvider: 'password',
      branchId: 'b1',
    );

Widget _harness(_FakeAuthCubit auth, _FakeNotificationCubit notifications) {
  final router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) =>
            const RoleScaffold(title: 'Dashboard', child: SizedBox()),
      ),
      GoRoute(
        path: RouteNames.chat,
        builder: (context, state) => const Scaffold(body: Text('CHAT INBOX')),
      ),
      GoRoute(
        path: RouteNames.settings,
        builder: (context, state) => const Scaffold(body: Text('SETTINGS HUB')),
      ),
    ],
  );
  return MultiBlocProvider(
    providers: [
      BlocProvider<AuthCubit>.value(value: auth),
      BlocProvider<NotificationCubit>.value(value: notifications),
    ],
    child: MaterialApp.router(routerConfig: router),
  );
}

void main() {
  late _FakeAuthCubit auth;
  late _FakeNotificationCubit notifications;

  setUp(() {
    auth = _FakeAuthCubit(_employee());
    notifications = _FakeNotificationCubit();
  });

  tearDown(() async {
    await auth.close();
    await notifications.close();
  });

  testWidgets('bottom nav shows Chat and no longer shows Profile',
      (tester) async {
    await tester.pumpWidget(_harness(auth, notifications));
    expect(find.text('Chat'), findsOneWidget);
    expect(find.text('Profile'), findsNothing);
    // The unchanged tabs are intact.
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Tasks'), findsOneWidget);
    expect(find.text('Schedule'), findsOneWidget);
  });

  testWidgets('tapping the Chat tab opens the conversation inbox',
      (tester) async {
    await tester.pumpWidget(_harness(auth, notifications));
    await tester.tap(find.text('Chat'));
    await tester.pumpAndSettle();
    expect(find.text('CHAT INBOX'), findsOneWidget);
  });

  testWidgets('tapping the app-bar avatar opens the More/Settings hub',
      (tester) async {
    await tester.pumpWidget(_harness(auth, notifications));
    // The trailing app-bar avatar is wrapped in the GestureDetector that routes
    // to the account hub; tapping the avatar hits it.
    await tester.tap(find.byType(UserAvatar));
    await tester.pumpAndSettle();
    expect(find.text('SETTINGS HUB'), findsOneWidget);
  });
}
