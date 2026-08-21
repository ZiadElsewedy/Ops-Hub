import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Where this device keeps the id of the session it currently owns.
///
/// **The single local half of single-active-session enforcement.** On a
/// successful sign-in the auth layer mints a session id, writes it here, and
/// claims it on `users/{uid}.activeSessionId`. The live user-document watcher
/// then compares the two on every emission: when the remote id no longer
/// matches the one stored here, another device has taken the session over and
/// this one signs itself out.
///
/// Deliberately **not** one of the uid-namespaced JSON stores in
/// `core/services/` (`case_seen_store` · `task_seen_store` ·
/// `notification_preferences_store`). Those hold per-user *preferences* — a
/// user editing them costs nothing. This holds the value that decides whether a
/// device stays signed in, so it lives in the platform keystore (Keychain on
/// iOS/macOS, `EncryptedSharedPreferences` on Android) instead of a plain file
/// in the app-support directory.
///
/// It is a **contract, not an implementation**, so the enforcement logic in
/// `AuthCubit` is testable without a platform channel — see [InMemorySessionStore].
abstract class SessionStore {
  /// The session id this device last claimed, or `null` when it has never
  /// claimed one (a fresh install, or after [clear]).
  Future<String?> read();

  /// Records [sessionId] as the session this device owns.
  Future<void> write(String sessionId);

  /// Forgets this device's session id (sign-out, or eviction by another device).
  Future<void> clear();
}

/// The production [SessionStore] — platform keystore backed.
///
/// Every operation is **best-effort**: a keystore read/write can fail on a
/// device with a broken or locked keychain, and losing this value must never
/// stop someone from signing in. A failed [read] degrades to `null`, which the
/// auth layer treats as "this device claims nothing" — the conservative
/// direction, since a null local id never *evicts* a session (see
/// `AuthCubit._isSessionTakenOver`).
class SecureSessionStore implements SessionStore {
  /// One key for the whole app: OpsHub is single-account-per-device by design
  /// (admin-provisioned, no account switcher), and the id is meaningless
  /// without the Firebase session it was minted alongside.
  static const String _key = 'drop.active_session_id';

  final FlutterSecureStorage _storage;

  const SecureSessionStore([
    this._storage = const FlutterSecureStorage(
      // Survives an app restart but never a backup restore onto another
      // device — a restored id would let a phone impersonate the session that
      // was claimed on the phone it was restored from.
      iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock_this_device),
      // `resetOnError` is the Samsung/Android hardening: EncryptedSharedPreferences
      // keeps its AES master key in the hardware AndroidKeyStore, and on Samsung
      // that key is regularly invalidated out from under the app (a keystore
      // hiccup, an OS/security-patch update, a Smart Switch/Samsung Cloud
      // restore). A decrypt against a mismatched key throws
      // `AEADBadTagException`/`InvalidKeyException` — or, worse for us, could
      // surface a *stale* claim. With this on, the plugin wipes the corrupt store
      // and returns cleanly, so [read] degrades to `null` — which the auth layer
      // treats as "this device claims nothing" and therefore NEVER evicts (see
      // `AuthCubit._isSessionTakenOver`). Without it a corrupt read could return
      // a leftover id that mismatches the remote claim and sign a legitimate
      // device out as a false "signed in on another device".
      aOptions: AndroidOptions(
        encryptedSharedPreferences: true,
        resetOnError: true,
      ),
      mOptions: MacOsOptions(accessibility: KeychainAccessibility.first_unlock_this_device),
    ),
  ]);

  @override
  Future<String?> read() async {
    try {
      final value = await _storage.read(key: _key);
      final trimmed = value?.trim();
      return (trimmed == null || trimmed.isEmpty) ? null : trimmed;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> write(String sessionId) async {
    try {
      await _storage.write(key: _key, value: sessionId);
    } catch (_) {/* best-effort — see class doc */}
  }

  @override
  Future<void> clear() async {
    try {
      await _storage.delete(key: _key);
    } catch (_) {/* best-effort — see class doc */}
  }
}

/// An in-memory [SessionStore] for tests and for any build where the platform
/// keystore is unavailable. Holds nothing across a restart, which for the
/// enforcement rules reads as "a device that has never claimed a session".
class InMemorySessionStore implements SessionStore {
  String? _value;

  InMemorySessionStore([this._value]);

  @override
  Future<String?> read() async => _value;

  @override
  Future<void> write(String sessionId) async => _value = sessionId;

  @override
  Future<void> clear() async => _value = null;
}
