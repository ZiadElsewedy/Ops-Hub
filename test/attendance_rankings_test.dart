import 'package:flutter_test/flutter_test.dart';
import 'package:drop/core/enums/schedule_shift.dart';
import 'package:drop/features/attendance/domain/reporting/attendance_exception.dart';
import 'package:drop/features/attendance/domain/reporting/attendance_ledger_row.dart';
import 'package:drop/features/attendance/domain/reporting/attendance_rankings.dart';

AttendanceLedgerRow _row({
  required String userId,
  String? userName,
  AttendanceLedgerOutcome outcome = AttendanceLedgerOutcome.worked,
  int worked = 0,
  int late = 0,
  int overtime = 0,
  List<AttendanceExceptionCode> exceptions = const [],
  String dayKey = '20260701',
}) => AttendanceLedgerRow(
  id: '${userId}_${dayKey}_morning',
  rowId: '${userId}_${dayKey}_morning',
  userId: userId,
  userName: userName,
  branchId: 'b1',
  dayKey: dayKey,
  businessDate: '2026-07-01',
  shift: ScheduleShift.morning,
  outcome: outcome,
  expected: true,
  workedMinutes: worked,
  lateMinutes: late,
  overtimeMinutes: overtime,
  exceptionCodes: exceptions,
);

void main() {
  group('attendanceRankings', () {
    test('ranks overtime high-to-low and sums per employee', () {
      final rows = [
        _row(userId: 'a', userName: 'Amal', overtime: 30, dayKey: '20260701'),
        _row(userId: 'a', userName: 'Amal', overtime: 45, dayKey: '20260702'),
        _row(userId: 'b', userName: 'Basma', overtime: 60, dayKey: '20260701'),
        _row(userId: 'c', userName: 'Carim', overtime: 0),
      ];
      final board = attendanceRankings(
        rows: rows,
        metric: AttendanceRankingMetric.overtime,
      );
      // Amal 75 > Basma 60; Carim (0) is off the board.
      expect(board.map((e) => e.userId).toList(), ['a', 'b']);
      expect(board.first.rank, 1);
      expect(board.first.value, 75);
      expect(board[1].rank, 2);
    });

    test('zero-value employees never appear (a leaderboard shows who has it)', () {
      final rows = [
        _row(userId: 'a', userName: 'Amal', late: 0),
        _row(userId: 'b', userName: 'Basma', late: 12),
      ];
      final board = attendanceRankings(
        rows: rows,
        metric: AttendanceRankingMetric.lateness,
      );
      expect(board.map((e) => e.userId).toList(), ['b']);
    });

    test('counts absences per matching shift', () {
      final rows = [
        _row(userId: 'a', userName: 'Amal', outcome: AttendanceLedgerOutcome.absent),
        _row(
          userId: 'a',
          userName: 'Amal',
          outcome: AttendanceLedgerOutcome.absent,
          dayKey: '20260702',
        ),
        _row(userId: 'b', userName: 'Basma', outcome: AttendanceLedgerOutcome.worked),
      ];
      final board = attendanceRankings(
        rows: rows,
        metric: AttendanceRankingMetric.absence,
      );
      expect(board.single.userId, 'a');
      expect(board.single.value, 2);
    });

    test('counts missing-punch exception shifts', () {
      final rows = [
        _row(
          userId: 'a',
          userName: 'Amal',
          exceptions: const [AttendanceExceptionCode.missingPunch],
        ),
        _row(
          userId: 'b',
          userName: 'Basma',
          exceptions: const [AttendanceExceptionCode.late],
        ),
      ];
      final board = attendanceRankings(
        rows: rows,
        metric: AttendanceRankingMetric.missingPunch,
      );
      expect(board.map((e) => e.userId).toList(), ['a']);
    });

    test('a tie breaks by name for a stable order', () {
      final rows = [
        _row(userId: 'z', userName: 'Zaid', overtime: 30),
        _row(userId: 'a', userName: 'Amal', overtime: 30),
      ];
      final board = attendanceRankings(
        rows: rows,
        metric: AttendanceRankingMetric.overtime,
      );
      expect(board.map((e) => e.displayName).toList(), ['Amal', 'Zaid']);
    });

    test('limit caps the board; 0 returns everyone with a value', () {
      final rows = [
        for (var i = 0; i < 8; i++)
          _row(userId: 'u$i', userName: 'U$i', worked: (i + 1) * 60),
      ];
      expect(
        attendanceRankings(
          rows: rows,
          metric: AttendanceRankingMetric.workedHours,
          limit: 3,
        ).length,
        3,
      );
      expect(
        attendanceRankings(
          rows: rows,
          metric: AttendanceRankingMetric.workedHours,
          limit: 0,
        ).length,
        8,
      );
    });

    test('falls back to the uid when a row carries no name', () {
      final rows = [_row(userId: 'ghost', userName: null, overtime: 10)];
      final board = attendanceRankings(
        rows: rows,
        metric: AttendanceRankingMetric.overtime,
      );
      expect(board.single.displayName, 'ghost');
    });
  });
}
