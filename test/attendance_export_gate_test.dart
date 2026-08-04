import 'package:flutter_test/flutter_test.dart';
import 'package:drop/core/enums/user_role.dart';
import 'package:drop/features/attendance/domain/reporting/attendance_export_gate.dart';

void main() {
  AttendanceExportAvailability gate({
    AttendanceExportKind kind = AttendanceExportKind.summaryPdf,
    UserRole role = UserRole.manager,
    bool hasRows = true,
    int blockingRows = 0,
  }) => attendanceExportAvailability(
    kind: kind,
    role: role,
    hasRows: hasRows,
    blockingRows: blockingRows,
  );

  test('a settled week exports for a manager and an admin', () {
    // Both artifacts are generated on the client (ADR-019), so there is nothing
    // to deploy and nothing to wait for.
    for (final kind in AttendanceExportKind.values) {
      expect(gate(kind: kind, role: UserRole.manager).isAllowed, isTrue);
      expect(gate(kind: kind, role: UserRole.admin).isAllowed, isTrue);
    }
  });

  test('an unsettled week is not shareable as though it were final', () {
    // A document leaves the app and outlives the screen that qualified it.
    expect(
      gate(blockingRows: 2).block,
      AttendanceExportBlock.notSettled,
    );
  });

  test('an empty period exports nothing at all', () {
    expect(gate(hasRows: false).block, AttendanceExportBlock.noRows);
  });

  test('an employee gets nothing', () {
    for (final kind in AttendanceExportKind.values) {
      expect(
        gate(kind: kind, role: UserRole.employee).block,
        AttendanceExportBlock.forbidden,
      );
    }
  });

  test('role outranks every other reason', () {
    // Someone who may never export must be told that, not sent to settle
    // shifts they cannot export afterwards either.
    expect(
      gate(role: UserRole.employee, hasRows: false, blockingRows: 3).block,
      AttendanceExportBlock.forbidden,
    );
  });

  test('payroll is gone — the enum carries only operational artifacts', () {
    // ADR-019: DROP is an operations system, nothing ingests a payroll file.
    expect(AttendanceExportKind.values, hasLength(2));
    expect(
      AttendanceExportKind.values.map((k) => k.label),
      ['PDF summary', 'Timesheet'],
    );
    for (final kind in AttendanceExportKind.values) {
      expect(kind.label.toLowerCase(), isNot(contains('payroll')));
    }
  });

  test('every block explains itself without jargon', () {
    const banned = [
      'ledger',
      'cloud function',
      'firestore',
      'null',
      'index',
      'locked',
      'deploy',
    ];
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
