import 'dart:math';

/// Minimal RFC 4122 **version 4** UUID generator — no package dependency.
///
/// Exists for the chat send flow: the backend deduplicates sends on a
/// client-minted UUID `idempotencyKey` (validated server-side with `isUuid`),
/// so the client needs a spec-compliant generator. [Random.secure] keeps
/// collision odds negligible; this is an idempotency token, not a secret.
class UuidV4 {
  UuidV4._();

  static final Random _rng = Random.secure();

  /// A new lowercase v4 UUID, e.g. `9f3b7a2e-8c41-4d6a-b1e0-5a2f9c8d7e6b`.
  static String generate() {
    final bytes = List<int>.generate(16, (_) => _rng.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40; // version 4
    bytes[8] = (bytes[8] & 0x3f) | 0x80; // variant 10xx
    final hex = [
      for (final b in bytes) b.toRadixString(16).padLeft(2, '0'),
    ];
    return '${hex.sublist(0, 4).join()}-'
        '${hex.sublist(4, 6).join()}-'
        '${hex.sublist(6, 8).join()}-'
        '${hex.sublist(8, 10).join()}-'
        '${hex.sublist(10).join()}';
  }
}
