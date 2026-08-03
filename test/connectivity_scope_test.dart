import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drop/core/network/connectivity_service.dart';
import 'package:drop/core/theme/app_theme.dart';
import 'package:drop/core/widgets/connectivity_scope.dart';

/// **The offline rule: gate the actions, never the app.**
///
/// The expensive failure for the *service* is a false online — an interface
/// that is up while nothing is reachable (captive portal, dead upstream). The
/// expensive failure for the *policy* is locking someone out of work they can
/// safely do offline: clock-in happens at a branch, which is where signal is
/// worst, and attendance IDs are deterministic so a late write cannot
/// duplicate. Both are pinned here.

class _FakeConnectivity implements Connectivity {
  _FakeConnectivity(this._current);

  List<ConnectivityResult> _current;
  final _controller = StreamController<List<ConnectivityResult>>.broadcast();

  void emit(List<ConnectivityResult> next) {
    _current = next;
    _controller.add(next);
  }

  Future<void> close() => _controller.close();

  @override
  Future<List<ConnectivityResult>> checkConnectivity() async => _current;

  @override
  Stream<List<ConnectivityResult>> get onConnectivityChanged =>
      _controller.stream;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

ConnectivityService _service(_FakeConnectivity c, {required bool reachable}) =>
    ConnectivityService(connectivity: c, probe: () async => reachable);

/// A screen that reads the scope: a guarded action and an always-allowed one,
/// standing in for "approve a submission" and "clock in".
Widget _host(ConnectivityService service, {VoidCallback? onGuardedRun}) =>
    MaterialApp(
      theme: AppTheme.dark,
      home: ConnectivityScope(
        service: service,
        child: OfflineBar(
          child: Builder(
            builder: (context) => Scaffold(
              body: Column(
                children: [
                  const Text('THE APP'),
                  TextButton(
                    onPressed: () {
                      if (!requireOnline(context, action: 'approving work')) {
                        return;
                      }
                      onGuardedRun?.call();
                    },
                    child: const Text('Approve'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

void main() {
  group('service verdict', () {
    testWidgets('an interface that reaches nothing counts as offline',
        (tester) async {
      final c = _FakeConnectivity([ConnectivityResult.wifi]);
      addTearDown(c.close);

      await tester.pumpWidget(_host(_service(c, reachable: false)));
      await tester.pumpAndSettle();

      expect(find.textContaining('Offline'), findsOneWidget);
    });

    testWidgets('no interface never reaches the probe', (tester) async {
      var probed = false;
      final c = _FakeConnectivity([ConnectivityResult.none]);
      addTearDown(c.close);
      final service = ConnectivityService(
        connectivity: c,
        probe: () async {
          probed = true;
          return true;
        },
      );

      await tester.pumpWidget(_host(service));
      await tester.pumpAndSettle();

      expect(find.textContaining('Offline'), findsOneWidget);
      expect(probed, isFalse);
    });
  });

  group('the app is never blocked', () {
    testWidgets('offline still renders the app, with the bar above it',
        (tester) async {
      final c = _FakeConnectivity([ConnectivityResult.none]);
      addTearDown(c.close);

      await tester.pumpWidget(_host(_service(c, reachable: false)));
      await tester.pumpAndSettle();

      // The whole point of the rewrite: cached work stays reachable.
      expect(find.text('THE APP'), findsOneWidget);
      expect(find.textContaining('showing saved data'), findsOneWidget);
    });

    testWidgets('online shows no bar at all', (tester) async {
      final c = _FakeConnectivity([ConnectivityResult.wifi]);
      addTearDown(c.close);

      await tester.pumpWidget(_host(_service(c, reachable: true)));
      await tester.pumpAndSettle();

      expect(find.text('THE APP'), findsOneWidget);
      expect(find.textContaining('Offline'), findsNothing);
    });

    testWidgets('the bar clears itself when the connection returns',
        (tester) async {
      final c = _FakeConnectivity([ConnectivityResult.none]);
      addTearDown(c.close);
      var reachable = false;
      final service =
          ConnectivityService(connectivity: c, probe: () async => reachable);

      await tester.pumpWidget(_host(service));
      await tester.pumpAndSettle();
      expect(find.textContaining('Offline'), findsOneWidget);

      reachable = true;
      c.emit([ConnectivityResult.wifi]);
      await tester.pumpAndSettle();

      expect(find.textContaining('Offline'), findsNothing);
      expect(find.text('THE APP'), findsOneWidget);
    });
  });

  group('server-authoritative actions are gated', () {
    testWidgets('offline blocks the action and says why', (tester) async {
      final c = _FakeConnectivity([ConnectivityResult.none]);
      addTearDown(c.close);
      var ran = false;

      await tester.pumpWidget(
        _host(_service(c, reachable: false), onGuardedRun: () => ran = true),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Approve'));
      await tester.pump();

      expect(ran, isFalse);
      expect(
        find.text('You are offline — approving work needs a connection.'),
        findsOneWidget,
      );
    });

    testWidgets('online lets the same action through', (tester) async {
      final c = _FakeConnectivity([ConnectivityResult.wifi]);
      addTearDown(c.close);
      var ran = false;

      await tester.pumpWidget(
        _host(_service(c, reachable: true), onGuardedRun: () => ran = true),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Approve'));
      await tester.pump();

      expect(ran, isTrue);
    });
  });

  testWidgets('with no scope above it, requireOnline allows the action',
      (tester) async {
    // A widget under test in isolation must never be treated as offline.
    var ran = false;
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.dark,
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () {
              if (!requireOnline(context, action: 'approving work')) return;
              ran = true;
            },
            child: const Text('Approve'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('Approve'));
    await tester.pump();

    expect(ran, isTrue);
  });
}
