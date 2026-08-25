import 'package:flutter_test/flutter_test.dart';
import 'package:opshub/core/enums/schedule_day.dart';
import 'package:opshub/core/enums/schedule_shift.dart';
import 'package:opshub/features/schedule/domain/entities/weekly_schedule_entity.dart';
import 'package:opshub/features/schedule/domain/swap_policy.dart';
import 'package:opshub/features/schedule/domain/swap_validation.dart';

WeeklyScheduleEntity _sched(
        Map<ScheduleDay, Map<ScheduleShift, List<String>>> assignments) =>
    WeeklyScheduleEntity(
      id: 'b_2026-06-21',
      branchId: 'b',
      weekStart: DateTime(2026, 6, 21),
      assignments: assignments,
    );

/// Pure verification of the swap-exchange rules (the single canonical definition,
/// mirrored in `functions/index.js`). Returns null when legal, a reason otherwise.
void main() {
  group('SwapValidation.check — slot integrity', () {
    final base = _sched({
      ScheduleDay.tuesday: {
        ScheduleShift.morning: ['ziad'],
        ScheduleShift.night: ['ahmed'],
      },
    });

    test('a clean opposite-shift exchange is valid', () {
      expect(
        SwapValidation.check(
          schedule: base,
          day: ScheduleDay.tuesday,
          requesterShift: ScheduleShift.morning,
          requesterId: 'ziad',
          targetId: 'ahmed',
        ),
        isNull,
      );
    });

    test('requester no longer on the claimed shift → rejected', () {
      expect(
        SwapValidation.check(
          schedule: base,
          day: ScheduleDay.tuesday,
          requesterShift: ScheduleShift.morning,
          requesterId: 'not-here',
          targetId: 'ahmed',
        ),
        isNotNull,
      );
    });

    test('target no longer on the opposite shift → rejected', () {
      expect(
        SwapValidation.check(
          schedule: base,
          day: ScheduleDay.tuesday,
          requesterShift: ScheduleShift.morning,
          requesterId: 'ziad',
          targetId: 'ghost',
        ),
        isNotNull,
      );
    });
  });

  group('SwapValidation.check — role compatibility', () {
    final base = _sched({
      ScheduleDay.tuesday: {
        ScheduleShift.morning: ['ziad'],
        ScheduleShift.night: ['ahmed'],
      },
    });

    test('restrict on + different positions → rejected', () {
      expect(
        SwapValidation.check(
          schedule: base,
          day: ScheduleDay.tuesday,
          requesterShift: ScheduleShift.morning,
          requesterId: 'ziad',
          targetId: 'ahmed',
          requesterPosition: 'Cashier',
          targetPosition: 'Supervisor',
          policy: const SwapPolicy(restrictToSamePosition: true),
        ),
        isNotNull,
      );
    });

    test('restrict on + matching positions → valid', () {
      expect(
        SwapValidation.check(
          schedule: base,
          day: ScheduleDay.tuesday,
          requesterShift: ScheduleShift.morning,
          requesterId: 'ziad',
          targetId: 'ahmed',
          requesterPosition: 'Cashier',
          targetPosition: 'Cashier',
          policy: const SwapPolicy(restrictToSamePosition: true),
        ),
        isNull,
      );
    });
  });

  group('SwapValidation.check — rest hours', () {
    // ziad also works Wednesday morning. Moving his Tuesday morning → night
    // shrinks the rest before Wednesday morning to 9.5h (Tue 23:00 → Wed 08:30).
    final sched = _sched({
      ScheduleDay.tuesday: {
        ScheduleShift.morning: ['ziad'],
        ScheduleShift.night: ['ahmed'],
      },
      ScheduleDay.wednesday: {
        ScheduleShift.morning: ['ziad'],
      },
    });

    test('an 11-hour minimum is violated → rejected', () {
      expect(
        SwapValidation.check(
          schedule: sched,
          day: ScheduleDay.tuesday,
          requesterShift: ScheduleShift.morning,
          requesterId: 'ziad',
          targetId: 'ahmed',
          policy: const SwapPolicy(minRestHours: 11),
        ),
        isNotNull,
      );
    });

    test('an 8-hour minimum is satisfied → valid', () {
      expect(
        SwapValidation.check(
          schedule: sched,
          day: ScheduleDay.tuesday,
          requesterShift: ScheduleShift.morning,
          requesterId: 'ziad',
          targetId: 'ahmed',
          policy: const SwapPolicy(minRestHours: 8),
        ),
        isNull,
      );
    });
  });
}
