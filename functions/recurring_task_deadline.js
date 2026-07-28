"use strict";

// Pure time-window and expiry decisions for generated recurring shift tasks.
//
// The task generator is responsible for Firestore I/O and converts these epoch
// milliseconds to Timestamps. Keeping the policy here means the generator and
// the auto-end sweep share the exact same, unit-tested definition of a shift
// window without importing Firebase.
//
// Hours resolve exactly as WeeklyScheduleEntity.hoursFor does in Flutter:
//   1. this week's per-slot shiftHours override;
//   2. this week's frozen shiftPlan;
//   3. the current business standard.
//
// A persisted weekly schedule's weekStart is an *instant*, not a date string.
// When it is available, it remains the anchor for the slot's local midnight;
// rebuilding midnight with Date.UTC would move a schedule created in a
// non-UTC timezone. A missing/legacy schedule intentionally falls back to UTC
// because the recurring engine's deterministic occurrence key is UTC.

const MINUTE_MS = 60 * 1000;
const DAY_MS = 24 * 60 * MINUTE_MS;

const DAY_NAMES = [
  "sunday",
  "monday",
  "tuesday",
  "wednesday",
  "thursday",
  "friday",
  "saturday",
];

const DAY_INDEX = Object.freeze(
  Object.fromEntries(DAY_NAMES.map((name, index) => [name, index])),
);

function isWeekendDay(day) {
  return day === "thursday" || day === "friday" || day === "saturday";
}

// Mirrors ShiftHours.standard in lib/features/schedule/domain/shift_hours.dart.
function standardShiftHours(day, shift) {
  if (shift !== "night") return { startMinutes: 8 * 60 + 30, endMinutes: 16 * 60 + 30 };
  return isWeekendDay(day)
    ? { startMinutes: 16 * 60, endMinutes: 24 * 60 }
    : { startMinutes: 15 * 60, endMinutes: 23 * 60 };
}

function normalizeDay(day) {
  if (typeof day !== "string") return null;
  const normalized = day.trim().toLowerCase();
  return Object.hasOwn(DAY_INDEX, normalized) ? normalized : null;
}

function normalizeShift(shift) {
  return String(shift || "").trim().toLowerCase() === "night"
    ? "night"
    : "morning";
}

// Accepts persisted `{ start, end }` and the camel-case shape used in a few
// in-memory callers. It deliberately shares Dart's safety bounds: starts are
// within the day and a shift may end up to 12 hours into the following day.
function parseHours(raw) {
  if (!raw || typeof raw !== "object") return null;
  const start = Number(raw.start ?? raw.startMinutes);
  const end = Number(raw.end ?? raw.endMinutes);
  if (!Number.isInteger(start) || !Number.isInteger(end)) return null;
  if (start < 0 || start >= 1440 || end <= start || end > 1440 + 720) return null;
  return { startMinutes: start, endMinutes: end };
}

function planHoursForSlot(shiftPlan, day, shift) {
  if (!shiftPlan || typeof shiftPlan !== "object") return null;
  if (shift === "morning") return parseHours(shiftPlan.morning);
  return parseHours(isWeekendDay(day) ? shiftPlan.weekendNight : shiftPlan.weekdayNight);
}

/**
 * Resolves one slot's concrete hours. The source is returned for observability
 * and tests; callers should use the minute values, never duplicate this order.
 */
function resolveShiftHours({ schedule = null, day, shift } = {}) {
  const resolvedDay = normalizeDay(day);
  if (!resolvedDay) return null;
  const resolvedShift = normalizeShift(shift);
  const override = parseHours(
    schedule && schedule.shiftHours && schedule.shiftHours[resolvedDay]
      ? schedule.shiftHours[resolvedDay][resolvedShift]
      : null,
  );
  if (override) return { ...override, source: "shiftHours" };

  const planned = planHoursForSlot(
    schedule && schedule.shiftPlan,
    resolvedDay,
    resolvedShift,
  );
  if (planned) return { ...planned, source: "shiftPlan" };

  return { ...standardShiftHours(resolvedDay, resolvedShift), source: "standard" };
}

// Converts the values the function reads from Firestore (Timestamp-like), plus
// Date/number/string test inputs, into an epoch value without a Firebase import.
function toEpochMs(value) {
  if (value == null) return null;
  if (typeof value === "number") return Number.isFinite(value) ? value : null;
  if (value instanceof Date) {
    const ms = value.getTime();
    return Number.isFinite(ms) ? ms : null;
  }
  if (typeof value === "object" && typeof value.toMillis === "function") {
    try {
      const ms = value.toMillis();
      return typeof ms === "number" && Number.isFinite(ms) ? ms : null;
    } catch (_) {
      return null;
    }
  }
  if (typeof value === "object" && typeof value.toDate === "function") {
    try {
      return toEpochMs(value.toDate());
    } catch (_) {
      return null;
    }
  }
  if (typeof value === "string") {
    const ms = Date.parse(value);
    return Number.isFinite(ms) ? ms : null;
  }
  return null;
}

function utcDayFor(occurrenceMs) {
  return DAY_NAMES[new Date(occurrenceMs).getUTCDay()];
}

function utcMidnightFor(occurrenceMs) {
  const occurrence = new Date(occurrenceMs);
  return Date.UTC(
    occurrence.getUTCFullYear(),
    occurrence.getUTCMonth(),
    occurrence.getUTCDate(),
  );
}

/**
 * Resolves the exact window for a recurring shift occurrence.
 *
 * `day` should be the generator's canonical lower-case day name when a
 * schedule is available. It avoids reinterpreting a branch-local calendar day
 * through the Cloud Function host timezone. Without it, the UTC occurrence day
 * is used, matching the existing deterministic `rt_{template}_{yyyy-MM-dd}`
 * convention.
 *
 * Returns null for an invalid occurrence rather than guessing with Date.now().
 * All returned values are epoch milliseconds so this helper stays Firebase-free.
 */
function resolveRecurringTaskWindow({
  schedule = null,
  occurrenceAt = null,
  occurrenceDate = null,
  day = null,
  shift = "morning",
} = {}) {
  const occurrenceMs = toEpochMs(occurrenceAt ?? occurrenceDate);
  if (occurrenceMs == null) return null;

  const resolvedDay = normalizeDay(day) || utcDayFor(occurrenceMs);
  const resolvedShift = normalizeShift(shift);
  const hours = resolveShiftHours({ schedule, day: resolvedDay, shift: resolvedShift });
  const weekStartMs = toEpochMs(schedule && schedule.weekStart);
  const slotMidnightMs = weekStartMs == null
    ? utcMidnightFor(occurrenceMs)
    : weekStartMs + DAY_INDEX[resolvedDay] * DAY_MS;
  const startsAtMs = slotMidnightMs + hours.startMinutes * MINUTE_MS;
  const deadlineMs = slotMidnightMs + hours.endMinutes * MINUTE_MS;

  return {
    // The task schema calls these startsAt/deadline; the `Ms` suffix keeps the
    // pure helper explicit about its Firebase-free values.
    startsAtMs,
    deadlineMs,
    instanceDateMs: slotMidnightMs,
    day: resolvedDay,
    shift: resolvedShift,
    hours: {
      startMinutes: hours.startMinutes,
      endMinutes: hours.endMinutes,
    },
    source: hours.source,
  };
}

// The closed lifecycle outcomes (Automated Tasks spec §2). Mirrors
// `TaskStatus.isTerminal` in lib/core/enums/task_status.dart.
const TERMINAL_TASK_STATUSES = Object.freeze([
  "approved",
  "missed",
  "cancelled",
]);

/**
 * Whether a task has already reached a closed outcome.
 *
 * "Terminal tasks are never resurrected" (§4.4): once today's instance exists in
 * a terminal state, no retry, regeneration **or repair** may recreate, reopen or
 * overwrite it. Generation for a day is spent the moment that day's instance
 * exists in any state, and this is the guard that keeps a well-meaning backfill
 * from writing to a record whose story is already over.
 */
function isTerminalTaskStatus(status) {
  return TERMINAL_TASK_STATUSES.includes(String(status || ""));
}

/**
 * Whether a generated recurring shift task may be terminally auto-ended.
 *
 * This is intentionally conservative: only a source-template instance that is
 * still pending/started, live (not soft-archived), and at/past a real deadline
 * qualifies. Review and completed lifecycle states are never rewritten.
 */
function shouldAutoEndRecurringTask({
  sourceTemplateId,
  status,
  archivedAt = null,
  deadline = null,
  deadlineMs = null,
  now = null,
  nowMs = null,
} = {}) {
  if (typeof sourceTemplateId !== "string" || sourceTemplateId.trim().length === 0) {
    return false;
  }
  if (status !== "pending" && status !== "started") return false;
  if (archivedAt != null) return false;

  const resolvedDeadlineMs = toEpochMs(deadlineMs ?? deadline);
  const resolvedNowMs = toEpochMs(nowMs ?? now);
  return resolvedDeadlineMs != null &&
    resolvedNowMs != null &&
    resolvedDeadlineMs <= resolvedNowMs;
}

/**
 * Who is told that a generated shift task was auto-closed as Missed.
 *
 * The spec routes this to **the branch manager** (§9.1) — the point being that
 * an automatic failure must reach a human rather than dying in the audit log.
 * A branch with no active manager would therefore be silent again, which is the
 * exact gap this notification exists to close, so admins are the **fallback**
 * (not an addition — a manager-covered branch never pages an admin, or every
 * miss in the estate would land in the same inbox and stop being read).
 *
 * Both lists are uid arrays. Returns a de-duplicated array, possibly empty when
 * the estate has neither — valid, and never an error.
 */
function selectMissedNotifyTargets({ managers = [], admins = [] } = {}) {
  const clean = (list) => [
    ...new Set(
      (Array.isArray(list) ? list : [])
        .map((uid) => String(uid || "").trim())
        .filter((uid) => uid.length > 0),
    ),
  ];
  const branchManagers = clean(managers);
  return branchManagers.length > 0 ? branchManagers : clean(admins);
}

module.exports = {
  DAY_NAMES,
  TERMINAL_TASK_STATUSES,
  isTerminalTaskStatus,
  selectMissedNotifyTargets,
  standardShiftHours,
  resolveShiftHours,
  resolveRecurringTaskWindow,
  shouldAutoEndRecurringTask,
};
