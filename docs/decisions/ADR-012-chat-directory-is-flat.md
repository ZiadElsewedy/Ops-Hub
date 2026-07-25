# ADR-012 — Chat is not org-scoped: a flat participant directory

**Status:** Accepted · **Date:** 2026-07-24

## Context

Every other feature in DROP is branch-scoped. Tasks, schedules, attendance,
requests and cases all answer "what may this person reach" with the same
predicate — `resource.branchId == selfBranch()`, with admin as a global
override. That invariant is documented in `PROJECT_CONTEXT.md` and enforced in
`firestore.rules`.

Chat's participant picker inherited that model, and it did not survive contact
with reality. Two failures, both structural:

1. **An admin has no `branchId`.** The role is global, so account provisioning
   omits the branch (`create_account_screen._needsBranch`). A live probe of the
   production `users` collection confirmed it: 1 admin, branchless; 8 employees
   across 2 branches; 1 manager. A branch query therefore returned *nothing at
   all* for an admin, and could never contain an admin for anyone else. Admins
   were unreachable in chat in both directions.
2. **The org chart is the wrong shape for messaging.** Even repaired
   (branch teammates + a role read for admins), the directory encoded a
   hierarchy that chat does not have. An employee in branch A had no way to
   message a manager in branch B, for no reason anyone asked for.

The first fix attempt (same day) kept the hierarchy and papered over it with a
role-based read. It worked, but it meant reachability was expressed as a
two-branch conditional whose only purpose was to reconstruct "basically
everyone" out of scoped queries.

## Decision

**Chat has a flat access model. Every authenticated user may message every other
active user.** No branch predicate, no role predicate — not in the Firestore
query, not in the repository, not in the use case, not in the cubit, not in the
UI.

The directory is one unfiltered read of `users`, with exactly two filters, both
in one place (`GetChatDirectory`):

- the caller is excluded (the backend also rejects a self-conversation);
- deactivated accounts are hidden (`isActive`, the app-wide access gate).

`isActive` is applied in the use case rather than as a query predicate on
purpose: `UserEntity` defaults a missing `isActive` to `true`, and an equality
filter would silently drop a legacy document instead of defaulting it.

**`firestore.rules` is brought in line rather than left inconsistent:**
`match /users/{uid}` read becomes `if isSignedIn()`. The previous
owner · admin · same-branch disjunction is deleted — under a flat directory
every one of those clauses is subsumed, and keeping them would have meant the
client asked one question while the rules answered another.

This ADR **names the decision it changes**: the branch-scoping invariant in
`PROJECT_CONTEXT.md` §Access model no longer applies to `users` *reads*. It
still governs every other collection, and it still governs all `users` *writes*.

## Consequences

**Accepted:**
- Any signed-in user can read any user document: profile fields, role, branch,
  position, employment status, and the optional contact details (phone, address,
  emergency contact). For a ~10-person internal roster where everyone is already
  directory-visible to their branch, this is a small widening of an existing
  exposure, not a new class of one.
- Salary and payment details are **not** included — they live in
  `users/{uid}/private/compensation`, which keeps its owner + admin rule.
- Writes are untouched: admin-only, plus the owner's own non-privileged fields,
  with every privileged field still frozen.

**Rejected alternatives:**
- *Keep branch scoping and special-case admins* — the previous fix. Rejected: it
  preserved a hierarchy chat does not have, and left cross-branch staff mutually
  unreachable.
- *Give admins a `branchId`* — rejected: it contradicts the global role and would
  have to be maintained forever.
- *A separate minimal `directory/{uid}` projection (name/photo/role only)* — the
  privacy-preserving option, and the right one if the roster ever grows or if
  contact details become sensitive. Rejected **for now** as premature for this
  scale ([ADR-010](ADR-010-lean-over-enterprise.md)): it doubles the write path
  for every profile edit and needs a backfill. **This is the documented exit if
  the tradeoff above stops being acceptable.**

**Requires a rules deploy.** Until `firestore.rules` ships, the client asks for
the full directory and the live ruleset denies it.
