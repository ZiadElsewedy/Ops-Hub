import 'package:opshub/features/attendance/domain/reporting/attendance_ledger_row.dart';

/// Read-only attendance reporting contract.
///
/// Reporting reads only `attendance_expectations`. It does not reconstruct
/// numbers from raw attendance records or rosters, and it exposes no write
/// methods because the ledger is materialized by Admin-SDK Cloud Functions.
abstract class AttendanceReportingRepository {
  Stream<List<AttendanceLedgerRow>> watchBranchLedgerRange({
    required String branchId,
    required String startDayKey,
    required String endDayKey,
  });

  Stream<List<AttendanceLedgerRow>> watchUserLedgerRange({
    required String userId,
    required String startDayKey,
    required String endDayKey,
  });
}
