import 'package:flutter_test/flutter_test.dart';
import 'package:opshub/core/observability/crash_reporter.dart';
import 'package:opshub/core/utils/app_logger.dart';

/// Phase 3 observability: breadcrumb recording, metadata rendering, timing
/// escalation, and crash-context derivation. Console output is disabled —
/// breadcrumbs must record regardless (they feed release crash reports).
void main() {
  setUp(() {
    AppLog.enabled = false;
    CrashContext.route = null;
    CrashContext.lastAction = null;
  });

  group('AppLog breadcrumbs', () {
    test('every category records a breadcrumb even with console off', () {
      AppLog.call('t', 'doThing');
      AppLog.success('t', 'done');
      AppLog.warning('t', 'odd');
      AppLog.state('TCubit', 'a → b');
      AppLog.route('push /x');
      AppLog.error('t', 'boom');
      final all = AppLog.breadcrumbs.join('\n');
      expect(all, contains('[CALL]'));
      expect(all, contains('[SUCCESS]'));
      expect(all, contains('[WARNING]'));
      expect(all, contains('[STATE]'));
      expect(all, contains('[ROUTE]'));
      expect(all, contains('[ERROR]'));
    });

    test('ring buffer stays bounded at 30', () {
      for (var i = 0; i < 100; i++) {
        AppLog.success('t', 'line $i');
      }
      expect(AppLog.breadcrumbs.length, 30);
      // Oldest lines dropped, newest kept.
      expect(AppLog.breadcrumbs.last, contains('line 99'));
      expect(AppLog.breadcrumbs.join(), isNot(contains('line 1 ')));
    });

    test('metadata renders as k=v pairs', () {
      AppLog.success('task', 'loaded', meta: {'count': 24, 'branch': 'b1'});
      expect(AppLog.breadcrumbs.last, contains('{count=24 branch=b1}'));
    });
  });

  group('AppLog.time', () {
    test('fast operation logs a ⏱ success with elapsed ms', () async {
      final result = await AppLog.time('t', 'fastOp', () async => 42);
      expect(result, 42);
      expect(AppLog.breadcrumbs.last, contains('⏱ fastOp finished in'));
      expect(AppLog.breadcrumbs.last, contains('[SUCCESS]'));
    });

    test('failure logs a red ⏱ line and rethrows', () async {
      await expectLater(
        AppLog.time<void>('t', 'badOp', () async => throw StateError('x')),
        throwsStateError,
      );
      expect(AppLog.breadcrumbs.last, contains('⏱ badOp failed'));
      expect(AppLog.breadcrumbs.last, contains('[ERROR]'));
    });
  });

  group('CrashContext', () {
    test('screen is the last segment of the route', () {
      CrashContext.route = '/admin/tasks';
      expect(CrashContext.screen, 'tasks');
      CrashContext.route = '/';
      expect(CrashContext.screen, 'home');
      CrashContext.route = null;
      expect(CrashContext.screen, isNull);
    });

    test('AppLog.call records the last action', () {
      AppLog.call('schedule', 'move');
      expect(CrashContext.lastAction, 'schedule.move');
    });
  });
}
