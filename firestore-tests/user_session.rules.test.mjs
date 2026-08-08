import test from "node:test";
import { doc, setDoc, updateDoc } from "firebase/firestore";
import { assertFails, assertSucceeds, makeEnv } from "./helpers.mjs";

/// Single-active-session enforcement (ADR-023) writes `activeSessionId` to the
/// caller's OWN user document at every sign-in. It shipped **without a rules
/// change**, on the claim that the field is not in the `users` update rule's
/// privileged freeze-list and is therefore already covered by the owner-update
/// clause.
///
/// That claim is load-bearing in the worst possible way: if it is wrong, the
/// claim write is denied, `AuthCubit` treats a failed claim as a failed sign-in,
/// and **nobody can log in at all**. The Dart suite runs against fake
/// repositories and never evaluates a rule, so it would stay green through that
/// outage. These cases are the only thing that can catch it.
const env = await makeEnv("drop-rules-user-session");

test.after(() => env.cleanup());
test.beforeEach(async () => {
  await env.clearFirestore();
  await env.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    await setDoc(doc(db, "users/admin1"), { role: "admin", isActive: true });
    await setDoc(doc(db, "users/emp1"), {
      role: "employee",
      branchId: "branch1",
      isActive: true,
      activeSessionId: "old-device",
    });
    await setDoc(doc(db, "users/emp2"), {
      role: "employee",
      branchId: "branch1",
      isActive: true,
    });
  });
});

const as = (uid) => env.authenticatedContext(uid).firestore();

test("the owner may claim their own session (the sign-in write)", async () => {
  await assertSucceeds(
    updateDoc(doc(as("emp1"), "users/emp1"), {
      activeSessionId: "new-device",
      activeSessionAt: new Date(),
      updatedAt: new Date(),
    }),
  );
});

test("the owner may claim a session on a document that never had one", async () => {
  // The back-compat path: every account that has not signed in since ADR-023.
  await assertSucceeds(
    updateDoc(doc(as("emp2"), "users/emp2"), {
      activeSessionId: "first-claim",
      activeSessionAt: new Date(),
    }),
  );
});

test("nobody may claim SOMEONE ELSE's session", async () => {
  // This is the attack the whole feature would otherwise enable: writing a
  // stranger's `activeSessionId` signs every one of their devices out.
  await assertFails(
    updateDoc(doc(as("emp2"), "users/emp1"), { activeSessionId: "hijack" }),
  );
});

test("an admin may still write it (support / forced eviction)", async () => {
  await assertSucceeds(
    updateDoc(doc(as("admin1"), "users/emp1"), { activeSessionId: "reset" }),
  );
});

test("claiming a session cannot smuggle a privileged field through", async () => {
  // The claim is a self-write, so it travels the same owner-update clause that
  // freezes role/isActive/branchId. Bundling one in must still be denied.
  await assertFails(
    updateDoc(doc(as("emp1"), "users/emp1"), {
      activeSessionId: "new-device",
      role: "admin",
    }),
  );
  await assertFails(
    updateDoc(doc(as("emp1"), "users/emp1"), {
      activeSessionId: "new-device",
      branchId: "branch2",
    }),
  );
});

test("a signed-out client may not claim anything", async () => {
  await assertFails(
    updateDoc(doc(env.unauthenticatedContext().firestore(), "users/emp1"), {
      activeSessionId: "anon",
    }),
  );
});
