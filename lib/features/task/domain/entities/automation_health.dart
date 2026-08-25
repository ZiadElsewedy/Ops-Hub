import 'package:opshub/features/task/domain/entities/recurring_task_template_entity.dart';

/// Derived health of one automation, computed on read from the cumulative
/// counters the Cloud Function maintains on the template (ADR-011). Nothing here
/// is stored — success rate and average duration are derived from the raw
/// counters so no vanity metric is persisted (the line ADR-009 draws). The whole
/// object is a pure function of a single template document (one read).
class AutomationHealth {
  const AutomationHealth({
    required this.totalRuns,
    required this.successCount,
    required this.failedCount,
    required this.skippedCount,
    required this.consecutiveFailures,
    required this.averageDurationMs,
    this.lastSuccessAt,
    this.lastFailureAt,
    this.lastRunAt,
  });

  final int totalRuns;
  final int successCount;
  final int failedCount;
  final int skippedCount;
  final int consecutiveFailures;
  final int averageDurationMs;
  final DateTime? lastSuccessAt;
  final DateTime? lastFailureAt;
  final DateTime? lastRunAt;

  /// Fraction in `[0, 1]` of runs that completed. `0` when there are no runs
  /// (an unrun automation is neither healthy nor unhealthy — callers show "—").
  double get successRate => totalRuns == 0 ? 0 : successCount / totalRuns;

  /// Fraction in `[0, 1]` of runs that failed.
  double get failureRate => totalRuns == 0 ? 0 : failedCount / totalRuns;

  bool get hasRuns => totalRuns > 0;

  /// True when the most recent runs are consistently failing — the one signal
  /// worth surfacing prominently (mirrors the card's "needs attention").
  bool get isFailing => consecutiveFailures > 0;

  factory AutomationHealth.fromTemplate(RecurringTaskTemplateEntity t) {
    final runs = t.runCount;
    return AutomationHealth(
      totalRuns: runs,
      successCount: t.successCount,
      failedCount: t.failedCount,
      skippedCount: t.skippedCount,
      consecutiveFailures: t.failureCount,
      averageDurationMs: runs == 0 ? 0 : (t.totalDurationMs / runs).round(),
      lastSuccessAt: t.lastSuccessAt,
      lastFailureAt: t.lastFailureAt,
      lastRunAt: t.lastRunAt,
    );
  }
}
