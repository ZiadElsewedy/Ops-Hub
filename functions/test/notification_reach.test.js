"use strict";

const test = require("node:test");
const assert = require("node:assert/strict");
const { canNotify, reachFacts } = require("../notification_reach");

// Role/branch shapes exactly as `createUserAccount` seeds them. The admin
// deliberately has NO branchId — the role is global (PROJECT_CONTEXT §8), and
// that fact is the entire reason this module exists.
const admin = { role: "admin", isActive: true };
const managerA = { role: "manager", branchId: "branchA", isActive: true };
const employeeA = { role: "employee", branchId: "branchA", isActive: true };
const employeeA2 = { role: "employee", branchId: "branchA", isActive: true };
const employeeB = { role: "employee", branchId: "branchB", isActive: true };

test("an employee CAN notify an admin (the regression this module exists for)", () => {
  // Before the fix this was false: `recipientBranch === callerBranch` compared
  // "" against "branchA", so every `taskSubmitted` for an admin-created task
  // was rejected and silently swallowed. The admin was never told a task they
  // created had come back for review.
  assert.equal(canNotify(employeeA, admin), true);
});

test("a manager CAN notify an admin", () => {
  assert.equal(canNotify(managerA, admin), true);
});

test("an admin can notify anyone, in any branch", () => {
  assert.equal(canNotify(admin, employeeA), true);
  assert.equal(canNotify(admin, employeeB), true);
  assert.equal(canNotify(admin, managerA), true);
  assert.equal(canNotify(admin, admin), true);
});

test("same-branch reachability is unchanged", () => {
  assert.equal(canNotify(employeeA, employeeA2), true);
  assert.equal(canNotify(employeeA, managerA), true);
  assert.equal(canNotify(managerA, employeeA), true);
});

test("cross-branch is still denied — the fix must not widen this", () => {
  assert.equal(canNotify(employeeA, employeeB), false);
  assert.equal(canNotify(employeeB, employeeA), false);
  assert.equal(canNotify(managerA, employeeB), false);
});

test("a branchless non-admin reaches admins only, never staff", () => {
  // A misprovisioned account (or a manager whose branch was cleared). It must
  // not become a wildcard just because "" === "" would compare equal.
  const orphan = { role: "employee", isActive: true };
  assert.equal(canNotify(orphan, admin), true);
  assert.equal(canNotify(orphan, employeeA), false);
  assert.equal(canNotify(orphan, { role: "employee" }), false);
});

test("an unknown or missing role never escalates to admin", () => {
  // Mirrors `UserRole.fromString` on the client: unknown degrades to employee.
  const bogus = { role: "superuser", branchId: "branchA" };
  assert.equal(reachFacts(bogus).isAdmin, false);
  assert.equal(canNotify(bogus, employeeB), false);
  assert.equal(canNotify(employeeB, bogus), false);
  // …and a recipient with a bogus role is not treated as a reachable admin.
  assert.equal(canNotify(employeeB, { role: "Admin", branchId: "" }), false);
});

test("a missing document degrades safely instead of throwing", () => {
  assert.equal(canNotify(undefined, employeeA), false);
  assert.equal(canNotify(employeeA, undefined), false);
  assert.equal(canNotify(undefined, undefined), false);
  // An admin caller still reaches an absent recipient shape.
  assert.equal(canNotify(admin, undefined), true);
});

test("reachFacts normalizes both fields", () => {
  assert.deepEqual(reachFacts(admin), { isAdmin: true, branchId: "" });
  assert.deepEqual(reachFacts(employeeA), {
    isAdmin: false,
    branchId: "branchA",
  });
  assert.deepEqual(reachFacts({}), { isAdmin: false, branchId: "" });
});
