"use strict";

const test = require("node:test");
const assert = require("node:assert");
const {
  computeAttendanceTotals,
  attendanceTotalsDiffer,
} = require("../attendance_totals");

// A rostered 09:00–17:00 day, in UTC millis.
const start = Date.UTC(2026, 6, 13, 9, 0, 0);
const end = Date.UTC(2026, 6, 13, 17, 0, 0);
const H = 3600e3;
const M = 60e3;

test("on-time full shift → 480 worked, no late/early/overtime", () => {
  const t = computeAttendanceTotals({
    scheduledStartMs: start,
    scheduledEndMs: end,
    clockInMs: start,
    clockOutMs: end,
    nowMs: end,
  });
  assert.deepStrictEqual(t, {
    workedMinutes: 480,
    lateMinutes: 0,
    earlyLeaveMinutes: 0,
    overtimeMinutes: 0,
    breakMinutes: 0,
  });
});

test("clocking in early never inflates worked time (spec R2)", () => {
  // In 30m early, out on time → still 480 worked, and NOT late.
  const t = computeAttendanceTotals({
    scheduledStartMs: start,
    scheduledEndMs: end,
    clockInMs: start - 30 * M,
    clockOutMs: end,
    nowMs: end,
  });
  assert.strictEqual(t.workedMinutes, 480);
  assert.strictEqual(t.lateMinutes, 0);
});

test("late beyond grace counts; within grace does not", () => {
  const late20 = computeAttendanceTotals({
    scheduledStartMs: start,
    scheduledEndMs: end,
    clockInMs: start + 20 * M,
    clockOutMs: end,
    nowMs: end,
  });
  assert.strictEqual(late20.lateMinutes, 20);
  // Worked runs from the real clock-in (past scheduledStart) → 460.
  assert.strictEqual(late20.workedMinutes, 460);

  const late4 = computeAttendanceTotals({
    scheduledStartMs: start,
    scheduledEndMs: end,
    clockInMs: start + 4 * M, // within the 5m grace
    clockOutMs: end,
    nowMs: end,
  });
  assert.strictEqual(late4.lateMinutes, 0);
});

test("early leave beyond grace counts; overtime beyond its grace counts", () => {
  const early = computeAttendanceTotals({
    scheduledStartMs: start,
    scheduledEndMs: end,
    clockInMs: start,
    clockOutMs: end - 30 * M,
    nowMs: end - 30 * M,
  });
  assert.strictEqual(early.earlyLeaveMinutes, 30);
  assert.strictEqual(early.overtimeMinutes, 0);

  const over = computeAttendanceTotals({
    scheduledStartMs: start,
    scheduledEndMs: end,
    clockInMs: start,
    clockOutMs: end + 45 * M,
    nowMs: end + 45 * M,
  });
  assert.strictEqual(over.overtimeMinutes, 45);
  assert.strictEqual(over.earlyLeaveMinutes, 0);
});

test("overtime within its 15m grace does not count", () => {
  const t = computeAttendanceTotals({
    scheduledStartMs: start,
    scheduledEndMs: end,
    clockInMs: start,
    clockOutMs: end + 10 * M,
    nowMs: end + 10 * M,
  });
  assert.strictEqual(t.overtimeMinutes, 0);
});

test("overnight shift crossing midnight needs no special-casing", () => {
  const nStart = Date.UTC(2026, 6, 13, 22, 0, 0);
  const nEnd = Date.UTC(2026, 6, 14, 6, 0, 0); // next day 06:00
  const t = computeAttendanceTotals({
    scheduledStartMs: nStart,
    scheduledEndMs: nEnd,
    clockInMs: nStart,
    clockOutMs: nEnd,
    nowMs: nEnd,
  });
  assert.strictEqual(t.workedMinutes, 480);
});

test("presence-only (no scheduled window) → worked from clock-in, no late/OT", () => {
  const t = computeAttendanceTotals({
    scheduledStartMs: null,
    scheduledEndMs: null,
    clockInMs: start,
    clockOutMs: start + 5 * H,
    nowMs: start + 5 * H,
  });
  assert.strictEqual(t.workedMinutes, 300);
  assert.strictEqual(t.lateMinutes, 0);
  assert.strictEqual(t.overtimeMinutes, 0);
  assert.strictEqual(t.earlyLeaveMinutes, 0);
});

test("an open session (no clock-out) has zero early-leave/overtime", () => {
  const t = computeAttendanceTotals({
    scheduledStartMs: start,
    scheduledEndMs: end,
    clockInMs: start,
    clockOutMs: null,
    nowMs: start + 2 * H,
  });
  assert.strictEqual(t.workedMinutes, 120);
  assert.strictEqual(t.earlyLeaveMinutes, 0);
  assert.strictEqual(t.overtimeMinutes, 0);
});

test("no clock-in → all zeros", () => {
  const t = computeAttendanceTotals({ clockInMs: null, nowMs: end });
  assert.strictEqual(t.workedMinutes, 0);
});

test("breaks net out of worked time", () => {
  const t = computeAttendanceTotals({
    scheduledStartMs: start,
    scheduledEndMs: end,
    clockInMs: start,
    clockOutMs: end,
    breaks: [{ startMs: start + 4 * H, endMs: start + 4 * H + 30 * M }],
    nowMs: end,
  });
  assert.strictEqual(t.breakMinutes, 30);
  assert.strictEqual(t.workedMinutes, 450);
});

test("attendanceTotalsDiffer detects a change and ignores equality", () => {
  const a = { workedMinutes: 480, lateMinutes: 0, earlyLeaveMinutes: 0, overtimeMinutes: 0, breakMinutes: 0 };
  assert.strictEqual(attendanceTotalsDiffer(a, { ...a }), false);
  assert.strictEqual(attendanceTotalsDiffer(a, { ...a, workedMinutes: 0 }), true);
});
