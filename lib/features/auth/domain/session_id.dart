import 'dart:math';

/// Mints the id that identifies **one sign-in on one device** — the value
/// written to `users/{uid}.activeSessionId` and to this device's
/// `SessionStore`. Pure Dart, injectable [random], so the format is unit-tested
/// without a platform channel.
///
/// 128 bits of entropy rendered as 32 lowercase hex characters. It must be
/// unguessable *and* collision-free across devices, because the whole
/// enforcement rule is a string comparison: two devices that ever minted the
/// same id would each believe they still own the session, and neither would be
/// evicted. A timestamp or a uid-derived value would not clear that bar.
///
/// Defaults to [Random.secure]; the seeded [Random] overload exists **only**
/// for tests. Never pass a seeded generator in production code.
String generateSessionId({Random? random}) {
  final rng = random ?? Random.secure();
  final buffer = StringBuffer();
  for (var i = 0; i < 16; i++) {
    buffer.write(rng.nextInt(256).toRadixString(16).padLeft(2, '0'));
  }
  return buffer.toString();
}
