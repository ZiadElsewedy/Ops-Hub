import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:opshub/core/enums/request_status.dart';
import 'package:opshub/core/enums/request_type.dart';
import 'package:opshub/core/enums/user_role.dart';
import 'package:opshub/features/task/domain/entities/task_attachment.dart';

part 'request_entity.freezed.dart';

/// A single **operations request** — an in-the-moment approval someone needs
/// during the work day (leave the store, use a staff discount, gift a customer,
/// pull stock, report maintenance…). Deliberately simple: a request is just a
/// **type + a short message** (+ optional attachments) that needs a yes/no.
/// Stored at `requests/{id}`; the timeline (opening submission, the approve /
/// reject decision, and comments) lives in the append-only
/// `requests/{id}/events` subcollection.
///
/// Unlike a Case there is **no privacy split** — [requesterId] rides the doc, so
/// the owner's list is a plain `where('requesterId', ==)` query. The free-text
/// reason lives in [details] under the `message` key (kept as a small map so the
/// persistence boundary and future needs stay flexible).
@freezed
class RequestEntity with _$RequestEntity {
  const RequestEntity._();

  const factory RequestEntity({
    required String id,

    /// Human-friendly reference ("REQ-000123"), server-assigned by
    /// `onRequestCreated` from the `counters/requests` sequence. Null until the
    /// function runs — [refLabel] falls back to a deterministic short code.
    String? refCode,
    int? seq,

    /// Owning branch (the requester's branch). Scopes every read/query.
    String? branchId,
    required RequestType type,
    @Default(RequestStatus.pending) RequestStatus status,
    required String requesterId,
    String? requesterName,
    @Default(UserRole.employee) UserRole requesterRole,

    /// The captured values — currently just `{'message': <reason>}`.
    @Default(<String, dynamic>{}) Map<String, dynamic> details,

    /// Opening media the requester attached (consumed by `onRequestCreated` into
    /// the opening event; Storage `requests/{id}/attachments/{attId}.<ext>`).
    @Default(<TaskAttachment>[]) List<TaskAttachment> attachments,

    /// Denormalized last-event preview for the inbox row (bumped server-side).
    String? lastEventPreview,
    DateTime? lastEventAt,
    @Default(0) int eventCount,

    /// Who decided (approved / rejected) + when — drives the header + metrics.
    String? decidedBy,
    String? decidedByName,
    DateTime? decidedAt,

    /// Soft delete (admin-only): the doc stays as a record, the inbox filters
    /// it out. Never a hard Firestore delete.
    DateTime? deletedAt,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) = _RequestEntity;

  bool get isActive => status.isActive;
  bool get isTerminal => status.isTerminal;
  bool get isPending => status.isPending;
  bool get isDeleted => deletedAt != null;
  bool get hasAttachments => attachments.isNotEmpty;

  /// The requester's short reason (the only captured field).
  String get message => (details['message'] ?? '').toString().trim();

  /// The one-line summary shown on cards / previews — the message, or the type
  /// label when no message was written.
  String get summary => message.isNotEmpty ? message : type.label;

  /// Timestamp used to order the inbox — latest event, falling back to create.
  DateTime? get lastActivityAt => lastEventAt ?? createdAt;

  /// The human-friendly reference to render — the server [refCode] when present,
  /// else a deterministic short fallback from the doc id (never blank).
  String get refLabel => (refCode != null && refCode!.trim().isNotEmpty)
      ? refCode!.trim()
      : requestRefCode(id);

  /// How long a pending request has been waiting (for the "ageing" hint). Null
  /// once decided.
  Duration? get pendingFor => status.isPending && createdAt != null
      ? DateTime.now().difference(createdAt!)
      : null;
}

/// Deterministic human-friendly fallback code from a Firestore id — used until
/// the server assigns the sequential [RequestEntity.refCode]. Pure + stable.
String requestRefCode(String id) {
  if (id.isEmpty) return 'REQ';
  final tail = id.length <= 6 ? id : id.substring(id.length - 6);
  return 'REQ-${tail.toUpperCase()}';
}
