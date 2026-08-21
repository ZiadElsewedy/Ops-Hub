import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opshub/core/enums/attachment_type.dart';
import 'package:opshub/core/enums/case_category.dart';
import 'package:opshub/core/enums/case_privacy.dart';
import 'package:opshub/core/enums/case_recipient.dart';
import 'package:opshub/core/enums/case_status.dart';
import 'package:opshub/features/cases/data/models/case_model.dart';
import 'package:opshub/features/cases/domain/entities/case_entity.dart';
import 'package:opshub/features/cases/domain/entities/case_identity.dart';
import 'package:opshub/features/cases/domain/entities/case_message.dart';
import 'package:opshub/features/task/domain/entities/task_attachment.dart';

void main() {
  group('CaseModel.toMap privacy split', () {
    test('a normal case denormalizes the sender name; visibleToManager tracks recipient',
        () {
      final map = CaseModel.fromEntity(const CaseEntity(
        id: 'c',
        subject: 't',
        privacy: CasePrivacy.normal,
        reporterDisplayName: 'Ziad',
        recipient: CaseRecipient.manager,
      )).toMap();
      expect(map['reporterDisplayName'], 'Ziad');
      expect(map['visibleToManager'], isTrue);
    });

    test('a confidential case never writes the sender name', () {
      final map = CaseModel.fromEntity(const CaseEntity(
        id: 'c',
        subject: 't',
        privacy: CasePrivacy.confidential,
        reporterDisplayName: 'Ziad',
      )).toMap();
      expect(map['reporterDisplayName'], isNull);
    });

    test('an admin-routed case is not visible to managers', () {
      final map = CaseModel.fromEntity(const CaseEntity(
        id: 'c',
        subject: 't',
        recipient: CaseRecipient.admin,
      )).toMap();
      expect(map['visibleToManager'], isFalse);
    });

    test('urgent is persisted; there is no severity field', () {
      final map = CaseModel.fromEntity(const CaseEntity(
        id: 'c',
        subject: 't',
        urgent: true,
      )).toMap();
      expect(map['urgent'], isTrue);
      expect(map.containsKey('severity'), isFalse);
    });
  });

  group('CaseModel round-trip', () {
    test('preserves the core fields incl. urgent + status', () {
      const entity = CaseEntity(
        id: 'c',
        branchId: 'b1',
        subject: 'Broken POS',
        description: 'It froze',
        category: CaseCategory.operations,
        recipient: CaseRecipient.both,
        privacy: CasePrivacy.normal,
        urgent: true,
        status: CaseStatus.inDiscussion,
        reporterDisplayName: 'Ziad',
        messageCount: 3,
      );
      final round = CaseModel.fromMap(
        CaseModel.fromEntity(entity).toMap(),
        id: 'c',
      ).toEntity();
      expect(round.subject, 'Broken POS');
      expect(round.category, CaseCategory.operations);
      expect(round.recipient, CaseRecipient.both);
      expect(round.privacy, CasePrivacy.normal);
      expect(round.urgent, isTrue);
      expect(round.status, CaseStatus.inDiscussion);
      expect(round.messageCount, 3);
    });
  });

  group('CaseModel message (de)serialization', () {
    test('round-trips kind / role / text / systemEvent', () {
      final msg = CaseMessage(
        id: 'm1',
        authorId: 'u1',
        authorName: 'Ziad',
        authorRole: CaseAuthorRole.recipient,
        kind: CaseMessageKind.message,
        text: 'Looking into it',
        createdAt: DateTime(2026, 7, 4, 10),
      );
      final map = {
        ...CaseModel.messageToMap(msg),
        'createdAt': Timestamp.fromDate(DateTime(2026, 7, 4, 10)),
      };
      final back = CaseModel.messageFromMap(map, id: 'm1');
      expect(back.authorRole, CaseAuthorRole.recipient);
      expect(back.kind, CaseMessageKind.message);
      expect(back.text, 'Looking into it');
      expect(back.authorId, 'u1');
    });

    test('a system message carries its systemEvent', () {
      final map = {
        ...CaseModel.messageToMap(CaseMessage(
          id: 's',
          kind: CaseMessageKind.system,
          authorRole: CaseAuthorRole.system,
          text: 'Case closed',
          systemEvent: CaseStatus.closed.value,
          createdAt: DateTime(2026, 7, 4),
        )),
        'createdAt': Timestamp.fromDate(DateTime(2026, 7, 4)),
      };
      final back = CaseModel.messageFromMap(map);
      expect(back.isSystem, isTrue);
      expect(back.systemEvent, 'closed');
    });

    test('attachments survive the round-trip', () {
      final msg = CaseMessage(
        id: 'm',
        kind: CaseMessageKind.message,
        attachments: [
          TaskAttachment(
            id: 'a1',
            url: 'https://x/a.jpg',
            type: AttachmentType.image,
            uploadedAt: DateTime(2026, 7, 4),
            uploadedBy: 'u1',
          ),
        ],
        createdAt: DateTime(2026, 7, 4),
      );
      final map = {
        ...CaseModel.messageToMap(msg),
        'createdAt': Timestamp.fromDate(DateTime(2026, 7, 4)),
      };
      final back = CaseModel.messageFromMap(map);
      expect(back.attachments.length, 1);
      expect(back.attachments.first.url, 'https://x/a.jpg');
    });
  });

  group('CaseModel identity subdoc', () {
    test('round-trips the reporter identity', () {
      const identity = CaseIdentity(
        caseId: 'c1',
        createdByUserId: 'u1',
        createdByName: 'Ziad',
        privacy: CasePrivacy.confidential,
        branchId: 'b1',
      );
      final back = CaseModel.identityFromMap(
        CaseModel.identityToMap(identity),
        caseId: 'c1',
      );
      expect(back.createdByUserId, 'u1');
      expect(back.createdByName, 'Ziad');
      expect(back.privacy, CasePrivacy.confidential);
      expect(back.branchId, 'b1');
    });
  });
}
