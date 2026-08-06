import 'package:flutter_test/flutter_test.dart';
import 'package:drop/core/enums/notification_type.dart';
import 'package:drop/features/notifications/domain/entities/notification_entity.dart';
import 'package:drop/features/notifications/presentation/notification_format.dart';

/// Notification Center pure helpers (§5a operations inbox): the priority model,
/// the category model, and the Today/Yesterday/Earlier time grouping.
NotificationEntity _n(
  String id, {
  required DateTime at,
  NotificationType type = NotificationType.taskApproved,
  bool read = false,
}) =>
    NotificationEntity(
      id: id,
      recipientUid: 'u1',
      type: type,
      title: 'Title',
      body: 'Body',
      createdAt: at,
      readAt: read ? at : null,
    );

void main() {
  group('notificationPriority', () {
    test('overdue + emergency are critical', () {
      expect(notificationPriority(NotificationType.taskOverdue),
          NotificationPriority.critical);
      expect(notificationPriority(NotificationType.broadcastEmergency),
          NotificationPriority.critical);
    });
    test('assigned / rejected / rework / submitted are high', () {
      for (final t in [
        NotificationType.taskAssigned,
        NotificationType.taskRejected,
        NotificationType.taskRework,
        NotificationType.taskSubmitted,
      ]) {
        expect(notificationPriority(t), NotificationPriority.high, reason: t.name);
      }
    });
    test('approvals / reminders / routine broadcasts are normal', () {
      for (final t in [
        NotificationType.taskApproved,
        NotificationType.taskReminder,
        NotificationType.broadcastReminder,
        NotificationType.broadcastAnnouncement,
      ]) {
        expect(notificationPriority(t), NotificationPriority.normal,
            reason: t.name);
      }
    });
  });

  group('NotificationCategory', () {
    test('content types map to the right category', () {
      expect(categoryOf(NotificationType.taskAssigned),
          NotificationCategory.tasks);
      expect(categoryOf(NotificationType.taskSubmitted),
          NotificationCategory.reviews);
      expect(categoryOf(NotificationType.broadcastEmergency),
          NotificationCategory.broadcast);
    });
    test('all matches everything; a category matches only its own', () {
      expect(NotificationCategory.all.matches(NotificationType.taskApproved),
          isTrue);
      expect(NotificationCategory.reviews.matches(NotificationType.taskApproved),
          isTrue); // approved is a review event
      expect(NotificationCategory.tasks.matches(NotificationType.taskApproved),
          isFalse);
    });
    test('pills are All / Tasks / Reviews / Requests / Cases / Schedule / '
        'Sales / Broadcast', () {
      expect(NotificationCategory.values.map((c) => c.label).toList(), [
        'All',
        'Tasks',
        'Reviews',
        'Requests',
        'Cases',
        'Schedule',
        'Sales',
        'Broadcast',
      ]);
    });
    test('a sales notification files under Sales — never Tasks', () {
      // The regression this pins: `salesSubmission` had no enum value, so
      // `NotificationModel.fromMap` fell back to `taskAssigned` and every
      // branch-sales notification arrived wearing a task glyph under the Tasks
      // pill, ranked HIGH above real work.
      expect(categoryOf(NotificationType.salesSubmission),
          NotificationCategory.sales);
      expect(
          NotificationCategory.tasks.matches(NotificationType.salesSubmission),
          isFalse);
      expect(notificationPriority(NotificationType.salesSubmission),
          NotificationPriority.normal);
    });
    test('swap notifications map to the Schedule category', () {
      for (final t in [
        NotificationType.swapRequested,
        NotificationType.swapAccepted,
        NotificationType.swapApproved,
        NotificationType.swapRejected,
      ]) {
        expect(categoryOf(t), NotificationCategory.schedule, reason: t.name);
      }
    });
  });

  group('swap notification priority', () {
    test('a swap awaiting manager approval is critical', () {
      expect(notificationPriority(NotificationType.swapAccepted),
          NotificationPriority.critical);
    });
    test('a swap request is high; approved/rejected are normal', () {
      expect(notificationPriority(NotificationType.swapRequested),
          NotificationPriority.high);
      expect(notificationPriority(NotificationType.swapApproved),
          NotificationPriority.normal);
      expect(notificationPriority(NotificationType.swapRejected),
          NotificationPriority.normal);
    });
  });

  group('groupByTime', () {
    final now = DateTime(2026, 6, 22, 12);

    test('buckets into Today / Yesterday / Earlier (non-empty only)', () {
      final items = [
        _n('today', at: DateTime(2026, 6, 22, 9)),
        _n('yesterday', at: DateTime(2026, 6, 21, 9)),
        _n('earlier', at: DateTime(2026, 6, 10, 9)),
      ];
      final sections = groupByTime(items, now);
      expect(sections.map((s) => s.title).toList(),
          ['Today', 'Yesterday', 'Earlier']);
    });

    test('within a day, higher priority sorts above newer-but-lower', () {
      final items = [
        // Newer, but only normal priority.
        _n('approvedNew',
            at: DateTime(2026, 6, 22, 11), type: NotificationType.taskApproved),
        // Older, but critical → must come first.
        _n('overdueOld',
            at: DateTime(2026, 6, 22, 8), type: NotificationType.taskOverdue),
      ];
      final today = groupByTime(items, now).single;
      expect(today.title, 'Today');
      expect(today.items.map((n) => n.id).toList(),
          ['overdueOld', 'approvedNew']);
    });

    test('same priority falls back to newest-first', () {
      final items = [
        _n('older', at: DateTime(2026, 6, 22, 8)),
        _n('newer', at: DateTime(2026, 6, 22, 10)),
      ];
      final today = groupByTime(items, now).single;
      expect(today.items.map((n) => n.id).toList(), ['newer', 'older']);
    });
  });

  // The inbox row leads with the SUBJECT (the thing the notification is about)
  // and hangs its context on the line below, so the headline can hold one line
  // and the column stops reading ragged.
  group('splitNotificationBody', () {
    test('splits a bullet body into subject + context', () {
      final p = splitNotificationBody('Restock the cooler • Due today 2:59 PM');
      expect(p.subject, 'Restock the cooler');
      expect(p.context, 'Due today 2:59 PM');
    });

    test('splits an em-dash body too', () {
      final p = splitNotificationBody('Fridge check — approved by Ziad');
      expect(p.subject, 'Fridge check');
      expect(p.context, 'approved by Ziad');
    });

    test('a body with no separator is all subject', () {
      final p = splitNotificationBody('Mahmoud filed a shift-change request');
      expect(p.subject, 'Mahmoud filed a shift-change request');
      expect(p.context, isNull);
    });

    test('splits on the FIRST separator, so a dash in the context survives', () {
      final p = splitNotificationBody('Deep clean — re-do it — photo unclear');
      expect(p.subject, 'Deep clean');
      expect(p.context, 're-do it — photo unclear');
    });

    test('the earliest separator wins when both kinds appear', () {
      final p = splitNotificationBody('Open up • Due 8:00 — late already');
      expect(p.subject, 'Open up');
      expect(p.context, 'Due 8:00 — late already');
    });

    test('an empty side falls back to the whole body as the subject', () {
      expect(splitNotificationBody('Close-down • ').subject, 'Close-down •');
      expect(splitNotificationBody('Close-down • ').context, isNull);
      // A leading separator has nothing before it, so there is no subject to
      // take — the body stays whole rather than becoming an empty headline.
      final leading = splitNotificationBody(' — approved by Ziad');
      expect(leading.subject, '— approved by Ziad');
      expect(leading.context, isNull);
    });

    test('trims surrounding whitespace', () {
      final p = splitNotificationBody('  Fridge check  •  Due 9 PM  ');
      expect(p.subject, 'Fridge check');
      expect(p.context, 'Due 9 PM');
    });
  });
}
