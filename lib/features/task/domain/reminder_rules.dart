/// Pure, deterministic decision logic for automated **task reminders**
/// (Communications Center — Phase 2 Commit 5). The `runTaskReminders` Cloud
/// Function mirrors this exactly; keeping it here as pure Dart lets the anti-spam
/// + quiet-hours + escalation rules be unit-tested.
///
/// Reminder kinds escalate forward: `due24h` → `due1h` → `overdue`. Each kind is
/// sent at most once per task; the escalation never goes backwards; quiet hours
/// and a `maxReminders` cap prevent spam.
class ReminderRules {
  const ReminderRules._();

  /// The escalation order (low → high).
  static const List<String> order = ['due24h', 'due1h', 'overdue'];

  /// The reminder kind to send for a task with [deadline] at [now], given the
  /// last-sent [lastKind] and total [reminderCount] so far — or `null` when no
  /// reminder is warranted (disabled, capped, quiet hours, not yet due, or the
  /// applicable kind was already sent).
  static String? dueKind({
    required DateTime deadline,
    required DateTime now,
    String? lastKind,
    int reminderCount = 0,
    int maxReminders = 3,
    int quietStartHour = 22,
    int quietEndHour = 7,
    bool enabled = true,

    /// The task's scheduled window (`dueAt − startsAt`), when known. A
    /// shift-bounded / same-day task (window ≤ 24h) suppresses the coarse 24h
    /// rung so its first reminder is the 1h one near the deadline, not one fired
    /// at creation. Null (no `startsAt`) keeps the 24h rung.
    Duration? scheduledWindow,
  }) {
    if (!enabled) return null;
    if (reminderCount >= maxReminders) return null;
    if (inQuietHours(now.hour, quietStartHour, quietEndHour)) return null;

    final diff = deadline.difference(now);
    final String kind;
    if (diff.isNegative) {
      kind = 'overdue';
    } else if (diff <= const Duration(hours: 1)) {
      kind = 'due1h';
    } else if (diff <= const Duration(hours: 24)) {
      // The 24h rung is a full day's advance notice — meaningful only for a
      // task whose window spans more than a day. A shift-bounded / same-day
      // task is created inside its own window, so this rung would fire "due
      // within 24 hours" at creation and misread the shift as a day. Suppress
      // it; the task still gets `due1h` near its deadline and `overdue` after.
      if (scheduledWindow != null &&
          scheduledWindow <= const Duration(hours: 24)) {
        return null;
      }
      kind = 'due24h';
    } else {
      return null; // more than 24h out — nothing to send
    }

    // Only escalate forward; never resend the same or an earlier kind.
    if (!_isAfter(kind, lastKind)) return null;
    return kind;
  }

  /// The notification `type` name for a reminder [kind] (mirrors
  /// `NotificationType`): an overdue reminder is `taskOverdue`, the rest
  /// `taskReminder`.
  static String typeFor(String kind) =>
      kind == 'overdue' ? 'taskOverdue' : 'taskReminder';

  static bool _isAfter(String kind, String? last) {
    if (last == null) return true;
    return order.indexOf(kind) > order.indexOf(last);
  }

  /// Whether [hour] (0–23) falls inside the quiet window, which may wrap
  /// midnight (e.g. 22 → 7). A zero-length window (`start == end`) is never quiet.
  static bool inQuietHours(int hour, int startHour, int endHour) {
    if (startHour == endHour) return false;
    if (startHour < endHour) return hour >= startHour && hour < endHour;
    return hour >= startHour || hour < endHour; // wraps midnight
  }
}
