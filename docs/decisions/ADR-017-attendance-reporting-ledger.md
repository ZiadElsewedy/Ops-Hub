# ADR-017 — Attendance is an operational reporting ledger (a scoped carve-out of ADR-009/010)

**Status:** Accepted · **Date:** 2026-07-30

## Context

Attendance shipped as a clock-in/clock-out engine with an operational board and a
history ledger. Its product behaviour is locked in
[ATTENDANCE_SPEC.md](../design/ATTENDANCE_SPEC.md) (2026-07-18), whose §8 is titled
*"Operational Dashboard (not analytics)"* and which postpones performance reports,
payroll export, CSV/PDF, and trends. When the History surface was built, the
"analytics-payroll foundation" was **explicitly declined** as contradicting
[ADR-009](ADR-009-no-analytics-pipeline.md) and
[ADR-010](ADR-010-lean-over-enterprise.md).

The owner has now reframed the module (2026-07-29/30), in three successive
directions, as an **operational reporting system**:

- Reports are the product; the history list is a drill-down, not the destination.
- Managers need dashboards, weekly/monthly reports, trends, exports, and employee
  performance at a glance.
- Attendance must not be a silo — it reports into Schedule, Tasks, Requests, Branch
  Operations, and the role dashboards.

**The conflict with ADR-009/010 was raised with the owner, and the direction was then
reaffirmed.** This is a deliberate reversal by the person who set those rules, not an
unknowing one — which is exactly what the ADR process exists to record.

The full audit behind this decision is
[ATTENDANCE_AUDIT_2026-07-30.md](../design/ATTENDANCE_AUDIT_2026-07-30.md).

Two facts make the reversal tractable. First, the module already has ledger-grade
foundations: server-authoritative writes ([ADR-005](ADR-005-server-authoritative-writes.md)),
deterministic record ids, one `AttendanceCalculator`, correction approval objects,
append-only audit events, and shift-hour snapshots
([ADR-006](ADR-006-schedule-shift-plan-snapshots.md)). Second, it has one defect that
makes reporting impossible until fixed: **a lazy no-show writes no Firestore
document**, but the ledger aggregates materialized records only, so `absentCount`
cannot grow and the displayed rate is structurally ~always 100%.

## Decision

Draw the line at **ledger, not scoreboard.**

Attendance minutes feed payroll. That makes them auditable business facts carrying a
financial and compliance obligation — categorically different from the vanity metrics
ADR-009 rejects. A *ledger* reconciles to money and is reproducible from durable
rows; a *scoreboard* ranks people using invented weights. We build the former and
still refuse the latter.

This ADR **names the decisions it changes** (ADR-009's no-metric/no-export bar and
ADR-010's lean-scope bar), as ADR-009 requires. It follows the precedent of
[ADR-011](ADR-011-automation-observability.md), which carved automation *execution
observability* out of the same two ADRs while explicitly refusing a time-series
analytics surface. This carve-out is wider — it does authorize periodic reports and
trends over closed periods — and is therefore fenced by the metric bar below.

**The metric bar.** No attendance metric ships unless it names all five: formula ·
denominator · computation owner · gameability analysis · the decision it changes.
A metric that cannot name the decision it changes is the vanity shape and stays out.

**In scope:**

- **A durable reporting denominator.** Expected-shift and no-show facts are
  materialized server-side at period close, derived from the roster. Virtual absences
  remain for the live board only; no report or export may be trusted before close.
- Daily close · weekly · monthly · pay-period · per-employee · per-branch reports,
  and an exception queue.
- **Period lifecycle** — `open → ready → locked → exported → restated` — with stored
  explicit denominators, timezone, source schedule ids, and calculator version.
- Monochrome trends **over closed periods** ([ADR-004](ADR-004-monochrome-design.md)
  still binds; a trend earns its place by driving a decision, not by being a chart).
- Server-generated CSV and PDF export, with an export audit ledger.
- Versioned restatement when a correction lands against a locked period.
- Attendance reporting widgets inside Branch Operations and the role dashboards.

**Out of scope (still refused):**

- A general analytics pipeline. ADR-009 remains active for everything outside
  attendance reporting; this ADR authorizes nothing beyond it.
- **Composite employee performance scores** and cross-employee leaderboards.
  Weighting attendance against task outcomes is arbitrary, gameable, and invites
  misuse as discipline without context. Report adjacent lanes — Attendance
  Reliability · Work Execution · Data Quality — never one fused number. This holds
  the standard already set by `lib/features/task/domain/task_outcomes.dart`
  (ungameable denominators; excluded means excluded, not counted as failure).
- Client-authored payroll totals. Anything feeding pay or an export is computed in a
  Cloud Function under ADR-005.
- Persisting late / early-leave / overtime as statuses. They stay **derived** from
  minute fields; queryability is solved with rollup rows, not a wider status enum.
- OpsHub as a payroll processor. It hands off a reconciled ledger; it does not compute
  pay.
- Decorative heatmaps, and trend alerts to employees.
- Any new backend platform. Firebase only ([ADR-001](ADR-001-firebase-backend.md)).

## Consequences

- **ATTENDANCE_SPEC §8 is amended** from *"Operational Dashboard (not analytics)"* to
  *"Operational Reporting Ledger"*. The rest of the locked spec — the state machine,
  business rules, and edge-case rulings — is untouched and still wins on behaviour.
- **The P0 denominator fix is a prerequisite, not a phase.** Report UI built on
  today's denominator would make wrong numbers look authoritative, which is worse
  than the current history list. No report surface ships before absences are durable.
- **New server surface:** period/rollup collections, a close Function, an export
  Function writing to Storage, plus rules and indexes. All of it lands **behind the
  standing undeployed functions/rules/indexes backlog** — and 2 of 23 functions are
  currently missing in production. Reporting inherits that risk.
- **Cost moves from read-time to close-time.** Client-side aggregation over raw
  records does not survive a real business (60 staff × 2 branches × a year is tens of
  thousands of documents per annual report). Rollups make reports O(period), and
  retire the "stats aggregate client-side" debt for attendance.
- **A payroll period must name a timezone.** `Africa/Cairo` business civil day, per
  [ADR-015](ADR-015-automation-business-timezone.md). Overnight shifts (`ShiftHours`
  end > 1440) are assigned to their scheduled-start business day.
- **Past rosters become load-bearing.** A locked period's denominator must not shift
  because someone edited an old week; expected-shift rows are frozen at close.
- **Restatement replaces silent mutation.** A correction against a locked period
  produces a new version with a link to what it supersedes, never an in-place edit.
- If a future need for genuine analytics appears outside attendance, it needs its
  **own** ADR — this one does not authorize it.

## Alternatives considered

- **Refuse the request and hold ADR-009/010.** Rejected: the owner set those rules,
  was shown the conflict, and reaffirmed the direction. Attendance minutes feeding
  payroll is a real operational obligation, not a vanity metric — the ADR-009
  reasoning does not actually cover this case.
- **Derive absences at read time by re-joining the roster** instead of materializing
  them. Rejected as the primary path: it re-derives payroll-relevant facts on every
  read, cannot be frozen at close, and makes a signed-off report depend on a mutable
  past roster. Kept only for the live board, where nothing is signed off.
- **Add `late` / `overtime` as persisted statuses** so exceptions are queryable.
  Rejected: it reintroduces the status drift the small enum exists to prevent. Rollup
  rows give the same queryability without widening the persisted vocabulary.
- **One composite employee performance score.** Rejected on the merits even though
  the owner asked for performance at a glance — see Out of scope. Adjacent lanes
  answer the same question without hiding which behaviour needs action.
- **Client-side PDF/CSV generation.** Rejected: a client-authored payroll artifact is
  unauditable and contradicts ADR-005. Server generation also lets the export ledger
  record who requested what, when.
