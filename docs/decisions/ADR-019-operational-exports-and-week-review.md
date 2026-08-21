# ADR-019 — Exports are operational documents, and a week is *reviewed*, never locked

**Status:** Accepted · **Date:** 2026-08-01

**Amends [ADR-017](ADR-017-attendance-reporting-ledger.md)** on three points, and
retires `ATTENDANCE_REPORTS_IA` §12.6. ADR-017's core — attendance is a ledger,
not a scoreboard, fenced by the metric bar — is unchanged and still binds.

## Context

ADR-017 authorised **server-generated CSV and PDF export with an export audit
ledger**, and rejected client-side generation with a one-line reason: *"a
client-authored payroll artifact is unauditable."* It also authorised a period
lifecycle `open → ready → locked → exported → restated`, because a figure that
feeds pay must not move after hand-off.

Every one of those decisions rests on a premise the owner has now retired:

> **OpsHub is an operations management system, not a payroll system, and payroll
> integration is not planned.**

The premise mattered more than it looked. Remove it and the reasoning collapses
in sequence: no payroll system ingests a file, so there is no machine-readable
schema to satisfy; nothing downstream consumes a figure, so nothing needs
freezing; the artifact is not financial, so it needs no audit chain; and with no
audit chain, server generation buys nothing that a client cannot do.

Phase 4 built to the old premise. `functions/attendance_export.js` produced the
37-column §12.6 payroll CSV with ISO-UTC instants and whole unrounded minutes —
a machine's file. **Nothing will read it.**

The two artifacts are not subsets of each other. Payroll wants
`2026-07-29T05:30:00.000Z` and `487`, because it rounds and prices itself. A
manager opening a file wants `29 Jul`, `08:37`, and `7h 52m`. Same facts,
opposite formatting rules, about eleven useful columns instead of thirty-seven.

Separately, the owner pushed back on removing the *whole* notion of finishing a
week: managers should still be able to mark a week reviewed *"so later changes
are intentional and visible"* — but explicitly without locking, export ledgers,
or restatement history. That pushback was correct, and the original framing was
wrong: **closing and locking had been treated as one thing.**

## Decision

### 1. Exports are operational documents, generated on the client

A **timesheet CSV** and a **weekly PDF**, produced in the app and saved with the
same `path_provider` → `open_filex` path the Schedule PNG export already uses.
No Cloud Function, no Storage object, no export ledger.

The CSV is written for a human in a spreadsheet: local dates and times, `7h 52m`
rather than `472`, headers a manager can read. It is **not** the §12.6 schema,
which is retired rather than trimmed.

`functions/attendance_export.js` and its tests are **deleted**. Git and this ADR
hold the record; keeping a payroll builder against a payroll system nobody plans
is the speculative generality [ADR-010](ADR-010-lean-over-enterprise.md) exists
to refuse.

### 2. A week is **reviewed**, and that is an assertion — not a lock

A manager may mark a branch-week **Reviewed**, recording who and when. Reversible
by **Reopen**, equally attributed.

**Review does not restrict anything.** No write is rejected, no rule enforces it,
no period becomes immutable. It is a durable statement that a named person looked
at this week on this date — nothing more, and that is the entire point.

**It is orthogonal to the derived data state and must never be conflated with
it.** `AttendanceCoverageStatus` (No data yet · Needs attention · In progress ·
Settled) answers *is the record complete?* — computed. Review answers *has a
person signed off?* — asserted, and underivable: a week can be Settled and never
opened by anyone.

Letting either imply the other is precisely the defect this redesign began from,
where *"Fully closed"* was rendered over a week that was 86% empty.

**A week with open items is still reviewable**, and says so: *"Reviewed — 2 items
still open."* A person looked; that claim is true whether or not everything could
be resolved. Blocking the button would make it read as broken, and the open items
are separately visible anyway.

**Post-review changes are derived, not versioned.** Any attendance record in the
week whose `updatedAt` is later than `reviewedAt` is a change made after review.
That is a timestamp comparison over data already stored — it delivers *"later
changes are intentional and visible"* with no history collection at all.

### 3. Dropped outright

- **Period lock.** Enforcement with nothing downstream to protect.
- **Export ledger.** An audit chain for a non-financial document.
- **Restatement versioning.** Superseded by the `updatedAt > reviewedAt`
  derivation.
- **`AttendancePeriodStatus`** (`open → ready → locked → exported → restated`) —
  never had a reader in `lib/` and now never will.
- **`ATTENDANCE_REPORTS_IA` §12.6** and the four-artifact export matrix in §12.

### 4. Still refused

Unlock ceremonies, approval chains, multi-level sign-off, and any version
history. One button, one reversal, both attributed. The moment week review needs
a workflow it has become the lock this ADR declined to build.

Also unchanged: OpsHub does not calculate pay, and does not round to payroll
increments.

## Consequences

- **Phase 4 stops being blocked.** Client generation removes the Cloud Function,
  the Storage write, and the deploy dependency that had made the remainder
  unshippable.
- **A new collection and one rules block.** Week review is a client write gated
  by rules — manager writes own branch, admin any. No Function. It needs a rules
  deploy, which is no longer a blocker now that the 2026-07-31 deploy is verified
  working.
- **Tests move, they do not vanish.** The 18 `node --test` cases covering the
  payroll builder go with it; the replacement CSV is pure Dart and tested there.
  CSV escaping in particular must survive the move — an employee named
  `Amal, "A"` silently shifting every later column is a real defect, not a
  hypothetical.
- **Two states now render on the weekly report**, and the UI must keep them
  visually distinct. If they ever merge into one badge, this ADR has been lost.
- **If payroll integration is ever planned, this ADR is reversed, not extended.**
  The §12.6 schema is in git history at `b02c949`.

## Alternatives considered

- **Keep the payroll CSV "in case".** Rejected: dead code kept against a
  hypothetical, and ADR-010 exists to refuse exactly that.
- **Trim the payroll schema into the operational one.** Rejected: they format the
  same facts oppositely, so the result would serve a human badly and a machine
  not at all.
- **Keep server generation for the audit trail.** Rejected: the trail existed to
  make a *financial* artifact defensible. An operational report shared with an
  owner does not carry that obligation.
- **Keep the lock, drop only the ledger.** Rejected on the owner's own framing —
  the requirement is that later changes be *visible*, not *prevented*, and
  `updatedAt > reviewedAt` delivers visibility for free.
- **Ship `.xlsx` rather than CSV.** Rejected for now: Excel opens CSV natively,
  and an xlsx writer is a dependency bought for formatting nobody asked for.
  Revisit if styled multi-sheet workbooks are ever wanted.
