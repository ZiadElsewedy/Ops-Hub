# Attendance Audit 2026-07-30

Date: 2026-07-30

This is a product and UX audit plus redesign proposal. It is not implemented, it is not a product specification, and it does not supersede the locked Attendance spec until a new ADR is accepted.

Reading guide:

- Read sections 1-4 first if deciding whether Attendance can become a reporting system.
- Read sections 8, 15, and 17 if deciding what to build.
- Read Appendix A if deciding how to amend the existing ADR position.
- Every current-behavior claim is tied to code or a project document where the repository exposes one.

## 1. Verdict

Attendance should be refounded as a reporting ledger, not as a clock screen plus history list.

The current implementation is strongest at the hard parts of a trustworthy attendance system: server-authoritative timestamps, deterministic record ids, a single minute calculator, separate correction approvals, geofence verification, and append-only audit events.

The current product experience is weakest at the thing the owner now wants most: managers cannot open Attendance and understand branch reliability, employee exceptions, close readiness, or payroll exposure at a glance.

The highest-leverage change is not visual polish. It is creating a server-owned reporting denominator from Schedule.

Today a rostered no-show can exist as a virtual board row but no Firestore attendance document. The history summary aggregates materialized records only, so absence can disappear from the denominator and the displayed attendance rate can become structurally untrustworthy.

Reports must become the primary product surface. The history list should survive as evidence and drill-down, not as the destination.

Desktop-first is also a real redesign, not a responsive tweak. Attendance screens use mobile-shaped single-column layouts, while the rest of the app already has desktop conventions in Admin Dashboard V2, Branch Operations, Schedule, and the shared primitives.

This proposal recommends a staged reporting system:

- Keep the current clock/correction engine.
- Add a Cloud Function close process that materializes expected shifts and no-shows.
- Add period rollups and export requests.
- Replace manager history-first IA with a report hub, close queue, exception queue, and report detail.
- Keep employee Attendance focused on "am I correct for this pay period?"

The proposal also requires an explicit ADR reversal. ADR-009 and ADR-010 rejected analytics-shaped surfaces; the owner has now reaffirmed dashboards, trends, performance at a glance, and exports after that conflict was raised.

The defensible line is ledger, not scoreboard. Attendance minutes feed payroll and operational compliance; they are auditable business facts, not vanity metrics. Composite employee scores and public rankings remain recommended against.

## 2. The Reframe

### 2.1 What changes

When Attendance is a standalone feature, the product question is:

| Role | Current question implied by the IA | Current destination |
| --- | --- | --- |
| Employee | "Can I clock in or clock out?" | Employee clock screen |
| Manager | "What attendance records exist?" | Branch ledger/history |
| Admin | "Which branch records can I browse?" | Branch review list |

When Attendance is an operational reporting system, the product question changes:

| Role | New primary question | Primary surface |
| --- | --- | --- |
| Employee | "Is my month/pay-period record correct before it affects pay?" | My Attendance period view |
| Manager | "Who needs a decision today, and is this period ready to close?" | Branch Attendance close workspace |
| Admin | "Which branches are exposed before payroll/export, and why?" | Attendance Reports hub |
| Owner/operator | "What changed week over week, and which exceptions are material?" | Period reports and trends |

The amendment changes the product center of gravity:

| Old center | New center |
| --- | --- |
| Clock actions | Close readiness |
| Flat records | Reports |
| Filter chips | Exception queues |
| "Rate" strip | Named metrics with denominators |
| Client summaries | Server-owned rollups for payroll-relevant numbers |
| Attendance silo | Schedule, Tasks, Requests, Branch Operations, and dashboards |

### 2.2 What the current IA answers instead

The current branch review screen leads with:

- Branch picker.
- Six/seven summary values.
- Free-text employee search.
- Three horizontal chip rows.
- Flat vertical record cards.

The implementation confirms this structure in `lib/features/attendance/presentation/history/attendance_history_screen.dart:148`, `lib/features/attendance/presentation/history/widgets/attendance_history_filters.dart:42`, and `lib/features/attendance/presentation/history/widgets/attendance_history_summary.dart:19`.

That IA answers "which records match these filters?"

It does not answer:

- Is today ready to close?
- Which no-shows have no record?
- Which corrections block payroll?
- What changed since last week?
- Which employees need manager review?
- Which branch is highest risk before export?
- Can payroll trust this period?

The amendment explicitly says the history list is the wrong destination. The proposed IA treats it as evidence behind a report, queue, or employee row.

## 3. The Central Tension

### 3.1 The conflict

The owner asks for:

- Dashboards.
- Trends.
- Employee performance at a glance.
- Weekly and monthly reports.
- Payroll-ready PDF/CSV exports.

The standing architecture says the opposite in several places:

| Source | Existing position | Conflict |
| --- | --- | --- |
| `docs/decisions/ADR-009-no-analytics-pipeline.md` | Avoid analytics and vanity metrics unless a metric names the decision it changes. | Trends and performance dashboards are time-series reporting surfaces. |
| `docs/decisions/ADR-010-lean-over-enterprise.md` | Avoid enterprise-shaped scope before the product proves it needs it. | Payroll-ready exports and report catalogues are enterprise-shaped. |
| `docs/design/ATTENDANCE_SPEC.md` | Section 8 is "Operational Dashboard (not analytics)". | The amendment asks for reports to be the product. |
| `CURRENT_STATE.md` | Attendance history holds ADR-009/010: no score, analytics, export. | The requested proposal reverses that position. |

This proposal does not refuse the owner's amendment.

The amendment came after the conflict was raised. That makes it a deliberate product direction change. The right response is to make the reversal explicit, scoped, and cheap to adopt.

### 3.2 The line that survives ADR-009

Attendance reporting should be allowed because it is a ledger.

It should not become a scoreboard.

| Allowed | Reason |
| --- | --- |
| Expected shifts | Directly derived from Schedule, which defines work obligation. |
| Worked minutes | Feed pay, staffing, close, and exception decisions. |
| Absence rate | Needed to reconcile roster against actual coverage. |
| Punctual arrival rate | Needed for shift reliability and branch operations. |
| Exception queue | Needed so managers can decide before payroll cutoff. |
| Period export | Needed to hand facts to payroll or accounting. |
| Trends over closed periods | Needed to spot operational changes and staffing risk. |

| Recommended against | Reason |
| --- | --- |
| Composite 0-100 employee score | Invented weighting is gameable and easy to misuse. |
| Public employee leaderboard | Encourages comparison without context. |
| Vanity heatmaps with no decision | Violates the ADR-009 decision bar. |
| Trend alerts to employees | Creates anxiety without a required action. |
| Persisted "late" status | Violates the small status-space decision in `lib/core/enums/attendance_status.dart:1`. |

ADR-011 is the precedent. It carved out automation observability from ADR-009/010 because automation execution needed an operational audit surface. Attendance deserves a similar carve-out because attendance minutes feed money, coverage, and compliance.

### 3.3 Required ADR change

Appendix A drafts ADR-017.

It changes:

- ADR-009: attendance operational reporting is not vanity analytics when every metric has a named decision, denominator, and audit trail.
- ADR-010: reporting is allowed only to the level needed for close, payroll handoff, and branch operations.
- ATTENDANCE_SPEC section 8: "Operational Dashboard (not analytics)" becomes "Operational Reporting Ledger".

It preserves:

- No general analytics pipeline.
- No composite scores.
- No leaderboards.
- No new backend platform.
- Server-authoritative payroll numbers.

## 4. The Broken Foundation

### 4.1 The load-bearing defect

The current reporting foundation cannot support the owner's request because the most important negative event, a rostered no-show, may have no attendance document.

The code proves the split:

| Fact | Evidence |
| --- | --- |
| The live board joins roster plus today's attendance. | `lib/features/attendance/domain/attendance_board.dart:7` |
| If no record exists and the shift is over, the board can show `absent`. | `lib/features/attendance/domain/attendance_board.dart:142` |
| The board model is today-oriented and computed in memory. | `lib/features/attendance/domain/attendance_board.dart:150` |
| History summaries aggregate only records they receive. | `lib/features/attendance/domain/attendance_analytics.dart:87` |
| Absence count only counts materialized records whose status is absence. | `lib/features/attendance/domain/attendance_analytics.dart:89` |
| Attendance percent is present / (present + absent). | `lib/features/attendance/domain/attendance_analytics.dart:57` |
| History stream reads attendance documents, not roster expectations. | `lib/features/attendance/data/datasources/attendance_remote_datasource.dart:183` |
| Branch range reads attendance documents by branch/date range. | `lib/features/attendance/data/datasources/attendance_remote_datasource.dart:207` |

Therefore:

- A no-show can be visible on today's board.
- The same no-show can disappear from historical summary after the day passes.
- The denominator cannot grow.
- Attendance rate can pin at or near 100 percent.
- Reports, trends, and exports become untrustworthy.

This is a BUG in reporting behavior, even though lazy absence was a deliberate MVP design.

### 4.2 Why this matters more than UI

A beautiful report on top of the current denominator would be worse than the current history list because it would make wrong numbers look more authoritative.

The owner asked for operational reporting. Operational reporting has a hard floor:

| Requirement | Current support |
| --- | --- |
| Know who was expected to work | Exists in Schedule, not in attendance history. |
| Know who did not appear | Exists as virtual today board row, not durable history. |
| Know which denominator a rate used | Not shown on current metric strip. |
| Reproduce a closed period later | Not guaranteed if past rosters can change. |
| Export payroll facts | Not built. |

### 4.3 Resolution options

#### Option A: Materialize on close

At a daily or period close, a Cloud Function reads Schedule plus attendance records and writes durable expected-shift rows and absence rows.

Possible shapes:

- Materialize missing no-shows as `attendance` documents with status `absent`.
- Or materialize expected-shift rows in a reporting collection and leave the raw attendance collection untouched.
- Use rollups to summarize both raw records and no-shows.

Benefits:

| Benefit | Explanation |
| --- | --- |
| Payroll auditability | Every expected shift has a durable row. |
| Stable denominator | Rates can be reproduced from closed rows. |
| Server authority | Function owns payroll-relevant facts under ADR-005. |
| Export ready | CSV/PDF can use closed report rows, not live client joins. |
| Backfill possible | Historical periods can be rebuilt where schedules still exist. |
| Queryable queues | Unresolved absences and exceptions can be indexed as reporting facts. |

Costs:

| Cost | Explanation |
| --- | --- |
| Writes | No-show days now create durable data. |
| Functions deploy risk | This inherits the undeployed functions/rules/indexes backlog. |
| Backfill ambiguity | Old mutable schedules may not represent historical truth. |
| Period lock needed | Corrections after close require restatement, not silent mutation. |

Correctness concerns:

- The close Function must use the same minute math as `AttendanceCalculator`, or a server-side equivalent must be generated from the same business rules.
- The source schedule id, shift slot, scheduled start/end, timezone, and roster snapshot must be copied into the report row.
- The report row must record whether it was computed from a verified schedule snapshot or from a best-effort historical roster.

Recommendation:

Use materialize-on-close for report facts.

Do not rely on raw `attendance` documents alone. Prefer a reporting row/rollup collection so the raw attendance state machine stays small and the report ledger can carry close/export metadata.

#### Option B: Derive at read

Every report query joins attendance records with Schedule and derives expected shifts at read time.

Benefits:

| Benefit | Explanation |
| --- | --- |
| Fewer writes | No new absence or expectation rows. |
| Preserves lazy MVP | Matches the spec rationale in `docs/design/ATTENDANCE_SPEC.md`. |
| Flexible | Can recompute after schedule changes. |

Costs:

| Cost | Explanation |
| --- | --- |
| Not payroll-auditable | A report can change if a historical schedule changes. |
| Expensive at scale | Every report joins rosters plus records. |
| Multiple calculators risk | Client, Function, and export can disagree. |
| Bad offline story | Managers cannot trust downloaded report files if source joins move. |
| Hard to lock | A closed period needs immutable inputs, not live joins. |

This option is acceptable for the live board only.

It is not sufficient for payroll-ready reporting.

#### Option C: Hybrid

Use read-time derivation for open/live periods and materialized reporting rows for closed periods.

This is the recommended architecture:

| Period state | Source of truth |
| --- | --- |
| Today/open shift | Live roster + raw attendance records. |
| Ready to close | Cloud Function computes expected-shift rows and exceptions. |
| Closed/locked | Reporting rows and rollups. |
| Exported | Stored export file plus report version. |
| Restated | New report version with delta from previous version. |

The live board can remain virtual. Reporting cannot.

### 4.4 Recommendation in one sentence

Keep lazy absence for live UI, but materialize no-shows and expected-shift facts at daily close through Cloud Functions before any weekly, monthly, pay-period, trend, or export surface is considered trustworthy.

## 5. What Exists Today

### 5.1 Current screens

| Screen | Route | Primary user | What it does today | What it does well | What fails for reporting | Can users find it? |
| --- | --- | --- | --- | --- | --- | --- |
| Employee clock | `/attendance` | Employee, also reachable by manager/admin through common attendance action | Shows current shift, clock in/out, GPS, recent history, correction actions. | Strong action focus and validation. | Does not answer period/pay correctness as primary job. | Yes for employee via app shell top action and sidebar. |
| Manager live board | `/admin/attendance` | Admin/manager depending entry | Branch live board, working/late/absent strip, pending corrections tab. | Good today triage seed. | Not a report, not period-aware, not desktop-first. | Admin sidebar points here; manager sidebar does not. |
| Self history | `/attendance/history` | Employee | Filtered personal ledger. | Gives evidence and detail navigation. | 180-record cap and client facets make it unsuitable for annual/payroll report. | Not primary nav; reachable from employee clock. |
| Branch review | `/attendance/review` | Manager/admin | Branch picker, summary, filters, flat record cards. | Gives branch ledger access. | Reports are missing; filters dominate; no close workflow. | Manager sidebar points here; admin reaches via manager tile/history icon. |
| Record details | `/attendance/record/:id` | Employee/manager/admin within scope | Record facts, audit timeline, corrections, metadata. | Strong audit candidate. | Needs report-period context and export/restatement references. | Only via cards/rows; acceptable as drill-down. |

Evidence:

- Routes are named in `lib/core/routes/route_names.dart` and surfaced through shell/sidebar usage.
- Employee screen uses `AdaptiveScaffold` and a single list body in `lib/features/attendance/presentation/pages/attendance_screen.dart:57` and `lib/features/attendance/presentation/pages/attendance_screen.dart:195`.
- Admin board uses `AdaptiveScaffold` and list/column body in `lib/features/attendance/presentation/pages/admin_attendance_screen.dart:52` and `lib/features/attendance/presentation/pages/admin_attendance_screen.dart:130`.
- Branch history uses a single `ListView` body in `lib/features/attendance/presentation/history/attendance_history_screen.dart:148`.
- Details screen is explicitly described as canonical audit view in `lib/features/attendance/presentation/details/attendance_details_screen.dart:21`.

### 5.2 Navigation reality

| Role | Desktop navigation today | Mobile navigation today | Reporting consequence |
| --- | --- | --- | --- |
| Admin | Sidebar item "Attendance" goes to `/admin/attendance`. | Bottom nav does not include Attendance; top action can expose common attendance. | Admin lands on live board, not report hub. |
| Manager | Sidebar item "Attendance" goes to `/attendance/review`. | Bottom nav does not include Attendance; home tile links to review. | Manager lands on history list, not close queue. |
| Employee | Sidebar item "Attendance" goes to `/attendance`. | Top action routes to `/attendance`. | Employee lands on clock surface, which is correct but incomplete. |

Evidence:

- Desktop/mobile shell split is in `lib/core/widgets/role_scaffold.dart:17`.
- Mobile bottom nav is Home, Tasks, Schedule, Chat in `lib/core/widgets/role_scaffold.dart:118`.
- Admin sidebar Attendance points to `/admin/attendance` in `lib/core/widgets/app_shell.dart:95`.
- Manager sidebar Attendance points to `/attendance/review` in `lib/core/widgets/app_shell.dart:160`.
- Employee sidebar Attendance points to `/attendance` in `lib/core/widgets/app_shell.dart:196`.
- Manager home Attendance tile describes "Review your team's clock-in history" in `lib/features/manager/presentation/pages/manager_home_screen.dart:173`.

### 5.3 What is worth keeping

| Asset | Keep because |
| --- | --- |
| `AttendanceCalculator` | It centralizes worked, late, early-leave, overtime, and break math. |
| Deterministic attendance id | It prevents duplicate same-day/shift records and supports idempotent server operations. |
| Separate correction object | It creates an approval workflow without mutating the raw record directly. |
| Audit events subcollection | It is the right evidence layer for details and exports. |
| GPS verifier | It is pure and can explain geofence pass/fail without UI guesswork. |
| Admin/manager/employee scope model | It already encodes admin global and manager own-branch access in rules. |
| Virtual live board | It is useful for today operations before close. |

Evidence:

- Calculator summary is in `lib/features/attendance/domain/attendance_calculator.dart:42`.
- Deterministic id rationale is in `lib/features/attendance/domain/attendance_id.dart:1`.
- Corrections are separate and server-applied in `lib/features/attendance/domain/entities/attendance_correction.dart:10`.
- Audit events are append-only in `lib/features/attendance/domain/entities/attendance_event.dart:5`.
- GPS Haversine verifier is in `lib/features/attendance/domain/attendance_gps.dart:5`.
- Firestore manager/admin/owner read scope is in `firestore.rules:806`.

### 5.4 What should be replaced

| Current surface | Recommendation | Why |
| --- | --- | --- |
| Branch review as primary manager destination | Replace with Branch Attendance Workspace | Managers need close readiness and exception decisions, not a filter exercise. |
| Summary strip label "Rate" | Replace with named metrics and denominators | "Rate" is ambiguous and hides late-as-present semantics. |
| Three stacked chip rows | Replace with saved report views, table columns, and a filter drawer | 16 controls before evidence is poor desktop IA. |
| Live board as admin Attendance root | Replace with report hub plus live close module | Admins need cross-branch risk, not one branch board first. |
| Record-card-only history | Replace with desktop table plus detail side panel | Managers need sorting, comparison, bulk action, exportable rows. |

### 5.5 Doc drift

The code wins over documents.

| Drift | Code evidence | Product implication |
| --- | --- | --- |
| `docs/design/ATTENDANCE.md` says early clock-in is not yet enforced. | Validation rejects too-early clock-in using `scheduledStart - clockInLead` in `lib/features/attendance/domain/attendance_validation.dart:73`. | Treat early lead as implemented. |
| The locked spec says lazy absence creates no document. | Current board still derives absence virtually in `lib/features/attendance/domain/attendance_board.dart:142`; no history writer materializes no-shows. | Spec and code align, but the amendment now makes this inadequate. |
| History is documented as holding no analytics/export. | Owner amendment asks for reports/export after that was challenged. | Requires ADR update, not quiet doc editing. |

## 6. Lifecycle Audit

### 6.1 Persisted and virtual vocabulary

Persisted statuses are frozen. Do not rename wire values.

| Status | Persisted? | Current meaning | Reporting handling |
| --- | --- | --- | --- |
| `scheduled` | Yes, but mostly virtual/design vocabulary | Expected but not yet started. | Use only as raw state if already present; report expected shifts through reporting rows, not status rename. |
| `inProgress` | Yes | Clocked in, not clocked out. | Open shift; provisional minutes only. |
| `completed` | Yes | Clocked out, calculator totals available. | Payroll candidate if no unresolved exception. |
| `pendingReview` | Yes | Needs manager decision, often auto-close/missed punch. | Blocks period close. |
| `absent` | Yes | Unexcused no-show when materialized or manager-resolved. | Must be durable for reports. |
| `onLeave` | Yes | Forgiven scheduled non-work day from schedule leave. | Excluded from show-up denominator; included as leave count. |
| `excused` | Yes | Terminal forgiven outcome with reason. | Excluded from show-up denominator but reported separately. |

Evidence:

- Status definitions and labels are in `lib/core/enums/attendance_status.dart:28`.
- Late, early leave, and overtime are derived from minute fields in `lib/core/enums/attendance_status.dart:1` and `lib/features/attendance/domain/entities/attendance_entity.dart:17`.

### 6.2 Implemented state flow

| Transition | Trigger today | Actor | Evidence | Reporting concern |
| --- | --- | --- | --- | --- |
| Rostered shift -> virtual not started | Schedule assignment, no attendance record | System/client board | `lib/features/attendance/domain/attendance_board.dart:150` | Not durable. |
| Virtual not started -> inProgress | Clock in | Employee | `lib/features/attendance/data/datasources/attendance_remote_datasource.dart:224` | Good raw event. |
| inProgress -> completed | Clock out | Employee | `lib/features/attendance/data/datasources/attendance_remote_datasource.dart:244` | Good raw event, GPS out captured but not blocking. |
| inProgress -> pendingReview | Auto close | Function | `functions/index.js:3686` | Deploy issue until functions deployed. |
| No record -> virtual absent | Board evaluation after shift end | Client/domain board | `lib/features/attendance/domain/attendance_board.dart:142` | Broken for history and reports. |
| No record -> excused | Manager excuse absence | Manager/admin | `lib/features/attendance/presentation/cubit/attendance_admin_cubit.dart:283` | Materializes a forgiven row. |
| Record -> correction pending | Correction request | Employee/manager | `lib/features/attendance/data/datasources/attendance_remote_datasource.dart:288` | Blocks close/export. |
| Correction pending -> approved/rejected | Manager/admin decision | Reviewer | `functions/index.js:3550` | Server applies approved correction. |
| Missing punch -> materialized after approval | Correction resolution | Function | `functions/index.js:3498` | Good path for no-record correction, but not no-show absence. |
| Record -> soft deleted | Correction or admin action shape | Server/client repository filters | `lib/features/attendance/data/repositories/attendance_repository_impl.dart:24` | Exports must exclude soft-deleted records but preserve audit reference. |

### 6.3 What a reporting business needs

| Needed lifecycle state | Exists today? | Proposal |
| --- | --- | --- |
| Open period | Partial | Use live board and raw records. |
| Ready to close | No | Function computes daily expected rows and unresolved exceptions. |
| Exception triage | Partial | Promote pending corrections, absences, missing punches, implausible records into one queue. |
| Closed/locked period | No | Add report period state and lock metadata. |
| Exported period | No | Add export request, Storage file, audit event. |
| Restated period | No | Add versioned report period and delta reason after corrections. |

### 6.4 Virtual/real split

The current split is correct for live operations and wrong for historical reporting.

| Use case | Virtual absence acceptable? | Why |
| --- | --- | --- |
| "Who is missing right now?" | Yes | Needs live roster join. |
| "Is today's board red?" | Yes | Board state can change as the day progresses. |
| "What was last month attendance rate?" | No | Denominator must be durable. |
| "Export payroll CSV" | No | Payroll needs reproducible facts. |
| "Show employee trend over 12 weeks" | No | Trend buckets must use stable denominator. |

## 7. Correctness Findings

### 7.1 Ranked findings

| Severity | Type | Finding | Evidence | Failure scenario | Recommendation |
| --- | --- | --- | --- | --- | --- |
| P0 | BUG | No-show absence can vanish from history denominator. | `lib/features/attendance/domain/attendance_board.dart:142`, `lib/features/attendance/domain/attendance_analytics.dart:57` | Branch has 4 no-shows and history still shows Rate 100%. | Materialize expected/no-show facts at close. |
| P0 | GAP | No period close/lock/export lifecycle exists. | No period/export collection in `docs/design/DATA_MODEL.md`; correction lifecycle only in `lib/features/attendance/domain/entities/attendance_correction.dart:10` | Manager exports before corrections are resolved, then numbers change. | Add period states and export request audit. |
| P1 | DESIGN DISAGREEMENT | Reports are absent because spec intentionally declined analytics/export. | `docs/design/ATTENDANCE_SPEC.md`, `CURRENT_STATE.md` | Owner wants reporting but team has no accepted ADR basis. | Adopt ADR-017. |
| P1 | GAP | No desktop Attendance layout exists. | `lib/features/attendance/presentation/history/attendance_history_screen.dart:148`, `lib/features/attendance/presentation/pages/admin_attendance_screen.dart:130` | macOS shows mobile list and stacked filters. | Replace with report workspace/table/side panel. |
| P1 | BUG | Metric label "Rate" is ambiguous. | `lib/features/attendance/presentation/history/widgets/attendance_history_summary.dart:38`, `lib/features/attendance/domain/attendance_analytics.dart:57` | Manager reads Rate as punctuality while late still counts present. | Rename to Show-up rate and add denominator tooltip/detail. |
| P1 | GAP | Self-history cap prevents annual/past-period report. | `lib/features/attendance/presentation/history/attendance_history_cubit.dart:133` | Employee cannot verify annual/pay-period history beyond latest 180 records. | Use period rows and paginated/range queries. |
| P1 | DESIGN DISAGREEMENT | Client-side filtering/aggregation is accepted debt but conflicts with reporting scale. | `lib/features/attendance/domain/attendance_history_query.dart:115`, `lib/features/attendance/domain/attendance_analytics.dart:3` | 120 staff x year streams tens of thousands of rows to compute a strip. | Scheduled rollups. |
| P1 | BUG | One-minute sessions can read as "0m worked" without incident framing. | `lib/features/attendance/domain/attendance_calculator.dart:71`, `lib/features/attendance/presentation/history/widgets/attendance_record_card.dart:163` | Employee clocks 14:14-14:15 and card appears nonsensical. | Add implausible-record exception. |
| P2 | BUG | Week boundary differs between Schedule and history presets. | `lib/features/schedule/domain/schedule_week.dart:3`, `lib/features/attendance/domain/attendance_history_query.dart:86` | Weekly report covers Monday-Sunday while roster doc is Sunday-based. | Define report week explicitly, likely schedule week or pay period. |
| P2 | BUG | Attendance streak math normalizes dates in UTC. | `lib/features/attendance/domain/attendance_analytics.dart:172` | Cairo late-night/overnight records can bucket incorrectly. | Use `Africa/Cairo` business day for reporting. |
| P2 | GAP | Past schedules can be updated/deleted by branch-scoped roles. | `firestore.rules:427`, `lib/features/schedule/data/datasources/schedule_remote_datasource.dart:170` | A closed report changes if old roster changes. | Lock/freeze expected shift rows at close. |
| P2 | DEPLOY ISSUE | Audit and auto-close reliability depends on undeployed functions. | `functions/index.js:3450`, `functions/index.js:3686` | Production lacks server events/auto-close despite code existing. | Treat reporting backend as blocked until deploy backlog is resolved. |
| P2 | GAP | Derived exception facts are not queryable as statuses. | `lib/core/enums/attendance_status_filter.dart:1`, `lib/features/attendance/domain/attendance_history_query.dart:151` | Server cannot query "late overtime unresolved" directly. | Store derived counts/flags in rollups, not status enum. |
| P2 | GAP | Notifications cover corrections/auto-close but not period close. | `functions/index.js:3404`, `functions/index.js:3550`, `functions/index.js:3686` | Manager misses payroll cutoff with unresolved exceptions. | Add cutoff and export-ready notifications. |
| P3 | POLISH | Record details lack report-period/export context. | `lib/features/attendance/presentation/details/attendance_details_screen.dart:87` | Reviewer cannot see if this record is part of an exported period. | Add report membership and restatement links. |

### 7.2 The "0m worked" case

The calculator is not wrong.

`AttendanceCalculator.compute` sets `workStart` to the later of scheduled start and actual clock-in in `lib/features/attendance/domain/attendance_calculator.dart:79`.

That means a very late, one-minute session can correctly produce:

- Almost zero worked minutes.
- Large late minutes.
- Large early-leave minutes.

The product failure is display and triage.

The record card formats minutes with `_hm()` in `lib/features/attendance/presentation/history/widgets/attendance_record_card.dart:163`, so a one-minute or sub-hour session can be visually collapsed into a row that reads as absurd without explaining why.

Proposal:

- Add an "Implausible record" exception category.
- Define it in a pure domain file, not a widget.
- Flag it when worked minutes are below a configured floor and the scheduled shift is substantial.
- Keep it as a review flag, not as a status.
- Include it in close readiness and export exception codes.

### 7.3 Scale math

At 60 staff x 2 branches x 1 year:

| Scenario | Approximate rows |
| --- | --- |
| Daily expectation, 365 days | 43,800 expected-shift opportunities |
| Five-day roster, 52 weeks | 31,200 expected-shift opportunities |
| Two shifts per employee on some days | Higher than either estimate |

Current branch range reads materialized attendance records and aggregates client-side. If absences are materialized as records, annual reports will stream tens of thousands of docs unless rollups exist.

Therefore:

- Raw records remain evidence.
- Rollups become the default report source.
- Detail tables page into raw/report rows only when needed.

## 8. The Reporting System

### 8.1 Product principle

Reports are the product.

History is evidence.

The manager should land on answers:

- Is today staffed?
- What is blocking close?
- Is this period ready for payroll?
- Which employees have unresolved facts?
- What changed compared with last period?

### 8.2 Report catalogue

| Report | Audience | Period | Primary decision | Primary source | Exportable |
| --- | --- | --- | --- | --- | --- |
| Daily Close | Manager, admin | One business day | Can we close today's attendance? | Close Function + daily rollup | PDF summary optional, CSV no |
| Exception Queue | Manager, admin | Open period/current day | Who needs a decision? | Exception rows/flags | CSV yes for audit, PDF optional |
| Weekly Branch Report | Manager, admin | Schedule week or configured week | What changed this week? | Daily rollups -> weekly rollup | PDF yes, CSV yes |
| Monthly Branch Report | Manager, admin | Calendar month in Africa/Cairo | Are branch attendance facts ready? | Period rollup | PDF yes, CSV yes |
| Pay-period Report | Admin, manager where scoped | Configured pay period | What should payroll receive? | Locked period rows | CSV required, PDF yes |
| Per-Employee Report | Employee, manager, admin | Month/pay period/custom | Is this person's record correct and fair? | Employee period rows | PDF yes, CSV row export yes |
| Per-Branch Comparison | Admin | Week/month/pay period | Which branch needs operational help? | Branch rollups | PDF yes, CSV summary yes |
| Export Ledger | Admin, manager scoped | Closed period | What files were generated and by whom? | Export request docs + Storage metadata | N/A |

### 8.3 Metric rules

Every metric must have:

- Name.
- Formula.
- Denominator.
- Computation owner.
- Gameability analysis.
- Action it changes.

No metric ships if it cannot name the decision it changes.

### 8.4 Core metric definitions

| Metric | Formula | Denominator | Computed by | Gameability analysis | Decision |
| --- | --- | --- | --- | --- | --- |
| Expected work shifts | Rostered shifts minus approved leave/on-leave/excused exclusions | Schedule roster slots | Close Function | Not employee-controlled if roster is locked/snapshotted. | Defines all rate denominators. |
| Show-up rate | Present shifts / expected work shifts | Expected work shifts | Rollup Function | Ungameable if no-shows are materialized; late still counts as present. | Staffing reliability. |
| Unexcused absence rate | Unexcused absent shifts / expected work shifts | Expected work shifts | Rollup Function | Ungameable if denominator comes from Schedule. | Manager intervention and coverage planning. |
| Punctual arrival rate | On-time arrivals / present scheduled arrivals | Present scheduled arrivals | Rollup Function | Avoids penalizing leave/excused; can be gamed by skipping entirely unless absence is shown beside it. | Coaching and shift handoff reliability. |
| Late minutes | Sum lateMinutes | Present scheduled arrivals | `AttendanceCalculator` then rollup | Direct timestamp math; no status drift. | Understand lateness severity. |
| Early-leave minutes | Sum earlyLeaveMinutes | Completed/pending records with scheduled end | `AttendanceCalculator` then rollup | Direct timestamp math; needs missing-punch exclusion. | Coverage gaps near shift end. |
| Overtime minutes | Sum overtimeMinutes | Completed records with scheduled end | `AttendanceCalculator` then rollup | Needs approval/policy context; otherwise overtime can be self-created. | Payroll review and staffing. |
| Worked minutes | Sum workedMinutes | Present records | `AttendanceCalculator` then rollup | Direct math; not a pay guarantee without break/pay policy. | Payroll input candidate. |
| Exception count | Count rows with actionable exception flags | Expected work shifts plus unscheduled work rows | Close Function | Must be explainable; no composite weighting. | Triage workload. |
| Pending correction count | Open correction requests | Open corrections in scope | Function/query | Employee can request but not approve; no self-approval. | Close blocker. |
| Implausible record count | Count records matching pure domain implausibility rules | Present records | Close Function/domain | Review flag, not punishment; avoids hidden data-quality failures. | Data cleanup before export. |
| Unscheduled work count | Records with no scheduledStart/scheduledEnd | Raw attendance records | Close Function | Employee can create if allowed; must be reviewed. | Payroll and schedule discipline. |
| Close readiness | All required exceptions resolved and period totals generated | Period checklist | Function | Boolean state; not a performance metric. | Close/export. |

### 8.5 Label fixes

Current "Rate" should be retired.

| Current label | Actual meaning | Proposed label |
| --- | --- | --- |
| Rate | Present / (present + absent) over materialized records | Show-up rate |
| Late | Count of present records with lateMinutes > 0 | Late arrivals |
| Worked | Sum worked minutes over materialized records | Worked time recorded |
| Avg arrival | Mean clock-in **wall-clock time**, not lateness: `avgArrivalMinuteOfDay` averages `clockIn.hour * 60 + clockIn.minute` and renders it as a time (`lib/features/attendance/domain/attendance_analytics.dart:104`, `lib/features/attendance/presentation/history/widgets/attendance_history_summary.dart:49`) | Average clock-in time |

Note on `Avg arrival`: averaging minute-of-day is **broken across midnight**. A 23:50 and a 00:10 arrival average to 12:00 noon. The file's own doc comment concedes this for `avgLeaveMinuteOfDay` (`lib/features/attendance/domain/attendance_analytics.dart:32`) but the identical wrap affects `avgArrivalMinuteOfDay` for night shifts, where it is not flagged. Either scope this metric to day shifts, compute it as a signed variance from `scheduledStart` (which has no wrap problem and is the more useful number), or drop it. Do not carry the raw minute-of-day mean into a report.

The report UI must show denominator details in a compact disclosure:

Example:

`Show-up rate 93% - 56 present / 60 expected work shifts; leave and excused excluded.`

### 8.6 Where numbers are computed

| Number class | Owner | Why |
| --- | --- | --- |
| Live "currently working" count | Client/domain board | It changes every minute and does not feed payroll. |
| Clock eligibility | Domain validation + client UX | Existing validation already centralizes it. |
| Worked/late/early/overtime minutes | `AttendanceCalculator` or server equivalent | Single math source. |
| Payroll/export totals | Cloud Function | Server-authoritative under ADR-005. |
| Period close state | Cloud Function | Must be auditable and rules-enforced. |
| Trend buckets | Scheduled rollup Function | Avoids client-side annual scans. |
| Personal period preview | Rollup rows plus raw drilldown | Employee can see same facts manager will close. |
| UI-only sort/filter | Client | Sorting visible rows does not create facts. |

### 8.7 Proposed reporting data shape

Use additive collections. Do not rename existing attendance enum values.

#### `attendance_periods/{periodId}`

| Field | Type | Meaning |
| --- | --- | --- |
| `periodId` | string | Deterministic id: scope + type + start + end + version. |
| `scopeKind` | string | `branch` or `multiBranch`. |
| `branchIds` | array<string> | Explicit scope; admin reports cannot assume admin branch. |
| `periodType` | string | `daily`, `weekly`, `monthly`, `payPeriod`. |
| `startDate` | string | `yyyy-MM-dd` business date in Africa/Cairo. |
| `endDate` | string | Inclusive business date in Africa/Cairo. |
| `timezone` | string | Always `Africa/Cairo` until branch timezone exists. |
| `status` | string | `open`, `ready`, `locked`, `exported`, `restated`. |
| `version` | int | Starts at 1; increments on restatement. |
| `sourceScheduleIds` | array<string> | Schedules used for denominator. |
| `sourceRecordsHash` | string | Integrity marker for source row set. |
| `calculatorVersion` | string | Version/commit marker for minute math. |
| `counts` | map | Summary counts. |
| `minutes` | map | Worked/late/early/overtime/break totals. |
| `denominators` | map | Explicit denominators used by rates. |
| `createdAt` | timestamp | Server timestamp. |
| `closedAt` | timestamp? | Server timestamp. |
| `closedBy` | string? | UID. |
| `supersedesPeriodId` | string? | Restatement link. |

#### `attendance_periods/{periodId}/employee_rows/{uid}`

| Field | Type | Meaning |
| --- | --- | --- |
| `uid` | string | Employee id. |
| `displayName` | string | Snapshot for export readability. |
| `branchId` | string | Branch scope. |
| `expectedShifts` | int | Denominator before exclusions. |
| `excludedLeaveShifts` | int | Leave/on-leave exclusions. |
| `excusedShifts` | int | Excused exclusions with reason count. |
| `presentShifts` | int | In progress/completed/pending review where clocked. |
| `absentShifts` | int | Unexcused no-shows. |
| `lateArrivals` | int | Derived late count. |
| `earlyLeaves` | int | Derived early-leave count. |
| `overtimeShifts` | int | Derived overtime count. |
| `missingPunches` | int | Pending/missed-punch facts. |
| `implausibleRecords` | int | Data-quality flags. |
| `workedMinutes` | int | Sum. |
| `lateMinutes` | int | Sum. |
| `earlyLeaveMinutes` | int | Sum. |
| `overtimeMinutes` | int | Sum. |
| `showUpRate` | number | Stored from numerator/denominator for display only. |
| `punctualArrivalRate` | number | Stored from numerator/denominator for display only. |
| `taskOutcomeSummaryRef` | string? | Optional pointer, not fused score. |

#### `attendance_periods/{periodId}/shift_rows/{rowId}`

| Field | Type | Meaning |
| --- | --- | --- |
| `rowId` | string | `uid_day_shift` or deterministic equivalent. |
| `uid` | string | Employee id. |
| `branchId` | string | Branch. |
| `businessDate` | string | Assigned to scheduled shift start day in Africa/Cairo. |
| `shift` | string | Shift name/id. |
| `scheduledStartAt` | timestamp? | Snapshot. |
| `scheduledEndAt` | timestamp? | Snapshot, may cross midnight. |
| `attendanceRecordId` | string? | Raw record if present. |
| `status` | string | Existing attendance status value when row maps to a record, or reporting-row classification. |
| `expected` | bool | Whether this row counts as expected work. |
| `excludedReason` | string? | Leave/excused reason category. |
| `exceptionCodes` | array<string> | Derived flags such as `late`, `early_leave`, `missing_punch`, `implausible`. |
| `workedMinutes` | int | Calculator output. |
| `lateMinutes` | int | Calculator output. |
| `earlyLeaveMinutes` | int | Calculator output. |
| `overtimeMinutes` | int | Calculator output. |
| `breakMinutes` | int | Currently zero/dormant unless breaks return. |
| `payrollCandidateMinutes` | int | Worked minus unpaid policy if configured; otherwise equals worked with policy warning. |

### 8.8 Why rollups are necessary

Late, early leave, and overtime are derived facts. They are intentionally not statuses.

That decision is correct because it avoids status drift.

It also means Firestore cannot efficiently query "all late records in a year" by status without either:

- Recomputing on the client.
- Adding queryable derived fields.
- Adding rollup/report rows.

The recommended answer is rollup/report rows, not new statuses.

The raw record remains clean. The reporting row stores derived flags computed by the server close process for report and export use.

### 8.9 Trend design

Trends are allowed only when they change an operational decision.

| Trend | Buckets | Actionable because | Monochrome encoding |
| --- | --- | --- | --- |
| Show-up rate trend | Daily for current week, weekly for quarter, monthly for year | Reveals coverage reliability changes. | Thin line over baseline, direct label at end, dotted previous period. |
| Late minutes trend | Same as above | Shows severity, not just count. | Vertical bars with grey intensity and numeric top labels. |
| Overtime minutes trend | Weekly/monthly | Flags staffing or payroll exposure. | Stacked rule bars with threshold line. |
| Pending exceptions trend | Daily | Shows close workload. | Step line with open/closed markers. |
| Absence count trend | Weekly/monthly | Helps manager plan coverage. | Small multiples per branch/employee, no color ranking. |

Do not use purple, indigo, or a multi-color chart palette. Use:

- Stroke weight.
- Solid vs dashed lines.
- Grey ramp separation.
- Direct numeric labels.
- Threshold rules.
- Small multiples.
- Shape markers.

A trend is decorative if it has no threshold, no comparison, and no decision. Decorative trends should not ship.

### 8.10 Period lifecycle

| State | Owner | Entry criteria | Exit action | Mutability |
| --- | --- | --- | --- | --- |
| Open | System | Period started. | Close Function runs daily/period calculation. | Raw records can still change by allowed corrections. |
| Ready | System | Expected rows and rollups generated. | Manager resolves blockers or closes. | Report rows can be regenerated. |
| Exceptions resolved | Manager/admin | No blocking pending corrections/missing punches/implausible records. | Close period. | Raw rows still linked. |
| Locked | Manager/admin | Close checklist complete. | Request export or restatement. | Report version immutable. |
| Exported | Function | CSV/PDF generated and stored. | Restate if later correction changes facts. | File immutable. |
| Restated | Function/admin | Post-export correction or schedule fix accepted. | Generate version N+1. | Prior versions remain visible. |

### 8.11 Close checklist

The close screen should show:

- Period.
- Branch scope.
- Expected shifts.
- Missing/no-show rows.
- Pending corrections.
- Auto-closed sessions.
- Missing punches.
- Implausible records.
- Overtime needing approval, if policy says overtime requires approval.
- Unsigned schedule changes after close start.
- Export availability.

The CTA should not be "Export" until close readiness is true.

### 8.12 Report confidence

Each report should expose confidence:

| Confidence flag | Meaning |
| --- | --- |
| `verified_roster` | Expected shifts came from schedule snapshots and no source changed after close. |
| `best_effort_roster` | Backfilled from old schedule docs that might have been edited. |
| `open_records` | In-progress or pending-review rows still affect totals. |
| `post_close_correction` | Facts changed after lock and require restatement. |
| `break_policy_missing` | Payroll-ready minutes exclude unpaid-break handling because breaks are not active. |

## 9. Employee Performance At A Glance

### 9.1 What attendance can fairly say

Attendance can say:

- Whether the employee appeared for scheduled work.
- Whether they arrived within the configured grace rule.
- Whether they left before scheduled end.
- Whether they created overtime exposure.
- Whether records are missing, corrected, or implausible.
- Whether leave/excused days explain absence from the denominator.

Attendance cannot fairly say:

- Overall employee quality.
- Task productivity.
- Reason behind lateness without manager context.
- Whether overtime was valuable.
- Whether a low worked-minute day was employee fault.

### 9.2 Per-employee report

The per-employee report should be a profile inside a period:

| Section | Content | Decision |
| --- | --- | --- |
| Header | Name, branch, role, period, close/export state | Confirm scope. |
| Attendance reliability | Expected, present, absent, leave, excused, show-up rate | Verify baseline. |
| Time reliability | Punctual arrivals, late minutes, early leave, overtime | Identify coaching or staffing issue. |
| Exceptions | Missing punches, pending corrections, implausible records | Resolve facts. |
| Payroll candidate | Worked minutes, overtime minutes, break policy warning | Handoff prep. |
| Task outcomes adjacent | Approved, missed, cancelled, late completion | Broader operational context. |
| Evidence | Shift rows and record detail links | Audit. |

### 9.3 Tasks seam

`lib/features/task/domain/task_outcomes.dart` already defines fair reporting categories:

- Approved.
- Missed.
- Cancelled.
- Late.

It explicitly excludes cancelled tasks from scored denominator and defines completion rate as Approved / (Approved + Missed) in `lib/features/task/domain/task_outcomes.dart:83`.

Attendance reporting should borrow that principle:

- Excluded means excluded, not counted as failure.
- Denominators must be ungameable.
- Late facts are separate from completion/show-up facts.
- Do not collapse different operational truths into one score.

### 9.4 Recommendation on fusing task and attendance

Do not create one "Employee Performance Score".

Instead create an "Employee Operations Snapshot" with adjacent lanes:

| Lane | Metric family | Denominator |
| --- | --- | --- |
| Attendance reliability | Show-up, absence, punctual arrival | Schedule expected work shifts. |
| Work execution | Task outcome completion, missed tasks, late tasks | Assigned accountable tasks excluding cancelled. |
| Data quality | Corrections, missing punches, implausible records | Records requiring review. |

Reasons:

- One number hides which behavior needs action.
- Weighting attendance vs tasks is arbitrary.
- Composite scores are easier to game.
- Managers may misuse a rank as discipline without context.
- The repo already values ungameable denominators.

The at-a-glance design should use side-by-side facts, not ranking.

### 9.5 Misuse failure modes

| Failure mode | Mitigation |
| --- | --- |
| Manager punishes leave/excused days as absence. | Exclude leave/excused from denominator and show them separately. |
| Overtime treated as positive performance. | Show overtime as exposure requiring context, not achievement. |
| Late count hides severity. | Pair late count with late minutes. |
| Absence rate penalizes unscheduled people. | Denominator only rostered expected shifts. |
| Task completion rate inflated by cancellations. | Follow task outcomes: cancelled excluded, not counted as success. |
| Cross-employee leaderboard encourages gaming. | Do not ship leaderboard; use exception queue and profile reports. |

## 10. Information Architecture

### 10.1 Proposed route map

| Current route | Proposed fate | New role |
| --- | --- | --- |
| `/attendance` | Keep | Employee clock plus personal period truth. |
| `/admin/attendance` | Change | Attendance Reports hub for admin; branch workspace when scoped. |
| `/attendance/history` | Keep but demote | My ledger drill-down from personal report. |
| `/attendance/review` | Merge/redirect | Branch ledger drill-down behind report and exception queue. |
| `/attendance/record/:id` | Keep | Canonical record/audit detail. |

New proposed conceptual screens:

| Screen | Route concept | Roles | Purpose |
| --- | --- | --- | --- |
| Attendance Reports Hub | `/admin/attendance` | Admin, manager where scoped | Reports, branch risk, period status. |
| Branch Attendance Workspace | `/attendance/branch/:branchId` | Manager, admin | Daily close, exception queue, report drilldown. |
| Attendance Period Detail | `/attendance/period/:periodId` | Manager, admin, employee scoped rows | Closed/open report with rows and exports. |
| Employee Attendance Profile | `/attendance/employee/:uid` | Employee self, manager branch, admin | Person period report and evidence. |
| Attendance Exception Queue | `/attendance/exceptions` | Manager/admin | Work queue, not filter list. |
| Attendance Export Ledger | `/attendance/exports` | Admin/manager scoped | Download/audit report exports. |

This proposal can preserve old route names initially by redirecting:

- `/attendance/review` -> Branch Attendance Workspace with the ledger tab open.
- `/attendance/history` -> Employee Attendance Profile with the ledger tab open.

### 10.2 Role entry points

| Role | Desktop nav | Mobile nav | Dashboard integration |
| --- | --- | --- | --- |
| Admin | Sidebar Attendance -> Reports Hub | Home attention tile -> Reports Hub | Additive Admin Dashboard V2 attendance strip only. |
| Manager | Sidebar Attendance -> Branch Workspace | Manager home Attendance tile -> close workspace | Replace tile copy from history to close readiness. |
| Employee | Sidebar/top action Attendance -> Clock/Profile | Top action -> Clock/Profile | Personal period truth under clock. |

Owner-frozen surfaces:

- Admin Dashboard V2 stays frozen. Propose only an additive attention row/slot.
- Employee My Week schedule UI stays frozen. Propose only contextual links out, not redesign.
- `LiveStatusBorder` orbit motion stays frozen.

### 10.3 Kill or merge

| Surface | Action | Reason |
| --- | --- | --- |
| Branch history as a page title/destination | Kill | It is the wrong product center. |
| Status chip wall | Merge into filter drawer/saved views | Controls should not precede the manager's real queue. |
| Admin one-branch live board root | Merge into branch workspace | Admins need cross-branch report risk first. |
| Separate corrections tab in live board | Merge into exception queue | Corrections are one exception type, not a separate mental model. |

## 11. Manager / Admin Workflows

### 11.1 Daily manager loop

| Time | Manager question | Surface | Primary CTA |
| --- | --- | --- | --- |
| Start of shift | Who has not arrived yet? | Live board inside Branch Workspace | Contact/mark context, no export. |
| During shift | Who is working, late, or offsite? | Live board + exception strip | Review row. |
| End of shift | Who is missing clock-out or early leave? | Exception queue | Resolve/miss punch/excuse. |
| End of day | Can I close today? | Daily Close report | Close day. |
| Before payroll cutoff | Which periods still block export? | Reports Hub | Resolve queue or request restatement. |

### 11.2 Exception triage as queue

The current history filter model asks managers to construct the problem manually.

The queue should show the problem directly:

| Queue group | Sort | Action |
| --- | --- | --- |
| Missing/no record | Shift ended, no attendance row | Mark absent, excuse, create missed-punch correction. |
| Pending corrections | Oldest first, payroll-impacting first | Approve/reject with reason. |
| Auto-closed sessions | Oldest first | Set clock-out or mark pending review outcome. |
| Implausible records | Highest severity first | Confirm, correct, or annotate. |
| Overtime | Largest minutes first | Approve/export or flag for staffing review. |
| Unscheduled work | Date/time | Attach to schedule, approve, or exclude from payroll export. |

### 11.3 Bulk actions

Bulk actions should be limited to facts that can be decided consistently:

| Bulk action | Allowed? | Reason |
| --- | --- | --- |
| Mark selected no-shows absent | Yes after confirmation | Same factual outcome, server writes audit. |
| Excuse selected absences with one reason | Yes with mandatory reason | Existing direct-resolve model supports reasoned outcomes. |
| Approve selected corrections | No by default | Each correction may change payroll minutes differently. |
| Reject selected corrections | No by default | Requires per-request reason. |
| Close period | Yes only when blockers resolved | Period state change is the workflow goal. |
| Export period | Yes only from locked period | Export must be versioned/audited. |

### 11.4 Admin workflow

Admin is branchless and global. Reports must not assume `user.branchId`.

Current UI bootstraps branch review by choosing a branch when no initial branch is present in `lib/features/attendance/presentation/history/attendance_history_screen.dart:90`.

For reporting, that is not enough.

Admin report scope must be explicit:

- Single branch.
- Multiple selected branches.
- All branches.

Firestore rules and Functions must validate the scope, not infer it from admin profile branch.

### 11.5 Notifications

Send notifications for:

| Event | Recipient | Why |
| --- | --- | --- |
| Period ready to close | Branch manager/admin | Required action. |
| Exceptions unresolved before cutoff | Branch manager/admin | Prevent payroll/export failure. |
| Correction approved/rejected | Requester | Existing useful flow. |
| Auto-close created pending review | Manager/admin | Existing useful flow. |
| Export ready or failed | Requester | File lifecycle. |
| Restatement required | Last exporter/manager/admin | Closed/exported facts changed. |

Do not send notifications for:

- "Your punctuality trend changed."
- Employee ranking changes.
- Manager daily digest if no action is needed.
- Decorative analytics milestones.

## 12. Employee Experience

### 12.1 Keep the clock simple

The employee clock should remain action-first:

- Current shift.
- Clock-in/clock-out eligibility.
- GPS status when relevant.
- Current worked time.
- One correction path.

The implementation already resolves schedule context and validation in the employee cubit in `lib/features/attendance/presentation/cubit/attendance_cubit.dart:211`.

### 12.2 Add personal truth

Below or beside the clock, the employee needs a period view:

| Question | UI answer |
| --- | --- |
| What does the system think I worked this month? | Worked minutes and shift rows for the current pay/month period. |
| Do I have any pending corrections? | Prominent pending row with status. |
| Are any days marked absent? | Exception row with request correction action. |
| Did leave/excused days count against me? | Separate excluded counts. |
| What will payroll receive? | Payroll candidate rows once period is locked/exported. |

### 12.3 Missed-punch path

The action sheet already supports missed punch and correction flows in `lib/features/attendance/presentation/widgets/attendance_action_sheet.dart:15`.

The redesign should make the path more contextual:

- From personal period row.
- From absent day.
- From pendingReview row.
- From record detail.

Do not make employees hunt through a general history list first.

### 12.4 Employee export visibility

Employees do not need payroll export authority.

They do need to see:

- Their locked period facts.
- Exported/restated badge if their row changed.
- Correction history.
- Manager decision reason.

This reduces manager support load before payroll.

## 13. Exceptions Model

### 13.1 Exception table

| Exception | Detection today | Actionable? | Actor | Closes when | Report/export treatment |
| --- | --- | --- | --- | --- | --- |
| Late | `lateMinutes > 0` from calculator | Usually informational; may require coaching | Manager | Record confirmed or corrected | Count and minutes; not status. |
| Absent | Virtual board if no record after shift end; materialized only by action | Yes | Manager/admin | Mark absent, excuse, or approve missed punch | Must be durable in report rows. |
| Leave | Schedule leave via roster | Usually no | Manager/admin from Schedule | Schedule/leave state accepted | Excluded denominator, counted separately. |
| Excused | Manager direct-resolve with reason | Yes until reason saved | Manager/admin | Excused record materialized | Excluded denominator, reason in export. |
| Overtime | `overtimeMinutes > 0` from calculator | Yes if payroll policy requires approval | Manager/admin | Approved/confirmed or corrected | Minutes and flag; not achievement. |
| Early leave | `earlyLeaveMinutes > 0` from calculator | Often yes | Manager/admin | Confirm/correct/excuse | Count/minutes and exception code. |
| Missing punch | Missing clock-in/out or pendingReview/auto-close | Yes | Employee requests, manager decides | Correction applied/rejected | Blocks close until resolved. |
| Unscheduled work | Record has no scheduled window | Yes | Manager/admin | Attach/approve/exclude | Separate export flag; does not inflate denominator. |
| Implausible record | Not implemented | Yes | Manager/admin | Confirm/correct/annotate | Blocks close if severe; flag in export. |

### 13.2 Derived facts stay derived

Late, early leave, and overtime should not be persisted as attendance statuses.

The persisted status enum should remain small.

Report rows may store `exceptionCodes` as derived facts computed at close. That is not the same as adding statuses.

### 13.3 Overnight shifts

Overnight shifts are real.

`ShiftHours` allows `endMinutes > 1440` in `lib/features/schedule/domain/shift_hours.dart:4`.

`ShiftWindow` converts that into instants in `lib/features/schedule/domain/shift_window.dart:9`.

Reporting rule:

- Assign an overnight shift to the business date of scheduled shift start in `Africa/Cairo`.
- Store both timestamps.
- Do not split one shift across two report dates unless payroll policy later requires a separate overtime/pay split.
- Weekly/monthly/pay-period reports include the shift in the period containing the scheduled start business date.

This rule must be stated in every export.

### 13.4 Grace/tolerance rule

Late grace already exists as configuration and is applied by the calculator in `lib/features/attendance/domain/attendance_calculator.dart:87`.

ADR-013 is the precedent: tolerance rules must be fixed enough to avoid gaming.

Recommendation:

- Keep grace configurable only through AttendanceConfig/branch policy if product accepts it.
- Store the grace value used in report metadata.
- Never hide raw clock-in time behind grace.
- Show "late after 5m grace" when explaining a row.

## 14. History And Search, Demoted

### 14.1 What survives

History remains valuable as:

- Evidence table behind reports.
- Employee self-ledger.
- Record drill-down entry.
- Audit search.
- Exception investigation tool.

It should not be the main manager product.

### 14.2 Replace the 16-filter stack

Current filters are implemented as three chip rows in `lib/features/attendance/presentation/history/widgets/attendance_history_filters.dart:46`.

Proposed desktop replacement:

| Area | Control |
| --- | --- |
| Report period bar | Branch, period type, period date, close/export state. |
| Saved views | All rows, Open exceptions, Payroll blockers, Overtime, Corrections. |
| Search | Employee/name/id global within period. |
| Table headers | Sortable Date, Employee, Shift, Status, Worked, Exceptions, Review state. |
| Filter drawer | Advanced status/source/shift/date filters. |
| Detail panel | Selected row audit details. |

Proposed mobile replacement:

- Period selector at top.
- Saved view segmented control.
- Search icon opens full-screen search.
- Row list grouped by exception priority.
- Filters in bottom sheet.
- Detail screen remains full page.

### 14.3 Desktop table columns

| Column | Reason |
| --- | --- |
| Date | Period evidence. |
| Employee | Manager scan. |
| Shift | Morning/night/overnight context. |
| Scheduled | Denominator evidence. |
| Actual | Clock-in/out evidence. |
| Worked | Payroll candidate. |
| Exceptions | Immediate triage. |
| Source | Self/manual/system. |
| Review | Pending/confirmed/exported/restated. |
| Actions | Resolve/details. |

Cards can survive on mobile. Desktop should use a data table and side panel.

## 15. Export: PDF And CSV

### 15.1 What "payroll-ready" means

OpsHub should not become a payroll processor.

Payroll-ready means:

- The export is a stable data contract.
- Every row has a source record or expected-shift row.
- Timezone and business date are explicit.
- Minutes are integer values from the attendance calculator.
- Leave/excused exclusions are explicit.
- Corrections/restatements are versioned.
- The file is auditable: who requested it, when, scope, period, version.

OpsHub responsibility ends at handing off a reconciled attendance ledger. Pay rates, deductions, tax, payroll approval, and payout remain outside OpsHub.

### 15.2 CSV schema

| Column | Type | Rule |
| --- | --- | --- |
| `period_id` | string | Report period id. |
| `period_version` | int | Version exported. |
| `export_id` | string | Export request id. |
| `scope_kind` | string | `branch` or `multiBranch`. |
| `branch_id` | string | Row branch id. |
| `branch_name` | string | Snapshot. |
| `employee_uid` | string | UID. |
| `employee_name` | string | Snapshot at export. |
| `business_date` | date string | `yyyy-MM-dd` in Africa/Cairo. |
| `shift` | string | Shift id/name. |
| `overnight` | bool | True if scheduled end crosses midnight. |
| `scheduled_start_at` | ISO timestamp | UTC timestamp plus timezone column. |
| `scheduled_end_at` | ISO timestamp | UTC timestamp plus timezone column. |
| `clock_in_at` | ISO timestamp? | Null for no-show/leave. |
| `clock_out_at` | ISO timestamp? | Null if missing/pending. |
| `timezone` | string | `Africa/Cairo`. |
| `status` | string | Existing attendance status value where applicable. |
| `expected_shift` | bool | Counts in expected denominator. |
| `excluded_from_show_up_rate` | bool | Leave/excused true. |
| `excluded_reason` | string? | Leave type or excused reason category. |
| `source` | string | Existing attendance source. |
| `worked_minutes` | int | Calculator output. |
| `break_minutes` | int | Dormant/zero unless breaks return. |
| `paid_candidate_minutes` | int | Worked minus unpaid break policy if configured. |
| `late_minutes` | int | Calculator output. |
| `early_leave_minutes` | int | Calculator output. |
| `overtime_minutes` | int | Calculator output. |
| `exception_codes` | string | Pipe-delimited stable labels. |
| `pending_review` | bool | Blocks payroll finality. |
| `correction_ids` | string | Pipe-delimited. |
| `gps_in_verified` | bool? | From verification snapshot. |
| `gps_in_distance_m` | int? | Rounded meters. |
| `gps_out_verified` | bool? | From verification snapshot. |
| `gps_out_distance_m` | int? | Rounded meters. |
| `attendance_record_id` | string? | Raw record id. |
| `report_row_id` | string | Durable row id. |
| `restatement_of` | string? | Prior period/export id if applicable. |

Rounding:

- Store and export whole minutes.
- Do not round to payroll increments.
- Payroll system owns rounding to 5/10/15 minute increments if required.

Breaks:

- Break support was removed for MVP, though a dormant break model remains in `lib/features/attendance/domain/attendance_break.dart:1`.
- Exports must include `break_minutes`.
- Until break UX/policy is implemented, exports must identify whether paid minutes are raw worked minutes or policy-adjusted.

### 15.3 PDF report layout

PDF period report:

1. Header: scope, period, timezone, version, status, generated by/at.
2. Close summary: expected shifts, present, absent, leave, excused, blockers.
3. Metric strip: show-up, punctual arrival, worked, overtime, exceptions.
4. Trend panel: current period vs prior period.
5. Exception queue summary.
6. Employee table.
7. Export/restatement log.
8. Footer: "OpsHub attendance ledger, not payroll calculation."

The PDF should be readable in monochrome and printable. No color legend should be required to understand it.

### 15.4 Generation and storage

Recommended:

- CSV generated by Cloud Function.
- PDF generated by Cloud Function if adopted, or app-side as a first visual export.
- Files stored in Firebase Storage.
- Export request document stored in Firestore.
- Audit event records requester, scope, period, version, file hash, createdAt, completedAt, failure.

Why server-side for CSV:

- Payroll-relevant data must not be client-authored.
- Client locale/timezone bugs can alter export interpretation.
- Admin/manager scope must be enforced once.

Package/platform cost:

| Option | Package | Platforms | Pros | Cons |
| --- | --- | --- | --- | --- |
| App-side visual PNG | Existing `RepaintBoundary.toImage` pattern | iOS, Android, macOS | No new dependency; matches Schedule Final View pattern in `lib/features/schedule/presentation/pages/schedule_final_view.dart:103`. | Not payroll CSV/PDF; client-generated. |
| Flutter PDF | `pdf` plus possibly `printing` | iOS, Android, macOS | Common Flutter route for PDF output. | New package; client-generated unless mirrored server-side. |
| Node PDF Function | e.g. `pdfkit` | Firebase Functions | Server-owned artifact. | New Node dependency and function complexity. |
| CSV only first | No new package | All platforms via download link | Satisfies payroll data contract earliest. | Owner asked PDF too; PDF deferred. |

Recommendation:

- P0/P1: server CSV.
- P2: PDF period summary.
- Optional app-side PNG snapshot only for shareable visual report preview, reusing Schedule's pattern.

## 16. Premium UI Direction

### 16.1 Design system constraints

Use existing design language:

- `PageHero` for report headers.
- `AttentionTile` for urgent operational counts.
- `StatStrip` for compact metrics, but adjust Attendance metric naming.
- `ActivityCard` for recent export/restatement events.
- `GlassContainer` where existing shells use it.

Evidence:

- `PageHero` is responsive in `lib/core/widgets/page_hero.dart:118`.
- `AttentionTile` is an operations triage primitive in `lib/core/widgets/attention_tile.dart:9`.
- `StatStrip` supports responsive wrapping in `lib/core/widgets/stat_strip.dart:68`.
- `ActivityCard` is a reusable feed row in `lib/core/widgets/activity_card.dart:7`.

Monochrome rules:

- White/greys only as dominant palette.
- Semantic color only for destructive/real state.
- Trends use shape, weight, labels, and baselines.
- No purple/indigo chart palette.
- Premium comes from hierarchy and density, not decorative gradients.

### 16.2 Desktop reports hub wireframe

```text
Attendance Reports
Branch / All branches      Pay period: Jul 1-31, 2026      [Generate close] [Export]

+--------------------------------------------------------------------------+
| Payroll readiness                                                        |
|  3 branches ready   1 branch blocked   14 open exceptions   cutoff 2d    |
+----------------------+----------------------+----------------------------+
| Show-up rate         | Punctual arrivals    | Overtime exposure          |
| 93%  56/60 expected  | 81%  42/52 arrivals  | 18h  +4h vs last period    |
+----------------------+----------------------+----------------------------+

+---------------------------------------------+----------------------------+
| Branch periods                              | Close checklist             |
| Branch     Status    Blockers   Show-up     | [ ] Pending corrections 5   |
| Cairo A    Blocked   7          91%         | [ ] Missing punches 2       |
| Cairo B    Ready     0          96%         | [ ] Implausible records 1   |
| Giza       Ready     0          94%         | [ ] Overtime review 4       |
|                                             | Export available after close |
+---------------------------------------------+----------------------------+

+--------------------------------------------------------------------------+
| Trend: show-up and exceptions over closed weeks                           |
| small multiples, direct labels, dashed prior period                        |
+--------------------------------------------------------------------------+
```

### 16.3 Branch workspace wireframe

```text
Branch Attendance - Cairo A
Today: Thu Jul 30, 2026      Shift: All      [Close today]

+-------------------+-------------------+-------------------+----------------+
| Missing now       | Pending review    | Late arrivals     | Overtime       |
| 2                 | 5                 | 9                 | 3              |
+-------------------+-------------------+-------------------+----------------+

+-----------------------------------------------+--------------------------+
| Exception queue                               | Live board               |
| Type       Employee     Shift    Action       | Working 18  Late 3       |
| No-show    Dina         Morning  Resolve      | Missing 2  Leave 1       |
| Missing    Omar         Night    Review       |                          |
| Implaus.   Ali          Morning  Inspect      |                          |
+-----------------------------------------------+--------------------------+

+--------------------------------------------------------------------------+
| Period rows table: Date Employee Shift Scheduled Actual Worked Exceptions |
+--------------------------------------------------------------------------+
```

### 16.4 Employee mobile wireframe

```text
My Attendance
Today
[Clock in / Clock out]
GPS verified / shift window / live worked time

This pay period
Expected 18   Present 16   Pending 1   Absent 1
Worked 124h   Overtime 3h

Needs attention
Jul 22 Missing clock-out   [Request correction]
Jul 26 Absent              [Dispute]

Rows
Jul 30 Morning  In progress
Jul 29 Morning  Completed  8h
```

### 16.5 Mobile form of desktop layouts

| Desktop element | Mobile form |
| --- | --- |
| Left table + right checklist | Stacked: attention, checklist, saved view list. |
| Branch comparison table | Branch cards with status and blocker count. |
| Trend small multiples | One trend at a time with segmented selector. |
| Filter drawer | Bottom sheet. |
| Detail side panel | Full details route. |
| Export ledger table | Grouped list by period. |

### 16.6 New primitive justified

Add one new primitive only if implementation proceeds:

`ReportPeriodHeader`

Purpose:

- Scope selector.
- Period selector.
- Status badge.
- Close/export CTA.
- Version/restatement marker.

Why justified:

- This header appears on hub, branch workspace, period detail, employee profile, and exports.
- It prevents every screen from reinventing period state.
- It encodes reporting lifecycle as UI hierarchy.

Do not add a chart library until the concrete trend designs cannot be built with CustomPaint/basic Flutter primitives.

## 17. Data Model And Backend Implications

### 17.1 Additive model

Do not mutate frozen enum values.

Add reporting collections:

- `attendance_periods/{periodId}`.
- `attendance_periods/{periodId}/employee_rows/{uid}`.
- `attendance_periods/{periodId}/shift_rows/{rowId}`.
- `attendance_exports/{exportId}` or subcollection under period.
- Optional `attendance_daily_rollups/{branchId}_{businessDate}` for cheap hub loading.

### 17.2 Cloud Functions

| Function | Trigger | Responsibility |
| --- | --- | --- |
| `closeAttendanceDay` | Scheduled or callable by manager/admin | Materialize expected rows, no-shows, daily rollup. |
| `rollupAttendancePeriod` | Scheduled/callable | Weekly/monthly/pay-period rollups from daily rows. |
| `lockAttendancePeriod` | Callable | Validate blockers resolved, lock version. |
| `exportAttendancePeriod` | Callable | Generate CSV/PDF, write Storage file and export doc. |
| `onAttendanceReportSourceChanged` | Firestore trigger | Mark open periods dirty or create restatement requirement. |
| `backfillAttendancePeriods` | Admin-only callable/manual | Best-effort backfill existing records/schedules. |

Existing functions already handle audit, correction application, and auto-close in `functions/index.js:3450`, `functions/index.js:3550`, and `functions/index.js:3686`.

### 17.3 Rules

Rules must enforce:

- Employee reads own period rows.
- Manager reads/writes close actions only for own branch.
- Admin reads/writes all scoped reports.
- Export requests require close/lock authority.
- No client writes report totals.
- No self-approval remains true for corrections.

Current attendance rules already enforce owner/manager/admin read/write scope in `firestore.rules:806`.

New reporting rules must be at least as strict because exports are payroll-adjacent.

### 17.4 Indexes

Likely indexes:

| Collection | Query |
| --- | --- |
| `attendance_periods` | `scopeKind`, `branchIds` array, `periodType`, `startDate`, `status`. |
| `employee_rows` collection group | `uid`, `periodType`, `startDate`. |
| `shift_rows` collection group | `branchId`, `businessDate`, `exceptionCodes`. |
| `attendance_exports` | `periodId`, `requestedBy`, `createdAt`. |
| Existing attendance | Branch/day range remains for evidence and backfill. |

### 17.5 Migration/backfill

Backfill plan:

| Data | Backfill quality |
| --- | --- |
| Existing completed/inProgress/pending records | High for minutes and statuses. |
| Late/early/overtime | High if scheduled snapshots exist on records. |
| No-show absences | Medium/low unless historical schedules are trustworthy. |
| Leave/onLeave | Medium if schedule leave data remains accurate. |
| Excused rows | High where materialized. |
| Breaks | Not available; mark policy gap. |

Backfilled reports must carry confidence:

- `verified_roster` when schedule snapshot is reliable.
- `best_effort_roster` when historical schedule could have changed.
- `missing_roster` when expected denominator cannot be reconstructed.

### 17.6 Schedule dependency

Schedule is the denominator.

Schedule gives:

- Assigned employees.
- Shifts.
- Leave.
- Day notes.
- Shift hours, including overnight.

Evidence:

- Weekly schedule stores assignments, day notes, leave, shift hours, and shift plan in `lib/features/schedule/domain/entities/weekly_schedule_entity.dart:31`.
- `hoursFor` resolves configured/frozen/default shift hours in `lib/features/schedule/domain/entities/weekly_schedule_entity.dart:110`.
- Schedule rules currently allow branch-reachable create/update/delete in `firestore.rules:427`.

Reporting requirement:

- Closed report periods must freeze expected-shift rows.
- Schedule edits after close must create restatement or be blocked for closed periods.
- The report should record source schedule ids.

### 17.7 Requests/corrections dependency

Corrections alter payroll-relevant facts.

Existing correction rules:

- One open correction at a time in validation.
- No self-approval in rules/functions.
- Approved correction is applied server-side.

Evidence:

- One-open correction validation is in `lib/features/attendance/domain/attendance_validation.dart:186`.
- No self-approval is described and enforced around correction rules in `firestore.rules:852`.
- Approved corrections are applied in `functions/index.js:3498`.

Reporting rule:

- Correction before lock updates open/ready period.
- Correction after lock creates a restatement requirement.
- Correction after export creates report version N+1 and keeps old export immutable.

### 17.8 Deployment risk

All server-side reporting proposals inherit current deployment risk.

The repo state says Attendance still awaits Firebase deploy for functions, rules, and indexes. Current functions include audit and auto-close, but code existence is not production availability.

This makes reporting a high-risk backend phase until:

- Functions deploy.
- Rules deploy.
- Indexes deploy.
- Real-device GPS QA completes.
- Function parity is confirmed in production.

## 18. Phased Plan

### 18.1 P0 - Make reports truthful

| Item | Type | Risk | Scope | Value |
| --- | --- | --- | --- | --- |
| Define report denominator contract | Feature | MED | Product/domain docs and domain code later | Stops ambiguous metrics. |
| Materialize expected/no-show facts at close | Bug | HIGH | Functions/rules/data | Fixes Rate/absence foundation. |
| Add period state model | Feature | HIGH | Firestore/Functions/UI later | Enables close/export. |
| Rename visible `Rate` to `Show-up rate` | Polish | LOW | Presentation-only later | Immediate clarity. |
| Add denominator disclosure to metrics | Polish | LOW | Presentation-only later | Reduces misuse. |

Independently valuable because even before full redesign, the numbers stop lying.

### 18.2 P1 - Manager close workspace

| Item | Type | Risk | Scope | Value |
| --- | --- | --- | --- | --- |
| Replace branch review destination with close workspace | Feature | MED | Presentation/domain | Makes manager workflow action-first. |
| Exception queue | Feature | MED | Domain/UI, maybe rollup flags | Turns filters into work. |
| Implausible-record flag | Feature | MED | Pure domain + Function later | Catches data-quality incidents. |
| Desktop table + side panel | Polish | MED | Presentation | Makes macOS usable. |
| Mobile saved views | Polish | LOW | Presentation | Keeps filters manageable. |

### 18.3 P2 - Period reports and trends

| Item | Type | Risk | Scope | Value |
| --- | --- | --- | --- | --- |
| Weekly/monthly/pay-period report screens | Feature | MED | UI/rollups | Delivers owner reporting ask. |
| Monochrome trend visuals | Feature | MED | UI/domain rollups | Shows change without violating design system. |
| Employee profile report | Feature | MED | UI/rollups | Makes performance at a glance fair. |
| Dashboard/Branch Ops widgets | Feature | LOW/MED | Additive UI | Integrates Attendance outside silo. |

### 18.4 P3 - Export

| Item | Type | Risk | Scope | Value |
| --- | --- | --- | --- | --- |
| Server CSV export | Feature | HIGH | Function/Storage/rules | Payroll-ready data contract. |
| Export ledger | Feature | MED | Firestore/UI | Auditability. |
| PDF summary | Feature | MED/HIGH | Package or server generator | Owner-facing report artifact. |
| Restatement workflow | Feature | HIGH | Functions/UI/rules | Real business correctness. |

### 18.5 P4 - Backfill and hardening

| Item | Type | Risk | Scope | Value |
| --- | --- | --- | --- | --- |
| Historical backfill | Feature | HIGH | Admin tooling/Functions | Makes older reports useful. |
| Schedule period lock integration | Feature | HIGH | Schedule + Attendance | Protects denominators. |
| Policy configuration | Feature | MED | Config/domain/UI | Breaks/overtime/pay period. |
| Production observability for reporting Functions | Feature | MED | Functions/admin | Prevents silent export failure. |

### 18.6 Presentation-only vs engine-touching

| Cheap/safe presentation-only | Engine-touching |
| --- | --- |
| Rename metric labels. | Materialize no-shows. |
| Add denominator text where known. | Add period rows/rollups. |
| Replace chip layout with filter drawer/table. | Add close/export Functions. |
| Add dashboard link/attention tile. | Add rules/indexes/Storage export. |
| Improve record card implausible messaging once flag exists. | Add schedule lock/restatement. |

Do not build P2/P3 UI on the current denominator. It will create false confidence.

## 19. Explicitly Out Of Scope / Recommended Against

| Request or tempting idea | Recommendation | Alternative |
| --- | --- | --- |
| Composite employee performance score | Do not build. | Side-by-side Attendance Reliability, Task Outcomes, Data Quality lanes. |
| Employee leaderboard | Do not build. | Manager exception queue and per-employee profile. |
| Persist late/early/overtime as statuses | Do not build. | Store derived report flags/counts in rollup rows. |
| Payroll processor | Do not build. | Payroll-ready ledger export contract. |
| New backend platform | Do not build. | Firebase Functions, Firestore, Storage. |
| Decorative heatmaps | Do not build. | Actionable monochrome trends with thresholds. |
| Full enterprise HR suite | Do not build. | Close, exception resolution, reports, export. |
| Client-generated payroll CSV | Do not build. | Server-generated CSV export. |
| Silent mutation of exported periods | Do not build. | Versioned restatement. |

## 20. Appendix A - Draft ADR-017

### ADR-017: Attendance Operational Reporting Ledger

Date: 2026-07-30

Status: Proposed

### Context

Attendance was originally scoped as a lean clock-in/clock-out and operational dashboard feature.

ADR-009 rejects a general analytics pipeline and requires every new metric to name the decision it changes.

ADR-010 prefers lean product scope over enterprise-shaped reporting.

The locked Attendance spec section 8 frames the dashboard as operational, not analytics, and postpones performance reports, payroll export, CSV/PDF export, and trends.

The product owner has now explicitly reframed Attendance as an operational reporting system:

- Reports are the product.
- History is a drill-down.
- Managers need dashboards, weekly/monthly reports, trends, exports, and employee performance at a glance.
- Attendance must connect to Schedule, Tasks, Requests, Branch Operations, and role dashboards.

The existing implementation already contains several ledger-grade foundations:

- Server-authoritative writes under ADR-005.
- Deterministic attendance ids.
- A single attendance calculator.
- Correction approval objects.
- Audit events.
- Schedule shift-hour snapshots.

But it does not contain a durable reporting denominator for no-shows because lazy absence may produce no Firestore attendance document.

### Decision

Attendance is approved as an operational reporting ledger.

This carves out a narrow exception to ADR-009 and ADR-010 for attendance facts that:

- Are derived from Schedule obligations, attendance records, correction decisions, or server close/export events.
- Feed branch close, payroll handoff, staffing coverage, or exception resolution.
- Have an explicit denominator.
- Are reproducible from durable report rows or source records.
- Are computed server-side when they affect payroll/export.
- Preserve the small persisted attendance status enum.

Attendance reporting may include:

- Daily close reports.
- Weekly reports.
- Monthly reports.
- Pay-period reports.
- Per-employee period reports.
- Per-branch reports.
- Exception queues.
- Monochrome trends over closed periods.
- PDF/CSV exports.
- Export audit logs.
- Restatements.

Attendance reporting may not include:

- A general analytics pipeline.
- Composite employee scores.
- Public leaderboards.
- Vanity heatmaps.
- Client-authored payroll totals.
- New backend platforms outside Firebase.

### Changes to ADR-009

ADR-009 remains active.

Attendance is an allowed exception because it is a ledger of payroll-adjacent operational facts, not a vanity metric surface.

Every attendance metric must name:

- Formula.
- Denominator.
- Decision changed.
- Computation owner.
- Gameability analysis.

Metrics that fail this bar do not ship.

### Changes to ADR-010

ADR-010 remains active.

The attendance scope is allowed to grow only to:

- Close readiness.
- Exception resolution.
- Period reports.
- Payroll handoff exports.
- Restatement/audit.

The system must not grow into HR performance management, payroll processing, or enterprise analytics.

### Changes to ATTENDANCE_SPEC section 8

Section 8 should be amended from "Operational Dashboard (not analytics)" to "Operational Reporting Ledger".

The dashboard remains operational, but reports become the primary attendance product surface.

History becomes a drill-down/evidence surface.

### Consequences

Positive:

- Attendance can satisfy the owner's reporting request without ambiguity.
- Payroll-adjacent data becomes reproducible and auditable.
- Managers receive close workflows instead of filter-heavy history browsing.
- The existing calculator/correction/audit architecture remains useful.

Negative:

- New Functions, rules, indexes, and Storage export flow are required.
- Existing deploy backlog becomes more important.
- Schedule immutability/locking becomes a reporting dependency.
- Backfill quality will vary depending on historical schedule trust.

### Alternatives considered

1. Keep Attendance as clock/history only.

Rejected because it ignores the owner's amended requirement.

2. Build client-side reports over existing records.

Rejected because lazy absences break the denominator and client aggregation does not meet payroll auditability.

3. Build a general analytics pipeline.

Rejected because it violates ADR-009/010 beyond the narrow attendance ledger need.

4. Create employee scores.

Rejected because composite scores are gameable, context-poor, and not needed to answer operational reporting questions.

## 21. Appendix B - Open Questions For The Owner

| Question | Recommendation | Why it matters |
| --- | --- | --- |
| What is the official pay period? | Start with calendar month plus configurable pay-period later. | Export periods and close deadlines depend on it. |
| Should report week follow Schedule's Sunday week or ISO Monday week? | Use Schedule week for branch operations; label explicitly. | Current history and schedule disagree. |
| Are past schedules allowed to change after close? | No; changes after close should create restatement. | Denominator trust depends on it. |
| Does overtime require manager approval before payroll export? | Yes, treat overtime as export blocker until confirmed. | Overtime affects money. |
| Are unpaid breaks required? | Decide before calling export final payroll-ready. | Break UX is removed; payroll minutes may be overstated if unpaid breaks exist. |
| Should managers see cross-employee comparisons? | Only within branch report tables, not rankings. | Supports operations without leaderboard misuse. |
| Can managers export their branch, or only admins? | Managers can export own branch closed periods; admins can export any explicit scope. | Matches branch scope model. |
| How long should exports be retained? | Keep immutable export metadata indefinitely; file retention per business/legal policy. | Audit and storage costs. |
| Should employees receive a period-ready notification? | Only if they have unresolved personal exceptions. | Avoid noisy trend/performance notifications. |
| How should implausible records be defined? | Start conservative: very short worked time on substantial scheduled shift, impossible order, missing strict GPS when required. | Avoid false accusations. |
