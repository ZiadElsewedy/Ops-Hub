import 'package:flutter_test/flutter_test.dart';
import 'package:opshub/core/enums/attachment_type.dart';
import 'package:opshub/features/cases/domain/case_thread.dart';
import 'package:opshub/features/cases/domain/entities/case_entity.dart';
import 'package:opshub/features/cases/domain/entities/case_message.dart';
import 'package:opshub/features/task/domain/entities/task_attachment.dart';

void main() {
  final t0 = DateTime(2026, 7, 4, 9);
  final t1 = DateTime(2026, 7, 4, 10);

  CaseEntity caseWith({
    String? description,
    List<TaskAttachment> attachments = const [],
    DateTime? createdAt,
  }) =>
      CaseEntity(
        id: 'c1',
        subject: 'Broken POS',
        description: description,
        reporterDisplayName: 'Ziad',
        attachments: attachments,
        createdAt: createdAt,
      );

  CaseMessage reply(String id, {DateTime? at}) => CaseMessage(
        id: id,
        authorId: 'mgr',
        authorName: 'Manager',
        authorRole: CaseAuthorRole.recipient,
        kind: CaseMessageKind.message,
        text: 'reply $id',
        createdAt: at ?? t1,
      );

  group('caseThread', () {
    test('synthesizes an opening from the case when none is present', () {
      final out = caseThread(
        [reply('m1')],
        caseWith(description: 'The register froze', createdAt: t0),
      );
      expect(out.length, 2);
      expect(out.first.isOpening, isTrue);
      expect(out.first.id, kSyntheticOpeningId);
      expect(out.first.text, 'The register froze');
      expect(out.first.authorRole, CaseAuthorRole.reporter);
      expect(out.first.createdAt, t0); // leads the thread
      expect(out.last.id, 'm1');
    });

    test('synthesizes from attachments even without a description', () {
      final out = caseThread(
        const [],
        caseWith(attachments: [
          TaskAttachment(
            id: 'a1',
            type: AttachmentType.image,
            url: 'https://example.com/a1.jpg',
            uploadedAt: t0,
            uploadedBy: 'ziad',
          ),
        ]),
      );
      expect(out.single.isOpening, isTrue);
      expect(out.single.hasAttachments, isTrue);
    });

    test('does NOT synthesize once a server opening exists (no double-render)',
        () {
      final serverOpening = CaseMessage(
        id: 'server-open',
        kind: CaseMessageKind.opening,
        authorRole: CaseAuthorRole.reporter,
        text: 'Opened server-side',
        createdAt: t0,
      );
      final out = caseThread(
        [serverOpening, reply('m1')],
        caseWith(description: 'The register froze', createdAt: t0),
      );
      expect(out.length, 2);
      expect(out.where((m) => m.isOpening).length, 1);
      expect(out.first.id, 'server-open');
    });

    test('returns messages unchanged when the case has no opening content', () {
      final msgs = [reply('m1')];
      final out = caseThread(msgs, caseWith());
      expect(out, msgs);
    });

    test('empty case with no content yields an empty thread', () {
      expect(caseThread(const [], caseWith()), isEmpty);
    });
  });
}
