"use strict";

const {
  BUSINESS_TIME_ZONE,
  businessCivilMidnightMs,
  businessDayParts,
  businessWeekStartKey,
  resolveRecurringTaskWindow,
  resolveShiftHours,
} = require("./recurring_task_deadline");

const MINUTE_MS = 60 * 1000;

// Mirrors AttendanceConfig.defaults.autoCloseGraceMinutes. The scheduled
// Function imports this constant so the policy lives in the pure module.
const AUTO_CLOSE_GRACE_MINUTES = 120;

const SCHEMA_VERSION = 1;

const SCHEDULE_DAYS = Object.freeze([
  "sunday",
  "monday",
  "tuesday",
  "wednesday",
  "thursday",
  "friday",
  "saturday",
]);

const SCHEDULE_SHIFTS = Object.freeze(["morning", "night"]);

const OUTCOMES = Object.freeze({
  worked: "worked",
  workedLate: "workedLate",
  absent: "absent",
  excused: "excused",
  onLeave: "onLeave",
  openSession: "openSession",
  needsReview: "needsReview",
  noRecordYet: "noRecordYet",
});

const EXCEPTION_CODES = Object.freeze({
  late: "late",
  earlyLeave: "earlyLeave",
  overtime: "overtime",
  missingPunch: "missingPunch",
  implausibleRecord: "implausibleRecord",
  unscheduledWork: "unscheduledWork",
  pendingCorrection: "pendingCorrection",
});

const IMPLAUSIBLE_WORKED_MINUTES_FLOOR = 15;
const IMPLAUSIBLE_SCHEDULED_MINUTES_FLOOR = 240;

function two(n) {
  return String(n).padStart(2, "0");
}

function attendanceDayKey(parts) {
  if (!parts) return "";
  return `${String(parts.year).padStart(4, "0")}${two(parts.month)}${two(parts.day)}`;
}

function attendanceDocId({ uid, dayKey, shift }) {
  return `${uid}_${dayKey}_${shift}`;
}

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

function normalizeBusinessDay(value) {
  if (!value) return null;
  if (
    Number.isInteger(value.year) &&
    Number.isInteger(value.month) &&
    Number.isInteger(value.day) &&
    typeof value.dayName === "string"
  ) {
    const dayName = value.dayName.trim().toLowerCase();
    if (!SCHEDULE_DAYS.includes(dayName)) return null;
    return {
      year: value.year,
      month: value.month,
      day: value.day,
      dateKey: value.dateKey || `${value.year}-${two(value.month)}-${two(value.day)}`,
      dayName,
      isoWeekday: value.isoWeekday,
    };
  }
  return businessDayParts(value);
}

function assignedUids(schedule, day, shift) {
  const assignments = schedule && schedule.assignments;
  const raw = assignments && assignments[day] && assignments[day][shift];
  if (!Array.isArray(raw)) return [];
  return [...new Set(raw.map((uid) => String(uid || "").trim()).filter(Boolean))]
    .sort();
}

function leaveTypeFor(schedule, day, uid) {
  const leave = schedule && schedule.leave && schedule.leave[day];
  const raw = leave && leave[uid];
  return typeof raw === "string" && raw.trim() ? raw.trim() : null;
}

function recordFrom(recordsById, id) {
  if (!recordsById) return null;
  const record = recordsById instanceof Map ? recordsById.get(id) : recordsById[id];
  if (!record || record.deletedAt != null) return null;
  return record;
}

function intField(record, field) {
  const n = Number(record && record[field]);
  return Number.isFinite(n) ? Math.trunc(n) : 0;
}

function totalsFromRecord(record) {
  return {
    workedMinutes: intField(record, "workedMinutes"),
    lateMinutes: intField(record, "lateMinutes"),
    earlyLeaveMinutes: intField(record, "earlyLeaveMinutes"),
    overtimeMinutes: intField(record, "overtimeMinutes"),
    breakMinutes: intField(record, "breakMinutes"),
  };
}

function isOpenRecord(record) {
  return !!record && toEpochMs(record.clockIn) != null && toEpochMs(record.clockOut) == null;
}

function hasClockedOut(record) {
  return !!record && toEpochMs(record.clockOut) != null;
}

function recordNeedsReview(record) {
  return String((record && record.status) || "") === "pendingReview";
}

function classifyRecordOutcome(record, totals) {
  if (isOpenRecord(record)) return OUTCOMES.openSession;
  if (recordNeedsReview(record)) return OUTCOMES.needsReview;
  return totals.lateMinutes > 0 ? OUTCOMES.workedLate : OUTCOMES.worked;
}

function classifyExpectedOutcome({
  record,
  leaveType,
  scheduledEndAtMs,
  nowMs,
  graceMinutes = AUTO_CLOSE_GRACE_MINUTES,
  totals,
}) {
  if (leaveType != null) return OUTCOMES.onLeave;
  if (record && record.status === "excused") return OUTCOMES.excused;
  if (!record) {
    return nowMs < scheduledEndAtMs + graceMinutes * MINUTE_MS
      ? OUTCOMES.noRecordYet
      : OUTCOMES.absent;
  }
  if (record.status === "absent") return OUTCOMES.absent;
  if (record.status === "onLeave") return OUTCOMES.onLeave;
  return classifyRecordOutcome(record, totals);
}

function openPastScheduledEnd(record, totals, scheduledEndAtMs) {
  const clockInMs = toEpochMs(record && record.clockIn);
  if (!isOpenRecord(record) || clockInMs == null || scheduledEndAtMs == null) {
    return false;
  }
  const recordScheduledStartMs = toEpochMs(record.scheduledStart);
  const workStartMs =
    recordScheduledStartMs != null && recordScheduledStartMs > clockInMs
      ? recordScheduledStartMs
      : clockInMs;
  const measuredEndMs =
    workStartMs + (totals.workedMinutes + totals.breakMinutes) * MINUTE_MS;
  return measuredEndMs > scheduledEndAtMs;
}

function isImplausibleClockedOutRecord({
  record,
  totals,
  scheduledStartAtMs,
  scheduledEndAtMs,
  workedFloor = IMPLAUSIBLE_WORKED_MINUTES_FLOOR,
  scheduledFloor = IMPLAUSIBLE_SCHEDULED_MINUTES_FLOOR,
}) {
  if (!hasClockedOut(record) || scheduledStartAtMs == null || scheduledEndAtMs == null) {
    return false;
  }
  const scheduledMinutes = Math.trunc((scheduledEndAtMs - scheduledStartAtMs) / MINUTE_MS);
  return scheduledMinutes >= scheduledFloor && totals.workedMinutes < workedFloor;
}

function classifyExceptions({
  record,
  totals,
  scheduledStartAtMs,
  scheduledEndAtMs,
  hasOpenCorrection = false,
} = {}) {
  const codes = [];
  if (totals.lateMinutes > 0) codes.push(EXCEPTION_CODES.late);
  if (totals.earlyLeaveMinutes > 0) codes.push(EXCEPTION_CODES.earlyLeave);
  if (totals.overtimeMinutes > 0) codes.push(EXCEPTION_CODES.overtime);

  if (record) {
    // Open sessions at a closed slot must be reviewed. We copy persisted minutes
    // as-is; authoritative minutes arrive when autoCloseAttendance or a
    // correction closes the session, and this row is then restated.
    if (
      recordNeedsReview(record) ||
      isOpenRecord(record) ||
      openPastScheduledEnd(record, totals, scheduledEndAtMs)
    ) {
      codes.push(EXCEPTION_CODES.missingPunch);
    }
    if (scheduledStartAtMs == null) codes.push(EXCEPTION_CODES.unscheduledWork);
    if (isImplausibleClockedOutRecord({
      record,
      totals,
      scheduledStartAtMs,
      scheduledEndAtMs,
    })) {
      codes.push(EXCEPTION_CODES.implausibleRecord);
    }
  }

  if (hasOpenCorrection) codes.push(EXCEPTION_CODES.pendingCorrection);
  return Object.freeze(codes);
}

function countsAsExpectedWork(outcome) {
  return outcome !== OUTCOMES.onLeave && outcome !== OUTCOMES.excused;
}

function countsAsPresent(outcome) {
  return outcome === OUTCOMES.worked ||
    outcome === OUTCOMES.workedLate ||
    outcome === OUTCOMES.openSession ||
    outcome === OUTCOMES.needsReview;
}

function countsAsAbsence(outcome) {
  return outcome === OUTCOMES.absent;
}

function isUnresolved(outcome) {
  return outcome === OUTCOMES.openSession ||
    outcome === OUTCOMES.needsReview ||
    outcome === OUTCOMES.noRecordYet;
}

function slotWindow({ schedule, businessDay, shift }) {
  const day = normalizeBusinessDay(businessDay);
  if (!day) return null;
  const occurrenceAt = businessCivilMidnightMs(day.year, day.month, day.day);
  if (occurrenceAt == null) return null;
  const window = resolveRecurringTaskWindow({
    schedule,
    occurrenceAt,
    day: day.dayName,
    shift,
  });
  if (!window) return null;
  return {
    scheduledStartAtMs: window.startsAtMs,
    scheduledEndAtMs: window.deadlineMs,
    hours: resolveShiftHours({ schedule, day: day.dayName, shift }),
  };
}

function buildExpectedShiftRows({
  schedule,
  businessDay,
  recordsById = {},
  nowMs,
  openCorrectionIds = new Set(),
  graceMinutes = AUTO_CLOSE_GRACE_MINUTES,
} = {}) {
  const day = normalizeBusinessDay(businessDay);
  if (!schedule || !day || !Number.isFinite(Number(nowMs))) return [];
  const branchId = String(schedule.branchId || "");
  if (!branchId) return [];
  const dayKey = attendanceDayKey(day);
  const rows = [];

  for (const shift of SCHEDULE_SHIFTS) {
    const window = slotWindow({ schedule, businessDay: day, shift });
    if (!window) continue;
    for (const uid of assignedUids(schedule, day.dayName, shift)) {
      const rowId = attendanceDocId({ uid, dayKey, shift });
      const record = recordFrom(recordsById, rowId);
      const totals = record ? totalsFromRecord(record) : totalsFromRecord(null);
      const leaveType = leaveTypeFor(schedule, day.dayName, uid);
      const outcome = classifyExpectedOutcome({
        record,
        leaveType,
        scheduledEndAtMs: window.scheduledEndAtMs,
        nowMs: Number(nowMs),
        graceMinutes,
        totals,
      });
      const exceptionCodes = classifyExceptions({
        record,
        totals,
        scheduledStartAtMs: window.scheduledStartAtMs,
        scheduledEndAtMs: window.scheduledEndAtMs,
        hasOpenCorrection: openCorrectionIds instanceof Set
          ? openCorrectionIds.has(rowId)
          : !!openCorrectionIds[rowId],
      });

      rows.push({
        rowId,
        userId: uid,
        userName: record && record.userName != null ? String(record.userName) : null,
        branchId,
        dayKey,
        businessDate: day.dateKey,
        shift,
        scheduledStartAtMs: window.scheduledStartAtMs,
        scheduledEndAtMs: window.scheduledEndAtMs,
        outcome,
        expected: countsAsExpectedWork(outcome),
        recordId: record ? rowId : null,
        leaveType,
        workedMinutes: totals.workedMinutes,
        lateMinutes: totals.lateMinutes,
        earlyLeaveMinutes: totals.earlyLeaveMinutes,
        overtimeMinutes: totals.overtimeMinutes,
        breakMinutes: totals.breakMinutes,
        exceptionCodes,
        locked: false,
        version: 1,
        source: "system",
        schemaVersion: SCHEMA_VERSION,
      });
    }
  }

  rows.sort((a, b) =>
    a.businessDate.localeCompare(b.businessDate) ||
    SCHEDULE_SHIFTS.indexOf(a.shift) - SCHEDULE_SHIFTS.indexOf(b.shift) ||
    a.userId.localeCompare(b.userId));
  return Object.freeze(rows);
}

function isSlotClosable(row, nowMs, graceMinutes = AUTO_CLOSE_GRACE_MINUTES) {
  return row &&
    Number.isFinite(Number(row.scheduledEndAtMs)) &&
    Number.isFinite(Number(nowMs)) &&
    row.scheduledEndAtMs + graceMinutes * MINUTE_MS <= Number(nowMs);
}

function expectationSignature(data) {
  const d = data || {};
  return JSON.stringify({
    rowId: String(d.rowId || ""),
    userId: String(d.userId || ""),
    userName: d.userName == null ? null : String(d.userName),
    branchId: String(d.branchId || ""),
    dayKey: String(d.dayKey || ""),
    businessDate: String(d.businessDate || ""),
    shift: String(d.shift || ""),
    scheduledStartAtMs: toEpochMs(d.scheduledStartAt ?? d.scheduledStartAtMs),
    scheduledEndAtMs: toEpochMs(d.scheduledEndAt ?? d.scheduledEndAtMs),
    outcome: String(d.outcome || ""),
    expected: d.expected === true,
    recordId: d.recordId == null ? null : String(d.recordId),
    leaveType: d.leaveType == null ? null : String(d.leaveType),
    workedMinutes: intField(d, "workedMinutes"),
    lateMinutes: intField(d, "lateMinutes"),
    earlyLeaveMinutes: intField(d, "earlyLeaveMinutes"),
    overtimeMinutes: intField(d, "overtimeMinutes"),
    exceptionCodes: Array.isArray(d.exceptionCodes)
      ? d.exceptionCodes.map(String)
      : [],
    source: String(d.source || "system"),
    schemaVersion: Number(d.schemaVersion || SCHEMA_VERSION),
  });
}

function expectationInputsChanged(nextRow, existingData) {
  return expectationSignature(nextRow) !== expectationSignature(existingData);
}

function summarizeRows(rows) {
  const summary = {
    materialized: rows.length,
    expected: 0,
    present: 0,
    absent: 0,
    excused: 0,
    onLeave: 0,
    phantom: 0,
  };
  for (const row of rows) {
    if (row.expected) summary.expected++;
    if (countsAsPresent(row.outcome)) summary.present++;
    if (countsAsAbsence(row.outcome)) summary.absent++;
    if (row.outcome === OUTCOMES.excused) summary.excused++;
    if (row.outcome === OUTCOMES.onLeave) summary.onLeave++;
    if (row.recordId == null) summary.phantom++;
  }
  return summary;
}

function previousBusinessDay(day) {
  const current = normalizeBusinessDay(day);
  if (!current) return null;
  const d = new Date(Date.UTC(current.year, current.month - 1, current.day - 1));
  const midnight = businessCivilMidnightMs(
    d.getUTCFullYear(),
    d.getUTCMonth() + 1,
    d.getUTCDate(),
  );
  return midnight == null ? null : businessDayParts(midnight);
}

function businessDaysToSweep(nowMs) {
  const today = businessDayParts(nowMs);
  if (!today) return [];
  const weekStart = weekStartInfoForBusinessDay(today);
  if (!weekStart) return [];

  const daysByKey = new Map();
  let cursor = today;
  while (cursor) {
    if (daysByKey.size >= 8) break;
    daysByKey.set(cursor.dateKey, cursor);
    if (cursor.dateKey === weekStart.key) break;
    cursor = previousBusinessDay(cursor);
  }

  const previous = previousBusinessDay(today);
  if (previous) daysByKey.set(previous.dateKey, previous);

  const days = [...daysByKey.values()].sort((a, b) => b.dateKey.localeCompare(a.dateKey));
  if (days.length > 8) {
    throw new Error(`businessDaysToSweep exceeded bounded window: ${days.length}`);
  }
  return Object.freeze(days);
}

function weekStartInfoForBusinessDay(day) {
  const current = normalizeBusinessDay(day);
  if (!current) return null;
  const midnight = businessCivilMidnightMs(current.year, current.month, current.day);
  if (midnight == null) return null;
  const key = businessWeekStartKey(midnight);
  if (!key) return null;
  const [year, month, date] = key.split("-").map(Number);
  const weekStartMs = businessCivilMidnightMs(year, month, date);
  return weekStartMs == null ? null : { key, weekStartMs };
}

module.exports = {
  AUTO_CLOSE_GRACE_MINUTES,
  BUSINESS_TIME_ZONE,
  EXCEPTION_CODES,
  IMPLAUSIBLE_SCHEDULED_MINUTES_FLOOR,
  IMPLAUSIBLE_WORKED_MINUTES_FLOOR,
  OUTCOMES,
  SCHEMA_VERSION,
  SCHEDULE_DAYS,
  SCHEDULE_SHIFTS,
  attendanceDayKey,
  attendanceDocId,
  businessDaysToSweep,
  buildExpectedShiftRows,
  classifyExceptions,
  classifyExpectedOutcome,
  countsAsAbsence,
  countsAsExpectedWork,
  countsAsPresent,
  expectationInputsChanged,
  expectationSignature,
  isSlotClosable,
  isUnresolved,
  previousBusinessDay,
  summarizeRows,
  toEpochMs,
  weekStartInfoForBusinessDay,
};
