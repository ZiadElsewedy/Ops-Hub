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

// ─── Recipient policy ────────────────────────────────────────────────────
// An admin has no `branchId`, so a branch query can never return one. These
// pin that admins are an ADDITION to every sales recipient set, not the
// fallback they used to be — which is why the whole feature was silent for
// them.
const branchStaff = [
  { id: "mgr1", role: "manager" },
  { id: "emp1", role: "employee" },
  { id: "emp2", role: "employee" },
];
const admins = [{ id: "admin1" }, { id: "admin2" }];

test("a branch-wide sales announcement reaches the branch and every admin", () => {
  const got = sales.selectSalesRecipients({ branchUsers: branchStaff, admins });
  assert.deepEqual(got.sort(), ["admin1", "admin2", "emp1", "emp2", "mgr1"]);
});
test("a review ping narrows the BRANCH to managers but still reaches every admin", () => {
  const got = sales.selectSalesRecipients({ branchUsers: branchStaff, admins, managersOnly: true });
  assert.deepEqual(got.sort(), ["admin1", "admin2", "mgr1"]);
});
test("admins are reached even when the branch has nobody at all", () => {
  assert.deepEqual(sales.selectSalesRecipients({ branchUsers: [], admins, managersOnly: true }).sort(), ["admin1", "admin2"]);
});
test("a branch with no manager still reaches its admins (the old fallback case)", () => {
  const got = sales.selectSalesRecipients({ branchUsers: [{ id: "emp1", role: "employee" }], admins, managersOnly: true });
  assert.deepEqual(got.sort(), ["admin1", "admin2"]);
});
test("the actor is never notified of their own sales action", () => {
  assert.deepEqual(
    sales.selectSalesRecipients({ branchUsers: branchStaff, admins, excludeUid: "admin1" }).sort(),
    ["admin2", "emp1", "emp2", "mgr1"],
  );
  assert.deepEqual(
    sales.selectSalesRecipients({ branchUsers: branchStaff, admins, managersOnly: true, excludeUid: "mgr1" }).sort(),
    ["admin1", "admin2"],
  );
});
test("recipients are de-duplicated and never blank", () => {
  const got = sales.selectSalesRecipients({
    branchUsers: [{ id: "mgr1", role: "manager" }, { id: "" }, { id: "  admin1  " }],
    admins: [{ id: "admin1" }, { id: "admin1" }],
  });
  assert.deepEqual(got.sort(), ["admin1", "mgr1"]);
});
test("an empty estate is a valid empty recipient set, not an error", () => {
  assert.deepEqual(sales.selectSalesRecipients(), []);
  assert.deepEqual(sales.selectSalesRecipients({ branchUsers: null, admins: undefined }), []);
});
