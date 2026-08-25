import 'dart:io';

import 'package:opshub/core/enums/attachment_type.dart';
import 'package:opshub/core/enums/case_status.dart';
import 'package:opshub/features/cases/domain/entities/case_entity.dart';
import 'package:opshub/features/cases/domain/entities/case_identity.dart';
import 'package:opshub/features/cases/domain/entities/case_message.dart';
import 'package:opshub/features/task/domain/entities/task_attachment.dart';

/// Contract for Case Management data access. The branch/role access model is
/// enforced server-side by `firestore.rules` (admin: all cases · manager: own
/// branch, non-admin-routed · reporter: their own cases); these methods are the
/// client surface the Cases UI builds on.
abstract class CaseRepository {
  /// All cases, most-recent-activity first — **admin only** (the rules reject a
  /// non-admin collection read).
  Stream<List<CaseEntity>> watchAllCases();

  /// Cases in a single branch that a manager may see — own-branch,
  /// non-admin-routed (`visibleToManager == true`). Realtime.
  Stream<List<CaseEntity>> watchBranchCases(String branchId);

  /// The caller's OWN cases (any privacy). Resolved via a collectionGroup query
  /// on the private `reporter` subdocs (the case doc carries no creator uid),
  /// then a per-case fetch. One-shot (the filer's list is small).
  Future<List<CaseEntity>> getMyCases(String uid);

  /// A single case by id, or null if it doesn't exist.
  Future<CaseEntity?> getCase(String caseId);

  /// Realtime stream of one case doc — drives the conversation header, status
  /// control, and the closed/read-only gate. Emits null if the case is deleted.
  Stream<CaseEntity?> watchCase(String caseId);

  /// Realtime stream of a case's conversation (`cases/{id}/messages`), oldest
  /// first. Every role gets this — the fix for the old no-stream reply bug.
  Stream<List<CaseMessage>> watchMessages(String caseId);

  /// A fresh, guaranteed-unique case id, generated up front so opening media can
  /// be uploaded before the case doc is written.
  String newCaseId();

  /// Files a new case: writes the case doc AND its private `reporter/identity`
  /// subdoc atomically (one [WriteBatch]). The opening message is written
  /// server-side by `onCaseCreated`. Returns the case with its generated id.
  Future<CaseEntity> createCase(CaseEntity newCase, CaseIdentity identity);

  /// Moves a case to [to] — a single doc update (`status`/`updatedAt`/`closedAt`).
  /// The `onCaseUpdated` function appends the system message + notifies.
  Future<void> changeStatus(String caseId, CaseStatus to);

  /// Appends one message to the conversation — a single `add` of one document
  /// (no whole-array read-modify-write). `onCaseMessageCreated` bumps the parent
  /// `lastMessage*` + notifies the other party.
  Future<void> sendMessage(String caseId, CaseMessage message);

  /// Reads the private reporter identity — an **admin** revealing a confidential
  /// sender, or the owner reading their own. Returns null if missing.
  Future<CaseIdentity?> revealReporter(String caseId);

  /// Uploads one media file to `cases/{caseId}/attachments/{id}.<ext>` (unique
  /// id, never overwrites) and returns the resolved [TaskAttachment].
  Future<TaskAttachment> uploadAttachment({
    required String caseId,
    required File file,
    required AttachmentType type,
    required String uploadedBy,
    String? uploadedByName,
    int? durationMs,
    void Function(int transferred, int total)? onProgress,
  });

  /// Permanently deletes a case — **admin only** (cases are records).
  Future<void> deleteCase(String caseId);
}
