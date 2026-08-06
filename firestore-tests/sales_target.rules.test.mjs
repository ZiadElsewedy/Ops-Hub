import test from "node:test";
import { collection, deleteDoc, doc, getDoc, setDoc, updateDoc } from "firebase/firestore";
import { assertFails, assertSucceeds, makeEnv } from "./helpers.mjs";

const env = await makeEnv("drop-rules-sales-target");
test.after(() => env.cleanup());
test.beforeEach(async () => { await env.clearFirestore(); await seedUsersAndTarget(); });
const as = (uid) => env.authenticatedContext(uid).firestore();
const submission = (over = {}) => ({
  id: "branch1_20260805", branchId: "branch1", monthKey: "202608", businessDateKey: "20260805",
  businessTimeZone: "Africa/Cairo", amountPiastres: 0, status: "pending", submittedById: "emp1",
  submittedByName: "Employee One", schemaVersion: 1, ...over,
});
async function seedUsersAndTarget() {
  await env.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    await Promise.all([
      setDoc(doc(db, "users/emp1"), { role: "employee", branchId: "branch1", isActive: true }),
      setDoc(doc(db, "users/emp2"), { role: "employee", branchId: "branch1", isActive: true }),
      setDoc(doc(db, "users/mgr1"), { role: "manager", branchId: "branch1", isActive: true }),
      setDoc(doc(db, "users/admin1"), { role: "admin", isActive: true }),
      setDoc(doc(db, "branch_sales_months/branch1_202608"), { branchId: "branch1", monthKey: "202608" }),
      // branch1 runs monthly targets; branch2 deliberately does not.
      setDoc(doc(db, "branches/branch1"), { name: "Branch One", isActive: true, salesTargetEnabled: true }),
      setDoc(doc(db, "branches/branch2"), { name: "Branch Two", isActive: true, salesTargetEnabled: false }),
    ]);
  });
}
const seedSubmission = (id, data) => env.withSecurityRulesDisabled((ctx) => setDoc(doc(ctx.firestore(), `branch_sales_submissions/${id}`), data));

test("ALLOW: active employee creates one valid own pending submission", async () => {
  await assertSucceeds(setDoc(doc(as("emp1"), "branch_sales_submissions/branch1_20260805"), submission()));
});
test("DENY: forged branch/user/status/decision/id and overwrite", async () => {
  const attempts = [
    submission({ submittedById: "emp2" }), submission({ branchId: "branch2", id: "branch2_20260805" }),
    submission({ status: "approved" }), submission({ decisionById: "mgr1" }), submission({ id: "wrong" }),
  ];
  for (const [i, value] of attempts.entries()) await assertFails(setDoc(doc(as("emp1"), `branch_sales_submissions/${value.id || `x${i}`}`), value));
  await seedSubmission("branch1_20260805", submission());
  await assertFails(setDoc(doc(as("emp1"), "branch_sales_submissions/branch1_20260805"), submission()));
});
test("DENY: employee cannot update or delete a submission", async () => {
  await seedSubmission("branch1_20260805", submission());
  await assertFails(updateDoc(doc(as("emp1"), "branch_sales_submissions/branch1_20260805"), { amountPiastres: 1 }));
  await assertFails(deleteDoc(doc(as("emp1"), "branch_sales_submissions/branch1_20260805")));
});
test("employee sees own records and peers' approved records only", async () => {
  await seedSubmission("branch1_20260805", submission({ submittedById: "emp2" }));
  await seedSubmission("branch1_20260804", submission({ id: "branch1_20260804", businessDateKey: "20260804", submittedById: "emp2", status: "approved" }));
  await assertFails(getDoc(doc(as("emp1"), "branch_sales_submissions/branch1_20260805")));
  await assertSucceeds(getDoc(doc(as("emp1"), "branch_sales_submissions/branch1_20260804")));
});
test("manager/admin cannot client-write targets or decisions; unauthenticated is denied", async () => {
  await seedSubmission("branch1_20260805", submission());
  await assertFails(updateDoc(doc(as("mgr1"), "branch_sales_months/branch1_202608"), { targetPiastres: 1 }));
  await assertFails(updateDoc(doc(as("admin1"), "branch_sales_submissions/branch1_20260805"), { status: "approved" }));
  await assertFails(getDoc(doc(env.unauthenticatedContext().firestore(), "branch_sales_months/branch1_202608")));
  await assertFails(setDoc(doc(env.unauthenticatedContext().firestore(), "branch_sales_submissions/branch1_20260806"), submission({ id: "branch1_20260806", businessDateKey: "20260806" })));
});

test("DENY: a branch that has monthly targets switched off accepts no submission", async () => {
  await env.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    await Promise.all([
      setDoc(doc(db, "users/emp3"), { role: "employee", branchId: "branch2", isActive: true }),
      setDoc(doc(db, "branch_sales_months/branch2_202608"), { branchId: "branch2", monthKey: "202608" }),
    ]);
  });
  await assertFails(setDoc(doc(as("emp3"), "branch_sales_submissions/branch2_20260805"),
    submission({ id: "branch2_20260805", branchId: "branch2", submittedById: "emp3" })));
});

test("DENY: a branch with no branch document at all accepts no submission", async () => {
  await env.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    await Promise.all([
      setDoc(doc(db, "users/emp4"), { role: "employee", branchId: "ghost", isActive: true }),
      setDoc(doc(db, "branch_sales_months/ghost_202608"), { branchId: "ghost", monthKey: "202608" }),
    ]);
  });
  await assertFails(setDoc(doc(as("emp4"), "branch_sales_submissions/ghost_20260805"),
    submission({ id: "ghost_20260805", branchId: "ghost", submittedById: "emp4" })));
});
