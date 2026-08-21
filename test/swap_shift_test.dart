import 'package:flutter_test/flutter_test.dart';
import 'package:opshub/core/enums/schedule_shift.dart';
import 'package:opshub/core/enums/swap_status.dart';

/// Pure-logic coverage for the shift-swap additions (exchange model + cancelled).
void main() {
  group('ScheduleShift.opposite (drives the swap exchange)', () {
    test('morning ⇄ night', () {
      expect(ScheduleShift.morning.opposite, ScheduleShift.night);
      expect(ScheduleShift.night.opposite, ScheduleShift.morning);
    });
    test('applying opposite twice returns the original', () {
      for (final s in ScheduleShift.values) {
        expect(s.opposite.opposite, s);
      }
    });
  });

  group('SwapStatus.cancelled', () {
    test('is a resolved (terminal) state', () {
      expect(SwapStatus.cancelled.isResolved, isTrue);
      expect(SwapStatus.cancelled.isCancelled, isTrue);
    });
    test('labels as Cancelled', () {
      expect(SwapStatus.cancelled.label, 'Cancelled');
    });
    test('open states are not resolved; terminal states are', () {
      expect(SwapStatus.pending.isResolved, isFalse);
      expect(SwapStatus.employeeApproved.isResolved, isFalse);
      expect(SwapStatus.managerApproved.isResolved, isTrue);
      expect(SwapStatus.rejected.isResolved, isTrue);
    });
    test('round-trips through fromString', () {
      expect(SwapStatus.fromString('cancelled'), SwapStatus.cancelled);
    });
  });
}
