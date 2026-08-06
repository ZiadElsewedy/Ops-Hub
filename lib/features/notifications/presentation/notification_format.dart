import 'package:drop/core/enums/notification_type.dart';
import 'package:drop/features/notifications/domain/entities/notification_entity.dart';

/// Shared, **pure** presentation helpers for the Notification Center — the
/// operational inbox's information architecture (§5a). Kept out of the widget
/// tree so they're unit-tested (the project convention, like `activity_format`).
///
/// The inbox is an **operations workflow inbox**: notifications are **grouped by
/// time** (Today / Yesterday / Earlier), **filtered by category** (All / Tasks /
/// Reviews / Requests / Cases / Schedule / Sales / Broadcast), and **ordered by
/// priority** within each section so the things that need acting on float up.
///
/// > **Scope note:** the **Schedule** category is live — the shift-swap workflow
/// > (`NotifySwapEvent`) is its producer (swap requested / accepted / approved /
/// > declined) — and so is **Sales**, whose producer is the server's
/// > `writeSalesNotifications`. A **System** pill is still omitted (no producer
/// > writes a system notification yet — re-add it **alongside** its producer,
/// > never before).

// ─── Priority ───────────────────────────────────────────────────────

/// How urgently a notification wants attention. Drives in-section ordering
/// (critical first) and the tile's unread emphasis.
enum NotificationPriority { critical, high, normal, low }

/// Maps a [NotificationType] to its [NotificationPriority].
///
/// - **critical** — an overdue task or an emergency broadcast (act now);
/// - **high** — assigned / rejected / rework / submitted-for-review (your move);
/// - **normal** — approvals, reminders, routine broadcasts (informational).
///
/// (`low` is reserved for future system/archive noise — no producer today.)
NotificationPriority notificationPriority(NotificationType type) =>
    switch (type) {
      NotificationType.taskOverdue ||
      NotificationType.broadcastEmergency ||
      // A swap waiting on manager/admin approval — the spec's "pending swap
      // approval" critical example.
      NotificationType.swapAccepted =>
        NotificationPriority.critical,
      NotificationType.taskAssigned ||
      NotificationType.taskRejected ||
      NotificationType.taskRework ||
      NotificationType.taskSubmitted ||
      // A cancel is the assignee's move: STOP — most of all when they had
      // already started (Automated Tasks spec §9.2). A missed task is the
      // manager's move: work the branch owed did not happen. An incorrect-task
      // report is the manager's move: decide whether to cancel it.
      NotificationType.taskCancelled ||
      NotificationType.taskMissed ||
      NotificationType.taskReportedIncorrect ||
      NotificationType.swapRequested ||
      // A new case needs a recipient to act; a new reply is the other party's
      // move.
      NotificationType.caseOpened ||
      NotificationType.caseReplied ||
      // A new request needs an approver to act; a new comment is the other
      // party's move.
      NotificationType.requestSubmitted ||
      NotificationType.requestCommented ||
      // A filed correction needs a reviewer to act; an auto-closed session needs
      // the employee to file a fix — both are "your move".
      NotificationType.attendanceCorrectionFiled ||
      NotificationType.attendanceAutoClosed =>
        NotificationPriority.high,
      NotificationType.taskApproved ||
      NotificationType.taskReminder ||
      NotificationType.broadcastReminder ||
      NotificationType.broadcastAnnouncement ||
      NotificationType.swapApproved ||
      NotificationType.swapRejected ||
      NotificationType.caseUpdated ||
      NotificationType.caseClosed ||
      NotificationType.requestApproved ||
      NotificationType.requestRejected ||
      NotificationType.requestCompleted ||
      NotificationType.requestCancelled ||
      // A correction decision (approved / rejected) is informational to the
      // employee.
      NotificationType.attendanceCorrectionApproved ||
      NotificationType.attendanceCorrectionRejected ||
      // The whole sales workflow shares one type, so it takes the honest FLOOR
      // of the events it covers: "your branch target was updated" is pure
      // information. Ranking the shared type `high` would float a target change
      // above an overdue task — the loudest row in the inbox would be the one
      // nobody has to act on.
      NotificationType.salesSubmission =>
        NotificationPriority.normal,
    };

// ─── Category ───────────────────────────────────────────────────────

/// The inbox category filter (the top pills). `all` matches everything; the
/// rest map to a notification's content kind.
enum NotificationCategory {
  all,
  tasks,
  reviews,
  requests,
  cases,
  schedule,
  sales,
  broadcast;

  String get label => switch (this) {
        NotificationCategory.all => 'All',
        NotificationCategory.tasks => 'Tasks',
        NotificationCategory.reviews => 'Reviews',
        NotificationCategory.requests => 'Requests',
        NotificationCategory.cases => 'Cases',
        NotificationCategory.schedule => 'Schedule',
        NotificationCategory.sales => 'Sales',
        NotificationCategory.broadcast => 'Broadcast',
      };

  /// Whether [type] belongs to this category (`all` always matches).
  bool matches(NotificationType type) =>
      this == NotificationCategory.all || categoryOf(type) == this;
}

/// The content category a notification type belongs to (never `all`).
NotificationCategory categoryOf(NotificationType type) => switch (type) {
      NotificationType.taskAssigned ||
      NotificationType.taskReminder ||
      NotificationType.taskOverdue ||
      // Cancelled / missed / reported-incorrect are facts about the WORK, not
      // verdicts on someone's submission, so they file under Tasks rather than
      // Reviews.
      NotificationType.taskCancelled ||
      NotificationType.taskMissed ||
      NotificationType.taskReportedIncorrect =>
        NotificationCategory.tasks,
      NotificationType.taskSubmitted ||
      NotificationType.taskApproved ||
      NotificationType.taskRejected ||
      NotificationType.taskRework =>
        NotificationCategory.reviews,
      NotificationType.broadcastAnnouncement ||
      NotificationType.broadcastReminder ||
      NotificationType.broadcastEmergency =>
        NotificationCategory.broadcast,
      NotificationType.swapRequested ||
      NotificationType.swapAccepted ||
      NotificationType.swapApproved ||
      NotificationType.swapRejected =>
        NotificationCategory.schedule,
      NotificationType.caseOpened ||
      NotificationType.caseUpdated ||
      NotificationType.caseClosed ||
      NotificationType.caseReplied =>
        NotificationCategory.cases,
      NotificationType.requestSubmitted ||
      NotificationType.requestApproved ||
      NotificationType.requestRejected ||
      NotificationType.requestCompleted ||
      NotificationType.requestCancelled ||
      NotificationType.requestCommented ||
      // An attendance correction IS an approval request about a record — it
      // rides the Requests filter (no separate pill until attendance ships a
      // surface); the tile still badges it "Attendance".
      NotificationType.attendanceCorrectionFiled ||
      NotificationType.attendanceCorrectionApproved ||
      NotificationType.attendanceCorrectionRejected =>
        NotificationCategory.requests,
      // An auto-closed session is the employee's action item.
      NotificationType.attendanceAutoClosed => NotificationCategory.tasks,
      // Branch sales gets its own pill rather than riding Requests: a target
      // change is not an approval, and burying it under Tasks (where the
      // missing enum value used to land it) made the sales workflow invisible.
      NotificationType.salesSubmission => NotificationCategory.sales,
    };

// ─── Row text ───────────────────────────────────────────────────────

/// A notification body split into the **subject** (the thing it is about) and
/// its trailing **context**.
class NotificationBodyParts {
  /// The subject — always non-empty; the whole body when there is no separator.
  final String subject;

  /// The trailing context, or null when the body carried none.
  final String? context;

  const NotificationBodyParts(this.subject, this.context);
}

/// The separators every producer uses to hang context off a subject:
/// `Restock the cooler • Due today 2:59 PM`, `Fridge check — approved by Ziad`.
const _bodySeparators = [' • ', ' — '];

/// Splits a notification [body] into its subject and trailing context.
///
/// The stored `body` is the only place a notification names the **thing** it is
/// about — `title` is a pure function of `type` in every producer, so it is a
/// label, not content. Producers append context to that name with a ` • ` or
/// ` — ` separator, and the inbox row needs the two apart: the subject sets the
/// row's headline (one line, never wrapped) and the context sits under it in the
/// grey ramp. Splitting here rather than in the widget keeps it unit-testable,
/// the same convention as [groupByTime].
///
/// Splits on the **first** separator only, so a context containing another dash
/// stays intact. A body with no separator is all subject (context `null`), and a
/// separator with nothing usable on one side is ignored — the row can always
/// fall back to showing the whole body as the subject. Pure / deterministic.
NotificationBodyParts splitNotificationBody(String body) {
  final trimmed = body.trim();
  var cut = -1;
  var cutLength = 0;
  for (final sep in _bodySeparators) {
    final i = trimmed.indexOf(sep);
    if (i > 0 && (cut < 0 || i < cut)) {
      cut = i;
      cutLength = sep.length;
    }
  }
  if (cut < 0) return NotificationBodyParts(trimmed, null);

  final subject = trimmed.substring(0, cut).trim();
  final context = trimmed.substring(cut + cutLength).trim();
  if (subject.isEmpty || context.isEmpty) {
    return NotificationBodyParts(trimmed, null);
  }
  return NotificationBodyParts(subject, context);
}

// ─── Time grouping ──────────────────────────────────────────────────

/// One titled section in the grouped inbox ("Today" / "Yesterday" / "Earlier").
class NotificationSection {
  final String title;
  final List<NotificationEntity> items;
  const NotificationSection(this.title, this.items);
}

/// Groups [items] into **Today / Yesterday / Earlier** by `createdAt` (relative
/// to [now]); within each section, **higher priority first**, then newest-first,
/// so critical items pin to the top of their day. Empty sections are omitted.
/// Pure / deterministic.
List<NotificationSection> groupByTime(
  List<NotificationEntity> items,
  DateTime now,
) {
  final todayStart = DateTime(now.year, now.month, now.day);
  final yesterdayStart = todayStart.subtract(const Duration(days: 1));

  final today = <NotificationEntity>[];
  final yesterday = <NotificationEntity>[];
  final earlier = <NotificationEntity>[];
  for (final n in items) {
    final d = n.createdAt;
    if (!d.isBefore(todayStart)) {
      today.add(n);
    } else if (!d.isBefore(yesterdayStart)) {
      yesterday.add(n);
    } else {
      earlier.add(n);
    }
  }

  int byPriorityThenRecency(NotificationEntity a, NotificationEntity b) {
    final p = notificationPriority(a.type)
        .index
        .compareTo(notificationPriority(b.type).index);
    if (p != 0) return p;
    return b.createdAt.compareTo(a.createdAt);
  }

  for (final list in [today, yesterday, earlier]) {
    list.sort(byPriorityThenRecency);
  }

  return [
    if (today.isNotEmpty) NotificationSection('Today', today),
    if (yesterday.isNotEmpty) NotificationSection('Yesterday', yesterday),
    if (earlier.isNotEmpty) NotificationSection('Earlier', earlier),
  ];
}
