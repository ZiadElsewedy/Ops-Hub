"use strict";

const test = require("node:test");
const assert = require("node:assert/strict");

const {
  canDeleteAdmin,
  weekIsCurrentOrFuture,
  cleanScheduleForUser,
  isActiveTaskStatus,
  remainingAssignees,
  shouldCancelTask,
  shouldDeleteSwap,
  shouldDeleteRequest,
  shouldDeleteSubmission,
  isFutureExpectation,
} = require("../user_deletion");

// ── Last-admin guard ──────────────────────────────────────────────────────
test("canDeleteAdmin refuses when the target is the only admin", () => {
  assert.equal(canDeleteAdmin([{ id: "a", isActive: true }], "a"), false);
});

test("canDeleteAdmin allows when another usable admin remains", () => {
  const admins = [{ id: "a", isActive: true }, { id: "b", isActive: true }];
  assert.equal(canDeleteAdmin(admins, "a"), true);
});

test("canDeleteAdmin refuses when the only other admin is deactivated", () => {
  const admins = [{ id: "a", isActive: true }, { id: "b", isActive: false }];
  assert.equal(canDeleteAdmin(admins, "a"), false);
});

test("canDeleteAdmin treats a missing isActive as usable (default active)", () => {
  const admins = [{ id: "a" }, { id: "b" }];
  assert.equal(canDeleteAdmin(admins, "a"), true);
});

// ── Schedule week gate ────────────────────────────────────────────────────
test("weekIsCurrentOrFuture keeps past weeks out, current+future in", () => {
  const current = "2026-08-02";
  assert.equal(weekIsCurrentOrFuture("branch1_2026-07-26", current), false);
  assert.equal(weekIsCurrentOrFuture("branch1_2026-08-02", current), true);
  assert.equal(weekIsCurrentOrFuture("branch1_2026-08-09", current), true);
});

// ── Schedule cleanup ──────────────────────────────────────────────────────
test("cleanScheduleForUser removes the uid from assignments and leave", () => {
  const data = {
    assignments: {
      sunday: { morning: ["u1", "u2"], night: ["u3"] },
      monday: { morning: ["u2"], night: [] },
    },
    leave: {
      sunday: { u1: "vacation", u2: "sick" },
    },
  };
  const out = cleanScheduleForUser(data, "u1");
  assert.equal(out.changed, true);
  assert.deepEqual(out.assignments.sunday.morning, ["u2"]);
  assert.deepEqual(out.assignments.sunday.night, ["u3"]);
  assert.deepEqual(out.leave.sunday, { u2: "sick" });
  // The source snapshot is untouched (pure transform).
  assert.deepEqual(data.assignments.sunday.morning, ["u1", "u2"]);
  assert.deepEqual(data.leave.sunday, { u1: "vacation", u2: "sick" });
});

test("cleanScheduleForUser reports no change when the uid is absent", () => {
  const data = { assignments: { sunday: { morning: ["u2"] } }, leave: {} };
  assert.equal(cleanScheduleForUser(data, "u1").changed, false);
});

test("cleanScheduleForUser tolerates missing maps", () => {
  const out = cleanScheduleForUser({}, "u1");
  assert.equal(out.changed, false);
  assert.deepEqual(out.assignments, {});
  assert.deepEqual(out.leave, {});
});

// ── Task decisions ────────────────────────────────────────────────────────
test("isActiveTaskStatus is false only for terminal statuses", () => {
  for (const s of ["pending", "started", "completed", "waitingReview", "rejected"]) {
    assert.equal(isActiveTaskStatus(s), true, s);
  }
  for (const s of ["approved", "missed", "cancelled"]) {
    assert.equal(isActiveTaskStatus(s), false, s);
  }
  assert.equal(isActiveTaskStatus(undefined), true); // defaults to pending
});

test("remainingAssignees strips the uid", () => {
  assert.deepEqual(remainingAssignees(["u1", "u2"], "u1"), ["u2"]);
  assert.deepEqual(remainingAssignees(["u1"], "u1"), []);
  assert.deepEqual(remainingAssignees(undefined, "u1"), []);
});

test("shouldCancelTask only when the deleted user was the sole assignee", () => {
  assert.equal(shouldCancelTask(["u1"], "u1"), true);
  assert.equal(shouldCancelTask(["u1", "u2"], "u1"), false);
  assert.equal(shouldCancelTask([], "u1"), true);
});

// ── Swap / request / sales / expectation predicates ───────────────────────
test("shouldDeleteSwap deletes open swaps, keeps terminal ones", () => {
  assert.equal(shouldDeleteSwap("pending"), true);
  assert.equal(shouldDeleteSwap("employeeApproved"), true);
  assert.equal(shouldDeleteSwap("managerApproved"), false);
  assert.equal(shouldDeleteSwap("rejected"), false);
  assert.equal(shouldDeleteSwap("cancelled"), false);
});

test("shouldDeleteRequest deletes only still-pending requests", () => {
  assert.equal(shouldDeleteRequest("pending"), true);
  assert.equal(shouldDeleteRequest("approved"), false);
  assert.equal(shouldDeleteRequest("rejected"), false);
});

test("shouldDeleteSubmission deletes in-flight closes, keeps decided ones", () => {
  assert.equal(shouldDeleteSubmission("pending"), true);
  assert.equal(shouldDeleteSubmission("correctionRequested"), true);
  assert.equal(shouldDeleteSubmission("approved"), false);
  assert.equal(shouldDeleteSubmission("rejected"), false);
});

test("isFutureExpectation keeps today onward, drops the past", () => {
  const today = "2026-08-06";
  assert.equal(isFutureExpectation("2026-08-05", today), false);
  assert.equal(isFutureExpectation("2026-08-06", today), true);
  assert.equal(isFutureExpectation("2026-08-07", today), true);
});
