"use strict";

const test = require("node:test");
const assert = require("node:assert");
const {
  isTerminalTaskStatus,
  selectMissedNotifyTargets,
  resolveRecurringTaskWindow,
  shouldAutoEndRecurringTask,
} = require("../recurring_task_deadline");

const MINUTE_MS = 60 * 1000;
const HOUR_MS = 60 * MINUTE_MS;
const WEEK_START = Date.UTC(2026, 6, 18, 21, 0, 0); // Sun 00:00 at UTC+03:00

function schedule(overrides = {}) {
  return { weekStart: { toMillis: () => WEEK_START }, ...overrides };
}

test("morning window anchors to the persisted schedule weekStart instant", () => {
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

test("missing schedule falls back to the UTC occurrence day and current standard", () => {
  const window = resolveRecurringTaskWindow({
    occurrenceAt: Date.UTC(2026, 6, 20, 12), // Monday
    shift: "night",
  });

  assert.deepStrictEqual(window.hours, { startMinutes: 900, endMinutes: 1380 });
  assert.strictEqual(window.source, "standard");
  assert.strictEqual(window.instanceDateMs, Date.UTC(2026, 6, 20));
  assert.strictEqual(window.startsAtMs, Date.UTC(2026, 6, 20, 15));
  assert.strictEqual(window.deadlineMs, Date.UTC(2026, 6, 20, 23));
});

test("auto-end eligibility only allows live generated pending/started tasks at deadline", () => {
  const nowMs = Date.UTC(2026, 6, 20, 16, 30);
  const eligible = {
    sourceTemplateId: "routine-1",
    status: "pending",
    deadlineMs: nowMs,
    nowMs,
  };
  assert.strictEqual(shouldAutoEndRecurringTask(eligible), true, "boundary is due");
  assert.strictEqual(
    shouldAutoEndRecurringTask({ ...eligible, status: "started", deadlineMs: nowMs - 1 }),
    true,
  );
  assert.strictEqual(
    shouldAutoEndRecurringTask({ ...eligible, sourceTemplateId: "   " }),
    false,
  );
  assert.strictEqual(
    shouldAutoEndRecurringTask({ ...eligible, status: "waitingReview" }),
    false,
  );
  assert.strictEqual(
    shouldAutoEndRecurringTask({ ...eligible, archivedAt: { toMillis: () => nowMs - 1 } }),
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
    deadlineMs: nowMs - 1,
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
