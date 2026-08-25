import 'dart:io';

import 'package:opshub/core/enums/attachment_type.dart';
import 'package:opshub/core/enums/schedule_shift.dart';
import 'package:opshub/core/media/media_upload_service.dart';
import 'package:opshub/core/errors/exceptions.dart';
import 'package:opshub/core/errors/failures.dart';
import 'package:opshub/core/network/network_guard.dart';
import 'package:opshub/features/task/data/datasources/task_remote_datasource.dart';
import 'package:opshub/features/task/data/models/recurring_task_template_model.dart';
import 'package:opshub/features/task/data/models/task_model.dart';
import 'package:opshub/features/task/data/models/task_template_model.dart';
import 'package:opshub/features/task/domain/entities/activity_entry.dart';
import 'package:opshub/features/task/domain/entities/automation_run_entity.dart';
import 'package:opshub/features/task/domain/entities/recurring_task_template_entity.dart';
import 'package:opshub/features/task/domain/entities/task_attachment.dart';
import 'package:opshub/features/task/domain/entities/task_entity.dart';
import 'package:opshub/features/task/domain/entities/task_template_entity.dart';
import 'package:opshub/features/task/domain/repositories/task_repository.dart';
import 'package:opshub/features/task/domain/task_ordering.dart';

class TaskRepositoryImpl implements TaskRepository {
  final TaskRemoteDataSource _remote;

  TaskRepositoryImpl(this._remote);

  /// Maps models → entities, drops archived (retention-swept) tasks, then orders
  /// newest-first (pending timestamps on top — see [sortTasksNewestFirst]).
  ///
  /// Archived tasks are still full records in `tasks` (soft archive), but they
  /// must never clutter an active list/feed — this is the single client-side
  /// gate that keeps them out of *every* stream + fetch. `getTask` deliberately
  /// bypasses this (deep-links to an archived task still resolve), and the
  /// statistics layer reads Firestore directly, so lifetime "completed" counts
  /// are unaffected. A future Archived view would use a dedicated unfiltered
  /// query rather than these active-list paths.
  List<TaskEntity> _newestFirst(List<TaskModel> models) => sortTasksNewestFirst(
        models
            .map((m) => m.toEntity())
            .where((t) => !t.isArchived)
            .toList(),
      );

  @override
  Future<List<TaskEntity>> getAllTasks() async {
    try {
      return _newestFirst(await _remote.getAllTasks());
    } on ServerException catch (e) {
      throw ServerFailure(e.message);
    }
  }

  @override
  Future<List<TaskEntity>> getTasksByBranch(String branchId) async {
    try {
      return _newestFirst(await _remote.getTasksByBranch(branchId));
    } on ServerException catch (e) {
      throw ServerFailure(e.message);
    }
  }

  @override
  Future<List<TaskEntity>> getEmployeeTasks(String employeeId) async {
    try {
      return _newestFirst(await _remote.getEmployeeTasks(employeeId));
    } on ServerException catch (e) {
      throw ServerFailure(e.message);
    }
  }

  @override
  Stream<List<TaskEntity>> watchAllTasks() =>
      _remote.watchAllTasks().map(_newestFirst);

  @override
  Stream<List<TaskEntity>> watchTasksByBranch(String branchId) =>
      _remote.watchTasksByBranch(branchId).map(_newestFirst);

  @override
  Stream<List<TaskEntity>> watchEmployeeTasks(String employeeId) =>
      _remote.watchEmployeeTasks(employeeId).map(_newestFirst);

  @override
  Stream<List<TaskEntity>> watchShiftTasks({
    required String branchId,
    required ScheduleShift shift,
  }) =>
      _remote
          .watchShiftTasks(branchId: branchId, shift: shift)
          .map(_newestFirst);

  @override
  Future<TaskEntity?> getTask(String taskId) async {
    try {
      final model = await _remote.getTask(taskId);
      return model?.toEntity();
    } on ServerException catch (e) {
      throw ServerFailure(e.message);
    }
  }

  @override
  Future<TaskEntity> createTask(TaskEntity task) async {
    NetworkGuard.ensureWritable();
    try {
      final created = await _remote.createTask(TaskModel.fromEntity(task));
      return created.toEntity();
    } on ServerException catch (e) {
      throw ServerFailure(e.message);
    }
  }

  @override
  Future<TaskEntity?> createTaskWithId(TaskEntity task) async {
    NetworkGuard.ensureWritable();
    try {
      final created = await _remote.createTaskWithId(TaskModel.fromEntity(task));
      return created?.toEntity();
    } on ServerException catch (e) {
      throw ServerFailure(e.message);
    }
  }

  @override
  Future<void> updateTask(TaskEntity task) async {
    NetworkGuard.ensureWritable();
    try {
      await _remote.updateTask(TaskModel.fromEntity(task));
    } on ServerException catch (e) {
      throw ServerFailure(e.message);
    }
  }

  @override
  Future<void> transitionTask({
    required String taskId,
    required Set<String> expectedFrom,
    required Map<String, Object?> patch,
    required List<ActivityEntry> appendLog,
  }) async {
    NetworkGuard.ensureWritable();
    try {
      await _remote.transitionTask(
        taskId: taskId,
        expectedFrom: expectedFrom,
        patch: patch,
        appendLog: appendLog,
      );
    } on ConflictException catch (e) {
      throw ConflictFailure(e.message);
    } on ServerException catch (e) {
      throw ServerFailure(e.message);
    }
  }

  @override
  Future<void> deleteTask(String taskId) async {
    NetworkGuard.ensureWritable();
    try {
      await _remote.deleteTask(taskId);
    } on ServerException catch (e) {
      throw ServerFailure(e.message);
    }
  }

  @override
  Future<void> assignTask({
    required String taskId,
    required List<String> employeeIds,
    String? assignedShiftId,
  }) async {
    NetworkGuard.ensureWritable();
    try {
      await _remote.assignTask(
        taskId: taskId,
        employeeIds: employeeIds,
        assignedShiftId: assignedShiftId,
      );
    } on ServerException catch (e) {
      throw ServerFailure(e.message);
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
    try {
      return await _remote.uploadAttachment(
        taskId: taskId,
        file: file,
        type: type,
        uploadedBy: uploadedBy,
        uploadedByName: uploadedByName,
        durationMs: durationMs,
        canceller: canceller,
        onProgress: onProgress,
      );
    } on ServerException catch (e) {
      throw ServerFailure(e.message);
    }
    // UploadCancelledException is intentionally NOT caught here — it isn't a
    // failure; it propagates to the cubit which restores the UI quietly.
  }

  // ─── Task templates ────────────────────────────────────────────
  // In-memory cache of the (tiny) template collection — read repeatedly when the
  // New-Task sheets open. Templates are global + change rarely, so a 20-minute
  // TTL + invalidate-on-write keeps the sheets off Firestore without staleness.
  static const _templatesTtl = Duration(minutes: 20);
  List<TaskTemplateEntity>? _cachedTemplates;
  DateTime? _templatesFetchedAt;

  bool get _templatesFresh =>
      _cachedTemplates != null &&
      _templatesFetchedAt != null &&
      DateTime.now().difference(_templatesFetchedAt!) < _templatesTtl;

  @override
  Future<List<TaskTemplateEntity>> getTemplates({
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh && _templatesFresh) return _cachedTemplates!;
    try {
      final models = await _remote.getTemplates();
      final list = models.map((m) => m.toEntity()).toList();
      _cachedTemplates = list;
      _templatesFetchedAt = DateTime.now();
      return list;
    } on ServerException catch (e) {
      throw ServerFailure(e.message);
    }
  }

  void _invalidateTemplates() {
    _cachedTemplates = null;
    _templatesFetchedAt = null;
  }

  @override
  Future<TaskTemplateEntity> createTemplate(TaskTemplateEntity template) async {
    NetworkGuard.ensureWritable();
    try {
      final created =
          await _remote.createTemplate(TaskTemplateModel.fromEntity(template));
      _invalidateTemplates();
      return created.toEntity();
    } on ServerException catch (e) {
      throw ServerFailure(e.message);
    }
  }

  @override
  Future<void> deleteTemplate(String templateId) async {
    NetworkGuard.ensureWritable();
    try {
      await _remote.deleteTemplate(templateId);
      _invalidateTemplates();
    } on ServerException catch (e) {
      throw ServerFailure(e.message);
    }
  }

  // ─── Recurring shift-task templates ────────────────────────────
  @override
  Future<List<RecurringTaskTemplateEntity>> getRecurringTemplates(
      String branchId) async {
    try {
      final models = await _remote.getRecurringTemplates(branchId);
      return models.map((m) => m.toEntity()).toList();
    } on ServerException catch (e) {
      throw ServerFailure(e.message);
    }
  }

  @override
  Future<RecurringTaskTemplateEntity> createRecurringTemplate(
      RecurringTaskTemplateEntity template) async {
    NetworkGuard.ensureWritable();
    try {
      final created = await _remote.createRecurringTemplate(
          RecurringTaskTemplateModel.fromEntity(template));
      return created.toEntity();
    } on ServerException catch (e) {
      throw ServerFailure(e.message);
    }
  }

  @override
  Future<void> updateRecurringTemplate(
      RecurringTaskTemplateEntity template) async {
    NetworkGuard.ensureWritable();
    try {
      await _remote.updateRecurringTemplate(
          RecurringTaskTemplateModel.fromEntity(template));
    } on ServerException catch (e) {
      throw ServerFailure(e.message);
    }
  }

  @override
  Future<void> deleteRecurringTemplate(String templateId) async {
    NetworkGuard.ensureWritable();
    try {
      await _remote.deleteRecurringTemplate(templateId);
    } on ServerException catch (e) {
      throw ServerFailure(e.message);
    }
  }

  // ─── Automation execution history (observability, ADR-011) ─────
  @override
  Future<List<AutomationRunEntity>> getAutomationRuns(
    String templateId, {
    required String branchId,
    int limit = 20,
    DateTime? before,
  }) async {
    try {
      return await _remote.getAutomationRuns(
        templateId,
        branchId: branchId,
        limit: limit,
        before: before,
      );
    } on ServerException catch (e) {
      throw ServerFailure(e.message);
    }
  }

  @override
  Future<AutomationRunEntity?> getAutomationRunByCorrelationId(
    String correlationId, {
    required String branchId,
  }) async {
    try {
      return await _remote.getAutomationRunByCorrelationId(
        correlationId,
        branchId: branchId,
      );
    } on ServerException catch (e) {
      throw ServerFailure(e.message);
    }
  }
}
