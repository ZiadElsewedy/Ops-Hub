import 'package:drop/core/config/app_environment.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

/// The environment is a pure function of the **build mode**:
///
///   Debug/Profile → Development → localhost
///   Release       → Production  → Railway (HTTPS)
///
/// `flutter test` always runs in debug, so [AppEnvironment.current] resolves to
/// Development here. The Development URL can be overridden for physical-device
/// LAN testing via `--dart-define=DEV_API_BASE_URL=...`.
void main() {
  const devOverride = String.fromEnvironment('DEV_API_BASE_URL');

  test('resolves a non-empty backend origin with no trailing slash', () {
    final env = AppEnvironment.current;
    expect(env.apiBaseUrl, isNotEmpty);
    expect(env.apiBaseUrl.endsWith('/'), isFalse);
  });

  test('tests run in Development (debug mode → local backend)', () {
    // Guard the invariant the tests rely on.
    expect(kReleaseMode, isFalse);

    final env = AppEnvironment.current;
    expect(env.type, AppEnvironmentType.development);
    expect(env.isDevelopment, isTrue);
    expect(env.isProduction, isFalse);
    expect(env.buildMode, anyOf('Debug', 'Profile'));
  });

  test('Development uses localhost, or the DEV_API_BASE_URL override', () {
    final env = AppEnvironment.current;
    if (devOverride.isEmpty) {
      expect(env.apiBaseUrl, 'http://localhost:3000');
    } else {
      expect(env.apiBaseUrl, devOverride.replaceAll(RegExp(r'/$'), ''));
    }
  });

  test('the startup banner reports environment, build mode, and URL', () {
    final banner = AppEnvironment.current.startupBanner;
    expect(banner, contains('Development'));
    expect(banner, contains(AppEnvironment.current.apiBaseUrl));
  });
}
