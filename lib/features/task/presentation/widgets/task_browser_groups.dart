import 'package:opshub/core/enums/task_status.dart';
import 'package:opshub/features/task/domain/entities/task_entity.dart';
import 'package:opshub/features/task/domain/task_feed.dart';

/// Date sectioning for the **record browser** ([TaskBrowser]).
///
/// The feed engine's `groupFeed(FeedGrouping.dueTime, …)` is a *forward-looking*
/// scheme built for the live homepage feed: everything already finished lands in
/// one bucket literally labelled **"Done today"**. That is correct for a feed
/// scoped to the active window, and wrong for a browser that deliberately opens
/// the closed record set — an approved task from three weeks ago was rendering
/// under a header that said it closed today.
///
/// So the browser splits the list in two and lets each half be grouped by the
/// question it actually answers:
///
/// * **open work** — still delegated to `groupFeed`, untouched, so the Late /
///   Today / This week / Later / No due date buckets can never drift from the
///   engine the rest of the app reads;
/// * **records** — bucketed *backwards* from when the work actually closed
///   (Closed today · Yesterday · Earlier this week · Last week · Older), newest
///   first, because nobody scans a finished ledger in ascending due order.
///
/// Pure Dart, presentation-only: no filtering, sorting or status semantics are
/// redefined here, and `task_feed.dart` is not modified.
List<FeedGroup> browserGroups(List<TaskEntity> tasks, DateTime now) {
  final open = <TaskEntity>[];
  final records = <TaskEntity>[];
  for (final task in tasks) {
    (isTaskRecord(task) ? records : open).add(task);
  }

  final groups = [...groupFeed(open, FeedGrouping.dueTime, now)];

  if (records.isNotEmpty) {
    final buckets = <String, _RecordBucket>{};
    for (final task in records) {
      final at = taskRecordDate(task);
      final bucket = _bucketFor(at, now);
      (buckets[bucket.key] ??= _RecordBucket(bucket.label, bucket.order)).add(
        task,
        at,
      );
    }
    for (final entry in buckets.entries) {
      groups.add(
        FeedGroup(
          key: entry.key,
          label: entry.value.label,
          order: entry.value.order,
          tasks: entry.value.sortedNewestFirst(),
        ),
      );
    }
  }

  groups.sort((a, b) {
    final byOrder = a.order.compareTo(b.order);
    return byOrder != 0
        ? byOrder
        : a.label.toLowerCase().compareTo(b.label.toLowerCase());
  });
  return groups;
}

/// Whether [task] is a **record** — work whose story is over, so its place in a
/// list is decided by when it ended rather than by when it was due.
///
/// The three terminal outcomes plus `completed`: an employee's "I'm done" is not
/// a closed task, but it is finished work, and the feed engine already treats it
/// as done — routing it here is what keeps a stale `completed` task from being
/// announced as *done today* too.
bool isTaskRecord(TaskEntity task) =>
    task.status.isTerminal || task.status == TaskStatus.completed;

/// When a record actually ended. Each terminal status has its own stamped
/// timestamp; `updatedAt` is the fallback for older documents written before
/// those fields existed, and the deadline is the last resort.
DateTime? taskRecordDate(TaskEntity task) {
  final closed = switch (task.status) {
    TaskStatus.approved => task.approvedAt,
    TaskStatus.missed => task.missedAt,
    TaskStatus.cancelled => task.cancelledAt,
    _ => task.submittedAt,
  };
  return closed ?? task.updatedAt ?? task.deadline;
}

class _RecordBucket {
  _RecordBucket(this.label, this.order);
  final String label;
  final int order;
  final List<(TaskEntity, DateTime?)> _entries = [];

  void add(TaskEntity task, DateTime? at) => _entries.add((task, at));

  List<TaskEntity> sortedNewestFirst() {
    final sorted = [..._entries]
      ..sort((a, b) {
        final x = a.$2, y = b.$2;
        if (x == null && y == null) return 0;
        if (x == null) return 1;
        if (y == null) return -1;
        return y.compareTo(x);
      });
    return [for (final entry in sorted) entry.$1];
  }
}

/// Record buckets start at 10 so they always sort **after** every open-work
/// bucket the engine produces (0–5), whatever it adds later.
({String key, String label, int order}) _bucketFor(DateTime? at, DateTime now) {
  if (at == null) return (key: 'r:older', label: 'Older', order: 14);

  final day = DateTime(at.year, at.month, at.day);
  final today = DateTime(now.year, now.month, now.day);
  final diff = today.difference(day).inDays;

  if (diff <= 0) return (key: 'r:today', label: 'Closed today', order: 10);
  if (diff == 1) return (key: 'r:yesterday', label: 'Yesterday', order: 11);

  // OpsHub's schedule week runs Sunday → Saturday. `weekday % 7` maps Sunday to 0,
  // and the date is rebuilt through the constructor (not `subtract`) so a DST
  // shift can never land the boundary on the wrong calendar day.
  final weekStart = DateTime(
    today.year,
    today.month,
    today.day - (today.weekday % 7),
  );
  if (!day.isBefore(weekStart)) {
    return (key: 'r:week', label: 'Earlier this week', order: 12);
  }
  final lastWeekStart = DateTime(
    weekStart.year,
    weekStart.month,
    weekStart.day - 7,
  );
  if (!day.isBefore(lastWeekStart)) {
    return (key: 'r:lastweek', label: 'Last week', order: 13);
  }
  return (key: 'r:older', label: 'Older', order: 14);
}
