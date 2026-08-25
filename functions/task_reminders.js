"use strict";

/**
 * Which task statuses `runTaskReminders` will still nag the assignee about.
 *
 * This set is deliberately **its own thing** and must NOT be collapsed into
 * `isTerminalTaskStatus` (`recurring_task_deadline.js` = approved · missed ·
 * cancelled). The two answer different questions:
 *
 * - **Lifecycle:** a `rejected` task is still OPEN — rework is owed.
 * - **Reminders:** on a `rejected` task the *reviewer* owns the next move, so
 *   reminding the assignee is noise.
 *
 * So `rejected` is reminder-ineligible while staying lifecycle-open, and
 * swapping in the canonical helper would resume reminding every rejected task.
 * That trade was considered and settled — keep them separate.
 *
 * `missed` and `cancelled` are here because a closed task must never generate a
 * "Task Late" reminder for work that is already over or explicitly void
 * (Automated Tasks spec §8 — Cancelled counts nowhere).
 *
 * `completed` / `waitingReview` stay reminder-ELIGIBLE. That is an open product
 * question, not an oversight — do not "fix" it without a ruling.
 */
const REMINDER_INELIGIBLE_STATUSES = Object.freeze([
  "approved",
  "rejected",
  "missed",
  "cancelled",
]);

/** Whether a task in [status] should still receive assignee reminders. */
function isReminderEligibleStatus(status) {
  return !REMINDER_INELIGIBLE_STATUSES.includes(String(status || "pending"));
}

/**
 * Whether a task should be reminded, given its [status] and whether it is a
 * generated shift instance ([isGeneratedShiftTask] — `assignmentType == "shift"`
 * with a `sourceTemplateId`).
 *
 * This is [isReminderEligibleStatus] plus **one narrow exception**, ruled
 * 2026-08-05 together with making `rejected` auto-closable:
 *
 * A rejected task normally stays silent because the *reviewer* owns the next
 * move (see the block above — that ruling stands for manual, individual and team
 * work). A generated shift instance is different in one decisive way: it now
 * **auto-fails at the shift wall**. Staying silent there would let an employee
 * lose a task to Missed without ever being told that rework was owed — the
 * automated equivalent of failing someone for a message you chose not to send.
 *
 * Deliberately narrow. Rejected manual work is still silent; only an instance
 * that a machine will close against a hard deadline earns the nudge.
 */
function shouldRemindTask(status, isGeneratedShiftTask) {
  const s = String(status || "pending");
  if (s === "rejected") return isGeneratedShiftTask === true;
  return isReminderEligibleStatus(s);
}

// The escalation ladder. A task climbs it in order and never descends.
const REMINDER_ORDER = Object.freeze(["due24h", "due1h", "overdue"]);

/**
 * How far back the reminder scan looks.
 *
 * The scan used to be `where("deadline", "<=", now + 24h)` with no lower bound,
 * no status filter and no limit — so every 30 minutes it re-read EVERY task ever
 * created with a past deadline, approved and cancelled ones included. That set
 * only grows, so the run time only grows, until it exceeds the function timeout
 * and takes reminders down with it.
 *
 * A floor is safe because the ladder tops out at `overdue` and the per-task
 * ledger caps the total count: a task older than this has already had every
 * reminder it will ever get. Seven days is generous cover for a weekend plus an
 * outage.
 */
const REMINDER_LOOKBACK_DAYS = 7;

/** The oldest deadline the scan will consider at [nowMs]. */
function reminderWindowFloorMs(nowMs, lookbackDays = REMINDER_LOOKBACK_DAYS) {
  return nowMs - lookbackDays * 24 * 60 * 60 * 1000;
}

/**
 * Whether [hour] falls inside the quiet window [startHour, endHour).
 *
 * **[hour] must be the hour in the BUSINESS timezone**, not UTC. It was UTC for
 * one release, which put the default 22→07 window at 00:00–09:00 Cairo: it
 * blacked out the 08:30 morning-shift start (exactly when a due-soon reminder
 * matters) while happily allowing a 23:30 ping. Resolve it with
 * `businessHourOf` in `recurring_task_deadline.js`.
 *
 * A window whose ends are equal is "no quiet hours", not "always quiet".
 */
function reminderInQuietHours(hour, startHour, endHour) {
  if (startHour === endHour) return false;
  if (startHour < endHour) return hour >= startHour && hour < endHour;
  return hour >= startHour || hour < endHour; // wraps midnight
}

/**
 * Which reminder (if any) [deadline] is owed at [now], given the ledger's
 * [lastKind] / [count] and the config [cfg].
 *
 * [businessHour] is the current hour on the staff's wall clock — see
 * `reminderInQuietHours`. Passing null (unresolvable) fails OPEN: a timezone
 * lookup failure must not silently mute every reminder in the estate.
 *
 * Returns null when nothing is owed, else `due24h` | `due1h` | `overdue`.
 */
function reminderDueKind(deadline, now, lastKind, count, cfg, businessHour, windowMinutes = null) {
  if (!cfg.enabled) return null;
  if (count >= cfg.maxReminders) return null;
  if (
    businessHour != null &&
    reminderInQuietHours(businessHour, cfg.quietStartHour, cfg.quietEndHour)
  ) {
    return null;
  }
  const diffMs = deadline.getTime() - now.getTime();
  let kind;
  if (diffMs < 0) kind = "overdue";
  else if (diffMs <= 60 * 60 * 1000) kind = "due1h";
  else if (diffMs <= 24 * 60 * 60 * 1000) {
    // The 24h rung is a full DAY'S advance notice, meaningful only for a task
    // whose window spans more than a day ("due tomorrow", "due next week"). A
    // shift-bounded / same-day task ([windowMinutes] = dueAt − startsAt ≤ 24h)
    // is created INSIDE its own window, so this rung fired "due within 24 hours"
    // the moment it was created and misread the shift as a day — the reported
    // bug. Suppress it for such tasks: they still get `due1h` near the deadline
    // (e.g. an hour before the shift ends) and `overdue` after. A task with no
    // known window (no startsAt) keeps the 24h rung — its horizon is open.
    if (windowMinutes != null && windowMinutes <= 24 * 60) return null;
    kind = "due24h";
  } else return null;
  // Only escalate forward.
  if (lastKind && REMINDER_ORDER.indexOf(kind) <= REMINDER_ORDER.indexOf(lastKind)) {
    return null;
  }
  return kind;
}

module.exports = {
  REMINDER_INELIGIBLE_STATUSES,
  REMINDER_LOOKBACK_DAYS,
  REMINDER_ORDER,
  isReminderEligibleStatus,
  reminderDueKind,
  reminderInQuietHours,
  reminderWindowFloorMs,
  shouldRemindTask,
};
