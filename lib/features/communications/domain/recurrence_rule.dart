import 'package:opshub/core/enums/broadcast_recurrence.dart';

/// Pure, deterministic next-run computation for scheduled broadcasts
/// (Communications Center — Phase 2 Commit 4). Mirrors the task feature's
/// `RecurrenceConfig.nextOccurrence` pattern; kept in `domain` so it can be
/// unit-tested and reused by both the client (preview) and (conceptually) the
/// scheduler Cloud Function.
class RecurrenceRule {
  const RecurrenceRule._();

  /// The next run strictly **after** [from] for a schedule of [type] with the
  /// given [interval] (custom = every `interval` days), or `null` when the
  /// schedule has completed:
  /// - [oneTime] never has a "next" run (returns null);
  /// - an [endDate], when passed, caps the series (a computed run past it → null).
  ///
  /// [from] is the anchor (typically the last run, or the start date for the
  /// first run). All instants are treated as absolute (UTC-agnostic) — the
  /// timezone is baked into the stored `nextRunAt`/`startDate` at creation.
  static DateTime? nextRun(
    BroadcastRecurrence type,
    DateTime from, {
    int interval = 1,
    DateTime? endDate,
  }) {
    DateTime? next;
    switch (type) {
      case BroadcastRecurrence.oneTime:
        return null;
      case BroadcastRecurrence.daily:
        next = from.add(const Duration(days: 1));
      case BroadcastRecurrence.weekly:
        next = from.add(const Duration(days: 7));
      case BroadcastRecurrence.monthly:
        next = _addMonths(from, 1);
      case BroadcastRecurrence.custom:
        next = from.add(Duration(days: interval < 1 ? 1 : interval));
    }
    if (endDate != null && next.isAfter(endDate)) return null;
    return next;
  }

  /// Whether a one-time / recurring schedule is still active at [now] given its
  /// [enabled] flag, [nextRunAt], and optional [endDate].
  static bool isActive(
    bool enabled, {
    DateTime? nextRunAt,
    DateTime? endDate,
    DateTime? now,
  }) {
    if (!enabled) return false;
    final ref = now ?? DateTime.now();
    if (endDate != null && ref.isAfter(endDate)) return false;
    return nextRunAt != null;
  }

  /// Adds [months] calendar months, clamping the day to the target month's
  /// length (e.g. Jan 31 + 1 month → Feb 28/29).
  static DateTime _addMonths(DateTime d, int months) {
    final totalMonth = d.month - 1 + months;
    final year = d.year + (totalMonth ~/ 12);
    final month = totalMonth % 12 + 1;
    final lastDay = DateTime(year, month + 1, 0).day;
    final day = d.day <= lastDay ? d.day : lastDay;
    return DateTime(year, month, day, d.hour, d.minute, d.second);
  }
}
