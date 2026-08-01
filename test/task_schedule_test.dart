import 'package:flutter_test/flutter_test.dart';
import 'package:drop/core/enums/schedule_shift.dart';
import 'package:drop/core/enums/task_status.dart';
import 'package:drop/features/schedule/domain/shift_hours.dart';
import 'package:drop/features/task/domain/entities/task_entity.dart';
import 'package:drop/features/task/domain/task_feed.dart';
import 'package:drop/features/task/domain/task_schedule.dart';

/// Task Scheduling V2 — the pure schedule math: smart-default windows from a
/// shift, the derived time-aware phase, and the "due soon" count.
void main() {
  TaskEntity task({
    TaskStatus status = TaskStatus.pending,
    DateTime? startsAt,
    DateTime? dueAt,
  }) => TaskEntity(
    id: 't',
    title: 't',
    status: status,
    startsAt: startsAt,
    deadline: dueAt,
  );

  group('shiftDefaultSchedule', () {
    test(
      'morning shift → same-day 08:30 → 16:30 (from the standard baseline)',
      () {
        final date = DateTime(2026, 7, 8); // Wed
        final w = shiftDefaultSchedule(date, ScheduleShift.morning);
        expect(w.start, DateTime(2026, 7, 8, 8, 30));
        expect(w.due, DateTime(2026, 7, 8, 16, 30));
      },
    );

    test('overnight hours roll the due instant into the next day', () {
      final date = DateTime(2026, 7, 9);
      // 16:30 → 00:30 next day (endMinutes 1470 > 1440).
      final w = shiftDefaultSchedule(
        date,
        ScheduleShift.night,
        hours: const ShiftHours(990, 1470),
      );
      expect(w.start, DateTime(2026, 7, 9, 16, 30));
      expect(w.due, DateTime(2026, 7, 10, 0, 30));
    });
  });

  group('schedulePhase', () {
    final now = DateTime(2026, 7, 8, 12, 0);

    test('terminal work is always done', () {
      final t = task(
        status: TaskStatus.approved,
        startsAt: now.add(const Duration(hours: 1)),
        dueAt: now.subtract(const Duration(hours: 1)),
      );
      expect(schedulePhase(t, now), TaskSchedulePhase.done);
      expect(
        schedulePhase(task(status: TaskStatus.waitingReview), now),
        TaskSchedulePhase.done,
      );
      expect(
        schedulePhase(task(status: TaskStatus.missed), now),
        TaskSchedulePhase.done,
      );
    });

    test('past due + non-terminal → overdue', () {
      final t = task(dueAt: now.subtract(const Duration(minutes: 5)));
      expect(schedulePhase(t, now), TaskSchedulePhase.overdue);
    });

    test('due within the window → dueSoon', () {
      final t = task(dueAt: now.add(const Duration(minutes: 20)));
      expect(schedulePhase(t, now), TaskSchedulePhase.dueSoon);
    });

    test('start still in the future → scheduled', () {
      final t = task(
        startsAt: now.add(const Duration(hours: 2)),
        dueAt: now.add(const Duration(hours: 6)),
      );
      expect(schedulePhase(t, now), TaskSchedulePhase.scheduled);
    });

    test('window is now (started, far from due) → active', () {
      final t = task(
        startsAt: now.subtract(const Duration(hours: 1)),
        dueAt: now.add(const Duration(hours: 4)),
      );
      expect(schedulePhase(t, now), TaskSchedulePhase.active);
    });

    test('no start/no due, non-terminal → active (graceful default)', () {
      expect(schedulePhase(task(), now), TaskSchedulePhase.active);
    });
  });

  group('canStartTaskNow', () {
    final now = DateTime(2026, 7, 8, 12, 0);

    test('null startsAt remains startable for manual and legacy rows', () {
      expect(canStartTaskNow(task(startsAt: null), now), isTrue);
      expect(startBlockedReason(task(startsAt: null), now), isNull);
    });

    test('blocks before the scheduled start', () {
      final t = task(startsAt: now.add(const Duration(minutes: 30)));
      expect(canStartTaskNow(t, now), isFalse);
      // 24-hour, to match the shift window shown beside it (`08:30 – 16:30`).
      expect(startBlockedReason(t, now), 'Starts at 12:30');
    });

    test('allows exactly at the scheduled start boundary', () {
      expect(canStartTaskNow(task(startsAt: now), now), isTrue);
    });

    test('allows after the scheduled start', () {
      expect(
        canStartTaskNow(
          task(startsAt: now.subtract(const Duration(seconds: 1))),
          now,
        ),
        isTrue,
      );
    });

    test('rejected/rework tasks are gated exactly like pending tasks', () {
      final future = now.add(const Duration(minutes: 15));
      expect(
        canStartTaskNow(
          task(status: TaskStatus.pending, startsAt: future),
          now,
        ),
        isFalse,
      );
      expect(
        canStartTaskNow(
          task(status: TaskStatus.rejected, startsAt: future),
          now,
        ),
        isFalse,
      );
    });
  });

  test('an upcoming pending task is scheduled, not overdue', () {
    final now = DateTime(2026, 7, 8, 12, 0);
    final t = task(
      startsAt: now.add(const Duration(hours: 1)),
      dueAt: now.add(const Duration(hours: 4)),
    );

    expect(schedulePhase(t, now), TaskSchedulePhase.scheduled);
    expect(isTaskOverdue(t, now), isFalse);
  });

  test('dueSoonCount counts only in-flight tasks inside the window', () {
    final now = DateTime(2026, 7, 8, 12, 0);
    final tasks = [
      task(dueAt: now.add(const Duration(minutes: 10))), // due soon
      task(dueAt: now.add(const Duration(minutes: 25))), // due soon
      task(dueAt: now.add(const Duration(hours: 3))), // active
      task(dueAt: now.subtract(const Duration(minutes: 5))), // overdue
      task(
        status: TaskStatus.approved,
        dueAt: now.add(const Duration(minutes: 5)),
      ), // done
    ];
    expect(dueSoonCount(tasks, now), 2);
  });

  group('assigneeShiftFit (smart default beyond shift assignment)', () {
    test('everyone on the same shift → unanimous', () {
      final r = assigneeShiftFit([
        [ScheduleShift.morning],
        [ScheduleShift.morning],
      ]);
      expect(r.fit, AssigneeShiftFit.unanimous);
      expect(r.shift, ScheduleShift.morning);
    });
    test('people on different shifts → mixed (no suggestion)', () {
      final r = assigneeShiftFit([
        [ScheduleShift.morning],
        [ScheduleShift.night],
      ]);
      expect(r.fit, AssigneeShiftFit.mixed);
      expect(r.shift, isNull);
    });
    test('nobody rostered → none', () {
      final r = assigneeShiftFit([<ScheduleShift>[], <ScheduleShift>[]]);
      expect(r.fit, AssigneeShiftFit.none);
    });
  });

  group('duration', () {
    test(
      'formatScheduleDuration renders compactly / empty for non-positive',
      () {
        expect(formatScheduleDuration(const Duration(hours: 8)), '8h');
        expect(
          formatScheduleDuration(const Duration(hours: 8, minutes: 30)),
          '8h 30m',
        );
        expect(formatScheduleDuration(const Duration(minutes: 45)), '45m');
        expect(formatScheduleDuration(Duration.zero), '');
        expect(formatScheduleDuration(const Duration(minutes: -10)), '');
      },
    );
    test(
      'scheduledDuration spans midnight (overnight) as a positive value',
      () {
        final t = TaskEntity(
          id: 't',
          title: 't',
          startsAt: DateTime(2026, 7, 8, 23, 0),
          deadline: DateTime(2026, 7, 9, 3, 0),
        );
        expect(scheduledDuration(t), const Duration(hours: 4));
      },
    );
  });
}
