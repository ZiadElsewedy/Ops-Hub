import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opshub/core/enums/task_status.dart';
import 'package:opshub/features/task/domain/entities/task_entity.dart';
import 'package:opshub/core/widgets/live_status_border.dart';
import 'package:opshub/features/task/presentation/widgets/task_card.dart';

/// The per-state living-border orbit on task cards:
///  1. [liveActivityColor] maps each state → its persistent orbit colour (the
///     soft, muted palette); [liveOrbitSpeed] / [taskOverdue] drive per-state
///     speed and the overdue pulse.
///  2. [LiveStatusBorder] is a pass-through when inactive, orbits in the state
///     colour, eases smoothly to the new colour on a state change, and does one
///     graceful fading orbit before going static when a task settles.
TaskEntity _task(TaskStatus status, {DateTime? deadline}) =>
    TaskEntity(id: 't', title: 'T', status: status, deadline: deadline);

const _babyBlue = Color(0xFF7DD3FC);
const _purple = Color(0xFFA78BFA);
const _amber = Color(0xFFF59E0B);
const _softRed = Color(0xFFF87171);
const _orange = Color(0xFFFB923C);

void main() {
  final past = DateTime(2000);
  final future = DateTime(2999);

  group('liveActivityColor — per-state palette', () {
    test('each active state maps to its own soft colour', () {
      expect(liveActivityColor(_task(TaskStatus.pending)), _babyBlue);
      expect(liveActivityColor(_task(TaskStatus.started)), _purple);
      expect(liveActivityColor(_task(TaskStatus.waitingReview)), _amber);
      expect(liveActivityColor(_task(TaskStatus.rejected)), _softRed);
    });

    test('overdue → orange, overriding the base status colour', () {
      expect(
        liveActivityColor(_task(TaskStatus.started, deadline: past)),
        _orange,
      );
      expect(
        liveActivityColor(_task(TaskStatus.pending, deadline: past)),
        _orange,
      );
    });

    test('a not-yet-due task keeps its base state colour', () {
      expect(
        liveActivityColor(_task(TaskStatus.started, deadline: future)),
        _purple,
      );
    });

    test('approved / completed / missed → no orbit (null)', () {
      expect(liveActivityColor(_task(TaskStatus.approved)), isNull);
      expect(liveActivityColor(_task(TaskStatus.completed)), isNull);
      expect(
        liveActivityColor(_task(TaskStatus.missed, deadline: past)),
        isNull,
      );
    });
  });

  group('per-state speed + overdue pulse', () {
    test('subtle speed multipliers by state', () {
      expect(liveOrbitSpeed(_task(TaskStatus.pending)), 1.0);
      expect(liveOrbitSpeed(_task(TaskStatus.started)), 1.2);
      expect(liveOrbitSpeed(_task(TaskStatus.waitingReview)), 0.9);
      expect(liveOrbitSpeed(_task(TaskStatus.rejected)), 1.3);
      expect(liveOrbitSpeed(_task(TaskStatus.started, deadline: past)), 1.1);
    });

    test('pulse only for overdue', () {
      expect(taskOverdue(_task(TaskStatus.started)), isFalse);
      expect(taskOverdue(_task(TaskStatus.started, deadline: past)), isTrue);
      expect(taskOverdue(_task(TaskStatus.missed, deadline: past)), isFalse);
    });
  });

  group('LiveStatusBorder', () {
    Widget host(Color? color) => MaterialApp(
      home: Scaffold(
        body: Center(
          child: LiveStatusBorder(
            color: color,
            child: const SizedBox(key: Key('card'), width: 240, height: 130),
          ),
        ),
      ),
    );

    Object? orbitPainter(WidgetTester tester) => tester
        .widgetList<CustomPaint>(find.byType(CustomPaint))
        .map((cp) => cp.foregroundPainter)
        .firstWhere(
          (p) => p?.runtimeType.toString() == '_OrbitPainter',
          orElse: () => null,
        );
    bool hasOrbit(WidgetTester tester) => orbitPainter(tester) != null;
    String phase(WidgetTester tester) =>
        (orbitPainter(tester)! as dynamic).phase.toString();

    testWidgets('null colour → pass-through, no painter, settles', (
      tester,
    ) async {
      await tester.pumpWidget(host(null));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('card')), findsOneWidget);
      expect(hasOrbit(tester), isFalse);
    });

    testWidgets('active colour → orbits (steady), keeps looping', (
      tester,
    ) async {
      await tester.pumpWidget(host(_purple));
      await tester.pump(const Duration(milliseconds: 120));
      expect(hasOrbit(tester), isTrue);
      expect(phase(tester), contains('steady'));
      await tester.pump(const Duration(milliseconds: 4500));
      expect(hasOrbit(tester), isTrue);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('state change → smooth colour ease, then steady (no snap)', (
      tester,
    ) async {
      await tester.pumpWidget(host(_babyBlue)); // pending
      await tester.pump(const Duration(milliseconds: 40));
      expect(phase(tester), contains('steady'));
      await tester.pumpWidget(host(_purple)); // → started
      await tester.pump(const Duration(milliseconds: 40));
      expect(phase(tester), contains('changing'));
      expect(tester.takeException(), isNull);
      await tester.pump(const Duration(milliseconds: 400)); // past the ease
      expect(phase(tester), contains('steady'));
      expect(hasOrbit(tester), isTrue);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets(
      'terminal → one graceful fading orbit, then static (no painter)',
      (tester) async {
        await tester.pumpWidget(host(_purple));
        await tester.pump(const Duration(milliseconds: 60));
        expect(hasOrbit(tester), isTrue);
        await tester.pumpWidget(host(null)); // approved
        await tester.pump(const Duration(milliseconds: 80));
        expect(hasOrbit(tester), isTrue); // still doing its final orbit
        await tester.pump(const Duration(milliseconds: 4600));
        expect(hasOrbit(tester), isFalse); // faded out → static border only
      },
    );
  });
}
