// Drives the REAL app router + NotificationsScreen + broadcast deep-link with
// the real cubits over fakes, exercising the FCM broadcast-tap flow end to end
// (Notifications V2 — deep-link regression coverage):
//   A) employee lands on /notifications (OS tap target); tapping a broadcast is
//      a guarded no-op (employees can't open broadcast detail);
//   B) admin taps the broadcast tile → /communications/:id detail, which
//      self-resolves the broadcast by id even though the feed was never loaded
//      (B3 fix — previously dead-ended on "Broadcast unavailable");
//   C) cold-start ordering: go('/notifications') BEFORE the router is attached
//      with initialLocation '/', proving the role home never has to build.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drop/core/enums/notification_type.dart';
import 'package:drop/core/enums/broadcast_audience.dart';
import 'package:drop/core/enums/user_role.dart';
import 'package:drop/core/routes/app_router.dart';
import 'package:drop/features/auth/domain/entities/user_entity.dart';
import 'package:drop/features/auth/domain/repositories/auth_repository.dart';
import 'package:drop/features/auth/domain/usecases/change_password.dart';
import 'package:drop/features/auth/domain/usecases/forgot_password.dart';
import 'package:drop/features/auth/domain/usecases/get_user.dart';
import 'package:drop/features/auth/domain/usecases/get_users_by_branch.dart';
import 'package:drop/features/auth/domain/usecases/sign_in_with_email.dart';
import 'package:drop/features/auth/domain/usecases/sign_out.dart';
import 'package:drop/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:drop/features/branch/domain/entities/branch_entity.dart';
import 'package:drop/features/branch/domain/repositories/branch_repository.dart';
import 'package:drop/features/communications/domain/entities/broadcast_entity.dart';
import 'package:drop/features/communications/domain/repositories/broadcast_repository.dart';
import 'package:drop/features/communications/domain/usecases/send_broadcast.dart';
import 'package:drop/features/communications/presentation/cubit/broadcast_cubit.dart';
import 'package:drop/features/notifications/domain/entities/notification_entity.dart';
import 'package:drop/features/notifications/domain/repositories/notification_repository.dart';
import 'package:drop/features/notifications/domain/usecases/mark_notification_read.dart';
import 'package:drop/features/notifications/presentation/cubit/notification_cubit.dart';
import 'package:drop/features/notifications/presentation/pages/notifications_screen.dart';

// ─── Fakes ───────────────────────────────────────────────────────────

class FakeAuthRepository implements AuthRepository {
  FakeAuthRepository(this.user);
  final UserEntity user;

  @override
  Stream<UserEntity?> get authStateChanges => const Stream.empty();
  @override
  UserEntity? get currentUser => user;
  @override
  Future<UserEntity?> getUser(String uid) async => user;
  @override
  Stream<UserEntity?> watchUser(String uid) => const Stream.empty();
  @override
  Future<List<UserEntity>> getUsersByBranch(String branchId) async => [user];
  @override
  Future<List<UserEntity>> getAllUsers() async => [user];
  @override
  Future<UserEntity> signInWithEmail(
          {required String email, required String password}) async =>
      user;
  @override
  Future<void> signOut() async {}
  @override
  Future<void> sendPasswordResetEmail(String email) async {}
  @override
  Future<void> changePassword(
      {required String currentPassword, required String newPassword}) async {}
  @override
  Future<void> setMustChangePassword(String uid, bool value) async {}
  @override
  Future<void> setProfileCompleted(String uid, bool value) async {}
  @override
  Future<void> setOnboardingCompleted(String uid, bool value) async {}
}

class FakeNotificationRepository implements NotificationRepository {
  FakeNotificationRepository(this.items);
  final List<NotificationEntity> items;
  final List<String> markedRead = [];

  @override
  Stream<List<NotificationEntity>> watch(String uid, {int limit = 30}) =>
      Stream.value(items);
  @override
  Future<void> markRead(String id) async => markedRead.add(id);
  @override
  Future<void> markAllRead(String uid) async {}
  @override
  Future<void> create(NotificationEntity notification) async {}
  @override
  Future<void> createMany(List<NotificationEntity> notifications) async {}
  @override
  Future<void> delete(String id) async {}
  @override
  Future<void> setArchived(String id, bool archived) async {}
  @override
  Future<void> setPinned(String id, bool pinned) async {}
}

class FakeBroadcastRepository implements BroadcastRepository {
  FakeBroadcastRepository(this.items);
  final List<BroadcastEntity> items;

  @override
  Stream<List<BroadcastEntity>> watchBroadcasts({String? branchId}) =>
      Stream.value(items);
  @override
  Future<BroadcastEntity> sendBroadcast(BroadcastEntity broadcast,
          {List<String> targetUserIds = const [], String roleFilter = ''}) async =>
      broadcast;
  @override
  Future<void> setArchived(String id, bool archived) async {}
  @override
  Future<void> delete(String id) async {}
  @override
  Future<BroadcastEntity?> getBroadcast(String id) async {
    for (final b in items) {
      if (b.id == id) return b;
    }
    return null;
  }
}

class FakeBranchRepository implements BranchRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) {
    final name = invocation.memberName.toString();
    if (name.contains('getBranches')) return Future.value(<BranchEntity>[]);
    return super.noSuchMethod(invocation);
  }
}

UserEntity userWith(UserRole role) => UserEntity(
      uid: 'u1',
      email: 'u1@drop.app',
      authProvider: 'password',
      displayName: 'Probe User',
      role: role,
      branchId: 'b1',
      isActive: true,
      isProfileCompleted: true,
      hasCompletedOnboarding: true,
    );

NotificationEntity broadcastNotification() => NotificationEntity(
      id: 'n-broadcast',
      recipientUid: 'u1',
      senderUid: 'admin1',
      type: NotificationType.broadcastReminder,
      title: 'Team Meeting',
      body: 'All hands at 5 PM',
      createdAt: DateTime.now(),
      payload: const {
        'broadcastId': 'bc1',
        'category': 'reminder',
        'route': 'broadcast_detail',
        'priority': 'normal',
      },
    );

Future<(AuthCubit, NotificationCubit, BroadcastCubit)> buildCubits(
    UserRole role) async {
  final authRepo = FakeAuthRepository(userWith(role));
  final auth = AuthCubit(
    repository: authRepo,
    signInWithEmail: SignInWithEmail(authRepo),
    signOut: SignOut(authRepo),
    getUser: GetUser(authRepo),
    forgotPassword: ForgotPassword(authRepo),
    changePassword: ChangePassword(authRepo),
  );
  await auth.restoreSession();

  final notifRepo = FakeNotificationRepository([broadcastNotification()]);
  final notifications = NotificationCubit(
    repository: notifRepo,
    markRead: MarkNotificationRead(notifRepo),
  );
  await notifications.load('u1');

  final broadcastRepo = FakeBroadcastRepository([
    BroadcastEntity(
      id: 'bc1',
      title: 'Team Meeting',
      message: 'All hands at 5 PM',
      category: 'reminder',
      senderId: 'admin1',
      senderName: 'Admin',
      senderRole: UserRole.admin,
      audience: BroadcastAudience.branch,
      branchId: 'b1',
      createdAt: DateTime.now(),
    ),
  ]);
  final broadcasts = BroadcastCubit(
    repository: broadcastRepo,
    sendBroadcast: SendBroadcast(broadcastRepo),
    branchRepository: FakeBranchRepository(),
    getUsersByBranch: GetUsersByBranch(authRepo),
  );

  return (auth, notifications, broadcasts);
}

Widget appWith(AuthCubit auth, NotificationCubit notifications,
        BroadcastCubit broadcasts, dynamic router) =>
    MultiBlocProvider(
      providers: [
        BlocProvider.value(value: auth),
        BlocProvider.value(value: notifications),
        BlocProvider.value(value: broadcasts),
      ],
      child: MaterialApp.router(routerConfig: router),
    );

void main() {
  testWidgets('A: employee — OS broadcast tap lands on /notifications',
      (tester) async {
    final (auth, notifications, broadcasts) =
        await buildCubits(UserRole.employee);
    final router = createRouter(auth, initialLocation: '/notifications');
    await tester
        .pumpWidget(appWith(auth, notifications, broadcasts, router));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byType(NotificationsScreen), findsOneWidget);
    expect(find.text('Team Meeting'), findsOneWidget);

    // Employee taps the broadcast tile — deep link is a guarded no-op.
    await tester.tap(find.text('Team Meeting'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byType(NotificationsScreen), findsOneWidget);
  });

  testWidgets('B: admin — inbox broadcast tile → /communications/:id',
      (tester) async {
    final (auth, notifications, broadcasts) =
        await buildCubits(UserRole.admin);
    final router = createRouter(auth, initialLocation: '/notifications');
    await tester
        .pumpWidget(appWith(auth, notifications, broadcasts, router));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Team Meeting'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    // B3 fix: the detail screen self-resolves the broadcast by id (one-shot
    // fetch) even though the Communications feed was never opened, so the deep
    // link lands on the real message — not the "Broadcast unavailable" state.
    expect(find.text('Broadcast unavailable'), findsNothing);
    // The resolved detail renders the broadcast's message body.
    expect(find.text('All hands at 5 PM'), findsWidgets);
  });

  testWidgets(
      'C: employee cold start — go(/notifications) BEFORE the router attaches '
      '(initialLocation is the role home, which must never build)',
      (tester) async {
    final (auth, notifications, broadcasts) =
        await buildCubits(UserRole.employee);
    final router = createRouter(auth, initialLocation: '/');
    router.go('/notifications'); // the FCM tap handler, pre-attach
    await tester
        .pumpWidget(appWith(auth, notifications, broadcasts, router));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byType(NotificationsScreen), findsOneWidget);
  });
}
