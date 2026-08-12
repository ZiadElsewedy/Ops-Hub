import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:drop/core/constants/app_constants.dart';
import 'package:drop/core/enums/attachment_type.dart';
import 'package:drop/core/enums/request_status.dart';
import 'package:drop/core/errors/exceptions.dart';
import 'package:drop/core/media/media_upload_service.dart';
import 'package:drop/features/requests/data/models/request_model.dart';
import 'package:drop/features/requests/domain/entities/request_event.dart';
import 'package:drop/features/task/domain/entities/task_attachment.dart';

abstract class RequestRemoteDataSource {
  Stream<List<RequestModel>> watchAllRequests();
  Stream<List<RequestModel>> watchBranchRequests(String branchId);
  Stream<List<RequestModel>> watchMyRequests(String uid);
  Future<RequestModel?> getRequest(String requestId);
  Stream<RequestModel?> watchRequest(String requestId);
  Stream<List<RequestEvent>> watchEvents(String requestId);

  /// A fresh, guaranteed-unique request id — generated up front so opening media
  /// can be uploaded to `requests/{id}/attachments/...` before the doc is written.
  String newRequestId();

  Future<RequestModel> createRequest(RequestModel request);

  /// Single targeted update — status + decision stamps. Moving to a decision
  /// stamps `decided*`; moving back to pending (an admin REOPEN) clears them and
  /// stamps `reopened*` instead — [decidedBy]/[decidedByName] carry the acting
  /// user either way.
  Future<void> changeStatus(
    String requestId,
    RequestStatus to, {
    String? decidedBy,
    String? decidedByName,
  });

  /// Single `add` of one event document (no whole-array rewrite).
  Future<void> addEvent(String requestId, RequestEvent event);

  /// SOFT delete — stamps `deletedAt`; the doc stays as a record and the inbox
  /// streams filter it out. Never a hard Firestore delete.
  Future<void> deleteRequest(String requestId);

  Future<TaskAttachment> uploadAttachment({
    required String requestId,
    required File file,
    required AttachmentType type,
    required String uploadedBy,
    String? uploadedByName,
    int? durationMs,
    void Function(int transferred, int total)? onProgress,
  });
}

class RequestRemoteDataSourceImpl implements RequestRemoteDataSource {
  final FirebaseFirestore _firestore;
  final MediaUploadService _media;

  RequestRemoteDataSourceImpl(this._firestore, this._media);

  static const String _eventsSub = 'events';

  CollectionReference<Map<String, dynamic>> get _requests =>
      _firestore.collection(AppConstants.requestsCollection);

  CollectionReference<Map<String, dynamic>> _eventsRef(String requestId) =>
      _requests.doc(requestId).collection(_eventsSub);

  List<RequestModel> _mapSnap(QuerySnapshot<Map<String, dynamic>> snap) =>
      snap.docs.map((d) => RequestModel.fromMap(d.data(), id: d.id)).toList();

  @override
  String newRequestId() => _requests.doc().id;

  @override
  Stream<List<RequestModel>> watchAllRequests() => _requests
      .orderBy('lastEventAt', descending: true)
      .snapshots()
      .map(_mapSnap);

  @override
  Stream<List<RequestModel>> watchBranchRequests(String branchId) => _requests
      // Single equality filter (served by the automatic single-field index);
      // ordering is applied client-side in the repository (per-branch volume is
      // small), so no composite index is needed.
      .where('branchId', isEqualTo: branchId)
      .snapshots()
      .map(_mapSnap);

  @override
  Stream<List<RequestModel>> watchMyRequests(String uid) => _requests
      .where('requesterId', isEqualTo: uid)
      .snapshots()
      .map(_mapSnap);

  @override
  Future<RequestModel?> getRequest(String requestId) async {
    try {
      final doc = await _requests.doc(requestId).get();
      if (!doc.exists || doc.data() == null) return null;
      return RequestModel.fromMap(doc.data()!, id: doc.id);
    } on FirebaseException catch (e) {
      throw ServerException(e.message ?? 'Failed to load request.');
    }
  }

  @override
  Stream<RequestModel?> watchRequest(String requestId) =>
      _requests.doc(requestId).snapshots().map((doc) =>
          (!doc.exists || doc.data() == null)
              ? null
              : RequestModel.fromMap(doc.data()!, id: doc.id));

  @override
  Stream<List<RequestEvent>> watchEvents(String requestId) =>
      _eventsRef(requestId)
          .orderBy('createdAt', descending: false)
          .snapshots()
          .map((snap) => snap.docs
              .map((d) => RequestModel.eventFromMap(d.data(), id: d.id))
              .toList());

  @override
  Future<RequestModel> createRequest(RequestModel request) async {
    try {
      // Honor a pre-generated id (from [newRequestId], so opening media is already
      // uploaded under it); otherwise mint a fresh one.
      final docRef =
          request.id.isNotEmpty ? _requests.doc(request.id) : _requests.doc();
      final created =
          request.id.isNotEmpty ? request : request.copyWithId(docRef.id);
      await docRef.set({
        ...created.toMap(),
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        // Seed ordering before `onRequestCreated` writes the opening event.
        'lastEventAt': FieldValue.serverTimestamp(),
      });
      return created;
    } on FirebaseException catch (e) {
      throw ServerException(e.message ?? 'Failed to file the request.');
    }
  }

  @override
  Future<void> changeStatus(
    String requestId,
    RequestStatus to, {
    String? decidedBy,
    String? decidedByName,
  }) async {
    // Guarded in a TRANSACTION rather than a blind `update`: the client's
    // `_busy` flag only stops a double-tap on ONE device, and `approverNext`
    // only vets the caller's (possibly stale) local snapshot. Two reviewers
    // deciding the same pending request at once would otherwise both land —
    // last write wins, so an approve could silently overwrite someone else's
    // reject. The transaction re-reads the CURRENT status server-side and
    // applies the move only if it is still legal, so the loser gets a clear
    // conflict instead of a clobber. (A transaction also cannot be queued
    // offline, which removes the stale-replay hazard the old update had.)
    final ref = _requests.doc(requestId);
    try {
      await _firestore.runTransaction((txn) async {
        final snap = await txn.get(ref);
        if (!snap.exists || snap.data() == null) {
          throw const ServerException('This request no longer exists.');
        }
        final current = RequestStatus.fromString(snap.data()!['status'] as String?);
        // A decision (approve/reject) is legal only from pending; a reopen
        // (→ pending) is legal only from a decided request.
        final legal = to.isPending ? current.isTerminal : current.isPending;
        if (!legal) throw ServerException(_transitionConflictMessage(current, to));

        final data = <String, dynamic>{
          'status': to.value,
          'updatedAt': FieldValue.serverTimestamp(),
        };
        if (to.isDecision) {
          data['decidedBy'] = decidedBy;
          data['decidedByName'] = decidedByName;
          data['decidedAt'] = FieldValue.serverTimestamp();
        } else if (to.isPending) {
          // Admin reopen — the request is pending again: clear the decision and
          // record who reopened (feeds the server-written `reopened` event).
          data['decidedBy'] = null;
          data['decidedByName'] = null;
          data['decidedAt'] = null;
          data['reopenedBy'] = decidedBy;
          data['reopenedByName'] = decidedByName;
          data['reopenedAt'] = FieldValue.serverTimestamp();
        }
        txn.update(ref, data);
      });
    } on ServerException {
      rethrow; // our own conflict/not-found — already user-facing.
    } on FirebaseException catch (e) {
      throw ServerException(e.message ?? 'Failed to update the request.');
    }
  }

  /// The message shown when a decision/reopen lost the race — the request had
  /// already moved on before this write ran.
  static String _transitionConflictMessage(RequestStatus current, RequestStatus to) {
    if (to.isPending) {
      // A reopen that found the request already pending.
      return 'This request is already pending.';
    }
    // A decision that found the request already decided by someone else.
    return 'This request was already ${current.label.toLowerCase()} by someone else.';
  }

  @override
  Future<void> addEvent(String requestId, RequestEvent event) async {
    try {
      await _eventsRef(requestId).add({
        ...RequestModel.eventToMap(event),
        'createdAt': FieldValue.serverTimestamp(),
      });
    } on FirebaseException catch (e) {
      throw ServerException(e.message ?? 'Failed to add your comment.');
    }
  }

  @override
  Future<void> deleteRequest(String requestId) async {
    try {
      // SOFT delete (owner ruling): stamp `deletedAt` and keep the doc + its
      // events as a record. The inbox streams filter deleted requests out
      // client-side, so no index/migration is needed. Passes rules as a plain
      // admin update — no rules change.
      await _requests.doc(requestId).update({
        'deletedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } on FirebaseException catch (e) {
      throw ServerException(e.message ?? 'Failed to delete request.');
    }
  }

  @override
  Future<TaskAttachment> uploadAttachment({
    required String requestId,
    required File file,
    required AttachmentType type,
    required String uploadedBy,
    String? uploadedByName,
    int? durationMs,
    void Function(int transferred, int total)? onProgress,
  }) async {
    final media = await _media.upload(
      basePath: '${AppConstants.requestsCollection}/$requestId/attachments',
      file: file,
      type: type,
      onProgress: onProgress,
    );
    return TaskAttachment(
      id: media.id,
      url: media.url,
      type: type,
      uploadedAt: DateTime.now(),
      uploadedBy: uploadedBy,
      uploadedByName: uploadedByName,
      durationMs: durationMs,
    );
  }
}
