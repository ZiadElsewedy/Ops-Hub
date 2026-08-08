"use strict";

/**
 * Who a client may send a notification to (`sendNotification`).
 *
 * Extracted as a pure predicate because the inline version shipped a defect that
 * no test could have caught in `index.js`: it asked only "is the recipient in my
 * branch?", and **admins are provisioned with no branch at all** (the role is
 * global — see PROJECT_CONTEXT §8, and `create_account_screen._needsBranch`).
 * So `recipientBranch === callerBranch` compared `""` against `"branch1"` and an
 * employee could never reach an admin.
 *
 * The operational cost of that was silent and total: `NotifyTaskEvent` routes
 * `taskSubmitted` to `task.createdBy`, so **every task an admin created was
 * submitted for review and the admin was never told.** The callable threw
 * `permission-denied`, the datasource turned it into a `ServerException`, and
 * `NotifyTaskEvent`'s deliberate catch-all swallowed it to a `developer.log` —
 * the employee saw a normal successful submission. The same held for any
 * generated shift task whose template an admin set up, since the instance
 * inherits the template's `createdBy`.
 */

/** The role string DROP treats as global (no branch, reaches everything). */
const ADMIN_ROLE = "admin";

/**
 * Normalizes a user document into just the two facts reachability depends on.
 * Missing/absent role degrades to `employee`, mirroring
 * `UserRole.fromString`'s "unknown never escalates" rule on the client.
 */
function reachFacts(userDoc) {
  const data = userDoc || {};
  return {
    isAdmin: String(data.role || "employee") === ADMIN_ROLE,
    branchId: String(data.branchId || ""),
  };
}

/**
 * Whether [caller] may send a notification to [recipient].
 *
 * Three ways to be reachable, in the order they matter:
 *  - **the caller is an admin** — the role is global, so it reaches every branch;
 *  - **the recipient is an admin** — an admin is the escalation target of the
 *    workflows that produce client notifications (a task they created coming
 *    back for review, a case, a report). They are branchless *by design*, so a
 *    branch comparison can never reach them and never will; this clause is what
 *    makes "notify whoever owns this work" possible at all;
 *  - **same branch** — the original rule, unchanged, for everyone else.
 *
 * Everything outside those three stays denied: an employee still cannot notify
 * another branch's staff, and a caller with no branch of their own (a
 * misprovisioned account) reaches nobody but admins.
 *
 * This is a *reachability* rule, not an authorization rule. What may be SENT is
 * constrained separately and independently by the `CLIENT_NOTIFICATION_TYPES`
 * whitelist, the title/body length caps, the payload key whitelist, the 50-item
 * cap, and the server-stamped `senderUid` — so widening reach to admins does not
 * widen what an employee can forge, only who can be told about it.
 */
function canNotify(caller, recipient) {
  const from = reachFacts(caller);
  const to = reachFacts(recipient);
  if (from.isAdmin) return true;
  if (to.isAdmin) return true;
  return from.branchId !== "" && to.branchId === from.branchId;
}

module.exports = { ADMIN_ROLE, canNotify, reachFacts };
