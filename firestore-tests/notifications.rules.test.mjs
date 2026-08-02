import test from "node:test";
import {
  deleteDoc,
  doc,
  getDoc,
  setDoc,
  updateDoc,
} from "firebase/firestore";
import { assertFails, assertSucceeds, makeEnv } from "./helpers.mjs";

const env = await makeEnv("drop-rules-notifications");

test.after(() => env.cleanup());
test.beforeEach(async () => {
  // clearFirestore wipes the users makeEnv seeded, so the roles the rules
  // resolve via selfDoc() have to be rewritten for every case.
  await env.clearFirestore();
  await env.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
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
});

const as = (uid) => env.authenticatedContext(uid).firestore();

/// A notification doc exactly as the server producers write it — every optional
/// key present so a fixture can never accidentally pass a rule by omission.
const notification = (over = {}) => ({
  id: "n1",
  recipientUid: "emp1",
  senderUid: "system",
  type: "taskAssigned",
  title: "New Task Assigned",
  body: "Restock the cold case • Due today 2:59 PM",
  createdAt: new Date(),
  readAt: null,
  archivedAt: null,
  pinnedAt: null,
  payload: { taskId: "task1", route: "task_details" },
  ...over,
});

/// Writes the fixture with rules bypassed. NOT `helpers.seed` — that one is
/// hardcoded to `tasks/{id}`, which would leave `notifications/n1` absent and
/// make every assertion below pass for the wrong reason.
const seedNotification = (id = "n1", over = {}) =>
  env.withSecurityRulesDisabled((ctx) =>
    setDoc(
      doc(ctx.firestore(), `notifications/${id}`),
      notification({ id, ...over }),
    ),
  );

test("a recipient can mark their own notification read, archived, or pinned", async () => {
  await seedNotification();
  const db = as("emp1");
  await assertSucceeds(updateDoc(doc(db, "notifications/n1"), { readAt: new Date() }));
  await assertSucceeds(updateDoc(doc(db, "notifications/n1"), { archivedAt: new Date() }));
  await assertSucceeds(updateDoc(doc(db, "notifications/n1"), { pinnedAt: new Date() }));
});

// The P0 this rule change exists for: before it, the update rule checked only
// the OLD doc and restricted no fields, so a recipient could rewrite the
// content and re-home the doc into someone else's inbox with a deep link of
// their choosing.
test("a recipient cannot re-home their notification or rewrite server-authored content", async () => {
  const forbidden = [
    { recipientUid: "emp2" },
    { title: "Forged title" },
    { body: "Forged body" },
    { type: "taskOverdue" },
    { payload: { route: "task_details", taskId: "attacker-choice" } },
    { senderUid: "emp1" },
    // A legal field smuggled in alongside an illegal one must still be denied.
    { readAt: new Date(), recipientUid: "emp2" },
  ];
  for (const patch of forbidden) {
    await seedNotification();
    await assertFails(updateDoc(doc(as("emp1"), "notifications/n1"), patch));
  }
});

test("a non-recipient non-admin cannot update a notification", async () => {
  await seedNotification();
  await assertFails(
    updateDoc(doc(as("emp2"), "notifications/n1"), { readAt: new Date() }),
  );
});

// Unchanged behaviour, pinned so a future edit can't quietly open it up: every
// client-produced notification must go through the `sendNotification` callable.
test("notifications cannot be created directly, including by an admin", async () => {
  await assertFails(setDoc(doc(as("emp1"), "notifications/n1"), notification()));
  await assertFails(
    setDoc(doc(as("admin1"), "notifications/n2"), notification({ id: "n2" })),
  );
});

// Unchanged behaviour, pinned: narrowing `update` must not have narrowed these.
test("the recipient and an admin keep their read and delete access", async () => {
  await seedNotification();
  await assertSucceeds(getDoc(doc(as("emp1"), "notifications/n1")));
  await assertSucceeds(deleteDoc(doc(as("emp1"), "notifications/n1")));

  await seedNotification();
  await assertSucceeds(getDoc(doc(as("admin1"), "notifications/n1")));
  await assertSucceeds(deleteDoc(doc(as("admin1"), "notifications/n1")));
});

test("a non-recipient non-admin cannot read a notification", async () => {
  await seedNotification();
  await assertFails(getDoc(doc(as("emp2"), "notifications/n1")));
});
