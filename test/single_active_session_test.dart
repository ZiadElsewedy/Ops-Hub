import 'dart:async';
import 'dart:math';

import 'package:drop/core/enums/user_role.dart';
import 'package:drop/core/services/session_store.dart';
import 'package:drop/features/auth/domain/entities/user_entity.dart';
import 'package:drop/features/auth/domain/repositories/auth_repository.dart';
import 'package:drop/features/auth/domain/session_id.dart';
import 'package:drop/features/auth/domain/usecases/change_password.dart';
import 'package:drop/features/auth/domain/usecases/forgot_password.dart';
import 'package:drop/features/auth/domain/usecases/get_user.dart';
import 'package:drop/features/auth/domain/usecases/sign_in_with_email.dart';
import 'package:drop/features/auth/domain/usecases/sign_out.dart';
import 'package:drop/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:drop/features/auth/presentation/cubit/auth_state.dart';
import 'package:drop/features/auth/presentation/pages/login_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

/// Single-active-session enforcement lives entirely in the auth layer:
/// `AuthCubit` claims a session id at sign-in and the existing user-document
/// watcher evicts the device when that id stops matching. These tests pin the
/// behaviour that matters operationally — a second sign-in kicks the first
/// device out, and none of the many "no claim on record" states does.
void main() {
  const uid = 'employee-1';

  UserEntity user({String? activeSessionId, bool isActive = true}) => UserEntity(
        uid: uid,
        email: 'sara@drop.test',
        authProvider: 'password',
        role: UserRole.employee,
        isActive: isActive,
        activeSessionId: activeSessionId,
      );

  group('generateSessionId', () {
    test('is 32 lowercase hex characters', () {
      final id = generateSessionId();
      expect(id, matches(RegExp(r'^[0-9a-f]{32}$')));
    });

    test('does not repeat across a large draw', () {
      // The whole enforcement rule is a string comparison, so two devices that
      // ever minted the same id would each believe they still hold the session.
      final ids = {for (var i = 0; i < 2000; i++) generateSessionId()};
      expect(ids.length, 2000);
    });

    test('is driven by the injected generator (deterministic under test)', () {
      expect(generateSessionId(random: Random(7)),
          generateSessionId(random: Random(7)));
    });
  });

  group('sign-in', () {
    test('claims a session, stores it locally, and enters the app', () async {
      final repo = _FakeAuthRepository(user());
      final store = InMemorySessionStore();
      final cubit = _cubit(repo, store);

      await cubit.signInWithEmail('sara@drop.test', 'pw');

      expect(repo.claimedSessionId, isNotNull);
      expect(await store.read(), repo.claimedSessionId);
      final signedIn = cubit.state.maybeWhen(
        authenticated: (u) => u,
        orElse: () => null,
      );
      // The emitted user carries the id we just claimed, so the first document
      // snapshot (which reports exactly that id) is not read as a mismatch.
      expect(signedIn?.activeSessionId, repo.claimedSessionId);

      await cubit.close();
    });

    test('refuses the session when the claim cannot be written', () async {
      // Entering the app on an unclaimed session would evict this device on the
      // very next document emission — which reads as "it signed me out
      // instantly". Failing the sign-in is the honest outcome.
      final repo = _FakeAuthRepository(user())..failClaim = true;
      final store = InMemorySessionStore();
      final cubit = _cubit(repo, store);

      await cubit.signInWithEmail('sara@drop.test', 'pw');

      expect(cubit.state, isA<AuthState>());
      expect(
        cubit.state.maybeWhen(error: (m) => m, orElse: () => null),
        contains('Could not start your session'),
      );
      expect(repo.signOutCount, 1);
      expect(await store.read(), isNull);

      await cubit.close();
    });

    test('a second sign-in mints a different id than the first', () async {
      final repo = _FakeAuthRepository(user());
      final first = _cubit(repo, InMemorySessionStore());
      await first.signInWithEmail('sara@drop.test', 'pw');
      final firstId = repo.claimedSessionId;

      final second = _cubit(repo, InMemorySessionStore());
      await second.signInWithEmail('sara@drop.test', 'pw');

      expect(repo.claimedSessionId, isNot(firstId));
      await first.close();
      await second.close();
    });
  });

  group('live eviction', () {
    test('a takeover signs this device out with the message, tears down, '
        'and forgets the local claim', () async {
      final repo = _FakeAuthRepository(user());
      final store = InMemorySessionStore();
      var preSignOutRan = 0;
      final cubit = _cubit(repo, store, onPreSignOut: () async {
        preSignOutRan++;
      });

      await cubit.signInWithEmail('sara@drop.test', 'pw');
      final ourId = repo.claimedSessionId!;

      // Another device claims the account.
      repo.emitUser(user(activeSessionId: 'some-other-device'));
      await pumpEventQueue();

      expect(
        cubit.state.maybeWhen(
          unauthenticated: (reason) => reason,
          orElse: () => null,
        ),
        kSessionTakenOverMessage,
      );
      // The eviction runs the SAME teardown a deliberate sign-out does — that
      // is why no feature (Chat included) needs eviction logic of its own.
      expect(preSignOutRan, 1);
      expect(repo.signOutCount, 1);
      expect(await store.read(), isNull);
      expect(ourId, isNot('some-other-device'));

      await cubit.close();
    });

    test('an unrelated document change does NOT evict', () async {
      final repo = _FakeAuthRepository(user());
      final cubit = _cubit(repo, InMemorySessionStore());
      await cubit.signInWithEmail('sara@drop.test', 'pw');
      final ourId = repo.claimedSessionId!;

      // e.g. an admin edits the profile — same session id.
      repo.emitUser(
        user(activeSessionId: ourId).copyWith(displayName: 'Sara A.'),
      );
      await pumpEventQueue();

      expect(cubit.state.maybeWhen(authenticated: (u) => u.displayName,
          orElse: () => null), 'Sara A.');

      await cubit.close();
    });

    test('a document with NO claim on record does not evict (back-compat)',
        () async {
      // Legacy documents, and every account that has not signed in since this
      // shipped, have a null `activeSessionId`. Treating that as a mismatch
      // would sign the whole company out the moment the build lands.
      final repo = _FakeAuthRepository(user());
      final cubit = _cubit(repo, InMemorySessionStore());
      await cubit.signInWithEmail('sara@drop.test', 'pw');

      repo.emitUser(user());
      await pumpEventQueue();

      expect(cubit.state.maybeWhen(authenticated: (_) => true,
          orElse: () => false), isTrue);

      await cubit.close();
    });

    test('a device that holds no local claim does not evict itself', () async {
      // An unreadable keystore must never look like a hostile login.
      final repo = _FakeAuthRepository(user(activeSessionId: 'someone-else'));
      final cubit = _cubit(repo, InMemorySessionStore());
      // Enter the app WITHOUT signing in (so nothing was claimed locally).
      await cubit.restoreSession();

      expect(cubit.state.maybeWhen(authenticated: (_) => true,
          orElse: () => false), isTrue);

      await cubit.close();
    });

    test('deactivation still signs out, and without a takeover message',
        () async {
      final repo = _FakeAuthRepository(user());
      final cubit = _cubit(repo, InMemorySessionStore());
      await cubit.signInWithEmail('sara@drop.test', 'pw');

      repo.emitUser(user(isActive: false));
      await pumpEventQueue();

      expect(
        cubit.state.maybeWhen(
          unauthenticated: (reason) => reason,
          orElse: () => 'still authenticated',
        ),
        isNull,
      );

      await cubit.close();
    });
  });

  group('cold start', () {
    test('a takeover that happened while the app was closed evicts on restore',
        () async {
      // Firebase restores its own session silently, so this is the only place
      // the eviction becomes visible.
      final repo = _FakeAuthRepository(user(activeSessionId: 'other-device'));
      final store = InMemorySessionStore('this-device');
      final cubit = _cubit(repo, store);

      await cubit.restoreSession();

      expect(
        cubit.state.maybeWhen(
          unauthenticated: (reason) => reason,
          orElse: () => null,
        ),
        kSessionTakenOverMessage,
      );
      expect(await store.read(), isNull);

      await cubit.close();
    });

    test('a device that still owns the session restores normally', () async {
      final repo = _FakeAuthRepository(user(activeSessionId: 'this-device'));
      final cubit = _cubit(repo, InMemorySessionStore('this-device'));

      await cubit.restoreSession();

      expect(cubit.state.maybeWhen(authenticated: (_) => true,
          orElse: () => false), isTrue);

      await cubit.close();
    });
  });

  group('a stale snapshot is not a takeover (the device-B bug)', () {
    // Reported: sign in on device A → sign out on A → sign in on device B →
    // B says "signed in on another device" immediately, on a session nobody
    // took over.
    //
    // Firestore's `snapshots()` replays the LOCALLY CACHED document the instant
    // you subscribe. A device that has been signed in before holds a cached
    // user doc carrying the PREVIOUS session's id, so the watcher's very first
    // emission reports that old id while this device already holds its own,
    // freshly claimed one — and the comparison reads it as a hostile login.
    // The first device on a fresh account never hit it: its cached doc had a
    // null `activeSessionId`, which the back-compat guard already ignores.

    test('the cached first snapshot after sign-in does not evict', () async {
      final repo = _FakeAuthRepository(user(activeSessionId: 'device-a-old'))
        // What device B has in its Firestore cache from its last session.
        ..cachedFirstSnapshot = user(activeSessionId: 'device-a-old');
      final store = InMemorySessionStore();
      final cubit = _cubit(repo, store);

      await cubit.signInWithEmail('sara@drop.test', 'pw');
      await pumpEventQueue();

      expect(
        cubit.state.maybeWhen(
          unauthenticated: (reason) => 'EVICTED: $reason',
          authenticated: (_) => 'signed in',
          orElse: () => 'other',
        ),
        'signed in',
      );
      expect(await store.read(), repo.claimedSessionId);

      await cubit.close();
    });

    test('a real takeover AFTER the stale snapshot still evicts', () async {
      // The guard must not become a permanent amnesty: once this device has
      // seen its own claim confirmed, the next mismatch is genuine.
      final repo = _FakeAuthRepository(user(activeSessionId: 'device-a-old'))
        ..cachedFirstSnapshot = user(activeSessionId: 'device-a-old');
      final cubit = _cubit(repo, InMemorySessionStore());

      await cubit.signInWithEmail('sara@drop.test', 'pw');
      await pumpEventQueue();
      // The server confirms our own claim...
      repo.emitUser(user(activeSessionId: repo.claimedSessionId));
      await pumpEventQueue();
      // ...and then somebody really does sign in elsewhere.
      repo.emitUser(user(activeSessionId: 'device-c'));
      await pumpEventQueue();

      expect(
        cubit.state.maybeWhen(
          unauthenticated: (reason) => reason,
          orElse: () => null,
        ),
        kSessionTakenOverMessage,
      );

      await cubit.close();
    });

    test('a THIRD device claiming during the stale window evicts immediately',
        () async {
      // The amnesty covers exactly one value — the id we replaced. A different
      // id, arriving before our own claim is ever confirmed, is a real takeover
      // and must not wait for a cold start to be enforced.
      final repo = _FakeAuthRepository(user(activeSessionId: 'device-a-old'))
        ..cachedFirstSnapshot = user(activeSessionId: 'device-a-old');
      final cubit = _cubit(repo, InMemorySessionStore());

      await cubit.signInWithEmail('sara@drop.test', 'pw');
      await pumpEventQueue();
      repo.emitUser(user(activeSessionId: 'device-c'));
      await pumpEventQueue();

      expect(
        cubit.state.maybeWhen(
          unauthenticated: (reason) => reason,
          orElse: () => null,
        ),
        kSessionTakenOverMessage,
      );

      await cubit.close();
    });

    test('the amnesty expires once our own claim is confirmed', () async {
      // A later snapshot that somehow reports the superseded id again (a replay
      // from a resubscribe) must not be forgiven a second time.
      final repo = _FakeAuthRepository(user(activeSessionId: 'device-a-old'))
        ..cachedFirstSnapshot = user(activeSessionId: 'device-a-old');
      final cubit = _cubit(repo, InMemorySessionStore());

      await cubit.signInWithEmail('sara@drop.test', 'pw');
      await pumpEventQueue();
      repo.emitUser(user(activeSessionId: repo.claimedSessionId)); // confirmed
      await pumpEventQueue();
      repo.emitUser(user(activeSessionId: 'device-a-old'));
      await pumpEventQueue();

      expect(
        cubit.state.maybeWhen(
          unauthenticated: (reason) => reason,
          orElse: () => null,
        ),
        kSessionTakenOverMessage,
      );

      await cubit.close();
    });

    test('a takeover that lands before our own claim is confirmed still evicts '
        'on the next cold start', () async {
      // The one hole the guard leaves: two sign-ins inside a single round trip.
      // It closes itself on restore, which compares against a fresh read.
      final repo = _FakeAuthRepository(user(activeSessionId: 'device-c'));
      final store = InMemorySessionStore('ours');
      final cubit = _cubit(repo, store);

      await cubit.restoreSession();

      expect(
        cubit.state.maybeWhen(
          unauthenticated: (reason) => reason,
          orElse: () => null,
        ),
        kSessionTakenOverMessage,
      );

      await cubit.close();
    });

    test('signing out on device A does not evict device B', () async {
      // The full reported sequence, end to end, on one shared account doc.
      final repo = _FakeAuthRepository(user());
      final deviceA = _cubit(repo, InMemorySessionStore());
      await deviceA.signInWithEmail('sara@drop.test', 'pw');
      await deviceA.signOut();
      final leftBehind = repo.claimedSessionId; // A's claim, deliberately kept

      // Device B: its cache still holds the document as A left it.
      repo.cachedFirstSnapshot = user(activeSessionId: leftBehind);
      final storeB = InMemorySessionStore();
      final deviceB = _cubit(repo, storeB);

      await deviceB.signInWithEmail('sara@drop.test', 'pw');
      await pumpEventQueue();

      expect(
        deviceB.state.maybeWhen(
          unauthenticated: (reason) => 'EVICTED: $reason',
          authenticated: (_) => 'signed in',
          orElse: () => 'other',
        ),
        'signed in',
      );
      expect(await storeB.read(), isNot(leftBehind));

      await deviceA.close();
      await deviceB.close();
    });
  });

  group('the message is shown exactly once', () {
    test('acknowledgeSignOutReason clears it', () async {
      final repo = _FakeAuthRepository(user());
      final cubit = _cubit(repo, InMemorySessionStore());
      await cubit.signInWithEmail('sara@drop.test', 'pw');
      repo.emitUser(user(activeSessionId: 'other'));
      await pumpEventQueue();

      cubit.acknowledgeSignOutReason();

      expect(
        cubit.state.maybeWhen(
          unauthenticated: (reason) => reason,
          orElse: () => 'wrong state',
        ),
        isNull,
      );

      await cubit.close();
    });

    test('acknowledging when there is no reason emits nothing', () async {
      final repo = _FakeAuthRepository(user());
      final cubit = _cubit(repo, InMemorySessionStore());
      await cubit.signInWithEmail('sara@drop.test', 'pw');
      final before = cubit.state;

      cubit.acknowledgeSignOutReason();

      expect(cubit.state, before);
      await cubit.close();
    });
  });

  group('enforcement is off when no store is wired', () {
    test('no claim is written and a mismatch never evicts', () async {
      // Every widget test builds a bare AuthCubit; none of them should suddenly
      // start signing themselves out.
      final repo = _FakeAuthRepository(user());
      final cubit = _cubit(repo, null);

      await cubit.signInWithEmail('sara@drop.test', 'pw');
      expect(repo.claimedSessionId, isNull);

      repo.emitUser(user(activeSessionId: 'other-device'));
      await pumpEventQueue();
      expect(cubit.state.maybeWhen(authenticated: (_) => true,
          orElse: () => false), isTrue);

      await cubit.close();
    });
  });

  group('the Login screen', () {
    testWidgets('shows the takeover message once, on the frame it mounts',
        (tester) async {
      // The eviction emits `unauthenticated(reason)` and the router THEN
      // redirects to Login, so the state change is already in the past by the
      // time this page exists — a `BlocListener` alone can never see it.
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      final repo = _FakeAuthRepository(user());
      final cubit = _cubit(repo, InMemorySessionStore());
      // Drive the eviction on the REAL clock: `testWidgets` runs inside a fake
      // one, where the stream emission that carries the takeover never gets a
      // chance to be delivered.
      await tester.runAsync(() async {
        await cubit.signInWithEmail('sara@drop.test', 'pw');
        repo.emitUser(user(activeSessionId: 'other-device'));
        await Future<void>.delayed(const Duration(milliseconds: 50));
      });

      await tester.pumpWidget(
        BlocProvider<AuthCubit>.value(
          value: cubit,
          child: const MaterialApp(home: LoginPage()),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text(kSessionTakenOverMessage), findsOneWidget);
      // Consumed — a rebuild must not repeat it.
      expect(
        cubit.state.maybeWhen(
          unauthenticated: (reason) => reason,
          orElse: () => 'wrong state',
        ),
        isNull,
      );

      // Drain the snackbar's auto-dismiss timer before the tree is torn down —
      // a pending Timer at disposal fails the test on its own.
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
      await cubit.close();
    });
  });

  group('deliberate sign-out', () {
    test('forgets the local claim and carries no message', () async {
      final repo = _FakeAuthRepository(user());
      final store = InMemorySessionStore();
      final cubit = _cubit(repo, store);
      await cubit.signInWithEmail('sara@drop.test', 'pw');

      await cubit.signOut();

      expect(await store.read(), isNull);
      expect(
        cubit.state.maybeWhen(
          unauthenticated: (reason) => reason,
          orElse: () => 'wrong state',
        ),
        isNull,
      );
      // The REMOTE claim is deliberately left alone: clearing it would release
      // the account for whichever stale device still holds a matching id.
      expect(repo.claimedSessionId, isNotNull);

      await cubit.close();
    });
  });
}

AuthCubit _cubit(
  _FakeAuthRepository repo,
  SessionStore? store, {
  Future<void> Function()? onPreSignOut,
}) =>
    AuthCubit(
      repository: repo,
      signInWithEmail: SignInWithEmail(repo),
      signOut: SignOut(repo),
      getUser: GetUser(repo),
      forgotPassword: ForgotPassword(repo),
      changePassword: ChangePassword(repo),
      onPreSignOut: onPreSignOut,
      sessionStore: store,
    );

class _FakeAuthRepository implements AuthRepository {
  _FakeAuthRepository(this._user);

  UserEntity _user;
  final _watch = StreamController<UserEntity?>.broadcast();

  /// The last id written by [claimSession] — null when nothing claimed.
  String? claimedSessionId;
  bool failClaim = false;
  int signOutCount = 0;

  /// What the listener replays on subscribe, modelling **Firestore's cached
  /// first snapshot**: `snapshots()` emits the locally cached document the
  /// instant you attach, before the server confirms anything. Null = replay
  /// nothing (the old fake's behaviour).
  ///
  /// This is the difference between a fake and Firestore, and it is where the
  /// device-B eviction bug lived: a device that had been signed in before
  /// carries a cached user doc holding the PREVIOUS session's id.
  UserEntity? cachedFirstSnapshot;

  /// Pushes [next] down the user-document stream, as Firestore would.
  void emitUser(UserEntity next) {
    _user = next;
    _watch.add(next);
  }

  @override
  Stream<UserEntity?> get authStateChanges => const Stream.empty();

  @override
  UserEntity? get currentUser => _user;

  @override
  Future<UserEntity> signInWithEmail({
    required String email,
    required String password,
  }) async =>
      _user;

  @override
  Future<void> signOut() async => signOutCount++;

  @override
  Future<UserEntity?> getUser(String uid) async => _user;

  @override
  Future<List<UserEntity>> getUsersByBranch(String branchId) async => [_user];

  @override
  Future<List<UserEntity>> getAllUsers() async => [_user];

  @override
  Stream<UserEntity?> watchUser(String uid) {
    final cached = cachedFirstSnapshot;
    if (cached == null) return _watch.stream;
    // Firestore replays the cached document on subscribe, then delivers the
    // server's. `onListen` attaches to the live stream synchronously with
    // `listen()`, so nothing emitted right after subscribing is lost — an
    // `async*` generator would open exactly that window.
    final controller = StreamController<UserEntity?>();
    controller.onListen = () {
      controller.add(cached);
      controller.addStream(_watch.stream);
    };
    return controller.stream;
  }

  @override
  Future<void> sendPasswordResetEmail(String email) async {}

  @override
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {}

  @override
  Future<void> setMustChangePassword(String uid, bool value) async {}

  @override
  Future<void> setProfileCompleted(String uid, bool value) async {}

  @override
  Future<void> setOnboardingCompleted(String uid, bool value) async {}

  @override
  Future<void> claimSession(String uid, String sessionId) async {
    if (failClaim) throw StateError('offline');
    claimedSessionId = sessionId;
    _user = _user.copyWith(activeSessionId: sessionId);
  }
}
