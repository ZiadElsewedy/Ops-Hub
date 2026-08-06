import 'package:flutter_test/flutter_test.dart';
import 'package:drop/core/enums/task_status.dart';
import 'package:drop/core/enums/user_role.dart';
import 'package:drop/features/auth/domain/entities/user_entity.dart';
import 'package:drop/features/task/domain/entities/task_entity.dart';
import 'package:drop/features/task/domain/task_origin.dart';
import 'package:drop/features/task/presentation/activity_format.dart';

/// A task carrying only the fields origin classification reads.
TaskEntity _task({
  String? createdBy,
  String? sourceTemplateId,
  String? correlationId,
  String? recurrenceRootId,
}) => TaskEntity(
  id: 't1',
  title: 'Open Shift',
  branchId: 'b1',
  status: TaskStatus.pending,
  createdAt: DateTime(2026, 8, 6),
  createdBy: createdBy,
  sourceTemplateId: sourceTemplateId,
  correlationId: correlationId,
  recurrenceRootId: recurrenceRootId,
);

void main() {
  group('taskOrigin', () {
    test('a hand-created task is manual, even with a createdBy', () {
      final t = _task(createdBy: 'u_manager');
      expect(taskOrigin(t), TaskOrigin.manual);
      expect(isAutomatedTask(t), isFalse);
      expect(taskOrigin(t).label, isNull);
    });

    test('a generated shift instance is automated despite inheriting the '
        'template owner as createdBy', () {
      // The exact shape `generateShiftTaskInstances` writes: the template's
      // createdBy is copied onto the instance, which is why createdBy alone
      // cannot answer "who created this task?".
      final t = _task(
        createdBy: 'u_manager',
        sourceTemplateId: 'tpl_1',
        correlationId: 'AUT-20260806-ab12',
      );
      expect(taskOrigin(t), TaskOrigin.recurringShift);
      expect(isAutomatedTask(t), isTrue);
      expect(taskOrigin(t).label, 'Automated task');
    });

    test('a correlationId alone is enough (pre-template legacy instance)', () {
      expect(
        taskOrigin(_task(correlationId: 'AUT-20260806-ab12')),
        TaskOrigin.recurringShift,
      );
    });

    test('a recurrence-chain successor is automated', () {
      final t = _task(createdBy: 'u_manager', recurrenceRootId: 'root_1');
      expect(taskOrigin(t), TaskOrigin.recurrenceChain);
      expect(taskOrigin(t).label, 'Automated task');
    });

    test('the manually-created ROOT of a chain stays manual — the root never '
        'carries its own recurrenceRootId', () {
      expect(taskOrigin(_task(createdBy: 'u_manager')), TaskOrigin.manual);
    });

    test('blank/whitespace marker fields do not fake automation', () {
      expect(
        taskOrigin(_task(sourceTemplateId: '   ', recurrenceRootId: '')),
        TaskOrigin.manual,
      );
    });
  });

  group('isSystemActorId', () {
    test('matches the server literal, case- and space-insensitively', () {
      expect(isSystemActorId('system'), isTrue);
      expect(isSystemActorId(' System '), isTrue);
    });

    test('a real uid and a missing actor are not the system', () {
      expect(isSystemActorId('u_abc'), isFalse);
      expect(isSystemActorId(''), isFalse);
      expect(isSystemActorId(null), isFalse);
    });
  });

  group('activityActorName / activityActorRole', () {
    const person = UserEntity(
      uid: 'u1',
      email: 'ziad@drop.com',
      authProvider: 'password',
      displayName: 'Ziad',
      role: UserRole.manager,
    );

    test('the system signs itself System · Automated, never "Someone"', () {
      // The regression this closes: "system" is not a uid, so it never resolves
      // in the directory and every automated event signed itself "Someone".
      expect(activityActorName('system', null, null), 'System');
      expect(activityActorRole('system', null), 'Automated');
    });

    test('the system wins even if a stale actorName rode along', () {
      expect(activityActorName('system', 'Ziad', person), 'System');
    });

    test('a stamped actorName is preferred over the directory', () {
      expect(activityActorName('u1', 'Ziad E.', person), 'Ziad E.');
    });

    test('falls back to the directory, then to the anonymous name', () {
      expect(activityActorName('u1', null, person), 'Ziad');
      expect(activityActorRole('u1', person), 'Manager');
      expect(activityActorName('u_gone', null, null), 'Someone');
      expect(activityActorRole('u_gone', null), isNull);
    });

    test('a blank actorName does not win over the directory', () {
      expect(activityActorName('u1', '   ', person), 'Ziad');
    });
  });
}
