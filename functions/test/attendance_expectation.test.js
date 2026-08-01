"use strict";

const test = require("node:test");
const assert = require("node:assert/strict");
const {
  AUTO_CLOSE_GRACE_MINUTES,
  EXCEPTION_CODES,
  OUTCOMES,
  attendanceDocId,
  businessDaysToSweep,
  buildExpectedShiftRows,
  classifyExceptions,
  expectationInputsChanged,
  isSlotClosable,
  previousBusinessDay,
  summarizeRows,
  weekStartInfoForBusinessDay,
} = require("../attendance_expectation");

const MINUTE_MS = 60 * 1000;
const HOUR_MS = 60 * MINUTE_MS;
const WEEK_START_MS = Date.parse("2026-07-25T21:00:00Z"); // Sun 2026-07-26 Cairo.
const THURSDAY = {
  year: 2026,
  month: 7,
  day: 30,
  dateKey: "2026-07-30",
  dayName: "thursday",
  isoWeekday: 4,
};

function schedule(over = {}) {
  return {
    id: "branch1_2026-07-26",
    branchId: "branch1",
    weekStart: { toMillis: () => WEEK_START_MS },
    assignments: {
      thursday: {
        morning: ["emp2", "emp1"],
        night: ["emp3"],
      },
    },
    leave: {},
    ...over,
  };
}

function record(over = {}) {
  return {
    id: "emp1_20260730_morning",
    userId: "emp1",
    userName: "Employee One",
    branchId: "branch1",
    shift: "morning",
    status: "completed",
    scheduledStart: { toMillis: () => Date.parse("2026-07-30T05:30:00Z") },
    scheduledEnd: { toMillis: () => Date.parse("2026-07-30T13:30:00Z") },
    clockIn: { toMillis: () => Date.parse("2026-07-30T05:35:00Z") },
    clockOut: { toMillis: () => Date.parse("2026-07-30T13:35:00Z") },
    workedMinutes: 480,
    lateMinutes: 5,
    earlyLeaveMinutes: 0,
    overtimeMinutes: 5,
    breakMinutes: 0,
    ...over,
  };
}

test("deterministic expectation row ids mirror attendance document ids", () => {
  assert.equal(
    attendanceDocId({ uid: "u1", dayKey: "20260730", shift: "night" }),
    "u1_20260730_night",
  );
});

test("business days to sweep returns the current week through mid-week, newest first", () => {
  assert.deepEqual(
    businessDaysToSweep(Date.parse("2026-07-30T09:00:00Z")).map((day) => day.dateKey),
    [
      "2026-07-30",
      "2026-07-29",
      "2026-07-28",
      "2026-07-27",
      "2026-07-26",
    ],
  );
});

test("business days to sweep includes previous Saturday only on Sunday boundary", () => {
  assert.deepEqual(
    businessDaysToSweep(Date.parse("2026-07-26T09:00:00Z")).map((day) => day.dateKey),
    [
      "2026-07-26",
      "2026-07-25",
    ],
  );
});

test("business days to sweep returns all seven days at week end", () => {
  assert.deepEqual(
    businessDaysToSweep(Date.parse("2026-08-01T09:00:00Z")).map((day) => day.dateKey),
    [
      "2026-08-01",
      "2026-07-31",
      "2026-07-30",
      "2026-07-29",
      "2026-07-28",
      "2026-07-27",
      "2026-07-26",
    ],
  );
});

test("business days to sweep is capped and unique", () => {
  const sampleNowMs = [
    "2026-07-26T09:00:00Z",
    "2026-07-27T09:00:00Z",
    "2026-07-28T09:00:00Z",
    "2026-07-29T09:00:00Z",
    "2026-07-30T09:00:00Z",
    "2026-07-31T09:00:00Z",
    "2026-08-01T09:00:00Z",
  ];
  for (const now of sampleNowMs) {
    const keys = businessDaysToSweep(Date.parse(now)).map((day) => day.dateKey);
    assert.ok(keys.length <= 8);
    assert.equal(new Set(keys).size, keys.length);
  }
});

test("a missing rostered record before close remains noRecordYet and is not closable", () => {
  const rows = buildExpectedShiftRows({
    schedule: schedule(),
    businessDay: THURSDAY,
    nowMs: Date.parse("2026-07-30T14:00:00Z"), // 30m after morning end.
  });
  const row = rows.find((r) => r.userId === "emp1" && r.shift === "morning");
  assert.equal(row.outcome, OUTCOMES.noRecordYet);
  assert.equal(isSlotClosable(row, Date.parse("2026-07-30T14:00:00Z")), false);
});

test("a missing rostered record after grace becomes an absent phantom row", () => {
  const rows = buildExpectedShiftRows({
    schedule: schedule(),
    businessDay: THURSDAY,
    nowMs: Date.parse("2026-07-30T15:30:00Z"), // morning end + 2h exactly.
  });
  const row = rows.find((r) => r.userId === "emp1" && r.shift === "morning");
  assert.equal(isSlotClosable(row, Date.parse("2026-07-30T15:30:00Z")), true);
  assert.equal(row.outcome, OUTCOMES.absent);
  assert.equal(row.expected, true);
  assert.equal(row.recordId, null);
  assert.deepEqual(row.exceptionCodes, []);
});

test("an absent phantom row takes its name from the roster directory", () => {
  // The roster stores uids only and a phantom no-show has no attendance record
  // to copy a name from, so without `namesByUid` every absence renders as a raw
  // Firebase uid in the report.
  const nowMs = Date.parse("2026-07-30T15:30:00Z");
  const rows = buildExpectedShiftRows({
    schedule: schedule(),
    businessDay: THURSDAY,
    namesByUid: { emp1: "Employee One" },
    nowMs,
  });
  const row = rows.find((r) => r.userId === "emp1" && r.shift === "morning");
  assert.equal(row.outcome, OUTCOMES.absent);
  assert.equal(row.recordId, null);
  assert.equal(row.userName, "Employee One");
});

test("a name is null, never the uid, when no source knows it", () => {
  const rows = buildExpectedShiftRows({
    schedule: schedule(),
    businessDay: THURSDAY,
    namesByUid: { someoneElse: "Not This Person" },
    nowMs: Date.parse("2026-07-30T15:30:00Z"),
  });
  const row = rows.find((r) => r.userId === "emp1" && r.shift === "morning");
  // Null lets a reader tell "no name known" apart from a person actually named
  // after their uid; the uid is already carried on the row.
  assert.equal(row.userName, null);
});

test("the attendance record's own name outranks the directory", () => {
  const rowId = "emp1_20260730_morning";
  const rows = buildExpectedShiftRows({
    schedule: schedule(),
    businessDay: THURSDAY,
    recordsById: { [rowId]: record() },
    namesByUid: { emp1: "Stale Directory Name" },
    nowMs: Date.parse("2026-07-30T15:30:00Z"),
  });
  const row = rows.find((r) => r.rowId === rowId);
  assert.equal(row.userName, "Employee One");
});

test("a blank directory name does not mask a missing name", () => {
  const rows = buildExpectedShiftRows({
    schedule: schedule(),
    businessDay: THURSDAY,
    namesByUid: { emp1: "   " },
    nowMs: Date.parse("2026-07-30T15:30:00Z"),
  });
  const row = rows.find((r) => r.userId === "emp1" && r.shift === "morning");
  assert.equal(row.userName, null);
});

test("worked late rows copy persisted minutes and derive exceptions", () => {
  const rowId = "emp1_20260730_morning";
  const rows = buildExpectedShiftRows({
    schedule: schedule(),
    businessDay: THURSDAY,
    recordsById: { [rowId]: record() },
    nowMs: Date.parse("2026-07-30T15:30:00Z"),
  });
  const row = rows.find((r) => r.rowId === rowId);
  assert.equal(row.outcome, OUTCOMES.workedLate);
  assert.equal(row.expected, true);
  assert.equal(row.recordId, rowId);
  assert.equal(row.userName, "Employee One");
  assert.equal(row.workedMinutes, 480);
  assert.equal(row.lateMinutes, 5);
  assert.equal(row.overtimeMinutes, 5);
  assert.deepEqual(row.exceptionCodes, [
    EXCEPTION_CODES.late,
    EXCEPTION_CODES.overtime,
  ]);
});

test("leave and excused rows do not count as expected work", () => {
  const rowId = "emp1_20260730_morning";
  const leaveRows = buildExpectedShiftRows({
    schedule: schedule({ leave: { thursday: { emp1: "sick" } } }),
    businessDay: THURSDAY,
    recordsById: { [rowId]: record({ status: "excused" }) },
    nowMs: Date.parse("2026-07-30T15:30:00Z"),
  });
  const leaveRow = leaveRows.find((r) => r.rowId === rowId);
  assert.equal(leaveRow.outcome, OUTCOMES.onLeave);
  assert.equal(leaveRow.leaveType, "sick");
  assert.equal(leaveRow.expected, false);

  const excusedRows = buildExpectedShiftRows({
    schedule: schedule(),
    businessDay: THURSDAY,
    recordsById: { [rowId]: record({ status: "excused", lateMinutes: 0 }) },
    nowMs: Date.parse("2026-07-30T15:30:00Z"),
  });
  const excusedRow = excusedRows.find((r) => r.rowId === rowId);
  assert.equal(excusedRow.outcome, OUTCOMES.excused);
  assert.equal(excusedRow.expected, false);
});

test("open sessions at close copy stale persisted minutes and require review", () => {
  const rowId = "emp1_20260730_morning";
  const rows = buildExpectedShiftRows({
    schedule: schedule(),
    businessDay: THURSDAY,
    recordsById: {
      [rowId]: record({
        status: "inProgress",
        clockOut: null,
        workedMinutes: 0,
        lateMinutes: 0,
        overtimeMinutes: 0,
      }),
    },
    nowMs: Date.parse("2026-07-30T15:30:00Z"),
  });
  const row = rows.find((r) => r.rowId === rowId);
  assert.equal(row.outcome, OUTCOMES.openSession);
  assert.equal(row.workedMinutes, 0);
  assert.deepEqual(row.exceptionCodes, [EXCEPTION_CODES.missingPunch]);
});

test("pending review records classify as needsReview with missingPunch", () => {
  const rowId = "emp1_20260730_morning";
  const rows = buildExpectedShiftRows({
    schedule: schedule(),
    businessDay: THURSDAY,
    recordsById: { [rowId]: record({ status: "pendingReview" }) },
    nowMs: Date.parse("2026-07-30T15:30:00Z"),
  });
  const row = rows.find((r) => r.rowId === rowId);
  assert.equal(row.outcome, OUTCOMES.needsReview);
  assert.deepEqual(row.exceptionCodes, [
    EXCEPTION_CODES.late,
    EXCEPTION_CODES.overtime,
    EXCEPTION_CODES.missingPunch,
  ]);
});

test("implausible clocked-out records use the Dart thresholds", () => {
  assert.deepEqual(
    classifyExceptions({
      record: record({ workedMinutes: 14 }),
      totals: {
        workedMinutes: 14,
        lateMinutes: 0,
        earlyLeaveMinutes: 0,
        overtimeMinutes: 0,
        breakMinutes: 0,
      },
      scheduledStartAtMs: Date.parse("2026-07-30T05:30:00Z"),
      scheduledEndAtMs: Date.parse("2026-07-30T13:30:00Z"),
    }),
    [EXCEPTION_CODES.implausibleRecord],
  );
});

test("pending corrections are included when the caller supplies open correction ids", () => {
  const rowId = "emp1_20260730_morning";
  const rows = buildExpectedShiftRows({
    schedule: schedule(),
    businessDay: THURSDAY,
    recordsById: { [rowId]: record({ lateMinutes: 0, overtimeMinutes: 0 }) },
    openCorrectionIds: new Set([rowId]),
    nowMs: Date.parse("2026-07-30T15:30:00Z"),
  });
  assert.deepEqual(rows.find((r) => r.rowId === rowId).exceptionCodes, [
    EXCEPTION_CODES.pendingCorrection,
  ]);
});

test("weekend night shifts close on the following calendar day but keep the start day key", () => {
  const rows = buildExpectedShiftRows({
    schedule: schedule(),
    businessDay: THURSDAY,
    nowMs: Date.parse("2026-07-31T02:00:00Z"),
  });
  const row = rows.find((r) => r.userId === "emp3" && r.shift === "night");
  assert.equal(row.dayKey, "20260730");
  assert.equal(row.businessDate, "2026-07-30");
  assert.equal(row.scheduledStartAtMs, Date.parse("2026-07-30T13:00:00Z"));
  assert.equal(row.scheduledEndAtMs, Date.parse("2026-07-30T21:00:00Z"));
  assert.equal(row.outcome, OUTCOMES.absent);
});

test("restatement signatures ignore server audit fields but detect changed inputs", () => {
  const rows = buildExpectedShiftRows({
    schedule: schedule(),
    businessDay: THURSDAY,
    recordsById: {
      emp1_20260730_morning: record({ lateMinutes: 0, overtimeMinutes: 0 }),
    },
    nowMs: Date.parse("2026-07-30T15:30:00Z"),
  });
  const row = rows.find((r) => r.rowId === "emp1_20260730_morning");
  const existing = {
    ...row,
    scheduledStartAt: { toMillis: () => row.scheduledStartAtMs },
    scheduledEndAt: { toMillis: () => row.scheduledEndAtMs },
    version: 9,
    closedAt: { toMillis: () => Date.parse("2026-07-30T15:30:01Z") },
    restatedAt: { toMillis: () => Date.parse("2026-07-30T16:00:00Z") },
  };
  assert.equal(expectationInputsChanged(row, existing), false);
  assert.equal(
    expectationInputsChanged({ ...row, lateMinutes: row.lateMinutes + 1 }, existing),
    true,
  );
});

test("summaries expose the denominator and absence counts", () => {
  const rows = [
    { outcome: OUTCOMES.worked, expected: true, recordId: "a" },
    { outcome: OUTCOMES.workedLate, expected: true, recordId: "b" },
    { outcome: OUTCOMES.absent, expected: true, recordId: null },
    { outcome: OUTCOMES.excused, expected: false, recordId: "c" },
    { outcome: OUTCOMES.onLeave, expected: false, recordId: null },
  ];
  assert.deepEqual(summarizeRows(rows), {
    materialized: 5,
    expected: 3,
    present: 2,
    absent: 1,
    excused: 1,
    onLeave: 1,
    phantom: 2,
  });
});

test("previous business day and week start use Cairo civil dates", () => {
  assert.deepEqual(previousBusinessDay(THURSDAY), {
    year: 2026,
    month: 7,
    day: 29,
    dateKey: "2026-07-29",
    dayName: "wednesday",
    isoWeekday: 3,
  });
  assert.deepEqual(weekStartInfoForBusinessDay(THURSDAY), {
    key: "2026-07-26",
    weekStartMs: WEEK_START_MS,
  });
});

test("attendance close grace constant stays at the client default", () => {
  assert.equal(AUTO_CLOSE_GRACE_MINUTES, 120);
});
