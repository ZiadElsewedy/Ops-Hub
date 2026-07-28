import 'package:flutter_test/flutter_test.dart';
import 'package:drop/core/enums/task_cancel_reason.dart';
import 'package:drop/core/enums/task_status.dart';
import 'package:drop/features/task/domain/entities/task_entity.dart';
import 'package:drop/features/task/domain/task_outcomes.dart';

/// The **four-way outcome classification** — `AUTOMATED_TASKS_PRODUCT_SPEC` §8
/// and §10, Phase 3.
///
/// The property under test throughout is that the four categories stay
/// *independent*. Approved is success, Missed is failure, Cancelled is neither
/// and counts nowhere, and Late is a timeliness signal that never becomes an
/// outcome. The headline rate must be **ungameable by cancellation** — that is
/// the whole reason Cancelled is excluded from both sides rather than just the
/// numerator, and it is asserted directly below.
void main() {
  TaskEntity task({
    required TaskStatus status,
    TaskCancelReason? cancelReason,
    DateTime? deadline,
    DateTime? submittedAt,
    DateTime? approvedAt,
  }) => TaskEntity(
    id: 't${status.name}${cancelReason?.value ?? ''}${submittedAt ?? ''}',
    title: 'Task',
    status: status,
    branchId: 'branch1',
    cancelReason: cancelReason,
    deadline: deadline,
    submittedAt: submittedAt,
    approvedAt: approvedAt,
  );

  group('completion rate (§10.1)', () {
    test('is Approved ÷ (Approved + Missed)', () {
      final o = taskOutcomes([
        for (var i = 0; i < 3; i++) task(status: TaskStatus.approved),
        task(status: TaskStatus.missed),
      ]);
      expect(o.approved, 3);
      expect(o.missed, 1);
      expect(o.scored, 4);
      expect(o.completionRatePct, 75);
    });

    test('is null — not 0% — until something has closed', () {
      final o = taskOutcomes([
        task(status: TaskStatus.pending),
        task(status: TaskStatus.started),
        task(status: TaskStatus.waitingReview),
      ]);
      expect(o.open, 3);
      expect(o.scored, 0);
      // A misleading 0% would read as total failure on a branch that has simply
      // not finished anything yet.
      expect(o.completionRatePct, isNull);
    });

    test('CANNOT be improved by cancelling work — the ungameable property', () {
      final base = [
        task(status: TaskStatus.approved),
        task(status: TaskStatus.missed),
      ];
      final before = taskOutcomes(base).completionRatePct;

      // A manager cancels five tasks they expect to fail. If Cancelled leaked
      // into the numerator the rate would jump; if it leaked into the
      // denominator only, the rate would collapse. Excluded from BOTH, it is
      // untouched — which is the entire point of §8.
      final after = taskOutcomes([
        ...base,
        for (var i = 0; i < 5; i++)
          task(
            status: TaskStatus.cancelled,
            cancelReason: TaskCancelReason.managementDecision,
          ),
      ]);

      expect(before, 50);
      expect(after.completionRatePct, 50);
      expect(after.scored, 2, reason: 'cancelled must not enter the denominator');
      expect(after.cancelled, 5, reason: 'but it is still reported on its own');
    });

    test('a fully-missed branch reads 0%, not null', () {
      final o = taskOutcomes([
        task(status: TaskStatus.missed),
        task(status: TaskStatus.missed),
      ]);
      // Real, earned zero — distinct from "nothing decided yet".
      expect(o.completionRatePct, 0);
    });
  });

  group('the hard invariant (§8)', () {
    test('Missed and Cancelled are counted separately and never summed', () {
      final o = taskOutcomes([
        task(status: TaskStatus.approved),
        task(status: TaskStatus.missed),
        task(
          status: TaskStatus.cancelled,
          cancelReason: TaskCancelReason.duplicate,
        ),
      ]);
      // They are different truths: one is work the branch owed and did not do,
      // the other is a decision that the work would not happen. There is
      // deliberately no "incomplete" figure anywhere on TaskOutcomes.
      expect(o.missed, 1);
      expect(o.cancelled, 1);
      expect(o.scored, 2, reason: 'approved + missed only');
    });

    test('cancelled work is not open work either', () {
      final o = taskOutcomes([
        task(status: TaskStatus.pending),
        task(
          status: TaskStatus.cancelled,
          cancelReason: TaskCancelReason.shiftCancelled,
        ),
      ]);
      expect(o.open, 1);
      expect(o.cancelled, 1);
    });
  });

  group('cancellations by reason (§10.3)', () {
    test('breaks the total down by code, most frequent first', () {
      final o = taskOutcomes([
        for (var i = 0; i < 3; i++)
          task(
            status: TaskStatus.cancelled,
            cancelReason: TaskCancelReason.noLongerNeeded,
          ),
        task(
          status: TaskStatus.cancelled,
          cancelReason: TaskCancelReason.duplicate,
        ),
      ]);

      expect(o.cancelled, 4);
      expect(o.cancelledByReason[TaskCancelReason.noLongerNeeded], 3);
      expect(o.cancelledByReason[TaskCancelReason.duplicate], 1);
      // The cluster is the signal — three "No Longer Needed" means a routine
      // that should be paused, so it must lead.
      expect(
        o.cancelReasonsByFrequency.first.key,
        TaskCancelReason.noLongerNeeded,
      );
    });

    test('a cancellation with no readable reason still counts', () {
      final o = taskOutcomes([
        task(status: TaskStatus.cancelled), // legacy / malformed doc
      ]);
      // An uncounted cancellation is worse than a vague one: it would make the
      // by-reason total silently disagree with the cancelled total.
      expect(o.cancelled, 1);
      expect(o.cancelledByReason[TaskCancelReason.unknown], 1);
      expect(
        o.cancelledByReason.values.fold<int>(0, (a, b) => a + b),
        o.cancelled,
      );
    });
  });

  group('Late as timeliness, never an outcome (§10.4)', () {
    final due = DateTime(2026, 7, 28, 16, 30);

    test('splits completed work by whether it beat its deadline', () {
      final o = taskOutcomes([
        task(
          status: TaskStatus.approved,
          deadline: due,
          submittedAt: due.subtract(const Duration(minutes: 10)),
        ),
        task(
          status: TaskStatus.approved,
          deadline: due,
          submittedAt: due.add(const Duration(minutes: 20)),
        ),
        task(
          status: TaskStatus.approved,
          deadline: due,
          submittedAt: due.add(const Duration(minutes: 40)),
        ),
      ]);

      expect(o.completedOnTime, 1);
      expect(o.completedLate, 2);
      expect(o.lateCompletionPct, 67);
      // Averaged over LATE work only — averaging across all completions would
      // dilute the coaching signal into noise.
      expect(o.averageLatenessMinutes, 30);
    });

    test('lateness never touches the completion rate', () {
      final allLate = taskOutcomes([
        for (var i = 0; i < 4; i++)
          task(
            status: TaskStatus.approved,
            deadline: due,
            submittedAt: due.add(Duration(minutes: 5 + i)),
          ),
      ]);
      // Late work was still *done*. Coaching data, never pass/fail.
      expect(allLate.completionRatePct, 100);
      expect(allLate.lateCompletionPct, 100);
    });

    test('work finished inside the grace period is simply on time or late by '
        'the clock — there is no Completed Late state', () {
      // ADR-013: a task submitted at 16:45 against a 16:30 deadline survived the
      // grace and is Approved. It reads *late* in timeliness — which is exactly
      // how the lateness signal is preserved without a fourth status.
      final o = taskOutcomes([
        task(
          status: TaskStatus.approved,
          deadline: due,
          submittedAt: due.add(const Duration(minutes: 15)),
        ),
      ]);
      expect(o.approved, 1);
      expect(o.missed, 0);
      expect(o.completedLate, 1);
      expect(o.averageLatenessMinutes, 15);
      expect(TaskStatus.values.map((s) => s.name), isNot(contains('completedLate')));
    });

    test('a task with no deadline is judged on neither side', () {
      final o = taskOutcomes([
        task(status: TaskStatus.approved, submittedAt: due),
        task(status: TaskStatus.approved, deadline: due),
      ]);
      expect(o.approved, 2);
      // No window to judge against — guessing would invent a signal.
      expect(o.completedOnTime, 0);
      expect(o.completedLate, 0);
      expect(o.lateCompletionPct, isNull);
      expect(o.averageLatenessMinutes, isNull);
    });

    test('falls back to approvedAt when the submission time is missing', () {
      final o = taskOutcomes([
        task(
          status: TaskStatus.approved,
          deadline: due,
          approvedAt: due.add(const Duration(minutes: 5)),
        ),
      ]);
      expect(o.completedLate, 1);
    });
  });

  test('an empty set reports nothing rather than zeroes', () {
    final o = taskOutcomes(const []);
    expect(o.isEmpty, isTrue);
    expect(o.completionRatePct, isNull);
    expect(o.lateCompletionPct, isNull);
    expect(o.cancelReasonsByFrequency, isEmpty);
  });
}
