"use strict";

const test = require("node:test");
const assert = require("node:assert");
const {
  AUTO_END_ELIGIBLE_STATUSES,
  BUSINESS_TIME_ZONE,
  TASK_GRACE_MINUTES,
  businessCivilMidnightMs,
  businessDayParts,
  businessHourOf,
  businessWeekStartKey,
  isTerminalTaskStatus,
  missedEvaluationMs,
  recurringInstanceId,
  selectMissedNotifyTargets,
  resolveRecurringTaskWindow,
  shouldAutoEndRecurringTask,
} = require("../recurring_task_deadline");

// The exact instants Cloud Scheduler fires `generateShiftTaskInstances` on
// (`schedule: "0 1 * * *"`, `timeZone: "Africa/Cairo"`) for four consecutive
// days — two on DST (UTC+03:00), two on standard time (UTC+02:00).
const CAIRO_0100_TICKS_DST = [
  Date.parse("2026-08-03T22:00:00Z"), // 01:00 Cairo, Tue 2026-08-04
  Date.parse("2026-08-04T22:00:00Z"), // 01:00 Cairo, Wed 2026-08-05
  Date.parse("2026-08-05T22:00:00Z"), // 01:00 Cairo, Thu 2026-08-06
];
const CAIRO_0100_TICK_STANDARD = Date.parse("2026-01-14T23:00:00Z"); // Thu 2026-01-15

// What the deleted transition guard computed: the HOST's UTC calendar date.
function utcDateKey(ms) {
  const d = new Date(ms);
  const two = (n) => String(n).padStart(2, "0");
  return `${d.getUTCFullYear()}-${two(d.getUTCMonth() + 1)}-${two(d.getUTCDate())}`;
}

const MINUTE_MS = 60 * 1000;
const GRACE_MS = TASK_GRACE_MINUTES * MINUTE_MS;
const HOUR_MS = 60 * MINUTE_MS;
const WEEK_START = Date.UTC(2026, 6, 18, 21, 0, 0); // Sun 00:00 at UTC+03:00

function schedule(overrides = {}) {
  return { weekStart: { toMillis: () => WEEK_START }, ...overrides };
}

test("business day parts use the Cairo civil date, not the UTC date", () => {
  assert.strictEqual(BUSINESS_TIME_ZONE, "Africa/Cairo");
  assert.deepStrictEqual(
    businessDayParts(Date.parse("2026-07-30T22:30:00Z")),
    {
      year: 2026,
      month: 7,
      day: 31,
      dateKey: "2026-07-31",
      dayName: "friday",
      isoWeekday: 5,
    },
  );
});

// ── The generation-key invariant (P0 regression, 2026-08-05) ──────────────
//
// A "temporary UTC→business-key transition guard" in `generateShiftTaskInstances`
// probed `rt_{templateId}_{utcDateKey}` before creating and skipped when it
// existed. At the 01:00 Cairo tick the UTC date is ALWAYS the previous day, and
// both keys share one id format — so it was reading yesterday's ordinary
// instance. For every DAILY routine it found one, recorded
// `skipped / alreadyExists`, and created nothing. Silently, with the Automation
// Center reporting "Already generated" and `failureCount` at 0.
//
// These tests pin the two facts that make any such probe wrong.

test("at the 01:00 Cairo tick the UTC date is always the PREVIOUS business day", () => {
  for (const tick of [...CAIRO_0100_TICKS_DST, CAIRO_0100_TICK_STANDARD]) {
    const businessKey = businessDayParts(tick).dateKey;
    assert.notStrictEqual(
      utcDateKey(tick),
      businessKey,
      "a UTC-derived key at this tick is never the business day",
    );
    const yesterday = businessDayParts(tick - 24 * HOUR_MS).dateKey;
    assert.strictEqual(
      utcDateKey(tick),
      yesterday,
      "it is precisely yesterday's key — which is why probing it skipped forever",
    );
  }
});

test("consecutive daily ticks produce distinct instance ids", () => {
  const ids = CAIRO_0100_TICKS_DST.map((tick) =>
    recurringInstanceId("tpl1", businessDayParts(tick).dateKey),
  );
  assert.deepStrictEqual(ids, [
    "rt_tpl1_2026-08-04",
    "rt_tpl1_2026-08-05",
    "rt_tpl1_2026-08-06",
  ]);
  assert.strictEqual(new Set(ids).size, ids.length, "no day may reuse an id");

  // The collision the guard walked into: the UTC key at day N's tick builds
  // exactly day N-1's id, so `create()` on it would always lose.
  assert.strictEqual(
    recurringInstanceId("tpl1", utcDateKey(CAIRO_0100_TICKS_DST[1])),
    ids[0],
  );
});

test("the business hour at the 01:00 Cairo tick is 1, not the UTC hour", () => {
  for (const tick of CAIRO_0100_TICKS_DST) {
    assert.strictEqual(businessHourOf(tick), 1);
    assert.strictEqual(new Date(tick).getUTCHours(), 22);
  }
  assert.strictEqual(businessHourOf(CAIRO_0100_TICK_STANDARD), 1);
  assert.strictEqual(businessHourOf("not a date"), null);
});

test("business civil midnight resolves Egypt standard time and DST", () => {
  assert.strictEqual(
    businessCivilMidnightMs(2026, 1, 15),
    Date.parse("2026-01-14T22:00:00Z"),
    "standard time is UTC+02:00",
  );
  assert.strictEqual(
    businessCivilMidnightMs(2026, 7, 15),
    Date.parse("2026-07-14T21:00:00Z"),
    "DST is UTC+03:00",
  );
});

test("business week start key is Sunday-anchored", () => {
  assert.strictEqual(
    businessWeekStartKey(Date.parse("2026-07-30T22:30:00Z")),
    "2026-07-26",
  );
  assert.strictEqual(
    businessWeekStartKey(Date.parse("2026-07-26T00:30:00Z")),
    "2026-07-26",
  );
});

test("morning window anchors to the occurrence's business midnight", () => {
  const window = resolveRecurringTaskWindow({
    schedule: schedule(),
    occurrenceAt: Date.UTC(2026, 6, 19, 10),
    day: "sunday",
    shift: "morning",
  });

  assert.deepStrictEqual(window.hours, { startMinutes: 510, endMinutes: 990 });
  assert.strictEqual(window.source, "standard");
  assert.strictEqual(window.instanceDateMs, WEEK_START);
  assert.strictEqual(window.startsAtMs, WEEK_START + 8.5 * HOUR_MS);
  assert.strictEqual(window.deadlineMs, WEEK_START + 16.5 * HOUR_MS);
});

test("per-slot shiftHours override controls the generated task window", () => {
  const window = resolveRecurringTaskWindow({
    schedule: schedule({
      shiftHours: { monday: { morning: { start: 600, end: 1080 } } },
    }),
    occurrenceAt: Date.UTC(2026, 6, 20, 9),
    day: "monday",
    shift: "morning",
  });

  assert.deepStrictEqual(window.hours, { startMinutes: 600, endMinutes: 1080 });
  assert.strictEqual(window.source, "shiftHours");
  assert.strictEqual(window.startsAtMs, WEEK_START + 24 * HOUR_MS + 10 * HOUR_MS);
  assert.strictEqual(window.deadlineMs, WEEK_START + 24 * HOUR_MS + 18 * HOUR_MS);
});

test("weekend night deadline crosses into the following local day", () => {
  const window = resolveRecurringTaskWindow({
    schedule: schedule(),
    occurrenceAt: Date.UTC(2026, 6, 23, 20),
    day: "thursday",
    shift: "night",
  });

  assert.deepStrictEqual(window.hours, { startMinutes: 960, endMinutes: 1440 });
  assert.strictEqual(window.startsAtMs, WEEK_START + 4 * 24 * HOUR_MS + 16 * HOUR_MS);
  assert.strictEqual(window.deadlineMs, WEEK_START + 5 * 24 * HOUR_MS);
});

test("hours precedence is override, then frozen shiftPlan, then standard", () => {
  const withOverride = resolveRecurringTaskWindow({
    schedule: schedule({
      shiftHours: { friday: { night: { start: 1020, end: 1500 } } },
      shiftPlan: {
        morning: { start: 420, end: 900 },
        weekdayNight: { start: 780, end: 1260 },
        weekendNight: { start: 900, end: 1410 },
      },
    }),
    occurrenceAt: Date.UTC(2026, 6, 24, 20),
    day: "friday",
    shift: "night",
  });
  assert.deepStrictEqual(withOverride.hours, { startMinutes: 1020, endMinutes: 1500 });
  assert.strictEqual(withOverride.source, "shiftHours");

  const fromPlan = resolveRecurringTaskWindow({
    schedule: schedule({
      shiftPlan: {
        morning: { start: 420, end: 900 },
        weekdayNight: { start: 780, end: 1260 },
        weekendNight: { start: 900, end: 1410 },
      },
    }),
    occurrenceAt: Date.UTC(2026, 6, 21, 20),
    day: "monday",
    shift: "night",
  });
  assert.deepStrictEqual(fromPlan.hours, { startMinutes: 780, endMinutes: 1260 });
  assert.strictEqual(fromPlan.source, "shiftPlan");
});

test("missing schedule falls back to the business occurrence day and current standard", () => {
  const window = resolveRecurringTaskWindow({
    occurrenceAt: Date.UTC(2026, 6, 20, 12), // Monday
    shift: "night",
  });

  assert.deepStrictEqual(window.hours, { startMinutes: 900, endMinutes: 1380 });
  assert.strictEqual(window.source, "standard");
  assert.strictEqual(window.instanceDateMs, Date.parse("2026-07-19T21:00:00Z"));
  assert.strictEqual(window.startsAtMs, Date.parse("2026-07-20T12:00:00Z"));
  assert.strictEqual(window.deadlineMs, Date.parse("2026-07-20T20:00:00Z"));
});

test("window midnight is not shifted by a DST transition earlier in the week", () => {
  const standardWeekStart = Date.parse("2026-04-18T22:00:00Z"); // Sun 00:00 UTC+02
  const window = resolveRecurringTaskWindow({
    schedule: schedule({ weekStart: { toMillis: () => standardWeekStart } }),
    occurrenceAt: Date.parse("2026-04-25T10:00:00Z"),
    day: "saturday",
    shift: "morning",
  });

  assert.strictEqual(window.instanceDateMs, Date.parse("2026-04-24T21:00:00Z"));
  assert.strictEqual(window.startsAtMs, Date.parse("2026-04-25T05:30:00Z"));
  assert.strictEqual(window.deadlineMs, Date.parse("2026-04-25T13:30:00Z"));
});

test("window start and deadline keep wall-clock time on DST transition days", () => {
  const spring = resolveRecurringTaskWindow({
    occurrenceAt: Date.parse("2026-04-24T10:00:00Z"),
    day: "friday",
    shift: "morning",
  });
  assert.strictEqual(spring.startsAtMs, Date.parse("2026-04-24T05:30:00Z"));
  assert.strictEqual(spring.deadlineMs, Date.parse("2026-04-24T13:30:00Z"));

  const fall = resolveRecurringTaskWindow({
    occurrenceAt: Date.parse("2026-10-29T10:00:00Z"),
    day: "thursday",
    shift: "night",
  });
  assert.strictEqual(fall.startsAtMs, Date.parse("2026-10-29T13:00:00Z"));
  assert.strictEqual(fall.deadlineMs, Date.parse("2026-10-29T22:00:00Z"));
});

test("auto-end eligibility only allows live generated pending/started tasks at deadline", () => {
  const nowMs = Date.UTC(2026, 6, 20, 16, 30);
  const eligible = {
    sourceTemplateId: "routine-1",
    status: "pending",
    deadlineMs: nowMs,
    nowMs,
  };
  // The boundary is the deadline PLUS the grace period (ADR-013), not the
  // deadline itself — a task at its raw deadline is Late, not yet Missed.
  assert.strictEqual(shouldAutoEndRecurringTask(eligible), false, "still in grace");
  assert.strictEqual(
    shouldAutoEndRecurringTask({ ...eligible, deadlineMs: nowMs - GRACE_MS }),
    true,
    "due exactly at deadline + grace",
  );
  assert.strictEqual(
    shouldAutoEndRecurringTask({
      ...eligible,
      status: "started",
      deadlineMs: nowMs - GRACE_MS - 1,
    }),
    true,
  );
  const overdue = { ...eligible, deadlineMs: nowMs - GRACE_MS };
  assert.strictEqual(
    shouldAutoEndRecurringTask({ ...overdue, sourceTemplateId: "   " }),
    false,
  );
  assert.strictEqual(
    shouldAutoEndRecurringTask({ ...overdue, status: "waitingReview" }),
    false,
  );
  assert.strictEqual(
    shouldAutoEndRecurringTask({ ...overdue, archivedAt: { toMillis: () => nowMs - 1 } }),
    false,
  );
  assert.strictEqual(
    shouldAutoEndRecurringTask({ ...eligible, deadlineMs: nowMs + 1 }),
    false,
  );
});

test("terminal statuses are the three closed outcomes", () => {
  // The set the generator's repair path and the auto-end sweep both refuse to
  // touch — "terminal tasks are never resurrected" (Automated Tasks spec §4.4).
  assert.strictEqual(isTerminalTaskStatus("approved"), true);
  assert.strictEqual(isTerminalTaskStatus("missed"), true);
  assert.strictEqual(isTerminalTaskStatus("cancelled"), true);

  for (const open of ["pending", "started", "completed", "waitingReview", "rejected"]) {
    assert.strictEqual(isTerminalTaskStatus(open), false, `${open} is still open`);
  }
  // A missing / malformed status must never read as terminal, or a legacy doc
  // would silently opt out of the sweep that closes it.
  assert.strictEqual(isTerminalTaskStatus(null), false);
  assert.strictEqual(isTerminalTaskStatus(undefined), false);
  assert.strictEqual(isTerminalTaskStatus(""), false);
});

test("a cancelled instance is never auto-ended as missed", () => {
  // Cancel vs Missed race (spec §5.7): first terminal to land wins, the other
  // becomes a no-op. The sweep re-reads status inside its transaction, so a
  // cancel that committed first leaves nothing for it to do.
  const nowMs = Date.UTC(2026, 6, 20, 16, 30);
  const base = {
    sourceTemplateId: "routine-1",
    deadlineMs: nowMs - GRACE_MS,
    nowMs,
  };
  assert.strictEqual(shouldAutoEndRecurringTask({ ...base, status: "pending" }), true);
  assert.strictEqual(
    shouldAutoEndRecurringTask({ ...base, status: "cancelled" }),
    false,
    "a cancelled task must not be rewritten to missed",
  );
  assert.strictEqual(shouldAutoEndRecurringTask({ ...base, status: "approved" }), false);
  assert.strictEqual(shouldAutoEndRecurringTask({ ...base, status: "missed" }), false);
});

test("a missed task pages the branch manager, falling back to admins", () => {
  // Spec §9.1 — the point is that an automatic failure reaches a HUMAN.
  assert.deepStrictEqual(
    selectMissedNotifyTargets({ managers: ["mgr1"], admins: ["admin1"] }),
    ["mgr1"],
    "a covered branch must not also page every admin, or the signal dies",
  );
  assert.deepStrictEqual(
    selectMissedNotifyTargets({ managers: [], admins: ["admin1", "admin2"] }),
    ["admin1", "admin2"],
    "a branch with no manager would otherwise be silent again",
  );
  // De-duplicated, blank-safe, and an empty estate is valid — not an error.
  assert.deepStrictEqual(
    selectMissedNotifyTargets({ managers: ["mgr1", "mgr1", "", "  "] }),
    ["mgr1"],
  );
  assert.deepStrictEqual(selectMissedNotifyTargets({}), []);
  assert.deepStrictEqual(selectMissedNotifyTargets(), []);
});

test("the grace period is a fixed 30 minutes, longer than the sweep interval", () => {
  // ADR-013. The number is load-bearing in two directions: it must exceed the
  // 15-minute sweep interval (or the cron cadence becomes the de facto rule
  // again, which is the defect grace replaced), and it must stay short enough
  // that a day's instance can never absorb the next shift's work.
  assert.strictEqual(TASK_GRACE_MINUTES, 30);
  assert.ok(TASK_GRACE_MINUTES > 15, "grace must outlast one sweep interval");
  assert.ok(TASK_GRACE_MINUTES < 8 * 60, "grace must not span a shift");
});

test("missed evaluation is the deadline plus grace, never the deadline", () => {
  const deadlineMs = Date.UTC(2026, 6, 20, 16, 30); // morning shift end
  assert.strictEqual(missedEvaluationMs(deadlineMs), Date.UTC(2026, 6, 20, 17, 0));
  // Accepts the Timestamp-like shapes the function reads from Firestore.
  assert.strictEqual(
    missedEvaluationMs({ toMillis: () => deadlineMs }),
    Date.UTC(2026, 6, 20, 17, 0),
  );
  // No deadline => never evaluated. A task with no due time cannot be missed.
  assert.strictEqual(missedEvaluationMs(null), null);
  assert.strictEqual(missedEvaluationMs(undefined), null);
});

test("an employee who finishes inside grace is not recorded as missed", () => {
  // The whole point of ADR-013: someone who stays to finish at 16:35 must not
  // get the same record as someone who walked away at 16:00.
  const deadlineMs = Date.UTC(2026, 6, 20, 16, 30);
  const stillOpen = {
    sourceTemplateId: "routine-1",
    status: "started",
    deadlineMs,
  };
  // 16:35 — five minutes over, still working. Late, but not failed.
  assert.strictEqual(
    shouldAutoEndRecurringTask({ ...stillOpen, nowMs: Date.UTC(2026, 6, 20, 16, 35) }),
    false,
  );
  // 16:59 — the last minute of tolerance.
  assert.strictEqual(
    shouldAutoEndRecurringTask({ ...stillOpen, nowMs: Date.UTC(2026, 6, 20, 16, 59) }),
    false,
  );
  // 17:00 — grace is spent. The cliff moved; it did not disappear.
  assert.strictEqual(
    shouldAutoEndRecurringTask({ ...stillOpen, nowMs: Date.UTC(2026, 6, 20, 17, 0) }),
    true,
  );
});

test("the weekend-night window's grace crosses into the next calendar day", () => {
  // The operational-weekend night shift ends at 00:00 (endMinutes 1440), so its
  // grace expires at 00:30 the NEXT day — the edge flagged in ADR-013. The
  // decision is a pure instant comparison, so a date rollover is not a special
  // case; this pins that so it cannot silently regress.
  const window = resolveRecurringTaskWindow({
    schedule: schedule(),
    occurrenceAt: Date.UTC(2026, 6, 23, 20),
    day: "thursday",
    shift: "night",
  });
  // Thursday's night window closes at Friday 00:00 local-to-the-schedule.
  assert.strictEqual(window.deadlineMs, WEEK_START + 5 * 24 * HOUR_MS);
  assert.strictEqual(
    missedEvaluationMs(window.deadlineMs),
    WEEK_START + 5 * 24 * HOUR_MS + 30 * MINUTE_MS,
  );

  const task = {
    sourceTemplateId: "routine-night",
    status: "pending",
    deadlineMs: window.deadlineMs,
  };
  // 00:29 next day — still inside grace.
  assert.strictEqual(
    shouldAutoEndRecurringTask({
      ...task,
      nowMs: window.deadlineMs + 29 * MINUTE_MS,
    }),
    false,
  );
  // 00:30 next day — closed, and the instance still belongs to ITS day.
  assert.strictEqual(
    shouldAutoEndRecurringTask({
      ...task,
      nowMs: window.deadlineMs + 30 * MINUTE_MS,
    }),
    true,
  );
});

// ── Rejected shift instances close at the wall (ruled 2026-08-05) ─────────
//
// `rejected` was excluded from the auto-end sweep, so a generated instance sent
// back for rework NEVER reached a terminal: Late forever, inside the active
// window forever, still surfacing for later days' crews — and, worst, absent
// from Approved ÷ (Approved + Missed) entirely, so rejecting work quietly
// improved a branch's completion rate versus letting it be missed (§10.1
// requires that rate to be ungameable).

test("a rejected generated instance is auto-ended like unfinished work", () => {
  const deadlineMs = Date.UTC(2026, 6, 20, 16, 30);
  const base = {
    sourceTemplateId: "tpl1",
    deadlineMs,
    nowMs: deadlineMs + GRACE_MS,
  };
  assert.strictEqual(
    shouldAutoEndRecurringTask({ ...base, status: "rejected" }),
    true,
    "rework still owed at the wall is unfinished work",
  );
  // ...and it obeys the same grace as every other open state.
  assert.strictEqual(
    shouldAutoEndRecurringTask({
      ...base,
      status: "rejected",
      nowMs: deadlineMs + GRACE_MS - MINUTE_MS,
    }),
    false,
    "grace applies to rework exactly as it does to pending/started",
  );
});

test("the reviewer's own states are never auto-failed", () => {
  const deadlineMs = Date.UTC(2026, 6, 20, 16, 30);
  const base = {
    sourceTemplateId: "tpl1",
    deadlineMs,
    nowMs: deadlineMs + GRACE_MS,
  };
  // The employee has done their part; the next move belongs to the manager.
  // Auto-failing here would record an employee failure for a reviewer's delay.
  for (const status of ["waitingReview", "completed"]) {
    assert.strictEqual(
      shouldAutoEndRecurringTask({ ...base, status }),
      false,
      `${status} must never be auto-closed as missed`,
    );
  }
});

test("the auto-end status set is exactly the states where work is still owed", () => {
  assert.deepStrictEqual(
    [...AUTO_END_ELIGIBLE_STATUSES],
    ["pending", "started", "rejected"],
  );
  // The sweep's Firestore query filters on this same constant. If the two ever
  // drift, the predicate accepts a status the query never fetches and those
  // tasks silently stop closing — the exact shape of the `rejected` leak.
  for (const status of AUTO_END_ELIGIBLE_STATUSES) {
    assert.strictEqual(isTerminalTaskStatus(status), false,
      "an auto-endable state must not already be terminal");
  }
});
