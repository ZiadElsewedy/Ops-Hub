import test from "node:test";
import { doc, getDoc, setDoc, deleteDoc } from "firebase/firestore";
import { makeEnv, assertFails, assertSucceeds } from "./helpers.mjs";

/// Security-rules contract for `attendance_week_reviews/{reviewId}` (ADR-019).
///
/// The week review is an **assertion, not a lock**: these rules decide who may
/// state "I reviewed this week", and nothing else. No other collection's writes
/// are affected by a review existing — if that ever changes, ADR-019 has been
/// lost and this file should fail loudly.
const env = await makeEnv("drop-rules-attendance-week-reviews");

test.after(() => env.cleanup());
// `clearFirestore()` wipes the seeded `users/*` docs that `selfRole()` reads,
// so every role check would silently fail without reseeding them.
test.beforeEach(() => env.clearFirestore().then(() => reseedUsers()));

async function reseedUsers() {
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
  });
}

const as = (uid) => env.authenticatedContext(uid).firestore();
const anon = () => env.unauthenticatedContext().firestore();

const ID = "branch1_20260726";
const review = (over = {}) => ({
  branchId: "branch1",
  weekStartKey: "20260726",
  reviewedBy: "mgr1",
  reviewedByName: "Manager One",
  reviewedAt: new Date("2026-08-01T18:00:00Z"),
  note: null,
  ...over,
});

async function seed(over = {}) {
  await env.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), `attendance_week_reviews/${ID}`), review(over));
  });
}

test("a manager reviews their own branch's week", async () => {
  await assertSucceeds(
    setDoc(doc(as("mgr1"), `attendance_week_reviews/${ID}`), review()),
  );
});

test("a manager cannot review another branch's week", async () => {
  await assertFails(
    setDoc(
      doc(as("mgr2"), `attendance_week_reviews/${ID}`),
      review({ reviewedBy: "mgr2" }),
    ),
  );
});

test("attribution cannot be forged — reviewedBy must be the caller", async () => {
  // Attribution is the entire point of the feature: a review signed with
  // someone else's name is worse than no review at all.
  await assertFails(
    setDoc(
      doc(as("mgr1"), `attendance_week_reviews/${ID}`),
      review({ reviewedBy: "admin1" }),
    ),
  );
});

test("an admin reviews any branch", async () => {
  await assertSucceeds(
    setDoc(
      doc(as("admin1"), `attendance_week_reviews/branch2_20260726`),
      review({ branchId: "branch2", reviewedBy: "admin1" }),
    ),
  );
});

test("an employee can neither read nor write a review", async () => {
  await seed();
  // It is a management sign-off, not a fact about their own shift.
  await assertFails(getDoc(doc(as("emp1"), `attendance_week_reviews/${ID}`)));
  await assertFails(
    setDoc(
      doc(as("emp1"), `attendance_week_reviews/${ID}`),
      review({ reviewedBy: "emp1" }),
    ),
  );
});

test("an anonymous caller is refused entirely", async () => {
  await seed();
  await assertFails(getDoc(doc(anon(), `attendance_week_reviews/${ID}`)));
  await assertFails(
    setDoc(doc(anon(), `attendance_week_reviews/${ID}`), review()),
  );
});

test("own-branch manager and admin can read", async () => {
  await seed();
  await assertSucceeds(getDoc(doc(as("mgr1"), `attendance_week_reviews/${ID}`)));
  await assertSucceeds(getDoc(doc(as("admin1"), `attendance_week_reviews/${ID}`)));
  await assertFails(getDoc(doc(as("mgr2"), `attendance_week_reviews/${ID}`)));
});

test("Reopen — withdrawing the assertion is as legitimate as making it", async () => {
  await seed();
  await assertSucceeds(
    deleteDoc(doc(as("mgr1"), `attendance_week_reviews/${ID}`)),
  );
});

test("a manager cannot reopen another branch's week", async () => {
  await seed();
  await assertFails(deleteDoc(doc(as("mgr2"), `attendance_week_reviews/${ID}`)));
});

test("re-reviewing updates in place rather than duplicating", async () => {
  await seed();
  await assertSucceeds(
    setDoc(
      doc(as("mgr1"), `attendance_week_reviews/${ID}`),
      review({ note: "Checked again after Sara's correction" }),
    ),
  );
});
