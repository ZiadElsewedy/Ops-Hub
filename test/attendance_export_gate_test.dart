import 'package:flutter_test/flutter_test.dart';
import 'package:drop/core/enums/user_role.dart';
import 'package:drop/features/attendance/domain/reporting/attendance_export_gate.dart';

void main() {
  AttendanceExportAvailability gate({
    required AttendanceExportKind kind,
    UserRole role = UserRole.admin,
    bool hasRows = true,
    bool isLocked = false,
    int blockingRows = 0,
    bool serverReady = true,
  }) => attendanceExportAvailability(
    kind: kind,
    role: role,
    hasRows: hasRows,
    isLocked: isLocked,
    blockingRows: blockingRows,
    serverReady: serverReady,
  );

  group('payroll export', () {
    test('requires a locked period', () {
      expect(
        gate(kind: AttendanceExportKind.payrollCsv).block,
        AttendanceExportBlock.notLocked,
      );
      expect(
        gate(kind: AttendanceExportKind.payrollCsv, isLocked: true).isAllowed,
        isTrue,
      );
    });

    test('is never offered to a manager, however locked', () {
      // Not distrust: an export one tap from a PDF button is eventually pressed
      // by someone who meant to print a summary.
      expect(
        gate(
          kind: AttendanceExportKind.payrollCsv,
          role: UserRole.manager,
          isLocked: true,
        ).block,
        AttendanceExportBlock.forbidden,
      );
    });

    test('forbidden outranks every other reason', () {
      // A manager must be told they are not the one who does this, not that the
      // period needs locking — otherwise they go and lock it.
      expect(
        gate(
          kind: AttendanceExportKind.payrollCsv,
          role: UserRole.manager,
          hasRows: false,
          isLocked: false,
        ).block,
        AttendanceExportBlock.forbidden,
      );
    });
  });

  group('manager artifacts', () {
    test('do not require a lock — only a settled period', () {
      for (final kind in [
        AttendanceExportKind.summaryPdf,
        AttendanceExportKind.timesheetCsv,
      ]) {
        expect(
          gate(kind: kind, role: UserRole.manager, isLocked: false).isAllowed,
          isTrue,
          reason: 'a week must be shareable before payroll finalises it',
        );
        expect(
          gate(
            kind: kind,
            role: UserRole.manager,
            blockingRows: 2,
          ).block,
          AttendanceExportBlock.notSettled,
        );
      }
    });

    test('an employee gets nothing', () {
      for (final kind in AttendanceExportKind.values) {
        expect(
          gate(kind: kind, role: UserRole.employee, isLocked: true).block,
          AttendanceExportBlock.forbidden,
        );
      }
    });
  });

  test('an empty period exports nothing at all', () {
    for (final kind in AttendanceExportKind.values) {
      expect(
        gate(kind: kind, hasRows: false, isLocked: true).block,
        AttendanceExportBlock.noRows,
      );
    }
  });

  test('the undeployed server is reported last, after the real reason', () {
    // "Settle these shifts" is more useful than "not deployed" to someone who
    // has shifts to settle either way.
    expect(
      gate(
        kind: AttendanceExportKind.summaryPdf,
        role: UserRole.manager,
        blockingRows: 1,
        serverReady: false,
      ).block,
      AttendanceExportBlock.notSettled,
    );
    expect(
      gate(
        kind: AttendanceExportKind.summaryPdf,
        role: UserRole.manager,
        serverReady: false,
      ).block,
      AttendanceExportBlock.notDeployed,
    );
  });

  test('every block explains itself without jargon', () {
    const banned = ['ledger', 'cloud function', 'firestore', 'null', 'index'];
    for (final block in AttendanceExportBlock.values) {
      expect(block.message, isNotEmpty);
      for (final word in banned) {
        expect(
          block.message.toLowerCase().contains(word),
          isFalse,
          reason: '"${block.message}" leaks internal vocabulary: $word',
        );
      }
    }
  });
}
