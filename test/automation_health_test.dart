import 'package:flutter_test/flutter_test.dart';
import 'package:opshub/core/enums/schedule_shift.dart';
import 'package:opshub/features/task/domain/entities/automation_health.dart';
import 'package:opshub/features/task/domain/entities/recurring_task_template_entity.dart';

RecurringTaskTemplateEntity _template({
  int runCount = 0,
  int successCount = 0,
  int failedCount = 0,
  int skippedCount = 0,
  int totalDurationMs = 0,
  int failureCount = 0,
  DateTime? lastSuccessAt,
  DateTime? lastFailureAt,
}) =>
    RecurringTaskTemplateEntity(
      id: 't',
      title: 'T',
      branchId: 'b',
      shift: ScheduleShift.morning,
      runCount: runCount,
      successCount: successCount,
      failedCount: failedCount,
      skippedCount: skippedCount,
      totalDurationMs: totalDurationMs,
      failureCount: failureCount,
      lastSuccessAt: lastSuccessAt,
      lastFailureAt: lastFailureAt,
    );

void main() {
  group('AutomationHealth.fromTemplate', () {
    test('derives success/failure rate and average duration from counters', () {
      final h = AutomationHealth.fromTemplate(_template(
        runCount: 10,
        successCount: 7,
        failedCount: 2,
        skippedCount: 1,
        totalDurationMs: 30000,
      ));
      expect(h.totalRuns, 10);
      expect(h.successRate, closeTo(0.7, 1e-9));
      expect(h.failureRate, closeTo(0.2, 1e-9));
      expect(h.averageDurationMs, 3000); // 30000 / 10
      expect(h.hasRuns, isTrue);
    });

    test('a never-run automation yields zeroed, safe values (no div-by-zero)', () {
      final h = AutomationHealth.fromTemplate(_template());
      expect(h.totalRuns, 0);
      expect(h.successRate, 0);
      expect(h.failureRate, 0);
      expect(h.averageDurationMs, 0);
      expect(h.hasRuns, isFalse);
      expect(h.isFailing, isFalse);
    });

    test('consecutive failures drive the isFailing signal', () {
      expect(
        AutomationHealth.fromTemplate(_template(runCount: 3, failureCount: 2))
            .isFailing,
        isTrue,
      );
      expect(
        AutomationHealth.fromTemplate(_template(runCount: 3, failureCount: 0))
            .isFailing,
        isFalse,
      );
    });

    test('average duration rounds to the nearest millisecond', () {
      final h = AutomationHealth.fromTemplate(
        _template(runCount: 3, totalDurationMs: 1000),
      );
      expect(h.averageDurationMs, 333); // 1000 / 3 = 333.33 → 333
    });

    test('carries the last success/failure timestamps through', () {
      final s = DateTime.utc(2026, 7, 18, 9);
      final f = DateTime.utc(2026, 7, 17, 9);
      final h = AutomationHealth.fromTemplate(
        _template(runCount: 2, lastSuccessAt: s, lastFailureAt: f),
      );
      expect(h.lastSuccessAt, s);
      expect(h.lastFailureAt, f);
    });
  });
}
