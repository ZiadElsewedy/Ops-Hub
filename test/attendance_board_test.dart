import 'package:flutter_test/flutter_test.dart';
import 'package:opshub/core/enums/attendance_status.dart';
import 'package:opshub/core/enums/leave_type.dart';
import 'package:opshub/core/enums/schedule_shift.dart';
import 'package:opshub/features/attendance/domain/attendance_board.dart';
import 'package:opshub/features/attendance/domain/entities/attendance_entity.dart';

void main() {
  // "Now" = Monday 2026-07-13, 10:00.
  final now = DateTime(2026, 7, 13, 10);
  final morningStart = DateTime(2026, 7, 13, 8, 30);
  final morningEnd = DateTime(2026, 7, 13, 16, 30);

  AttendanceRosterEntry roster(
    String uid, {
    DateTime? start,
    DateTime? end,
    LeaveType? leave,
  }) =>
      AttendanceRosterEntry(
        uid: uid,
        name: uid,
        shift: ScheduleShift.morning,
        scheduledStart: start ?? morningStart,
        scheduledEnd: end ?? morningEnd,
        leave: leave,
      );

  AttendanceEntity rec(
    String uid, {
    DateTime? clockIn,
    DateTime? clockOut,
    AttendanceStatus status = AttendanceStatus.inProgress,
    int lateMinutes = 0,
  }) =>
      AttendanceEntity(
        id: '${uid}_20260713_morning',
        userId: uid,
        shift: ScheduleShift.morning,
        date: DateTime(2026, 7, 13),
        scheduledStart: morningStart,
        scheduledEnd: morningEnd,
        clockIn: clockIn,
        clockOut: clockOut,
        status: status,
        lateMinutes: lateMinutes,
      );

  test('derives the Not started / Late / Absent no-show buckets by time', () {
    final board = computeAttendanceBoard(
      roster: [
        roster('bob', start: DateTime(2026, 7, 13, 12)), // future → not started
        roster('abby'), // 08:30 start, no record, shift running → late
        roster('cara', start: DateTime(2026, 7, 13, 6),
            end: DateTime(2026, 7, 13, 9)), // shift over → absent
      ],
      records: const [],
      now: now,
    );

    Map<String, AttendanceBoardStatus> byUid = {
      for (final r in board.rows) r.uid: r.status
    };
    expect(byUid['bob'], AttendanceBoardStatus.notStarted);
    expect(byUid['abby'], AttendanceBoardStatus.late);
    expect(byUid['cara'], AttendanceBoardStatus.absent);
    // Lazy absent (spec R13): the absent row is derived with NO document.
    final caraRow = board.rows.firstWhere((r) => r.uid == 'cara');
    expect(caraRow.record, isNull);
  });

  test('an excused record surfaces as Excused, not Completed (R14)', () {
    final board = computeAttendanceBoard(
      roster: [roster('dana')],
      records: [
        rec('dana', status: AttendanceStatus.excused), // no clock, zero minutes
      ],
      now: now,
    );
    final row = board.rows.single;
    expect(row.status, AttendanceBoardStatus.excused);
    expect(board.excused, 1);
    expect(board.completed, 0);
  });

  test('joins records → working / completed / pending review (+ late flag)', () {
    final board = computeAttendanceBoard(
      roster: [roster('dan'), roster('eve'), roster('finn'), roster('hank')],
      records: [
        rec('dan', clockIn: morningStart), // open, on time
        rec('eve',
            clockIn: morningStart,
            clockOut: morningEnd,
            status: AttendanceStatus.completed),
        rec('finn', clockIn: DateTime(2026, 7, 13, 9), lateMinutes: 25), // late
        rec('hank',
            clockIn: morningStart, status: AttendanceStatus.pendingReview),
      ],
      now: now,
    );
    final byUid = {for (final r in board.rows) r.uid: r};

    expect(byUid['dan']!.status, AttendanceBoardStatus.working);
    expect(byUid['dan']!.isLate, isFalse);
    expect(byUid['eve']!.status, AttendanceBoardStatus.completed);
    expect(byUid['finn']!.status, AttendanceBoardStatus.working);
    expect(byUid['finn']!.isLate, isTrue); // arrived late
    expect(byUid['hank']!.status, AttendanceBoardStatus.pendingReview);
  });

  test('on-leave with no record shows On leave', () {
    final board = computeAttendanceBoard(
      roster: [roster('gwen', leave: LeaveType.annual)],
      records: const [],
      now: now,
    );
    expect(board.rows.single.status, AttendanceBoardStatus.onLeave);
  });

  test('KPI counts + problems sort to the top', () {
    final board = computeAttendanceBoard(
      roster: [
        roster('abby'), // late no-show
        roster('bob', start: DateTime(2026, 7, 13, 12)), // not started
        roster('cara', start: DateTime(2026, 7, 13, 6),
            end: DateTime(2026, 7, 13, 9)), // absent
        roster('dan'),
        roster('finn'),
        roster('gwen', leave: LeaveType.sick),
        roster('hank'),
      ],
      records: [
        rec('dan', clockIn: morningStart),
        rec('finn', clockIn: DateTime(2026, 7, 13, 9), lateMinutes: 25),
        rec('hank',
            clockIn: morningStart, status: AttendanceStatus.pendingReview),
      ],
      now: now,
    );

    expect(board.rostered, 7);
    expect(board.working, 2); // dan, finn
    expect(board.absent, 1); // cara
    expect(board.notStarted, 1); // bob
    expect(board.onLeave, 1); // gwen
    expect(board.pendingReview, 1); // hank
    expect(board.late, 2); // abby (no-show) + finn (late arrival)
    expect(board.present, 3); // dan, finn, hank clocked in

    // Problems first: pending review is the top row.
    expect(board.rows.first.status, AttendanceBoardStatus.pendingReview);
  });

  group('unscheduled work (ADR-018)', () {
    test('a record with no roster slot still reaches the board', () {
      // The board walks the roster. Without the unmatched-record pass the punch
      // exists in Firestore and is invisible on every manager surface.
      final board = computeAttendanceBoard(
        roster: [roster('rostered')],
        records: [rec('rostered'), rec('walkin')],
        now: now,
      );

      expect(board.rows, hasLength(2));
      final walkin = board.rows.firstWhere((r) => r.uid == 'walkin');
      expect(walkin.status, AttendanceBoardStatus.unscheduled);
      expect(walkin.entry.scheduledStart, isNull);
      expect(walkin.entry.scheduledEnd, isNull);
      expect(walkin.isLate, isFalse, reason: 'nothing to be late for');
    });

    test('it outranks an absence — unrecorded hours beat a coverage gap', () {
      final board = computeAttendanceBoard(
        roster: [roster('zz_absent')],
        records: [rec('aa_walkin')],
        now: DateTime(2026, 7, 13, 18), // past shift end → absent
      );

      expect(board.rows.first.uid, 'aa_walkin');
      expect(board.rows.first.status, AttendanceBoardStatus.unscheduled);
      expect(board.rows.last.status, AttendanceBoardStatus.absent);
    });

    test('a rostered record is never duplicated as unscheduled', () {
      final board = computeAttendanceBoard(
        roster: [roster('u1')],
        records: [rec('u1')],
        now: now,
      );

      expect(board.rows, hasLength(1));
      expect(board.rows.single.status, AttendanceBoardStatus.completed);
    });
  });
}
