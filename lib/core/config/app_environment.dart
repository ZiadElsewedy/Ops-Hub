import 'package:flutter/foundation.dart';

/// The two — and only two — deployment targets the app runs against.
enum AppEnvironmentType { development, production }

/// The resolved runtime environment — the single typed source of truth for
/// "which backend am I talking to and what environment am I".
///
/// ## The one rule: the backend follows the **build mode**, automatically.
///
/// There are no environment flags to remember and no source to edit. The URL is
/// a pure function of how the binary was compiled:
///
/// ```text
///   Debug / Profile  (flutter run)      →  Development  →  http://localhost:3000
///   Release          (flutter build …)  →  Production   →  Railway (HTTPS)
/// ```
///
/// * `flutter run` → always the **local** backend. Hot reload works as before.
/// * `flutter build apk|appbundle|ipa --release` → **always** Railway. It is
///   impossible for a release binary to resolve to localhost or an emulator IP:
///   the release URL is a hardcoded `const` and no dart-define can override it.
///
/// ### Optional LAN override (development only)
///
/// To test a debug build on a *physical* device against your Mac's local
/// backend, pass the LAN IP once:
///
/// ```bash
/// flutter run --dart-define=DEV_API_BASE_URL=http://192.168.1.8:3000
/// ```
///
/// This define is read **only** in debug/profile — it is ignored entirely in
/// release, so it can never leak into production.
@immutable
class AppEnvironment {
  const AppEnvironment._({required this.type, required this.apiBaseUrl});

  /// The environment name (`development` | `production`).
  final AppEnvironmentType type;

  /// Backend origin used for both the REST `ApiClient` and the Socket.IO
  /// namespace. No trailing slash.
  final String apiBaseUrl;

  bool get isProduction => type == AppEnvironmentType.production;
  bool get isDevelopment => type == AppEnvironmentType.development;
  String get name => type == AppEnvironmentType.production ? 'Production' : 'Development';

  /// Human-readable build mode for diagnostics ("Release" | "Profile" | "Debug").
  String get buildMode {
    if (kReleaseMode) return 'Release';
    if (kProfileMode) return 'Profile';
    return 'Debug';
  }

  // ── The two fixed backends. These are the source of truth. ────────────────

  /// Railway production backend. Compiled into every **release** binary.
  /// Change this (and only this) when the production host changes.
  static const String _productionBaseUrl =
      'https://drop-api-production.up.railway.app';

  /// Local dev backend for `flutter run` on the host / iOS Simulator / Android
  /// emulator (`10.0.2.2` is the emulator's alias for the host — override via
  /// [_devOverride] for a physical device on the LAN).
  static const String _developmentBaseUrl = 'http://localhost:3000';

  /// Optional dev-only LAN override (e.g. `http://192.168.1.8:3000`). Read only
  /// in debug/profile; never consulted in release.
  static const String _devOverride = String.fromEnvironment('DEV_API_BASE_URL');

  /// The resolved environment for this build. Computed once at first access.
  static final AppEnvironment current = _resolve();

  static AppEnvironment _resolve() {
    // Release builds are locked to production — full stop. No define, no config
    // file, and no accident can point a release artifact at localhost.
    if (kReleaseMode) {
      return const AppEnvironment._(
        type: AppEnvironmentType.production,
        apiBaseUrl: _productionBaseUrl,
      );
    }

    // Debug / profile → development. Allow an optional LAN override for testing
    // on a physical device; fall back to the local default otherwise.
    final override = _devOverride.trim();
    final baseUrl = _stripTrailingSlash(
      override.isEmpty ? _developmentBaseUrl : override,
    );
    return AppEnvironment._(
      type: AppEnvironmentType.development,
      apiBaseUrl: baseUrl,
    );
  }

  static String _stripTrailingSlash(String url) =>
      url.endsWith('/') ? url.substring(0, url.length - 1) : url;

  /// One-line startup banner: environment · build mode · resolved API URL.
  /// Printed once at boot so every log stream states which backend it hit.
  String get startupBanner => '''
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
🌍 Environment : $name
🔧 Build Mode  : $buildMode
🔗 API Base URL: $apiBaseUrl
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━''';

  @override
  String toString() => 'AppEnvironment($name, apiBaseUrl: $apiBaseUrl)';
}
