# Data Model — Firestore · Storage · Functions · Security

> The backend contract. Everything a client cannot be trusted to do lives here.
>
> **Field lists are deliberately not reproduced.** The `*Model` class *is* the
> schema — duplicating its fields here guarantees drift. This doc covers what the
> models **cannot** tell you: id schemes, ownership, the rules contract, and the
> server-side pipeline.

Collection names are centralized in
[`core/constants/app_constants.dart`](../../lib/core/constants/app_constants.dart).
Rules live in `firestore.rules` / `storage.rules`. Server logic is
`functions/index.js` (Node.js, `firebase-functions` v6, **2nd-gen**, region not
pinned → `us-central1`).

---

## 1. Collection tree

```
users/{uid}                              identity + profile + role/branch (admin-provisioned)
  └── private/compensation               salary + paymentNumber (owner + admin ONLY)

branches/{branchId}                      branch record (+ swapPolicy, + geofence)

tasks/{taskId}                           embedded checklist · activityLog · attachments
task_templates/{id}                      reusable blueprint (branchId '' = global)
recurringTaskTemplates/{id}              recurring shift-task blueprint (branch-scoped)
taskReminders/{taskId}                   reminder ledger (function-written)

weekly_schedules/{branchId}_{yyyy-MM-dd} one doc per (branch, week) — assignments/leave/notes/shiftPlan
shift_templates/{branchId}__{role}       per-branch configurable shift hours
shift_swaps/{swapId}                     swap request between two employees

attendance/{uid}_{yyyyMMdd}_{shift}      one record per person per shift per day
  └── events/{eventId}                   audit trail — ADMIN SDK ONLY, immutable
attendance_corrections/{id}              Pending → Approved/Rejected approval object

cases/{caseId}                           private conversation (NO creator uid on the doc)
  ├── reporter/identity                  the creator's uid/name (owner + admin ONLY)
  └── messages/{messageId}               conversation messages (immutable)

requests/{requestId}                     employee → manager approval
  └── events/{eventId}                   timeline (immutable)

broadcasts/{id}                          announcement (function-written)
broadcastTemplates/{id}                  reusable broadcast blueprint
broadcastSchedules/{id}                  scheduled / recurring broadcast
notifications/{id}                       one in-app notification per recipient

audit_logs/{id}                          EventTrackingService entries
automationRuns/{templateId}_{dateKey}    automation execution record (ADR-011): correlationId·schedule·validations·target·generation·notification·error·logs[]·immutable snapshot; client read-only
reminderConfig/{id}                      org-wide reminder rules ("global")
usageStats/{doc}                         FieldValue.increment counters
config/{doc}                             function-only config ("taskRetention") — no client path
counters/{id}                            refCode sequence (REQ-######)
savedAudiences/{id}                      declared in constants; no confirmed usage
```

`savedAudiences` and parts of `counters` are candidates for deletion — verify before
building on them.

## 2. Deterministic ids

Non-obvious and load-bearing. Each one buys idempotency for free.

| Document | Id | Why |
| --- | --- | --- |
| `attendance/{id}` | `{uid}_{yyyyMMdd}_{shift}` | Clock-in is **idempotent and offline-safe** — a retry writes the same doc rather than a duplicate shift |
| `weekly_schedules/{id}` | `{branchId}_{Sunday-yyyy-MM-dd}` | One doc per branch-week; addressable without a query |
| `shift_templates/{id}` | `{branchId}__{role}` | Direct lookup |
| Recurring shift-task instance | `rt_{templateId}_{yyyy-MM-dd}` (UTC) | The id **is** the duplicate guard; each instance persists its resolved `startsAt` / `deadline` window |
| Recurrence respawn | `rec_{sourceTaskId}` | Fixed the reopen → re-approve duplicate-task bug |

## 3. The two privacy splits

Both are enforced by rules, not by UI.

**Cases.** The case doc carries **no creator uid**. The reporter's identity lives in
`cases/{caseId}/reporter/identity`, readable only by the owner + admin — so a
same-branch manager handling a confidential case **cannot resolve who filed it**.
`reporterDisplayName` rides the parent doc only when the case is `normal`.

**Compensation.** `salaryAmount` / `salaryType` / `paymentMethod` are admin-set and
live in `users/{uid}/private/compensation`, never on the user doc. The owner may
self-edit **only** `paymentNumber` (the number their salary is sent to), enforced as
a field-diff check in rules.

## 4. Security model

Firebase Auth is the identity source. **All authorization is in rules** — no custom
claims; role and branch are read from the caller's own `users/{uid}` doc.

### Helpers (`firestore.rules`)

| Helper | Means |
| --- | --- |
| `selfDoc()` | `get(users/{auth.uid}).data` — Firestore caches this per request, so it bills once |
| `selfRole()` / `selfBranch()` | The caller's role / branch |
| `isAdmin()` / `isManager()` | Role checks |
| `canReachBranch(branch)` | **admin = any branch · manager = own branch only.** Employees never reach a whole branch |
| `isCaseReporter(caseId)` | Resolves case ownership via the private identity subdoc |

### Per-collection

| Collection | Read | Create | Update | Delete |
| --- | --- | --- | --- | --- |
| `users/{uid}` | **any signed-in user** — flat directory ([ADR-012](../decisions/ADR-012-chat-directory-is-flat.md)); chat is org-wide, so branch/role read scoping was removed. Compensation is unaffected (private subdoc, next row) | **false** — `createUserAccount` only | admin (all) · owner (profile + first-login flags + fcmToken; **privileged fields frozen**) | **false** — deactivate via `isActive` |
| `users/{uid}/private/{doc}` | owner · admin | admin · owner (`compensation`/`paymentNumber` only) | admin · owner (`paymentNumber` diff only) | false |
| `tasks/{id}` | branch-reachable · assignee · shift-task-in-my-branch | branch-reachable (never `missed` / `missedAt`) | branch-reachable (approved locked except admin reopen; missed locked) **or** assignee (can't reassign / move branch / forge review / set terminal; `activityLog` non-decreasing) | branch-reachable & neither approved nor missed |
| `attendance/{id}` | own · own-branch manager · admin | own | own (clock fields) · manager/admin | false |
| `attendance/{id}/events` | whoever can read the record | **false** | **false** | **false** — Admin SDK only |
| `attendance_corrections/{id}` | involved · manager · admin | employee (own) | reviewer — **self-approval forbidden** | false |
| `weekly_schedules/{id}` | branch-reachable · branch employee | branch-reachable | branch-reachable | branch-reachable |
| `shift_templates/{id}` | branch-reachable | admin · own-branch manager | same | same |
| `shift_swaps/{id}` | branch-reachable · requester · target | requester, own branch, **future slot only** | manager/admin (**never `managerApproved`**) · involved employee (status + updatedAt only) | branch-reachable |
| `branches/{id}` | any signed-in | admin | admin | false — soft delete |
| `cases/{id}` | admin · own-branch manager (`visibleToManager`) · reporter | admin · branch member (own branch) | admin · own-branch manager (status) | admin |
| `cases/{id}/messages/{id}` | anyone who can read the case | participant · `kind=='message'` · case not closed · `createdAt==request.time` · author-stamped | false | false |
| `requests/{id}` | requester · admin · own-branch manager | employee/requester, own branch | admin · own-branch manager (approve/reject/reopen); admin-only soft delete via `deletedAt` | **false** |
| `requests/{id}/events` | participants | participants (own, while active) | false | false |
| `broadcasts/{id}` | admin · `targetUserId` · in `targetUserIds` · branch/all member | **false** — `sendBroadcast` only | `archivedAt` diff only, by admin/sender/branch-manager | admin · sender · branch-manager |
| `notifications/{id}` | recipient · admin | **false** — functions only | recipient (mark read) | recipient · admin |
| `task_templates` · `broadcastTemplates` · `recurringTaskTemplates` | admin · manager | admin · own-branch manager | admin · owning-branch manager | same |
| `broadcastSchedules/{id}` | admin · creator | creator (manager own branch) | admin · creator | admin · creator |
| `audit_logs/{id}` | admin | server | false | false |
| `taskReminders/{id}` | admin | false | false | false |
| `reminderConfig/{id}` | admin · manager | — | admin | — |
| `usageStats/{doc}` | admin | any signed-in (increment) | any signed-in | false |
| `{path=**}/reporter/{doc}` (collection-group) | admin · `createdByUserId==uid` | signed-in, `identity` doc, self-claimed uid | false | false |

### Isolation invariants

- **Admin-provisioned identity.** `createUserAccount` (Admin SDK) is the only user-doc
  creation path. `users` `create: if false`.
- **Privilege freeze.** The self-update rule enumerates `role`, `isActive`,
  `branchId`, `assignedShift`, `position`, `employmentStatus`, `createdBy`,
  `salaryAmount`, `salaryType`, `paymentMethod` and requires them **unchanged**.
  The client mirrors this by keeping them out of `UserModel.toMap()`.
- **Function-owned writes.** Broadcasts, notifications, swap finalization, case
  opening/system messages, attendance audit, and account creation are Admin SDK.
  See [ADR-005](../decisions/ADR-005-server-authoritative-writes.md).

## 5. Cloud Functions

23 functions, all in `functions/index.js`. `dispatchBroadcast(params)` is shared by
the callable and the scheduler.

| Function | Trigger | Purpose |
| --- | --- | --- |
| `sendBroadcast` | `onCall` | Validate sender → resolve recipients → persist → fan out inbox + FCM → prune dead tokens |
| `createUserAccount` | `onCall` (admin) | Provision Auth user + seed `users/{uid}` |
| `adminResetPassword` | `onCall` (admin) | Temp password + force change |
| `approveSwap` | `onCall` | Re-validate + **atomically exchange** a coworker-approved swap |
| `claimFcmToken` | `onDocumentUpdated users/{uid}` | Enforce **exclusive** token ownership — strips the token from every other user |
| `sendNotification` | `onCall` | The only client path to create a notification (type whitelist, branch-reach check, server-stamped sender) |
| `onNotificationCreated` | `onDocumentCreated notifications/{id}` | Deliver the FCM push |
| `onCaseCreated` | `onDocumentCreated cases/{id}` | Opening message (de-identified if confidential) + notify |
| `onCaseUpdated` | `onDocumentUpdated cases/{id}` | Status change → system message + notify |
| `onCaseMessageCreated` | `onDocumentCreated cases/{id}/messages/{id}` | Bump parent + notify the other party |
| `onRequestCreated` | `onDocumentCreated requests/{id}` | `REQ-######` refCode + timeline + notify |
| `onRequestUpdated` | `onDocumentUpdated requests/{id}` | Decision events + notify |
| `onRequestEventCreated` | `onDocumentCreated requests/{id}/events/{id}` | Notify participants |
| `onAttendanceWritten` | `onDocumentWritten attendance/{id}` | **Derive the audit trail by diffing** — the client never writes it |
| `onAttendanceCorrectionWritten` | `onDocumentWritten attendance_corrections/{id}` | Correction lifecycle → apply resolution → audit event → notify |
| `autoCloseAttendance` | `onSchedule` | Never-clocked-out sessions → `pendingReview` |
| `generateShiftTaskInstances` | `onSchedule 24h` | Materialize one task per due recurring template; resolve/persist frozen weekly shift window; roster-filtered; deterministic id = dup guard |
| `autoEndRecurringShiftTasks` | `onSchedule 15 min` | Transactionally end only overdue generated `pending`/`started` shift tasks as server-owned `missed` |
| `runTaskReminders` | `onSchedule 30 min` | Escalating due24h → due1h → overdue, with a per-task ledger + quiet hours + cap |
| `runBroadcastSchedules` | `onSchedule 5 min` | Fire due schedules, advance `nextRunAt` |
| `broadcastHousekeeping` | `onSchedule 24h` | Delete archived notifications > 60d |
| `taskHousekeeping` | `onSchedule 24h` | Soft-archive approved/missed tasks, cold-tier Storage, opt-in hard delete |

Push carries `data.recipientUid` per token so the client can **drop** a message
addressed to a different user (defence against token drift). Dead tokens are pruned
on FCM error codes `registration-token-not-registered` /
`invalid-registration-token` / `invalid-argument`.

## 6. Storage

```
users/{uid}/avatar.jpg · cover.jpg            fixed path → overwrite
branches/{branchId}/logo.jpg · cover.jpg      fixed path → overwrite
tasks/{taskId}/attachments/{pushId}.{ext}     unique id → immutable
cases/{caseId}/attachments/{pushId}.{ext}     unique id → immutable
requests/{requestId}/attachments/{pushId}.{ext}
attendance/{...}
```

| Path | Read | Write |
| --- | --- | --- |
| `users/{uid}/{file}` | signed-in | owner only |
| `tasks` · `cases` · `requests` | signed-in | create only — update/delete **false** (immutable) |
| `branches/{id}/{file}` | signed-in | signed-in |

**Storage rules cannot read a Firestore role cheaply.** Branch/task/case writes are
therefore gated by the *Firestore write of the URL* onto the doc, which **is**
role-checked. Ids are unguessable 20-char auto-ids. This is a deliberate trade —
know it before "hardening" the Storage rules in isolation.

**Naming.** Profile/branch media use fixed filenames (a new upload overwrites;
Firebase issues a fresh token so the saved URL changes). Task/case/request media use
a fresh Firestore push id + extension from the source, Content-Type set from the
extension. All uploads go through
[`core/media/media_upload_service.dart`](../../lib/core/media/media_upload_service.dart)
— the single seam: progress via `snapshotEvents`, a hard timeout (60s profile / 180s
attachments), `Cache-Control`, and error translation that distinguishes permission
from network failures.

**Cleanup.** `taskHousekeeping` re-tiers media for archived approved/missed task
records to COLDLINE, and hard-deletes only under the opt-in `deleteAfterDays` purge. Client `deleteTask` /
`deleteRequest` remove the doc only — a deleted request **intentionally orphans** its
`events` subcollection (rare admin op).
