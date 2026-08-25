import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:opshub/core/extensions/firestore_extensions.dart';
import 'package:opshub/core/enums/attachment_type.dart';
import 'package:opshub/core/enums/recurrence_frequency.dart';
import 'package:opshub/core/enums/schedule_shift.dart';
import 'package:opshub/core/enums/task_assignment_type.dart';
import 'package:opshub/core/enums/task_cancel_reason.dart';
import 'package:opshub/core/enums/task_type.dart';
import 'package:opshub/core/enums/task_status.dart';
import 'package:opshub/core/enums/task_priority.dart';
import 'package:opshub/features/task/domain/entities/activity_entry.dart';
import 'package:opshub/features/task/domain/entities/checklist_item.dart';
import 'package:opshub/features/task/domain/entities/recurrence_config.dart';
import 'package:opshub/features/task/domain/entities/task_attachment.dart';
import 'package:opshub/features/task/domain/entities/task_entity.dart';

/// Firestore (de)serialization for [TaskEntity] — collection `tasks/{taskId}`.
///
/// Multi-assignee (Phase 9): the canonical field is `assigneeIds` (array). For
/// backward compatibility with the legacy single-assignee schema, [fromMap]
/// falls back to a `assignedEmployeeId` string when no array is present, and
/// [toMap] keeps `assignedEmployeeId` in sync as the **primary** assignee
/// (first id, or null) so existing Firestore rules / statistics queries that
/// key off it keep working without a migration.
class TaskModel {
  final String id;
  final String title;
  final String? description;
  final TaskType type;
  final String workType;
  final TaskStatus status;
  final TaskPriority priority;
  final String? branchId;
  final List<String> assigneeIds;
  final List<ChecklistItem> checklist;
  final List<TaskAttachment> referenceAttachments;
  final Map<String, dynamic> data;
  final String? createdBy;
  final String? assignedShiftId;
  final ScheduleShift? shift;
  final TaskAssignmentType assignmentType;
  final DateTime? instanceDate;
  final String? sourceTemplateId;
  final String? recurrenceRootId;
  final String? occurrenceKey;
  final String? correlationId;
  final DateTime? startsAt;
  final DateTime? deadline;
  final DateTime? missedAt;
  final DateTime? cancelledAt;
  final String? cancelledBy;
  final TaskCancelReason? cancelReason;
  final String? cancelNote;
  final String? reportedIncorrectBy;
  final DateTime? reportedIncorrectAt;
  final String? reportedIncorrectNote;
  final String? notes;
  final String? proofImageUrl;
  final DateTime? startedAt;
  final DateTime? submittedAt;
  final String? approvedBy;
  final DateTime? approvedAt;
  final String? rejectedBy;
  final DateTime? rejectedAt;
  final String? reviewNotes;
  final int revisionNumber;
  final bool requiresRework;
  final String? rejectionReason;
  final RecurrenceConfig? recurrence;
  final List<ActivityEntry> activityLog;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? archivedAt;
  final int version;

  const TaskModel({
    required this.id,
    required this.title,
    this.description,
    this.type = TaskType.daily,
    this.workType = 'general',
    this.status = TaskStatus.pending,
    this.priority = TaskPriority.normal,
    this.branchId,
    this.assigneeIds = const [],
    this.checklist = const [],
    this.referenceAttachments = const [],
    this.data = const {},
    this.createdBy,
    this.assignedShiftId,
    this.shift,
    this.assignmentType = TaskAssignmentType.individual,
    this.instanceDate,
    this.sourceTemplateId,
    this.recurrenceRootId,
    this.occurrenceKey,
    this.correlationId,
    this.startsAt,
    this.deadline,
    this.missedAt,
    this.cancelledAt,
    this.cancelledBy,
    this.cancelReason,
    this.cancelNote,
    this.reportedIncorrectBy,
    this.reportedIncorrectAt,
    this.reportedIncorrectNote,
    this.notes,
    this.proofImageUrl,
    this.startedAt,
    this.submittedAt,
    this.approvedBy,
    this.approvedAt,
    this.rejectedBy,
    this.rejectedAt,
    this.reviewNotes,
    this.revisionNumber = 0,
    this.requiresRework = false,
    this.rejectionReason,
    this.recurrence,
    this.activityLog = const [],
    this.createdAt,
    this.updatedAt,
    this.archivedAt,
    this.version = 0,
  });

  factory TaskModel.fromMap(Map<String, dynamic> map, {String? id}) => TaskModel(
        id: id ?? map['id'] as String? ?? '',
        title: map['title'] as String? ?? '',
        description: map['description'] as String?,
        type: TaskType.fromString(map['type'] as String?),
        workType: (map['workType'] as String?) ?? 'general',
        status: TaskStatus.fromString(map['status'] as String?),
        priority: TaskPriority.fromString(map['priority'] as String?),
        branchId: map['branchId'] as String?,
        assigneeIds: _assigneesFromMap(map),
        checklist: _checklistFromList(map['checklist']),
        referenceAttachments: _attachmentsFromList(map['referenceAttachments']),
        data: _dataFromMap(map['data']),
        createdBy: map['createdBy'] as String?,
        assignedShiftId: map['assignedShiftId'] as String?,
        shift: ScheduleShift.fromStringOrNull(map['shift'] as String?),
        assignmentType: TaskAssignmentType.fromString(map['assignmentType'] as String?),
        instanceDate: map.date('instanceDate'),
        sourceTemplateId: map['sourceTemplateId'] as String?,
        recurrenceRootId: map['recurrenceRootId'] as String?,
        occurrenceKey: map['occurrenceKey'] as String?,
        correlationId: map['correlationId'] as String?,
        startsAt: map.date('startsAt'),
        deadline: map.date('deadline'),
        missedAt: map.date('missedAt'),
        cancelledAt: map.date('cancelledAt'),
        cancelledBy: map['cancelledBy'] as String?,
        cancelReason: TaskCancelReason.fromString(map['cancelReason'] as String?),
        cancelNote: map['cancelNote'] as String?,
        reportedIncorrectBy: map['reportedIncorrectBy'] as String?,
        reportedIncorrectAt: map.date('reportedIncorrectAt'),
        reportedIncorrectNote: map['reportedIncorrectNote'] as String?,
        notes: map['notes'] as String?,
        proofImageUrl: map['proofImageUrl'] as String?,
        startedAt: map.date('startedAt'),
        submittedAt: map.date('submittedAt'),
        approvedBy: map['approvedBy'] as String?,
        approvedAt: map.date('approvedAt'),
        rejectedBy: map['rejectedBy'] as String?,
        rejectedAt: map.date('rejectedAt'),
        reviewNotes: map['reviewNotes'] as String?,
        revisionNumber: (map['revisionNumber'] as num?)?.toInt() ?? 0,
        requiresRework: map['requiresRework'] as bool? ?? false,
        rejectionReason: map['rejectionReason'] as String?,
        recurrence: _recurrenceFromMap(map['recurrence']),
        activityLog: _activityLogFromList(map['activityLog']),
        createdAt: map.date('createdAt'),
        updatedAt: map.date('updatedAt'),
        archivedAt: map.date('archivedAt'),
        version: (map['version'] as num?)?.toInt() ?? 0,
      );

  factory TaskModel.fromEntity(TaskEntity e) => TaskModel(
        id: e.id,
        title: e.title,
        description: e.description,
        type: e.type,
        workType: e.workType,
        status: e.status,
        priority: e.priority,
        branchId: e.branchId,
        assigneeIds: e.assigneeIds,
        checklist: e.checklist,
        referenceAttachments: e.referenceAttachments,
        data: e.data,
        createdBy: e.createdBy,
        assignedShiftId: e.assignedShiftId,
        shift: e.shift,
        assignmentType: e.assignmentType,
        instanceDate: e.instanceDate,
        sourceTemplateId: e.sourceTemplateId,
        recurrenceRootId: e.recurrenceRootId,
        occurrenceKey: e.occurrenceKey,
        correlationId: e.correlationId,
        startsAt: e.startsAt,
        deadline: e.deadline,
        missedAt: e.missedAt,
        cancelledAt: e.cancelledAt,
        cancelledBy: e.cancelledBy,
        cancelReason: e.cancelReason,
        cancelNote: e.cancelNote,
        reportedIncorrectBy: e.reportedIncorrectBy,
        reportedIncorrectAt: e.reportedIncorrectAt,
        reportedIncorrectNote: e.reportedIncorrectNote,
        notes: e.notes,
        proofImageUrl: e.proofImageUrl,
        startedAt: e.startedAt,
        submittedAt: e.submittedAt,
        approvedBy: e.approvedBy,
        approvedAt: e.approvedAt,
        rejectedBy: e.rejectedBy,
        rejectedAt: e.rejectedAt,
        reviewNotes: e.reviewNotes,
        revisionNumber: e.revisionNumber,
        requiresRework: e.requiresRework,
        rejectionReason: e.rejectionReason,
        recurrence: e.recurrence,
        activityLog: e.activityLog,
        createdAt: e.createdAt,
        updatedAt: e.updatedAt,
        archivedAt: e.archivedAt,
        version: e.version,
      );

  /// Persisted fields. `createdAt`/`updatedAt` are written by the datasource as
  /// server timestamps, so they are intentionally not included here. `version`
  /// is likewise omitted — it is owned by the transactional transition path
  /// (`transitionTask`), so a plain write can never regress it. `deadline`
  /// is converted to a [Timestamp] when present. `assignedEmployeeId` mirrors
  /// the primary assignee for backward compatibility (rules / statistics).
  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        'description': description,
        'type': type.value,
        'workType': workType,
        'status': status.value,
        'priority': priority.value,
        'branchId': branchId,
        'assigneeIds': assigneeIds,
        'assignedEmployeeId': assigneeIds.isEmpty ? null : assigneeIds.first,
        'checklist': _checklistToList(checklist),
        'referenceAttachments': _attachmentsToList(referenceAttachments),
        'data': _dataToMap(data),
        'createdBy': createdBy,
        'assignedShiftId': assignedShiftId,
        'shift': shift?.value,
        'assignmentType': assignmentType.value,
        'instanceDate': instanceDate == null ? null : Timestamp.fromDate(instanceDate!),
        'sourceTemplateId': sourceTemplateId,
        'recurrenceRootId': recurrenceRootId,
        'occurrenceKey': occurrenceKey,
        'correlationId': correlationId,
        'startsAt': startsAt == null ? null : Timestamp.fromDate(startsAt!),
        'deadline': deadline == null ? null : Timestamp.fromDate(deadline!),
        // Server-owned terminal timestamp. Included as null for a newly-created
        // task, but stripped from ordinary client content edits so a stale task
        // snapshot can never clear an automation-recorded missed outcome.
        'missedAt': missedAt == null ? null : Timestamp.fromDate(missedAt!),
        // Terminal cancellation evidence. Like `missedAt`, these are owned by
        // the transactional transition path and stripped from ordinary content
        // edits, so a stale snapshot can never erase a recorded cancellation or
        // rewrite its reason (the reason is immutable — spec §5.5).
        'cancelledAt':
            cancelledAt == null ? null : Timestamp.fromDate(cancelledAt!),
        'cancelledBy': cancelledBy,
        'cancelReason': cancelReason?.value,
        'cancelNote': cancelNote,
        // An open "this task is wrong" report. Transition-owned like the
        // cancellation record: an employee files it and a manager clears it, so
        // a routine content edit must never carry (or silently drop) it.
        'reportedIncorrectBy': reportedIncorrectBy,
        'reportedIncorrectAt': reportedIncorrectAt == null
            ? null
            : Timestamp.fromDate(reportedIncorrectAt!),
        'reportedIncorrectNote': reportedIncorrectNote,
        'notes': notes,
        'proofImageUrl': proofImageUrl,
        'startedAt': startedAt == null ? null : Timestamp.fromDate(startedAt!),
        'submittedAt': submittedAt == null ? null : Timestamp.fromDate(submittedAt!),
        'approvedBy': approvedBy,
        'approvedAt': approvedAt == null ? null : Timestamp.fromDate(approvedAt!),
        'rejectedBy': rejectedBy,
        'rejectedAt': rejectedAt == null ? null : Timestamp.fromDate(rejectedAt!),
        'reviewNotes': reviewNotes,
        'revisionNumber': revisionNumber,
        'requiresRework': requiresRework,
        'rejectionReason': rejectionReason,
        'recurrence': _recurrenceToMap(recurrence),
        'activityLog': _activityLogToList(activityLog),
        // Server-managed by `taskHousekeeping`, but written here so an admin
        // REOPEN (which passes `archivedAt: null`) un-archives the task. For a
        // live task this is always null (no-op); the function is the only other
        // writer, and archived tasks are filtered out of every client stream, so
        // a client write can't race-clobber a fresh archive stamp.
        'archivedAt': archivedAt == null ? null : Timestamp.fromDate(archivedAt!),
      };

  /// Returns a copy with the Firestore-generated [id] applied (used on create).
  TaskModel copyWithId(String id) => TaskModel(
        id: id,
        title: title,
        description: description,
        type: type,
        workType: workType,
        status: status,
        priority: priority,
        branchId: branchId,
        assigneeIds: assigneeIds,
        checklist: checklist,
        referenceAttachments: referenceAttachments,
        data: data,
        createdBy: createdBy,
        assignedShiftId: assignedShiftId,
        shift: shift,
        assignmentType: assignmentType,
        instanceDate: instanceDate,
        sourceTemplateId: sourceTemplateId,
        recurrenceRootId: recurrenceRootId,
        occurrenceKey: occurrenceKey,
        correlationId: correlationId,
        startsAt: startsAt,
        deadline: deadline,
        missedAt: missedAt,
        cancelledAt: cancelledAt,
        cancelledBy: cancelledBy,
        cancelReason: cancelReason,
        cancelNote: cancelNote,
        reportedIncorrectBy: reportedIncorrectBy,
        reportedIncorrectAt: reportedIncorrectAt,
        reportedIncorrectNote: reportedIncorrectNote,
        notes: notes,
        proofImageUrl: proofImageUrl,
        startedAt: startedAt,
        submittedAt: submittedAt,
        approvedBy: approvedBy,
        approvedAt: approvedAt,
        rejectedBy: rejectedBy,
        rejectedAt: rejectedAt,
        reviewNotes: reviewNotes,
        revisionNumber: revisionNumber,
        requiresRework: requiresRework,
        rejectionReason: rejectionReason,
        recurrence: recurrence,
        activityLog: activityLog,
        createdAt: createdAt,
        updatedAt: updatedAt,
        archivedAt: archivedAt,
        version: version,
      );

  TaskEntity toEntity() => TaskEntity(
        id: id,
        title: title,
        description: description,
        type: type,
        workType: workType,
        status: status,
        priority: priority,
        branchId: branchId,
        assigneeIds: assigneeIds,
        checklist: checklist,
        referenceAttachments: referenceAttachments,
        data: data,
        createdBy: createdBy,
        assignedShiftId: assignedShiftId,
        shift: shift,
        assignmentType: assignmentType,
        instanceDate: instanceDate,
        sourceTemplateId: sourceTemplateId,
        recurrenceRootId: recurrenceRootId,
        occurrenceKey: occurrenceKey,
        correlationId: correlationId,
        startsAt: startsAt,
        deadline: deadline,
        missedAt: missedAt,
        cancelledAt: cancelledAt,
        cancelledBy: cancelledBy,
        cancelReason: cancelReason,
        cancelNote: cancelNote,
        reportedIncorrectBy: reportedIncorrectBy,
        reportedIncorrectAt: reportedIncorrectAt,
        reportedIncorrectNote: reportedIncorrectNote,
        notes: notes,
        proofImageUrl: proofImageUrl,
        startedAt: startedAt,
        submittedAt: submittedAt,
        approvedBy: approvedBy,
        approvedAt: approvedAt,
        rejectedBy: rejectedBy,
        rejectedAt: rejectedAt,
        reviewNotes: reviewNotes,
        revisionNumber: revisionNumber,
        requiresRework: requiresRework,
        rejectionReason: rejectionReason,
        recurrence: recurrence,
        activityLog: activityLog,
        createdAt: createdAt,
        updatedAt: updatedAt,
        archivedAt: archivedAt,
        version: version,
      );

  /// Serializes activity entries to their Firestore map form — the single
  /// encoder, reused by the transactional transition path (which appends to the
  /// server's current log outside `toMap`). Public so the datasource can encode
  /// the entries it appends without duplicating the shape.
  static List<Map<String, dynamic>> encodeActivityLog(
          List<ActivityEntry> log) =>
      _activityLogToList(log);

  /// Reads `assigneeIds` (array); falls back to the legacy single
  /// `assignedEmployeeId` string for documents written before Phase 9.
  static List<String> _assigneesFromMap(Map<String, dynamic> map) {
    final raw = map['assigneeIds'];
    if (raw is List) {
      final ids = raw.whereType<String>().where((s) => s.isNotEmpty).toList();
      if (ids.isNotEmpty) return ids;
    }
    final legacy = map['assignedEmployeeId'] as String?;
    return (legacy != null && legacy.isNotEmpty) ? [legacy] : const [];
  }

  static List<ChecklistItem> _checklistFromList(dynamic raw) {
    if (raw is! List) return const [];
    final items = <ChecklistItem>[];
    for (final e in raw) {
      if (e is Map) {
        final title = e['title'] as String? ?? '';
        if (title.isEmpty) continue;
        items.add(ChecklistItem(
          id: e['id'] as String? ?? '',
          title: title,
          isRequired: e['isRequired'] as bool? ?? true,
          completed: e['completed'] as bool? ?? false,
          completedAt: (e['completedAt'] as Timestamp?)?.toDate(),
        ));
      }
    }
    return items;
  }

  static List<Map<String, dynamic>> _checklistToList(List<ChecklistItem> items) =>
      [
        for (final i in items)
          {
            'id': i.id,
            'title': i.title,
            'isRequired': i.isRequired,
            'completed': i.completed,
            'completedAt':
                i.completedAt == null ? null : Timestamp.fromDate(i.completedAt!),
          },
      ];

  static RecurrenceConfig? _recurrenceFromMap(dynamic raw) {
    if (raw is! Map) return null;
    return RecurrenceConfig(
      frequency: RecurrenceFrequency.fromString(raw['frequency'] as String?),
      interval: (raw['interval'] as int?) ?? 1,
      weekday: (raw['weekday'] as int?) ?? 1,
      hour: (raw['hour'] as int?) ?? 9,
      minute: (raw['minute'] as int?) ?? 0,
    );
  }

  static Map<String, dynamic>? _recurrenceToMap(RecurrenceConfig? r) {
    if (r == null) return null;
    return {
      'frequency': r.frequency.value,
      'interval': r.interval,
      'weekday': r.weekday,
      'hour': r.hour,
      'minute': r.minute,
    };
  }

  static List<ActivityEntry> _activityLogFromList(dynamic raw) {
    if (raw is! List) return const [];
    final result = <ActivityEntry>[];
    for (final e in raw) {
      if (e is Map) {
        final at = (e['at'] as Timestamp?)?.toDate();
        if (at == null) continue;
        result.add(ActivityEntry(
          status: e['status'] as String? ?? '',
          actorId: e['actorId'] as String? ?? '',
          actorName: e['actorName'] as String?,
          at: at,
          note: e['note'] as String?,
          attachments: _attachmentsFromList(e['attachments']),
        ));
      }
    }
    return result;
  }

  static List<Map<String, dynamic>> _activityLogToList(
          List<ActivityEntry> log) =>
      [
        for (final e in log)
          {
            'status': e.status,
            'actorId': e.actorId,
            'actorName': e.actorName,
            'at': Timestamp.fromDate(e.at),
            'note': e.note,
            'attachments': _attachmentsToList(e.attachments),
          },
      ];

  /// Reads the dynamic work-type [TaskEntity.data] map, converting persisted
  /// [Timestamp]s back to [DateTime] so date/time fields stay strongly typed in
  /// the domain. Non-map input → empty (back-compat for pre-work-type docs).
  static Map<String, dynamic> _dataFromMap(dynamic raw) {
    if (raw is! Map) return const {};
    return {
      for (final entry in raw.entries)
        entry.key.toString(): _decodeValue(entry.value),
    };
  }

  static dynamic _decodeValue(dynamic v) {
    if (v is Timestamp) return v.toDate();
    if (v is Map) {
      return {
        for (final e in v.entries) e.key.toString(): _decodeValue(e.value),
      };
    }
    if (v is List) return v.map(_decodeValue).toList();
    return v;
  }

  /// Writes the dynamic work-type [TaskEntity.data] map, converting [DateTime]s
  /// to [Timestamp] (Firestore cannot store a raw `DateTime`). Recurses into
  /// nested maps/lists (e.g. an inspection's per-point results map).
  static Map<String, dynamic> _dataToMap(Map<String, dynamic> data) => {
        for (final entry in data.entries) entry.key: _encodeValue(entry.value),
      };

  static dynamic _encodeValue(dynamic v) {
    if (v is DateTime) return Timestamp.fromDate(v);
    if (v is Map) {
      return {
        for (final e in v.entries) e.key.toString(): _encodeValue(e.value),
      };
    }
    if (v is List) return v.map(_encodeValue).toList();
    return v;
  }

  static List<TaskAttachment> _attachmentsFromList(dynamic raw) {
    if (raw is! List) return const [];
    final result = <TaskAttachment>[];
    for (final a in raw) {
      if (a is Map) {
        final url = a['url'] as String? ?? '';
        if (url.isEmpty) continue;
        result.add(TaskAttachment(
          id: a['id'] as String? ?? '',
          url: url,
          type: AttachmentType.fromString(a['type'] as String?),
          uploadedAt:
              (a['uploadedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
          uploadedBy: a['uploadedBy'] as String? ?? '',
          uploadedByName: a['uploadedByName'] as String?,
          durationMs: (a['durationMs'] as num?)?.toInt(),
        ));
      }
    }
    return result;
  }

  static List<Map<String, dynamic>> _attachmentsToList(
          List<TaskAttachment> items) =>
      [
        for (final a in items)
          {
            'id': a.id,
            'url': a.url,
            'type': a.type.value,
            'uploadedAt': Timestamp.fromDate(a.uploadedAt),
            'uploadedBy': a.uploadedBy,
            'uploadedByName': a.uploadedByName,
            'durationMs': a.durationMs,
          },
      ];
}
