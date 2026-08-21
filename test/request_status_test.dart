import 'package:flutter_test/flutter_test.dart';
import 'package:opshub/core/enums/request_status.dart';

void main() {
  group('RequestStatus lifecycle', () {
    test('has exactly three states with the expected labels', () {
      expect(RequestStatus.values.length, 3);
      expect(RequestStatus.pending.label, 'Pending');
      expect(RequestStatus.approved.label, 'Approved');
      expect(RequestStatus.rejected.label, 'Rejected');
    });

    test('pending is active and can advance to approved or rejected', () {
      expect(RequestStatus.pending.isActive, isTrue);
      expect(RequestStatus.pending.isTerminal, isFalse);
      expect(RequestStatus.pending.approverNext,
          [RequestStatus.approved, RequestStatus.rejected]);
    });

    test('decided states are terminal with no next transitions', () {
      for (final s in [RequestStatus.approved, RequestStatus.rejected]) {
        expect(s.isActive, isFalse, reason: '$s should be inactive');
        expect(s.isTerminal, isTrue);
        expect(s.approverNext, isEmpty);
      }
    });

    test('both approve and reject are decisions', () {
      expect(RequestStatus.approved.isDecision, isTrue);
      expect(RequestStatus.rejected.isDecision, isTrue);
      expect(RequestStatus.pending.isDecision, isFalse);
    });

    test('only rejected is a negative outcome', () {
      expect(RequestStatus.rejected.isNegative, isTrue);
      expect(RequestStatus.approved.isNegative, isFalse);
      expect(RequestStatus.pending.isNegative, isFalse);
    });

    test('fromString is lenient and defaults to pending', () {
      expect(RequestStatus.fromString('approved'), RequestStatus.approved);
      expect(RequestStatus.fromString('rejected'), RequestStatus.rejected);
      // Legacy values that no longer exist fall back to pending.
      expect(RequestStatus.fromString('completed'), RequestStatus.pending);
      expect(RequestStatus.fromString('cancelled'), RequestStatus.pending);
      expect(RequestStatus.fromString('nonsense'), RequestStatus.pending);
      expect(RequestStatus.fromString(null), RequestStatus.pending);
    });
  });
}
