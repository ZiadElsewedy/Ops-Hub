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

module.exports = {
  REMINDER_INELIGIBLE_STATUSES,
  isReminderEligibleStatus,
};
