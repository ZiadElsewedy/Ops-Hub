import 'package:flutter_test/flutter_test.dart';
import 'package:opshub/core/enums/broadcast_recurrence.dart';
import 'package:opshub/features/communications/domain/recurrence_rule.dart';

/// Phase 2 Commit 4 — the pure recurrence engine for scheduled broadcasts.
void main() {
  final from = DateTime(2026, 6, 22, 9); // Mon 22 Jun 2026, 09:00

  group('RecurrenceRule.nextRun', () {
    test('one-time has no next run', () {
      expect(RecurrenceRule.nextRun(BroadcastRecurrence.oneTime, from), isNull);
    });

    test('daily / weekly advance by 1 / 7 days', () {
      expect(RecurrenceRule.nextRun(BroadcastRecurrence.daily, from),
          DateTime(2026, 6, 23, 9));
      expect(RecurrenceRule.nextRun(BroadcastRecurrence.weekly, from),
          DateTime(2026, 6, 29, 9));
    });

    test('monthly advances one calendar month, clamping the day', () {
      expect(RecurrenceRule.nextRun(BroadcastRecurrence.monthly, from),
          DateTime(2026, 7, 22, 9));
      // Jan 31 + 1 month → Feb 28 (2026 is not a leap year).
      expect(
        RecurrenceRule.nextRun(
            BroadcastRecurrence.monthly, DateTime(2026, 1, 31, 8)),
        DateTime(2026, 2, 28, 8),
      );
    });

    test('custom advances by interval days (min 1)', () {
      expect(RecurrenceRule.nextRun(BroadcastRecurrence.custom, from, interval: 3),
          DateTime(2026, 6, 25, 9));
      expect(RecurrenceRule.nextRun(BroadcastRecurrence.custom, from, interval: 0),
          DateTime(2026, 6, 23, 9));
    });

    test('a computed run past endDate stops the series', () {
      expect(
        RecurrenceRule.nextRun(
          BroadcastRecurrence.daily,
          from,
          endDate: DateTime(2026, 6, 22, 23),
        ),
        isNull,
      );
      expect(
        RecurrenceRule.nextRun(
          BroadcastRecurrence.daily,
          from,
          endDate: DateTime(2026, 6, 30),
        ),
        DateTime(2026, 6, 23, 9),
      );
    });
  });

  group('RecurrenceRule.isActive', () {
    test('disabled / no next-run / past end-date are inactive', () {
      final now = DateTime(2026, 6, 22, 12);
      expect(RecurrenceRule.isActive(false, nextRunAt: from, now: now), isFalse);
      expect(RecurrenceRule.isActive(true, nextRunAt: null, now: now), isFalse);
      expect(
        RecurrenceRule.isActive(true,
            nextRunAt: from, endDate: DateTime(2026, 6, 21), now: now),
        isFalse,
      );
      expect(
        RecurrenceRule.isActive(true,
            nextRunAt: DateTime(2026, 6, 23), now: now),
        isTrue,
      );
    });
  });
}
