import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opshub/core/enums/schedule_shift.dart';
import 'package:opshub/features/task/data/models/automation_run_model.dart';
import 'package:opshub/features/task/domain/entities/automation_run_entity.dart';

void main() {
  group('AutomationRunModel.fromMap', () {
    test('parses a full completed run into every block', () {
      final started = DateTime.utc(2026, 7, 18, 9, 0, 0);
      final finished = DateTime.utc(2026, 7, 18, 9, 0, 3);
      final run = AutomationRunModel.fromMap({
        'templateId': 'tpl-1',
        'automationName': 'Open Store',
        'version': 4,
        'branchId': 'branch-1',
        'dateKey': '2026-07-18',
        'executionId': 'exec-abc',
        'startedAt': Timestamp.fromDate(started),
        'finishedAt': Timestamp.fromDate(finished),
        'durationMs': 3000,
        'trigger': 'schedule',
        'retryCount': 0,
        'status': 'completed',
        'outcome': 'created',
        'schedule': {
          'scheduledAt': Timestamp.fromDate(started),
          'actualAt': Timestamp.fromDate(started),
          'delayMs': 1200,
          'shift': 'morning',
          'day': 'saturday',
          'branchId': 'branch-1',
        },
        'validations': [
          {'name': 'templateExists', 'result': 'pass'},
          {'name': 'scheduleValid', 'result': 'pass'},
          {'name': 'employeesFound', 'result': 'fail'},
        ],
        'target': {
          'uids': ['u1', 'u2'],
          'names': ['Alice', 'Bob'],
          'count': 2,
          'matched': true,
        },
        'generation': {
          'templateVersion': 4,
          'checklistCount': 3,
          'priority': 'high',
          'proofRequired': false,
        },
        'generated': {
          'taskIds': ['rt_tpl-1_2026-07-18'],
          'titles': ['Open Store'],
          'count': 1,
          'skippedCount': 0,
        },
        'notification': {
          'sent': 2,
          'failed': 0,
          'notificationIds': ['n1', 'n2'],
        },
        'error': null,
        'logs': [
          {
            'at': Timestamp.fromDate(started),
            'stage': 'start',
            'severity': 'info',
            'message': 'Execution started',
            'meta': {'executionId': 'exec-abc'},
          },
          {
            'at': Timestamp.fromDate(finished),
            'stage': 'complete',
            'severity': 'info',
            'message': 'Execution completed',
            'meta': null,
          },
        ],
      }, id: 'tpl-1_2026-07-18');

      expect(run.id, 'tpl-1_2026-07-18');
      expect(run.automationName, 'Open Store');
      expect(run.version, 4);
      expect(run.status, AutomationRunStatus.completed);
      expect(run.outcome, AutomationRunOutcome.created);
      expect(run.durationMs, 3000);
      expect(run.startedAt!.isAtSameMomentAs(started), isTrue);
      expect(run.shift, ScheduleShift.morning);
      expect(run.day, 'saturday');
      expect(run.delayMs, 1200);

      expect(run.validations, hasLength(3));
      expect(run.validations.last.name, 'employeesFound');
      expect(run.validations.last.result, ValidationResult.fail);

      expect(run.target.count, 2);
      expect(run.target.matched, isTrue);
      expect(run.target.names, ['Alice', 'Bob']);

      expect(run.generation.checklistCount, 3);
      expect(run.generation.priority, 'high');
      expect(run.generation.taskIds, ['rt_tpl-1_2026-07-18']);

      expect(run.notification.sent, 2);
      expect(run.notification.notificationIds, ['n1', 'n2']);

      expect(run.error, isNull);
      expect(run.logs, hasLength(2));
      expect(run.logs.first.stage, 'start');
      expect(run.logs.first.severity, LogSeverity.info);
      expect(run.logs.first.meta?['executionId'], 'exec-abc');
    });

    test('parses a failed run with a structured, retryable error', () {
      final run = AutomationRunModel.fromMap({
        'templateId': 'tpl-2',
        'status': 'failed',
        'outcome': 'error',
        'error': {
          'stage': 'generate',
          'code': 14,
          'message': 'backend unavailable',
          'retryable': true,
          'recovered': false,
        },
        'logs': [
          {
            'stage': 'generate',
            'severity': 'error',
            'message': 'Execution failed at generate',
          },
        ],
      }, id: 'tpl-2_2026-07-18');

      expect(run.didFail, isTrue);
      expect(run.outcome, AutomationRunOutcome.error);
      expect(run.error, isNotNull);
      expect(run.error!.stage, 'generate');
      expect(run.error!.code, 14);
      expect(run.error!.retryable, isTrue);
      expect(run.error!.recovered, isFalse);
      expect(run.logs.single.severity, LogSeverity.error);
    });

    test('degrades gracefully on a malformed/partial row (no throw)', () {
      final run = AutomationRunModel.fromMap({
        'templateId': 'tpl-3',
        'status': 'weird-value',
        'validations': 'not-a-list',
        'target': 42,
        'logs': null,
      }, id: 'tpl-3_x');

      expect(run.status, AutomationRunStatus.unknown);
      expect(run.outcome, AutomationRunOutcome.unknown);
      expect(run.validations, isEmpty);
      expect(run.target.count, 0);
      expect(run.target.matched, isFalse);
      expect(run.logs, isEmpty);
      expect(run.error, isNull);
    });

    test('parses the correlation id and immutable execution snapshot', () {
      final run = AutomationRunModel.fromMap({
        'templateId': 'tpl-1',
        'correlationId': 'AUT-20260718-A3F9C1',
        'status': 'completed',
        'outcome': 'created',
        'snapshot': {
          'automation': {'id': 'tpl-1', 'name': 'Open Store', 'version': 4},
          'template': {
            'id': 'tpl-1',
            'name': 'Open Store',
            'version': 4,
            'checklistCount': 3,
            'priority': 'high',
            'proofRequired': false,
          },
          'schedule': {
            'type': 'weekly',
            'days': ['saturday'],
            'shift': 'morning',
            'branchId': 'branch-1',
            'timezone': 'UTC',
          },
          'target': {'branchId': 'branch-1', 'branchName': 'Downtown'},
          'recipients': [
            {
              'uid': 'u1',
              'displayName': 'Alice',
              'role': 'employee',
              'assignedShift': 'morning',
            },
            {
              'uid': 'u2',
              'displayName': 'Bob',
              'role': 'manager',
              'assignedShift': 'morning',
            },
          ],
          'recipientCount': 2,
        },
      }, id: 'tpl-1_2026-07-18');

      expect(run.correlationId, 'AUT-20260718-A3F9C1');
      final s = run.snapshot;
      expect(s, isNotNull);
      expect(s!.automationName, 'Open Store');
      expect(s.automationVersion, 4);
      expect(s.checklistCount, 3);
      expect(s.priority, 'high');
      expect(s.scheduleType, 'weekly');
      expect(s.days, ['saturday']);
      expect(s.shift, ScheduleShift.morning);
      expect(s.timezone, 'UTC');
      expect(s.branchName, 'Downtown');
      expect(s.recipientCount, 2);
      expect(s.recipients.first.uid, 'u1');
      expect(s.recipients.first.displayName, 'Alice');
      expect(s.recipients.first.role, 'employee');
      expect(s.recipients.first.assignedShift, ScheduleShift.morning);
    });

    test('a run with no snapshot (skipped/failed) leaves snapshot null', () {
      final run = AutomationRunModel.fromMap({
        'templateId': 'tpl-1',
        'status': 'skipped',
        'outcome': 'alreadyExists',
      });
      expect(run.snapshot, isNull);
      expect(run.correlationId, '');
    });

    test('an unmatched target records matched:false explicitly', () {
      final run = AutomationRunModel.fromMap({
        'templateId': 'tpl-4',
        'outcome': 'noEligibleEmployees',
        'target': {'uids': [], 'names': [], 'count': 0, 'matched': false},
      });
      expect(run.outcome, AutomationRunOutcome.noEligibleEmployees);
      expect(run.target.matched, isFalse);
      expect(run.target.uids, isEmpty);
    });
  });
}
