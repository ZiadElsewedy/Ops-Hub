import 'package:drop/core/enums/notification_type.dart';
import 'package:drop/core/enums/task_status.dart';
import 'package:drop/core/enums/user_role.dart';
import 'package:drop/features/auth/domain/entities/user_entity.dart';
import 'package:drop/features/notifications/domain/entities/notification_entity.dart';
import 'package:drop/features/notifications/domain/repositories/notification_repository.dart';
import 'package:drop/features/notifications/domain/usecases/notify_task_event.dart';
import 'package:drop/features/task/domain/entities/task_entity.dart';
import 'package:flutter_test/flutter_test.dart';

/// The **copy** a task notification carries, in particular the due label.
///
/// `NotifyTaskEvent` used to hand-roll its own month table and a 12-hour AM/PM
/// clock, which put the notification (`Due today 4:30 PM`) and the Task Details
/// schedule band (`16:30`, since the 2026-08-06 rework) on two different clocks
/// for the same deadline. It now delegates to `AppDateFormatter`, the single
/// `DateTime → String` source, and takes an injected clock so "is this today?"
/// is testable across a day boundary instead of depending on when the suite runs.
void main() {
  const actor = UserEntity(
    uid: 'mgr1',
    email: 'mona@drop.test',
    displayName: 'Mona',
    authProvider: 'password',
    role: UserRole.manager,
  );

  // A Thursday afternoon.
  final now = DateTime(2026, 8, 6, 14, 0);

  TaskEntity task({DateTime? deadline}) => TaskEntity(
        id: 't1',
        title: 'Restock the cold case',
        status: TaskStatus.pending,
        branchId: 'branch1',
        assigneeIds: const ['emp1'],
        createdBy: 'mgr1',
        deadline: deadline,
      );

  Future<String> bodyFor(DateTime? deadline) async {
    final repo = _RecordingRepo();
    final notify = NotifyTaskEvent(repo, now: () => now);
    await notify(
      task: task(deadline: deadline),
      type: NotificationType.taskAssigned,
      actor: actor,
    );
    return repo.sent.single.body;
  }

  group('the assigned-task due label', () {
    test('uses the 24-hour clock the shift windows use', () async {
      // `ShiftHours.format` renders `08:30 – 16:30`; a deadline that reads
      // "4:30 PM" beside it looks like a different clock.
      expect(await bodyFor(DateTime(2026, 8, 6, 16, 30)),
          'Restock the cold case • Due Today 16:30');
    });

    test('zero-pads the hour', () async {
      expect(await bodyFor(DateTime(2026, 8, 6, 8, 5)),
          'Restock the cold case • Due Today 08:05');
    });

    test('says Tomorrow — the old code printed a bare date', () async {
      // A task assigned late for the next morning shift used to read
      // "7 Aug 08:30", which makes the reader do calendar arithmetic to find
      // out whether it is urgent.
      expect(await bodyFor(DateTime(2026, 8, 7, 8, 30)),
          'Restock the cold case • Due Tomorrow 08:30');
    });

    test('falls back to a compact date further out', () async {
      expect(await bodyFor(DateTime(2026, 8, 21, 16, 30)),
          'Restock the cold case • Due 21 Aug 16:30');
    });

    test('carries the year once it differs', () async {
      expect(await bodyFor(DateTime(2027, 1, 4, 9, 0)),
          'Restock the cold case • Due 4 Jan 2027 09:00');
    });

    test('a task with no deadline is just its title', () async {
      expect(await bodyFor(null), 'Restock the cold case');
    });

    test('the injected clock decides "today", not the wall clock', () async {
      // The whole point of injecting it: run this at 23:59 or at 00:01 and the
      // answer is the same.
      final repo = _RecordingRepo();
      final atMidnight = NotifyTaskEvent(
        repo,
        now: () => DateTime(2026, 8, 6, 23, 59),
      );
      await atMidnight(
        // 00:30 on the 7th — an hour away, but a different calendar day.
        task: task(deadline: DateTime(2026, 8, 7, 0, 30)),
        type: NotificationType.taskAssigned,
        actor: actor,
      );
      expect(repo.sent.single.body, contains('Due Tomorrow 00:30'));
    });
  });

  group('the separator the inbox splits on survives', () {
    test('subject and context stay divisible by " • "', () async {
      // `splitNotificationBody` makes the subject the row headline and demotes
      // the context; the due label must remain the CONTEXT half.
      final body = await bodyFor(DateTime(2026, 8, 6, 16, 30));
      final parts = body.split(' • ');
      expect(parts, hasLength(2));
      expect(parts.first, 'Restock the cold case');
      expect(parts.last, 'Due Today 16:30');
    });
  });
}

class _RecordingRepo implements NotificationRepository {
  final List<NotificationEntity> sent = [];

  @override
  Future<void> createMany(List<NotificationEntity> notifications) async =>
      sent.addAll(notifications);

  @override
  Future<void> create(NotificationEntity notification) async =>
      sent.add(notification);

  @override
  Stream<List<NotificationEntity>> watch(String uid, {int limit = 30}) =>
      const Stream.empty();

  @override
  Future<void> markRead(String id) async {}

  @override
  Future<void> markAllRead(String uid) async {}

  @override
  Future<void> delete(String id) async {}

  @override
  Future<void> deleteArchived(String uid) async {}

  @override
  Future<void> setArchived(String id, bool archived) async {}

  @override
  Future<void> setPinned(String id, bool pinned) async {}
}
