import 'dart:io';
import 'dart:isolate';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:opshub/core/utils/app_logger.dart';

/// Ambient context stamped onto every crash report. Fed passively by the
/// systems that already see everything:
/// - [LoggingNavigatorObserver] sets [route] on every push/pop/replace;
/// - the auth listener in `main.dart` sets [userId]/[userRole] as the
///   session changes;
/// - [AppLog.call] records [lastAction] on every logged function entry.
class CrashContext {
  CrashContext._();

  /// Full path of the route on screen (e.g. `/admin/tasks`).
  static String? route;

  static String? userId;
  static String? userRole;

  /// The last `scope.function` that logged a 🟡 CALL — what was running.
  static String? lastAction;

  /// Friendly screen label — the last path segment of [route].
  static String? get screen {
    final r = route;
    if (r == null || r.isEmpty) return null;
    final segments = r.split('/').where((s) => s.isNotEmpty).toList();
    return segments.isEmpty ? 'home' : segments.last;
  }
}

/// Global crash capture for OpsHub. One funnel for every class of uncaught
/// error:
/// - **Flutter framework errors** → `FlutterError.onError`;
/// - **platform / engine + uncaught async errors** →
///   `PlatformDispatcher.instance.onError`;
/// - **zone-level uncaught errors** → the `runZonedGuarded` handler in
///   `main.dart` (belt-and-braces alongside the dispatcher hook);
/// - **isolate errors** → `Isolate.current.addErrorListener`.
///
/// Every capture produces one structured 🔴 CRASH report (timestamp · screen ·
/// route · user · role · error · full stacktrace · last action · the last 30
/// log breadcrumbs), logs it, and **persists it to disk even in release** —
/// on the next launch [pendingReport] surfaces it for export.
class CrashReporter {
  CrashReporter._();

  static const _fileName = 'last_crash.log';

  /// Serialize-in-flight guard so a crash storm can't stack file writes.
  static bool _writing = false;

  /// Install the global handlers. Call INSIDE the `runZonedGuarded` zone,
  /// after `WidgetsFlutterBinding.ensureInitialized()`.
  static void install() {
    // 1. Flutter framework errors (build/layout/paint/gesture).
    final previousFlutterHandler = FlutterError.onError;
    FlutterError.onError = (FlutterErrorDetails details) {
      record('flutter', details.exception, details.stack);
      // Keep the framework's debug behaviour (red screen + console dump).
      if (kDebugMode) {
        previousFlutterHandler?.call(details);
      }
    };

    // 2. Platform dispatcher — engine callbacks + uncaught async errors.
    //    Returning true marks the error handled so a recoverable error can't
    //    take the whole desktop app down.
    PlatformDispatcher.instance.onError = (error, stack) {
      record('platform', error, stack);
      return true;
    };

    // 3. Isolate errors (none spawned today; cheap forward-compat).
    Isolate.current.addErrorListener(RawReceivePort((dynamic pair) {
      final list = pair as List<dynamic>;
      record(
        'isolate',
        list.first ?? 'unknown isolate error',
        list.length > 1 && list[1] != null
            ? StackTrace.fromString(list[1].toString())
            : null,
      );
    }).sendPort);
  }

  /// The `runZonedGuarded` onError target (4th funnel).
  static void recordZoneError(Object error, StackTrace stack) =>
      record('zone', error, stack);

  /// A `WebSocketConnectionClosed` bubbling out of the socket teardown path —
  /// an expected transient (the peer or server closed the connection), never
  /// an application fault. Matched by type name so `crash_reporter` needn't
  /// depend on the transitive `web_socket` package that defines it.
  static bool _isBenignSocketClosure(Object error) =>
      error.runtimeType.toString() == 'WebSocketConnectionClosed';

  /// Build, log, and persist one structured crash report.
  static void record(String source, Object error, StackTrace? stack) {
    // A socket closing is not a crash. When the server disconnects a rejected
    // socket, socket_io_client tears the transport down in a microtask and
    // web_socket's `IOWebSocket.close()` throws `WebSocketConnectionClosed`
    // from a callback we don't own, so it escapes to the zone/platform funnels.
    // ChatSocketService already handles the closure (a backed-off reconnect) —
    // downgrade it to a breadcrumb instead of a 🔴 CRASH report.
    if (_isBenignSocketClosure(error)) {
      AppLog.warning('chat', 'socket closed ($source, non-fatal): $error');
      return;
    }
    final report = _buildReport(source, error, stack);
    AppLog.error('crash', 'uncaught ($source) — ${CrashContext.screen ?? '?'}',
        error);
    // Persist even in release — that's the observability payoff. Best-effort
    // and re-entrancy-guarded: the crash handler must never crash.
    if (!_writing) {
      _writing = true;
      _persist(report).whenComplete(() => _writing = false);
    }
  }

  static String _buildReport(String source, Object error, StackTrace? stack) {
    final b = StringBuffer()
      ..writeln('🔴 CRASH')
      ..writeln('Timestamp: ${DateTime.now().toIso8601String()}')
      ..writeln('Source: $source')
      ..writeln('Screen: ${CrashContext.screen ?? 'unknown'}')
      ..writeln('Route: ${CrashContext.route ?? 'unknown'}')
      ..writeln('Current user: ${CrashContext.userId ?? 'signed out'}')
      ..writeln('Role: ${CrashContext.userRole ?? '—'}')
      ..writeln('Error: $error')
      ..writeln('Last action: ${CrashContext.lastAction ?? '—'}')
      ..writeln('Stacktrace:')
      ..writeln(stack?.toString() ?? '(no stack trace)')
      ..writeln('Breadcrumbs (oldest first):');
    for (final line in AppLog.breadcrumbs) {
      b.writeln('  $line');
    }
    return b.toString();
  }

  static Future<File?> _crashFile() async {
    try {
      final dir = await getApplicationSupportDirectory();
      return File('${dir.path}${Platform.pathSeparator}$_fileName');
    } catch (_) {
      return null; // No usable storage on this platform — skip persistence.
    }
  }

  static Future<void> _persist(String report) async {
    try {
      final file = await _crashFile();
      await file?.writeAsString(report, flush: true);
    } catch (_) {
      // Never let crash persistence crash the crash handler.
    }
  }

  /// The report from a previous run, if that run crashed. Null when the last
  /// session ended cleanly.
  static Future<String?> pendingReport() async {
    try {
      final file = await _crashFile();
      if (file == null || !await file.exists()) return null;
      final content = await file.readAsString();
      return content.trim().isEmpty ? null : content;
    } catch (_) {
      return null;
    }
  }

  /// Delete the persisted report (after export or dismissal).
  static Future<void> clearPendingReport() async {
    try {
      final file = await _crashFile();
      if (file != null && await file.exists()) await file.delete();
    } catch (_) {
      // Non-fatal.
    }
  }
}
