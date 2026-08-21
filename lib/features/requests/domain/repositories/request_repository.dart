import 'dart:io';

import 'package:opshub/core/enums/attachment_type.dart';
import 'package:opshub/core/enums/request_status.dart';
import 'package:opshub/features/requests/domain/entities/request_entity.dart';
import 'package:opshub/features/requests/domain/entities/request_event.dart';
import 'package:opshub/features/task/domain/entities/task_attachment.dart';

/// Contract for Operations Requests data access. The branch/role access model is
/// enforced server-side by `firestore.rules` (admin: all · manager: own branch ·
/// requester: their own requests); these methods are the client surface the
/// Requests UI builds on. Ordering is applied client-side (small per-scope
/// volume) so no composite indexes are needed.
abstract class RequestRepository {
  /// All requests, latest-activity first — **admin only** (rules reject a
  /// non-admin collection read).
  Stream<List<RequestEntity>> watchAllRequests();

  /// Requests in a single branch — an own-branch manager. Realtime.
  Stream<List<RequestEntity>> watchBranchRequests(String branchId);

  /// The caller's OWN requests (`requesterId == uid`). Realtime — no privacy
  /// split, so this is a plain equality query (unlike Cases' collectionGroup).
  Stream<List<RequestEntity>> watchMyRequests(String uid);

  /// Realtime stream of one request doc — drives the detail header, status
  /// control, and the terminal/read-only gate. Emits null if deleted.
  Stream<RequestEntity?> watchRequest(String requestId);

  /// One-shot fetch for a request doc. Mostly useful for command-style callers
  /// and tests; realtime UI should prefer [watchRequest].
  Future<RequestEntity?> getRequest(String requestId);

  /// Realtime stream of a request's timeline (`requests/{id}/events`), oldest
  /// first. Every role gets this.
  Stream<List<RequestEvent>> watchEvents(String requestId);

  /// A fresh, guaranteed-unique request id, generated up front so opening media
  /// can be uploaded before the request doc is written.
  String newRequestId();

  /// Files a new request (single doc write). The opening `submitted` event +
  /// human-friendly `refCode` are written server-side by `onRequestCreated`.
  /// Returns the request with its generated id.
  Future<RequestEntity> createRequest(RequestEntity request);

  /// Moves a request to [to] — a single targeted doc update. `onRequestUpdated`
  /// appends the lifecycle event + notifies. [decidedBy]/[decidedByName] carry
  /// the acting user: they stamp `decided*` on approve/reject, and `reopened*`
  /// on an admin reopen back to pending.
  Future<void> changeStatus(
    String requestId,
    RequestStatus to, {
    String? decidedBy,
    String? decidedByName,
  });

  /// Appends one event (a comment / attachment-added) — a single `add` of one
  /// document. `onRequestEventCreated` bumps the parent `lastEvent*` + notifies
  /// the other party.
  Future<void> addEvent(String requestId, RequestEvent event);

  /// Uploads one media file to `requests/{requestId}/attachments/{id}.<ext>`
  /// (unique id, never overwrites) and returns the resolved [TaskAttachment].
  Future<TaskAttachment> uploadAttachment({
    required String requestId,
    required File file,
    required AttachmentType type,
    required String uploadedBy,
    String? uploadedByName,
    int? durationMs,
    void Function(int transferred, int total)? onProgress,
  });

  /// Permanently deletes a request — **admin only** (requests are records).
  Future<void> deleteRequest(String requestId);
}
