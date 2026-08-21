import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:opshub/core/errors/failures.dart';
import 'package:opshub/core/services/session_store.dart';
import 'package:opshub/core/utils/app_logger.dart';
import 'package:opshub/features/auth/domain/session_id.dart';
import 'package:opshub/features/auth/domain/usecases/sign_in_with_email.dart';
import 'package:opshub/features/auth/domain/usecases/sign_out.dart';
import 'package:opshub/features/auth/domain/usecases/get_user.dart';
import 'package:opshub/features/auth/domain/usecases/forgot_password.dart';
import 'package:opshub/features/auth/domain/usecases/change_password.dart';
import 'package:opshub/features/auth/domain/repositories/auth_repository.dart';
import 'package:opshub/features/auth/domain/entities/user_entity.dart';
import 'auth_state.dart';

/// Shown when a signed-in account has been deactivated by an admin. DROP is
/// admin-provisioned: access is gated solely by `isActive`.
const String _disabledMessage =
    'This account has been disabled. Contact your administrator.';

/// Shown on the Login screen after this device lost the session to a newer
/// sign-in elsewhere. Public because the Login screen and its tests assert on
/// the exact sentence; there is no second copy of it anywhere.
const String kSessionTakenOverMessage =
    'Your account has been signed in on another device.';

/// Shown when the sign-in itself succeeded but the session claim could not be
/// written. Entering the app in that state is worse than refusing: the device
/// would hold an id the server never recorded and evict itself on the next
/// document emission, which reads to the user as "it signed me out instantly".
const String _sessionClaimFailedMessage =
    'Could not start your session. Check your connection and try again.';

class AuthCubit extends Cubit<AuthState> {
  final AuthRepository _repository;
  final SignInWithEmail _signInWithEmail;
  final SignOut _signOut;
  final GetUser _getUser;
  final ForgotPassword _forgotPassword;
  final ChangePassword _changePassword;

  /// Hook run **before** Firebase sign-out, while the session is still
  /// authenticated — used to drop this device's FCM token from the user's doc
  /// (a write that would be permission-denied once signed out) and to wipe every
  /// user-scoped stream and cache. Wired in DI; see `injection.dart`.
  ///
  /// It runs for BOTH exits — a deliberate sign-out and a single-active-session
  /// eviction — which is the whole reason eviction is implemented here rather
  /// than per feature: Chat, notifications and the FCM token are cleaned up by
  /// the one path they already trusted.
  final Future<void> Function()? _onPreSignOut;

  /// Where this device records the session it owns. Null disables
  /// single-active-session enforcement entirely — the state every widget test
  /// that builds a bare [AuthCubit] runs in, and the honest fallback for a
  /// platform with no keystore. DI always supplies one.
  final SessionStore? _sessionStore;

  /// The session id THIS device claimed, cached from [_sessionStore] so the
  /// document watcher can decide synchronously on every emission instead of
  /// awaiting a keystore read per snapshot.
  String? _sessionId;

  /// The id the document carried **immediately before** this device claimed it,
  /// held until this device sees its own claim come back. A snapshot still
  /// reporting exactly this id is a stale read of the value we just
  /// overwrote — not a takeover. See [_isSessionTakenOver].
  String? _supersededSessionId;

  StreamSubscription? _authSub;
  StreamSubscription? _userWatchSub;

  /// True while any auth action is in flight. Used to reject duplicate taps.
  bool get _busy => state.maybeWhen(loading: (_) => true, orElse: () => false);

  AuthCubit({
    required AuthRepository repository,
    required SignInWithEmail signInWithEmail,
    required SignOut signOut,
    required GetUser getUser,
    required ForgotPassword forgotPassword,
    required ChangePassword changePassword,
    Future<void> Function()? onPreSignOut,
    SessionStore? sessionStore,
  }) : this._(
          repository: repository,
          signInWithEmail: signInWithEmail,
          signOut: signOut,
          getUser: getUser,
          forgotPassword: forgotPassword,
          changePassword: changePassword,
          onPreSignOut: onPreSignOut,
          sessionStore: sessionStore,
        );

  AuthCubit._({
    required this._repository,
    required this._signInWithEmail,
    required this._signOut,
    required this._getUser,
    required this._forgotPassword,
    required this._changePassword,
    this._onPreSignOut,
    this._sessionStore,
  }) : super(const AuthState.initial());

  /// Called once from SplashPage on cold start.
  Future<void> restoreSession() async {
    final firebaseUser = _repository.currentUser;
    // Cold-start persistence probe. If this logs `firebase user=null` right after
    // a sign-in + full close (e.g. the Samsung "original instance" report), the
    // session was lost by Firebase Auth's OWN storage, NOT by any app-side
    // eviction — the login screen then shows no reason because we take the branch
    // below. Compare a working sandbox (a Samsung clone runs in a separate user
    // profile, so its storage — and its Auto Backup / cleanup exposure — differ).
    AppLog.warning('auth',
        'restoreSession: firebase user=${firebaseUser == null ? 'null' : firebaseUser.uid}');
    if (firebaseUser == null) {
      emit(const AuthState.unauthenticated());
    } else {
      // Load this device's claim BEFORE the profile read, so the session check
      // below has something to compare against on the very first snapshot.
      // Firebase restores its own session silently; the takeover that happened
      // while this app was closed is only visible here.
      await _loadSessionId();
      try {
        final user = await _withStoredProfile(firebaseUser);
        if (!user.isActive) {
          // Deactivated mid-session / since last login → block + sign out.
          await _signOut();
          emit(const AuthState.unauthenticated());
        } else if (_isSessionTakenOver(user)) {
          // Signed in elsewhere while this device was closed. Same exit as a
          // live takeover — full teardown, then Login with the explanation.
          await _endSession(reason: kSessionTakenOverMessage);
        } else {
          emit(AuthState.authenticated(user));
          watchCurrentUser();
        }
      } catch (_) {
        emit(AuthState.authenticated(firebaseUser));
      }
    }
    _listenToAuthChanges();
  }

  // ─── Single active session ──────────────────────────────────────
  /// Reads this device's claimed session id into [_sessionId]. Cheap and
  /// idempotent; a store that is absent or unreadable leaves it null, which
  /// [_isSessionTakenOver] treats as "never evict".
  Future<void> _loadSessionId() async {
    _sessionId = await _sessionStore?.read();
  }

  /// Whether [user]'s document says some OTHER device now owns the session.
  ///
  /// Both null cases are deliberately **not** evictions:
  ///  - **remote null** — a legacy document, or an account that has not signed
  ///    in since this feature shipped. Treating it as a mismatch would sign the
  ///    entire company out the moment the build lands.
  ///  - **local null** — no store wired (tests), an unreadable keystore, or a
  ///    device signed in before the feature existed. It cannot prove it owns the
  ///    session, but it cannot prove it lost it either, and a keychain hiccup
  ///    must never look like a hostile login. It re-claims at its next sign-in.
  ///
  /// **Nor is the id this device just superseded.** Firestore's `snapshots()`
  /// replays the locally cached document the instant you subscribe, so a device
  /// that has been signed in before receives its *last session's* id as the
  /// watcher's first emission — while this device already holds the id it just
  /// claimed. That mismatch is a stale read of the value we overwrote, and
  /// reading it as a hostile login is what signed device B out the moment it
  /// signed in. (The first device on a fresh account never hit it: its cached
  /// document carried a null id, which the back-compat rule above ignores.)
  ///
  /// The amnesty is deliberately narrow — **only** the one id we replaced, and
  /// only until our own claim is seen. Every other mismatch still evicts on the
  /// spot, so a genuine takeover racing our sign-in is enforced live rather
  /// than waiting for a cold start.
  bool _isSessionTakenOver(UserEntity user) {
    if (_sessionStore == null) return false;
    final remote = user.activeSessionId;
    final local = _sessionId;
    if (remote == null || local == null) return false;
    if (remote == local) {
      // Confirmed: the document reports our claim, so nothing is outstanding.
      _supersededSessionId = null;
      return false;
    }
    if (_supersededSessionId != null && remote == _supersededSessionId) {
      AppLog.warning(
          'auth', 'ignoring a stale snapshot of the session id we replaced');
      return false;
    }
    return true;
  }

  /// Mints and claims a session for [uid], and records it locally. Returns the
  /// id on success, `null` when the claim could not be written (the caller must
  /// then refuse the sign-in — see [_sessionClaimFailedMessage]).
  ///
  /// The local write happens **after** the remote claim lands, so a failed claim
  /// cannot leave this device holding an id the server never recorded.
  /// [previousSessionId] is what the document reported when we read it, i.e.
  /// the claim this sign-in replaces. Remembered so a stale snapshot still
  /// carrying it is not mistaken for a takeover (see [_isSessionTakenOver]).
  Future<String?> _claimSession(String uid, {String? previousSessionId}) async {
    final store = _sessionStore;
    if (store == null) return null;
    final sessionId = generateSessionId();
    try {
      await _repository.claimSession(uid, sessionId);
    } catch (e) {
      AppLog.error('auth', 'session claim failed for $uid — $e');
      return null;
    }
    await store.write(sessionId);
    _sessionId = sessionId;
    _supersededSessionId = previousSessionId;
    return sessionId;
  }

  /// The exit for "this session is over and it was not the user's doing".
  ///
  /// Deliberately the **same teardown** as a deliberate sign-out — one path, so
  /// an eviction can never clean up less than the Settings button does — plus
  /// the [reason] the Login screen will show. That teardown order matters:
  /// watcher off first (its own emissions must not re-enter here), then
  /// [_onPreSignOut] **while still authenticated** (dropping the FCM token,
  /// wiping the chat caches and resetting the user-scoped cubits all need the
  /// session), then Firebase sign-out, then forget the local claim.
  Future<void> _endSession({required String reason}) =>
      _signOutInternal(reason: reason);

  /// Consumes the one-shot [AuthState.unauthenticated.signedOutReason] once the
  /// Login screen has shown it, so a rebuild (or a second visit to Login) never
  /// repeats the message.
  void acknowledgeSignOutReason() {
    final showed = state.maybeWhen(
      unauthenticated: (reason) => reason != null,
      orElse: () => false,
    );
    if (showed) emit(const AuthState.unauthenticated());
  }

  /// Firebase sign-in only knows the Auth profile (no role/flags). Re-read the
  /// Firestore document so the emitted [AuthState.authenticated] carries the
  /// authoritative role/branch + provisioning flags (mustChangePassword /
  /// isProfileCompleted) and the router can dispatch correctly. Falls back to the
  /// Firebase user if the read fails.
  Future<UserEntity> _withStoredProfile(UserEntity fallback) async {
    try {
      final stored = await _getUser(fallback.uid);
      return stored ?? fallback;
    } catch (_) {
      return fallback;
    }
  }

  /// Re-reads the current user's Firestore document and re-emits
  /// [AuthState.authenticated] so the router re-evaluates access. Used after the
  /// first-login flows (force password change / profile completion) clear a flag.
  Future<void> refreshUser() async {
    final firebaseUser = _repository.currentUser;
    if (firebaseUser == null) {
      emit(const AuthState.unauthenticated());
      return;
    }
    final user = await _withStoredProfile(firebaseUser);
    if (!user.isActive) {
      await _signOut();
      emit(const AuthState.unauthenticated());
    } else if (_isSessionTakenOver(user)) {
      // The first-login flows (force password change, profile completion) each
      // end in a refresh, and a takeover can land during them just as easily as
      // anywhere else. Checking here keeps the gate closed on the one path that
      // re-emits `authenticated` without going through the watcher.
      await _endSession(reason: kSessionTakenOverMessage);
    } else {
      emit(AuthState.authenticated(user));
    }
  }

  /// Live-watches the signed-in user's document and re-emits on every change, so
  /// an admin revoking access mid-session takes effect instantly. Started
  /// automatically once a session settles on authenticated (cold-start restore
  /// and fresh sign-in). Three cases end the session here:
  ///  - **deactivated** — the doc still exists but `isActive == false`;
  ///  - **hard-deleted** — the doc is gone, so [watchUser] emits `null` (without
  ///    this, `restoreSession`'s fallback would treat the still-present Auth user
  ///    as active). Deleting the Auth user also ends the session via
  ///    [authStateChanges]; this is the Firestore-side backstop.
  ///  - **taken over** — `activeSessionId` no longer matches this device's
  ///    claim, i.e. the account signed in somewhere else. This is the ONLY
  ///    place single-active-session is enforced: the user document is already
  ///    streamed for the two cases above, so enforcement costs no extra
  ///    listener and no feature (Chat included) needs a rule of its own.
  void watchCurrentUser() {
    final firebaseUser = _repository.currentUser;
    if (firebaseUser == null) return;
    _userWatchSub?.cancel();
    _userWatchSub = _repository.watchUser(firebaseUser.uid).listen(
      (user) async {
        if (user == null || !user.isActive) {
          stopWatchingUser();
          await _signOut();
          emit(const AuthState.unauthenticated());
        } else if (_isSessionTakenOver(user)) {
          await _endSession(reason: kSessionTakenOverMessage);
        } else {
          emit(AuthState.authenticated(user));
        }
      },
      onError: (_) {/* transient */},
    );
  }

  /// Stops the [watchCurrentUser] subscription (call on leaving the screen).
  void stopWatchingUser() {
    _userWatchSub?.cancel();
    _userWatchSub = null;
  }

  void _listenToAuthChanges() {
    _authSub = _repository.authStateChanges.listen((user) {
      if (user == null) {
        emit(const AuthState.unauthenticated());
      }
      // Positive auth events are handled explicitly per action.
    });
  }

  Future<void> signInWithEmail(String email, String password) async {
    if (_busy) return;
    emit(const AuthState.loading(AuthAction.emailSignIn));
    try {
      final signedIn = await _signInWithEmail(email: email, password: password);
      final user = await _withStoredProfile(signedIn);
      if (!user.isActive) {
        // Deactivated account: never enter the app — sign out + surface why.
        await _signOut();
        emit(const AuthState.error(_disabledMessage));
        return;
      }
      // Take the session for THIS device. Every other device watching this
      // document sees an id it does not hold and signs itself out. Done before
      // the authenticated emit so the app is never entered on an unclaimed
      // session.
      var claimed = user;
      if (_sessionStore != null) {
        final sessionId = await _claimSession(
          user.uid,
          previousSessionId: user.activeSessionId,
        );
        if (sessionId == null) {
          await _signOut();
          emit(const AuthState.error(_sessionClaimFailedMessage));
          return;
        }
        // Carry the id we just claimed on the emitted user, so the first
        // document snapshot (which reports exactly this id) cannot be read as a
        // mismatch by anything downstream.
        claimed = user.copyWith(activeSessionId: sessionId);
      }
      emit(AuthState.authenticated(claimed));
      watchCurrentUser();
    } on AuthFailure catch (e) {
      emit(AuthState.error(e.message));
    }
  }

  Future<void> forgotPassword(String email) async {
    if (_busy) return;
    emit(const AuthState.loading(AuthAction.forgotPassword));
    try {
      await _forgotPassword(email);
      emit(const AuthState.passwordResetSent());
    } on AuthFailure catch (e) {
      emit(AuthState.error(e.message));
    }
  }

  /// Settings → Change Password (a voluntary change). Emits [passwordChanged] on
  /// success so the settings page can confirm + pop.
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    if (_busy) return;
    emit(const AuthState.loading(AuthAction.changePassword));
    try {
      await _changePassword(
        currentPassword: currentPassword,
        newPassword: newPassword,
      );
      emit(const AuthState.passwordChanged());
    } on AuthFailure catch (e) {
      emit(AuthState.error(e.message));
    }
  }

  /// First-login forced change: the user replaces the admin-issued temp
  /// password. On success the `mustChangePassword` flag is cleared and the
  /// session re-emitted as authenticated, so the router advances the user to
  /// Profile Completion (or Home).
  Future<void> forcePasswordChange({
    required String currentPassword,
    required String newPassword,
  }) async {
    if (_busy) return;
    final uid = _repository.currentUser?.uid;
    if (uid == null) {
      emit(const AuthState.unauthenticated());
      return;
    }
    emit(const AuthState.loading(AuthAction.changePassword));
    try {
      await _changePassword(
        currentPassword: currentPassword,
        newPassword: newPassword,
      );
      await _repository.setMustChangePassword(uid, false);
      await refreshUser();
    } on AuthFailure catch (e) {
      emit(AuthState.error(e.message));
    }
  }

  /// Marks profile completion (after the profile fields were saved) and seeds
  /// the one-time Welcome flag `false` so the router shows the Welcome screen to
  /// a newly-provisioned employee exactly once, then re-emits the session so the
  /// router advances (→ Welcome for employees, → Home for others). Existing
  /// users never pass through here again, so they keep the default `true` and
  /// are never shown Welcome.
  Future<void> completeProfile() async {
    final uid = _repository.currentUser?.uid;
    if (uid == null) {
      emit(const AuthState.unauthenticated());
      return;
    }
    try {
      await _repository.setProfileCompleted(uid, true);
      await _repository.setOnboardingCompleted(uid, false);
      await refreshUser();
    } on AuthFailure catch (e) {
      emit(AuthState.error(e.message));
    }
  }

  /// Dismisses the one-time Welcome screen (its "Get started" CTA): flips the
  /// flag `true` and re-emits so the router advances to the role home. The flag
  /// is persisted, so Welcome is never shown again on any device.
  Future<void> completeOnboarding() async {
    final uid = _repository.currentUser?.uid;
    if (uid == null) {
      emit(const AuthState.unauthenticated());
      return;
    }
    try {
      await _repository.setOnboardingCompleted(uid, true);
      await refreshUser();
    } on AuthFailure catch (e) {
      emit(AuthState.error(e.message));
    }
  }

  /// A deliberate sign-out (the Settings action). Same teardown as an eviction,
  /// minus the explanation — the user knows why they are on Login.
  ///
  /// The remote `activeSessionId` is deliberately left as-is rather than
  /// cleared: this device drops its local claim, so it can never win a
  /// comparison again, and clearing the remote value would *release* the account
  /// for whichever stale device still holds a matching id. The next sign-in
  /// overwrites it anyway.
  Future<void> signOut() => _signOutInternal(reason: null);

  Future<void> _signOutInternal({required String? reason}) async {
    // Stop the live user watcher first — a deleted/deactivated doc emission
    // during teardown would otherwise re-run the sign-out path redundantly.
    stopWatchingUser();
    // Drop this device's FCM token FIRST, while still authenticated — the
    // post-sign-out listener can't (rules require `isOwner`). This is also
    // where every user-scoped stream and cache is torn down.
    try {
      await _onPreSignOut?.call();
    } catch (_) {/* best-effort */}
    try {
      await _signOut();
    } catch (_) {/* don't block clearing the local session */}
    // Forget this device's claim, so a later cold start cannot compare a stale
    // id against whatever the account looks like by then.
    await _sessionStore?.clear();
    _sessionId = null;
    _supersededSessionId = null;
    emit(AuthState.unauthenticated(signedOutReason: reason));
  }

  @override
  Future<void> close() {
    _authSub?.cancel();
    _userWatchSub?.cancel();
    return super.close();
  }
}
