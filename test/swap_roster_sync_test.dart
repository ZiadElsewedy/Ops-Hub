import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:drop/core/enums/schedule_day.dart';
import 'package:drop/core/enums/schedule_shift.dart';
import 'package:drop/core/enums/swap_status.dart';
import 'package:drop/features/schedule/domain/entities/shift_swap_entity.dart';
import 'package:drop/features/schedule/presentation/cubit/schedule_cubit.dart';
import 'package:drop/features/schedule/presentation/cubit/schedule_state.dart';
import 'package:drop/features/schedule/presentation/cubit/shift_swap_cubit.dart';
import 'package:drop/features/schedule/presentation/cubit/shift_swap_state.dart';
import 'package:drop/features/schedule/presentation/widgets/swap_roster_sync.dart';

/// Pins the roster refresh that follows an approved swap.
///
/// `approveSwap` rewrites `weekly_schedules` on the server, but [ScheduleCubit]
/// is a one-shot read: without this, the party who did NOT press Approve keeps
/// showing the pre-swap week, and a swap requested off that stale roster names a
/// shift its requester no longer holds — which the function then refuses
/// forever ("sometimes it approves, sometimes it doesn't").
class _FakeScheduleCubit extends Cubit<ScheduleState> implements ScheduleCubit {
  _FakeScheduleCubit({required this.branchId, required this.weekStart})
    : super(const ScheduleState.initial());

  @override
  final String branchId;

  @override
  final DateTime weekStart;

  int refreshes = 0;

  @override
  Future<void> refresh() async => refreshes++;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeShiftSwapCubit extends Cubit<ShiftSwapState>
    implements ShiftSwapCubit {
  _FakeShiftSwapCubit(super.initialState);

  void push(ShiftSwapState state) => emit(state);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

ShiftSwapEntity _swap({
  String id = 's1',
  String branchId = 'b1',
  required SwapStatus status,
  DateTime? weekStart,
}) => ShiftSwapEntity(
  id: id,
  branchId: branchId,
  weekStart: weekStart ?? DateTime(2026, 8, 2),
  day: ScheduleDay.thursday,
  shift: ScheduleShift.night,
  requesterId: 'u1',
  targetId: 'u2',
  status: status,
);

Future<_FakeScheduleCubit> _pump(
  WidgetTester tester,
  _FakeShiftSwapCubit swaps, {
  String branchId = 'b1',
  DateTime? weekStart,
}) async {
  final schedule = _FakeScheduleCubit(
    branchId: branchId,
    weekStart: weekStart ?? DateTime(2026, 8, 2),
  );
  addTearDown(schedule.close);
  await tester.pumpWidget(
    MaterialApp(
      home: MultiBlocProvider(
        providers: [
          BlocProvider<ScheduleCubit>.value(value: schedule),
          BlocProvider<ShiftSwapCubit>.value(value: swaps),
        ],
        child: const SwapRosterSync(child: SizedBox.shrink()),
      ),
    ),
  );
  await tester.pump();
  return schedule;
}

void main() {
  testWidgets('a swap approved on the loaded week refetches the roster', (
    tester,
  ) async {
    final swaps = _FakeShiftSwapCubit(
      ShiftSwapState.loaded([_swap(status: SwapStatus.employeeApproved)]),
    );
    addTearDown(swaps.close);
    final schedule = await _pump(tester, swaps);

    swaps.push(
      ShiftSwapState.loaded([_swap(status: SwapStatus.managerApproved)]),
    );
    await tester.pump();

    expect(schedule.refreshes, 1);
  });

  testWidgets('an already-approved swap on mount refetches nothing', (
    tester,
  ) async {
    final swaps = _FakeShiftSwapCubit(
      ShiftSwapState.loaded([_swap(status: SwapStatus.managerApproved)]),
    );
    addTearDown(swaps.close);
    final schedule = await _pump(tester, swaps);

    // A second emit of the same settled list is not news either.
    swaps.push(
      ShiftSwapState.loaded([_swap(status: SwapStatus.managerApproved)]),
    );
    await tester.pump();

    expect(schedule.refreshes, 0);
  });

  testWidgets('a swap approved outside the loaded scope is ignored', (
    tester,
  ) async {
    final swaps = _FakeShiftSwapCubit(
      ShiftSwapState.loaded([
        _swap(
          id: 'other-branch',
          status: SwapStatus.employeeApproved,
          branchId: 'b2',
        ),
        _swap(
          id: 'other-week',
          status: SwapStatus.employeeApproved,
          weekStart: DateTime(2026, 8, 9),
        ),
      ]),
    );
    addTearDown(swaps.close);
    final schedule = await _pump(tester, swaps);

    swaps.push(
      ShiftSwapState.loaded([
        _swap(
          id: 'other-branch',
          status: SwapStatus.managerApproved,
          branchId: 'b2',
        ),
        _swap(
          id: 'other-week',
          status: SwapStatus.managerApproved,
          weekStart: DateTime(2026, 8, 9),
        ),
      ]),
    );
    await tester.pump();

    expect(schedule.refreshes, 0);
  });
}
