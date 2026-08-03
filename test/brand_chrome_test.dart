import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drop/core/widgets/adaptive_scaffold.dart';
import 'package:drop/core/widgets/animated_drop_logo.dart';
import 'package:drop/core/widgets/app_sidebar.dart';
import 'package:drop/core/widgets/drop_logo.dart';
import 'package:drop/core/widgets/role_scaffold.dart';
import 'package:drop/features/auth/domain/entities/user_entity.dart';
import 'package:drop/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:drop/features/auth/presentation/cubit/auth_state.dart';
import 'package:drop/features/notifications/presentation/cubit/notification_cubit.dart';
import 'package:drop/features/notifications/presentation/cubit/notification_state.dart';

/// Brand-rollout chrome checks (2026-07-02): the real DROP artwork
/// (`assets/drop_logo.png`, via [DropLogo]) must lead the role-home app bar,
/// the desktop sidebar lockup, and close every mobile [AdaptiveScaffold] app
/// bar — so the brand is present on the homepage and all migrated screens.

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

void main() {
  // The default 800×600 test surface is below the 1024 desktop breakpoint,
  // so AdaptiveScaffold/RoleScaffold render their MOBILE chrome here.
  testWidgets('AdaptiveScaffold mobile app bar carries the DROP mark',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: AdaptiveScaffold(title: 'Tasks', body: SizedBox()),
    ));

    expect(
      find.descendant(of: find.byType(AppBar), matching: find.byType(DropLogo)),
      findsOneWidget,
    );
  });

  testWidgets('AdaptiveScaffold brand mark can be opted out', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: AdaptiveScaffold(
        title: 'Tasks',
        body: SizedBox(),
        showBrandMark: false,
      ),
    ));

    expect(find.byType(DropLogo), findsNothing);
  });

  testWidgets('AppSidebar brand header uses the static real logo artwork',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: AppSidebar(
          sections: const [
            SidebarSection(items: [
              SidebarItem(
                icon: Icons.home_outlined,
                activeIcon: Icons.home_rounded,
                label: 'Home',
                route: '/',
              ),
            ]),
          ],
          location: '/',
          onSelect: (_) {},
        ),
      ),
    ));

    expect(find.byType(DropLogo), findsOneWidget);
    expect(find.byType(AnimatedDropLogo), findsNothing);
  });

  testWidgets('AnimatedDropLogo renders the artwork and loops without error',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: Center(child: AnimatedDropLogo(height: 60))),
    ));

    expect(find.byType(DropLogo), findsOneWidget);
    // The shimmer repeats forever (pumpAndSettle would hang) — step through
    // more than one full 3200ms cycle to prove the loop is well-behaved.
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 1500));
    await tester.pump(const Duration(milliseconds: 3300));
    expect(find.byType(AnimatedDropLogo), findsOneWidget);
  });

  testWidgets('RoleScaffold home app bar leads with the DROP lockup',
      (tester) async {
    final auth = _FakeAuthCubit(_employee());
    final notifications = _FakeNotificationCubit();
    addTearDown(() async {
      await auth.close();
      await notifications.close();
    });

    await tester.pumpWidget(MultiBlocProvider(
      providers: [
        BlocProvider<AuthCubit>.value(value: auth),
        BlocProvider<NotificationCubit>.value(value: notifications),
      ],
      child: const MaterialApp(
        home: RoleScaffold(title: 'Dashboard', child: SizedBox()),
      ),
    ));

    expect(
      find.descendant(of: find.byType(AppBar), matching: find.byType(DropLogo)),
      findsOneWidget,
    );
    // The role word is no longer drawn beside the mark — it was the first thing
    // a crowded action cluster truncated ("Mana…") and each home's hero already
    // names the user and their scope. It survives as the bar's accessible label.
    expect(find.text('Dashboard'), findsNothing);
    expect(
      tester.getSemantics(
        find.descendant(
          of: find.byType(AppBar),
          matching: find.byType(DropLogo),
        ),
      ),
      matchesSemantics(label: 'Dashboard', isHeader: true, isImage: true),
    );
  });
}
