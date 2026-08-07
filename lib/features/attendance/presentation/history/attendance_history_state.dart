import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:drop/features/attendance/domain/attendance_analytics.dart';
import 'package:drop/features/attendance/domain/attendance_directory_match.dart';
import 'package:drop/features/attendance/domain/attendance_history_query.dart';
import 'package:drop/features/attendance/domain/entities/attendance_entity.dart';

part 'attendance_history_state.freezed.dart';

/// State for the Attendance History ledger (employee self-history or the
/// manager/admin branch review). One realtime stream feeds [_records] in the
/// cubit; the emitted [records] here are already **filtered** by [query] and
/// [stats] is computed over exactly those survivors, so the summary strip and the
/// list can never disagree.
@freezed
class AttendanceHistoryState with _$AttendanceHistoryState {
  const factory AttendanceHistoryState.initial() = _Initial;

  /// First load (skeleton).
  const factory AttendanceHistoryState.loading() = _Loading;

  const factory AttendanceHistoryState.loaded({
    /// The filtered records, newest day first.
    required List<AttendanceEntity> records,

    /// Summary metrics over [records] (present/late/absent/rate/arrival/worked…).
    required AttendanceStats stats,

    /// The active filter facets driving [records].
    required AttendanceHistoryQuery query,

    /// The branch being reviewed (review mode only; null for self-history).
    String? branchId,

    /// The snapshot came purely from Firestore's offline cache (device offline).
    @Default(false) bool offline,

    /// A local write hasn't been acknowledged by the backend yet ("syncing…").
    @Default(false) bool syncing,

    /// The active branch's employee directory (review mode only), so a name
    /// search resolves against everyone — not just the days that produced a
    /// record. Empty in self mode and until the directory loads.
    @Default(<AttendanceDirectoryEntry>[])
    List<AttendanceDirectoryEntry> directory,
  }) = _Loaded;

  /// Terminal load failure (e.g. a rules-denied branch read) — shown full-screen.
  const factory AttendanceHistoryState.error(String message) = _Error;
}
