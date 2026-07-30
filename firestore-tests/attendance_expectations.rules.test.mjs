import test from "node:test";
import {
  doc,
  getDoc,
  setDoc,
  updateDoc,
  deleteDoc,
} from "firebase/firestore";
import {
  makeEnv,
  assertFails,
  assertSucceeds,
} from "./helpers.mjs";

/// Security-rules contract for `attendance_expectations/{rowId}`: rows are
/// written only by Cloud Functions/Admin SDK, while reads are scoped to admin,
/// own-branch managers, and the employee who owns the row.
const env = await makeEnv("drop-rules-attendance-expectations");

test.after(() => env.cleanup());
test.beforeEach(() => env.clearFirestore().then(() => reseed()));

const as = (uid) => env.authenticatedContext(uid).firestore();

const row = (over = {}) => ({
  rowId: "emp1_20260730_morning",
  userId: "emp1",
  userName: "Employee One",
  branchId: "branch1",
  dayKey: "20260730",
  businessDate: "2026-07-30",
  shift: "morning",
  scheduledStartAt: new Date("2026-07-30T05:30:00Z"),
  scheduledEndAt: new Date("2026-07-30T13:30:00Z"),
  outcome: "absent",
  expected: true,
  recordId: null,
  leaveType: null,
  workedMinutes: 0,
  lateMinutes: 0,
  earlyLeaveMinutes: 0,
  overtimeMinutes: 0,
  exceptionCodes: [],
  locked: false,
  version: 1,
  closedAt: new Date("2026-07-30T15:30:00Z"),
  restatedAt: null,
  source: "system",
  schemaVersion: 1,
  ...over,
});

async function reseed() {
  await env.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    await setDoc(doc(db, "users/mgr1"), {
      role: "manager",
      branchId: "branch1",
      isActive: true,
    });
    await setDoc(doc(db, "users/mgr2"), {
      role: "manager",
      branchId: "branch2",
      isActive: true,
    });
    await setDoc(doc(db, "users/admin1"), { role: "admin", isActive: true });
    await setDoc(doc(db, "users/emp1"), {
      role: "employee",
      branchId: "branch1",
      isActive: true,
    });
    await setDoc(doc(db, "users/emp2"), {
      role: "employee",
      branchId: "branch1",
      isActive: true,
    });
    await setDoc(
      doc(db, "attendance_expectations/emp1_20260730_morning"),
      row(),
    );
    await setDoc(
      doc(db, "attendance_expectations/emp2_20260730_morning"),
      row({
        rowId: "emp2_20260730_morning",
        userId: "emp2",
        userName: "Employee Two",
      }),
    );
    await setDoc(
      doc(db, "attendance_expectations/emp1_20260730_night"),
      row({
        rowId: "emp1_20260730_night",
        shift: "night",
        branchId: "branch2",
      }),
    );
  });
}

test("admin reads any attendance expectation row", async () => {
  await assertSucceeds(
    getDoc(doc(as("admin1"), "attendance_expectations/emp1_20260730_night")),
  );
});

test("manager reads an own-branch attendance expectation row", async () => {
  await assertSucceeds(
    getDoc(doc(as("mgr1"), "attendance_expectations/emp1_20260730_morning")),
  );
});

test("manager is denied another branch's attendance expectation row", async () => {
  await assertFails(
    getDoc(doc(as("mgr1"), "attendance_expectations/emp1_20260730_night")),
  );
});

test("employee reads their own attendance expectation row", async () => {
  await assertSucceeds(
    getDoc(doc(as("emp1"), "attendance_expectations/emp1_20260730_morning")),
  );
});

test("employee is denied a teammate's attendance expectation row", async () => {
  await assertFails(
    getDoc(doc(as("emp1"), "attendance_expectations/emp2_20260730_morning")),
  );
});

test("every client write is denied, including for an admin", async () => {
  await assertFails(
    setDoc(
      doc(as("admin1"), "attendance_expectations/emp3_20260730_morning"),
      row({ rowId: "emp3_20260730_morning", userId: "emp3" }),
    ),
  );
  await assertFails(
    updateDoc(
      doc(as("admin1"), "attendance_expectations/emp1_20260730_morning"),
      { outcome: "worked" },
    ),
  );
  await assertFails(
    deleteDoc(doc(as("admin1"), "attendance_expectations/emp1_20260730_morning")),
  );
});
