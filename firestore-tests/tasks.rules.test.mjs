import test from "node:test";
import assert from "node:assert";
import {
  collection,
  doc,
  getDoc,
  getDocs,
  query,
  where,
  setDoc,
  updateDoc,
  deleteDoc,
} from "firebase/firestore";
import {
  makeEnv,
  currentTask,
  legacyTask,
  seed,
  assertFails,
  assertSucceeds,
} from "./helpers.mjs";

/// Security-rules contract for `tasks/{taskId}` — the Automated Tasks spec
/// (Phases 1–3) as enforced by the server, not as intended by the client.
///
/// Every fixture uses the **real `TaskModel.toMap()` shape**, where an unset
/// optional is present-with-null rather than absent. That distinction is the
/// entire reason this suite exists: on 2026-07-28 a rule defaulted a nullable
/// field to `''`, which `get(key, '')` never returns for a null-valued key, and
/// every task creation in production was denied.
const env = await makeEnv("drop-rules-tasks");

test.after(() => env.cleanup());
test.beforeEach(() => env.clearFirestore().then(() => reseedUsers()));

// clearFirestore() wipes the seeded user docs that selfDoc() depends on.
const reseedUsers = () =>
  env.withSecurityRulesDisabled(async (ctx) => {
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
  });

const as = (uid) => env.authenticatedContext(uid).firestore();

// ─── Creation ───────────────────────────────────────────────────────

test("a manager creates a task using the exact payload the app sends", async () => {
  // THE REGRESSION TEST. `currentTask()` carries `cancelReason: null` and the
  // rest of the Phase 1–3 keys as explicit nulls, which is what
  // `TaskModel.toMap()` produces. A fixture that omitted them would pass while
  // production stayed broken.
  await assertSucceeds(
    setDoc(doc(as("mgr1"), "tasks/c1"), currentTask({ id: "c1" })),
  );
});

test("an admin creates a task in any branch", async () => {
  await assertSucceeds(
    setDoc(
      doc(as("admin1"), "tasks/c2"),
      currentTask({ id: "c2", branchId: "branch2" }),
    ),
  );
});

test("a manager cannot create a task outside their branch", async () => {
  await assertFails(
    setDoc(
      doc(as("mgr1"), "tasks/c3"),
      currentTask({ id: "c3", branchId: "branch2" }),
    ),
  );
});

test("an employee cannot create a task at all", async () => {
  await assertFails(
    setDoc(doc(as("emp1"), "tasks/c4"), currentTask({ id: "c4" })),
  );
});

test("nobody can forge a terminal outcome at creation", async () => {
  // `missed` is server-owned; `cancelled` is a decision someone has to take
  // explicitly, never a state a task is born into (spec §4.4 / §5).
  await assertFails(
    setDoc(
      doc(as("mgr1"), "tasks/c5"),
      currentTask({ id: "c5", status: "missed", missedAt: new Date() }),
    ),
  );
  await assertFails(
    setDoc(
      doc(as("mgr1"), "tasks/c6"),
      currentTask({
        id: "c6",
        status: "cancelled",
        cancelledAt: new Date(),
        cancelReason: "duplicate",
      }),
    ),
  );
  // …and not by smuggling the evidence in on an otherwise-pending task.
  await assertFails(
    setDoc(
      doc(as("mgr1"), "tasks/c7"),
      currentTask({ id: "c7", cancelReason: "duplicate" }),
    ),
  );
});

// ─── Reads ──────────────────────────────────────────────────────────

test("reads stay scoped: admin all, manager own branch, employee own tasks", async () => {
  await seed(env, "r1", currentTask());
  // Unassigned must clear BOTH the array and the legacy single-assignee mirror —
  // `isTaskAssignee()` still honours `assignedEmployeeId` for pre-Phase-9 docs,
  // so leaving it set would (correctly) grant the read and mask the check.
  await seed(
    env,
    "r2",
    currentTask({
      branchId: "branch2",
      assigneeIds: [],
      assignedEmployeeId: null,
    }),
  );

  await assertSucceeds(getDocs(collection(as("admin1"), "tasks")));
  await assertSucceeds(
    getDocs(query(collection(as("mgr1"), "tasks"), where("branchId", "==", "branch1"))),
  );
  await assertSucceeds(
    getDocs(
      query(
        collection(as("emp1"), "tasks"),
        where("assigneeIds", "array-contains", "emp1"),
      ),
    ),
  );
  await assertSucceeds(getDoc(doc(as("emp1"), "tasks/r1")));
  // Another branch's task, not assigned to them.
  await assertFails(getDoc(doc(as("emp1"), "tasks/r2")));
});

// ─── Normal lifecycle still works ───────────────────────────────────

test("the ordinary lifecycle is unaffected by the cancellation rules", async () => {
  await seed(env, "u1", currentTask());
  await assertSucceeds(
    updateDoc(doc(as("mgr1"), "tasks/u1"), { title: "Edited" }),
  );

  await seed(env, "u2", currentTask());
  await assertSucceeds(
    updateDoc(doc(as("emp1"), "tasks/u2"), {
      status: "started",
      startedAt: new Date(),
      version: 1,
      activityLog: [{ status: "started", actorId: "emp1", at: new Date() }],
    }),
  );

  await seed(env, "u3", currentTask({ status: "waitingReview" }));
  await assertSucceeds(
    updateDoc(doc(as("mgr1"), "tasks/u3"), {
      status: "approved",
      approvedBy: "mgr1",
      approvedAt: new Date(),
      requiresRework: false,
      version: 1,
      activityLog: [{ status: "approved", actorId: "mgr1", at: new Date() }],
    }),
  );
});

// ─── Cancellation (spec §5) ─────────────────────────────────────────

const cancelPatch = (over = {}) => ({
  status: "cancelled",
  cancelledAt: new Date(),
  cancelledBy: "mgr1",
  cancelReason: "duplicate",
  cancelNote: null,
  reportedIncorrectBy: null,
  reportedIncorrectAt: null,
  reportedIncorrectNote: null,
  version: 1,
  activityLog: [{ status: "cancelled", actorId: "mgr1", at: new Date() }],
  ...over,
});

test("a manager cancels from pending or started, with a picklist reason", async () => {
  await seed(env, "x1", currentTask());
  await assertSucceeds(updateDoc(doc(as("mgr1"), "tasks/x1"), cancelPatch()));

  await seed(env, "x2", currentTask({ status: "started" }));
  await assertSucceeds(
    updateDoc(
      doc(as("mgr1"), "tasks/x2"),
      cancelPatch({ cancelReason: "shift_cancelled" }),
    ),
  );
});

test("a submitted task must be reviewed, never voided (§5.4)", async () => {
  for (const status of ["waitingReview", "completed", "rejected"]) {
    await seed(env, `x-${status}`, currentTask({ status }));
    await assertFails(
      updateDoc(doc(as("mgr1"), `tasks/x-${status}`), cancelPatch()),
    );
  }
});

test("a cancellation without a valid reason is refused (§5.5)", async () => {
  await seed(env, "x3", currentTask());
  // No reason at all.
  await assertFails(
    updateDoc(doc(as("mgr1"), "tasks/x3"), cancelPatch({ cancelReason: null })),
  );
  // A code outside the frozen picklist.
  await assertFails(
    updateDoc(
      doc(as("mgr1"), "tasks/x3"),
      cancelPatch({ cancelReason: "because_i_said_so" }),
    ),
  );
  // Free text is not a code.
  await assertFails(
    updateDoc(
      doc(as("mgr1"), "tasks/x3"),
      cancelPatch({ cancelReason: "", cancelNote: "not needed anymore" }),
    ),
  );
  // Missing the timestamp.
  await assertFails(
    updateDoc(doc(as("mgr1"), "tasks/x3"), cancelPatch({ cancelledAt: null })),
  );
});

test("employees may never cancel, and managers only in their own branch (§5.1/§5.3)", async () => {
  await seed(env, "x4", currentTask());
  await assertFails(updateDoc(doc(as("emp1"), "tasks/x4"), cancelPatch()));
  await assertFails(updateDoc(doc(as("mgr2"), "tasks/x4"), cancelPatch()));
});

test("a cancelled task is frozen and undeletable (§3.5)", async () => {
  const cancelled = currentTask({
    status: "cancelled",
    cancelledAt: new Date(),
    cancelledBy: "mgr1",
    cancelReason: "duplicate",
  });
  await seed(env, "x5", cancelled);

  await assertFails(updateDoc(doc(as("mgr1"), "tasks/x5"), { title: "nope" }));
  // The reason is immutable — rewriting it would falsify by-reason reporting.
  await assertFails(
    updateDoc(doc(as("mgr1"), "tasks/x5"), { cancelReason: "no_longer_needed" }),
  );
  await assertFails(deleteDoc(doc(as("mgr1"), "tasks/x5")));
  await assertFails(deleteDoc(doc(as("admin1"), "tasks/x5")));
});

test("the cancellation record cannot be stamped onto a live task", async () => {
  await seed(env, "x6", currentTask());
  // Setting a reason without actually cancelling would poison the by-reason
  // count with tasks that were never cancelled.
  await assertFails(
    updateDoc(doc(as("mgr1"), "tasks/x6"), { cancelReason: "duplicate" }),
  );
  await assertFails(
    updateDoc(doc(as("mgr1"), "tasks/x6"), { cancelledAt: new Date() }),
  );
});

// ─── Report incorrect (spec §5.2) ───────────────────────────────────

const reportPatch = (uid, over = {}) => ({
  reportedIncorrectBy: uid,
  reportedIncorrectAt: new Date(),
  reportedIncorrectNote: "This is the night routine, not ours",
  version: 1,
  activityLog: [{ status: "reportedIncorrect", actorId: uid, at: new Date() }],
  ...over,
});

test("an assigned employee files a report under their own uid", async () => {
  await seed(env, "p1", currentTask());
  await assertSucceeds(
    updateDoc(doc(as("emp1"), "tasks/p1"), reportPatch("emp1")),
  );
});

test("an employee cannot forge a report as someone else", async () => {
  await seed(env, "p2", currentTask({ assigneeIds: ["emp1", "emp2"] }));
  await assertFails(
    updateDoc(doc(as("emp1"), "tasks/p2"), reportPatch("emp2")),
  );
});

test("an employee cannot overwrite or clear an open report", async () => {
  await seed(
    env,
    "p3",
    currentTask({
      assigneeIds: ["emp1", "emp2"],
      reportedIncorrectBy: "emp2",
      reportedIncorrectAt: new Date(),
      reportedIncorrectNote: "already reported",
    }),
  );
  // Clearing is the manager's decision — that is the whole point of routing it.
  await assertFails(
    updateDoc(doc(as("emp1"), "tasks/p3"), {
      reportedIncorrectBy: null,
      reportedIncorrectAt: null,
      reportedIncorrectNote: null,
    }),
  );
  await assertFails(
    updateDoc(doc(as("emp1"), "tasks/p3"), reportPatch("emp1")),
  );
});

test("a manager dismisses a report, and cancelling clears it too", async () => {
  const reported = currentTask({
    reportedIncorrectBy: "emp1",
    reportedIncorrectAt: new Date(),
    reportedIncorrectNote: "wrong shift",
  });

  await seed(env, "p4", reported);
  await assertSucceeds(
    updateDoc(doc(as("mgr1"), "tasks/p4"), {
      reportedIncorrectBy: null,
      reportedIncorrectAt: null,
      reportedIncorrectNote: null,
      version: 1,
    }),
  );

  await seed(env, "p5", reported);
  await assertSucceeds(updateDoc(doc(as("mgr1"), "tasks/p5"), cancelPatch()));
});

test("an employee's ordinary work is unaffected by the report guard", async () => {
  // start / submit / tick a checklist item must not accidentally trip the
  // report rules just because they leave those fields untouched.
  await seed(env, "p6", currentTask());
  await assertSucceeds(
    updateDoc(doc(as("emp1"), "tasks/p6"), {
      status: "started",
      startedAt: new Date(),
      version: 1,
      activityLog: [{ status: "started", actorId: "emp1", at: new Date() }],
    }),
  );
});

// ─── Scheduled start gate ──────────────────────────────────────────

const startPatch = (over = {}) => ({
  status: "started",
  startedAt: new Date(),
  version: 1,
  activityLog: [{ status: "started", actorId: "emp1", at: new Date() }],
  ...over,
});

test("an employee cannot start a task before its stored startsAt", async () => {
  await seed(
    env,
    "s1",
    currentTask({ startsAt: new Date(Date.now() + 60 * 60 * 1000) }),
  );

  await assertFails(updateDoc(doc(as("emp1"), "tasks/s1"), startPatch()));
});

test("an employee can start a task once startsAt has arrived", async () => {
  await seed(
    env,
    "s2",
    currentTask({ startsAt: new Date(Date.now() - 1000) }),
  );

  await assertSucceeds(updateDoc(doc(as("emp1"), "tasks/s2"), startPatch()));
});

test("an employee can still start a task with null startsAt", async () => {
  await seed(env, "s3", currentTask({ startsAt: null }));

  await assertSucceeds(updateDoc(doc(as("emp1"), "tasks/s3"), startPatch()));
});

test("rework has no schedule exception before startsAt", async () => {
  await seed(
    env,
    "s4",
    currentTask({
      status: "rejected",
      startsAt: new Date(Date.now() + 60 * 60 * 1000),
    }),
  );
  await assertFails(updateDoc(doc(as("emp1"), "tasks/s4"), startPatch()));
});

test("rework can start once startsAt has arrived", async () => {
  await seed(
    env,
    "s5",
    currentTask({
      status: "rejected",
      startsAt: new Date(Date.now() - 1000),
    }),
  );
  await assertSucceeds(updateDoc(doc(as("emp1"), "tasks/s5"), startPatch()));
});

// ─── Admin terminal correction (spec §6.4) ──────────────────────────

const correctionPatch = {
  status: "pending",
  missedAt: null,
  cancelledAt: null,
  cancelledBy: null,
  cancelReason: null,
  cancelNote: null,
  archivedAt: null,
  version: 2,
  activityLog: [
    { status: "terminalCorrected", actorId: "admin1", at: new Date() },
  ],
};

test("an admin returns a cancelled or missed task to pending", async () => {
  await seed(
    env,
    "t1",
    currentTask({
      status: "cancelled",
      cancelledAt: new Date(),
      cancelledBy: "mgr1",
      cancelReason: "duplicate",
    }),
  );
  await assertSucceeds(
    updateDoc(doc(as("admin1"), "tasks/t1"), correctionPatch),
  );

  await seed(
    env,
    "t2",
    currentTask({ status: "missed", missedAt: new Date() }),
  );
  await assertSucceeds(
    updateDoc(doc(as("admin1"), "tasks/t2"), correctionPatch),
  );
});

test("a manager cannot correct a terminal — admin only (§6.4)", async () => {
  await seed(
    env,
    "t3",
    currentTask({
      status: "cancelled",
      cancelledAt: new Date(),
      cancelReason: "duplicate",
    }),
  );
  await assertFails(updateDoc(doc(as("mgr1"), "tasks/t3"), correctionPatch));
  await assertFails(updateDoc(doc(as("emp1"), "tasks/t3"), correctionPatch));
});

test("a correction must clear the outcome it undoes, and lands on pending", async () => {
  await seed(
    env,
    "t4",
    currentTask({
      status: "cancelled",
      cancelledAt: new Date(),
      cancelledBy: "mgr1",
      cancelReason: "duplicate",
    }),
  );
  // Leaving the cancellation evidence behind would put a task in `pending`
  // still carrying a reason it was cancelled for.
  await assertFails(
    updateDoc(doc(as("admin1"), "tasks/t4"), {
      ...correctionPatch,
      cancelReason: "duplicate",
    }),
  );
  // The correction lands on `pending`, not straight into the workflow.
  await assertFails(
    updateDoc(doc(as("admin1"), "tasks/t4"), {
      ...correctionPatch,
      status: "started",
    }),
  );
});

// ─── Backwards compatibility ────────────────────────────────────────

test("legacy task documents behave identically to current ones", async () => {
  // Documents written before Phase 1–3 have these keys ABSENT rather than null.
  // `get(key, null)` returns null for both shapes, which is what makes the
  // rules backwards-compatible — and defaulting to '' is what broke it.
  await seed(env, "L1", legacyTask());
  await assertSucceeds(
    updateDoc(doc(as("mgr1"), "tasks/L1"), { title: "Edited" }),
  );

  await seed(env, "L2", legacyTask());
  await assertSucceeds(updateDoc(doc(as("mgr1"), "tasks/L2"), cancelPatch()));

  await seed(env, "L3", legacyTask());
  await assertSucceeds(
    updateDoc(doc(as("emp1"), "tasks/L3"), reportPatch("emp1")),
  );

  await seed(env, "L4", legacyTask());
  await assertSucceeds(
    updateDoc(doc(as("emp1"), "tasks/L4"), {
      status: "started",
      startedAt: new Date(),
      version: 1,
      activityLog: [{ status: "started", actorId: "emp1", at: new Date() }],
    }),
  );

  // A legacy task can still be created (an older client build in the wild).
  await assertSucceeds(
    setDoc(doc(as("mgr1"), "tasks/L5"), legacyTask({ id: "L5" })),
  );
});

// ─── Standing guarantees that predate this work ─────────────────────

test("missed stays server-only and terminal", async () => {
  await seed(env, "m1", currentTask());
  await assertFails(
    updateDoc(doc(as("mgr1"), "tasks/m1"), {
      status: "missed",
      missedAt: new Date(),
    }),
  );

  await seed(env, "m2", currentTask({ status: "missed", missedAt: new Date() }));
  await assertFails(updateDoc(doc(as("mgr1"), "tasks/m2"), { title: "nope" }));
  await assertFails(deleteDoc(doc(as("mgr1"), "tasks/m2")));
});

test("an employee cannot forge review attribution or shrink history", async () => {
  await seed(
    env,
    "g1",
    currentTask({
      status: "waitingReview",
      activityLog: [
        { status: "pending", actorId: "mgr1", at: new Date() },
        { status: "started", actorId: "emp1", at: new Date() },
      ],
    }),
  );
  await assertFails(
    updateDoc(doc(as("emp1"), "tasks/g1"), {
      status: "approved",
      approvedBy: "emp1",
    }),
  );
  await assertFails(
    updateDoc(doc(as("emp1"), "tasks/g1"), { reviewNotes: "I approve myself" }),
  );
  await assertFails(
    updateDoc(doc(as("emp1"), "tasks/g1"), { activityLog: [] }),
  );
  await assertFails(
    updateDoc(doc(as("emp1"), "tasks/g1"), { assigneeIds: ["emp1", "emp2"] }),
  );
});

test("an approved task is locked, and only an admin reopens it", async () => {
  const approved = currentTask({
    status: "approved",
    approvedBy: "mgr1",
    approvedAt: new Date(),
  });
  await seed(env, "a1", approved);
  await assertFails(updateDoc(doc(as("mgr1"), "tasks/a1"), { title: "nope" }));
  await assertFails(deleteDoc(doc(as("mgr1"), "tasks/a1")));

  await seed(env, "a2", approved);
  await assertSucceeds(
    updateDoc(doc(as("admin1"), "tasks/a2"), {
      status: "started",
      approvedBy: null,
      approvedAt: null,
      archivedAt: null,
      requiresRework: false,
      version: 1,
      activityLog: [{ status: "started", actorId: "admin1", at: new Date() }],
    }),
  );
});

test("sanity: the rules file under test is the repository's own", async () => {
  const { RULES } = await import("./helpers.mjs");
  assert.ok(
    RULES.includes("match /tasks/{taskId}"),
    "helpers must load the real firestore.rules",
  );
});
