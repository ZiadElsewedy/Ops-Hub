# Automated Tasks — Product Specification (Source of Truth)

> **Status:** FROZEN for implementation (V1). Product-level contract only — no
> platform/implementation detail. This document is the authority for *what the
> workflow does and why*. For *how it is built*, see
> [AUTOMATION_ENGINE](AUTOMATION_ENGINE.md) and [TASKS](TASKS.md).
>
> Where a decision had multiple viable options, exactly one was chosen and
> justified below. Alternatives are closed. This is final unless a real issue
> surfaces in production.

---

## 0. Scope & vocabulary

An **Automated Task** is a task the *system* creates from a recurring routine,
rather than a manager creating it by hand. It lives the same lifecycle as a
manual task once created. This spec covers the full lifecycle, the two ways work
becomes closed (Approved / Missed / Cancelled), and how each is reported.

- **Manual Task** — created by a manager/admin by hand.
- **Automated Shift Task** — generated automatically from a recurring shift
  routine; assigned to a *shift* (whoever is rostered), not a named person.
- **Recurring (per-task) Task** — a normal task flagged to repeat; the next
  instance appears when the current one is approved. (Secondary engine — see §4.)

---

## 1. Final lifecycle

```
                 ┌────────── manager cancel (+reason) ──────────┐
                 │                                              ▼
   [generated/created] ─► Pending ─► Started ─► Waiting Review ─► Approved ●
                 │           │          │              │
                 │           │          │              └── reject ─► Started   (rework)
                 │           │          │
                 │           │          └── (shift deadline) ─► Missed ●   (shift tasks only)
                 │           └───────── (shift deadline) ─► Missed ●
                 │
                 └── manager cancel (+reason) from Pending or Started ─► Cancelled ●

   ● = terminal
   "Late" is a derived visual overlay on any active, past-deadline task — NOT a state.
```

**Reading the diagram:** Cancelled is an **early exit** taken from `Pending` or
`Started`. Approved and Missed are **end-of-line**. Cancelled is *not* a review
outcome — it is unavailable once a task reaches Waiting Review.

---

## 2. Final state machine

| State | Meaning | Set by | Terminal? |
|---|---|---|---|
| **Pending** | Generated/created, not yet started | System / manager | No |
| **Started** | Employee is working on it | Employee | No |
| **Waiting Review** | Employee submitted; awaiting decision | Employee | No |
| **Approved** | Work accepted | Manager/Admin | **Yes** |
| **Rejected** | Sent back for rework → returns to Started | Manager/Admin | No (loops) |
| **Missed** | Shift window closed on unfinished work | System (automatic) | **Yes** |
| **Cancelled** | Business decision: will not be done | Manager/Admin | **Yes** |

### Allowed transitions

- `Pending → Started` (employee)
- `Started → Waiting Review` (employee)
- `Waiting Review → Approved | Rejected` (manager/admin)
- `Rejected → Started` (rework)
- `Pending → Missed`, `Started → Missed` (system, shift tasks only, at deadline)
- `Pending → Cancelled`, `Started → Cancelled` (manager/admin, reason required)
- `Approved | Missed | Cancelled → Pending` **admin-only correction** (§6.4)

### Explicitly forbidden transitions

- `Waiting Review → Cancelled` — a submitted task must be reviewed, never voided.
- Any manual `→ Missed` — Missed is system-only and shift-only.
- Any employee-initiated `→ Cancelled`.
- Any transition *out of* a terminal except the admin correction in §6.4.
- Automation re-writing a terminal task (no resurrection — §5.4).

---

## 3. Business rules

1. **Late (Overdue) is a derived visual only**, never a workflow state. It means
   "active task past its expected deadline, still expected to be done." It
   applies to any active task with a deadline. It disappears the instant the task
   reaches a terminal state.
2. **Missed is terminal, automatic, and exclusive to Automated Shift Tasks.** A
   manual or per-task recurring task **never** becomes Missed automatically.
3. **Cancelled is terminal, manual, and universal** — available on every task
   type (manual, shift, per-task recurring). It is neither success nor failure.
4. **A task in Waiting Review cannot be Cancelled.** It is reviewed normally.
5. **Terminal is terminal.** Once Approved, Missed, or Cancelled, a task leaves
   all active queues. The only way back is the admin correction (§6.4).

---

## 4. Automation rules

1. **Automated Shift Tasks remain fully automatic.** The recurring-template
   engine keeps generating one instance per routine per day, unchanged. No
   architectural change is introduced by this spec.
2. **One instance per routine per day.** Generation is idempotent — a routine
   produces exactly one task for a given day, no matter how many times generation
   runs.
3. **Cancelling an instance never touches its routine.** Cancelling today's
   generated Shift Task cancels *only that instance*. Tomorrow's instance still
   generates normally. Stopping a routine is a **separate** action (pause/deactivate
   the template) and is out of the Cancel workflow entirely.
4. **Terminal tasks are never resurrected.** If today's instance is already
   Cancelled or Missed, no retry, regeneration, or repair may recreate, reopen,
   or overwrite it. Generation for a day is spent once that day's instance exists
   in any state.
5. **Second engine — known asymmetry (accepted).** A *per-task recurring* task
   spawns its successor only when the current instance is **Approved**. Therefore
   **cancelling a per-task recurring instance ends that series** (no successor is
   created). This differs from Shift Tasks (where tomorrow still generates) and is
   accepted for V1. Unifying the two engines' Cancel behavior is postponed (§13).

---

## 5. Cancellation rules

1. **Who:** Managers and Admins only. Employees may **never** cancel.
2. **Employee path:** an employee may **report** a task as incorrect; the report
   routes to a manager, who decides. The cancellation decision always belongs to
   management. (The report affordance is required, not optional — it is the
   release valve that makes manager-only cancellation workable.)
3. **Scope of authority:** a Manager may cancel only tasks in their own branch.
   An Admin may cancel across branches.
4. **When:** cancellable from **Pending or Started only**. Not from Waiting
   Review, and not from any terminal.
5. **Reason is mandatory and structured.** Every cancellation records exactly one
   reason from a fixed picklist:
   - Duplicate Task
   - Wrong Task Generated
   - No Longer Needed
   - Shift Cancelled
   - Management Decision

   An optional free-text note may accompany it. The reason is **immutable** once
   written — renaming the picklist later never rewrites historical records.
6. **Cancelled ≠ Completed and ≠ Missed.** It is its own reporting category (§7).
7. **Cancel vs Missed race:** **first terminal to land wins; the other becomes a
   no-op.** A manager cancel and the automatic miss can, in a narrow window,
   compete. Whichever is written first stands. If the wrong one wins (e.g. a
   cancel intent lost to the sweep by seconds), it is corrected via §6.4 — not by
   special-casing the race. *Justification:* a deterministic first-writer rule
   plus one correction path is simpler and more predictable than time-window
   arbitration logic, and avoids ever un-terminating a state through automation.

---

## 6. Manager & Admin permissions

| Action | Manager | Admin |
|---|---|---|
| Review (Approve / Reject) | Own branch | All branches |
| Cancel a task (Pending/Started, +reason) | Own branch | All branches |
| Reopen Approved | Own branch | All branches |
| **Correct a terminal (Missed/Cancelled)** — §6.4 | No | **Admin only** |
| Manage recurring templates (create/pause/delete) | Per existing template workflow | Per existing template workflow |
| See all tasks across branches | No | Yes |

### 6.4 Terminal correction (final decision — INCLUDED in V1)

**Decision:** a single **admin-only, audited** correction primitive may return a
terminal task (Approved, Missed, or Cancelled) to Pending. Managers cannot;
employees cannot.

**Justification:** without any correction path, a mistimed or fat-fingered
terminal (a cancel that lost the race to a Missed sweep, a wrong cancel, an
erroneous approval) becomes a **permanent lie in the reporting**. Making all
three terminals admin-reversible — consistent with Approved, which was already
reopenable — is the cheapest possible safety valve and keeps the data honest.
It is deliberately narrow (admin-only, audited, no manager/employee access) so it
cannot become a routine escape hatch that erodes accountability. This reverses
the prior "Missed is never reversible" stance; the reversal is intentional and is
the resolution of the one genuine data-integrity hole in the model.

---

## 7. Employee permissions

| Action | Employee |
|---|---|
| Start / submit their own task | Yes |
| See tasks assigned to them or to their rostered shift | Yes |
| Report a task as incorrect (routes to a manager) | Yes |
| Cancel a task | **Never** |
| Review / Approve / Reject | **Never** |
| Correct a terminal | **Never** |

---

## 8. Reporting rules

Four categories, kept **independent**. No report may ever merge any two.

| Category | Scored as | In completion rate? |
|---|---|---|
| **Approved** | Success | Yes (numerator + denominator) |
| **Missed** | Failure | Yes (denominator only) |
| **Cancelled** | Neither | **Excluded entirely** |
| **Late** | Timeliness signal, not an outcome | N/A |

- **Completion rate = Approved ÷ (Approved + Missed).** Cancelled is excluded from
  both sides — by decision, the work never happened.
- **Cancelled is always reported on its own line, broken down by reason code.**
- **Hard invariant:** "incomplete = Missed + Cancelled" is forbidden anywhere. The
  moment that appears, the Cancelled/Missed distinction is destroyed.

---

## 9. Notification rules

1. **Missed → notify the branch manager.** (This closes the current silent-failure
   gap; a task that fails automatically must be visible to a human.)
2. **Cancelled → notify the assigned employee(s), targeted — not branch-wide.**
   Someone expected to do that work and must know it is void. A cancel of a task
   that was already **Started** is the highest-priority cancel notification.
3. **Shift-broadcast cancel with no named assignee → notify the rostered crew**
   (or nobody, if none are rostered). An empty assignee set must never break
   notification.
4. **No notification on Late.** It is a passive visual; alerting on every deadline
   crossing is noise.

---

## 10. Analytics rules

1. **Headline KPI — Completion rate** = Approved ÷ (Approved + Missed). It must be
   **ungameable by cancellation** — hence Cancelled is excluded.
2. **Missed feeds branch performance scorecards.** It is the real failure signal.
   *Gate:* scorecard wiring must not go live until the grace decision (§12) is
   consciously ruled — until then, Missed may over-report failure at shift
   boundaries.
3. **Cancellation volume by reason code is a secondary KPI.** Each cancel is
   legitimate; a *cluster* is a smell — repeated "No Longer Needed" means a
   routine that should be paused; repeated "Wrong Task Generated" means a
   misconfigured template. This is the laundering/quality detector.
4. **Late is tracked as timeliness on completed work** ("% completed after
   deadline", average lateness) — coaching data, never pass/fail.

---

## 11. Product decisions we intentionally ACCEPTED

1. **Two closure kinds by design:** automatic **Missed** (shift wall) and manual
   **Cancelled** (business decision) — because a shift deadline is a hard
   real-world boundary while a cancel is a human choice; they are genuinely
   different truths and must not be merged.
2. **Late stays a derived visual, not a state** — a late-but-open task is *more*
   urgent, not closed; collapsing it into a terminal would tell staff to abandon
   work the business still needs.
3. **Manual tasks never auto-Miss** — their deadlines are targets, not walls.
4. **One cancel verb ("Cancelled")** — Close/Stop/Dismiss were rejected as
   ambiguous or too soft.
5. **Manager-only cancellation with a required, structured reason** — preserves
   accountability and keeps reporting honest.
6. **Instance-scoped cancellation** — cancelling one occurrence never stops a
   routine.
7. **Admin-only terminal correction** (§6.4) — the single safety valve for
   mistaken terminals.
8. **Stores never close** (business constraint) — so no closed-day handling
   exists, by design.

---

## 12. Product decisions we intentionally POSTPONED

1. **Grace period / "Completed Late" outcome.** V1 ships **zero grace**: a shift
   task unfinished at the exact shift end becomes Missed. This is a *conscious*
   acceptance, not an oversight — it keeps V1 simple. The known cost: an employee
   finishing minutes after shift end is recorded Missed while the store is open.
   Revisit before Missed carries heavy weight in performance reviews.
2. **Single-timezone assumption.** V1 assumes all stores share one timezone. If
   the estate ever spans timezones, the "today"/deadline boundary must be
   revisited before that expansion — it is a hard prerequisite, not a nicety.
3. **Unifying the two recurrence engines' Cancel behavior** (§4.5).

---

## 13. Non-goals (explicitly out of scope)

- Closed-day / holiday calendars (stores never close).
- Multi-timezone task boundaries (single-timezone assumed for V1).
- Employee-initiated cancellation.
- Multiple cancel verbs (Close / Stop / Dismiss).
- Overdue as a workflow state.
- Round-robin / single-winner automatic assignment (shift tasks broadcast to the
  whole rostered crew, by design).
- A standalone analytics pipeline or automation dashboard beyond the KPIs in §10.
- Task-to-task dependency graphs, SLA tiers, story points, or custom workflow-state
  builders — deliberately not this product.

---

## 14. Future roadmap

**Phase 1 — Cancelled core.** Cancelled terminal + mandatory structured reason
code + manager/admin-only + branch scoping + audit + reporting category + the
"terminal is never resurrected" invariant. Reachable from Pending/Started only.
*Risk:* shipping without the mandatory reason enables laundering; without the
no-resurrection invariant, zombie tasks.

**Phase 2 — Visibility & trust.** Notify-on-Missed; targeted notify-on-Cancel;
the employee "report incorrect task" flag feeding manager cancellation; admin
terminal-correction (§6.4).
*Risk:* skipping the employee report path makes manager-only cancel inhumane.

**Phase 3 — Reporting & analytics.** Lock the four-way classification; Cancelled
excluded from completion rate; cancellation-by-reason secondary KPI; Late as
timeliness; wire Missed into branch scorecards.
*Risk:* wiring Missed into scorecards before ruling the grace question (§12.1)
bakes the truth-gap into performance data.

**V2 / V3 candidates.** Grace period / Completed-Late; unify recurrence-engine
Cancel behavior; a "this routine is cancelled repeatedly → suggest pausing it"
nudge; multi-timezone support if the estate expands.

---

## 15. Related documents

[AUTOMATION_ENGINE](AUTOMATION_ENGINE.md) · [TASKS](TASKS.md) ·
[REQUESTS](REQUESTS.md) · [AUDIT_LOG](AUDIT_LOG.md) ·
[ADR-010 lean-over-enterprise](../decisions/ADR-010-lean-over-enterprise.md)
