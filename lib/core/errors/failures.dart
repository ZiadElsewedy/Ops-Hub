abstract class Failure {
  final String message;
  const Failure(this.message);
}

class ServerFailure extends Failure {
  const ServerFailure(super.message);
}

/// A write lost a race against a concurrent change (see [ConflictException]).
/// Carried as a [Failure] so it flows through the same cubit error channel, but
/// callers may treat it as benign (the realtime stream will deliver the true
/// state moments later).
class ConflictFailure extends Failure {
  const ConflictFailure(super.message);
}

class AuthFailure extends Failure {
  const AuthFailure(super.message);
}

class CacheFailure extends Failure {
  const CacheFailure(super.message);
}

/// A write was refused because the device is offline (see `NetworkGuard`).
///
/// Firestore's offline cache would otherwise accept the write silently and
/// replay it whenever the connection returns — so the user is told it worked,
/// nobody receives it, and it lands an hour later. This failure is what turns
/// that into an honest "not now". It rides the normal cubit error channel, so
/// every screen already surfaces it.
class OfflineFailure extends Failure {
  const OfflineFailure([super.message = _default]);

  static const _default =
      'You are offline. This needs a connection — try again once you are back.';
}
