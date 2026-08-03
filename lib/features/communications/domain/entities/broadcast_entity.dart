import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:drop/core/enums/broadcast_audience.dart';
import 'package:drop/core/enums/user_role.dart';

part 'broadcast_entity.freezed.dart';

/// A one-way announcement in the Communications Center. A manager or admin
/// "sends" a broadcast to every branch ([BroadcastAudience.allBranches],
/// admin-only), a single branch ([BroadcastAudience.branch]), or one individual
/// ([BroadcastAudience.user], Phase 2); recipients read it and receive a push
/// notification. Persisted at `broadcasts/{id}` **by the `sendBroadcast` Cloud
/// Function** (the authoritative write — clients don't write the doc directly).
///
/// Access is enforced server-side in `firestore.rules`: admin reads all, branch
/// members read their branch's broadcasts plus all-branches ones, and the
/// individual recipient reads their own direct message. The queryable targeting
/// field for the branch/all feed is [branchId] (`null`/empty == all branches);
/// an individual message instead carries [targetUserId].
@freezed
class BroadcastEntity with _$BroadcastEntity {
  const BroadcastEntity._();

  const factory BroadcastEntity({
    required String id,
    required String title,
    required String message,

    /// Who sent it.
    required String senderId,
    required String senderName,
    @Default(UserRole.manager) UserRole senderRole,
    @Default(BroadcastAudience.allBranches) BroadcastAudience audience,

    /// Target branch when [audience] is [BroadcastAudience.branch]; null for an
    /// all-branches or individual broadcast.
    String? branchId,

    /// The individual recipient when [audience] is [BroadcastAudience.user].
    String? targetUserId,

    /// Notification category (announcement / reminder / emergency). Emergency
    /// retains high FCM priority; delivery is the independent [sendsPush] axis.
    @Default('general') String category,

    /// Explicit delivery choice. `true` = Push + Inbox; `false` = Inbox only.
    @Default(true) bool sendsPush,

    /// How many users the send engine resolved as recipients (set by the
    /// function on send; null on an unsent/legacy doc).
    int? recipientCount,

    /// How many devices the push was actually delivered to (set by the function
    /// after the FCM multicast completes; null until then / legacy).
    int? deliveredCount,

    /// When this broadcast was archived (hidden from the default feed but kept
    /// for history). Null = active.
    DateTime? archivedAt,
    DateTime? createdAt,
  }) = _BroadcastEntity;

  /// Whether this targets a single branch (vs. every branch / one user).
  bool get isBranchScoped => audience == BroadcastAudience.branch;

  /// Whether this is a direct message to one individual.
  bool get isDirect => audience == BroadcastAudience.user;

  /// Whether this broadcast is archived (kept for history, off the default feed).
  bool get isArchived => archivedAt != null;

  /// Whether this is live in the default feed (not archived).
  bool get isActive => archivedAt == null;

  /// Recipients the push could not be delivered to (recipients − delivered);
  /// null until both counts are known.
  int? get failedCount => (recipientCount != null && deliveredCount != null)
      ? (recipientCount! - deliveredCount!).clamp(0, recipientCount!)
      : null;
}
