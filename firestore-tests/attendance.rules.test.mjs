import test from "node:test";
import { doc, setDoc, updateDoc } from "firebase/firestore";
import { assertFails, assertSucceeds, makeEnv } from "./helpers.mjs";

// Security-rules contract for the `attendance/{id}` record itself (ADR-024): a
// client may clock IN an empty record and clock OUT of its own, but may NEVER
// write a payroll minute field or backdate a clock time — those are computed by
// the Admin SDK. Record ids are `{uid}_{yyyyMMdd}_{shift}`.
const env = await makeEnv("drop-rules-attendance-record");

test.after(() => env.cleanup());
test.beforeEach(() => env.clearFirestore().then(reseedUsers));

const reseedUsers = () => env.withSecurityRulesDisabled(async (ctx) => {
  const db = ctx.firestore();
  await Promise.all([
    setDoc(doc(db, "users/mgr1"), { role: "manager", branchId: "branch1", isActive: true }),
    setDoc(doc(db, "users/admin1"), { role: "admin", isActive: true }),
    setDoc(doc(db, "users/emp1"), { role: "employee", branchId: "branch1", isActive: true }),
    setDoc(doc(db, "users/emp2"), { role: "employee", branchId: "branch1", isActive: true }),
  ]);
});

const as = (uid) => env.authenticatedContext(uid).firestore();

const clockIn = new Date("2026-08-02T09:00:00Z");
const clockOut = new Date("2026-08-02T17:00:00Z");
const schedStart = new Date("2026-08-02T09:00:00Z");
const schedEnd = new Date("2026-08-02T17:00:00Z");

// An OPEN record exactly as the client clock-in writes it (all minutes zero,
// no clock-out yet).
const openRecord = (overrides = {}) => ({
  id: "emp1_20260802_morning",
  userId: "emp1",
  userName: "Employee One",
  branchId: "branch1",
  shift: "morning",
  dayKey: "20260802",
  scheduledStart: schedStart,
  scheduledEnd: schedEnd,
  presenceOnly: false,
  clockIn,
  clockOut: null,
  breaks: [],
  status: "inProgress",
  workedMinutes: 0,
  lateMinutes: 0,
  earlyLeaveMinutes: 0,
  overtimeMinutes: 0,
  breakMinutes: 0,
  source: "clock",
  ...overrides,
});

const seedRecord = (data = openRecord()) => env.withSecurityRulesDisabled(
  (ctx) => setDoc(doc(ctx.firestore(), `attendance/${data.id}`), data),
);

const recRef = (uid, id = "emp1_20260802_morning") => doc(as(uid), `attendance/${id}`);

// ── Create ────────────────────────────────────────────────────────────────
test("ALLOW: an employee clocks in with an empty, zero-minute open record", async () => {
  await assertSucceeds(setDoc(recRef("emp1"), openRecord()));
});

test("DENY: clocking in with pre-filled worked minutes", async () => {
  await assertFails(setDoc(recRef("emp1"), openRecord({ workedMinutes: 600 })));
});

test("DENY: clocking in with a clock-out already set", async () => {
  await assertFails(setDoc(recRef("emp1"), openRecord({ clockOut })));
});

// ── Owner clock-out ─────────────────────────────────────────────────────────
test("ALLOW: the owner clocks out (clockOut + completed, minutes untouched)", async () => {
  await seedRecord();
  await assertSucceeds(updateDoc(recRef("emp1"), {
    clockOut,
    status: "completed",
    clockOutVerification: { verified: true },
    updatedAt: new Date(),
  }));
});

test("DENY: the owner writes their own worked minutes at clock-out", async () => {
  await seedRecord();
  await assertFails(updateDoc(recRef("emp1"), {
    clockOut,
    status: "completed",
    workedMinutes: 600,
  }));
});

test("DENY: the owner inflates overtime at clock-out", async () => {
  await seedRecord();
  await assertFails(updateDoc(recRef("emp1"), {
    clockOut,
    status: "completed",
    overtimeMinutes: 120,
  }));
});

test("DENY: the owner backdates their clock-in to erase lateness", async () => {
  await seedRecord(openRecord({ clockIn: new Date("2026-08-02T09:30:00Z") }));
  await assertFails(updateDoc(recRef("emp1"), {
    clockOut,
    status: "completed",
    clockIn: new Date("2026-08-02T09:00:00Z"),
  }));
});

test("DENY: the owner rewrites the scheduled window", async () => {
  await seedRecord();
  await assertFails(updateDoc(recRef("emp1"), {
    clockOut,
    status: "completed",
    scheduledStart: new Date("2026-08-02T10:00:00Z"),
  }));
});

test("DENY: the owner self-excuses instead of completing", async () => {
  await seedRecord();
  await assertFails(updateDoc(recRef("emp1"), {
    clockOut,
    status: "excused",
  }));
});

test("DENY: the owner self-brands the write as a correction", async () => {
  await seedRecord();
  await assertFails(updateDoc(recRef("emp1"), {
    clockOut,
    status: "completed",
    source: "correction",
  }));
});

test("DENY: re-clocking-out an already completed record", async () => {
  await seedRecord(openRecord({ status: "completed", clockOut }));
  await assertFails(updateDoc(recRef("emp1"), {
    clockOut: new Date("2026-08-02T18:00:00Z"),
    status: "completed",
  }));
});

// ── Cross-user + reviewer ───────────────────────────────────────────────────
test("DENY: an employee updates another employee's record", async () => {
  await seedRecord();
  await assertFails(updateDoc(recRef("emp2"), { clockOut, status: "completed" }));
});

test("ALLOW: an admin soft-deletes an employee's record", async () => {
  await seedRecord();
  await assertSucceeds(updateDoc(recRef("admin1"), {
    deletedAt: new Date(),
    updatedAt: new Date(),
  }));
});

test("ALLOW: the branch manager soft-deletes an employee's record", async () => {
  await seedRecord();
  await assertSucceeds(updateDoc(recRef("mgr1"), {
    deletedAt: new Date(),
    updatedAt: new Date(),
  }));
});

test("DENY: nobody can hard-delete an attendance record", async () => {
  await seedRecord();
  const { deleteDoc } = await import("firebase/firestore");
  await assertFails(deleteDoc(recRef("admin1")));
});
