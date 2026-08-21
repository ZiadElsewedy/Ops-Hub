import 'package:opshub/core/enums/schedule_shift.dart';

/// Outcome status of one automation execution (the coarse verdict).
enum AutomationRunStatus {
  completed,
  skipped,
  failed,
  unknown;

  static AutomationRunStatus fromString(String? raw) => switch (raw) {
        'completed' => AutomationRunStatus.completed,
        'skipped' => AutomationRunStatus.skipped,
        'failed' => AutomationRunStatus.failed,
        _ => AutomationRunStatus.unknown,
      };
}

/// The specific reason for the [AutomationRunStatus] (the fine-grained verdict).
enum AutomationRunOutcome {
  created,
  alreadyExists,
  noEligibleEmployees,
  error,
  unknown;

  static AutomationRunOutcome fromString(String? raw) => switch (raw) {
        'created' => AutomationRunOutcome.created,
        'alreadyExists' => AutomationRunOutcome.alreadyExists,
        'noEligibleEmployees' => AutomationRunOutcome.noEligibleEmployees,
        'error' => AutomationRunOutcome.error,
        _ => AutomationRunOutcome.unknown,
      };
}

/// Result of one validation step (`pass` / `fail` / `skipped`). `skipped` means
/// an earlier stage short-circuited before this check could run — distinct from
/// a check that ran and failed.
enum ValidationResult {
  pass,
  fail,
  skipped,
  unknown;

  static ValidationResult fromString(String? raw) => switch (raw) {
        'pass' => ValidationResult.pass,
        'fail' => ValidationResult.fail,
        'skipped' => ValidationResult.skipped,
        _ => ValidationResult.unknown,
      };
}

/// Severity of one execution-log step.
enum LogSeverity {
  info,
  warning,
  error;

  static LogSeverity fromString(String? raw) => switch (raw) {
        'warning' => LogSeverity.warning,
        'error' => LogSeverity.error,
        _ => LogSeverity.info,
      };
}

/// One named validation check on a run.
class AutomationRunValidation {
  const AutomationRunValidation({required this.name, required this.result});

  final String name;
  final ValidationResult result;
}

/// Which employees the run targeted. [matched] is stored explicitly so "nobody
/// matched" is a first-class recorded fact, not an empty list to be guessed at.
class AutomationRunTarget {
  const AutomationRunTarget({
    this.uids = const [],
    this.names = const [],
    this.count = 0,
    this.matched = false,
  });

  final List<String> uids;
  final List<String> names;
  final int count;
  final bool matched;
}

/// What the run generated.
class AutomationRunGeneration {
  const AutomationRunGeneration({
    this.templateVersion = 1,
    this.checklistCount = 0,
    this.priority = 'normal',
    this.taskIds = const [],
    this.taskTitles = const [],
    this.skippedCount = 0,
  });

  final int templateVersion;
  final int checklistCount;
  final String priority;
  final List<String> taskIds;
  final List<String> taskTitles;
  final int skippedCount;
}

/// Notification delivery for the run.
class AutomationRunNotification {
  const AutomationRunNotification({
    this.sent = 0,
    this.failed = 0,
    this.notificationIds = const [],
  });

  final int sent;
  final int failed;
  final List<String> notificationIds;
}

/// Structured error for a failed (or recovered) run. [recovered] marks a failure
/// the run continued past (e.g. notify failed but the task was still created).
class AutomationRunError {
  const AutomationRunError({
    required this.stage,
    this.code,
    required this.message,
    this.retryable = false,
    this.recovered = false,
  });

  final String stage;
  final Object? code;
  final String message;
  final bool retryable;
  final bool recovered;
}

/// One chronological execution-log step.
class AutomationRunLogEntry {
  const AutomationRunLogEntry({
    required this.at,
    required this.stage,
    required this.severity,
    required this.message,
    this.meta,
  });

  final DateTime? at;
  final String stage;
  final LogSeverity severity;
  final String message;
  final Map<String, dynamic>? meta;
}

/// One recipient as captured at execution time — lightweight and immutable, so
/// an old run stays accurate even if the employee later leaves, is renamed, or
/// changes branch/shift. Never a full user document.
class RecipientSnapshot {
  const RecipientSnapshot({
    required this.uid,
    this.displayName = '',
    this.role,
    this.assignedShift,
  });

  final String uid;
  final String displayName;
  final String? role;
  final ScheduleShift? assignedShift;
}

/// The immutable **execution snapshot** embedded in a run — exactly what existed
/// at execution time (definition identity/version, task blueprint, schedule,
/// branch id+name, and lightweight recipients). Read this — never the live
/// definition — when displaying a past run, so history never changes when
/// templates, branches, employees, schedules, or checklists change.
class AutomationRunSnapshot {
  const AutomationRunSnapshot({
    this.automationId = '',
    this.automationName = '',
    this.automationVersion = 1,
    this.templateId = '',
    this.templateName = '',
    this.templateVersion = 1,
    this.checklistCount = 0,
    this.priority = 'normal',
    this.proofRequired = false,
    this.scheduleType = 'daily',
    this.days = const [],
    this.shift,
    this.timezone = 'UTC',
    this.branchId = '',
    this.branchName,
    this.recipients = const [],
    this.recipientCount = 0,
  });

  // Automation + template identity (immutable at run time)
  final String automationId;
  final String automationName;
  final int automationVersion;
  final String templateId;
  final String templateName;
  final int templateVersion;
  final int checklistCount;
  final String priority;
  final bool proofRequired;

  // Schedule
  final String scheduleType;
  final List<String> days;
  final ScheduleShift? shift;
  final String timezone;

  // Target + recipients
  final String branchId;
  final String? branchName;
  final List<RecipientSnapshot> recipients;
  final int recipientCount;
}

/// A single automation **execution** — distinct from the automation definition
/// (`RecurringTaskTemplateEntity`). Read-only observability written by the
/// `generateShiftTaskInstances` Cloud Function (ADR-011); the client never
/// writes it. Answers, for one run: did it execute, when, why, who was targeted,
/// what was generated/notified, what was validated, and where it failed.
class AutomationRunEntity {
  const AutomationRunEntity({
    required this.id,
    required this.templateId,
    this.automationName = '',
    this.version = 1,
    this.branchId = '',
    this.dateKey = '',
    this.executionId = '',
    this.correlationId = '',
    this.startedAt,
    this.finishedAt,
    this.durationMs = 0,
    this.trigger = 'schedule',
    this.retryCount = 0,
    this.status = AutomationRunStatus.unknown,
    this.outcome = AutomationRunOutcome.unknown,
    this.scheduledAt,
    this.actualAt,
    this.delayMs = 0,
    this.shift,
    this.day = '',
    this.validations = const [],
    this.target = const AutomationRunTarget(),
    this.generation = const AutomationRunGeneration(),
    this.notification = const AutomationRunNotification(),
    this.error,
    this.logs = const [],
    this.snapshot,
  });

  // Identity
  final String id;
  final String templateId;
  final String automationName;
  final int version;
  final String branchId;
  final String dateKey;
  final String executionId;

  /// The deterministic execution correlation id (`AUT-{yyyymmdd}-{hash}`) shared
  /// with the generated task, its notifications, and its audit entries.
  final String correlationId;

  // Execution
  final DateTime? startedAt;
  final DateTime? finishedAt;
  final int durationMs;
  final String trigger;
  final int retryCount;
  final AutomationRunStatus status;
  final AutomationRunOutcome outcome;

  // Schedule
  final DateTime? scheduledAt;
  final DateTime? actualAt;
  final int delayMs;
  final ScheduleShift? shift;
  final String day;

  // Detail blocks
  final List<AutomationRunValidation> validations;
  final AutomationRunTarget target;
  final AutomationRunGeneration generation;
  final AutomationRunNotification notification;
  final AutomationRunError? error;
  final List<AutomationRunLogEntry> logs;

  /// Immutable point-in-time snapshot of the definition/branch/recipients (§Execution
  /// Snapshot). Present on runs that generated a task; null on skipped/failed runs
  /// (fall back to the top-level identity fields, which are also immutable).
  final AutomationRunSnapshot? snapshot;

  bool get didFail => status == AutomationRunStatus.failed;
}
