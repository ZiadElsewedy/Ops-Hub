import 'package:flutter_test/flutter_test.dart';
import 'package:opshub/core/enums/schedule_day.dart';
import 'package:opshub/core/enums/schedule_shift.dart';
import 'package:opshub/features/schedule/domain/shift_hours.dart';
import 'package:opshub/features/schedule/domain/shift_window.dart';
import 'package:opshub/features/schedule/domain/swap_eligibility.dart';

/// Pure time math for shift slots — the midnight crossing is the case the whole
/// helper exists for: the standard weekend (Thu/Fri/Sat) night ends **00:00 the
/// next calendar day**, and a manager can push a close past midnight (e.g.
/// 01:00). A naive same-day end (00:00 ≤ 16:00) would mark every such evening
/// "finished".
void main() {
  // Sunday 2026-01-04 00:00 — a known, stable week start.
  final weekStart = DateTime(2026, 1, 4);

  group('start/end instants', () {
    test('start delegates to the swap-eligibility source of truth', () {
      for (final day in ScheduleDay.values) {
        for (final shift in ScheduleShift.values) {
          expect(
            ShiftWindow.start(weekStart, day, shift),
            SwapEligibility.slotStart(weekStart, day, shift),
          );
        }
      }
    });

    test('weekday night ends 23:00 the same day', () {
      expect(
        ShiftWindow.endOf(
          weekStart,
          ScheduleDay.monday,
          ShiftHours.standard(ScheduleDay.monday, ScheduleShift.night),
        ),
        DateTime(2026, 1, 5, 23, 0),
      );
    });

    test('weekend night ends 00:00 the NEXT day', () {
      expect(
        ShiftWindow.endOf(
          weekStart,
          ScheduleDay.thursday,
          ShiftHours.standard(ScheduleDay.thursday, ScheduleShift.night),
        ),
        DateTime(2026, 1, 9), // Thursday 8th 16:00 → Friday 9th 00:00
      );
    });

    test('morning ends 16:30 the same day', () {
      expect(
        ShiftWindow.endOf(
          weekStart,
          ScheduleDay.tuesday,
          ShiftHours.standard(ScheduleDay.tuesday, ScheduleShift.morning),
        ),
        DateTime(2026, 1, 6, 16, 30),
      );
    });

    test('configured starts and ends override the standing fallback', () {
      const custom = ShiftHours(600, 1560); // 10:00 → 02:00 next day
      expect(
        ShiftWindow.startOf(weekStart, ScheduleDay.friday, custom),
        DateTime(2026, 1, 9, 10),
      );
      expect(
        ShiftWindow.endOf(weekStart, ScheduleDay.friday, custom),
        DateTime(2026, 1, 10, 2),
      );
    });
  });

  group('phase', () {
    test(
      'standard weekend night is ACTIVE all evening and finishes at 00:00',
      () {
        const day = ScheduleDay.friday; // Friday 2026-01-09, night 16:00–00:00
        const night = ScheduleShift.night;
        final hours = ShiftHours.standard(day, night);
        expect(
          ShiftWindow.phaseOf(
            weekStart,
            day,
            night,
            hours,
            DateTime(2026, 1, 9, 15, 0),
          ),
          ShiftPhase.upcoming,
        );
        expect(
          ShiftWindow.phaseOf(
            weekStart,
            day,
            night,
            hours,
            DateTime(2026, 1, 9, 23, 30),
          ),
          ShiftPhase.active,
          reason: 'still on shift right up to the midnight close',
        );
        expect(
          ShiftWindow.phaseOf(
            weekStart,
            day,
            night,
            hours,
            DateTime(2026, 1, 10), // Saturday 00:00 sharp
          ),
          ShiftPhase.finished,
          reason: 'the interval is [start, end); it ends at midnight',
        );
      },
    );

    test('a night configured past midnight stays active after 00:00', () {
      const day = ScheduleDay.friday;
      const night = ScheduleShift.night;
      const late = ShiftHours(960, 1500); // 16:00 → 01:00 next day
      expect(
        ShiftWindow.phaseOf(
          weekStart,
          day,
          night,
          late,
          DateTime(2026, 1, 10, 0, 30), // Saturday 00:30
        ),
        ShiftPhase.active,
        reason: 'a configured overnight close carries past midnight',
      );
      expect(
        ShiftWindow.phaseOf(
          weekStart,
          day,
          night,
          late,
          DateTime(2026, 1, 10, 1, 0), // Saturday 01:00 sharp
        ),
        ShiftPhase.finished,
      );
    });

    test('morning phases across its boundaries', () {
      const day = ScheduleDay.monday; // Monday 2026-01-05
      const morning = ScheduleShift.morning;
      final hours = ShiftHours.standard(day, morning);
      expect(
        ShiftWindow.phaseOf(
          weekStart,
          day,
          morning,
          hours,
          DateTime(2026, 1, 5, 8, 0),
        ),
        ShiftPhase.upcoming,
      );
      expect(
        ShiftWindow.phaseOf(
          weekStart,
          day,
          morning,
          hours,
          DateTime(2026, 1, 5, 8, 30),
        ),
        ShiftPhase.active,
        reason: 'start is inclusive',
      );
      expect(
        ShiftWindow.phaseOf(
          weekStart,
          day,
          morning,
          hours,
          DateTime(2026, 1, 5, 18, 0),
        ),
        ShiftPhase.finished,
      );
    });

    test('custom start participates in phase checks', () {
      const custom = ShiftHours(600, 900); // 10:00 → 15:00
      expect(
        ShiftWindow.phaseOf(
          weekStart,
          ScheduleDay.monday,
          ScheduleShift.morning,
          custom,
          DateTime(2026, 1, 5, 9, 30),
        ),
        ShiftPhase.upcoming,
      );
      expect(
        ShiftWindow.phaseOf(
          weekStart,
          ScheduleDay.monday,
          ScheduleShift.morning,
          custom,
          DateTime(2026, 1, 5, 10),
        ),
        ShiftPhase.active,
      );
    });
  });

  group('nightSpillEnd (the post-midnight carry-over window)', () {
    // The standard weekend now closes at 00:00 (no spill past midnight); the
    // carry-over only exists when a manager configures a close after midnight,
    // so these exercise an explicit overnight close of 16:00 → 00:30.
    const overnight = ShiftHours(960, 1470); // 16:00 → 00:30 next day

    test('00:00–00:29 after an overnight night returns the end instant', () {
      // Friday 00:15 → Thursday night still running.
      expect(
        ShiftWindow.nightSpillEnd(DateTime(2026, 1, 9, 0, 15), overnight),
        DateTime(2026, 1, 9, 0, 30),
      );
      // Sunday 00:10 → Saturday night (previous week's doc).
      expect(
        ShiftWindow.nightSpillEnd(DateTime(2026, 1, 11, 0, 10), overnight),
        DateTime(2026, 1, 11, 0, 30),
      );
    });

    test('closes at the configured end sharp', () {
      expect(
        ShiftWindow.nightSpillEnd(DateTime(2026, 1, 9, 0, 30), overnight),
        null,
      );
    });

    test('weekday nights never spill (they end 23:00 the same day)', () {
      // Tuesday 00:15 → Monday was not an overnight night.
      expect(
        ShiftWindow.nightSpillEnd(
          DateTime(2026, 1, 6, 0, 15),
          ShiftHours.standard(ScheduleDay.monday, ScheduleShift.night),
        ),
        null,
      );
    });

    test('a standard weekend (00:00 close) never spills', () {
      // Ends exactly at midnight → nothing carries into the new day.
      expect(
        ShiftWindow.nightSpillEnd(
          DateTime(2026, 1, 9, 0, 0),
          ShiftHours.standard(ScheduleDay.thursday, ScheduleShift.night),
        ),
        null,
      );
    });

    test('daytime is never a spill window', () {
      expect(
        ShiftWindow.nightSpillEnd(DateTime(2026, 1, 9, 12, 0), overnight),
        null,
      );
    });

    test('custom overnight close defines the spill window', () {
      const late = ShiftHours(990, 1560); // 16:30 → 02:00
      expect(
        ShiftWindow.nightSpillEnd(DateTime(2026, 1, 9, 1, 45), late),
        DateTime(2026, 1, 9, 2),
      );
      expect(ShiftWindow.nightSpillEnd(DateTime(2026, 1, 9, 2), late), null);
    });
  });
}
