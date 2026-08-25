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
// A persisted weekly schedule's weekStart is still used to resolve that week's
// frozen hours, but never as "today's" midnight. The automation occurrence date
// is the business civil date in Africa/Cairo (spec §12.2), rebuilt with calendar
// arithmetic so DST transitions cannot shift a slot by one hour.

const MINUTE_MS = 60 * 1000;

// Automated Tasks spec §12.2: OpsHub operates in Egypt only, on one timezone.
// A multi-timezone estate must revisit this constant and the deterministic key
// convention before expanding.
const BUSINESS_TIME_ZONE = "Africa/Cairo";

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

const BUSINESS_DAY_FORMATTER = new Intl.DateTimeFormat("en-US", {
  timeZone: BUSINESS_TIME_ZONE,
  weekday: "long",
  year: "numeric",
  month: "2-digit",
  day: "2-digit",
});

const BUSINESS_DATE_TIME_FORMATTER = new Intl.DateTimeFormat("en-US", {
  timeZone: BUSINESS_TIME_ZONE,
  hourCycle: "h23",
  year: "numeric",
  month: "2-digit",
  day: "2-digit",
  hour: "2-digit",
  minute: "2-digit",
  second: "2-digit",
});

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

function two(n) {
  return String(n).padStart(2, "0");
}

function dateKey(year, month, day) {
  return `${year}-${two(month)}-${two(day)}`;
}

function partsMap(formatter, ms) {
  return Object.fromEntries(
    formatter.formatToParts(new Date(ms))
      .filter((part) => part.type !== "literal")
      .map((part) => [part.type, part.value]),
  );
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

function businessDateTimeParts(value) {
  const ms = toEpochMs(value);
  if (ms == null) return null;
  const parts = partsMap(BUSINESS_DATE_TIME_FORMATTER, ms);
  return {
    year: Number(parts.year),
    month: Number(parts.month),
    day: Number(parts.day),
    hour: Number(parts.hour),
    minute: Number(parts.minute),
    second: Number(parts.second),
  };
}

function offsetMsForBusinessInstant(value) {
  const parts = businessDateTimeParts(value);
  if (!parts) return null;
  const asUtcMs = Date.UTC(
    parts.year,
    parts.month - 1,
    parts.day,
    parts.hour,
    parts.minute,
    parts.second,
  );
  return asUtcMs - toEpochMs(value);
}

/**
 * The hour-of-day (0–23) at [value] in the business timezone.
 *
 * Anything that gates on "what time is it for the staff" must use this, never
 * `Date#getUTCHours()`: Egypt runs UTC+2/UTC+3, so a UTC hour is 2–3 hours
 * behind the wall clock the rule was written against. Returns null for an
 * unparseable value so callers can fail open rather than guess.
 */
function businessHourOf(value) {
  const parts = businessDateTimeParts(value);
  return parts ? parts.hour : null;
}

function businessDayParts(value) {
  const ms = toEpochMs(value);
  if (ms == null) return null;
  const parts = partsMap(BUSINESS_DAY_FORMATTER, ms);
  const year = Number(parts.year);
  const month = Number(parts.month);
  const day = Number(parts.day);
  const dayName = String(parts.weekday || "").toLowerCase();
  const dayIndex = DAY_INDEX[dayName];
  if (
    !Number.isInteger(year) ||
    !Number.isInteger(month) ||
    !Number.isInteger(day) ||
    dayIndex == null
  ) {
    return null;
  }
  return {
    year,
    month,
    day,
    dateKey: dateKey(year, month, day),
    dayName,
    isoWeekday: dayIndex === 0 ? 7 : dayIndex,
  };
}

function businessCivilMidnightMs(year, month, day) {
  const utcCivilMidnight = Date.UTC(year, month - 1, day);
  const firstOffset = offsetMsForBusinessInstant(utcCivilMidnight);
  if (firstOffset == null) return null;
  const candidate = utcCivilMidnight - firstOffset;
  const correctedOffset = offsetMsForBusinessInstant(candidate);
  if (correctedOffset == null) return null;
  return utcCivilMidnight - correctedOffset;
}

function businessCivilTimeMs(year, month, day, minutesAfterMidnight) {
  const wholeDays = Math.floor(minutesAfterMidnight / 1440);
  const minuteOfDay = minutesAfterMidnight - wholeDays * 1440;
  const hour = Math.floor(minuteOfDay / 60);
  const minute = minuteOfDay % 60;
  const utcCivilTime = Date.UTC(year, month - 1, day + wholeDays, hour, minute);
  const firstOffset = offsetMsForBusinessInstant(utcCivilTime);
  if (firstOffset == null) return null;
  const candidate = utcCivilTime - firstOffset;
  const correctedOffset = offsetMsForBusinessInstant(candidate);
  if (correctedOffset == null) return null;
  return utcCivilTime - correctedOffset;
}

function businessWeekStartKey(value) {
  const parts = businessDayParts(value);
  if (!parts) return null;
  const sunday = new Date(Date.UTC(
    parts.year,
    parts.month - 1,
    parts.day - DAY_INDEX[parts.dayName],
  ));
  return dateKey(
    sunday.getUTCFullYear(),
    sunday.getUTCMonth() + 1,
    sunday.getUTCDate(),
  );
}

/**
 * Resolves the exact window for a recurring shift occurrence.
 *
 * `day` should be the generator's canonical lower-case business day name when a
 * schedule is available. Without it, the occurrence's Africa/Cairo civil day is
 * used. The returned window is anchored to that occurrence's business midnight,
 * while `schedule.weekStart` affects only the frozen hours lookup.
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
  const occurrenceDay = businessDayParts(occurrenceMs);
  if (!occurrenceDay) return null;

  const resolvedDay = normalizeDay(day) || occurrenceDay.dayName;
  const resolvedShift = normalizeShift(shift);
  const hours = resolveShiftHours({ schedule, day: resolvedDay, shift: resolvedShift });
  const slotMidnightMs = businessCivilMidnightMs(
    occurrenceDay.year,
    occurrenceDay.month,
    occurrenceDay.day,
  );
  if (slotMidnightMs == null) return null;
  const startsAtMs = businessCivilTimeMs(
    occurrenceDay.year,
    occurrenceDay.month,
    occurrenceDay.day,
    hours.startMinutes,
  );
  const deadlineMs = businessCivilTimeMs(
    occurrenceDay.year,
    occurrenceDay.month,
    occurrenceDay.day,
    hours.endMinutes,
  );
  if (startsAtMs == null || deadlineMs == null) return null;

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

/**
 * The deterministic document id of one routine's occurrence on one business day
 * — the whole duplicate guarantee (spec §4.2: one instance per routine per day).
 *
 * [dateKey] **must** be the Africa/Cairo business civil day (`businessDayParts`
 * ⇒ `dateKey`). There is exactly one id format, so a key derived any other way
 * does not produce "the same occurrence under an older convention" — it names a
 * DIFFERENT DAY's occurrence. A generator that probed a UTC-derived key at the
 * 01:00 Cairo tick was therefore reading yesterday's instance, finding it, and
 * skipping generation forever; see the tests pinning this.
 *
 * Mirrored client-side by `TaskCubit._materializeTodayInstance`.
 */
function recurringInstanceId(templateId, dateKey) {
  return `rt_${templateId}_${dateKey}`;
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
 * The grace period between a shift task's deadline and the moment it may be
 * recorded as Missed — **a fixed, global 30 minutes**
 * ([ADR-013](../docs/decisions/ADR-013-task-grace-period.md), spec §3.6).
 *
 * It is deliberately NOT configurable: a per-branch grace would be a dial that
 * moves the headline completion rate, held by the person that rate evaluates.
 * Changing this number is a product decision with an ADR, never a setting.
 *
 * It must stay **greater than the sweep interval** (15 minutes). Below that, the
 * cron cadence becomes the de facto rule again and two employees finishing at
 * the same minute can get opposite records — the exact defect this replaced.
 *
 * Mirrored client-side by `kTaskGraceMinutes` in
 * `lib/features/task/domain/task_schedule.dart`.
 */
const TASK_GRACE_MINUTES = 30;
const TASK_GRACE_MS = TASK_GRACE_MINUTES * MINUTE_MS;

/**
 * The instant a task becomes eligible to be recorded as Missed: its deadline
 * plus the grace period. Null for a task with no resolved deadline.
 *
 * Note this is **not** the task's due time and must never be presented as one —
 * grace is a tolerance on the close. The task reads *Late* from `deadline`
 * (spec §3.1); it is simply not recorded as failed until this instant.
 */
function missedEvaluationMs(deadline) {
  const deadlineMs = toEpochMs(deadline);
  return deadlineMs == null ? null : deadlineMs + TASK_GRACE_MS;
}

/**
 * The lifecycle states a generated shift instance can be auto-closed FROM — the
 * states in which work is still owed when the shift wall arrives.
 *
 * `rejected` belongs here (ruled 2026-08-05) even though it is the reviewer who
 * sent the task back. The reasons:
 *
 * - **It is the truth.** A rejected instance at shift end is unfinished work at
 *   the shift wall — the exact thing Missed exists to record (spec §3.2).
 * - **It closed a gaming vector.** While `rejected` was excluded, the task never
 *   reached a terminal at all, so it fell out of Approved ÷ (Approved + Missed)
 *   entirely — meaning a rejection quietly *improved* a branch's completion rate
 *   versus letting the same work be missed. §10.1 requires that rate to be
 *   ungameable.
 * - **It stopped an unbounded leak.** A rejected instance never closed: it read
 *   Late forever, stayed inside `isTaskInActiveWindow` forever, and — because the
 *   shift task stream has no date filter — kept surfacing for whoever was
 *   rostered on that shift days later.
 *
 * Rework inside the window is unaffected: a task rejected at 14:00 against a
 * 16:30 wall is only evaluated at 17:00, so there is real time to redo it, and
 * resubmitting moves it to `waitingReview`, which is never auto-closed.
 *
 * `waitingReview` and `completed` stay OUT: the employee has done their part and
 * the next move is the reviewer's — auto-failing there would record an employee
 * failure for a manager's delay.
 */
const AUTO_END_ELIGIBLE_STATUSES = Object.freeze([
  "pending",
  "started",
  "rejected",
]);

/**
 * Whether a generated recurring shift task may be terminally auto-ended.
 *
 * This is intentionally conservative: only a source-template instance in one of
 * [AUTO_END_ELIGIBLE_STATUSES], live (not soft-archived), and past its deadline
 * **plus the grace period** qualifies. Review and completed lifecycle states are
 * never rewritten.
 *
 * The grace is what stops an employee who stayed to finish at 16:35 from getting
 * the same record as one who walked away at 16:00.
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
  if (!AUTO_END_ELIGIBLE_STATUSES.includes(String(status || ""))) return false;
  if (archivedAt != null) return false;

  const evaluateAtMs = missedEvaluationMs(deadlineMs ?? deadline);
  const resolvedNowMs = toEpochMs(nowMs ?? now);
  return evaluateAtMs != null &&
    resolvedNowMs != null &&
    evaluateAtMs <= resolvedNowMs;
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
  AUTO_END_ELIGIBLE_STATUSES,
  BUSINESS_TIME_ZONE,
  DAY_NAMES,
  TASK_GRACE_MINUTES,
  TASK_GRACE_MS,
  TERMINAL_TASK_STATUSES,
  businessCivilMidnightMs,
  businessDayParts,
  businessHourOf,
  businessWeekStartKey,
  isTerminalTaskStatus,
  missedEvaluationMs,
  recurringInstanceId,
  selectMissedNotifyTargets,
  standardShiftHours,
  resolveShiftHours,
  resolveRecurringTaskWindow,
  shouldAutoEndRecurringTask,
};
