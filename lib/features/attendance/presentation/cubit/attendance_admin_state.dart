import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:opshub/features/attendance/domain/attendance_board.dart';
import 'package:opshub/features/attendance/domain/entities/attendance_correction.dart';
import 'package:opshub/features/branch/domain/entities/branch_entity.dart';

part 'attendance_admin_state.freezed.dart';

/// State for the **admin attendance dashboard** — a branch-scoped snapshot fusing
/// today's roster with today's attendance ([board]) plus the branch's pending
/// [corrections]. Branch-scoped by design: a future Manager view reuses this same
/// state pinned to the manager's own branch (no [branches] picker).
@freezed
class AttendanceAdminState with _$AttendanceAdminState {
  const factory AttendanceAdminState.initial() = _Initial;
  const factory AttendanceAdminState.loading() = _Loading;

  const factory AttendanceAdminState.loaded({
    /// The branch currently in view.
    required String branchId,

    /// Branches the viewer may switch between (admin: all; a manager view would
    /// pass just their own). Drives the picker; a single entry hides it.
    @Default(<BranchEntity>[]) List<BranchEntity> branches,

    /// The roster × attendance join for today.
    required AttendanceBoard board,

    /// This branch's still-pending correction requests (the review queue).
    @Default(<AttendanceCorrectionEntity>[]) List<AttendanceCorrectionEntity>
        corrections,

    /// The moment the board was derived (bumped by a minute tick so no-shows roll
    /// Not started → Late → Absent as time passes).
    required DateTime now,

    /// A correction decision is in flight.
    @Default(false) bool deciding,
  }) = _Loaded;

  const factory AttendanceAdminState.error(String message) = _Error;
}
