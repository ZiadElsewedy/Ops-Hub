import 'package:opshub/core/enums/broadcast_category.dart';
import 'package:opshub/core/extensions/firestore_extensions.dart';
import 'package:opshub/features/communications/domain/entities/broadcast_template_entity.dart';

/// Firestore (de)serialization for [BroadcastTemplateEntity] — collection
/// `broadcastTemplates/{id}`. Hand-written (matching the project's model
/// convention) so Firestore `Timestamp`s round-trip cleanly. A **global**
/// template stores the empty `''` branchId.
class BroadcastTemplateModel {
  final String id;
  final String title;
  final String message;
  final BroadcastCategory category;
  final String ownerId;
  final String branchId; // '' = global
  final bool isFavorite;
  final int usageCount;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const BroadcastTemplateModel({
    required this.id,
    required this.title,
    required this.message,
    this.category = BroadcastCategory.announcement,
    this.ownerId = '',
    this.branchId = '',
    this.isFavorite = false,
    this.usageCount = 0,
    this.createdAt,
    this.updatedAt,
  });

  factory BroadcastTemplateModel.fromMap(Map<String, dynamic> map,
          {String? id}) =>
      BroadcastTemplateModel(
        id: id ?? map['id'] as String? ?? '',
        title: map['title'] as String? ?? '',
        message: map['message'] as String? ?? '',
        category: BroadcastCategory.fromString(map['category'] as String?),
        ownerId: map['ownerId'] as String? ?? '',
        branchId: map['branchId'] as String? ?? '',
        isFavorite: map['isFavorite'] as bool? ?? false,
        usageCount: (map['usageCount'] as num?)?.toInt() ?? 0,
        createdAt: map.date('createdAt'),
        updatedAt: map.date('updatedAt'),
      );

  factory BroadcastTemplateModel.fromEntity(BroadcastTemplateEntity e) =>
      BroadcastTemplateModel(
        id: e.id,
        title: e.title,
        message: e.message,
        category: e.category,
        ownerId: e.ownerId,
        branchId: e.branchId ?? '',
        isFavorite: e.isFavorite,
        usageCount: e.usageCount,
        createdAt: e.createdAt,
        updatedAt: e.updatedAt,
      );

  /// Writable fields (`createdAt`/`updatedAt` are server-set in the datasource).
  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        'message': message,
        'category': category.value,
        'ownerId': ownerId,
        'branchId': branchId,
        'isFavorite': isFavorite,
        'usageCount': usageCount,
      };

  BroadcastTemplateModel copyWithId(String newId) => BroadcastTemplateModel(
        id: newId,
        title: title,
        message: message,
        category: category,
        ownerId: ownerId,
        branchId: branchId,
        isFavorite: isFavorite,
        usageCount: usageCount,
        createdAt: createdAt,
        updatedAt: updatedAt,
      );

  BroadcastTemplateEntity toEntity() => BroadcastTemplateEntity(
        id: id,
        title: title,
        message: message,
        category: category,
        ownerId: ownerId,
        branchId: branchId.isEmpty ? null : branchId,
        isFavorite: isFavorite,
        usageCount: usageCount,
        createdAt: createdAt,
        updatedAt: updatedAt,
      );
}
