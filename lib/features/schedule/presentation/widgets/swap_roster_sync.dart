import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:opshub/core/enums/swap_status.dart';
import 'package:opshub/features/schedule/domain/entities/shift_swap_entity.dart';
import 'package:opshub/features/schedule/domain/schedule_week.dart';
import 'package:opshub/features/schedule/presentation/cubit/schedule_cubit.dart';
import 'package:opshub/features/schedule/presentation/cubit/shift_swap_cubit.dart';
import 'package:opshub/features/schedule/presentation/cubit/shift_swap_state.dart';

/// Keeps the weekly roster on screen in step with **approved swaps**.
///
/// An approved swap rewrites `weekly_schedules` server-side (the `approveSwap`
/// Cloud Function owns the exchange), but [ScheduleCubit] is a one-shot read —
/// nothing tells it the roster moved. Refreshing on the local mutation settling
/// only fixed the device that pressed Approve; the **other** party kept showing
/// the pre-swap week for as long as their screen stayed mounted. A swap then
/// requested off that stale week names a shift its requester no longer holds,
/// and `approveSwap`'s slot-integrity check correctly refuses it — permanently.
/// That is the "sometimes it approves, sometimes it doesn't" failure: the
/// request was invalid the moment it was created.
///
/// The swap stream *is* realtime on every device, so the approval itself is the
/// signal: when a swap on the loaded (branch, week) reaches
/// [SwapStatus.managerApproved], refetch the schedule.
class SwapRosterSync extends StatefulWidget {
  const SwapRosterSync({super.key, required this.child});

  final Widget child;

  @override
  State<SwapRosterSync> createState() => _SwapRosterSyncState();
}

class _SwapRosterSyncState extends State<SwapRosterSync> {
  /// Ids already known to be approved. Null until the first loaded list — that
  /// opening snapshot is *adopted*, never treated as news, so mounting the
  /// screen does not fire a refetch for every swap approved in the past.
  ///
  /// Seeded from the cubit's CURRENT state at mount: a `BlocListener` is only
  /// called on later changes, so without this the first real approval would be
  /// mistaken for the opening snapshot and swallowed.
  Set<String>? _approved;

  @override
  void initState() {
    super.initState();
    _approved = _approvedIds(context.read<ShiftSwapCubit>().state);
  }

  Set<String>? _approvedIds(ShiftSwapState state) {
    final swaps = _swapsOf(state);
    if (swaps == null) return null;
    return {
      for (final s in swaps)
        if (s.status == SwapStatus.managerApproved) s.id,
    };
  }

  List<ShiftSwapEntity>? _swapsOf(ShiftSwapState state) =>
      state.maybeWhen<List<ShiftSwapEntity>?>(
        loaded: (swaps, _) => swaps,
        orElse: () => null,
      );

  void _onSwaps(BuildContext context, ShiftSwapState state) {
    final swaps = _swapsOf(state);
    if (swaps == null) return;

    final seen = _approved;
    _approved = _approvedIds(state);
    if (seen == null) return;

    final schedule = context.read<ScheduleCubit>();
    final branchId = schedule.branchId;
    if (branchId.isEmpty) return;
    final affectsView = swaps.any(
      (s) =>
          s.status == SwapStatus.managerApproved &&
          !seen.contains(s.id) &&
          s.branchId == branchId &&
          ScheduleWeek.isSameWeek(s.weekStart, schedule.weekStart),
    );
    if (affectsView) schedule.refresh();
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<ShiftSwapCubit, ShiftSwapState>(
      listener: _onSwaps,
      child: widget.child,
    );
  }
}
