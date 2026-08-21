import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:opshub/core/observability/crash_reporter.dart';

/// Global structured logging for OpsHub — the single entry point for every log
/// line in the app (no scattered `print`s).
///
/// Categories:
/// - 🟡 **CALL** — a function/flow was entered ([call], the start of [time]);
/// - 🟢 **SUCCESS** — it completed ([success], [time]'s fast completions);
/// - 🔵 **ROUTE** — navigation ([route]: pushes/pops/redirects);
/// - 🟣 **STATE** — cubit state transitions ([state], via [AppBlocObserver]);
/// - 🟠 **WARNING** — suspicious behaviour ([warning], slow ops from [time]);
/// - 🔴 **ERROR** — failures ([error]).
///
/// Every line carries a timestamp + module scope + message + optional
/// `meta` map (rendered `k=v`). Console output is **debug-only** ([enabled]);
/// every line is ALSO recorded into a bounded in-memory [breadcrumbs] ring —
/// always, including release — so a crash report can show the lead-up.
/// ANSI colours render in `flutter run` terminals; consoles that strip ANSI
/// (Xcode) still show the emoji.
class AppLog {
  AppLog._();

  /// Console switch — debug builds only by default. Breadcrumb recording is
  /// independent of this (always on, bounded, negligible).
  static bool enabled = kDebugMode;

  /// Async operations slower than this are logged as 🟠 WARNING, not 🟢.
  static const Duration slowThreshold = Duration(milliseconds: 1000);

  static const _yellow = '\x1B[33m';
  static const _green = '\x1B[32m';
  static const _red = '\x1B[31m';
  static const _cyan = '\x1B[36m';
  static const _magenta = '\x1B[35m';
  static const _orange = '\x1B[38;5;208m';
  static const _reset = '\x1B[0m';

  // ── Breadcrumbs (crash-report context) ─────────────────────────
  static const int _maxBreadcrumbs = 30;
  static final Queue<String> _breadcrumbs = Queue<String>();

  /// The most recent log lines (oldest first) — attached to crash reports.
  static List<String> get breadcrumbs => List.unmodifiable(_breadcrumbs);

  static String _stamp() {
    final n = DateTime.now();
    String p(int v, [int w = 2]) => v.toString().padLeft(w, '0');
    return '${p(n.hour)}:${p(n.minute)}:${p(n.second)}.${p(n.millisecond, 3)}';
  }

  static String _meta(Map<String, Object?>? meta) => meta == null ||
          meta.isEmpty
      ? ''
      : ' {${meta.entries.map((e) => '${e.key}=${e.value}').join(' ')}}';

  static void _emit(
    String color,
    String emoji,
    String category,
    String scope,
    String message,
  ) {
    final line = '$emoji [${_stamp()}][$category][$scope] $message';
    _breadcrumbs.addLast(line);
    if (_breadcrumbs.length > _maxBreadcrumbs) _breadcrumbs.removeFirst();
    if (enabled) debugPrint('$color$line$_reset');
  }

  /// 🟡 CALL — a function/flow was entered. Also records the "last action"
  /// on [CrashContext], so a crash report names what was running.
  static void call(String scope, String fn,
      {String? details, Map<String, Object?>? meta}) {
    CrashContext.lastAction = '$scope.$fn';
    _emit(_yellow, '🟡', 'CALL', scope,
        '$fn${details == null ? '' : ' ($details)'}${_meta(meta)}');
  }

  /// 🟢 SUCCESS — an operation completed.
  static void success(String scope, String message,
          {Map<String, Object?>? meta}) =>
      _emit(_green, '🟢', 'SUCCESS', scope, '$message${_meta(meta)}');

  /// 🔵 ROUTE — navigation events (pushes/pops/redirect decisions).
  static void route(String message, {Map<String, Object?>? meta}) =>
      _emit(_cyan, '🔵', 'ROUTE', 'nav', '$message${_meta(meta)}');

  /// 🟣 STATE — cubit/BLoC state transitions.
  static void state(String scope, String message,
          {Map<String, Object?>? meta}) =>
      _emit(_magenta, '🟣', 'STATE', scope, '$message${_meta(meta)}');

  /// 🟠 WARNING — suspicious but non-fatal behaviour.
  static void warning(String scope, String message,
          {Map<String, Object?>? meta}) =>
      _emit(_orange, '🟠', 'WARNING', scope, '$message${_meta(meta)}');

  /// 🔴 ERROR — a failure.
  static void error(String scope, String message,
      [Object? err, StackTrace? stack]) {
    _emit(_red, '🔴', 'ERROR', scope,
        '$message${err == null ? '' : ' — $err'}');
    if (stack != null && enabled) debugPrint('$_red$stack$_reset');
  }

  /// Times an async [operation]: 🟡 on entry; on completion
  /// `⏱ label finished in Nms` — 🟢 when fast, escalated to 🟠 WARNING past
  /// [slowThreshold]; 🔴 + rethrow on failure.
  static Future<T> time<T>(
    String scope,
    String label,
    Future<T> Function() operation,
  ) async {
    call(scope, label);
    final sw = Stopwatch()..start();
    try {
      final result = await operation();
      final ms = sw.elapsedMilliseconds;
      final message = '⏱ $label finished in ${ms}ms';
      if (sw.elapsed >= slowThreshold) {
        warning(scope, '$message (slow)');
      } else {
        success(scope, message);
      }
      return result;
    } catch (e) {
      error(scope, '⏱ $label failed after ${sw.elapsedMilliseconds}ms', e);
      rethrow;
    }
  }
}

/// Cubit lifecycle logging for every cubit in the app — wire once in `main`:
/// `Bloc.observer = AppBlocObserver();`. Transitions log the state
/// runtimeType only — never payloads, which can carry PII and flood the
/// console. Cubit errors are ALSO recorded as crash-context breadcrumbs.
class AppBlocObserver extends BlocObserver {
  /// `_Loaded` / `TaskLoaded` → `loaded` — the spec's readable short form.
  static String _short(Object? state) {
    var name = state.runtimeType.toString();
    if (name.startsWith('_')) name = name.substring(1);
    if (name.startsWith(r'$')) name = name.substring(1);
    return name.isEmpty ? '?' : name[0].toLowerCase() + name.substring(1);
  }

  @override
  void onCreate(BlocBase<dynamic> bloc) {
    super.onCreate(bloc);
    AppLog.call('cubit', '${bloc.runtimeType} created');
  }

  @override
  void onChange(BlocBase<dynamic> bloc, Change<dynamic> change) {
    super.onChange(bloc, change);
    AppLog.state('${bloc.runtimeType}',
        '${_short(change.currentState)} → ${_short(change.nextState)}');
  }

  @override
  void onError(BlocBase<dynamic> bloc, Object error, StackTrace stackTrace) {
    AppLog.error('cubit', '${bloc.runtimeType} threw', error, stackTrace);
    super.onError(bloc, error, stackTrace);
  }

  @override
  void onClose(BlocBase<dynamic> bloc) {
    super.onClose(bloc);
    AppLog.call('cubit', '${bloc.runtimeType} closed');
  }
}

/// Route logging for a [Navigator] — attached to GoRouter's `observers`
/// (root navigator) AND the ShellRoute's `observers` (the shell navigator,
/// where all in-shell page swaps happen). Every event also updates
/// [CrashContext] so crash reports carry the exact screen/route.
class LoggingNavigatorObserver extends NavigatorObserver {
  LoggingNavigatorObserver(this.label);

  /// Which navigator this observer watches (e.g. `root`, `shell`).
  final String label;

  String _name(Route<dynamic>? route) =>
      route?.settings.name ??
      route?.settings.runtimeType.toString() ??
      'unknown';

  void _setContext(Route<dynamic>? route) {
    final name = route?.settings.name;
    if (name != null) CrashContext.route = name;
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _setContext(route);
    AppLog.route(
        '[$label] push ${_name(route)} (from ${_name(previousRoute)})');
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _setContext(previousRoute);
    AppLog.route('[$label] pop ${_name(route)} (to ${_name(previousRoute)})');
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    _setContext(newRoute);
    AppLog.route('[$label] replace ${_name(oldRoute)} → ${_name(newRoute)}');
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      AppLog.route('[$label] remove ${_name(route)}');
}
