import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:opshub/features/attendance/domain/entities/attendance_correction.dart';
import 'package:opshub/features/attendance/domain/entities/attendance_entity.dart';
import 'package:opshub/features/attendance/domain/entities/attendance_event.dart';

part 'attendance_details_state.freezed.dart';

/// State for a single attendance record's Details screen. The record, its
/// append-only audit trail ([events], server-derived — the timeline) and any
/// [corrections] filed against it are merged from three realtime streams. When
/// the caller passes the record it was tapped from, the cubit seeds straight into
/// [loaded] for an instant first paint, then refreshes from the streams.
@freezed
class AttendanceDetailsState with _$AttendanceDetailsState {
  /// No seed record yet — waiting on the first `watchRecord` emission.
  const factory AttendanceDetailsState.loading() = _Loading;

  const factory AttendanceDetailsState.loaded({
    required AttendanceEntity record,
    @Default(<AttendanceEvent>[]) List<AttendanceEvent> events,
    @Default(<AttendanceCorrectionEntity>[]) List<AttendanceCorrectionEntity> corrections,
  }) = _Loaded;

  /// The record is missing (deleted) or unreadable (rules-denied).
  const factory AttendanceDetailsState.error(String message) = _Error;
}
