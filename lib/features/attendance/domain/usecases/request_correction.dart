import 'package:opshub/features/attendance/domain/entities/attendance_correction.dart';
import 'package:opshub/features/attendance/domain/repositories/attendance_repository.dart';

/// Files an attendance correction — persists a freshly built `pending`
/// [AttendanceCorrectionEntity] for the employee's own record. The caller (the
/// cubit) has already run [AttendanceValidation.checkCorrection]; the
/// `correctionRequested` audit event + reviewer notifications are derived
/// server-side by `onAttendanceCorrectionWritten`.
class RequestCorrection {
  final AttendanceRepository _repository;
  const RequestCorrection(this._repository);

  Future<void> call(AttendanceCorrectionEntity correction) =>
      _repository.requestCorrection(correction);
}
