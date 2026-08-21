import 'package:opshub/features/attendance/domain/entities/attendance_entity.dart';
import 'package:opshub/features/attendance/domain/repositories/attendance_repository.dart';

/// Clocks in — persists a freshly built in-progress [AttendanceEntity] on its
/// deterministic id. The caller (the cubit) has already run
/// [AttendanceValidation.checkClockIn]; the `clockedIn` audit event is derived
/// server-side.
class ClockIn {
  final AttendanceRepository _repository;
  const ClockIn(this._repository);

  Future<void> call(AttendanceEntity record) => _repository.clockIn(record);
}
