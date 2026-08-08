"use strict";

// The server-authoritative port of the Flutter `AttendanceCalculator`
// (`lib/features/attendance/domain/attendance_calculator.dart`). Pure + I/O-free,
// so it is unit-tested in isolation (see test/attendance_totals.test.js) and can
// never disagree with the client math for the same inputs.
//
// WHY THIS EXISTS. Attendance minutes feed payroll. The client used to compute
// AND persist them at clock-out, which meant the record's own security rules had
// to trust a client-written number — an employee talking to Firestore directly
// could set `workedMinutes` to anything. This module lets `onAttendanceWritten`
// recompute the authoritative snapshot with the Admin SDK, so the rules can (and
// now do) forbid every client minute write. See
// docs/decisions/ADR-024-server-authoritative-attendance-minutes.md.
//
// Every input is epoch-millis (or null); the caller converts Firestore
// Timestamps. The arithmetic mirrors the Dart line for line — integer minutes
// truncated toward zero, worked time clamped to `max(clockIn, scheduledStart)`,
// grace windows suppressing trivial late/early/overtime — so an overnight shift
// that crosses midnight needs no special-casing (it is all instant subtraction).

// Mirrors AttendanceConfig.defaults. The single knob set until per-branch
// attendance config lands; the client uses the same defaults for the live timer.
const LATE_GRACE_MINUTES = 5;
const EARLY_LEAVE_GRACE_MINUTES = 5;
const OVERTIME_GRACE_MINUTES = 15;

const MINUTE_MS = 60 * 1000;

function nonNeg(v) {
  return v < 0 ? 0 : v;
}

// Whole minutes between two epoch-millis instants, truncated toward zero to match
// Dart's `Duration.inMinutes`.
function minutesBetween(fromMs, toMs) {
  return Math.trunc((toMs - fromMs) / MINUTE_MS);
}

// Total break minutes across [breaks] measured to [endMs] for any open break.
// Mirrors `totalBreakMinutes` in attendance_break.dart. [breaks] is an array of
// `{ startMs, endMs }` (endMs null while the break is still open).
function totalBreakMinutes(breaks, endMs) {
  if (!Array.isArray(breaks)) return 0;
  let total = 0;
  for (const b of breaks) {
    const startMs = b && Number.isFinite(Number(b.startMs)) ? Number(b.startMs) : null;
    if (startMs == null) continue;
    const until = b.endMs != null && Number.isFinite(Number(b.endMs)) ? Number(b.endMs) : endMs;
    total += nonNeg(minutesBetween(startMs, until));
  }
  return total;
}

/**
 * Compute the five worked-time totals for one shift, in whole minutes.
 *
 * Mirrors `AttendanceCalculator.compute`. Lateness/early-leave/overtime are
 * measured against the scheduled instants and suppressed under the grace windows;
 * early-leave and overtime are only real once clocked out (an open session leaves
 * them at 0 — honest, not projected).
 *
 * @return {{workedMinutes:number,lateMinutes:number,earlyLeaveMinutes:number,overtimeMinutes:number,breakMinutes:number}}
 */
function computeAttendanceTotals({
  scheduledStartMs = null,
  scheduledEndMs = null,
  clockInMs = null,
  clockOutMs = null,
  breaks = [],
  nowMs,
  lateGraceMinutes = LATE_GRACE_MINUTES,
  earlyLeaveGraceMinutes = EARLY_LEAVE_GRACE_MINUTES,
  overtimeGraceMinutes = OVERTIME_GRACE_MINUTES,
} = {}) {
  const zero = {
    workedMinutes: 0,
    lateMinutes: 0,
    earlyLeaveMinutes: 0,
    overtimeMinutes: 0,
    breakMinutes: 0,
  };
  if (clockInMs == null || !Number.isFinite(Number(clockInMs))) return zero;

  const measureNow = Number.isFinite(Number(nowMs)) ? Number(nowMs) : clockInMs;
  const end = clockOutMs != null && Number.isFinite(Number(clockOutMs))
    ? Number(clockOutMs)
    : measureNow;

  // Worked time runs from `max(clockIn, scheduledStart)` — clocking in early
  // never inflates the total (spec R2). Lateness below still measures the real
  // clock-in.
  const workStart =
    scheduledStartMs != null && Number(scheduledStartMs) > Number(clockInMs)
      ? Number(scheduledStartMs)
      : Number(clockInMs);
  const gross = nonNeg(minutesBetween(workStart, end));
  const breakMinutes = totalBreakMinutes(breaks, end);
  const worked = nonNeg(gross - breakMinutes);

  let late = 0;
  if (scheduledStartMs != null) {
    const rawLate = minutesBetween(Number(scheduledStartMs), Number(clockInMs));
    if (rawLate > lateGraceMinutes) late = rawLate;
  }

  let earlyLeave = 0;
  let overtime = 0;
  if (clockOutMs != null && scheduledEndMs != null) {
    const beforeEnd = minutesBetween(Number(clockOutMs), Number(scheduledEndMs)); // >0 = early
    if (beforeEnd > earlyLeaveGraceMinutes) earlyLeave = beforeEnd;

    const afterEnd = minutesBetween(Number(scheduledEndMs), Number(clockOutMs)); // >0 = over
    if (afterEnd > overtimeGraceMinutes) overtime = afterEnd;
  }

  return {
    workedMinutes: worked,
    lateMinutes: nonNeg(late),
    earlyLeaveMinutes: nonNeg(earlyLeave),
    overtimeMinutes: nonNeg(overtime),
    breakMinutes,
  };
}

// True when two totals objects carry different minute values (so the finalizer
// only writes when the snapshot actually changed — no write loop).
function attendanceTotalsDiffer(a, b) {
  return (
    Number(a.workedMinutes || 0) !== Number(b.workedMinutes || 0) ||
    Number(a.lateMinutes || 0) !== Number(b.lateMinutes || 0) ||
    Number(a.earlyLeaveMinutes || 0) !== Number(b.earlyLeaveMinutes || 0) ||
    Number(a.overtimeMinutes || 0) !== Number(b.overtimeMinutes || 0) ||
    Number(a.breakMinutes || 0) !== Number(b.breakMinutes || 0)
  );
}

module.exports = {
  LATE_GRACE_MINUTES,
  EARLY_LEAVE_GRACE_MINUTES,
  OVERTIME_GRACE_MINUTES,
  computeAttendanceTotals,
  totalBreakMinutes,
  attendanceTotalsDiffer,
};
