import 'package:flutter_test/flutter_test.dart';
import 'package:drop/core/enums/schedule_shift.dart';
import 'package:drop/features/attendance/domain/reporting/attendance_ledger_row.dart';
import 'package:drop/features/attendance/domain/reporting/attendance_week_review.dart';

void main() {
  final reviewedAt = DateTime(2026, 8, 1, 18);

  AttendanceWeekReview review({String? name = 'Manager One'}) =>
      AttendanceWeekReview(
        branchId: 'b1',
        weekStartKey: '20260726',
        reviewedBy: 'mgr1',
        reviewedByName: name,
        reviewedAt: reviewedAt,
      );

  AttendanceLedgerRow row({DateTime? closedAt, DateTime? restatedAt}) =>
      AttendanceLedgerRow(
        id: 'u1_20260729_morning',
        rowId: 'u1_20260729_morning',
        userId: 'u1',
        branchId: 'b1',
        dayKey: '20260729',
        businessDate: '2026-07-29',
        shift: ScheduleShift.morning,
        outcome: AttendanceLedgerOutcome.worked,
        expected: true,
        locked: false,
        version: 1,
        source: 'system',
        closedAt: closedAt,
        restatedAt: restatedAt,
      );

  test('the id is deterministic, so reviewing twice updates in place', () {
    expect(
      AttendanceWeekReview.idFor('b1', DateTime(2026, 7, 26)),
      'b1_20260726',
    );
    expect(review().id, 'b1_20260726');
  });

  test('a week nobody signed off says exactly that', () {
    const state = AttendanceWeekReviewState.none();
    expect(state.isReviewed, isFalse);
    expect(state.label, 'Not reviewed yet');
    expect(state.hasChangedSince, isFalse);
  });

  test('a reviewed week names the person', () {
    final state = AttendanceWeekReviewState.resolve(
      review: review(),
      rows: [row(closedAt: DateTime(2026, 7, 29, 18))],
    );
    expect(state.isReviewed, isTrue);
    expect(state.label, 'Reviewed by Manager One');
    expect(state.changedSinceReview, 0);
  });

  test('changes after the review are counted, not prevented', () {
    // The whole point: "later changes are intentional and visible". Nothing is
    // blocked — the change simply becomes visible.
    final state = AttendanceWeekReviewState.resolve(
      review: review(),
      rows: [
        row(closedAt: DateTime(2026, 7, 29, 18)), // before review
        row(restatedAt: reviewedAt.add(const Duration(hours: 2))), // after
        row(restatedAt: reviewedAt.add(const Duration(days: 1))), // after
      ],
    );

    expect(state.changedSinceReview, 2);
    expect(state.hasChangedSince, isTrue);
    expect(state.label, 'Reviewed by Manager One · 2 changes since');
  });

  test('one change reads in the singular', () {
    final state = AttendanceWeekReviewState.resolve(
      review: review(),
      rows: [row(restatedAt: reviewedAt.add(const Duration(minutes: 1)))],
    );
    expect(state.label, endsWith('· 1 change since'));
  });

  test('a change exactly at the review instant is not "after"', () {
    final state = AttendanceWeekReviewState.resolve(
      review: review(),
      rows: [row(restatedAt: reviewedAt)],
    );
    expect(state.changedSinceReview, 0);
  });

  test('restatement outranks close when both are stamped', () {
    // A row closed before review but restated after it *is* a later change.
    final state = AttendanceWeekReviewState.resolve(
      review: review(),
      rows: [
        row(
          closedAt: DateTime(2026, 7, 29, 18),
          restatedAt: reviewedAt.add(const Duration(hours: 1)),
        ),
      ],
    );
    expect(state.changedSinceReview, 1);
  });

  test('an unreadable name still attributes rather than going anonymous', () {
    final state = AttendanceWeekReviewState.resolve(
      review: review(name: '   '),
      rows: const [],
    );
    expect(state.label, 'Reviewed by mgr1');
  });

  test('review never claims anything about completeness', () {
    // It is an assertion that a person looked — orthogonal to the derived
    // coverage status. If these ever merge, ADR-019 has been lost.
    final state = AttendanceWeekReviewState.resolve(
      review: review(),
      rows: const [], // an entirely empty week
    );
    expect(state.isReviewed, isTrue);
    expect(state.label, isNot(contains('closed')));
    expect(state.label, isNot(contains('complete')));
    expect(state.label, isNot(contains('settled')));
  });
}
