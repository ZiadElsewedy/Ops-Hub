import 'dart:developer' as developer;

import 'package:drop/core/enums/notification_type.dart';
import 'package:drop/features/auth/domain/entities/user_entity.dart';
import 'package:drop/features/notifications/domain/entities/notification_entity.dart';
import 'package:drop/features/notifications/domain/notification_deep_link.dart';
import 'package:drop/features/notifications/domain/repositories/notification_repository.dart';
import 'package:drop/features/task/domain/entities/task_entity.dart';

/// Builds + persists the in-app notification(s) for a task event (Notification
/// System Phase 1, Part 3). One document per recipient. The matching FCM push is
/// delivered by the `onNotificationCreated` Cloud Function.
///
/// **Best-effort by design** — a notification failure must never affect the task
/// write, so [call] never throws: errors are logged and swallowed.
class NotifyTaskEvent {
  final NotificationRepository _repository;
  const NotifyTaskEvent(this._repository);

  /// Emits [type] for [task], triggered by [actor]. For an *assignment* event,
  /// pass [recipientOverride] to target only the newly-added assignees (so a
  /// re-assign doesn't re-notify everyone).
  Future<void> call({
    required TaskEntity task,
    required NotificationType type,
    required UserEntity actor,
    List<String>? recipientOverride,
  }) async {
    try {
      final recipients = recipientOverride ?? _recipientsFor(task, type);
      final cleaned = recipients
          .where((uid) => uid.isNotEmpty && uid != actor.uid)
          .toSet()
          .toList();
      if (cleaned.isEmpty) return;

      final actorName = _actorName(actor);
      final title = _titleFor(type);
      final body = _bodyFor(task, type, actorName);
      final payload = _payloadFor(task, type);
      final now = DateTime.now();

      final notifications = [
        for (final uid in cleaned)
          NotificationEntity(
            id: '',
            recipientUid: uid,
            senderUid: actor.uid,
            type: type,
            title: title,
            body: body,
            createdAt: now,
            payload: payload,
          ),
      ];
      await _repository.createMany(notifications);
    } catch (e, st) {
      developer.log('NotifyTaskEvent failed for ${type.value}',
          name: 'notifications', error: e, stackTrace: st);
    }
  }

  // ─── Recipient resolution ──────────────────────────────────────
  List<String> _recipientsFor(TaskEntity task, NotificationType type) {
    switch (type) {
      case NotificationType.taskSubmitted:
        // The reviewer who created the task.
        return [task.createdBy ?? ''];
      default:
        // Everyone working the task (assign / rework / approve / reject).
        return task.assigneeIds;
    }
  }

  // ─── Copy ──────────────────────────────────────────────────────
  String _titleFor(NotificationType type) {
    switch (type) {
      case NotificationType.taskAssigned:
        return 'New Task Assigned';
      case NotificationType.taskRework:
        return 'Task Needs Rework';
      case NotificationType.taskSubmitted:
        return 'Task Submitted';
      case NotificationType.taskApproved:
        return 'Task Approved';
      case NotificationType.taskRejected:
        return 'Task Rejected';
      case NotificationType.taskCancelled:
        return 'Task Cancelled';
      case NotificationType.taskReportedIncorrect:
        return 'Task Reported';
      default:
        return 'Task Update';
    }
  }

  /// The notification's **subject** — the inbox renders this as the row's
  /// headline and demotes [_titleFor] to a small kicker, so **every branch must
  /// name the task**. A body that only restates the event ("Task approved")
  /// leaves a row that is indistinguishable from every other row of its type,
  /// which is exactly the complaint this copy was rewritten for.
  String _bodyFor(TaskEntity task, NotificationType type, String actorName) {
    switch (type) {
      case NotificationType.taskAssigned:
        final due = _dueLabel(task.deadline);
        return due == null ? task.title : '${task.title} • Due $due';
      case NotificationType.taskRework:
        final reason = (task.rejectionReason ?? '').trim();
        return reason.isNotEmpty
            ? '${task.title} — $reason'
            : '${task.title} needs rework';
      case NotificationType.taskSubmitted:
        return '${task.title} submitted by $actorName';
      case NotificationType.taskApproved:
        return '${task.title} — approved by $actorName';
      case NotificationType.taskRejected:
        final reason = (task.rejectionReason ?? '').trim();
        return reason.isNotEmpty
            ? '${task.title} — $reason'
            : '${task.title} — review manager notes';
      case NotificationType.taskCancelled:
        // Always says WHY — the reason is mandatory precisely so the person who
        // was going to do this work isn't left guessing. Work already underway
        // is called out, since that is the cancel that costs someone something
        // (Automated Tasks spec §9.2).
        final reason = task.cancelReason?.label;
        final prefix = task.startedAt != null
            ? '${task.title} — stopped'
            : task.title;
        return reason == null ? prefix : '$prefix • $reason';
      case NotificationType.taskReportedIncorrect:
        final note = (task.reportedIncorrectNote ?? '').trim();
        return note.isNotEmpty
            ? '${task.title} — $note'
            : '${task.title} was reported as incorrect';
      default:
        return task.title;
    }
  }

  Map<String, dynamic> _payloadFor(TaskEntity task, NotificationType type) {
    final payload = <String, dynamic>{
      'taskId': task.id,
      'route': NotificationRoute.task,
    };
    if (type == NotificationType.taskRework) {
      payload['revisionNumber'] = task.revisionNumber;
    }
    return payload;
  }

  String _actorName(UserEntity user) {
    final name = user.displayName?.trim();
    if (name != null && name.isNotEmpty) return name;
    final email = user.email.trim();
    return email.isNotEmpty ? email : 'Someone';
  }

  /// "today 4:30 PM" / "21 Jun 4:30 PM" — a short, human due label.
  String? _dueLabel(DateTime? deadline) {
    if (deadline == null) return null;
    final now = DateTime.now();
    final isToday = deadline.year == now.year &&
        deadline.month == now.month &&
        deadline.day == now.day;
    final time = _timeLabel(deadline);
    if (isToday) return 'today $time';
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', //
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${deadline.day} ${months[deadline.month - 1]} $time';
  }

  String _timeLabel(DateTime d) {
    final hour12 = d.hour % 12 == 0 ? 12 : d.hour % 12;
    final minute = d.minute.toString().padLeft(2, '0');
    final period = d.hour < 12 ? 'AM' : 'PM';
    return '$hour12:$minute $period';
  }
}
