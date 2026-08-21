import 'package:opshub/core/errors/failures.dart';

/// **NetworkGuard** — the one line that stops a write from being swallowed.
///
/// ## The problem it exists for
///
/// Firestore offline persistence is enabled, so a write issued with no
/// connection is accepted into the local cache, reported to the caller as a
/// success, and replayed whenever the connection returns. From the user's side
/// that reads as: *"I created the task, it said done, nobody got it, and an hour
/// later it appeared."* Nothing in the app was lying — the platform was doing
/// exactly what it promises — but the result is a silent, invisible delay on
/// operational work.
///
/// So every **write** repository method asks this first. Reads never do: serving
/// a cached roster is the whole point of the cache.
///
/// ## Why it is a cached flag and not a live check
///
/// The reachability probe is a DNS lookup that can take seconds. Running one in
/// front of every write would put that latency on the happy path, which is the
/// path that matters. The flag is kept fresh by `ConnectivityScope` off the same
/// `ConnectivityService` stream the UI uses, so the worst case here is one write
/// issued in the moment between the connection dropping and the probe noticing —
/// exactly the case Firestore's replay handles well.
///
/// ## Default is online, on purpose
///
/// Anything that never installs a status — a unit test, a widget test, a script
/// — must behave exactly as it did before this existed. Failing closed would
/// turn a missing wire-up into "every write in the app is broken", which is a
/// much worse failure than the one being prevented.
class NetworkGuard {
  NetworkGuard._();

  static bool _online = true;

  /// The last known verdict. See the class doc for why this defaults to `true`.
  static bool get isOnline => _online;

  /// Fed by `ConnectivityScope`. Exposed for tests, which set it directly.
  static void setOnline(bool value) => _online = value;

  /// Resets to the default. For test teardown.
  static void reset() => _online = true;

  /// Throws [OfflineFailure] when there is no connection.
  ///
  /// Call as the **first statement** of a write. Repository callers already sit
  /// under a cubit that catches `Failure` and emits its error state, so this
  /// surfaces to the user with no per-screen work.
  static void ensureWritable() {
    if (!_online) throw const OfflineFailure();
  }
}
