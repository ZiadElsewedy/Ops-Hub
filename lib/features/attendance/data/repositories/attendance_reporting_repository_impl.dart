import 'package:opshub/core/errors/exceptions.dart';
import 'package:opshub/core/errors/failures.dart';
import 'package:opshub/features/attendance/data/datasources/attendance_reporting_datasource.dart';
import 'package:opshub/features/attendance/data/models/attendance_ledger_model.dart';
import 'package:opshub/features/attendance/domain/reporting/attendance_ledger_row.dart';
import 'package:opshub/features/attendance/domain/repositories/attendance_reporting_repository.dart';

class AttendanceReportingRepositoryImpl
    implements AttendanceReportingRepository {
  AttendanceReportingRepositoryImpl(this._remote);

  final AttendanceReportingDataSource _remote;

  List<AttendanceLedgerRow> _entities(List<AttendanceLedgerModel> models) {
    final rows = models.map((model) => model.toEntity()).toList()
      ..sort(_compareRows);
    return List.unmodifiable(rows);
  }

  @override
  Stream<List<AttendanceLedgerRow>> watchBranchLedgerRange({
    required String branchId,
    required String startDayKey,
    required String endDayKey,
  }) {
    try {
      return _remote
          .watchBranchLedgerRange(
            branchId: branchId,
            startDayKey: startDayKey,
            endDayKey: endDayKey,
          )
          .map(_entities);
    } on ServerException catch (e) {
      throw ServerFailure(e.message);
    }
  }

  @override
  Stream<List<AttendanceLedgerRow>> watchUserLedgerRange({
    required String userId,
    required String startDayKey,
    required String endDayKey,
  }) {
    try {
      return _remote
          .watchUserLedgerRange(
            userId: userId,
            startDayKey: startDayKey,
            endDayKey: endDayKey,
          )
          .map(_entities);
    } on ServerException catch (e) {
      throw ServerFailure(e.message);
    }
  }
}

int _compareRows(AttendanceLedgerRow a, AttendanceLedgerRow b) {
  final day = a.dayKey.compareTo(b.dayKey);
  if (day != 0) return day;
  final shift = a.shift.index.compareTo(b.shift.index);
  if (shift != 0) return shift;
  return a.userId.compareTo(b.userId);
}
