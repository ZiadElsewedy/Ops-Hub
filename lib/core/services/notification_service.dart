import 'dart:developer' as developer;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:opshub/core/constants/app_constants.dart';
import 'package:opshub/core/utils/app_logger.dart';
import 'package:opshub/core/utils/platform_capabilities.dart';
import 'package:opshub/features/notifications/domain/notification_deep_link.dart';

/// Whether a foreground FCM message is intentionally left to chat's
/// socket-backed in-app banner instead of surfacing a second notification.
///
/// Chat is the one route with **two** independent delivery paths — the chat
/// socket and FCM — so without this the same message notifies twice while the
/// app is open. The socket banner wins on Android because a foreground push
/// there reaches `onMessage` only and the OS draws nothing; on Apple platforms
/// the OS banner wins instead and `ChatNotificationListener` stands down (see
/// its `_onIncoming`). Every FCM data value is a string, but this stays lenient
/// for tests and legacy callers.
bool suppressForegroundFcmNotification(Map<String, dynamic> data) =>
    data['route']?.toString() == NotificationRoute.chat;

/// Firebase Cloud Messaging engine (Phase 6 foundation + Phase 2 receive
/// handling). Requests notification permission, keeps the device's FCM token in
/// the user's `fcmTokens` array — under single-active-session ([ADR-023]) that
/// array holds exactly **one** token, this device's: registering overwrites it,
/// so a newer sign-in on another device stops push to the old one immediately
/// (refresh-aware, cleaned up on sign-out) — and routes incoming messages:
/// - **foreground** → [onForeground] (e.g. an in-app snackbar);
/// - **tap** (background-opened or cold-start) → [onMessageTap] with the push
///   `data` payload (category · target ids · route), for navigation.
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
  /// would (route · taskId · caseId · requestId · broadcastId · conversationId).
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
      // What the OS actually granted. `denied` / `notDetermined`
      // means iOS may never complete APNs registration, so `getAPNSToken()`
      // stays null and no push can arrive.
      //
      // Deliberately AppLog, not developer.log: on a device the
      // `developer.log` line does NOT surface in the Xcode/Cursor console, so
      // this diagnostic was invisible on the exact platform it exists to debug.
      //
      // `alert`/`badge`/`sound` are logged separately from `authorizationStatus`
      // because they can be denied INDIVIDUALLY while the status still reads
      // `authorized` — a push then arrives and displays nothing, which looks
      // identical to "push is broken".
      AppLog.success(
          'fcm',
          'permission: status=${settings.authorizationStatus.name} '
          'alert=${settings.alert.name} badge=${settings.badge.name} '
          'sound=${settings.sound.name}');
      if (settings.authorizationStatus != AuthorizationStatus.authorized &&
          settings.authorizationStatus != AuthorizationStatus.provisional) {
        AppLog.error(
            'fcm',
            'notifications are ${settings.authorizationStatus.name} — iOS will '
            'not issue an APNs token, so no push can arrive until this is '
            'granted (Settings > Drop Operations > Notifications).');
      }

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
        // The chat socket listener is the only foreground chat surface. This
        // prevents Android's Dart-side snackbar from duplicating it; iOS's
        // system presentation is disabled above for the same reason.
        if (suppressForegroundFcmNotification(message.data)) return;
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
          AppLog.error(
              'fcm',
              'no APNs token after retrying — registration never completed, so '
              'no FCM token can be minted and no push can arrive.');
          return;
        }
        AppLog.success(
            'fcm', 'APNs token acquired (…${apns.substring(apns.length - 8)})');
      }
      final token = await AppLog.time(
          'fcm', 'getToken', () => _messaging.getToken());
      if (token == null) {
        AppLog.error(
            'fcm',
            'APNs token exists but getToken() returned null — FCM could not '
            'mint a token, which points at the Firebase app / APNs-key pairing '
            'rather than the device.');
        return;
      }
      AppLog.success(
          'fcm', 'FCM token (…${token.substring(token.length - 12)})');
      await _rotateToken(uid, token);
    } catch (e, st) {
      AppLog.error('fcm', 'registerToken THREW — $e');
      developer.log('registerToken FAILED: $e',
          name: 'fcm', error: e, stackTrace: st);
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
        // Only worth a line when it took more than one try — that is the signal
        // that registration is running slow rather than not happening at all.
        if (i > 0) {
          AppLog.success(
              'fcm', 'APNs token arrived on attempt ${i + 1}/$attempts');
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

  /// Makes [token] the **sole** entry in the user's `fcmTokens` array — the
  /// single active session invariant applied to push.
  ///
  /// Under single-active-session ([ADR-023]) one account = one signed-in
  /// device, so this device's token is the *whole* array. We therefore
  /// **overwrite** it rather than `arrayUnion`-ing: the token of a device this
  /// account was previously signed in on is a different, per-device string, and
  /// nothing else removes it. That old device only drops its own token
  /// (`forgetUser`) when it *processes* its eviction — which never happens while
  /// it is backgrounded or force-killed — so with `arrayUnion` its token lingers
  /// and the sender keeps pushing to it (the "notifications still arrive on the
  /// old phone" bug). Replacing the array here stops push to every other device
  /// the instant this one registers, independent of whether the old device ever
  /// comes back online.
  ///
  /// (Cross-*user* ownership — the same physical device switching accounts —
  /// is still reconciled server-side by `claimFcmToken`, which fires on the
  /// token being added and reclaims it from any other user.)
  Future<void> _rotateToken(String uid, String token) async {
    if (_currentToken == token && _uid == uid) {
      // Not an error, but it IS a way the token can appear "not uploaded":
      // this device already wrote this exact token for this uid in-process, so
      // there is nothing to re-persist.
      return;
    }
    try {
      final doc =
          _firestore.collection(AppConstants.usersCollection).doc(uid);
      await doc.set({
        // A plain array, not arrayUnion — this device is the only one that may
        // own the session, so it owns the whole token list. This evicts any
        // stale token left by a device that hasn't handled its own sign-out.
        'fcmTokens': [token],
        // Drop the pre-array legacy single field. The server push paths
        // (`onNotificationCreated`, `dispatchBroadcast`) read BOTH `fcmTokens`
        // and this legacy `fcmToken`; if a stale-but-still-live legacy value
        // lingered here it would be pushed to alongside the array token — the
        // same notification delivered twice. Nothing writes it any more, and
        // the array now carries this device's token, so clearing it removes an
        // entire duplicate-delivery class at the source on the next launch.
        'fcmToken': FieldValue.delete(),
        'fcmTokenUpdatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      _currentToken = token;
      AppLog.success('fcm',
          'token written to users/$uid.fcmTokens — device registered for push');
    } catch (e) {
      // A PERMISSION_DENIED here means firestore.rules rejected the self-write
      // of fcmTokens: the device stays unregistered and every send to this user
      // reports "0 delivered / failed".
      AppLog.error(
          'fcm',
          'token write to users/$uid rejected — $e. An FCM token exists but no '
          'server can find it, so every push to this user will report 0 delivered.');
      developer.log('token write FAILED for users/$uid: $e', name: 'fcm');
      // Non-fatal.
    }
  }
}
