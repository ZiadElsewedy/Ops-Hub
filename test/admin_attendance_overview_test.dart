import 'package:flutter_test/flutter_test.dart';
import 'package:opshub/core/enums/schedule_shift.dart';
import 'package:opshub/features/attendance/domain/reporting/admin_attendance_overview.dart';
import 'package:opshub/features/attendance/domain/reporting/attendance_coverage_status.dart';
import 'package:opshub/features/attendance/domain/reporting/attendance_exception.dart';
import 'package:opshub/features/attendance/domain/reporting/attendance_ledger_row.dart';
import 'package:opshub/features/attendance/domain/reporting/attendance_period.dart';

void main() {
  // Sunday 26 Jul – Saturday 1 Aug 2026.
  final window = weeklyWindow(DateTime(2026, 7, 29));

  AttendanceLedgerRow row({
    required String branchId,
    required String userId,
    String dayKey = '20260729',
    AttendanceLedgerOutcome outcome = AttendanceLedgerOutcome.worked,
    int workedMinutes = 480,
    List<AttendanceExceptionCode> exceptionCodes = const [],
  }) => AttendanceLedgerRow(
    id: '${userId}_${dayKey}_morning',
    rowId: '${userId}_${dayKey}_morning',
    userId: userId,
    userName: userId,
    branchId: branchId,
    dayKey: dayKey,
    businessDate: '2026-07-29',
    shift: ScheduleShift.morning,
    outcome: outcome,
    expected: true,
    recordId: outcome == AttendanceLedgerOutcome.absent
        ? null
        : '${userId}_${dayKey}_morning',
    workedMinutes: workedMinutes,
    exceptionCodes: exceptionCodes,
    locked: false,
    version: 1,
    source: 'system',
  );

  group('AdminAttendanceOverview', () {
    test('a branch that reported nothing still appears', () {
      // The single most important thing this surface shows. A branch with no
      // rows must not simply be absent from the list.
      final overview = AdminAttendanceOverview.fromBranchRows(
        window: window,
        rowsByBranch: {
          'busy': [row(branchId: 'busy', userId: 'u1')],
          'silent': const [],
        },
        namesByBranchId: {'busy': 'Arkan', 'silent': 'Maadi'},
      );

      expect(overview.branches.map((b) => b.branchName), contains('Maadi'));
      final silent = overview.branches.firstWhere(
        (b) => b.branchId == 'silent',
      );
      expect(silent.status, AttendanceCoverageStatus.noData);
      expect(silent.daysCovered, 0);
      expect(silent.daysTotal, 7);
    });

    test('worst first — blocked, then empty, then gappy, then settled', () {
      final overview = AdminAttendanceOverview.fromBranchRows(
        window: window,
        rowsByBranch: {
          'gappy': [row(branchId: 'gappy', userId: 'g1')],
          'empty': const [],
          'blocked': [
            row(
              branchId: 'blocked',
              userId: 'b1',
              exceptionCodes: const [AttendanceExceptionCode.missingPunch],
            ),
          ],
        },
      );

      expect(overview.branches.map((b) => b.branchId), [
        'blocked',
        'empty',
        'gappy',
      ]);
    });

    test('the cross-branch rate pools every branch — a real denominator', () {
      // Show-up rate left the store surface because at one shift `0%` is
      // meaningless. Pooled, it finally has volume behind it.
      final overview = AdminAttendanceOverview.fromBranchRows(
        window: window,
        rowsByBranch: {
          'a': [
            row(branchId: 'a', userId: 'a1'),
            row(
              branchId: 'a',
              userId: 'a2',
              outcome: AttendanceLedgerOutcome.absent,
              workedMinutes: 0,
            ),
          ],
          'b': [
            row(branchId: 'b', userId: 'b1'),
            row(branchId: 'b', userId: 'b2'),
          ],
        },
      );

      expect(overview.summary.expectedWorkShifts, 4);
      expect(overview.summary.present, 3);
      expect(overview.summary.showUpRate.percent, 75);
      expect(overview.rows, hasLength(4));
    });

    test('incompleteBranches is what the admin is accountable for', () {
      final overview = AdminAttendanceOverview.fromBranchRows(
        window: window,
        rowsByBranch: {
          'a': [row(branchId: 'a', userId: 'a1')],
          'b': const [],
        },
      );

      // Neither is settled: one has six empty days, the other has seven.
      expect(overview.incompleteBranches, hasLength(2));
    });

    group('escalation', () {
      test('a blocker only escalates once it has gone stale', () {
        final overview = AdminAttendanceOverview.fromBranchRows(
          window: window,
          rowsByBranch: {
            'a': [
              row(
                branchId: 'a',
                userId: 'a1',
                exceptionCodes: const [AttendanceExceptionCode.missingPunch],
              ),
            ],
          },
        );

        // The day itself: the manager has not had a chance yet.
        expect(overview.escalations(DateTime(2026, 7, 29)), isEmpty);
        // Next morning: still theirs to clear.
        expect(overview.escalations(DateTime(2026, 7, 30)), isEmpty);
        // Two days on, silence is a signal.
        expect(overview.escalations(DateTime(2026, 7, 31)), hasLength(1));
      });

      test('a branch with no blockers never escalates, however empty', () {
        final overview = AdminAttendanceOverview.fromBranchRows(
          window: window,
          rowsByBranch: {'a': const []},
        );

        // A gap is not a blocker: nobody may have been scheduled, and chasing a
        // manager for that is how an escalation queue becomes noise.
        expect(overview.escalations(DateTime(2026, 8, 30)), isEmpty);
        expect(overview.branches.single.oldestBlockerAgeDays(DateTime(2026, 8, 30)), isNull);
      });
    });
  });

  test('windowDayKeys covers the whole inclusive window', () {
    expect(windowDayKeys(window), [
      '20260726',
      '20260727',
      '20260728',
      '20260729',
      '20260730',
      '20260731',
      '20260801',
    ]);
  });
}
