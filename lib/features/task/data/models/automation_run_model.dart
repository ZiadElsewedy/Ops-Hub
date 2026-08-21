import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:opshub/core/enums/schedule_shift.dart';
import 'package:opshub/features/task/domain/entities/automation_run_entity.dart';

/// Firestore → [AutomationRunEntity] parsing for `automationRuns/{id}`. Read-only
/// (the collection is server-authoritative — the client never writes it), so
/// there is no `toMap`. Defensive throughout: a malformed or partial run row
/// degrades to sane defaults rather than throwing, because observability must
/// never crash the surface that displays it.
class AutomationRunModel {
  const AutomationRunModel._();

  static AutomationRunEntity fromMap(Map<String, dynamic> map, {String? id}) {
    return AutomationRunEntity(
      id: id ?? _str(map['id']),
      templateId: _str(map['templateId']),
      automationName: _str(map['automationName']),
      version: _int(map['version'], 1),
      branchId: _str(map['branchId']),
      dateKey: _str(map['dateKey']),
      executionId: _str(map['executionId']),
      correlationId: _str(map['correlationId']),
      startedAt: _date(map['startedAt']),
      finishedAt: _date(map['finishedAt']),
      durationMs: _int(map['durationMs']),
      trigger: _str(map['trigger'], 'schedule'),
      retryCount: _int(map['retryCount']),
      status: AutomationRunStatus.fromString(map['status'] as String?),
      outcome: AutomationRunOutcome.fromString(map['outcome'] as String?),
      scheduledAt: _date(_field(map['schedule'], 'scheduledAt')),
      actualAt: _date(_field(map['schedule'], 'actualAt')),
      delayMs: _int(_field(map['schedule'], 'delayMs')),
      shift: _shift(_field(map['schedule'], 'shift')),
      day: _str(_field(map['schedule'], 'day')),
      validations: _validations(map['validations']),
      target: _target(map['target']),
      generation: _generation(map['generation'], map['generated']),
      notification: _notification(map['notification']),
      error: _error(map['error']),
      logs: _logs(map['logs']),
      snapshot: _snapshot(map['snapshot']),
    );
  }

  // ── Block parsers ──────────────────────────────────────────────────────

  static List<AutomationRunValidation> _validations(Object? raw) {
    if (raw is! List) return const [];
    return raw.whereType<Map>().map((m) {
      return AutomationRunValidation(
        name: _str(m['name']),
        result: ValidationResult.fromString(m['result'] as String?),
      );
    }).toList();
  }

  static AutomationRunTarget _target(Object? raw) {
    if (raw is! Map) return const AutomationRunTarget();
    return AutomationRunTarget(
      uids: _strList(raw['uids']),
      names: _strList(raw['names']),
      count: _int(raw['count']),
      matched: raw['matched'] == true,
    );
  }

  static AutomationRunGeneration _generation(Object? gen, Object? generated) {
    final g = gen is Map ? gen : const {};
    final out = generated is Map ? generated : const {};
    return AutomationRunGeneration(
      templateVersion: _int(g['templateVersion'], 1),
      checklistCount: _int(g['checklistCount']),
      priority: _str(g['priority'], 'normal'),
      taskIds: _strList(out['taskIds']),
      taskTitles: _strList(out['titles']),
      skippedCount: _int(out['skippedCount']),
    );
  }

  static AutomationRunNotification _notification(Object? raw) {
    if (raw is! Map) return const AutomationRunNotification();
    return AutomationRunNotification(
      sent: _int(raw['sent']),
      failed: _int(raw['failed']),
      notificationIds: _strList(raw['notificationIds']),
    );
  }

  static AutomationRunError? _error(Object? raw) {
    if (raw is! Map) return null;
    return AutomationRunError(
      stage: _str(raw['stage']),
      code: raw['code'],
      message: _str(raw['message']),
      retryable: raw['retryable'] == true,
      recovered: raw['recovered'] == true,
    );
  }

  static AutomationRunSnapshot? _snapshot(Object? raw) {
    if (raw is! Map) return null;
    final automation = raw['automation'] is Map ? raw['automation'] as Map : const {};
    final template = raw['template'] is Map ? raw['template'] as Map : const {};
    final schedule = raw['schedule'] is Map ? raw['schedule'] as Map : const {};
    final target = raw['target'] is Map ? raw['target'] as Map : const {};
    return AutomationRunSnapshot(
      automationId: _str(automation['id']),
      automationName: _str(automation['name']),
      automationVersion: _int(automation['version'], 1),
      templateId: _str(template['id'], _str(automation['id'])),
      templateName: _str(template['name'], _str(automation['name'])),
      templateVersion: _int(template['version'], 1),
      checklistCount: _int(template['checklistCount']),
      priority: _str(template['priority'], 'normal'),
      proofRequired: template['proofRequired'] == true,
      scheduleType: _str(schedule['type'], 'daily'),
      days: _strList(schedule['days']),
      shift: _shift(schedule['shift']),
      timezone: _str(schedule['timezone'], 'UTC'),
      branchId: _str(target['branchId'], _str(schedule['branchId'])),
      branchName: target['branchName'] is String
          ? target['branchName'] as String
          : null,
      recipients: _recipients(raw['recipients']),
      recipientCount: _int(raw['recipientCount']),
    );
  }

  static List<RecipientSnapshot> _recipients(Object? raw) {
    if (raw is! List) return const [];
    return raw.whereType<Map>().map((m) {
      return RecipientSnapshot(
        uid: _str(m['uid']),
        displayName: _str(m['displayName']),
        role: m['role'] is String ? m['role'] as String : null,
        assignedShift: _shift(m['assignedShift']),
      );
    }).toList();
  }

  static List<AutomationRunLogEntry> _logs(Object? raw) {
    if (raw is! List) return const [];
    return raw.whereType<Map>().map((m) {
      final meta = m['meta'];
      return AutomationRunLogEntry(
        at: _date(m['at']),
        stage: _str(m['stage']),
        severity: LogSeverity.fromString(m['severity'] as String?),
        message: _str(m['message']),
        meta: meta is Map ? Map<String, dynamic>.from(meta) : null,
      );
    }).toList();
  }

  // ── Primitive coercers ─────────────────────────────────────────────────

  static Object? _field(Object? map, String key) =>
      map is Map ? map[key] : null;

  static String _str(Object? v, [String fallback = '']) =>
      v is String ? v : fallback;

  static int _int(Object? v, [int fallback = 0]) =>
      v is num ? v.toInt() : fallback;

  static List<String> _strList(Object? v) =>
      v is List ? v.whereType<String>().toList() : const [];

  static DateTime? _date(Object? v) => v is Timestamp ? v.toDate() : null;

  static ScheduleShift? _shift(Object? v) =>
      v is String ? ScheduleShift.fromString(v) : null;
}
