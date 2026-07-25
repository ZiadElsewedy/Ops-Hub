import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:drop/core/constants/app_constants.dart';
import 'package:drop/core/utils/app_logger.dart';
import 'package:drop/core/enums/attachment_type.dart';
import 'package:drop/core/enums/case_status.dart';
import 'package:drop/core/errors/exceptions.dart';
import 'package:drop/core/media/media_upload_service.dart';
import 'package:drop/features/cases/data/models/case_model.dart';
import 'package:drop/features/cases/domain/entities/case_identity.dart';
import 'package:drop/features/cases/domain/entities/case_message.dart';
import 'package:drop/features/task/domain/entities/task_attachment.dart';

abstract class CaseRemoteDataSource {
  Stream<List<CaseModel>> watchAllCases();
  Stream<List<CaseModel>> watchBranchCases(String branchId);
  Future<List<CaseModel>> getMyCases(String uid);
  Future<CaseModel?> getCase(String caseId);
  Stream<CaseModel?> watchCase(String caseId);
  Stream<List<CaseMessage>> watchMessages(String caseId);

  /// A fresh, guaranteed-unique case id — generated up front so opening media
  /// can be uploaded to `cases/{id}/attachments/...` before the doc is written
  /// (so `onCaseCreated` sees the attachments when it builds the opening message).
  String newCaseId();

  /// Writes the case doc + its private `reporter/identity` subdoc atomically.
  /// The opening message is written server-side by `onCaseCreated`.
  Future<CaseModel> createCase(CaseModel newCase, CaseIdentity identity);

  /// Single targeted update — status + timestamps only.
  Future<void> changeStatus(String caseId, CaseStatus to);

  /// Single `add` of one message document (no whole-array rewrite).
  Future<void> sendMessage(String caseId, CaseMessage message);

  Future<CaseIdentity?> revealReporter(String caseId);
  Future<void> deleteCase(String caseId);

  Future<TaskAttachment> uploadAttachment({
    required String caseId,
    required File file,
    required AttachmentType type,
    required String uploadedBy,
    String? uploadedByName,
    int? durationMs,
    void Function(int transferred, int total)? onProgress,
  });
}

class CaseRemoteDataSourceImpl implements CaseRemoteDataSource {
  final FirebaseFirestore _firestore;
  final MediaUploadService _media;

  CaseRemoteDataSourceImpl(this._firestore, this._media);

  /// The private identity subcollection under a case. Named `reporter` (NOT
  /// `private`) so a collectionGroup('reporter') query never collides with
  /// `users/{uid}/private/compensation`.
  static const String _reporterSub = 'reporter';
  static const String _identityDoc = 'identity';
  static const String _messagesSub = 'messages';

  CollectionReference<Map<String, dynamic>> get _cases =>
      _firestore.collection(AppConstants.casesCollection);

  DocumentReference<Map<String, dynamic>> _identityRef(String caseId) =>
      _cases.doc(caseId).collection(_reporterSub).doc(_identityDoc);

  CollectionReference<Map<String, dynamic>> _messagesRef(String caseId) =>
      _cases.doc(caseId).collection(_messagesSub);

  List<CaseModel> _mapSnap(QuerySnapshot<Map<String, dynamic>> snap) =>
      snap.docs.map((d) => CaseModel.fromMap(d.data(), id: d.id)).toList();

  @override
  String newCaseId() => _cases.doc().id;

  @override
  Stream<List<CaseModel>> watchAllCases() => _cases
      .orderBy('lastMessageAt', descending: true)
      .snapshots()
      .map(_mapSnap);

  @override
  Stream<List<CaseModel>> watchBranchCases(String branchId) => _cases
      // Two equality filters (branch + manager-visibility) are served by
      // single-field indexes (zigzag merge) — no composite index needed. Order
      // is applied client-side in the repository (per-branch volume is small).
      .where('branchId', isEqualTo: branchId)
      .where('visibleToManager', isEqualTo: true)
      .snapshots()
      .map(_mapSnap);

  @override
  Future<List<CaseModel>> getMyCases(String uid) async {
    AppLog.call('cases', 'getMyCases',
        details: 'collectionGroup("$_reporterSub").where(createdByUserId == $uid)');
    try {
      // The case doc carries no creator uid (privacy split), so the owner's list
      // comes from the private `reporter` subdocs (collectionGroup), then a
      // per-case fetch. Case volume per filer is small.
      final identitySnap = await _firestore
          .collectionGroup(_reporterSub)
          .where('createdByUserId', isEqualTo: uid)
          .get();
      AppLog.success('cases',
          'collectionGroup ok: ${identitySnap.docs.length} identity doc(s)');
      final caseIds = <String>{
        for (final d in identitySnap.docs)
          // `reporter` was also used by the retired `reports` collection, and a
          // collection-group query spans both trees. Never reinterpret a legacy
          // report id as a case id.
          if (d.reference.parent.parent != null &&
              d.reference.parent.parent!.parent.id ==
                  AppConstants.casesCollection)
            d.reference.parent.parent!.id,
      };
      if (caseIds.isEmpty) return const [];
      final cases = await Future.wait(caseIds.map((id) async {
        final doc = await _cases.doc(id).get();
        if (!doc.exists || doc.data() == null) return null;
        return CaseModel.fromMap(doc.data()!, id: doc.id);
      }));
      return cases.whereType<CaseModel>().toList();
    } on FirebaseException catch (e, st) {
      AppLog.error('cases',
          'getMyCases failed: code=${e.code} message=${e.message}', e, st);
      throw ServerException(
          '[${e.code}] ${e.message ?? 'Failed to load your cases.'}');
    }
  }

  @override
  Future<CaseModel?> getCase(String caseId) async {
    try {
      final doc = await _cases.doc(caseId).get();
      if (!doc.exists || doc.data() == null) return null;
      return CaseModel.fromMap(doc.data()!, id: doc.id);
    } on FirebaseException catch (e) {
      throw ServerException(e.message ?? 'Failed to load case.');
    }
  }

  @override
  Stream<CaseModel?> watchCase(String caseId) =>
      _cases.doc(caseId).snapshots().map((doc) =>
          (!doc.exists || doc.data() == null)
              ? null
              : CaseModel.fromMap(doc.data()!, id: doc.id));

  @override
  Stream<List<CaseMessage>> watchMessages(String caseId) => _messagesRef(caseId)
      .orderBy('createdAt', descending: false)
      .snapshots()
      .map((snap) => snap.docs
          .map((d) => CaseModel.messageFromMap(d.data(), id: d.id))
          .toList());

  @override
  Future<CaseModel> createCase(CaseModel newCase, CaseIdentity identity) async {
    try {
      // Honor a pre-generated id (from [newCaseId], so opening media already
      // uploaded under it); otherwise mint a fresh one.
      final docRef =
          newCase.id.isNotEmpty ? _cases.doc(newCase.id) : _cases.doc();
      final created =
          newCase.id.isNotEmpty ? newCase : newCase.copyWithId(docRef.id);
      final batch = _firestore.batch();
      batch.set(docRef, {
        ...created.toMap(),
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        // Seed ordering before `onCaseCreated` writes the opening message.
        'lastMessageAt': FieldValue.serverTimestamp(),
      });
      batch.set(_identityRef(docRef.id), {
        ...CaseModel.identityToMap(identity),
        'caseId': docRef.id,
        'createdAt': FieldValue.serverTimestamp(),
      });
      await batch.commit();
      return created;
    } on FirebaseException catch (e) {
      throw ServerException(e.message ?? 'Failed to open case.');
    }
  }

  @override
  Future<void> changeStatus(String caseId, CaseStatus to) async {
    try {
      await _cases.doc(caseId).update({
        'status': to.value,
        'updatedAt': FieldValue.serverTimestamp(),
        // Stamp on close, clear on reopen.
        'closedAt':
            to == CaseStatus.closed ? FieldValue.serverTimestamp() : null,
      });
    } on FirebaseException catch (e) {
      throw ServerException(e.message ?? 'Failed to update the case.');
    }
  }

  @override
  Future<void> sendMessage(String caseId, CaseMessage message) async {
    try {
      await _messagesRef(caseId).add({
        ...CaseModel.messageToMap(message),
        'createdAt': FieldValue.serverTimestamp(),
      });
    } on FirebaseException catch (e) {
      throw ServerException(e.message ?? 'Failed to send your message.');
    }
  }

  @override
  Future<CaseIdentity?> revealReporter(String caseId) async {
    try {
      final doc = await _identityRef(caseId).get();
      if (!doc.exists || doc.data() == null) return null;
      return CaseModel.identityFromMap(doc.data()!, caseId: caseId);
    } on FirebaseException catch (e) {
      throw ServerException(e.message ?? 'Failed to read the reporter.');
    }
  }

  @override
  Future<void> deleteCase(String caseId) async {
    try {
      // The private reporter subdoc + messages are left in place; deleting a
      // case is an admin-only, rare operation and the subdocs are orphaned
      // harmlessly.
      await _cases.doc(caseId).delete();
    } on FirebaseException catch (e) {
      throw ServerException(e.message ?? 'Failed to delete case.');
    }
  }

  @override
  Future<TaskAttachment> uploadAttachment({
    required String caseId,
    required File file,
    required AttachmentType type,
    required String uploadedBy,
    String? uploadedByName,
    int? durationMs,
    void Function(int transferred, int total)? onProgress,
  }) async {
    final media = await _media.upload(
      basePath: '${AppConstants.casesCollection}/$caseId/attachments',
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
