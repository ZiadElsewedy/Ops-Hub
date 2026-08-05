# DROP — Automated Task Engine (Audit + Hardening)

> **Status:** P0 + P1 implemented (`feature/media-upload-v2`, 2026-07-11);
> **execution observability (Tier 1) implemented 2026-07-18** under
> [ADR-011](../decisions/ADR-011-automation-observability.md). Owner-approved
> scope after a full automation audit. Calibrated to small-team scale per
> [product philosophy](../../PROJECT_CONTEXT.md) — **no parallel automation
> backend, no round-robin assignment engine, no standalone analytics dashboard,
> no replay engine**. **Recurring-shift deadline close implemented 2026-07-19:**
> generated instances persist their resolved shift window and a bounded 15-minute
> server sweep ends only unfinished instances as `missed`. This doc is the source
> of truth for how recurring/scheduled task automation works and why it is now
> deterministic and observable.

---

## 1. What "automation" means in DROP

Two **independent** recurrence engines feed the one `tasks/{id}` collection:

| | **Path A — Shift-template recurrence** | **Path B — Per-task recurrence** |
|---|---|---|
| Blueprint | `recurringTaskTemplates/{id}` (a standing routine) | A `RecurrenceConfig` embedded on a `TaskEntity` |
| Trigger | `generateShiftTaskInstances` Cloud Function (01:00 Africa/Cairo daily) + client `_materializeTodayInstance` on template save; `autoEndRecurringShiftTasks` checks persisted deadlines every 15 min | Client `_spawnNextRecurrence` **after** a task is approved |
| Assignment | **Shift broadcast** — `assigneeIds: []`, targets whoever is rostered on that (day, shift) | Inherits the source task's `assigneeIds` |
| Instance id | Deterministic `rt_{templateId}_{yyyy-MM-dd}` where the date is the Africa/Cairo business civil day | Deterministic `rec_{sourceTaskId}` (**new** — was a random auto-id) |

There is **no single-employee selection engine**. "Automatic assignment" = a shift
task is visible to and notifies every rostered employee on its shift; a per-task
recurrence inherits its parent's assignees. This is deliberate (a small team wants
the whole shift to see the routine, not a lottery winner).

---

## 2. The duplicate bug — root cause

### Path B was the real duplicate-*task* vector (fixed)
`_spawnNextRecurrence` created the next instance with a **non-deterministic
auto-generated document id**. Its only protection against duplicates was an
*emergent* invariant (the approve state machine), not an *intrinsic* dedup key:

- Concurrent double-approve → already closed by the atomic `transitionTask`
  (only the winner reaches the spawn). ✔
- **Reopen → re-approve → duplicate.** `reopenTask` moves `approved → started`
  and keeps `recurrence` intact. The task legitimately reaches `waitingReview →
  approved` again, so the spawn runs a **second** time and — with a random id —
  writes a **second** "next" task. ✘ (reachable, this was the bug)
- Crash between commit and spawn → *zero* next tasks (a lost recurrence). ✘

### Path A duplicated *notifications*, not tasks
The deterministic id already prevented duplicate task documents, but the id check
was a non-atomic **read-then-`set`** and the notify step was unconditional, so an
overlapping run / scheduler retry could **re-notify** the whole roster (and blind-
`set` could overwrite a live doc).

### Systemic
No `maxInstances`/`retryCount` on scheduled functions (Cloud Scheduler is
at-least-once); no run history/observability.

---

## 3. Prevention strategy — idempotency made intrinsic

**Principle: one (source, occurrence) → exactly one deterministic document id,
written create-only.** Then retries, concurrency, and reopen→re-approve all
*converge* on one doc instead of multiplying.

- **Path B:** the successor's id is **`rec_{sourceTaskId}`**. Each task spawns at
  most one successor, so keying the successor on the (stable, globally-unique)
  current task id is the natural idempotency key — and, crucially, it does **not**
  depend on the deadline (which may be null). Written via the now-**atomic**
  `createTaskWithId` (Firestore transaction: get→if-exists-return-null→set). A
  duplicate spawn is a silent no-op. The successor deadline is rolled forward
  until it is in the future, so approving an old occurrence cannot create a
  permanently-late next task. Lineage is stored as `recurrenceRootId` (root task
  id, propagated down the chain) + `occurrenceKey` (the successor's due-date key,
  for display).
- **Path A (Cloud Function):** `get→set` replaced by an **atomic `ref.create()`**
  (throws `ALREADY_EXISTS` → skip). Roster notification runs **only when create
  actually succeeded**, and each notification uses a **deterministic id**
  (`autoassign_{taskId}_{uid}`) written with `set`, so a re-run can never
  double-notify.
- **Scheduler:** `generateShiftTaskInstances` is pinned to **01:00
  Africa/Cairo** so it runs before the earliest shift starts. It, plus
  `autoEndRecurringShiftTasks` and `runTaskReminders`, runs with
  `maxInstances: 1` (no overlap) + explicit `retryCount: 0` + `timeoutSeconds`.

---

## 4. Automation Center (extends the existing collection)

No new backend. `recurringTaskTemplates/{id}` gains **operational metadata**
(additive, no migration):

| Field | Writer | Meaning |
|---|---|---|
| `updatedBy` | client | who last edited the routine |
| `lastRunAt` | Cloud Function | last generation attempt |
| `nextRunAt` | Cloud Function | next scheduled generation (computed) |
| `lastStatus` | Cloud Function | `completed` / `skipped` / `failed` |
| `lastGeneratedTaskId` | Cloud Function | the last instance produced |
| `failureCount` | Cloud Function | consecutive failures (reset on success) |

The existing **Manage Recurring Shift Tasks** sheet is the Automation Center; no
new route or feature module exists. Branch Operations exposes it through a visible
branch-scoped Automation summary (active/paused counts + earliest check), and the
sheet renders one rich card per routine: active/paused/error state, human schedule,
next check, generation outcome, failure count and a link to
`lastGeneratedTaskId`. Create, pause/resume and delete still use the existing
`TaskCubit` paths. Client `toMap` writes only `updatedBy` — the rollups are
Cloud-Function-owned (like `version`/`createdAt`), so a client edit can't regress
them. Template read failures render an error/retry state; they are not treated as
an empty branch.

Routine details use the same single-modal loop, but the details-only route opts
into the device safe area. A pinned header provides a labelled 44px Close action;
the scroll body initially shows schedule + next check, latest generation outcome
and the last generated task. Priority, checklist, assignment, shift-window notes
and the Missed policy are deliberately collapsed under **More details**. Failure
state stays visible above that disclosure. Pause/resume and confirmed delete
remain in the primary scroll flow and use the existing `TaskCubit` mutations.

The presentation is deliberately honest about the boundary between a template and
one generated occurrence:

- `nextRunAt` is labelled **Next automation check**, not guaranteed publish time;
  it points at the next 01:00 Africa/Cairo generation tick.
- The sheet's Shift window row is a standard-hours guide; a generated task itself
  captures the exact resolved weekly window (`shiftHours` override → frozen
  `shiftPlan` → standard) in `startsAt` / `deadline`.
- The policy row is **Enabled**: at the persisted shift end, unfinished generated
  tasks become server-owned `TaskStatus.missed`. The 15-minute sweep only moves
  `pending`/`started` source-template instances, writes `missedAt` + an activity
  entry atomically, and never falsely completes or approves work.
- `lastStatus` describes the **generator** (`completed` / `skipped` / `failed`),
  not employee task completion; the UI therefore says Generated successfully,
  Already generated or Last generation failed.
- The client save-time materializer may create today's task while the resolved
  shift window is still live, but it refuses to create an instance after the
  deadline has passed. The 01:00 server generator is the durable authority for
  the next occurrence.

---

## 5. Automation execution records (`automationRuns`) — ADR-011

Operational execution telemetry — **distinct from `audit_logs`** (business facts).
Written by the Cloud Function per (template, business day) at a
**deterministic id** `{templateId}_{yyyy-MM-dd}`, so the history is itself
idempotent (a retry overwrites the run row, never appends a duplicate). As of
[ADR-011](../decisions/ADR-011-automation-observability.md) the row is a rich
**execution record** — same one write per template/day, richer payload:

```
automationRuns/{templateId}_{dateKey}
  # Identity
  templateId, automationName, version, branchId, dateKey, executionId
  correlationId          # AUT-{yyyymmdd}-{hash} — deterministic, shared by task/notif/audit
  # Execution
  startedAt, finishedAt, durationMs, trigger, retryCount, status, outcome
  # Schedule
  schedule: { scheduledAt, actualAt, delayMs, shift, day, branchId }
  # Validation (each pass | fail | skipped)
  validations: [ { name, result } ]   # templateExists · branchExists · scheduleValid · employeesFound
  # Target resolution (explicit even when nobody matched)
  target: { uids[], names[], count, matched, shift, branchId }
  # Generation
  generation: { templateVersion, checklistCount, priority, proofRequired }
  generated:  { taskIds[], titles[], count, skippedCount }
  # Notification
  notification: { sent, failed, notificationIds[] }
  # Error (null unless failed / recovered)
  error: { stage, code, message, retryable, recovered } | null
  # Chronological timeline (EMBEDDED, bounded ~7–12 steps)
  logs: [ { at, stage, severity, message, meta } ]
  # Immutable execution snapshot (written on `created` only — see below)
  snapshot: {
    automation: { id, name, version },
    template:   { id, name, version, checklistCount, priority, proofRequired },
    schedule:   { type, days[], shift, branchId, timezone },
    target:     { branchId, branchName },
    recipients: [ { uid, displayName, role, assignedShift } ], recipientCount
  }
  # Back-compat flat fields (pre-ADR-011 readers / retention)
  generatedTaskId, recipientCount, failureReason
```

### Execution snapshot + correlation id (ADR-011 extension, 2026-07-18)

**Snapshot** — an **immutable point-in-time copy** of the definition, schedule,
branch, and lightweight recipients, so an old run renders correctly *forever*
even after the template/branch/employees/schedule/checklist change. Only
immutable primitives are stored (never full user/branch docs — just `uid ·
displayName · role · assignedShift` per recipient). Written **on the `created`
outcome only**: creation happens at most once per deterministic run id, so the
snapshot is immutable by construction — a later skip/failure never overwrites it,
and recipients are already resolved on that path. Cost: **one** extra read (the
branch doc, for `branchName`); everything else is in hand. Skipped/failed runs
carry no snapshot — the client falls back to the top-level identity fields
(also immutable at write time). Assembled by the pure `buildExecutionSnapshot`.

**Correlation id** — `AUT-{yyyymmdd}-{6-hex sha1(templateId)}`, **deterministic**
per (template, day) so a retry re-computes the identical id. Stamped on **every
resource** the run produces — the run record, the generated `tasks/{id}`
(`correlationId` field), each notification (top-level + `payload.correlationId`),
and each execution audit event (`metadata.correlationId`) — so any one traces
back to the whole execution. Not a sequence (`-000241`): a counter would need a
doc (extra write + contention) and could not be reproduced idempotently. Distinct
from `executionId` (the per-*invocation* id, shared across all templates in one
scheduler tick). Client traceability: `TaskRepository.getAutomationRunByCorrelationId`
(two equality filters → no composite index); a task also computes its run id
directly as `{sourceTemplateId}_{isoDate(instanceDate)}`.

The pure, unit-tested shape logic lives in `functions/automation_run.js`
(`buildValidations` · `classifyError` · `healthDeltas` · `executionDelayMs`); the
Cloud Function does the I/O and calls it, so the record is deterministic and
testable (`functions/test/automation_run.test.js`).

**Client reader (ADR-011).** `AutomationRunEntity` + `AutomationRunModel` +
`TaskRepository.getAutomationRuns(templateId, branchId, {limit, before})` — a
paginated, newest-first read (cursor = the last row's `startedAt`). Read-only;
the collection stays server-authoritative. This is the data foundation for a
future Details screen (Overview · Runs · Timeline · Logs · Recipients ·
Notifications) — **no screen is built yet**. `branchId` is filtered (not just
`templateId`) because the rules gate a manager's read on `branchId ==
selfBranch`; a list query must constrain branchId.

Runs older than `config/taskRetention.automationRunRetentionDays` (default 90)
are pruned by the daily `taskHousekeeping` sweep (bounded, idempotent), so the
collection stays small (~1 doc/template/day → ~900 steady-state).

### Health counters (template rollup)

The generator increments cumulative counters on the template (O(1) per run) so
the whole health panel is **one read**: `runCount`, `successCount`,
`failedCount`, `skippedCount`, `totalDurationMs`, `lastSuccessAt`,
`lastFailureAt`, plus the pre-existing consecutive `failureCount`. Success rate
and average duration are **derived on read** (`AutomationHealth.fromTemplate`) and
never stored — the line ADR-011 draws vs. an analytics pipeline. All CF-owned and
read-only to the client (omitted from `toMap`, like the §4 rollups).

### Lifecycle audit (`onRecurringTemplateWritten`)

Definition edits are audited **server-side** (ADR-005): the client mutates the
template directly and never writes its own audit; this trigger diffs before/after
and appends `automation.created | paused | resumed | config_changed | deleted` to
`audit_logs` with the field-level change set. Idempotent (audit id derived from
the CloudEvent id) and non-looping: the CF-owned rollup/health/`configVersion`
fields are excluded from the diff, so a generation run's rollup write produces no
audit and no version bump. `configVersion` (bumped here on config changes) is
captured onto each run's `version`, so history is attributable to a definition.

## 6. Audit events (reuses Event Tracking — no parallel system)

Business-meaningful automation facts are written to the existing `audit_logs`
collection (Admin SDK, `actorId: "system"`), via new `AuditEventType`s:
`task.auto_generated`, `task.auto_missed`, `automation.assigned`,
`automation.failed`
(+ `automation` `AuditEntityType`). `automationRuns` (§5) is operational run
telemetry, not audit — the two are complementary, mirroring how `taskReminders`
and `broadcastSchedules` already sit beside `audit_logs`.

---

## 7. Automatic assignment flow (documented + hardened)

```
Shift task generated (assignmentType: shift, assigneeIds: [])
        ↓
weekly_schedules/{branch}_{weekStart}.assignments[day][shift]  → rostered uids
        ↓  FILTER (new)
  drop on-leave uids (leave[day][uid]) · drop inactive users (isActive == false)
        ↓
eligible recipients → one deterministic notification each
        ↓
(none eligible) → run recorded outcome: noEligibleEmployees (task still created)
```

Previously the raw roster was notified (on-leave / deactivated employees
included) and an empty roster failed silently. Now the roster is filtered and the
"no eligible employees" case is a first-class recorded outcome.

---

## 8. Firestore

- `recurringTaskTemplates`: §4 rollups + §5 health counters (`runCount`,
  `successCount`, `failedCount`, `skippedCount`, `totalDurationMs`,
  `lastSuccessAt`, `lastFailureAt`, `configVersion`). All additive, CF-owned,
  omitted from client `toMap`. Existing rules unchanged.
- `tasks`: +`recurrenceRootId` / `occurrenceKey` / **`correlationId`** (additive,
  nullable). `correlationId` links a generated task to its run/notifications/audit.
  Generated shift instances also persist additive `startsAt`, `deadline`, and
  server-only `missedAt`; client rules deny creating/setting/reopening `missed`.
- `automationRuns/{id}`: enriched execution record (§5) — read: admin, or manager
  of the run's branch; **write: server-only** (`allow write: if false`; the Admin
  SDK bypasses rules).
- **Composite indexes (ADR-011):** `(branchId, templateId, startedAt desc)` for
  the paginated per-template history; `(branchId, status, startedAt desc)` for a
  future branch-failure view. The correlation-id lookup (`branchId` + `correlationId`,
  both equality) needs **no** composite index (Firestore zig-zag merge join).
- **Recurring expiry index:** `tasks` `(assignmentType asc, status asc,
  deadline asc)` backs the bounded `pending|started` deadline sweep.

## 9. Cloud Function summary

**`generateShiftTaskInstances`** — pinned to **01:00 Africa/Cairo** · atomic
`create` (dedup) · notify-on-create-only with deterministic notif ids · roster
filtering (active + not-on-leave) · enriched `automationRuns` execution record +
embedded step logs (§5) · `recurringTaskTemplates` rollups + health counters ·
`audit_logs` events · `maxInstances:1` + `retryCount:0` + `timeoutSeconds`. The
deterministic date key is the **Africa/Cairo business civil day** (Automated
Tasks spec §12.2), not UTC. It resolves and persists the weekly shift window
from the saved schedule, anchored to the occurrence's business-local midnight;
a duplicate created by an older client is repaired only when its deadline is
missing **and the instance is not already terminal** — "terminal tasks are never
resurrected" ([spec §4.4](AUTOMATED_TASKS_PRODUCT_SPEC.md)), and that explicitly
includes repair, so a cancelled/missed/approved instance is left exactly as it is
(the guard is the pure `isTerminalTaskStatus` in `functions/recurring_task_deadline.js`).
Generation for a day is spent the moment that day's instance exists in **any**
state.

> ⚠️ **Never add a "legacy date key" pre-check before the `create()`.** One
> existed for the UTC-key → business-date-key transition and it silently
> disabled every **daily** routine (fixed 2026-08-05). The generator is pinned to
> 01:00 Africa/Cairo, where the UTC date is *always* the previous day (UTC+2 and
> UTC+3 alike), and both conventions share one id format
> (`rt_{templateId}_{yyyy-MM-dd}`) — so the "legacy id" it probed was simply
> **yesterday's ordinary instance**. It existed, so every run recorded
> `skipped / alreadyExists` and no task was created. The premise was wrong from
> the start: the pre-fix generator ran at a UTC-anchored hour where the UTC and
> Cairo dates agreed, so one occurrence was never written under two keys. The
> deterministic id now has one source, `recurringInstanceId`, and the invariant is
> pinned in `functions/test/recurring_task_deadline.test.js`.

Pure record-shape logic is extracted to `functions/automation_run.js`.

**`autoEndRecurringShiftTasks`** — every 15 minutes, queries the indexed due
generated shift tasks and transactionally revalidates each one. A task is due
only once its deadline is at least the **30-minute grace period** in the past
([ADR-013](../decisions/ADR-013-task-grace-period.md)); the query cutoff and the
transaction's re-check use the same rule, so the sweep's own cadence can never
become the effective policy — which is precisely the defect grace replaced. It
changes only a live source-template instance in `AUTO_END_ELIGIBLE_STATUSES` —
**`pending` · `started` · `rejected`** — to `missed`, stamps `missedAt`, appends
the system timeline entry, bumps `version`, and emits `task.auto_missed` carrying
`fromStatus`, so the audit records whether this was work never done or rework
never returned. A manager cancel and this sweep can race; **the first terminal to
land wins and the other is a no-op** (spec §5.7) — the transaction re-reads the
status, so an already-`cancelled` instance is skipped rather than rewritten to
`missed`. It does not send a notification. The pure window and eligibility policy
is in `functions/recurring_task_deadline.js`.

**`rejected` joined that set on 2026-08-05** (owner-ruled). It had been excluded
on the principle that the *reviewer* owns the next move on a rejected task — true
for manual work, wrong here. A rejected instance never reached a terminal at all,
so it read Late forever, stayed inside `isTaskInActiveWindow` forever, kept
surfacing for later days' crews (the shift task stream has no date filter), and —
decisively — fell out of **Approved ÷ (Approved + Missed)** entirely, so
rejecting work quietly *improved* a branch's completion rate versus letting the
same work be missed. §10.1 requires that rate to be ungameable. Rework inside the
window is unaffected: a task rejected at 14:00 against a 16:30 wall is not
evaluated until 17:00, and resubmitting moves it to `waitingReview`.
`waitingReview` and `completed` stay **out** on purpose — auto-failing there would
record an employee failure for a reviewer's delay.

> ⚠️ **The sweep's Firestore query filters on the same
> `AUTO_END_ELIGIBLE_STATUSES` constant.** A status the predicate accepts but the
> query never fetches is simply never closed — that is the exact shape of the
> `rejected` leak. Keep them one constant. No index change: the existing
> `(assignmentType, status, deadline)` composite serves the widened `in`.

**`runTaskReminders`** — every 30 minutes, escalates `due24h → due1h → overdue`
per task through the `taskReminders/{taskId}` ledger. Three rules matter for
automation (all fixed 2026-08-05):

- **A rejected shift instance is reminded** (2026-08-05), the one exception to
  the standing "rejected is reminder-ineligible" ruling in `task_reminders.js`.
  That ruling holds wherever the reviewer owns the next move; it does not hold
  for an instance a machine will close at the wall. Silence there means losing a
  task to Missed without ever being told rework was owed. The nudge is its own
  message (**Rework Needed** · "… was sent back and is due soon"), and the
  exception is narrow: `shouldRemindTask` widens *only* `rejected`, and *only*
  for a generated shift instance — a terminal is never revived into the sweep.
- **Generated shift tasks are reminded.** They carry `assigneeIds: []` by
  construction (a shift broadcast), and the sweep used to `continue` on an empty
  assignee list — so the most important task class in the app had *no* reminder
  coverage at all: one 01:00 notification, then silence until the manager was
  told it was Missed. Recipients now resolve through the same
  `eligibleRecipients` the generator uses (rostered · not on leave · active),
  against the week of the task's **own occurrence** (`instanceDate`), never
  "today" — a reminder just after midnight for a night shift would otherwise
  resolve the wrong day's crew. Weekly-schedule reads are memoized per sweep.
- **Quiet hours are the staff's wall clock.** They were evaluated with
  `getUTCHours()`, putting the default 22→07 window at **00:00–09:00 Cairo** — it
  muted the 08:30 morning-shift start and allowed a 23:30 ping. Resolved with
  `businessHourOf` (Africa/Cairo, per ADR-015); an unresolvable hour fails
  **open**, never into a silent estate-wide mute.
- **The scan is bounded.** It was `deadline <= now + 24h` with no floor, no limit
  and no status filter, re-reading every task ever written with a past deadline
  48×/day — a runtime that only grew, until it would exceed the timeout and take
  reminders down with it. Now floored at `REMINDER_LOOKBACK_DAYS` (7) and paged
  at `BATCH_LIMIT`, both on the same auto-indexed `deadline` field (no composite
  index). Notification ids are deterministic
  (`taskreminder_{taskId}_{kind}_{uid}`), so a retried sweep converges instead of
  stacking duplicates. Decisions are pure and unit-tested in
  `functions/task_reminders.js`.

**`onRecurringTemplateWritten`** (ADR-011) — server-derived lifecycle audit
(created / paused / resumed / config_changed / deleted) from the definition's
before/after diff; idempotent (audit id from the CloudEvent id) and non-looping
(rollup/health/`configVersion` fields excluded from the diff).

---

## 10. Deferred (not built)

- **Tier 2 enterprise envelope** (ADR-011, declined): per-run Firestore read/write
  counters, CF version/region/cold-start metadata, stored stack traces, and a
  **replay engine** (re-execution risks double-creation).
- Automation **Dashboard** / analytics-time-series surface → out of scope
  (ADR-009); observability lives on the run records + health counters.
- A **Details screen** over the ADR-011 read layer — data foundation is built;
  the screen is a future UI phase.
- `assignmentStrategy` scaffolding for future non-broadcast strategies.
- Monthly recurrence for **shift** templates (per-task recurrence already has it).
- Firestore-native TTL on `automationRuns` (today a bounded `taskHousekeeping`
  age-prune covers it — `automationRunRetentionDays`, default 90).

## 11. Deploy checklist (owner's machine)

> 🚨 **`generateShiftTaskInstances` and `runTaskReminders` carry the 2026-08-05
> fixes and are UNDEPLOYED.** Until step 1 runs, daily routines generate nothing
> and shift tasks get no reminders. This is the highest-priority deploy in the
> repository.

1. `firebase deploy --only functions:generateShiftTaskInstances,functions:autoEndRecurringShiftTasks,functions:onRecurringTemplateWritten,functions:runTaskReminders,functions:taskHousekeeping`
2. `firebase deploy --only firestore:rules` (including the server-owned missed lock)
3. `firebase deploy --only firestore:indexes` (the two `automationRuns` composites
   and the recurring-expiry `tasks` composite)
4. No data migration — every new field is additive and defaults cleanly (counters
   start at 0/1 via `?? ` fallbacks; historical runs simply lack the new blocks).
