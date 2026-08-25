import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:opshub/core/enums/schedule_day.dart';
import 'package:opshub/core/enums/schedule_shift.dart';
import 'package:opshub/core/enums/swap_status.dart';

part 'shift_swap_entity.freezed.dart';

/// A shift-swap request (Phase 7, exchange model). The [requesterId] employee
/// asks the [targetId] coworker on the **opposite shift that same day** to
/// **trade** shifts — the requester holds (week, [day], [shift]); the target
/// holds the opposite shift (there are only two). The coworker approves first,
/// then the branch manager; on manager approval the `approveSwap` Cloud Function
/// **exchanges both slots atomically** (Ziad's Night ⇄ Ahmed's Morning) — the
/// requester moves to the opposite shift and the target takes the requester's.
/// No new field is needed: the target's slot is always [shift]`.opposite`.
///
/// Names are denormalized ([requesterName] / [targetName]) so the request can be
/// displayed without extra user lookups. Access is enforced server-side in
/// `firestore.rules` (`shift_swaps/{id}`): the two employees and the branch
/// manager/admin can see and act on it; the final `managerApproved` transition is
/// owned by the Cloud Function.
@freezed
class ShiftSwapEntity with _$ShiftSwapEntity {
  const factory ShiftSwapEntity({
    required String id,
    required String branchId,

    /// The week the slot belongs to (Sunday 00:00) — used to address the
    /// schedule document the swap mutates on approval.
    required DateTime weekStart,
    required ScheduleDay day,
    required ScheduleShift shift,

    /// The employee giving up the slot.
    required String requesterId,
    String? requesterName,

    /// The coworker asked to take the slot.
    required String targetId,
    String? targetName,
    @Default(SwapStatus.pending) SwapStatus status,

    /// Optional free-text note from the requester.
    String? note,
    DateTime? createdAt,
    DateTime? updatedAt,

    /// The manager/admin who atomically approved the exchange. Written only by
    /// the server-authoritative `approveSwap` Cloud Function.
    String? managerApprovedById,
    String? managerApprovedByName,
    DateTime? managerApprovedAt,
  }) = _ShiftSwapEntity;
}
