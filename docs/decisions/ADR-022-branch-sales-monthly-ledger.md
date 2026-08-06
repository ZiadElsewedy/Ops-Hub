# ADR-022 — Branch monthly sales is a derived ledger, not a stored running total

**Status:** Accepted · **Date:** 2026-08-05

## Context

Each branch needs a **monthly sales target** (in EGP) that employees work toward.
At the end of a working day one branch employee submits that day's sales; a manager
approves or rejects it; only **approved** sales count toward the branch's monthly
progress. Progress, remaining, and forecast are shown on Employee Home, a manager
dashboard, and an admin overview. Full behaviour is specified in
[SALES_TARGETS.md](../design/SALES_TARGETS.md).

Three forces shape the architecture:

- **It is a monetary operating record.** An approval changes what the branch counts
  as revenue against its target. That is forgeable-sensitive and audit-obligated —
  the same class of fact as attendance minutes, and firmly inside
  [ADR-005](ADR-005-server-authoritative-writes.md).
- **The spec is explicit that remaining / progress / percentage are derived**, not
  stored. That instinct matches DROP's ethos and removes a whole class of drift bug.
- **DROP is small and lean.** A handful of branches, a month is ≤ ~31 daily
  documents per branch. [ADR-009](ADR-009-no-analytics-pipeline.md) and
  [ADR-010](ADR-010-lean-over-enterprise.md) still bind: no analytics pipeline, no
  rollup tables, no scoreboards.

DROP already solved a structurally identical problem — a period-scoped, timezone-
pinned, server-closed record with derived summaries — in attendance
([ADR-017](ADR-017-attendance-reporting-ledger.md),
`functions/attendance_expectation.js`). The relevant question is which parts of that
pattern to reuse and which to deliberately *not* reuse.

## Decision

**Model branch monthly sales as a derived ledger.** Persist only source-of-truth
facts; compute every operational number on read.

1. **Two immutable, month-scoped, deterministically-keyed collections.**
   - `branch_sales_months/{branchId}_{yyyyMM}` — one target record per branch-month.
   - `branch_sales_submissions/{branchId}_{yyyyMMdd}` — one daily-close record per
     branch business day.
   The deterministic id **is** the duplicate guard, exactly as attendance uses
   `{uid}_{yyyyMMdd}_{shift}`. There is no create-then-check race.

2. **No stored accumulation. Approved total is always re-summed on read** from the
   month's approved submissions. There is therefore **nothing to "reset"** at month
   end and **no aggregate that can drift** when an approved amount is later corrected.
   This is the leanest form of the spec's "Option A" (immutable month records created
   lazily) — *not* a scheduled reset job and *not* a mutable active-month singleton.

3. **All monetary state transitions are server-authoritative callables.** The client
   may write **only** the initial `pending` submission (its own branch, own uid,
   deterministic id, no decision fields). Approve / reject / request-correction /
   edit-approved / reopen / set-target all run through Cloud Functions in a
   transaction that checks the expected status and revision — reusing the existing
   `approveSwap` callable precedent (`schedule_remote_datasource.dart`). Per ADR-005,
   a client may never author a manager's approval fact.

4. **Money is a signed integer of piastres (`amountPiastres`).** Never `double`,
   never a decimal string. Zero is a valid, explicitly-submitted "no sales" day;
   negative is forbidden.

5. **All period and date keys are `Africa/Cairo` business civil days/months**, per
   [ADR-015](ADR-015-automation-business-timezone.md). "The current month" is never
   device-local and never UTC.

6. **Audit and notifications reuse existing seams** — `audit_logs` +
   `EventTrackingService` ([AUDIT_LOG](../design/AUDIT_LOG.md)) and the notification
   deep-link resolver ([NOTIFICATIONS](../design/NOTIFICATIONS.md)). No parallel
   subsystem is created.

**This ADR does not carve out ADR-009/010, and needs no carve-out.** Unlike
[ADR-017](ADR-017-attendance-reporting-ledger.md), sales targets ship **zero** rollup
collections, analytics Functions, stored KPIs, scoreboards, or exports. Every KPI —
days remaining, average approved daily sales, required run-rate, forecast, completion
estimate — is derived on read over a bounded month of documents and must name the
decision it changes. The moment a KPI would need a stored aggregate to be affordable,
that is a **new ADR decision**, not licence to prebuild one now.

## Consequences

- **Correction-after-approval is correct by construction.** Because no total is
  stored, editing an approved amount (a server callable, mandatory reason, `revision`
  bump) re-derives every downstream number automatically. There is no cache to
  invalidate.
- **Double approval is structurally safe.** The decision transaction requires
  `status == pending` and the expected `revision`; the second caller gets
  `failed-precondition` with no second effect.
- **Self-approval is *guarded*, not structurally impossible.** Unlike
  [Requests](../design/REQUESTS.md) (where an admin cannot create, so no path exists),
  a branch employee who also acts as an approver could submit — the callable
  therefore rejects when the actor uid equals the submitter uid. Do not remove this
  guard on the assumption that Requests' structural argument transfers; it does not.
- **Sales writes are offline-gated and do NOT inherit attendance's offline
  exception.** Attendance clock-in is allowed offline because a deterministic id makes
  a late replay safe *and* the punch happens where signal is worst. A financial close
  must not silently replay an hour later, so every sales write goes through
  `NetworkGuard.ensureWritable()` and is blocked offline. Reads stay available from
  cache under the standard `OfflineBar`.
- **A target must exist before sales can be submitted.** Employees see an explicit
  "Target not set" state rather than accumulating sales against an undefined target.
- **Lowering a target below already-approved sales is allowed** (mandatory reason,
  audited): remaining shows `0`, textual progress may read `> 100%`, the visual bar
  caps at 100%. It is never blocked and progress is never silently capped in the data.
- **A Cloud Functions deploy must precede the client build that calls it.** DROP has a
  documented deploy-lag hazard (stale production functions while the client shipped
  ahead — see CURRENT_STATE); sales inherits it. Deploy order is functions → rules +
  indexes → verify revisions → release client.
- **Two policy decisions are left to the owner at P0 sign-off**, recorded in
  SALES_TARGETS.md: (a) whether an employee may read peers' **approved** daily
  amounts for their own branch/month (recommended: yes for approved only, never
  others' pending/rejected), and (b) the back-date window for late closes
  (recommended: current + previous three Cairo days for employees; managers/admins
  unrestricted with a reason). No implementation starts until these are ruled.
- **Extension points stay optional and non-blocking:** weekly targets, per-category
  line items, multi-currency, and a designated "closer" branch config each require
  their own product decision (multi-currency requires its own ADR) and must not be
  inferred from v1.

## Alternatives considered

- **Store a running `achievedPiastres` total on the month document** and increment it
  on approval. Rejected: it is the classic drift bug — a post-approval correction, a
  reopen, or a failed partial transaction desynchronises the total from the
  submissions it claims to sum, and the spec explicitly forbids storing it. Re-summing
  a bounded month is cheap and always correct.
- **Put `monthlyTarget` as a field on `branches/{id}`.** Rejected: `branches` is
  mutable current configuration; a target belongs to a specific historical accounting
  month. A field on the branch doc either loses past-month targets or forces an
  embedded historical array. A month-keyed record is directly addressable, auditable,
  and naturally retained.
- **A scheduled monthly "reset/rollover" Function** (spec Option A, literal reading).
  Rejected: there is no state to roll over. The Cairo month key changes on its own;
  queries point at the new month with no server action. A scheduler would add a
  deploy-gated moving part and a new failure mode for zero benefit.
- **Build it on the attendance reporting ledger (rollups, close Function, versioned
  restatement).** Rejected as over-built for this scale — it is the ADR-017 machinery
  that ADR-009/010 only tolerated because attendance feeds payroll over tens of
  thousands of rows. Sales has a bounded month and no payroll obligation; deriving on
  read is simpler, inspectable, and stays inside ADR-009/010.
- **Let the client write approvals directly with a Firestore rule guard.** Rejected
  per ADR-005: an approval is a privileged financial fact. Rules cannot reliably
  derive the Cairo business date from `request.time`, cannot run the cross-document
  revision transaction, and cannot author trustworthy actor attribution. The callable
  is the enforcement point; rules are defense-in-depth.
