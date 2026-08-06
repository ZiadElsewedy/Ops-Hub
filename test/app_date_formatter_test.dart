import 'package:flutter_test/flutter_test.dart';
import 'package:drop/core/utils/app_date_formatter.dart';

/// Locks the exact user-visible output of the single app date formatter. The
/// expected strings mirror the formats that used to be re-implemented across
/// ~20 feature files (and are asserted by the older activity/attachment tests),
/// so this doubles as the regression guard for the Sprint 1 consolidation.
void main() {
  group('AppDateFormatter.time (12h AM/PM)', () {
    test('afternoon, midnight, noon, late', () {
      expect(AppDateFormatter.time(DateTime(2026, 7, 6, 1, 43)), '1:43 AM');
      expect(AppDateFormatter.time(DateTime(2026, 7, 6, 0, 5)), '12:05 AM');
      expect(AppDateFormatter.time(DateTime(2026, 7, 6, 12, 0)), '12:00 PM');
      expect(AppDateFormatter.time(DateTime(2026, 7, 6, 16, 32)), '4:32 PM');
      expect(AppDateFormatter.time(DateTime(2026, 7, 6, 23, 30)), '11:30 PM');
    });
  });

  group('AppDateFormatter.time24 (24h, zero-padded)', () {
    test('pads the hour so it lines up with a shift window', () {
      expect(AppDateFormatter.time24(DateTime(2026, 7, 6, 8, 30)), '08:30');
      expect(AppDateFormatter.time24(DateTime(2026, 7, 6, 0, 5)), '00:05');
      expect(AppDateFormatter.time24(DateTime(2026, 7, 6, 12, 0)), '12:00');
      expect(AppDateFormatter.time24(DateTime(2026, 7, 6, 16, 30)), '16:30');
      expect(AppDateFormatter.time24(DateTime(2026, 7, 6, 23, 59)), '23:59');
    });
  });

  group('absolute date styles', () {
    final d = DateTime(2026, 7, 6, 16, 32);
    test('dayMonth', () => expect(AppDateFormatter.dayMonth(d), '6 Jul'));
    test('dayMonthYear',
        () => expect(AppDateFormatter.dayMonthYear(d), '6 Jul 2026'));
    test('monthDayYear',
        () => expect(AppDateFormatter.monthDayYear(d), 'Jul 6, 2026'));
    test('dayMonthYearTime', () {
      expect(AppDateFormatter.dayMonthYearTime(d), '6 Jul 2026 • 4:32 PM');
      expect(AppDateFormatter.dayMonthYearTime(DateTime(2026, 1, 5, 0, 5)),
          '5 Jan 2026 • 12:05 AM');
    });
    test('weekdayDayMonth (long weekday)',
        () => expect(AppDateFormatter.weekdayDayMonth(d), 'Monday, 6 Jul'));
    test('numeric', () => expect(AppDateFormatter.numeric(d), '6/7/2026'));
  });

  group('AppDateFormatter.relative', () {
    final now = DateTime(2026, 7, 6, 12, 0);
    test('just now / minutes / hours / days / absolute fallback', () {
      expect(AppDateFormatter.relative(now, now: now), 'Just now');
      expect(
          AppDateFormatter.relative(
              now.subtract(const Duration(seconds: 30)), now: now),
          'Just now');
      expect(
          AppDateFormatter.relative(
              now.subtract(const Duration(minutes: 5)), now: now),
          '5m ago');
      expect(
          AppDateFormatter.relative(
              now.subtract(const Duration(hours: 3)), now: now),
          '3h ago');
      expect(
          AppDateFormatter.relative(
              now.subtract(const Duration(days: 2)), now: now),
          '2d ago');
      // A week+ old falls back to the absolute day+month label.
      expect(
          AppDateFormatter.relative(DateTime(2026, 6, 19), now: now), '19 Jun');
    });
  });

  group('AppDateFormatter.relativeDay / relativeDayShort', () {
    final now = DateTime(2026, 7, 18, 10, 0);

    test('the three relative words are identical in both variants', () {
      for (final (day, word) in [
        (DateTime(2026, 7, 18, 8), 'Today'),
        (DateTime(2026, 7, 19, 8), 'Tomorrow'),
        (DateTime(2026, 7, 17, 8), 'Yesterday'),
      ]) {
        expect(AppDateFormatter.relativeDay(day, now: now), word);
        expect(AppDateFormatter.relativeDayShort(day, now: now), word);
      }
    });

    test('only the absolute branch differs — long weekday vs compact date', () {
      final soon = DateTime(2026, 7, 20, 16, 30);
      expect(AppDateFormatter.relativeDay(soon, now: now), 'Monday, 20 Jul');
      // The narrow-slot variant: `Thursday, 6…` says less than `6 Aug`.
      expect(AppDateFormatter.relativeDayShort(soon, now: now), '20 Jul');

      final nextYear = DateTime(2027, 1, 2, 8, 30);
      expect(AppDateFormatter.relativeDay(nextYear, now: now), '2 Jan 2027');
      expect(
        AppDateFormatter.relativeDayShort(nextYear, now: now),
        '2 Jan 2027',
      );
    });
  });

  group('AppDateFormatter.relativeDayTime', () {
    final now = DateTime(2026, 7, 18, 10, 0);

    test('a recent past execution reads Yesterday, not a bare weekday', () {
      expect(
        AppDateFormatter.relativeDayTime(
          DateTime(2026, 7, 17, 8, 30),
          now: now,
        ),
        'Yesterday • 8:30 AM',
      );
    });

    test('uses Today and Tomorrow for the next two local dates', () {
      expect(
        AppDateFormatter.relativeDayTime(
          DateTime(2026, 7, 18, 8, 30),
          now: now,
        ),
        'Today • 8:30 AM',
      );
      expect(
        AppDateFormatter.relativeDayTime(
          DateTime(2026, 7, 19, 16, 30),
          now: now,
        ),
        'Tomorrow • 4:30 PM',
      );
    });

    test('falls back to weekday/date, then includes the year', () {
      expect(
        AppDateFormatter.relativeDayTime(
          DateTime(2026, 7, 20, 16, 30),
          now: now,
        ),
        'Monday, 20 Jul • 4:30 PM',
      );
      expect(
        AppDateFormatter.relativeDayTime(DateTime(2027, 1, 2, 8, 30), now: now),
        '2 Jan 2027 • 8:30 AM',
      );
    });
  });
}
