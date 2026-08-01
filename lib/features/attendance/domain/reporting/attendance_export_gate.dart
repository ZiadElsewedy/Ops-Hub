import 'package:drop/core/enums/user_role.dart';

/// What a person may export from a period, and — when they may not — why.
///
/// This exists so the UI is *honest* rather than offering a button that does
/// nothing useful — a report of a week that is not settled would be shared as
/// though it were final.
///
/// **Payroll export, period lock and server generation were all removed by
/// [ADR-019]** when payroll integration was ruled out. What remains is the one
/// rule that still earns its place: a summary of an *unsettled* week must not be
/// shared as though it were final, because a document leaves the app and outlives
/// the screen that qualified it.
///
/// Both artifacts are generated on the client, so there is nothing to deploy and
/// nothing to wait for.
enum AttendanceExportKind {
  summaryPdf,
  timesheetCsv;

  String get label => switch (this) {
    AttendanceExportKind.summaryPdf => 'PDF summary',
    AttendanceExportKind.timesheetCsv => 'Timesheet',
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

  /// This role never gets this artifact.
  forbidden;

  String get message => switch (this) {
    AttendanceExportBlock.noRows => 'Nothing has been recorded for this period '
        'yet.',
    AttendanceExportBlock.notSettled =>
      'Some shifts still need a decision. Settle them first so the file is '
          'final.',
    AttendanceExportBlock.forbidden =>
      'Attendance exports are for managers and administrators.',
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
AttendanceExportAvailability attendanceExportAvailability({
  required AttendanceExportKind kind,
  required UserRole role,
  required bool hasRows,
  int blockingRows = 0,
}) {
  if (!(role.isAdmin || role.isManager)) {
    return const AttendanceExportAvailability.blocked(
      AttendanceExportBlock.forbidden,
    );
  }
  if (!hasRows) {
    return const AttendanceExportAvailability.blocked(
      AttendanceExportBlock.noRows,
    );
  }
  if (blockingRows > 0) {
    return const AttendanceExportAvailability.blocked(
      AttendanceExportBlock.notSettled,
    );
  }
  return const AttendanceExportAvailability.allowed();
}
