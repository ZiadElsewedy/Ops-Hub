"use strict";

const test = require("node:test");
const assert = require("node:assert/strict");
const {
  REMINDER_LOOKBACK_DAYS,
  isReminderEligibleStatus,
  reminderDueKind,
  reminderInQuietHours,
  reminderWindowFloorMs,
  shouldRemindTask,
} = require("../task_reminders");
const { businessHourOf } = require("../recurring_task_deadline");

const HOUR_MS = 60 * 60 * 1000;
const DAY_MS = 24 * HOUR_MS;

// The shipped defaults in `runTaskReminders` when `reminderConfig/global` is absent.
const CFG = Object.freeze({
  enabled: true,
  quietStartHour: 22,
  quietEndHour: 7,
  maxReminders: 3,
});

/** A reminder decision at [businessHour] with no prior ledger entry. */
function kindAt(deadline, now, businessHour, overrides = {}) {
  return reminderDueKind(
    deadline,
    now,
    overrides.lastKind ?? null,
    overrides.count ?? 0,
    { ...CFG, ...(overrides.cfg || {}) },
    businessHour,
    overrides.windowMinutes ?? null,
  );
}

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

// ── Quiet hours are the STAFF's wall clock, not UTC (2026-08-05) ──────────
//
// `runTaskReminders` evaluated quiet hours with `now.getUTCHours()`. Egypt runs
// UTC+2/UTC+3, so the default 22→07 window actually landed at 00:00–09:00 Cairo:
// it muted the 08:30 morning-shift start — exactly when a due-soon reminder is
// worth sending — while allowing a 23:30 ping. These pin the Cairo reading.

test("the default quiet window covers the night, not the morning shift start", () => {
  const quiet = (h) => reminderInQuietHours(h, CFG.quietStartHour, CFG.quietEndHour);

  // 08:30 is the standard morning shift start; the hour around it must be loud.
  assert.equal(quiet(8), false, "the morning shift start must never be muted");
  assert.equal(quiet(7), false, "the window ends at 07:00, exclusive");
  assert.equal(quiet(9), false);
  assert.equal(quiet(15), false, "the night shift start is loud too");

  // And the genuine night hours must be quiet.
  for (const h of [22, 23, 0, 3, 6]) {
    assert.equal(quiet(h), true, `${h}:00 Cairo should be quiet`);
  }
});

test("the UTC reading of the same window would have muted the morning shift", () => {
  // The regression, stated as the bug it was: at 08:00 Cairo (DST) the UTC hour
  // is 05:00, which falls inside 22→07 — so the old code went quiet.
  const cairo0800 = Date.parse("2026-08-05T05:00:00Z");
  assert.equal(businessHourOf(cairo0800), 8);
  assert.equal(new Date(cairo0800).getUTCHours(), 5);

  assert.equal(reminderInQuietHours(5, 22, 7), true, "the old UTC reading: muted");
  assert.equal(reminderInQuietHours(8, 22, 7), false, "the Cairo reading: sends");
});

test("a quiet window with equal ends means no quiet hours at all", () => {
  for (let h = 0; h < 24; h++) {
    assert.equal(reminderInQuietHours(h, 0, 0), false);
  }
});

test("quiet hours suppress a reminder that is otherwise due", () => {
  const now = new Date("2026-08-05T05:00:00Z");
  const deadline = new Date(now.getTime() + 30 * 60 * 1000); // due in 30m

  assert.equal(kindAt(deadline, now, 8), "due1h", "08:00 Cairo sends");
  assert.equal(kindAt(deadline, now, 3), null, "03:00 Cairo stays silent");
});

test("an unresolvable business hour fails OPEN rather than muting the estate", () => {
  // A timezone lookup that returns null must not become a silent global mute —
  // that would reproduce the outage this whole pass exists to prevent.
  const now = new Date("2026-08-05T05:00:00Z");
  const deadline = new Date(now.getTime() + 30 * 60 * 1000);
  assert.equal(kindAt(deadline, now, null), "due1h");
});

// ── The escalation ladder (unchanged behaviour, now pinned) ───────────────

test("the ladder climbs due24h → due1h → overdue and never descends", () => {
  const now = new Date("2026-08-05T09:00:00Z");
  const in20h = new Date(now.getTime() + 20 * HOUR_MS);
  const in30m = new Date(now.getTime() + 30 * 60 * 1000);
  const past = new Date(now.getTime() - 5 * 60 * 1000);

  assert.equal(kindAt(in20h, now, 12), "due24h");
  assert.equal(kindAt(in30m, now, 12), "due1h");
  assert.equal(kindAt(past, now, 12), "overdue");

  // Already on a rung: the same or a lower rung is not re-sent.
  assert.equal(kindAt(in20h, now, 12, { lastKind: "due24h" }), null);
  assert.equal(kindAt(in30m, now, 12, { lastKind: "due1h" }), null);
  assert.equal(kindAt(in30m, now, 12, { lastKind: "overdue" }), null);
  // But a genuine escalation still fires.
  assert.equal(kindAt(in30m, now, 12, { lastKind: "due24h" }), "due1h");
  assert.equal(kindAt(past, now, 12, { lastKind: "due1h" }), "overdue");
});

test("a deadline further out than 24h is not yet reminded", () => {
  const now = new Date("2026-08-05T09:00:00Z");
  assert.equal(kindAt(new Date(now.getTime() + 30 * HOUR_MS), now, 12), null);
});

// The reported bug: a task created during its own shift (deadline = shift end,
// a few hours out) got a "due within 24 hours" reminder on the next tick,
// because the 24h rung ignored the task's actual window. A shift-bounded task
// (window ≤ 24h) now suppresses the 24h rung; its first reminder is the 1h one.
test("a shift-bounded task (window ≤ 24h) suppresses the eager 24h rung", () => {
  const now = new Date("2026-08-11T07:30:00Z"); // 10:30 Africa/Cairo
  const shiftEnd = new Date(now.getTime() + 6 * HOUR_MS); // 16:30 Cairo, ~6h out
  const shiftWindow = 8 * 60; // 08:30–16:30 = an 8-hour window

  // Without a window it would fire due24h at creation (the old, wrong behavior)…
  assert.equal(kindAt(shiftEnd, now, 12), "due24h");
  // …but knowing the 8h window, the 24h rung is withheld.
  assert.equal(kindAt(shiftEnd, now, 12, { windowMinutes: shiftWindow }), null);

  // The 1h rung still fires near the shift end.
  const in30m = new Date(now.getTime() + 30 * 60 * 1000);
  assert.equal(kindAt(in30m, now, 12, { windowMinutes: shiftWindow }), "due1h");
  // And overdue still fires after it.
  const past = new Date(now.getTime() - 5 * 60 * 1000);
  assert.equal(kindAt(past, now, 12, { windowMinutes: shiftWindow }), "overdue");
});

test("a multi-day task (window > 24h) keeps the 24h rung", () => {
  const now = new Date("2026-08-11T07:30:00Z");
  const in20h = new Date(now.getTime() + 20 * HOUR_MS);
  const threeDayWindow = 3 * 24 * 60;
  assert.equal(kindAt(in20h, now, 12, { windowMinutes: threeDayWindow }), "due24h");
});

test("the max-reminders cap and the global disable both stop the sweep", () => {
  const now = new Date("2026-08-05T09:00:00Z");
  const past = new Date(now.getTime() - 5 * 60 * 1000);
  assert.equal(kindAt(past, now, 12, { count: 3 }), null, "cap reached");
  assert.equal(kindAt(past, now, 12, { count: 2 }), "overdue", "under the cap");
  assert.equal(kindAt(past, now, 12, { cfg: { enabled: false } }), null);
});

// ── The scan window is bounded (2026-08-05) ───────────────────────────────
//
// The query was `where("deadline", "<=", now + 24h)` with no floor, no limit and
// no status filter: every 30 minutes it re-read every task ever created with a
// past deadline. That set only grows, so the runtime only grows — until it
// exceeds the timeout and reminders stop entirely.

test("the scan floor is a bounded lookback, not the beginning of time", () => {
  const now = Date.parse("2026-08-05T09:00:00Z");
  assert.equal(REMINDER_LOOKBACK_DAYS, 7);
  assert.equal(
    reminderWindowFloorMs(now),
    now - 7 * DAY_MS,
    "the floor tracks now — it must never be a fixed epoch",
  );
  assert.ok(reminderWindowFloorMs(now) < now);
  assert.equal(reminderWindowFloorMs(now, 1), now - DAY_MS);
});

// ── Rework on a shift instance is nudged (ruled 2026-08-05) ───────────────
//
// The blanket `rejected` silence above is correct for work whose next move is
// the reviewer's. It is NOT correct for a generated shift instance, which — as
// of the same ruling — auto-fails as Missed at the shift wall. Staying silent
// there means an employee loses a task to automation without ever being told
// rework was owed.

test("a rejected GENERATED SHIFT instance is reminded, because it will auto-fail", () => {
  assert.equal(shouldRemindTask("rejected", true), true);
});

test("rejected work that no machine will close stays silent", () => {
  // The original ruling, still intact for manual / individual / team tasks.
  assert.equal(shouldRemindTask("rejected", false), false);
  assert.equal(shouldRemindTask("rejected", undefined), false);
});

test("the shift exception is narrow — it never revives a closed outcome", () => {
  // Being a generated shift task must not smuggle a terminal back into the
  // reminder sweep: those are closed, and a closed task is never nagged.
  for (const status of ["approved", "missed", "cancelled"]) {
    assert.equal(shouldRemindTask(status, true), false, `${status} stays silent`);
    assert.equal(shouldRemindTask(status, false), false);
  }
});

test("ordinary open work is reminded on both task kinds", () => {
  for (const status of ["pending", "started", undefined, ""]) {
    assert.equal(shouldRemindTask(status, true), true);
    assert.equal(shouldRemindTask(status, false), true);
  }
});
