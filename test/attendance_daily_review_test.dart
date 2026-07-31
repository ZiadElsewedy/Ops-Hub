import 'package:flutter_test/flutter_test.dart';
import 'package:drop/core/enums/attendance_status.dart';
import 'package:drop/core/enums/leave_type.dart';
import 'package:drop/core/enums/schedule_shift.dart';
import 'package:drop/features/attendance/domain/attendance_board.dart';
import 'package:drop/features/attendance/domain/attendance_id.dart';
import 'package:drop/features/attendance/domain/daily_review.dart';
import 'package:drop/features/attendance/domain/entities/attendance_entity.dart';

void main() {
  // The day under review is over: 2026-07-13, looked at the next morning.
  final nextMorning = DateTime(2026, 7, 14, 9);
  final morningStart = DateTime(2026, 7, 13, 8, 30);
  final morningEnd = DateTime(2026, 7, 13, 16, 30);

  AttendanceRosterEntry roster(String uid, {LeaveType? leave}) =>
      AttendanceRosterEntry(
        uid: uid,
        name: uid,
        shift: ScheduleShift.morning,
        scheduledStart: morningStart,
        scheduledEnd: morningEnd,
        leave: leave,
      );

  AttendanceEntity rec(
    String uid, {
    DateTime? clockIn,
    DateTime? clockOut,
    AttendanceStatus status = AttendanceStatus.completed,
    int lateMinutes = 0,
  }) => AttendanceEntity(
    id: '${uid}_20260713_morning',
    userId: uid,
    shift: ScheduleShift.morning,
    date: DateTime(2026, 7, 13),
    scheduledStart: morningStart,
    scheduledEnd: morningEnd,
    clockIn: clockIn ?? morningStart,
    clockOut: clockOut,
    status: status,
    lateMinutes: lateMinutes,
  );

  DailyReview reviewOf({
    required List<AttendanceRosterEntry> rosterEntries,
    List<AttendanceEntity> records = const [],
  }) => DailyReview.fromBoard(
    computeAttendanceBoard(
      roster: rosterEntries,
      records: records,
      now: nextMorning,
    ),
  );

  group('DailyReview', () {
    test('a clean day asks for nothing', () {
      final review = reviewOf(
        rosterEntries: [roster('dina'), roster('omar')],
        records: [
          rec('dina', clockOut: morningEnd),
          rec('omar', clockOut: morningEnd),
        ],
      );

      expect(review.items, isEmpty);
      expect(review.isClean, isTrue);
      expect(review.summaryLine, '2 of 2 shifts worked');
    });

    test('an unworked rostered shift asks whether they worked or were out', () {
      final review = reviewOf(rosterEntries: [roster('omar')]);

      expect(review.items, hasLength(1));
      final item = review.items.single;
      expect(item.kind, DailyReviewKind.noShow);
      expect(item.headline, 'omar was scheduled but never clocked in');
      // Names a person and states a fact — no record id, no exception code, no
      // severity label anywhere in what the manager reads.
      expect(item.headline, isNot(contains('_20260713_')));
      expect(item.detail.toLowerCase(), isNot(contains('blocking')));
      expect(item.detail.toLowerCase(), isNot(contains('exception')));
    });

    test('an unclosed shift is the top item, above a no-show', () {
      // Cost of being wrong decides the order: unknown hours are a payroll
      // problem, a no-show is a coverage fact someone already noticed. "Abby"
      // sorts first alphabetically and still comes second.
      final review = reviewOf(
        rosterEntries: [roster('abby'), roster('zara')],
        records: [rec('zara', status: AttendanceStatus.pendingReview)],
      );

      expect(review.items.map((i) => i.kind), [
        DailyReviewKind.missingClockOut,
        DailyReviewKind.noShow,
      ]);
      expect(review.items.first.headline, "zara didn't clock out");
    });

    test('ties inside one kind stay alphabetical', () {
      final review = reviewOf(
        rosterEntries: [roster('carla'), roster('basma')],
      );

      expect(review.items.map((i) => i.row.name), ['basma', 'carla']);
    });

    test('leave and excused are not expected to work, so not counted', () {
      final review = reviewOf(
        rosterEntries: [
          roster('dina'),
          roster('sam', leave: LeaveType.annual),
        ],
        records: [rec('dina', clockOut: morningEnd)],
      );

      // Sam is on leave: not a no-show, not part of the day's denominator.
      expect(review.items, isEmpty);
      expect(review.scheduled, 1);
      expect(review.summaryLine, '1 of 1 shift worked');
    });

    test('a day nobody was rostered for reads as no shifts, not as zero', () {
      final review = reviewOf(rosterEntries: const []);

      expect(review.items, isEmpty);
      expect(review.summaryLine, 'No shifts scheduled');
      // Never a percentage: one store-day is the smallest sample in the product.
      expect(review.summaryLine, isNot(contains('%')));
    });

    test('a still-open shift counts as worked, and needs no decision', () {
      // Auto-close will settle it; nothing for a human to decide yet.
      final review = reviewOf(
        rosterEntries: [roster('dina')],
        records: [rec('dina', status: AttendanceStatus.inProgress)],
      );

      expect(review.items, isEmpty);
      expect(review.worked, 1);
    });

    test('late arrivals are reported, never queued as a decision', () {
      final review = reviewOf(
        rosterEntries: [roster('dina')],
        records: [rec('dina', clockOut: morningEnd, lateMinutes: 12)],
      );

      // Lateness is a recorded fact, not something needing a manager's ruling.
      expect(review.items, isEmpty);
      expect(review.lateArrivals, 1);
    });
  });

  group('parseAttendanceDayKey', () {
    test('round-trips a real date', () {
      final date = DateTime(2026, 7, 13);
      expect(parseAttendanceDayKey(attendanceDayKey(date)), date);
    });

    test('rejects route input that is not a business date', () {
      expect(parseAttendanceDayKey('2026071'), isNull);
      expect(parseAttendanceDayKey('20260732'), isNull);
      expect(parseAttendanceDayKey('20260231'), isNull);
      expect(parseAttendanceDayKey('yyyymmdd'), isNull);
    });
  });

  group('unscheduled work (ADR-018)', () {
    test('surfaces as its own item, above a no-show', () {
      final board = computeAttendanceBoard(
        roster: [roster('Zara')], // rostered, never clocked in → no-show
        records: [rec('Adam')], // clocked in, no roster slot → unscheduled
        now: nextMorning,
      );

      final review = DailyReview.fromBoard(board);

      expect(review.items.map((i) => i.kind), [
        DailyReviewKind.unscheduledWork,
        DailyReviewKind.noShow,
      ]);
      expect(review.items.first.headline, contains('Adam'));
      expect(review.items.first.headline, contains('not scheduled'));
    });

    test('stays out of the day denominator until approved', () {
      // The roster did not ask for this shift, so it cannot make the day look
      // better staffed than it was planned to be — the same exclusion the
      // reporting aggregates make via `isUnscheduledWork`.
      final board = computeAttendanceBoard(
        roster: [roster('Rostered')],
        records: [rec('Rostered'), rec('Walkin')],
        now: nextMorning,
      );

      final review = DailyReview.fromBoard(board);

      expect(review.scheduled, 1);
      expect(review.summaryLine, '1 of 1 shift worked');
    });
  });
}
