import 'dart:developer' as developer;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:drop/core/constants/app_constants.dart';
import 'package:drop/core/utils/app_logger.dart';
import 'package:drop/core/utils/platform_capabilities.dart';

/// Firebase Cloud Messaging engine (Phase 6 foundation + Phase 2 receive
/// handling). Requests notification permission, keeps the device's FCM token in
/// the user's `fcmTokens` **array** (multi-device, refresh-aware, cleaned up on
/// sign-out), and routes incoming messages:
/// - **foreground** → [onForeground] (e.g. an in-app snackbar);
/// - **tap** (background-opened or cold-start) → [onMessageTap] with the push
///   `data` payload (category · senderId · broadcastId), for navigation.
///
/// Sending is done server-side by the `sendBroadcast` Cloud Function; this is
/// the client device + delivery side.
class NotificationService {
  final FirebaseMessaging _messaging;
  final FirebaseFirestore _firestore;

  /// The signed-in uid whose tokens we maintain.
  String? _uid;

  /// This device's current token (tracked so we can rotate it on refresh and
  /// remove it on sign-out — the array must not accumulate stale tokens).
  String? _currentToken;

  /// Set by the app to show foreground notifications in-app (e.g. a snackbar).
  /// Receives the push `data` payload too, so the in-app surface can offer a
  /// tappable action that deep-links to the same destination a background tap
  /// would (route · taskId · caseId · requestId · broadcastId).
  void Function(String? title, String? body, Map<String, dynamic> data)?
      onForeground;

  /// Set by the app to handle a notification **tap** (background-opened or
  /// cold-start launch). Receives the message `data` payload.
  void Function(Map<String, dynamic> data)? onMessageTap;

  NotificationService(this._messaging, this._firestore);

  /// One-time setup at app start: permission + message listeners. Best-effort —
  /// never throws (FCM is unsupported on some platforms).
  Future<void> init() async {
    AppLog.call('fcm', 'init');
    // Push is mobile-only: this build (e.g. macOS — no aps-environment
    // entitlement) can never finish APNS registration, so skip the permission
    // prompt and listeners entirely instead of warning on every launch.
    if (!supportsPushNotifications) {
      AppLog.success(
          'fcm', 'init skipped — push not supported on this platform');
      return;
    }
    try {
      final settings = await AppLog.time(
          'fcm',
          'requestPermission',
          () => _messaging.requestPermission(
              alert: true, badge: true, sound: true));
      // Whether the OS granted notification permission. `denied` /
      // `notDetermined` means iOS never registers with APNs, so `getAPNSToken()`
      // stays null forever and no push can arrive — the single most common
      // cause of "push works on Android, silently not on iOS".
      //
      // Deliberately AppLog, not developer.log: on a device/simulator the
      // `developer.log` line does NOT surface in `xcrun simctl log stream` or
      // the Xcode console, so this diagnostic was invisible on the exact
      // platform it exists to debug. AppLog lines do show.
      AppLog.success(
          'fcm', 'permission status = ${settings.authorizationStatus.name}');

      // iOS ONLY: without this, iOS shows nothing while the app is open — the
      // system suppresses the banner and only `onMessage` fires. Android is
      // unaffected (the OS posts to the `drop_default` channel itself), so this
      // call is gated to Apple platforms and changes no Android behaviour.
      if (requiresApnsToken) {
        await _messaging.setForegroundNotificationPresentationOptions(
          alert: true,
          badge: true,
          sound: true,
        );
      }

      // Foreground messages — suppressed if intended for a different account.
      FirebaseMessaging.onMessage.listen((message) {
        if (!_isForCurrentUser(message)) {
          _handleMismatch(message);
          return;
        }
        final n = message.notification;
        if (n != null) onForeground?.call(n.title, n.body, message.data);
      });

      // Tap handling — app opened from background by tapping the notification.
      FirebaseMessaging.onMessageOpenedApp.listen(_handleTap);

      // Tap handling — app launched from terminated state by a notification.
      final initial = await _messaging.getInitialMessage();
      if (initial != null) _handleTap(initial);

      // Token rotation: replace this device's stale token with the fresh one.
      _messaging.onTokenRefresh.listen((token) {
        final uid = _uid;
        if (uid != null) _rotateToken(uid, token);
      });
    } catch (_) {
      // FCM not available on this platform/build — ignore.
    }
  }

  /// Persist this device's token for [uid] (call after the user is
  /// authenticated, on login / app start).
  Future<void> registerToken(String uid) async {
    // Account switch on this device: the device's FCM token is the SAME across
    // accounts (getToken returns a per-device token, not per-user), so if the
    // previous session's `_currentToken` survives in memory (any switch path
    // that bypassed `forgetUser`), `_rotateToken`'s dedup guard
    // (`_currentToken == token && _uid == uid`) would no-op and the new user's
    // doc would NEVER get the token — every push to them then fails. Clearing it
    // on a uid change forces a fresh write, which `claimFcmToken` reclaims from
    // the prior owner. (L1 client gap behind the EXCLUSIVE-ownership guarantee.)
    if (_uid != uid) _currentToken = null;
    _uid = uid;
    AppLog.call('fcm', 'registerToken', details: 'uid=$uid');
    if (!supportsPushNotifications) {
      AppLog.success(
          'fcm', 'registerToken skipped — push not supported on this platform');
      return;
    }
    try {
      // Apple platforms: `getToken()` before the APNS token arrives is the
      // "APNS token has not been set yet" failure — the auth listener fires
      // this the instant sign-in completes, which is usually earlier than
      // APNS registration. Wait for it explicitly and bail cleanly when the
      // platform can't produce one (missing entitlement / simulator); the
      // `onTokenRefresh` listener re-registers when a token appears later.
      if (requiresApnsToken) {
        final apns = await _awaitApnsToken();
        if (apns == null) {
          AppLog.error('fcm',
              'registerToken aborted — APNS token not available after retrying '
              '(push entitlement missing, or APNs registration failed)');
          return;
        }
      }
      final token = await AppLog.time(
          'fcm', 'getToken', () => _messaging.getToken());
      // DIAGNOSTIC (temporary): did the device obtain an FCM token at all? A
      // null token = the device can't register (iOS without APNs/entitlement,
      // missing Play Services, permission denied). A non-null token that never
      // reaches Firestore points at the write (see _rotateToken below).
      developer.log(
        'registerToken uid=$uid token=${token == null ? "NULL" : "…${token.substring(token.length - 8)}"}',
        name: 'fcm',
      );
      if (token != null) await _rotateToken(uid, token);
    } catch (e) {
      developer.log('registerToken FAILED: $e', name: 'fcm');
      // Best-effort; push is non-critical to app function.
    }
  }

  /// Waits briefly for Apple to hand back the APNS token.
  ///
  /// **This is the iOS silent-failure guard.** `getAPNSToken()` returns null
  /// while APNs registration is still in flight, and the auth listener calls
  /// [registerToken] the instant sign-in completes — which is almost always
  /// earlier. A single null check therefore aborted registration on a cold
  /// start, and the old comment's claim that "`onTokenRefresh` re-registers when
  /// a token appears later" does **not** hold: that stream only fires when the
  /// **FCM** token *changes*. On a returning device the FCM token is already
  /// minted and unchanged, so nothing ever re-fired, the token never reached
  /// `users/{uid}.fcmTokens`, and every push to that device silently vanished.
  ///
  /// Polls up to ~5s, which comfortably covers normal APNs registration while
  /// still giving up on a build that genuinely cannot register (no entitlement,
  /// simulator). Returns `null` only after exhausting the budget.
  Future<String?> _awaitApnsToken({
    int attempts = 10,
    Duration gap = const Duration(milliseconds: 500),
  }) async {
    for (var i = 0; i < attempts; i++) {
      final token = await _messaging.getAPNSToken();
      if (token != null) {
        if (i > 0) {
          developer.log('APNS token arrived after ${i + 1} attempt(s)',
              name: 'fcm');
        }
        return token;
      }
      if (i < attempts - 1) await Future<void>.delayed(gap);
    }
    return null;
  }

  /// Remove this device's token (call on sign-out) so the signed-out account no
  /// longer receives this device's pushes, then stop tracking.
  Future<void> forgetUser() async {
    final uid = _uid;
    final token = _currentToken;
    if (uid != null && token != null) {
      try {
        await _firestore
            .collection(AppConstants.usersCollection)
            .doc(uid)
            .set({
          'fcmTokens': FieldValue.arrayRemove([token]),
        }, SetOptions(merge: true));
      } catch (_) {
        // Non-fatal.
      }
    }
    _uid = null;
    _currentToken = null;
  }

  void _handleTap(RemoteMessage message) {
    // Never route a tap for a notification meant for a different account.
    if (!_isForCurrentUser(message)) {
      _handleMismatch(message);
      return;
    }
    if (message.data.isNotEmpty) onMessageTap?.call(message.data);
  }

  /// Defense-in-depth #3 (client guard): whether [message] is intended for the
  /// currently signed-in user. The server stamps `data.recipientUid` on every
  /// push; a match (or an absent stamp — legacy / non-stamped messages) means
  /// it's for us. A **mismatch** means this device's token had drifted to the
  /// wrong user (interrupted logout, account-switch race, a token claimed before
  /// reconciliation) — so the notification is **dropped**, guaranteeing it never
  /// reaches the wrong account even if the server hasn't reconciled ownership yet.
  bool _isForCurrentUser(RemoteMessage message) {
    final intended = (message.data['recipientUid'] ?? '').toString().trim();
    if (intended.isEmpty) return true; // not stamped → allow (back-compat)
    return intended == _uid;
  }

  /// A push arrived for a different user on this device. Drop it (handled by the
  /// callers) and **self-heal**: re-register this device's token to the current
  /// user, so the server `claimFcmToken` reclaims it from the previous owner.
  void _handleMismatch(RemoteMessage message) {
    final intended = (message.data['recipientUid'] ?? '').toString();
    developer.log(
      'Dropped a push intended for "$intended" (current uid "$_uid") — '
      'token ownership drift; reclaiming this device for the current user.',
      name: 'fcm',
    );
    final uid = _uid;
    if (uid != null) registerToken(uid);
  }

  /// Adds [token] to the user's `fcmTokens` array and drops the previously
  /// tracked token for this device (token refresh), in a single merge write.
  Future<void> _rotateToken(String uid, String token) async {
    if (_currentToken == token && _uid == uid) return;
    try {
      final doc =
          _firestore.collection(AppConstants.usersCollection).doc(uid);
      final previous = _currentToken;
      await doc.set({
        'fcmTokens': FieldValue.arrayUnion([token]),
        'fcmTokenUpdatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      // Drop the stale token from this device (best-effort, separate op so a
      // failure never blocks adding the fresh one).
      if (previous != null && previous != token) {
        await doc.set({
          'fcmTokens': FieldValue.arrayRemove([previous]),
        }, SetOptions(merge: true));
      }
      _currentToken = token;
      // DIAGNOSTIC (temporary): the token write to users/{uid}.fcmTokens
      // succeeded — the recipient is now registered for push.
      developer.log('token written to users/$uid (push registered)', name: 'fcm');
    } catch (e) {
      // DIAGNOSTIC (temporary): a PERMISSION_DENIED here means firestore.rules
      // rejected the self-write of fcmTokens — the device stays unregistered and
      // every send to this user reports "0 delivered / failed".
      developer.log('token write FAILED for users/$uid: $e', name: 'fcm');
      // Non-fatal.
    }
  }
}
