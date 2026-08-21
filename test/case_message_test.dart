import 'package:flutter_test/flutter_test.dart';
import 'package:opshub/features/cases/domain/entities/case_message.dart';

void main() {
  group('CaseMessageKind', () {
    test('parses known values, defaults to message', () {
      expect(CaseMessageKind.fromString('opening'), CaseMessageKind.opening);
      expect(CaseMessageKind.fromString('system'), CaseMessageKind.system);
      expect(CaseMessageKind.fromString('message'), CaseMessageKind.message);
      expect(CaseMessageKind.fromString(null), CaseMessageKind.message);
      expect(CaseMessageKind.fromString('???'), CaseMessageKind.message);
    });
  });

  group('CaseAuthorRole', () {
    test('parses known values, defaults to reporter', () {
      expect(CaseAuthorRole.fromString('reporter'), CaseAuthorRole.reporter);
      expect(CaseAuthorRole.fromString('recipient'), CaseAuthorRole.recipient);
      expect(CaseAuthorRole.fromString('system'), CaseAuthorRole.system);
      expect(CaseAuthorRole.fromString(null), CaseAuthorRole.reporter);
    });
  });

  group('CaseMessage helpers', () {
    CaseMessage msg({
      String? text,
      CaseMessageKind kind = CaseMessageKind.message,
    }) =>
        CaseMessage(id: 'm', text: text, kind: kind, createdAt: DateTime(2026));

    test('isSystem / isOpening reflect the kind', () {
      expect(msg(kind: CaseMessageKind.system).isSystem, isTrue);
      expect(msg(kind: CaseMessageKind.opening).isOpening, isTrue);
      expect(msg().isSystem, isFalse);
    });

    test('hasText ignores blank text', () {
      expect(msg(text: 'hi').hasText, isTrue);
      expect(msg(text: '   ').hasText, isFalse);
      expect(msg(text: null).hasText, isFalse);
    });
  });
}
