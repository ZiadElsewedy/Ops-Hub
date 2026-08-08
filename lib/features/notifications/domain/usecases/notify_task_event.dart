import 'dart:developer' as developer;

import 'package:drop/core/enums/notification_type.dart';
import 'package:drop/core/utils/app_date_formatter.dart';
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

  /// Injectable clock. Nullable rather than defaulted so the constructor stays
  /// `const`; read through [_clock]. Exists because [_dueLabel] has to decide
  /// "is this deadline today?", and a use case that reads the wall clock
  /// directly cannot be tested across a day boundary — the project convention
  /// for every other pure domain decision (`AppDateFormatter.relativeDay`,
  /// `startBlockedReason`, `reminderDueKind`) is an injected `now`.
  final DateTime Function()? _now;

  // The lint wants `{this._now}`, which Dart does not allow: a named parameter
  // cannot have a private name. The field stays private, so this stays a plain
  // initializer.
  const NotifyTaskEvent(this._repository, {DateTime Function()? now})
      : _now = now; // ignore: prefer_initializing_formals

  DateTime get _clock => (_now ?? DateTime.now)();

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

      final now = _clock;
      final actorName = _actorName(actor);
      final title = _titleFor(type);
      final body = _bodyFor(task, type, actorName, now);
      final payload = _payloadFor(task, type);

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
  String _bodyFor(
    TaskEntity task,
    NotificationType type,
    String actorName,
    DateTime now,
  ) {
    switch (type) {
      case NotificationType.taskAssigned:
        final due = _dueLabel(task.deadline, now);
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

  /// `Today 16:30` / `Tomorrow 08:30` / `21 Jun 16:30` — a short due label.
  ///
  /// Delegates entirely to [AppDateFormatter], the single source for
  /// `DateTime → String` (PROJECT_CONTEXT §4). It used to hand-roll its own
  /// month table and a 12-hour AM/PM clock, which put this notification
  /// (`Due today 4:30 PM`) and the Task Details schedule band (`16:30`, since
  /// the 2026-08-06 rework) on **two different clocks for the same deadline**.
  /// 24-hour is the one the shift windows use (`ShiftHours.format` →
  /// `08:30 – 16:30`), so it is the one a deadline sits beside.
  ///
  /// [relativeDayShort] also earns `Tomorrow` for free — the old code called
  /// anything that was not today by its bare date, so a task assigned late at
  /// night for the morning shift read `7 Aug 08:30` instead of `Tomorrow 08:30`.
  String? _dueLabel(DateTime? deadline, DateTime now) {
    if (deadline == null) return null;
    final day = AppDateFormatter.relativeDayShort(deadline, now: now);
    return '$day ${AppDateFormatter.time24(deadline)}';
  }
}
