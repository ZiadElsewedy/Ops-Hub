import 'package:flutter_test/flutter_test.dart';
import 'package:opshub/core/enums/schedule_day.dart';
import 'package:opshub/core/enums/schedule_shift.dart';
import 'package:opshub/features/schedule/data/models/weekly_schedule_model.dart';
import 'package:opshub/features/schedule/domain/entities/weekly_schedule_entity.dart';
import 'package:opshub/features/schedule/domain/shift_hours.dart';

/// Configurable shift hours — the replacement for the hardcoded weekend close.
/// Covers the value object (overnight formatting, parse guards), the standing
/// default, per-week overrides resolved through `hoursFor`, and Firestore
/// round-tripping (so a manager-set 01:00 survives a reload).
void main() {
  group('ShiftHours value object', () {
    test('same-day range formats plainly', () {
      expect(const ShiftHours(990, 1380).format(), '16:30 – 23:00');
      expect(const ShiftHours(990, 1380).format(separator: '→'), '16:30 → 23:00');
      expect(const ShiftHours(990, 1380).crossesMidnight, isFalse);
    });

    test('overnight end wraps past midnight and is flagged', () {
      // 00:30 = 1470, 01:00 = 1500, 02:00 = 1560.
      expect(const ShiftHours(990, 1470).format(separator: '→'), '16:30 → 00:30');
      expect(const ShiftHours(990, 1500).format(separator: '→'), '16:30 → 01:00');
      expect(const ShiftHours(990, 1560).endLabel, '02:00');
      expect(const ShiftHours(990, 1500).crossesMidnight, isTrue);
    });

    test('hm factory builds overnight ends', () {
      expect(ShiftHours.hm(16, 30, 1, 0, endNextDay: true),
          const ShiftHours(990, 1500));
    });

    test('toMap/fromMap round-trip; malformed input is rejected', () {
      const h = ShiftHours(990, 1500);
      expect(ShiftHours.fromMap(h.toMap()), h);
      expect(ShiftHours.fromMap(null), isNull);
      expect(ShiftHours.fromMap({'start': 990}), isNull);
      expect(ShiftHours.fromMap({'start': 1000, 'end': 900}), isNull,
          reason: 'end must be after start');
      expect(ShiftHours.fromMap({'start': 990, 'end': 9999}), isNull,
          reason: 'absurd end is rejected');
    });
  });

  group('ShiftHours.standard (the standing default)', () {
    test('morning is 08:30–16:30 every day', () {
      for (final day in ScheduleDay.values) {
        expect(ShiftHours.standard(day, ScheduleShift.morning),
            const ShiftHours(510, 990));
      }
    });

    test('weekday night is 15:00–23:00', () {
      expect(ShiftHours.standard(ScheduleDay.monday, ScheduleShift.night),
          const ShiftHours(900, 1380));
    });

    test('operational-weekend nights are 16:00–00:00 (close at midnight)', () {
      for (final day in [
        ScheduleDay.thursday,
        ScheduleDay.friday,
        ScheduleDay.saturday
      ]) {
        expect(ShiftHours.standard(day, ScheduleShift.night),
            const ShiftHours(960, 1440));
        // Ending at 24:00 still counts as crossing midnight (endMinutes ≥ 1440).
        expect(
            ShiftHours.standard(day, ScheduleShift.night).crossesMidnight, isTrue);
      }
    });
  });

  group('WeeklyScheduleEntity.hoursFor (override ?? standard)', () {
    WeeklyScheduleEntity week({
      Map<ScheduleDay, Map<ScheduleShift, ShiftHours>> overrides = const {},
    }) =>
        WeeklyScheduleEntity(
          id: 'b1_w',
          branchId: 'b1',
          weekStart: DateTime(2026, 1, 4),
          shiftHours: overrides,
        );

    test('no override falls back to the standing default', () {
      final w = week();
      expect(w.hoursFor(ScheduleDay.monday, ScheduleShift.night),
          const ShiftHours(900, 1380));
      expect(w.hasHoursOverride(ScheduleDay.monday, ScheduleShift.night), isFalse);
    });

    test('a configured Saturday close of 01:00 is honoured', () {
      // The business change: Saturday now runs to 01:00 — set as data, no code.
      final w = week(overrides: {
        ScheduleDay.saturday: {ScheduleShift.night: const ShiftHours(990, 1500)},
      });
      final sat = w.hoursFor(ScheduleDay.saturday, ScheduleShift.night);
      expect(sat.endLabel, '01:00');
      expect(sat.format(separator: '→'), '16:30 → 01:00');
      expect(w.hasHoursOverride(ScheduleDay.saturday, ScheduleShift.night), isTrue);
      // Other days are untouched by one override.
      expect(w.hoursFor(ScheduleDay.friday, ScheduleShift.night),
          ShiftHours.standard(ScheduleDay.friday, ScheduleShift.night));
    });

    test('an override can push a special-event close arbitrarily late', () {
      final w = week(overrides: {
        ScheduleDay.thursday: {ScheduleShift.night: const ShiftHours(990, 1560)},
      });
      expect(w.hoursFor(ScheduleDay.thursday, ScheduleShift.night).endLabel,
          '02:00');
    });
  });

  group('Firestore serialization', () {
    test('shiftHours overrides survive a toMap → fromMap round-trip', () {
      final model = WeeklyScheduleModel(
        id: 'b1_w',
        branchId: 'b1',
        weekStart: DateTime(2026, 1, 4),
        shiftHours: {
          ScheduleDay.saturday: {
            ScheduleShift.night: const ShiftHours(990, 1500),
          },
        },
      );
      final restored =
          WeeklyScheduleModel.fromMap(model.toMap(), id: 'b1_w').toEntity();
      expect(restored.hoursFor(ScheduleDay.saturday, ScheduleShift.night),
          const ShiftHours(990, 1500));
      // A day with no override still resolves to the standard default.
      expect(restored.hoursFor(ScheduleDay.monday, ScheduleShift.night),
          const ShiftHours(900, 1380));
    });
  });
}
