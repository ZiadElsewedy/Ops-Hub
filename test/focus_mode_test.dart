import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opshub/core/responsive/breakpoints.dart';
import 'package:opshub/core/widgets/app_shell.dart';
import 'package:opshub/core/widgets/app_sidebar.dart';
import 'package:opshub/features/auth/domain/entities/user_entity.dart';
import 'package:opshub/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:opshub/features/auth/presentation/cubit/auth_state.dart';
import 'package:opshub/features/notifications/presentation/cubit/notification_cubit.dart';
import 'package:opshub/features/notifications/presentation/cubit/notification_state.dart';

/// Schedule V2 · Pillar 1 — Focus Mode. Collapsing the shell sidebar hands the
/// active screen the full width, and the choice survives while the shell stays
/// mounted. The GlobalKey shell Navigator (the child) must never be remounted
/// by the toggle, so we assert the content simply slides to x=0 and back.

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

Future<void> _pumpShell(WidgetTester tester) async {
  // A desktop-width surface so AppShell renders the persistent sidebar chrome
  // (below 1024 it is a mobile pass-through with no sidebar).
  tester.view.physicalSize = const Size(1200, 800);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

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
      home: AppShell(
        location: '/',
        child: SizedBox.expand(key: Key('shell-child')),
      ),
    ),
  ));
  await tester.pumpAndSettle();
}

void main() {
  double childLeft(WidgetTester tester) =>
      tester.getTopLeft(find.byKey(const Key('shell-child'))).dx;

  testWidgets('collapse control hands the content the full width', (tester) async {
    await _pumpShell(tester);

    // Sidebar present; content begins one sidebar-width in.
    expect(find.byType(AppSidebar), findsOneWidget);
    expect(childLeft(tester), Breakpoints.sidebarWidth);

    // Hide the sidebar via the header control.
    await tester.tap(find.byIcon(Icons.menu_open_rounded));
    await tester.pumpAndSettle();

    // Content now starts at the left edge; the restore handle is offered.
    expect(childLeft(tester), 0);
    expect(find.byIcon(Icons.menu_rounded), findsOneWidget);
  });

  testWidgets('restore handle brings the sidebar back', (tester) async {
    await _pumpShell(tester);

    await tester.tap(find.byIcon(Icons.menu_open_rounded));
    await tester.pumpAndSettle();
    expect(childLeft(tester), 0);

    // Tap the floating "show sidebar" handle.
    await tester.tap(find.byIcon(Icons.menu_rounded));
    await tester.pumpAndSettle();

    expect(childLeft(tester), Breakpoints.sidebarWidth);
  });

  testWidgets('the shell child element is never remounted by the toggle',
      (tester) async {
    await _pumpShell(tester);

    final before = tester.element(find.byKey(const Key('shell-child')));

    await tester.tap(find.byIcon(Icons.menu_open_rounded));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.menu_rounded));
    await tester.pumpAndSettle();

    // Same Element across both toggles — the GlobalKey Navigator was never
    // duplicated/rebuilt (the macOS nav-freeze failure mode).
    expect(tester.element(find.byKey(const Key('shell-child'))), same(before));
  });
}
