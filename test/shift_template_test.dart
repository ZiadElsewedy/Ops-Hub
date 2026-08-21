import 'package:flutter_test/flutter_test.dart';
import 'package:opshub/core/enums/schedule_day.dart';
import 'package:opshub/core/enums/schedule_shift.dart';
import 'package:opshub/core/enums/shift_template_role.dart';
import 'package:opshub/features/schedule/domain/entities/weekly_schedule_entity.dart';
import 'package:opshub/features/schedule/domain/shift_hours.dart';
import 'package:opshub/features/schedule/domain/shift_plan.dart';
import 'package:opshub/features/schedule/domain/shift_template.dart';

/// Schedule V2 · Pillar 5 — the shift-template domain: role mapping, the
/// per-week [ShiftPlan] snapshot + resolution, the template library, and — the
/// load-bearing invariant — that legacy schedules resolve exactly as before.
void main() {
  WeeklyScheduleEntity schedule({
    ShiftPlan? plan,
    Map<ScheduleDay, Map<ScheduleShift, ShiftHours>> overrides = const {},
  }) =>
      WeeklyScheduleEntity(
        id: 'b1_2026-07-05',
        branchId: 'b1',
        weekStart: DateTime(2026, 7, 5),
        shiftPlan: plan,
        shiftHours: overrides,
      );

  group('ShiftTemplateRole.forSlot', () {
    test('maps every slot to its standing role', () {
      expect(ShiftTemplateRole.forSlot(ScheduleDay.sunday, ScheduleShift.morning),
          ShiftTemplateRole.morning);
      expect(ShiftTemplateRole.forSlot(ScheduleDay.sunday, ScheduleShift.night),
          ShiftTemplateRole.weekdayNight);
      // Thu/Fri/Sat nights are the operational weekend.
      expect(
          ShiftTemplateRole.forSlot(ScheduleDay.thursday, ScheduleShift.night),
          ShiftTemplateRole.weekendNight);
      expect(ShiftTemplateRole.forSlot(ScheduleDay.friday, ScheduleShift.morning),
          ShiftTemplateRole.morning);
    });
  });

  group('ShiftPlan', () {
    test('standard() matches the standing default hours', () {
      final p = ShiftPlan.standard();
      expect(p.morning, const ShiftHours(510, 990)); // 08:30–16:30
      expect(p.weekdayNight, const ShiftHours(900, 1380)); // 15:00–23:00
      expect(p.weekendNight, const ShiftHours(960, 1440)); // 16:00–00:00 (midnight)
    });

    test('forSlot splits weekday vs weekend night', () {
      final p = ShiftPlan(
        morning: const ShiftHours(540, 1020),
        weekdayNight: const ShiftHours(900, 1380), // 15:00–23:00
        weekendNight: const ShiftHours(960, 1500), // 16:00–01:00 overnight
      );
      expect(p.forSlot(ScheduleDay.sunday, ScheduleShift.morning),
          const ShiftHours(540, 1020));
      expect(p.forSlot(ScheduleDay.sunday, ScheduleShift.night),
          const ShiftHours(900, 1380));
      expect(p.forSlot(ScheduleDay.saturday, ScheduleShift.night),
          const ShiftHours(960, 1500));
    });

    test('toMap/fromMap round-trips including an overnight close', () {
      final p = ShiftPlan(
        morning: const ShiftHours(510, 990),
        weekdayNight: const ShiftHours(900, 1380),
        weekendNight: const ShiftHours(960, 1500),
      );
      expect(ShiftPlan.fromMap(p.toMap()), p);
    });

    test('fromMap → null for a non-map (absent field on a legacy doc)', () {
      expect(ShiftPlan.fromMap(null), isNull);
      expect(ShiftPlan.fromMap('nope'), isNull);
    });

    test('fromMap fills a missing/malformed slot from standard', () {
      final p = ShiftPlan.fromMap({'morning': const ShiftHours(600, 1000).toMap()});
      expect(p!.morning, const ShiftHours(600, 1000));
      expect(p.weekdayNight, ShiftPlan.standard().weekdayNight);
      expect(p.weekendNight, ShiftPlan.standard().weekendNight);
    });

    test('withRole replaces one role, leaves the others', () {
      final p = ShiftPlan.standard()
          .withRole(ShiftTemplateRole.weekendNight, const ShiftHours(960, 1560));
      expect(p.weekendNight, const ShiftHours(960, 1560));
      expect(p.morning, ShiftPlan.standard().morning);
    });
  });

  group('WeeklyScheduleEntity.hoursFor (resolution)', () {
    test('legacy week (no plan, no override) → standard', () {
      final s = schedule();
      expect(s.hoursFor(ScheduleDay.sunday, ScheduleShift.morning),
          const ShiftHours(510, 990));
      expect(s.hoursFor(ScheduleDay.sunday, ScheduleShift.night),
          const ShiftHours(900, 1380)); // weekday night 15:00–23:00
      expect(s.hoursFor(ScheduleDay.thursday, ScheduleShift.night),
          const ShiftHours(960, 1440)); // weekend night 16:00–00:00
    });

    test('the frozen snapshot resolves when present', () {
      final plan = ShiftPlan(
        morning: const ShiftHours(540, 1020),
        weekdayNight: const ShiftHours(900, 1380),
        weekendNight: const ShiftHours(960, 1500),
      );
      final s = schedule(plan: plan);
      expect(s.hoursFor(ScheduleDay.sunday, ScheduleShift.morning),
          const ShiftHours(540, 1020));
      expect(s.hoursFor(ScheduleDay.tuesday, ScheduleShift.night),
          const ShiftHours(900, 1380));
      expect(s.hoursFor(ScheduleDay.friday, ScheduleShift.night),
          const ShiftHours(960, 1500));
    });

    test('a per-slot override still beats the snapshot', () {
      final plan = ShiftPlan.standard();
      final s = schedule(plan: plan, overrides: {
        ScheduleDay.thursday: {ScheduleShift.night: const ShiftHours(990, 1560)},
      });
      expect(s.hoursFor(ScheduleDay.thursday, ScheduleShift.night),
          const ShiftHours(990, 1560));
      // Every other slot falls to the snapshot.
      expect(s.hoursFor(ScheduleDay.sunday, ScheduleShift.morning), plan.morning);
    });
  });

  group('ShiftTemplateSet', () {
    ShiftTemplate t(String id, String name, ShiftTemplateRole role, ShiftHours h) =>
        ShiftTemplate(id: id, branchId: 'b1', name: name, role: role, hours: h);

    test('plan resolves defined roles and falls back to standard for gaps', () {
      final set = ShiftTemplateSet([
        t('m', 'Morning', ShiftTemplateRole.morning, const ShiftHours(540, 1020)),
      ]);
      expect(set.plan.morning, const ShiftHours(540, 1020));
      expect(set.plan.weekdayNight, ShiftPlan.standard().weekdayNight);
      expect(set.plan.weekendNight, ShiftPlan.standard().weekendNight);
    });

    test('defaultsFor seeds the 3 standing roles, behaviour-neutral', () {
      final defaults =
          ShiftTemplateSet.defaultsFor('b1', idFor: (r) => 'b1__${r.value}');
      expect(defaults, hasLength(3));
      expect(defaults.map((d) => d.role), [
        ShiftTemplateRole.morning,
        ShiftTemplateRole.weekdayNight,
        ShiftTemplateRole.weekendNight,
      ]);
      // Seeding matches standard → adopting templates changes nothing.
      expect(ShiftTemplateSet(defaults).plan, ShiftPlan.standard());
    });

    test('validate flags empty + duplicate names (case-insensitive)', () {
      final set = ShiftTemplateSet([
        t('m', 'Morning', ShiftTemplateRole.morning, const ShiftHours(510, 990)),
        t('n', 'Night', ShiftTemplateRole.weekdayNight, const ShiftHours(990, 1380)),
      ]);
      expect(set.validate(''), ShiftTemplateError.emptyName);
      expect(set.validate('  '), ShiftTemplateError.emptyName);
      expect(set.validate('morning'), ShiftTemplateError.duplicateName);
      // Renaming a template to its own name is fine.
      expect(set.validate('Morning', excludingId: 'm'), isNull);
      expect(set.validate('Evening'), isNull);
    });
  });
}
