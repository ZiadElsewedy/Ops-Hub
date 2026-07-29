# Tasks — the operations workflow

The core of DROP. A manager/admin creates work, an employee executes it, a
manager/admin reviews it. Everything else in the app orbits this.

Covers `features/task/` and `features/operations/` (the branch cockpit that reads
the same stream).

> Product behaviour for automated tasks, cancellation and the four-way reporting
> classification is frozen in
> [AUTOMATED_TASKS_PRODUCT_SPEC](AUTOMATED_TASKS_PRODUCT_SPEC.md) — that document
> is the authority for *what* the workflow does; this one covers *how* it is built.

## Lifecycle

```
pending ──start──► started ──submit──► waitingReview ──approve──► approved
                      ▲                      │
                      └────── reject ────────┘  (rework: revisionNumber++)

pending / started ──shift end +30m──► missed     (generated recurring shift task only)
pending / started ──manager cancel──► cancelled  (+ mandatory reason; any task type)
```

Three terminal outcomes, and they mean different things:

| Terminal | Set by | Reporting | Escape hatch |
| --- | --- | --- | --- |
| `approved` | manager/admin on review | success | admin **reopen** |
| `missed` | server sweep only, at shift end **+ 30 min grace** | failure | **admin terminal correction** |
| `cancelled` | manager/admin, from `pending`/`started` only | **neither — excluded entirely** | **admin terminal correction** |

`cancelled` is a **business decision**: the work will not be done. It is not a
review outcome and is unavailable once a task reaches `waitingReview` — a
submitted task must be reviewed, never voided. Every cancellation carries a
**mandatory structured reason** from the fixed picklist in
`core/enums/task_cancel_reason.dart`, whose wire ids are frozen so relabelling an
option never rewrites history; the reason is immutable once written. Cancelling
one generated instance never touches its routine — pausing a routine is a
separate action on the template.

Statuses live in `core/enums/task_status.dart`; the status → colour mapping has
exactly one home, `core/widgets/status_badge.dart` (`taskStatusColor`).

### The grace period ([ADR-013](../decisions/ADR-013-task-grace-period.md))

A generated shift task is evaluated for `missed` **30 minutes after its resolved
shift end**, not at the shift end. The number is a fixed global constant —
`TASK_GRACE_MINUTES` in `functions/recurring_task_deadline.js` (the enforcing
copy) mirrored by `kTaskGracePeriod` in `domain/task_schedule.dart`. It is
deliberately **not configurable**: a per-branch grace would be a dial on the
headline completion rate held by the person that rate evaluates.

> **Grace is a tolerance on the close, not a deadline.** Never add it to `dueAt`,
> never feed it into `schedulePhase`, and never use it to delay the Overdue/Late
> reading. A task is Late from its deadline (§3.1) so the employee feels the
> urgency immediately — they are simply not *recorded as failed* until grace
> expires. It must also stay longer than the sweep interval, or the cron cadence
> silently becomes the real rule again.

### Reporting a task as incorrect

An employee may **never** cancel — but handing someone the wrong work with no
way to say so is what would make manager-only cancellation inhumane, so
`TaskCubit.reportTaskIncorrect` is the release valve (spec §5.2). It writes
`reportedIncorrectBy` / `At` / `Note` (a required explanation — a bare "this is
wrong" gives the manager nothing to decide on), notifies the branch's managers,
and **does not change the task's status**: the work stays exactly where it is
until someone with the authority acts. A manager then either cancels it or calls
`dismissIncorrectReport` ("the task stands"); cancelling clears the report too,
since cancelling *is* the answer. `firestore.rules` lets an employee file only
under their own uid, never over an open report, and never clear one.

### Reporting — the four-way classification

`domain/task_outcomes.dart` is the single derivation of the spec's §8/§10
reporting contract. Pure, over the already-in-memory task list, no stored
aggregates ([ADR-009](../decisions/ADR-009-no-analytics-pipeline.md)).

| Category | Scored as | In the completion rate? |
| --- | --- | --- |
| **Approved** | success | numerator **and** denominator |
| **Missed** | failure | denominator only |
| **Cancelled** | neither | **excluded entirely** |
| **Late** | timeliness signal | never |

**Completion rate = Approved ÷ (Approved + Missed).** Excluding Cancelled from
*both* sides is what makes it ungameable: a manager cannot lift the number by
cancelling work they expect to fail. It is a *reliability* measure over decided
work — not progress through the backlog (`approved / total`), and the copy keeps
the two apart.

> **Hard invariant:** "incomplete = Missed + Cancelled" is forbidden anywhere.
> There is deliberately no field or helper that sums them — the moment such a
> number exists, someone renders it, and the distinction is gone.

Cancellations report on their **own line, broken down by reason code** — a single
cancel is legitimate, a *cluster* is the smell that catches a misconfigured
template or a routine that should be paused. Lateness is measured from
`submittedAt` (falling back to `approvedAt`) against `deadline` and reported as
"% completed after deadline" + average lateness: coaching data, never pass/fail.
This is why no *Completed Late* status exists — the timestamps already answer it.

### Terminal correction (§6.4)

`correctTerminal` returns a `missed` / `cancelled` task to `pending`, clearing
every trace of the outcome being undone. **Admin only, always audited**
(`task.terminal_corrected`). Without it a mistimed terminal — a cancel that lost
the race to the sweep by seconds, a miss recorded against work that was actually
done — becomes a permanent lie in the reporting. It is deliberately narrow so it
stays a safety valve rather than a routine escape hatch. Correcting an
**approved** task is the separate, longer-standing `reopenTask`, which a manager
may also do.

### Transitions are transactional

Every move goes through **`TaskRepository.transitionTask`**, a Firestore transaction
that:

1. re-reads the doc and **verifies the expected predecessor status**,
2. appends the `ActivityEntry` to the **server's** current log,
3. bumps the additive `TaskEntity.version`.

A stale or concurrent move raises `ConflictFailure`. This fixed a real
concurrent-reviewer race where two managers could both approve and one decision
vanished. See [ADR-005](../decisions/ADR-005-server-authoritative-writes.md).

> **Never split a status change and its activity entry into two writes.** That bug
> has been fixed once (2026-06-18) and the transaction is what keeps it fixed.

The one exception is the server-side recurring-shift expiry sweep. Every 15 minutes
`autoEndRecurringShiftTasks` re-reads each due candidate in an Admin-SDK
transaction. A task is only a candidate once its deadline is **at least the
30-minute grace period** in the past ([ADR-013](../decisions/ADR-013-task-grace-period.md));
the query and the transaction's re-check share one definition of "due", so the
sweep's own cadence can never become the effective rule. Only a live generated
instance (`sourceTemplateId` present) still in
`pending` or `started` can become `missed`; it appends the system activity entry,
sets `missedAt`, and increments `version` in that same write. It never turns
unfinished work into `completed`, `waitingReview`, or `approved`. Firestore rules
make `missed`/`missedAt` server-only and lock the record against client reopen or
deletion.

**Cancel vs. miss is a race with a deterministic winner: the first terminal to
land wins, and the other becomes a no-op.** The sweep's transaction re-checks the
live status through the pure `shouldAutoEndRecurringTask`, so a cancel that
committed first leaves nothing to do; a sweep that won first leaves the task
`missed`, and the client's cancel fails its `expectedFrom` precondition with a
benign `ConflictFailure`. There is deliberately no time-window arbitration — one
predictable rule plus a correction path beats special-casing the race.

Recurrence respawn happens **post-commit**, so only the winning reviewer spawns the
next instance (`rec_{sourceTaskId}` — a deterministic id, which is what stops the
reopen → re-approve duplicate).

## Assignment

`assignmentType` (`core/enums/task_assignment_type.dart`) has three modes:

| Mode | Target | Visible to |
| --- | --- | --- |
| `individual` | named people | those people |
| `team` | named people | those people |
| `shift` | a **shift**, not a person | whoever is rostered on it **today** |

`shift` mode is the interesting one: the task belongs to the Morning or Night crew,
and who that is changes daily. Visibility resolves through the single pure gate
[`domain/task_access.dart`](../../lib/features/task/domain/task_access.dart)
(`canUserAccessTask`) — mirrored in `firestore.rules`, and the only place this
question is answered.

`assigneeIds[]` is canonical (multi-assignee); `assignedEmployeeId` is a
**denormalized mirror** of the primary that rules and statistics depend on — keep
them in sync on write.

### Recurring shift routines

These use a **template → generated instance** split, *not* the per-task
`RecurrenceConfig`:

```
recurringTaskTemplates/{id}   ← the blueprint (branch-scoped, active flag)
        │  generateShiftTaskInstances (onSchedule 24h, roster-filtered, atomic)
        ▼
tasks/rt_{templateId}_{yyyy-MM-dd}   ← the deterministic id IS the dup guard
```

The client also materializes "today" best-effort (`_materializeTodayInstance`,
unawaited) so a new template is usable before the scheduler runs. The template write
is the Save boundary — see `recurring_shift_task_sheets.dart` (single-modal
Manage → Add; never stack bottom sheets).

Every generated instance persists its exact `instanceDate`, `startsAt`, and
`deadline`. The generator and the client materializer resolve the week slot using
the saved weekly schedule in the same order as attendance: per-day `shiftHours`
override → frozen `shiftPlan` → `ShiftHours.standard`. The window is anchored to
the occurrence's **business-local midnight** (`Africa/Cairo`,
[ADR-015](../decisions/ADR-015-automation-business-timezone.md)), so a configured
08:30–16:30 Morning shift is actually due at that shift end (and night windows may
cross midnight); the saved `weekStart` now only resolves which hours apply. The
task id is keyed on the same business civil date; the deadline itself is an
absolute timestamp.

At or after that persisted deadline, `autoEndRecurringShiftTasks` marks an
unfinished generated task **Missed**. A normal task that merely has a past deadline
remains a derived **Overdue** phase — it is not auto-closed. The expiry query needs
the deployed `tasks` composite index
`assignmentType` + `status` + `deadline`; its transaction revalidation means a
simultaneous employee submission wins instead of being overwritten. Missed records
leave active queues immediately and follow the ordinary task-retention window.

⚠️ The employee shift-task **stream** needs the `tasks` composite index
(`branchId`+`assignmentType`+`shift`) — it fails `failed-precondition` until
deployed.

## Scheduling (V2)

`startsAt` + `dueAt` (the due side is the existing `deadline`, aliased). Both
additive — no migration.

Create-mode quick deadline presets (`Tomorrow` / `2 days` / `Week`) sit on a
compact duration rail and set `startsAt` to the current creation time and `dueAt`
to +1/+2/+7 days. They are deadline presets, not shift suggestions, so
outside-shift-hours warnings do not apply to those windows. Picking one moves the
rail thumb and animates the duration rail under the Start/Due rows.

**`TaskSchedulePhase` is derived, not persisted** — Scheduled / Active / Due-soon /
Overdue / Done, computed from the times + lifecycle in pure
`domain/task_schedule.dart`. It is not a replacement for lifecycle state:
`TaskStatus.missed` is the narrow server-only terminal result for an expired
generated recurring shift task, while **Overdue** remains a derived phase for any
other open task.

Smart defaults pre-fill start/due from the assigned shift's hours
(`shiftDefaultSchedule`) as a *suggestion that is never locked*. For
individual/team, `TaskCubit.resolveAssigneeShift` reads the branch roster and the
pure `assigneeShiftFit` decides: unanimous → suggest · mixed → a Morning/Night/Custom
chooser · none → manual. The banner keeps the **original** shift after edits
("Originally: …"). Due-before-start is blocking; outside-shift-hours is a warning.

## Work types

Polymorphic tasks via **Strategy + Registry**. Adding a type is **1 file + 1 line**
(open/closed). `workType` + `data` are additive; an unknown type degrades to
`general` rather than crashing. `TaskWorkX` is the only adapter seam — all save
paths are identical.

## Composition

`TaskCubit` is the hybrid described in [ADR-002](../decisions/ADR-002-cubit-only.md):

| Concern | Path |
| --- | --- |
| Writes | use cases (`CreateTask`, `UpdateTask`, `AssignTask`, `UploadTaskAttachment`, …) |
| Realtime lists | `TaskRepository.watch{AllTasks,TasksByBranch,EmployeeTasks}` directly |
| Templates | `TaskRepository` directly |
| Admin branch picker | `BranchRepository` directly |
| Employee's shift(s) today | `ScheduleRepository` directly |

It also warms a per-branch **user directory** (`_ensureDirectory` via
`GetUsersByBranch`) so cards render real names and avatars instead of uids.

## Ordering

Admin query uses Firestore `orderBy('createdAt', descending: true)` (index-free).
**Filtered branch/employee queries stay filter-only** — a filter + `orderBy` needs a
composite index, which broke loading and was reverted. They are ordered in Dart by
`sortTasksNewestFirst` ([`domain/task_ordering.dart`](../../lib/features/task/domain/task_ordering.dart),
pending-timestamp on top). This is a deliberate Firebase trade
([ADR-001](../decisions/ADR-001-firebase-backend.md)) — don't "optimize" it back
into the query without adding the index.

## Media

All uploads go through the single seam `core/media/media_upload_service.dart`.

- `TaskAttachment` (+ `AttachmentLimits`), attached to `ActivityEntry.attachments[]`.
- Mobile-only pre-upload editing: crop/rotate/flip (`image_cropper`) and video
  transcode (`video_compress`), gated on `supportsImageEditing` /
  `supportsVideoCompression` — desktop uploads are untouched.
- Submission uploads run through `mapPooled` (concurrency cap 3, fixed-denominator
  progress).
- **Cancellable:** the overlay's Cancel → `TaskCubit.cancelSubmission()` aborts every
  in-flight upload via `UploadCanceller`, hidden during `finalizing` so the Firestore
  write can't be orphaned mid-commit.
- **Partial retry:** a per-task `_uploadedCache` re-uploads only what didn't already
  succeed.
- Video thumbnails are local and view-time (`video_thumbnail_image.dart`, LRU cache)
  — no server posters.

## Operations cockpit

`features/operations/` reads the same branch stream and derives, never writes
(writes stay in `TaskCubit`, so both see changes live).

`computeBranchWorkload` is pure and deterministic (`day`/`now` injectable): it joins
the task stream × `getUsersByBranch` × today's `weekly_schedule`, sorts
overload-first. The public predicates (`isOperationalActiveTask` / `…Overdue` /
`…PendingReview`) are shared by the headline counts **and** the drill lists, so a KPI
can never disagree with the list it opens.

## Retention

`taskHousekeeping` (onSchedule 24h) soft-archives approved tasks past
`archiveAfterDays` (`archivedAt`; clients filter it out), cold-tiers their Storage
media, and hard-deletes only under an opt-in `deleteAfterDays` purge. Owner ruling:
**soft-archive forever** is the default.

## Related

[DATA_MODEL](DATA_MODEL.md) · [SCHEDULE](SCHEDULE.md) ·
[AUTOMATION_ENGINE](AUTOMATION_ENGINE.md) · [AUDIT_LOG](AUDIT_LOG.md)
