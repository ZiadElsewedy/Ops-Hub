import 'package:flutter_test/flutter_test.dart';
import 'package:opshub/core/utils/concurrent.dart';

void main() {
  group('mapPooled', () {
    test('preserves result order regardless of completion order', () async {
      final results = await mapPooled<int>(2, [
        () async {
          await Future<void>.delayed(const Duration(milliseconds: 30));
          return 0;
        },
        () async {
          await Future<void>.delayed(const Duration(milliseconds: 5));
          return 1;
        },
        () async {
          await Future<void>.delayed(const Duration(milliseconds: 15));
          return 2;
        },
      ]);
      expect(results, [0, 1, 2]);
    });

    test('never exceeds the concurrency limit and does reach it', () async {
      var running = 0;
      var maxRunning = 0;
      Future<int> Function() task(int v) => () async {
            running++;
            if (running > maxRunning) maxRunning = running;
            await Future<void>.delayed(const Duration(milliseconds: 10));
            running--;
            return v;
          };
      final results =
          await mapPooled<int>(3, [for (var i = 0; i < 9; i++) task(i)]);
      expect(results, [0, 1, 2, 3, 4, 5, 6, 7, 8]);
      expect(maxRunning, lessThanOrEqualTo(3));
      expect(maxRunning, 3);
    });

    test('empty list returns empty', () async {
      expect(await mapPooled<int>(3, <Future<int> Function()>[]), isEmpty);
    });

    test('rethrows the first error and stops starting new tasks', () async {
      var started = 0;
      Future<int> Function() task(int v, {bool fail = false}) => () async {
            started++;
            await Future<void>.delayed(const Duration(milliseconds: 5));
            if (fail) throw StateError('boom $v');
            return v;
          };
      // limit 1 → strictly sequential; task index 1 fails, so tasks 2 & 3 must
      // never start.
      await expectLater(
        mapPooled<int>(1, [
          task(0),
          task(1, fail: true),
          task(2),
          task(3),
        ]),
        throwsA(isA<StateError>()),
      );
      expect(started, 2);
    });

    test('clamps a limit below 1 to a single worker', () async {
      final results = await mapPooled<int>(0, [
        () async => 1,
        () async => 2,
      ]);
      expect(results, [1, 2]);
    });
  });
}
