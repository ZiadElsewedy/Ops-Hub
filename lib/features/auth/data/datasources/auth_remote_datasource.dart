import 'dart:async';
import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart' show PlatformException;
import 'package:opshub/core/errors/exceptions.dart';
import 'package:opshub/features/auth/data/models/user_model.dart';

/// Firebase Auth access. DROP is **admin-provisioned** — there is no public
/// registration, Google sign-in, or phone/OTP path here. Accounts are created
/// server-side by the `createUserAccount` Cloud Function; clients only sign in
/// with email/password, reset/change their password, and keep the Auth profile
/// (display name / photo) in sync with Firestore.
abstract class AuthRemoteDataSource {
  Stream<UserModel?> get authStateChanges;
  UserModel? get currentUser;

  Future<UserModel> signInWithEmail({required String email, required String password});
  Future<void> signOut();

  Future<void> sendPasswordResetEmail(String email);
  Future<void> updateDisplayName(String displayName);
  Future<void> updatePhotoUrl(String photoUrl);
  Future<void> changePassword({required String currentPassword, required String newPassword});
}

class AuthRemoteDataSourceImpl implements AuthRemoteDataSource {
  final FirebaseAuth _auth;

  AuthRemoteDataSourceImpl(this._auth);

  String _resolveProvider(User user) {
    if (user.providerData.isEmpty) return 'unknown';
    final id = user.providerData.first.providerId;
    if (id == 'password') return 'email';
    if (id == 'phone') return 'phone';
    return id;
  }

  @override
  Stream<UserModel?> get authStateChanges => _auth
      .authStateChanges()
      .map((u) => u == null
          ? null
          : UserModel.fromFirebaseUser(u, authProvider: _resolveProvider(u)));

  @override
  UserModel? get currentUser {
    final u = _auth.currentUser;
    return u == null
        ? null
        : UserModel.fromFirebaseUser(u, authProvider: _resolveProvider(u));
  }

  @override
  Future<UserModel> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      final user = credential.user;
      if (user == null) {
        throw const AuthException(
          'Sign in succeeded but no account was returned. Please try again.',
        );
      }
      return UserModel.fromFirebaseUser(user, authProvider: _resolveProvider(user));
    } on FirebaseAuthException catch (e) {
      throw AuthException(_resolveSignInError(e.code, e.message));
    } catch (e) {
      // Anything that is not a FirebaseAuthException (raw socket/DNS/SSL
      // failures, method-channel PlatformExceptions, timeouts) used to escape
      // this layer and surface as an opaque "no internet" string from the
      // native SDK. Map it to a precise, actionable message instead.
      throw AuthException(_resolveInfraError(e));
    }
  }

  String _resolveSignInError(String code, String? message) {
    switch (code) {
      // Modern Firebase collapses wrong-password / user-not-found into the
      // generic invalid-credential for email-enumeration protection.
      case 'invalid-credential':
      case 'wrong-password':
      case 'user-not-found':
        return 'Incorrect email or password. Please try again.';
      case 'invalid-email':
        return 'The email address is not valid.';
      case 'user-disabled':
        return 'This account has been disabled. Contact your administrator.';
      case 'too-many-requests':
        return 'Too many attempts. Please wait and try again.';
      case 'network-request-failed':
        // Distinct from "you're offline": on macOS this most often means the
        // request never left the sandbox (missing network.client entitlement)
        // or the auth host is unreachable — not a wrong password.
        return 'Could not reach the authentication server. Check your '
            'connection and that the app is allowed network access, then '
            'try again.';
      case 'operation-not-allowed':
        return 'Email/password sign-in is disabled for this project. '
            'Contact your administrator.';
      case 'keychain-error':
        // FirebaseAuth could not read/write the macOS login keychain while
        // persisting the session. On macOS this is an entitlement problem, not a
        // wrong password: the build needs the `keychain-access-groups`
        // entitlement (Keychain Sharing) in the entitlements file used by the
        // running configuration (DebugProfile.entitlements for `flutter run`).
        return 'Could not access the keychain to save your session. '
            'The app needs the Keychain Sharing entitlement on this build. '
            'Contact your administrator / rebuild after enabling it.';
      case 'api-key-not-valid':
      case 'invalid-api-key':
        return 'The app is misconfigured (invalid Firebase API key). '
            'Contact your administrator.';
      default:
        return message ?? 'Sign in failed. Please try again.';
    }
  }

  /// Maps non-Firebase infrastructure errors (socket/DNS/SSL/timeout/method
  /// channel) to precise, user-actionable messages. Keeps the generic
  /// "no internet" bucket from swallowing genuinely different root causes.
  String _resolveInfraError(Object error) {
    if (error is AuthException) return error.message;
    if (error is TimeoutException) {
      return 'The connection timed out. Check your network and try again.';
    }
    if (error is SocketException) {
      final msg = error.osError?.message.toLowerCase() ?? '';
      if (msg.contains('nodename') ||
          msg.contains('not known') ||
          msg.contains('resolve') ||
          error.message.toLowerCase().contains('failed host lookup')) {
        return 'Could not resolve the server address (DNS issue). '
            'Check your network/DNS settings and try again.';
      }
      return 'Unable to reach the server. The network may be down or the '
          'app may be blocked from making connections.';
    }
    if (error is HandshakeException || error is TlsException) {
      return 'A secure connection could not be established (SSL/TLS error). '
          'Check your system date/time and network, then try again.';
    }
    if (error is PlatformException) {
      final code = error.code.toLowerCase();
      if (code.contains('network')) {
        return 'Could not reach the authentication server. Check your '
            'connection and that the app is allowed network access.';
      }
      return error.message ?? 'Sign in failed (${error.code}). Please try again.';
    }
    return 'An unexpected error occurred during sign in. Please try again.';
  }

  @override
  Future<void> signOut() => _auth.signOut();

  @override
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } on FirebaseAuthException catch (e) {
      throw AuthException(_resolvePasswordResetError(e.code, e.message));
    } catch (e) {
      throw AuthException(_resolveInfraError(e));
    }
  }

  String _resolvePasswordResetError(String code, String? message) {
    switch (code) {
      case 'invalid-email':
        return 'The email address is not valid.';
      case 'user-not-found':
        return 'No account found with this email address.';
      case 'too-many-requests':
        return 'Too many requests. Please wait before trying again.';
      case 'network-request-failed':
        return 'Network error. Check your connection and try again.';
      default:
        return message ?? 'Failed to send reset email.';
    }
  }

  @override
  Future<void> updateDisplayName(String displayName) async {
    final user = _auth.currentUser;
    if (user == null) throw const AuthException('No user is signed in.');
    try {
      await user.updateDisplayName(displayName);
    } on FirebaseAuthException catch (e) {
      throw AuthException(e.message ?? 'Failed to update display name.');
    }
  }

  @override
  Future<void> updatePhotoUrl(String photoUrl) async {
    final user = _auth.currentUser;
    if (user == null) throw const AuthException('No user is signed in.');
    try {
      await user.updatePhotoURL(photoUrl);
    } on FirebaseAuthException catch (e) {
      throw AuthException(e.message ?? 'Failed to update photo.');
    }
  }

  @override
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw const AuthException('No user is signed in.');
    try {
      final credential = EmailAuthProvider.credential(
        email: user.email!,
        password: currentPassword,
      );
      await user.reauthenticateWithCredential(credential);
      await user.updatePassword(newPassword);
    } on FirebaseAuthException catch (e) {
      throw AuthException(_resolveChangePasswordError(e.code, e.message));
    } catch (e) {
      throw AuthException(_resolveInfraError(e));
    }
  }

  String _resolveChangePasswordError(String code, String? message) {
    switch (code) {
      case 'wrong-password':
      case 'invalid-credential':
        return 'Your current password is incorrect.';
      case 'weak-password':
        return 'New password is too weak. Use at least 6 characters.';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later.';
      case 'requires-recent-login':
        return 'Please sign out and sign in again before changing your password.';
      default:
        return message ?? 'Failed to change password.';
    }
  }
}
