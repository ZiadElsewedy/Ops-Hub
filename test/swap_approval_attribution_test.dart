import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:opshub/core/enums/schedule_day.dart';
import 'package:opshub/core/enums/schedule_shift.dart';
import 'package:opshub/core/enums/swap_status.dart';
import 'package:opshub/features/schedule/domain/entities/shift_swap_entity.dart';
import 'package:opshub/features/schedule/presentation/cubit/shift_swap_cubit.dart';
import 'package:opshub/features/schedule/presentation/cubit/shift_swap_state.dart';
import 'package:opshub/features/schedule/presentation/widgets/swap_view.dart';

/// Pins the reviewer attribution an approved swap carries: a manager/admin who
/// approved an exchange is **named on the card**, and a record written before
/// that attribution existed shows no invented person.
///
/// The attribution itself is written only by the server-authoritative
/// `approveSwap` Cloud Function (`functions/index.js`) — the client never
/// forges it, so these tests feed the entity the way Firestore would.
class _FakeShiftSwapCubit extends Cubit<ShiftSwapState>
    implements ShiftSwapCubit {
  _FakeShiftSwapCubit(this._swaps) : super(ShiftSwapState.loaded(_swaps));

  final List<ShiftSwapEntity> _swaps;

  /// Replays what the real cubit does when a decision is refused: a transient
  /// error, then straight back to the list.
  void refuse(String message) {
    emit(ShiftSwapState.error(message));
    emit(ShiftSwapState.loaded(_swaps));
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

ShiftSwapEntity _approvedSwap({String? approverName, DateTime? approvedAt}) =>
    ShiftSwapEntity(
      id: 's1',
      branchId: 'b1',
      weekStart: DateTime(2026, 8, 2),
      day: ScheduleDay.thursday,
      shift: ScheduleShift.night,
      requesterId: 'u1',
      requesterName: 'Ziad Elsewedy',
      targetId: 'u2',
      targetName: 'Test Acc',
      status: SwapStatus.managerApproved,
      createdAt: DateTime.now().subtract(const Duration(hours: 1)),
      managerApprovedById: approverName == null ? null : 'm1',
      managerApprovedByName: approverName,
      managerApprovedAt: approvedAt,
    );

Future<_FakeShiftSwapCubit> _pump(
  WidgetTester tester,
  ShiftSwapEntity swap,
) async {
  final cubit = _FakeShiftSwapCubit([swap]);
  addTearDown(cubit.close);
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: BlocProvider<ShiftSwapCubit>.value(
          value: cubit,
          child: const SwapListView(isManager: true, currentUid: 'm1'),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return cubit;
}

void main() {
  testWidgets('an approved swap names the manager/admin who approved it', (
    tester,
  ) async {
    await _pump(
      tester,
      _approvedSwap(
        approverName: 'Ziad Elsewedy',
        approvedAt: DateTime.now().subtract(const Duration(minutes: 6)),
      ),
    );

    expect(find.text('Approved by Ziad Elsewedy'), findsOneWidget);
    // The decision time is stated beside the name, not only the request time.
    expect(find.text('6m ago'), findsOneWidget);
  });

  testWidgets('the swap progress rail is centred on its three stages', (
    tester,
  ) async {
    await _pump(tester, _approvedSwap());

    final requested = tester.getCenter(
      find.byKey(const ValueKey<String>('swap-timeline-node-Requested')),
    );
    final accepted = tester.getCenter(
      find.byKey(const ValueKey<String>('swap-timeline-node-Accepted')),
    );
    final approved = tester.getCenter(
      find.byKey(const ValueKey<String>('swap-timeline-node-Approved')),
    );
    final firstRail = tester.getRect(
      find.byKey(const ValueKey<String>('swap-timeline-track-0')),
    );
    final secondRail = tester.getRect(
      find.byKey(const ValueKey<String>('swap-timeline-track-1')),
    );

    // Equal-width stages make the middle step the actual visual midpoint.
    expect(accepted.dx, closeTo((requested.dx + approved.dx) / 2, 0.5));
    // Each rail runs from one node centre to the next, through the dot centre.
    expect(firstRail.left, closeTo(requested.dx, 0.5));
    expect(firstRail.right, closeTo(accepted.dx, 0.5));
    expect(secondRail.left, closeTo(accepted.dx, 0.5));
    expect(secondRail.right, closeTo(approved.dx, 0.5));
    expect(firstRail.center.dy, closeTo(requested.dy, 0.5));
    expect(secondRail.center.dy, closeTo(accepted.dy, 0.5));
  });

  testWidgets('an approved swap with no stored approver invents nobody', (
    tester,
  ) async {
    await _pump(tester, _approvedSwap());

    expect(find.textContaining('Approved by'), findsNothing);
    // …but it says so, rather than leaving a silent gap that reads as a bug.
    expect(find.text('Approver not recorded'), findsOneWidget);
  });

  testWidgets('a swap still awaiting a decision carries no approval line', (
    tester,
  ) async {
    await _pump(
      tester,
      _approvedSwap(
        approverName: 'Ziad Elsewedy',
      ).copyWith(status: SwapStatus.employeeApproved),
    );

    expect(find.textContaining('Approved by'), findsNothing);
    expect(find.text('Approver not recorded'), findsNothing);
  });

  // The queue is opened as a modal sheet, and a ScaffoldMessenger snackbar
  // renders in the page Scaffold UNDERNEATH it — a refused approval was
  // invisible, so the button read as doing nothing at all.
  testWidgets('a refused decision is stated inside the list', (tester) async {
    const message =
        'The schedule changed — the requester is no longer on that shift.';
    final cubit = await _pump(
      tester,
      _approvedSwap().copyWith(status: SwapStatus.employeeApproved),
    );

    cubit.refuse(message);
    await tester.pumpAndSettle();

    expect(find.text('Not applied'), findsOneWidget);
    expect(find.text(message), findsOneWidget);
  });
}
