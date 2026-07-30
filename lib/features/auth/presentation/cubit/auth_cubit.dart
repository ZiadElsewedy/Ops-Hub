import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:drop/core/errors/failures.dart';
import 'package:drop/features/auth/domain/usecases/sign_in_with_email.dart';
import 'package:drop/features/auth/domain/usecases/sign_out.dart';
import 'package:drop/features/auth/domain/usecases/get_user.dart';
import 'package:drop/features/auth/domain/usecases/forgot_password.dart';
import 'package:drop/features/auth/domain/usecases/change_password.dart';
import 'package:drop/features/auth/domain/repositories/auth_repository.dart';
import 'package:drop/features/auth/domain/entities/user_entity.dart';
import 'auth_state.dart';

/// Shown when a signed-in account has been deactivated by an admin. DROP is
/// admin-provisioned: access is gated solely by `isActive`.
const String _disabledMessage =
    'This account has been disabled. Contact your administrator.';

class AuthCubit extends Cubit<AuthState> {
  final AuthRepository _repository;
  final SignInWithEmail _signInWithEmail;
  final SignOut _signOut;
  final GetUser _getUser;
  final ForgotPassword _forgotPassword;
  final ChangePassword _changePassword;

  /// Hook run **before** Firebase sign-out, while the session is still
  /// authenticated — used to drop this device's FCM token from the user's doc
  /// (a write that would be permission-denied once signed out). Wired in DI to
  /// [NotificationService.forgetUser].
  final Future<void> Function()? _onPreSignOut;

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
  }) : this._(
          repository: repository,
          signInWithEmail: signInWithEmail,
          signOut: signOut,
          getUser: getUser,
          forgotPassword: forgotPassword,
          changePassword: changePassword,
          onPreSignOut: onPreSignOut,
        );

  AuthCubit._({
    required this._repository,
    required this._signInWithEmail,
    required this._signOut,
    required this._getUser,
    required this._forgotPassword,
    required this._changePassword,
    this._onPreSignOut,
  }) : super(const AuthState.initial());

  /// Called once from SplashPage on cold start.
  Future<void> restoreSession() async {
    final firebaseUser = _repository.currentUser;
    if (firebaseUser == null) {
      emit(const AuthState.unauthenticated());
    } else {
      try {
        final user = await _withStoredProfile(firebaseUser);
        if (!user.isActive) {
          // Deactivated mid-session / since last login → block + sign out.
          await _signOut();
          emit(const AuthState.unauthenticated());
        } else {
          emit(AuthState.authenticated(user));
        }
      } catch (_) {
        emit(AuthState.authenticated(firebaseUser));
      }
    }
    _listenToAuthChanges();
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
    } else {
      emit(AuthState.authenticated(user));
    }
  }

  /// Live-watches the signed-in user's document and re-emits on every change. An
  /// admin deactivating the account mid-session signs the user out instantly.
  void watchCurrentUser() {
    final firebaseUser = _repository.currentUser;
    if (firebaseUser == null) return;
    _userWatchSub?.cancel();
    _userWatchSub = _repository.watchUser(firebaseUser.uid).listen(
      (user) async {
        if (user == null) return;
        if (!user.isActive) {
          await _signOut();
          emit(const AuthState.unauthenticated());
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
      emit(AuthState.authenticated(user));
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

  Future<void> signOut() async {
    // Drop this device's FCM token FIRST, while still authenticated — the
    // post-sign-out listener can't (rules require `isOwner`).
    try {
      await _onPreSignOut?.call();
    } catch (_) {/* best-effort */}
    try {
      await _signOut();
    } catch (_) {/* don't block clearing the local session */}
    emit(const AuthState.unauthenticated());
  }

  @override
  Future<void> close() {
    _authSub?.cancel();
    _userWatchSub?.cancel();
    return super.close();
  }
}
