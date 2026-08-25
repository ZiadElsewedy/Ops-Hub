import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:opshub/core/enums/broadcast_category.dart';
import 'package:opshub/features/communications/domain/template_renderer.dart';

part 'broadcast_template_entity.freezed.dart';

/// A reusable broadcast blueprint (Communications Center — Phase 2). Saved by a
/// manager/admin and applied in the composer. Persisted at
/// `broadcastTemplates/{id}`; [branchId] empty/null = a **global** template
/// (admin-made, usable by every branch), mirroring `task_templates`.
///
/// The [message] may carry `{{placeholder}}` tokens (e.g. `{{employee_name}}`)
/// rendered by [TemplateRenderer] before send.
@freezed
class BroadcastTemplateEntity with _$BroadcastTemplateEntity {
  const BroadcastTemplateEntity._();

  const factory BroadcastTemplateEntity({
    required String id,
    required String title,
    required String message,
    @Default(BroadcastCategory.announcement) BroadcastCategory category,
    /// Who created the template.
    @Default('') String ownerId,
    /// Owning branch; null/empty = a global template.
    String? branchId,
    @Default(false) bool isFavorite,
    @Default(0) int usageCount,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) = _BroadcastTemplateEntity;

  /// Whether this template is shared across all branches (admin-made).
  bool get isGlobal => (branchId ?? '').isEmpty;

  /// The `{{placeholder}}` tokens this template's message references.
  List<String> get placeholders => TemplateRenderer.extract(message);
}
