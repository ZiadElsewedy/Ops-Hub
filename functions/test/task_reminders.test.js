"use strict";

const test = require("node:test");
const assert = require("node:assert/strict");
const { isReminderEligibleStatus } = require("../task_reminders");

// Guards the fix for the bug where `runTaskReminders`'s terminal set was only
// {approved, rejected}: an assignee kept receiving "Task Late" pushes for work
// that had been auto-closed as Missed or explicitly Cancelled.
test("closed outcomes never receive a reminder", () => {
  for (const status of ["approved", "missed", "cancelled"]) {
    assert.equal(
      isReminderEligibleStatus(status),
      false,
      `${status} is a closed outcome and must not be reminded`,
    );
  }
});

// The one that is NOT about being closed. `rejected` is lifecycle-OPEN (rework
// is owed) but the reviewer owns the next move, so reminding the assignee is
// noise. If this test ever fails because someone swapped in the canonical
// `isTerminalTaskStatus`, that is the regression — not this assertion.
test("rejected stays reminder-ineligible even though it is lifecycle-open", () => {
  assert.equal(isReminderEligibleStatus("rejected"), false);
});

test("open assignee work is still reminded", () => {
  for (const status of ["pending", "started"]) {
    assert.equal(
      isReminderEligibleStatus(status),
      true,
      `${status} should receive reminders`,
    );
  }
});

// A task doc written before `status` existed, or carrying an empty value, must
// be treated as `pending` — the same default the scheduler's
// `t.status || "pending"` used before this helper was extracted.
test("a missing or empty status defaults to pending, and is reminded", () => {
  for (const status of [undefined, null, ""]) {
    assert.equal(isReminderEligibleStatus(status), true);
  }
});
