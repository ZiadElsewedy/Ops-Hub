import 'package:flutter_test/flutter_test.dart';
import 'package:opshub/core/enums/case_status.dart';

void main() {
  group('CaseStatus lifecycle (Open → In Discussion → Waiting Response → Closed)',
      () {
    test('has exactly four states with the expected labels', () {
      expect(CaseStatus.values.length, 4);
      expect(CaseStatus.open.label, 'Open');
      expect(CaseStatus.inDiscussion.label, 'In Discussion');
      expect(CaseStatus.waitingResponse.label, 'Waiting Response');
      expect(CaseStatus.closed.label, 'Closed');
    });

    test('open can advance to inDiscussion or close', () {
      expect(CaseStatus.open.canTransitionTo(CaseStatus.inDiscussion), isTrue);
      expect(CaseStatus.open.canTransitionTo(CaseStatus.closed), isTrue);
      expect(CaseStatus.open.canTransitionTo(CaseStatus.waitingResponse), isFalse);
    });

    test('inDiscussion ↔ waitingResponse, and either can close', () {
      expect(
          CaseStatus.inDiscussion.canTransitionTo(CaseStatus.waitingResponse),
          isTrue);
      expect(CaseStatus.inDiscussion.canTransitionTo(CaseStatus.closed), isTrue);
      expect(
          CaseStatus.waitingResponse.canTransitionTo(CaseStatus.inDiscussion),
          isTrue);
      expect(CaseStatus.waitingResponse.canTransitionTo(CaseStatus.closed),
          isTrue);
    });

    test('closed can only reopen (→ inDiscussion), never jump to open/waiting',
        () {
      expect(CaseStatus.closed.allowedNext, [CaseStatus.inDiscussion]);
      expect(CaseStatus.closed.canTransitionTo(CaseStatus.inDiscussion), isTrue);
      expect(CaseStatus.closed.canTransitionTo(CaseStatus.open), isFalse);
      expect(CaseStatus.closed.canTransitionTo(CaseStatus.waitingResponse),
          isFalse);
    });

    test('isActive is true for every state except closed', () {
      expect(CaseStatus.open.isActive, isTrue);
      expect(CaseStatus.inDiscussion.isActive, isTrue);
      expect(CaseStatus.waitingResponse.isActive, isTrue);
      expect(CaseStatus.closed.isActive, isFalse);
      expect(CaseStatus.closed.isClosed, isTrue);
    });

    test('fromString round-trips and defaults to open', () {
      for (final s in CaseStatus.values) {
        expect(CaseStatus.fromString(s.value), s);
      }
      expect(CaseStatus.fromString(null), CaseStatus.open);
      expect(CaseStatus.fromString('nonsense'), CaseStatus.open);
    });
  });
}
