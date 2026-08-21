import 'package:flutter_test/flutter_test.dart';
import 'package:opshub/core/enums/schedule_day.dart';
import 'package:opshub/core/enums/schedule_shift.dart';
import 'package:opshub/features/schedule/domain/entities/weekly_schedule_entity.dart';
import 'package:opshub/features/schedule/domain/move_validation.dart';
import 'package:opshub/features/schedule/domain/swap_policy.dart';

/// Schedule 4.0 — validation for manager/admin direct roster edits (move /
/// switch / remove). Blocked edits must return a user-facing reason; legal
/// ones return null.

WeeklyScheduleEntity _schedule(
    Map<ScheduleDay, Map<ScheduleShift, List<String>>> assignments) {
  return WeeklyScheduleEntity(
    id: 'b1_w',
    branchId: 'b1',
    weekStart: DateTime(2026, 6, 28),
    assignments: assignments,
  );
}

void main() {
  group('checkMove', () {
    final schedule = _schedule({
      ScheduleDay.monday: {
        ScheduleShift.morning: ['ziad'],
        ScheduleShift.night: ['richard'],
      },
      ScheduleDay.tuesday: {
        ScheduleShift.night: ['ziad'],
      },
    });

    test('a clean move is legal', () {
      expect(
        MoveValidation.checkMove(
          schedule: schedule,
          uid: 'ziad',
          name: 'Ziad',
          fromDay: ScheduleDay.monday,
          fromShift: ScheduleShift.morning,
          toDay: ScheduleDay.wednesday,
          toShift: ScheduleShift.morning,
        ),
        isNull,
      );
    });

    test('moving onto a slot the person already holds is blocked', () {
      final reason = MoveValidation.checkMove(
        schedule: schedule,
        uid: 'ziad',
        name: 'Ziad',
        fromDay: ScheduleDay.monday,
        fromShift: ScheduleShift.morning,
        toDay: ScheduleDay.tuesday,
        toShift: ScheduleShift.night,
      );
      expect(reason, contains('already on'));
    });

    test('a move that creates a double-booking is blocked with the day named',
        () {
      // Ziad already works Tuesday night; moving him onto Tuesday morning
      // would put him on both shifts that day.
      final reason = MoveValidation.checkMove(
        schedule: schedule,
        uid: 'ziad',
        name: 'Ziad',
        fromDay: ScheduleDay.monday,
        fromShift: ScheduleShift.morning,
        toDay: ScheduleDay.tuesday,
        toShift: ScheduleShift.morning,
      );
      expect(reason, contains('both shifts'));
      expect(reason, contains('Tuesday'));
    });

    test('moving to the same day\'s opposite shift is legal (source vacated)',
        () {
      // Monday morning → Monday night: he leaves morning, so no double-booking.
      expect(
        MoveValidation.checkMove(
          schedule: schedule,
          uid: 'ziad',
          name: 'Ziad',
          fromDay: ScheduleDay.monday,
          fromShift: ScheduleShift.morning,
          toDay: ScheduleDay.monday,
          toShift: ScheduleShift.night,
        ),
        isNull,
      );
    });
  });

  group('checkExchange', () {
    final schedule = _schedule({
      ScheduleDay.monday: {
        ScheduleShift.morning: ['ziad'],
        ScheduleShift.night: ['richard'],
      },
      ScheduleDay.tuesday: {
        ScheduleShift.morning: ['ahmed'],
        ScheduleShift.night: ['ziad'],
      },
    });

    test('a clean trade is legal', () {
      expect(
        MoveValidation.checkExchange(
          schedule: schedule,
          uidA: 'ziad',
          nameA: 'Ziad',
          dayA: ScheduleDay.monday,
          shiftA: ScheduleShift.morning,
          uidB: 'richard',
          nameB: 'Richard',
          dayB: ScheduleDay.monday,
          shiftB: ScheduleShift.night,
        ),
        isNull,
      );
    });

    test('a trade that double-books one side is blocked', () {
      // Ziad (Mon morning) ⇄ Ahmed (Tue morning): Ziad already works Tue
      // night, so landing on Tue morning double-books him.
      final reason = MoveValidation.checkExchange(
        schedule: schedule,
        uidA: 'ziad',
        nameA: 'Ziad',
        dayA: ScheduleDay.monday,
        shiftA: ScheduleShift.morning,
        uidB: 'ahmed',
        nameB: 'Ahmed',
        dayB: ScheduleDay.tuesday,
        shiftB: ScheduleShift.morning,
      );
      expect(reason, contains('both shifts'));
      expect(reason, contains('Ziad'));
    });

    test('same-day opposite-shift trade never counts vacated slots', () {
      // The classic swap: Mon morning ⇄ Mon night. Each vacates the slot the
      // other lands next to — no double-booking.
      expect(
        MoveValidation.checkExchange(
          schedule: schedule,
          uidA: 'ziad',
          nameA: 'Ziad',
          dayA: ScheduleDay.monday,
          shiftA: ScheduleShift.morning,
          uidB: 'richard',
          nameB: 'Richard',
          dayB: ScheduleDay.monday,
          shiftB: ScheduleShift.night,
        ),
        isNull,
      );
    });

    test('position policy blocks cross-position trades with the reason', () {
      final reason = MoveValidation.checkExchange(
        schedule: schedule,
        uidA: 'ziad',
        nameA: 'Ziad',
        dayA: ScheduleDay.monday,
        shiftA: ScheduleShift.morning,
        uidB: 'richard',
        nameB: 'Richard',
        dayB: ScheduleDay.monday,
        shiftB: ScheduleShift.night,
        positionA: 'Cashier',
        positionB: 'Supervisor',
        policy: const SwapPolicy(restrictToSamePosition: true),
      );
      expect(reason, contains('same-position'));
    });

    test('position policy passes same-position trades', () {
      expect(
        MoveValidation.checkExchange(
          schedule: schedule,
          uidA: 'ziad',
          nameA: 'Ziad',
          dayA: ScheduleDay.monday,
          shiftA: ScheduleShift.morning,
          uidB: 'richard',
          nameB: 'Richard',
          dayB: ScheduleDay.monday,
          shiftB: ScheduleShift.night,
          positionA: 'Cashier',
          positionB: 'cashier',
          policy: const SwapPolicy(restrictToSamePosition: true),
        ),
        isNull,
      );
    });
  });

  group('wouldEmptySlot', () {
    final schedule = _schedule({
      ScheduleDay.monday: {
        ScheduleShift.morning: ['ziad'],
        ScheduleShift.night: ['richard', 'ahmed'],
      },
    });

    test('true when the person is the only one on the slot', () {
      expect(
        MoveValidation.wouldEmptySlot(
          schedule: schedule,
          uid: 'ziad',
          day: ScheduleDay.monday,
          shift: ScheduleShift.morning,
        ),
        isTrue,
      );
    });

    test('false when coworkers remain', () {
      expect(
        MoveValidation.wouldEmptySlot(
          schedule: schedule,
          uid: 'richard',
          day: ScheduleDay.monday,
          shift: ScheduleShift.night,
        ),
        isFalse,
      );
    });
  });
}
