# Branch Monthly Sales Target — design spec

Each branch has a **monthly sales target** in EGP. An employee submits the branch's
sales at the end of a working day; a manager approves or rejects it; **only approved
sales count** toward the branch's monthly progress. Remaining, progress %, and
forecast are **derived on read — never stored**.

> **Status: designed, not yet built.** This is the locked design for a planned
> feature; no `lib/features/sales/` code exists yet. Read
> **[ADR-022](../decisions/ADR-022-branch-sales-monthly-ledger.md) before changing
> anything here** — the ledger shape, the derive-don't-store rule, and the
> server-authoritative boundary are settled there. When the feature is built, its
> live collections move into [DATA_MODEL.md](DATA_MODEL.md) and this doc becomes the
> behaviour reference (the shape of Requests/Attendance docs).

## Rules of the shape

| | |
| --- | --- |
| **Money** | Signed integer **piastres** (`amountPiastres`). Never `double`/decimal. `>= 0`; **zero is a valid, explicitly-submitted "no sales" day**; negative forbidden |
| **Target owner** | The **branch**, per accounting **month** — not an employee, not the mutable branch doc |
| **Submission statuses** | `pending → approved \| rejected \| correctionRequested`. A `correctionRequested` doc, once resubmitted, returns to `pending`. A manager/admin edit of an already-`approved` amount stays `approved` and bumps `revision`. Admin reopen returns any terminal record to `pending` |
| **Submit** | Any **active branch employee**. **One document per branch business day** — first valid submission wins (deterministic id); a second attempt opens the existing record, never overwrites it |
| **Decide** | Own-branch **manager**, or **admin** (global). Approve / reject / request correction |
| **Correct** | Manager/admin only, server-authoritative, **mandatory reason** — an approved amount can be edited; a terminal record can be reopened |
| **Target** | Set/changed by own-branch manager or admin, **mandatory reason**, audited. A target **must exist before an employee can submit** |
| **Accumulation** | **Never stored.** Approved total is always re-summed from the month's approved submissions |
| **Time** | All month/date keys are **`Africa/Cairo`** business civil days ([ADR-015](../decisions/ADR-015-automation-business-timezone.md)) |

**Self-approval is guarded, not structurally impossible.** Unlike
[Requests](REQUESTS.md), the callable rejects when the actor uid equals the submitter
uid — do not remove it assuming Requests' structural argument transfers. It does not.

No stored running total. No rollup table. No analytics pipeline. No scoreboard. No
export. All deliberate — this feature stays **inside** ADR-009/010 (see ADR-022).

## Structure

Two top-level collections, deterministically keyed (add both names to
`core/constants/app_constants.dart`):

```
branch_sales_months/{branchId}_{yyyyMM}        ← the target for one branch-month
branch_sales_submissions/{branchId}_{yyyyMMdd} ← one daily close per branch business day
```

### `branch_sales_months/{branchId}_{yyyyMM}`

| Field | Type | Notes |
| --- | --- | --- |
| `id` `branchId` `monthKey` | string | deterministic id · `yyyyMM` |
| `timeZone` | string | always `Africa/Cairo` — pins interpretation |
| `targetPiastres` | int | source of truth |
| `targetRevision` | int | increments on each target edit (optimistic-concurrency token) |
| `createdAt` `updatedAt` | server `Timestamp` | |
| `createdBy{Id,Name,Role}` `updatedBy{Id,Name,Role}` | provenance | |
| `lastChangeReason` | string | mandatory on edit |
| `schemaVersion` | int | additive migrations |

**Not stored:** achieved / remaining / percentage / forecast / pending count / branch
name. Branch name is a display join via `BranchRepository`.

### `branch_sales_submissions/{branchId}_{yyyyMMdd}`

| Field | Type | Notes |
| --- | --- | --- |
| `id` `branchId` `monthKey` `businessDateKey` | string | deterministic id · `yyyyMM` · `yyyyMMdd` |
| `businessTimeZone` | string | `Africa/Cairo` |
| `amountPiastres` | int | `>= 0` |
| `status` | enum | `pending \| approved \| rejected \| correctionRequested` |
| `revision` `approvedRevision` | int · int? | content revision · which revision was approved |
| `submittedBy{Id,Name}` `submittedAt` | provenance | |
| `lastEditedBy{Id,Name}` `lastEditedAt` | nullable | |
| `decisionBy{Id,Name,Role}` `decisionAt` | nullable | who decided |
| `decisionReason` | string? | **mandatory** for reject / correction / reopen |
| `createdAt` `updatedAt` `schemaVersion` | | |

**Unknown/missing `status` maps to a non-approving read state — never to `approved`.**
No embedded totals, no timeline array; `audit_logs` is the immutable history.

### Indexes (`firestore.indexes.json`)

- `branch_sales_submissions`: `branchId ASC, monthKey ASC, status ASC, businessDateKey DESC`
- `branch_sales_submissions`: `branchId ASC, monthKey ASC, businessDateKey DESC`
- (only if employee history spans beyond current branch-month)
  `submittedById ASC, monthKey ASC, businessDateKey DESC`

Managers query their own `branchId`; admins run one bounded branch-month query per
known branch. **No global materialized rollup** — DROP's branch set is small.

## Server-authoritative boundary ([ADR-005](../decisions/ADR-005-server-authoritative-writes.md))

| Write | Who |
| --- | --- |
| Create initial `pending` submission | **Client** — own branch, own uid, `pending`, deterministic id, no decision fields, no overwrite. `NetworkGuard.ensureWritable()` first |
| `setBranchSalesTarget` | **Callable** — creates month record if absent, else bumps `targetRevision` (expects prior revision) |
| `decideDailySalesSubmission` (`approve\|reject\|requestCorrection\|reopen`) | **Callable** — transaction on the submission |
| `editApprovedDailySalesSubmission` | **Callable** — edits approved amount, bumps `revision` |

Each callable: authenticate → read caller's `users/{uid}` → apply admin-global /
manager-own-branch scope → validate Cairo keys, money, reason, expected
status/revision → Firestore transaction → reject stale revision / terminal-state
conflict / wrong branch / self-approval → write server actor + timestamps → write the
`audit_logs` entry and notification. Factor pure logic into
`functions/sales_target.js` (date-key parsing, transitions, idempotency) with
`node --test` coverage. Mirrors the existing `approveSwap` callable in
`schedule_remote_datasource.dart`.

**Approval never mutates an accumulated total** — the authoritative fact is just
`status == approved`; the transaction changes only the one submission.

## Security rules

- **`branch_sales_months`** — read: admin all · manager+employee own branch. Create /
  update / delete: `false` for clients (targets are callable-only). No delete.
- **`branch_sales_submissions`** — read: admin all · manager own branch · employee own
  submitted records, **plus** own-branch **approved** records if the peer-visibility
  decision (below) is *yes*. Create: active employee, own branch, own uid, `pending`,
  deterministic id, no privileged fields, no overwrite. Update / delete: `false` for
  ordinary clients (all transitions go through callables).

Add `firestore-tests/sales_target.rules.test.mjs`: employee can create one valid own
pending submission; cannot create for another user/branch, an approved/rejected doc,
arbitrary decision fields, or a duplicate overwrite; cannot update/delete; cannot read
others' pending/rejected; manager/admin cannot client-write targets or decisions;
unauthenticated denied. Rules cannot derive Cairo date from `request.time` — that
validation is callable-side; document it as defense-in-depth.

## Composition

Vertical slice `lib/features/sales/` mirroring `requests/` and `branch/`.

- **Entities** (`freezed`, `const X._()` getters): `BranchSalesMonthEntity` ·
  `DailySalesSubmissionEntity` · `SalesSubmissionStatus` · `SalesMonthSnapshot`
  (in-memory composed view: target + submission lists — never serialized) · `SalesKpis`.
- **Pure domain** (unit-tested, injected `now`, no `DateTime.now()` inside):
  `businessMonthKey` · `businessDateKey` · `salesSubmissionId` · `sumApprovedPiastres`
  · `remainingPiastres = max(0, target − achieved)` · `progressRatio` (uncapped raw
  for `124%` text **and** a `[0,1]` capped visual ratio) · `averageApprovedDailySales`
  · `requiredDailyRunRate` · `calendarDaysRemaining` · `monthEndForecast` ·
  `completionDateEstimate` · money/date/transition validation.
- **Repository** `SalesRepository`: `watchMonth` · `watchSubmissions` ·
  `watchSubmission` · `watchBranchMonthSummaries` (admin, composed not persisted) +
  the write methods above.
- **Use cases** (verb-phrase, one action each): `GetCurrentSalesMonth` ·
  `WatchSalesSubmissions` · `SubmitDailySales` · `SetBranchMonthlyTarget` ·
  `ApproveSalesSubmission` · `RejectSalesSubmission` · `RequestSalesCorrection` ·
  `ResubmitCorrectedSales` · `EditApprovedSalesSubmission` · `ReopenSalesSubmission`.
- **Data**: `BranchSalesMonthModel` · `DailySalesSubmissionModel`
  (`fromMap/fromEntity/toMap/toEntity`, `Timestamp⇄DateTime` via
  `firestore_extensions`, tolerant defaults, additive schema);
  `SalesRemoteDataSource(Impl)` — Firestore streams for reads,
  `FirebaseFunctions` callables for privileged writes; `SalesRepositoryImpl`
  (`NetworkGuard` before every write, `Exception → Failure`, model → entity).
- **Cubits** (mirror `RequestsListCubit`/`RequestDetailCubit`: freezed unions, busy
  guard, action discriminator, preserve loaded content through a mutation, cancel
  subscriptions in `close()`): `SalesMonthCubit` (role-scoped current branch/month,
  app-wide only if Employee Home + shell reuse it) · `SalesManagerDashboardCubit` ·
  `SalesSubmissionDetailCubit` (per submission) · `SalesTargetEditorCubit` (per sheet)
  · `SalesAdminOverviewCubit` (page-owned). Wire all datasource/repo/use case/cubit
  additions into `core/di/injection.dart`.

## UI

Every screen composes the shared design system ([PROJECT_CONTEXT §7](../../PROJECT_CONTEXT.md));
no bespoke cards, colours, spinners, or spacing. **Progress bars/rings are neutral
greys/white** — the only semantic colour is `StatusBadge` for `pending` / `rejected` /
`correctionRequested` / achieved. One primary CTA per screen; ≥44px targets;
`Semantics` labels; entrance/stagger motion only, collapsed under reduced-motion.

| Screen | Composition |
| --- | --- |
| **Employee Home card** | One `GlassContainer` module on the existing Home: `StatStrip` (target · approved · remaining), monochrome linear progress, `StatusBadge` for state, one `PrimaryCta` "Submit today's sales" when eligible. `Skeleton` loading · `DropEmptyState` when no target · `AppProblemPanel` + retry on failure |
| **Submission screen** | `AdaptiveScaffold` + `PageHero`; piastres-safe EGP field, business-date confirmation; one `AppButton` "Submit for approval". A duplicate-day state shows the existing record with a route to detail instead of a second CTA |
| **Manager dashboard** | `PageHero` (one CTA: "Review pending sales") → KPI `GlassContainer` → `AttentionPanel` for pending / correction-requested → `MetricTileRow` for approved / rejected / history (each navigable). Edit Target is a secondary/overflow action, not a competing hero CTA |
| **Approval / detail** | `PageHero` + `GlassContainer` evidence block (amount · day · submitter · revision · audit context). One primary action per state: Approve; Reject / Request correction in a confirm sheet with **mandatory reason**. Approved is read-only except authorized edit/reopen |
| **Admin management** | `PageHero` + branch selector; `MetricTileRow` per branch (progress → history drill). Target edit / approved correction / reopen live in contextual sheets. No dense enterprise table |
| **History** | Month picker, `PageHero`, `StatStrip` month facts, daily `ActivityCard` list newest-first. `DropEmptyState` · `ListSkeleton` · `AppErrorState`. Manager reuses the same page with its branch preselected |

**Routes:** `/sales/submit` · `/sales/submission/:submissionId` · `/sales/history` ·
`/sales/manage` (admin) — role-guarded in `app_router.dart` + `route_names.dart`.

## Audit ([AUDIT_LOG](AUDIT_LOG.md))

Reuse `audit_logs` + `EventTrackingService` + `AuditLogEntry`; **do not** create a
sales audit collection. Add `sales_month` / `daily_sales_submission` entity types and
event ids: `sales.submitted` · `sales.approved` · `sales.rejected` ·
`sales.correction_requested` · `sales.resubmitted` · `sales.approved_amount_edited` ·
`sales.target_changed` · `sales.reopened`. Metadata carries branch/month/date keys,
submission/target id, actor id/name/role, old/new amount & target piastres & revision,
old/new status, mandatory reason, server timestamp, schema version. Client submission
may write via `EventTrackingService` after its Firestore write; **callable decisions
write the same `audit_logs` schema from the Admin SDK** (a client cannot author a
manager's approval fact).

## Notifications ([NOTIFICATIONS](NOTIFICATIONS.md))

Extend `resolveNotificationRoute`, not a second push path. Add
`NotificationRoute.salesSubmission = 'sales_submission'` (+ `salesSubmissionId`),
resolving to `/sales/submission/:submissionId`, fallback to role-appropriate history.

| Event | Producer | Recipient |
| --- | --- | --- |
| New submission | server create trigger | own-branch manager(s) |
| Approved / Rejected / Correction requested | decision callable | submitting employee |
| Target updated | target callable | branch employees + manager(s) |
| Target achieved | approval/correction callable, **only on a `< target → >= target` crossing** | manager(s) + branch employees |
| Month completed | deferred scheduled job (00:05 Cairo, day 1) — build only if genuinely wanted | manager(s), optionally admin |

Server-originated docs → existing `onNotificationCreated` FCM mirror. Clients never
construct sales notification docs.

## KPIs (derived-on-read only)

days remaining in the current Cairo month · approved total · average approved daily
sales · required calendar-day run-rate · simple month-end forecast · completion-date
estimate · a compact recent-days approved trend (a list, **not** a stored chart
series). Each must name the decision it changes (run-rate → intervene today?;
forecast → on track?; pending count → approvals needed?). **No** `sales_analytics`,
rollups, scorecards, leaderboards, exports, or per-read write aggregation — that is an
ADR decision, not a default (ADR-009/010, ADR-022).

## Edge cases

| Case | Guard |
| --- | --- |
| Duplicate / two employees submit same day | deterministic `{branchId}_{yyyyMMdd}` id + create-only rule; existing doc opens |
| Employee submits twice | same id; update denied |
| Wrong / negative / malformed amount | piastres parser + client + callable + rule type/ownership constraints; negative forbidden, zero allowed |
| Submission after approval | direct update denied; only manager/admin callable correction/reopen |
| Month rollover mid-submit | server computes/validates the Cairo date/month; a doc belongs to its business date, not the displayed month |
| Timezone / DST | all keys + scheduler use `Africa/Cairo` calendar arithmetic + pure tests (ADR-015) |
| Offline submit / network failure | `NetworkGuard` blocks the write offline (no attendance exception — money must not silently replay); a callable transaction is all-or-nothing, UI holds loaded detail + retry |
| Double approval | transaction checks `status == pending` + expected `revision`; second caller gets `failed-precondition` |
| Manager lowers target below achieved | allowed + mandatory reason; `remaining = 0`, raw progress may exceed 100%, visual bar caps at 100% |
| Correction changes counted total | approved-edit callable bumps source amount/revision; totals re-summed from approved records — no stale aggregate exists |
| Manager approves own submission | callable rejects actor uid == submitter uid |
| Missing target | employee sees "Target not set"; cannot submit until set |
| Resubmission after correction | must be `correctionRequested` + expected revision; increments and returns to `pending` |

## Open decisions (rule at P0 sign-off, before any code)

1. **Peer visibility.** May an employee read peers' **approved** daily amounts for
   their own branch/month (needed for the Home "achieved" number)? *Recommended: yes
   for approved only; never others' pending/rejected.*
2. **Back-date window.** *Recommended: employee may submit for the current + previous
   three completed Cairo days; managers/admins may reopen/correct older with a reason.*

## Implementation plan

Phased, following DROP's `datasource → repository → use case → cubit/state → page →
inject → router → codegen → rules + tests → functions + deploy` workflow.

| Phase | Scope | Gate |
| --- | --- | --- |
| **P0** | Lock the two open decisions + this doc + ADR-022; update DATA_MODEL/AUDIT_LOG/NOTIFICATIONS on build | Owner sign-off — no code before financial semantics are ruled |
| **P1** | Domain + data read slice: enums, entities, `sales_calculator` / `sales_business_time` / `sales_submission_id`, repository contract, models, datasource, `GetCurrentSalesMonth` / `WatchSalesSubmissions`; constants + DI | `flutter analyze` · `flutter test` · `build_runner` |
| **P2** | Server boundary: `functions/sales_target.js` (+ test), callables in `index.js`, `firestore.rules`, `firestore.indexes.json`, `sales_target.rules.test.mjs`, audit taxonomy, write use cases | `node --test` · `npm test` · **deploy functions → rules → indexes before dependent client** |
| **P3** | Employee read/submit: `SalesMonthCubit`, submission screen, Home card + progress strip, `sales_format`; routes/DI | one CTA, shared widgets, no raw colours, clean analyze/tests |
| **P4** | Manager approve/dashboard/history: dashboard + detail cubits, three screens, target-edit sheet | own-branch scope in UI **and** rules; optimistic-preservation; busy guard |
| **P5** | Admin + audit + notifications: admin overview cubit + screen, deep-link route, server producers, notification tests | deploy functions before shipping producers; target-achieved is one-shot per crossing |
| **P6** | Derived KPIs + polish (each metric names its decision) | confirm **no** rollup/analytics/stored-KPI was introduced |

Final gates: `flutter analyze` · `flutter test` · `dart run build_runner build
--delete-conflicting-outputs` · `cd firestore-tests && npm test` · `cd functions &&
node --test`. Deploy order: functions → rules + indexes → verify revisions → release
client.

## Related

[ADR-022](../decisions/ADR-022-branch-sales-monthly-ledger.md) ·
[ADR-005](../decisions/ADR-005-server-authoritative-writes.md) ·
[ADR-015](../decisions/ADR-015-automation-business-timezone.md) ·
[ADR-009](../decisions/ADR-009-no-analytics-pipeline.md) ·
[ADR-010](../decisions/ADR-010-lean-over-enterprise.md) ·
[REQUESTS](REQUESTS.md) · [ATTENDANCE](ATTENDANCE.md) · [AUDIT_LOG](AUDIT_LOG.md) ·
[NOTIFICATIONS](NOTIFICATIONS.md) · [DATA_MODEL](DATA_MODEL.md)
