import test from "node:test";
import {
  collection,
  deleteDoc,
  doc,
  getDoc,
  setDoc,
  updateDoc,
} from "firebase/firestore";
import {
  assertFails,
  assertSucceeds,
  makeEnv,
} from "./helpers.mjs";

// Security-rules contract for attendance_corrections. Attendance document ids
// are `{uid}_{yyyyMMdd}_{shift}`; a correction must name a record owned by its
// `userId`, including an Add record correction whose parent does not exist yet.
const env = await makeEnv("drop-rules-attendance-corrections");

test.after(() => env.cleanup());
test.beforeEach(() => env.clearFirestore().then(reseedUsers));

const reseedUsers = () => env.withSecurityRulesDisabled(async (ctx) => {
  const db = ctx.firestore();
  await Promise.all([
    setDoc(doc(db, "users/mgr1"), { role: "manager", branchId: "branch1", isActive: true }),
    setDoc(doc(db, "users/mgr2"), { role: "manager", branchId: "branch2", isActive: true }),
    setDoc(doc(db, "users/admin1"), { role: "admin", isActive: true }),
    setDoc(doc(db, "users/emp1"), { role: "employee", branchId: "branch1", isActive: true }),
    setDoc(doc(db, "users/emp2"), { role: "employee", branchId: "branch1", isActive: true }),
  ]);
});

const as = (uid) => env.authenticatedContext(uid).firestore();

const correction = (overrides = {}) => ({
  userId: "emp1",
  userName: "Employee One",
  branchId: "branch1",
  attendanceId: "emp1_20260802_morning",
  requestedBy: "emp1",
  requestedByName: "Employee One",
  status: "pending",
  kind: "update",
  reason: "Correct clock-out time",
  resolution: { status: "completed", workedMinutes: 480 },
  ...overrides,
});

const seedCorrection = (id, data = correction()) => env.withSecurityRulesDisabled(
  (ctx) => setDoc(doc(ctx.firestore(), `attendance_corrections/${id}`), data),
);

test("DENY: an employee cannot file a correction against another employee's record", async () => {
  await assertFails(setDoc(
    doc(as("emp1"), "attendance_corrections/cross-employee"),
    correction({ attendanceId: "emp2_20260802_morning" }),
  ));
});

test("DENY: a manager cannot direct-action their own attendance through another user", async () => {
  await assertFails(setDoc(
    doc(as("mgr1"), "attendance_corrections/self-approval-evasion"),
    correction({
      attendanceId: "mgr1_20260802_morning",
      status: "approved",
      requestedBy: "mgr1",
      decidedBy: "mgr1",
    }),
  ));
});

test("DENY: a correction attendanceId without an owner segment is malformed", async () => {
  await assertFails(setDoc(
    doc(as("emp1"), "attendance_corrections/malformed"),
    correction({ attendanceId: "not-a-deterministic-id" }),
  ));
});

test("ALLOW: an employee files a pending correction for their own record", async () => {
  await assertSucceeds(setDoc(
    doc(as("emp1"), "attendance_corrections/own"),
    correction(),
  ));
});

test("ALLOW: a manager adds an approved correction for a branch employee without a parent record", async () => {
  await assertSucceeds(setDoc(
    doc(as("mgr1"), "attendance_corrections/add-record"),
    correction({
      status: "approved",
      requestedBy: "mgr1",
      decidedBy: "mgr1",
      decidedByName: "Manager One",
    }),
  ));
});

test("DENY: a manager cannot direct-action a correction outside their branch", async () => {
  await assertFails(setDoc(
    doc(as("mgr1"), "attendance_corrections/outside-branch"),
    correction({
      userId: "emp3",
      branchId: "branch2",
      attendanceId: "emp3_20260802_morning",
      status: "approved",
      requestedBy: "mgr1",
      decidedBy: "mgr1",
    }),
  ));
});

test("DENY: reviewers cannot change correction identity fields", async () => {
  await seedCorrection("frozen");
  for (const patch of [
    { userId: "emp2" },
    { attendanceId: "emp2_20260802_morning" },
    { requestedBy: "mgr1" },
  ]) {
    await assertFails(updateDoc(doc(as("mgr1"), "attendance_corrections/frozen"), patch));
  }
});

test("read/delete behavior remains scoped and corrections remain undeletable", async () => {
  await seedCorrection("branch1");
  await seedCorrection("branch2", correction({
    userId: "emp3",
    branchId: "branch2",
    attendanceId: "emp3_20260802_morning",
    requestedBy: "emp3",
  }));

  await assertSucceeds(getDoc(doc(as("emp1"), "attendance_corrections/branch1")));
  await assertFails(getDoc(doc(as("emp2"), "attendance_corrections/branch1")));
  await assertSucceeds(getDoc(doc(as("mgr1"), "attendance_corrections/branch1")));
  await assertFails(getDoc(doc(as("mgr1"), "attendance_corrections/branch2")));
  await assertSucceeds(getDoc(doc(as("admin1"), "attendance_corrections/branch2")));
  await assertFails(deleteDoc(doc(as("admin1"), "attendance_corrections/branch1")));
});
