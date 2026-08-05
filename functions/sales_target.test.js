"use strict";
const test = require("node:test");
const assert = require("node:assert/strict");
const sales = require("./sales_target");

test("Cairo date and month keys honor UTC/Cairo midnight and DST boundaries", () => {
  assert.equal(sales.businessDateKey(new Date("2026-08-05T21:30:00Z")), "20260806");
  assert.equal(sales.businessMonthKey(new Date("2026-02-28T22:30:00Z")), "202603");
  // Egypt's DST start is a calendar boundary: Intl/IANA, not a hard-coded offset.
  assert.equal(sales.businessDateKey(new Date("2026-04-23T22:30:00Z")), "20260424");
});
test("back-date window includes today and previous three Cairo days", () => {
  const now = new Date("2026-08-05T12:00:00Z");
  for (const key of ["20260805", "20260804", "20260803", "20260802"]) assert.ok(sales.isWithinLastBusinessDays(key, 3, now));
  assert.equal(sales.isWithinLastBusinessDays("20260801", 3, now), false);
  assert.equal(sales.isWithinLastBusinessDays("not-a-date", 3, now), false);
});
test("deterministic ids and validators bind branch and period", () => {
  assert.equal(sales.salesSubmissionId("b1", "20260805"), "b1_20260805");
  assert.equal(sales.salesMonthId("b1", "202608"), "b1_202608");
  assert.ok(sales.validSubmissionId("b1_20260805", "b1", "20260805"));
  assert.equal(sales.validSubmissionId("b2_20260805", "b1", "20260805"), false);
  assert.ok(sales.validMonthId("b1_202608", "b1", "202608"));
  assert.equal(sales.validMonthId("b1_20261", "b1", "20261"), false);
});
test("money accepts only finite non-negative integer piastres", () => {
  for (const value of [0, 1, 9000000000000]) assert.ok(sales.isValidMoney(value));
  for (const value of [-1, 1.5, NaN, Infinity, "100", 9000000000001]) assert.equal(sales.isValidMoney(value), false);
});
test("status transition matrix allows only the ledger transitions", () => {
  const legal = [
    ["pending", "approve", "manager", "approved"], ["pending", "reject", "admin", "rejected"],
    ["pending", "requestCorrection", "manager", "correctionRequested"], ["approved", "reopen", "admin", "pending"],
    ["rejected", "reopen", "admin", "pending"], ["correctionRequested", "resubmit", "employee", "pending"],
    ["approved", "editApproved", "manager", "approved"],
  ];
  for (const [status, action, role, next] of legal) assert.equal(sales.nextStatus(status, action, role).status, next);
  for (const row of [["approved", "approve", "admin"], ["pending", "reopen", "admin"], ["rejected", "resubmit", "employee"], ["correctionRequested", "resubmit", "manager"], ["correctionRequested", "resubmit", "admin"], ["approved", "reopen", "manager"], ["pending", "approve", "employee"]]) assert.ok(sales.nextStatus(...row).error);
});
test("self approval is rejected by the pure decision guard", () => {
  assert.equal(sales.canDecideSubmission("employee1", "employee1"), false);
  assert.equal(sales.canDecideSubmission("manager1", "employee1"), true);
});
test("target-achieved crossing fires once, not on later approvals", () => {
  assert.ok(sales.targetAchievedCrossing(900, 1000, 1000));
  assert.equal(sales.targetAchievedCrossing(1000, 1100, 1000), false);
  assert.equal(sales.targetAchievedCrossing(900, 999, 1000), false);
});
