import 'package:drop/core/enums/user_role.dart';

/// What a person may export from a period, and — when they may not — why.
///
/// **The mirror of `functions/attendance_export.js`.** The server is the
/// authority: it rejects a request that should not have been made, because a
/// client check is a courtesy and never a control. This exists so the UI can be
/// *honest* rather than offering a button that will fail, or — worse — a button
/// that looks the same whether or not it would work.
///
/// The two rules worth stating in one place:
///
/// * **Payroll requires a locked period, and only an admin may ask.** A pay
///   figure that can still move is not a pay figure. Keeping this off the
///   manager surface is not distrust — it is that an export sitting one tap from
///   a PDF button is eventually pressed by someone who meant to print a summary.
/// * **Manager artifacts do not require a lock.** A summary and a timesheet
///   carry no financial authority, and managers need to share a week before
///   payroll finalises it. Gating them would only push people back to
///   screenshots, which is the outcome an export exists to prevent.
enum AttendanceExportKind {
  summaryPdf,
  timesheetCsv,
  payrollCsv;

  String get label => switch (this) {
    AttendanceExportKind.summaryPdf => 'PDF summary',
    AttendanceExportKind.timesheetCsv => 'Timesheet',
    AttendanceExportKind.payrollCsv => 'Payroll export',
  };
}

/// Why an export is unavailable. Never rendered as an error — none of these is
/// a failure, they are all "not yet".
enum AttendanceExportBlock {
  /// Nothing has been recorded, so there is nothing to put in a file.
  noRows,

  /// Shifts still need a decision; a summary of an unsettled week would be
  /// shared as though it were final.
  notSettled,

  /// The period has not been locked, so the numbers can still move.
  notLocked,

  /// This role never gets this artifact.
  forbidden,

  /// The server side that generates files is not deployed yet.
  notDeployed;

  String get message => switch (this) {
    AttendanceExportBlock.noRows => 'Nothing has been recorded for this period '
        'yet.',
    AttendanceExportBlock.notSettled =>
      'Some shifts still need a decision. Settle them first so the file is '
          'final.',
    AttendanceExportBlock.notLocked =>
      'The period has to be locked before payroll can be exported — until then '
          'the numbers can still change.',
    AttendanceExportBlock.forbidden =>
      'Payroll exports are handled by an administrator.',
    AttendanceExportBlock.notDeployed =>
      'Exports are generated on the server, which an administrator still needs '
          'to switch on.',
  };
}

class AttendanceExportAvailability {
  const AttendanceExportAvailability.allowed()
    : isAllowed = true,
      block = null;
  const AttendanceExportAvailability.blocked(AttendanceExportBlock this.block)
    : isAllowed = false;

  final bool isAllowed;
  final AttendanceExportBlock? block;

  String? get message => block?.message;
}

/// Resolve availability for one [kind].
///
/// [serverReady] is the honest admission that file generation is a Cloud
/// Function which has never been deployed. It is checked **last**, so a reader
/// sees the substantive reason first — "settle these shifts" is more useful
/// than "not deployed" to someone who has shifts to settle either way.
AttendanceExportAvailability attendanceExportAvailability({
  required AttendanceExportKind kind,
  required UserRole role,
  required bool hasRows,
  required bool isLocked,
  int blockingRows = 0,
  bool serverReady = false,
}) {
  final isAdmin = role.isAdmin;
  final isManagerOrAdmin = isAdmin || role.isManager;

  if (kind == AttendanceExportKind.payrollCsv) {
    if (!isAdmin) {
      return const AttendanceExportAvailability.blocked(
        AttendanceExportBlock.forbidden,
      );
    }
  } else if (!isManagerOrAdmin) {
    return const AttendanceExportAvailability.blocked(
      AttendanceExportBlock.forbidden,
    );
  }

  if (!hasRows) {
    return const AttendanceExportAvailability.blocked(
      AttendanceExportBlock.noRows,
    );
  }

  if (kind == AttendanceExportKind.payrollCsv) {
    if (!isLocked) {
      return const AttendanceExportAvailability.blocked(
        AttendanceExportBlock.notLocked,
      );
    }
  } else if (blockingRows > 0) {
    return const AttendanceExportAvailability.blocked(
      AttendanceExportBlock.notSettled,
    );
  }

  if (!serverReady) {
    return const AttendanceExportAvailability.blocked(
      AttendanceExportBlock.notDeployed,
    );
  }
  return const AttendanceExportAvailability.allowed();
}
