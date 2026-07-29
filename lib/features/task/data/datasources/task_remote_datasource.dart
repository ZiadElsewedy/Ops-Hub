import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:drop/core/constants/app_constants.dart';
import 'package:drop/core/enums/attachment_type.dart';
import 'package:drop/core/enums/schedule_shift.dart';
import 'package:drop/core/errors/exceptions.dart';
import 'package:drop/core/media/media_upload_service.dart';
import 'package:drop/features/task/data/models/automation_run_model.dart';
import 'package:drop/features/task/data/models/recurring_task_template_model.dart';
import 'package:drop/features/task/data/models/task_model.dart';
import 'package:drop/features/task/data/models/task_template_model.dart';
import 'package:drop/features/task/domain/entities/activity_entry.dart';
import 'package:drop/features/task/domain/entities/automation_run_entity.dart';
import 'package:drop/features/task/domain/entities/task_attachment.dart';

abstract class TaskRemoteDataSource {
  Future<List<TaskModel>> getAllTasks();
  Future<List<TaskModel>> getTasksByBranch(String branchId);
  Future<List<TaskModel>> getEmployeeTasks(String employeeId);

  /// Real-time variants — emit on every change so a newly assigned/updated task
  /// appears without a manual refresh (backed by Firestore's offline cache).
  Stream<List<TaskModel>> watchAllTasks();
  Stream<List<TaskModel>> watchTasksByBranch(String branchId);
  Stream<List<TaskModel>> watchEmployeeTasks(String employeeId);
  Stream<List<TaskModel>> watchShiftTasks({
    required String branchId,
    required ScheduleShift shift,
  });

  Future<TaskModel?> getTask(String taskId);
  Future<TaskModel> createTask(TaskModel task);

  /// Creates [task] at its own `task.id` — a no-op (returns null) if a doc
  /// with that id already exists. Sets both `createdAt`/`updatedAt` server
  /// timestamps (unlike [updateTask], which only stamps `updatedAt`), so a
  /// task materialized this way sorts correctly forever after.
  Future<TaskModel?> createTaskWithId(TaskModel task);
  Future<void> updateTask(TaskModel task);

  /// Atomically moves a task through its lifecycle inside a Firestore
  /// transaction — the ONLY consistent way to change status or append to the
  /// activity log. Re-reads the doc, and if [expectedFrom] is non-empty and the
  /// current `status` isn't in it, throws [ConflictException] (someone moved the
  /// task first). Otherwise it appends [appendLog] to the **server's** current
  /// `activityLog` (never a stale client array), merges [patch] (DateTime values
  /// auto-encoded), and bumps `version`. Pass an empty [expectedFrom] for a pure
  /// log append with no status precondition (notes / work-event milestones).
  Future<void> transitionTask({
    required String taskId,
    required Set<String> expectedFrom,
    required Map<String, Object?> patch,
    required List<ActivityEntry> appendLog,
  });

  Future<void> deleteTask(String taskId);
  Future<void> assignTask({
    required String taskId,
    required List<String> employeeIds,
    String? assignedShiftId,
  });

  /// Uploads one media file to `tasks/{taskId}/attachments/{id}.<ext>` (unique
  /// id, never overwrites) and returns the resolved [TaskAttachment]. Reports
  /// byte progress via [onProgress] (transferred, total) for the loading overlay.
  /// Pass an [UploadCanceller] to make the upload abortable.
  Future<TaskAttachment> uploadAttachment({
    required String taskId,
    required File file,
    required AttachmentType type,
    required String uploadedBy,
    String? uploadedByName,
    int? durationMs,
    UploadCanceller? canceller,
    void Function(int transferred, int total)? onProgress,
  });

  // ─── Task templates (reusable blueprints) ──────────────────────
  Future<List<TaskTemplateModel>> getTemplates();
  Future<TaskTemplateModel> createTemplate(TaskTemplateModel template);
  Future<void> deleteTemplate(String templateId);

  // ─── Recurring shift-task templates (Shift Assignment feature) ─
  Future<List<RecurringTaskTemplateModel>> getRecurringTemplates(
      String branchId);
  Future<RecurringTaskTemplateModel> createRecurringTemplate(
      RecurringTaskTemplateModel template);
  Future<void> updateRecurringTemplate(RecurringTaskTemplateModel template);
  Future<void> deleteRecurringTemplate(String templateId);

  /// One page of a template's execution history, newest-first. [before] is the
  /// `startedAt` of the last row of the previous page (the pagination cursor);
  /// null loads the first page. Needs the `(templateId, startedAt desc)` index.
  Future<List<AutomationRunEntity>> getAutomationRuns(
    String templateId, {
    required String branchId,
    int limit,
    DateTime? before,
  });

  /// The run a resource's [correlationId] belongs to (traceability: task /
  /// notification / audit → run). Two equality filters need no composite index.
  Future<AutomationRunEntity?> getAutomationRunByCorrelationId(
    String correlationId, {
    required String branchId,
  });
}

class TaskRemoteDataSourceImpl implements TaskRemoteDataSource {
  final FirebaseFirestore _firestore;
  final MediaUploadService _media;

  TaskRemoteDataSourceImpl(this._firestore, this._media);

  CollectionReference<Map<String, dynamic>> get _tasks =>
      _firestore.collection(AppConstants.tasksCollection);

  CollectionReference<Map<String, dynamic>> get _templates =>
      _firestore.collection(AppConstants.taskTemplatesCollection);

  CollectionReference<Map<String, dynamic>> get _recurringTemplates =>
      _firestore.collection(AppConstants.recurringTaskTemplatesCollection);

  CollectionReference<Map<String, dynamic>> get _automationRuns =>
      _firestore.collection(AppConstants.automationRunsCollection);

  // Newest-first ordering: the admin query orders on a single field
  // (auto-indexed by Firestore, no setup). The branch / employee queries
  // **filter** (`where` / `arrayContains`); adding `orderBy` on a *different*
  // field would require a composite index and break loading until it's deployed,
  // so those are intentionally NOT ordered server-side — the repository applies
  // `sortTasksNewestFirst` instead (a per-branch / per-employee task list is
  // small, so the client sort is cheap and never needs an index).
  static const String _createdAt = 'createdAt';

  @override
  Future<List<TaskModel>> getAllTasks() async {
    try {
      final snap = await _tasks.orderBy(_createdAt, descending: true).get();
      return _mapSnap(snap);
    } on FirebaseException catch (e) {
      throw ServerException(e.message ?? 'Failed to load tasks.');
    }
  }

  @override
  Future<List<TaskModel>> getTasksByBranch(String branchId) async {
    try {
      final snap = await _tasks.where('branchId', isEqualTo: branchId).get();
      return _mapSnap(snap);
    } on FirebaseException catch (e) {
      throw ServerException(e.message ?? 'Failed to load branch tasks.');
    }
  }

  @override
  Future<List<TaskModel>> getEmployeeTasks(String employeeId) async {
    try {
      // Multi-assignee (Phase 9): a task belongs to an employee if their uid is
      // in the `assigneeIds` array.
      final snap =
          await _tasks.where('assigneeIds', arrayContains: employeeId).get();
      return _mapSnap(snap);
    } on FirebaseException catch (e) {
      throw ServerException(e.message ?? 'Failed to load your tasks.');
    }
  }

  List<TaskModel> _mapSnap(QuerySnapshot<Map<String, dynamic>> snap) =>
      snap.docs.map((d) => TaskModel.fromMap(d.data(), id: d.id)).toList();

  @override
  Stream<List<TaskModel>> watchAllTasks() =>
      _tasks.orderBy(_createdAt, descending: true).snapshots().map(_mapSnap);

  @override
  Stream<List<TaskModel>> watchTasksByBranch(String branchId) => _tasks
      .where('branchId', isEqualTo: branchId)
      .snapshots()
      .map(_mapSnap);

  @override
  Stream<List<TaskModel>> watchEmployeeTasks(String employeeId) => _tasks
      .where('assigneeIds', arrayContains: employeeId)
      .snapshots()
      .map(_mapSnap);

  @override
  Stream<List<TaskModel>> watchShiftTasks({
    required String branchId,
    required ScheduleShift shift,
  }) =>
      _tasks
          .where('branchId', isEqualTo: branchId)
          .where('assignmentType', isEqualTo: 'shift')
          .where('shift', isEqualTo: shift.value)
          .snapshots()
          .map(_mapSnap);

  @override
  Future<TaskModel?> getTask(String taskId) async {
    try {
      final doc = await _tasks.doc(taskId).get();
      if (!doc.exists || doc.data() == null) return null;
      return TaskModel.fromMap(doc.data()!, id: doc.id);
    } on FirebaseException catch (e) {
      throw ServerException(e.message ?? 'Failed to load task.');
    }
  }

  @override
  Future<TaskModel> createTask(TaskModel task) async {
    try {
      final docRef = _tasks.doc();
      final created = task.copyWithId(docRef.id);
      await docRef.set({
        ...created.toMap(),
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return created;
    } on FirebaseException catch (e) {
      throw ServerException(e.message ?? 'Failed to create task.');
    }
  }

  @override
  Future<TaskModel?> createTaskWithId(TaskModel task) async {
    try {
      final docRef = _tasks.doc(task.id);
      // Atomic create-if-absent: the existence check and the write are one
      // transaction, so two concurrent callers (a reopen→re-approve replay, a
      // retried spawn, the Cloud Function racing the client materializer) all
      // converge on a single document instead of racing the old read-then-set.
      // Returns null when the deterministic id already exists (a benign no-op).
      final created = await _firestore.runTransaction<bool>((txn) async {
        final snap = await txn.get(docRef);
        if (snap.exists) return false;
        txn.set(docRef, {
          ...task.toMap(),
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
        return true;
      });
      return created ? task : null;
    } on FirebaseException catch (e) {
      throw ServerException(e.message ?? 'Failed to create task.');
    }
  }

  // Fields whose authority is the transactional transition path
  // ([transitionTask]). A plain content update (edit / checklist tick / work-data
  // patch) must NEVER write them from a possibly-stale client snapshot, or it
  // could clobber the activity log or regress a lifecycle field it never meant to
  // touch. Stripping them makes [updateTask] a pure content write; every
  // lifecycle move + log append goes through [transitionTask] instead.
  static const Set<String> _transitionOwnedFields = {
    'activityLog', 'version', 'status',
    'startedAt', 'submittedAt',
    'approvedBy', 'approvedAt', 'rejectedBy', 'rejectedAt',
    'reviewNotes', 'rejectionReason', 'revisionNumber', 'requiresRework',
    'archivedAt', 'missedAt',
    // Cancellation is a terminal decision recorded by the transition path; the
    // reason in particular is immutable (spec §5.5), so a content edit must
    // never carry it.
    'cancelledAt', 'cancelledBy', 'cancelReason', 'cancelNote',
    // An employee's open "this task is wrong" report — filed and cleared only
    // through the transition path, so an edit can neither forge nor erase one.
    'reportedIncorrectBy', 'reportedIncorrectAt', 'reportedIncorrectNote',
  };

  @override
  Future<void> updateTask(TaskModel task) async {
    try {
      final content = task.toMap()
        ..removeWhere((k, _) => _transitionOwnedFields.contains(k));
      await _tasks.doc(task.id).set({
        ...content,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } on FirebaseException catch (e) {
      throw ServerException(e.message ?? 'Failed to update task.');
    }
  }

  @override
  Future<void> transitionTask({
    required String taskId,
    required Set<String> expectedFrom,
    required Map<String, Object?> patch,
    required List<ActivityEntry> appendLog,
  }) async {
    try {
      await _firestore.runTransaction((txn) async {
        final ref = _tasks.doc(taskId);
        final snap = await txn.get(ref);
        if (!snap.exists || snap.data() == null) {
          throw const ConflictException(
              'This task no longer exists — it may have been removed.');
        }
        final data = snap.data()!;
        final status = data['status'] as String? ?? 'pending';
        if (expectedFrom.isNotEmpty && !expectedFrom.contains(status)) {
          // Someone changed the task between the client's read and this write.
          throw const ConflictException(
              'This task was just updated by someone else. It has been refreshed.');
        }
        // Append to the SERVER's current log (the fix for the lost-update race)
        // and bump the concurrency counter from the server's current value.
        final serverLog =
            (data['activityLog'] as List?)?.toList() ?? <dynamic>[];
        final version = (data['version'] as num?)?.toInt() ?? 0;
        txn.set(
          ref,
          {
            for (final e in patch.entries) e.key: _encodeTransitionValue(e.value),
            'activityLog': [
              ...serverLog,
              ...TaskModel.encodeActivityLog(appendLog),
            ],
            'version': version + 1,
            'updatedAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );
      });
    } on ConflictException {
      rethrow;
    } on FirebaseException catch (e) {
      throw ServerException(e.message ?? 'Failed to update task.');
    }
  }

  // Firestore can't store a raw DateTime; encode patch values on the boundary
  // (scalars pass through untouched, incl. an explicit null used to clear a
  // field like approvedBy on reopen).
  static Object? _encodeTransitionValue(Object? v) =>
      v is DateTime ? Timestamp.fromDate(v) : v;

  @override
  Future<void> deleteTask(String taskId) async {
    try {
      await _tasks.doc(taskId).delete();
    } on FirebaseException catch (e) {
      throw ServerException(e.message ?? 'Failed to delete task.');
    }
  }

  @override
  Future<void> assignTask({
    required String taskId,
    required List<String> employeeIds,
    String? assignedShiftId,
  }) async {
    try {
      await _tasks.doc(taskId).set({
        'assigneeIds': employeeIds,
        // Keep the legacy primary-assignee mirror in sync (rules / statistics).
        'assignedEmployeeId': employeeIds.isEmpty ? null : employeeIds.first,
        // Only touch the shift link when one is supplied (merge preserves it).
        'assignedShiftId': ?assignedShiftId,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } on FirebaseException catch (e) {
      throw ServerException(e.message ?? 'Failed to assign task.');
    }
  }

  @override
  Future<TaskAttachment> uploadAttachment({
    required String taskId,
    required File file,
    required AttachmentType type,
    required String uploadedBy,
    String? uploadedByName,
    int? durationMs,
    UploadCanceller? canceller,
    void Function(int transferred, int total)? onProgress,
  }) async {
    // The Storage mechanics (unique id → never overwritten, content-type,
    // cache-control, progress, timeout, error translation) live once in
    // [MediaUploadService]; this maps its result onto the task's attachment.
    final media = await _media.upload(
      basePath: '${AppConstants.tasksCollection}/$taskId/attachments',
      file: file,
      type: type,
      canceller: canceller,
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

  // ─── Task templates ────────────────────────────────────────────
  @override
  Future<List<TaskTemplateModel>> getTemplates() async {
    try {
      // Single-field order (auto-indexed). Branch scoping is applied
      // client-side in the cubit — template volume is tiny.
      final snap = await _templates.orderBy('title').get();
      return snap.docs
          .map((d) => TaskTemplateModel.fromMap(d.data(), id: d.id))
          .toList();
    } on FirebaseException catch (e) {
      throw ServerException(e.message ?? 'Failed to load task templates.');
    }
  }

  @override
  Future<TaskTemplateModel> createTemplate(TaskTemplateModel template) async {
    try {
      final docRef = _templates.doc();
      final created = template.copyWithId(docRef.id);
      await docRef.set({
        ...created.toMap(),
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return created;
    } on FirebaseException catch (e) {
      throw ServerException(e.message ?? 'Failed to save task template.');
    }
  }

  @override
  Future<void> deleteTemplate(String templateId) async {
    try {
      await _templates.doc(templateId).delete();
    } on FirebaseException catch (e) {
      throw ServerException(e.message ?? 'Failed to delete task template.');
    }
  }

  // ─── Recurring shift-task templates ────────────────────────────
  @override
  Future<List<RecurringTaskTemplateModel>> getRecurringTemplates(
      String branchId) async {
    try {
      final snap =
          await _recurringTemplates.where('branchId', isEqualTo: branchId).get();
      return snap.docs
          .map((d) => RecurringTaskTemplateModel.fromMap(d.data(), id: d.id))
          .toList();
    } on FirebaseException catch (e) {
      throw ServerException(
          e.message ?? 'Failed to load recurring shift-task templates.');
    }
  }

  @override
  Future<List<AutomationRunEntity>> getAutomationRuns(
    String templateId, {
    required String branchId,
    int limit = 20,
    DateTime? before,
  }) async {
    try {
      // `branchId` is filtered (not just `templateId`) because the rules gate a
      // manager's read on `branchId == selfBranch`; a list query must constrain
      // branchId or Firestore rejects it. Needs the
      // (branchId, templateId, startedAt desc) composite index.
      Query<Map<String, dynamic>> query = _automationRuns
          .where('branchId', isEqualTo: branchId)
          .where('templateId', isEqualTo: templateId)
          .orderBy('startedAt', descending: true);
      if (before != null) {
        query = query.startAfter([Timestamp.fromDate(before)]);
      }
      final snap = await query.limit(limit).get();
      return snap.docs
          .map((d) => AutomationRunModel.fromMap(d.data(), id: d.id))
          .toList();
    } on FirebaseException catch (e) {
      throw ServerException(e.message ?? 'Failed to load automation history.');
    }
  }

  @override
  Future<AutomationRunEntity?> getAutomationRunByCorrelationId(
    String correlationId, {
    required String branchId,
  }) async {
    try {
      final snap = await _automationRuns
          .where('branchId', isEqualTo: branchId)
          .where('correlationId', isEqualTo: correlationId)
          .limit(1)
          .get();
      if (snap.docs.isEmpty) return null;
      final d = snap.docs.first;
      return AutomationRunModel.fromMap(d.data(), id: d.id);
    } on FirebaseException catch (e) {
      throw ServerException(e.message ?? 'Failed to load the automation run.');
    }
  }

  @override
  Future<RecurringTaskTemplateModel> createRecurringTemplate(
      RecurringTaskTemplateModel template) async {
    try {
      final docRef = _recurringTemplates.doc();
      final created = template.copyWithId(docRef.id);
      await docRef.set({
        ...created.toMap(),
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return created;
    } on FirebaseException catch (e) {
      throw ServerException(
          e.message ?? 'Failed to save recurring shift-task template.');
    }
  }

  @override
  Future<void> updateRecurringTemplate(
      RecurringTaskTemplateModel template) async {
    try {
      await _recurringTemplates.doc(template.id).set({
        ...template.toMap(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } on FirebaseException catch (e) {
      throw ServerException(
          e.message ?? 'Failed to update recurring shift-task template.');
    }
  }

  @override
  Future<void> deleteRecurringTemplate(String templateId) async {
    try {
      await _recurringTemplates.doc(templateId).delete();
    } on FirebaseException catch (e) {
      throw ServerException(
          e.message ?? 'Failed to delete recurring shift-task template.');
    }
  }
}
