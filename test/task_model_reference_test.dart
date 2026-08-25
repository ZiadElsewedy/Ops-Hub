import 'package:flutter_test/flutter_test.dart';
import 'package:opshub/core/enums/attachment_type.dart';
import 'package:opshub/features/task/data/models/task_model.dart';
import 'package:opshub/features/task/domain/entities/task_attachment.dart';
import 'package:opshub/features/task/domain/entities/task_entity.dart';

/// Verifies the manager/admin `referenceAttachments` round-trip through
/// serialization and the entity boundary, and that absence reads as an empty
/// list (back-compatible with tasks written before reference images existed).
void main() {
  final ref = TaskAttachment(
    id: 'a1',
    url: 'https://example.com/ref.jpg',
    type: AttachmentType.image,
    uploadedAt: DateTime.utc(2026, 6, 25, 9),
    uploadedBy: 'mgr1',
    uploadedByName: 'Mona K.',
  );

  group('TaskModel.referenceAttachments serialization', () {
    test('writes the reference attachments as a list of maps', () {
      final map =
          TaskModel(id: '1', title: 't', referenceAttachments: [ref]).toMap();
      final list = map['referenceAttachments'] as List;
      expect(list, hasLength(1));
      expect((list.first as Map)['url'], 'https://example.com/ref.jpg');
      expect((list.first as Map)['type'], 'image');
    });

    test('reads reference attachments back, empty when absent', () {
      expect(TaskModel.fromMap(const {}).referenceAttachments, isEmpty);
      final back = TaskModel.fromMap({
        'referenceAttachments': [
          {
            'id': 'a1',
            'url': 'https://example.com/ref.jpg',
            'type': 'image',
            'uploadedBy': 'mgr1',
            'uploadedByName': 'Mona K.',
          },
        ],
      });
      expect(back.referenceAttachments, hasLength(1));
      expect(back.referenceAttachments.first.url,
          'https://example.com/ref.jpg');
      expect(back.referenceAttachments.first.type, AttachmentType.image);
    });

    test('round-trips through the entity boundary', () {
      final e = TaskEntity(id: '1', title: 't', referenceAttachments: [ref]);
      expect(TaskModel.fromEntity(e).referenceAttachments, hasLength(1));
      expect(
        TaskModel.fromEntity(e).toEntity().referenceAttachments.first.id,
        'a1',
      );
      expect(e.hasReferences, isTrue);
      expect(const TaskEntity(id: '2', title: 't').hasReferences, isFalse);
    });
  });
}
