import 'package:opshub/core/config/app_environment.dart';

/// Configuration for the external NestJS API (chat backend).
///
/// This stays the **single source of truth** for the base URL used by both the
/// REST `ApiClient` and the Socket.IO namespace — one value wires the whole
/// backend. The value comes from the typed [AppEnvironment], which resolves it
/// purely from the **build mode** — no dart-defines, no config files, no manual
/// switching:
///
/// ```text
///   flutter run              → Development → http://localhost:3000
///   flutter build … --release → Production → Railway (HTTPS)
/// ```
///
/// A release binary is **locked** to Railway and can never resolve to localhost
/// (see [AppEnvironment]).
class NetworkConfig {
  NetworkConfig._();

  /// Backend origin for REST and Socket.IO. Resolved once via [AppEnvironment].
  static String get apiBaseUrl => AppEnvironment.current.apiBaseUrl;

  /// One ceiling for connect / send / receive — the API is a small internal
  /// service; anything slower than this is down, not slow.
  static const Duration timeout = Duration(seconds: 20);
}
