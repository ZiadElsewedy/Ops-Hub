# Branch Monthly Sales Target — design spec

Each branch has a **monthly sales target** in EGP. An employee submits the branch's
sales at the end of a working day; a manager approves or rejects it; **only approved
sales count** toward the branch's monthly progress. Remaining, progress %, and
forecast are **derived on read — never stored**.

> **Status: implemented and audited (2026-08-05) on `Sales-target`.** The full
> vertical slice lives under `lib/features/sales/`. A post-implementation audit
> fixed a routing bug that made the entire employee half unreachable, corrected
> the pace metrics, added the per-branch opt-in, added the employee sales page and
> the missing resubmit loop, and put Branch Sales in the desktop sidebar. Read
> **[ADR-022](../decisions/ADR-022-branch-sales-monthly-ledger.md) before changing
> anything here.** ⚠️ **Deploy in order — Cloud Functions → `firestore.rules` +
> `firestore.indexes.json` → verify the deployed revisions → the client build**
> (the standing deploy-lag hazard). The functions were deployed 2026-08-05; the
> **branch opt-in added a rule and a callable precondition, so rules + functions
> must be redeployed before this client ships.** Live collections are summarised
> in [DATA_MODEL.md](DATA_MODEL.md).

## Rules of the shape

| | |
| --- | --- |
| **Money** | Signed integer **piastres** (`amountPiastres`). Never `double`/decimal. `>= 0`; **zero is a valid, explicitly-submitted "no sales" day**; negative forbidden |
| **Opt-in** | Per branch: `branches/{id}.salesTargetEnabled`, **admin-only, default `false`**. Off ⇒ the feature does not exist for that branch — no Home card, no sales pages, no target management, no submissions (client + rules + callable) |
| **Target owner** | The **branch**, per accounting **month** — not an employee, not the mutable branch doc |
| **Submission statuses** | `pending → approved \| rejected \| correctionRequested`. A `correctionRequested` doc, once resubmitted, returns to `pending`. A manager/admin edit of an already-`approved` amount stays `approved` and bumps `revision`. Admin reopen returns any terminal record to `pending` |
| **Submit** | Any **active branch employee**. **One document per branch business day** — first valid submission wins (deterministic id); a second attempt opens the existing record, never overwrites it |
| **Record (direct)** | Own-branch **manager** or **admin** may record a day **directly** via the `recordApprovedDailySales` callable. It lands **already `approved`** (the actor is the branch's approver — there is no self-review), for today or **any past** Cairo day (never the future), and counts toward the target immediately. Same deterministic id, so a day that already has any record is refused (`already-exists`) — edit it instead. Requires the month's target to exist. Optional note. This is why a client cannot write it: an `approved` doc is exactly the create the rules forbid, so it goes through the Admin SDK |
| **Decide** | Own-branch **manager**, or **admin** (global). Approve / reject / request correction |
| **Correct** | Manager/admin only, server-authoritative. Editing an already-approved amount takes an **optional reason** (owner call, 2026-08-07 — `salesReason(reason, false)`); reopening a terminal record keeps a **mandatory reason**. Reject / request-correction reasons stay mandatory (see Decide). ⚠️ Making the edit reason optional weakens the audit trail for a monetary change — the audit row now stores `reason: null` when none is given |
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
| `decisionReason` | string? | **mandatory** for reject / correction / reopen; optional note for a direct record |
| `recordedDirectly` | bool? | `true` on a manager/admin direct record (server-written); absent on an employee submission |
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
| `recordApprovedDailySales` | **Callable** — manager/admin records a day **directly** as `approved`. Rejects a future day, a day that already has a record, or a month with no target. Actor is both `submittedBy` and `decisionBy` (a deliberate direct entry, **not** the self-approval `canDecideSubmission` forbids). Stamps `recordedDirectly: true`. Fires the target-achieved crossing like any approval |
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
  `WatchSalesSubmissions` · `SubmitDailySales` · `RecordDailySales` (returns a
  `SalesRecordResult`: amount, new achieved total, target, target-crossed flag)
  · `SetBranchMonthlyTarget` ·
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
  subscriptions in `close()`): `SalesMonthCubit` (app-wide; current branch/month,
  with two entry points — `loadForEmployee` adds the employee's own records,
  `loadForBranch` is the manager Home read and omits that stream. ⚠️ Its
  submission getters — `canSubmitToday` above all — are meaningless in branch
  mode and must never drive a CTA there) · `SalesManagerDashboardCubit` (also
  owns `recordSales`; on success it carries a one-shot `justRecorded`
  `SalesRecordResult` on the loaded state — a **separate** channel from `message`
  so the celebration is an overlay, not also a snackbar) ·
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
| **Employee Home card** | One compact `GlassContainer`: **target · achieved · remaining** and a tap into the branch sales page. Nothing else — no bar, no percentage, no badge. An opted-out branch renders **nothing, including its spacing** |
| **Employee sales page** (`/sales/mine`) | The team month (`SalesMoneyRow`) → **Needed per day**, toned by today → today's close and its status → the one CTA. A day sent back for correction keeps a single actionable row; there is no month-history table |
| **Submission screen** | `PageHero`, piastres-safe EGP field, Cairo business-date confirmation, one `AppButton`. Dual mode: new close, or a correction seeded with the amount under review and the manager's reason. Already-closed / no-target / teammate-closed each render their own panel instead of a dead CTA |
| **Manager Home card** | The same `SalesTargetCard` as Employee Home — **target · achieved · remaining**, one tap into `/sales` — sitting under *On shift today*. Fed by `SalesMonthCubit.loadForBranch`, which is `loadForEmployee` minus the own-submissions stream: a manager never closes a day. Gates itself **and its spacing**; an opted-out branch renders nothing. It replaced a *Branch sales* `DigestEntry` that carried no figure and — alone among the sales surfaces — never consulted `salesTargetEnabled`, so it offered an opted-out manager a door onto the Disabled screen |
| **Manager dashboard** | The one **rich** surface. The branch month — **achieved · a monochrome progress ring · remaining**, then the target (**"Set target"** until one exists, **"Edit target"** after) → **Needed per day** → a **Record sales** button (manager/admin direct entry) → the review queue with inline approve/reject → **one** *All submissions* door → a **Pace** card. See the manager-dashboard note below |
| **Record sales (direct)** | A `showSalesRecordSheet` collects the amount, the business day (today by default, or any past day this month via a date picker), and an optional note. On success a `showSalesRecordAddedOverlay` plays once: the figure **counts up** to "**+ {amount} EGP** added to the branch total", with a slim achieved-of-target bar. Strictly monochrome — the **only** chromatic pixel is the **success** tint that appears solely when this record is the one that **reached** the monthly target ("Monthly target reached"). Auto-dismisses (~2.6s), tap to close, reduced motion rests on the final frame |
| **Approval / detail** | Evidence block (amount · day · submitter · decision provenance · revision). Actions render only for a manager or admin; reopen only for an admin on a terminal record. One primary action per state |
| **Admin overview** | One row per **opted-in** branch: name + **target · achieved · remaining**. Opted-out branches are absent, not greyed — `salesEnabledBranches` is the single scope rule, shared with Admin Home |
| **Admin Home summary** | One line per opted-in branch: name + achieved *of* target. Gates itself and its heading; with nothing opted in it never builds its cubit, so Home costs nothing |
| **History** | Month picker, status chips, daily list newest-first. Pending / Approved / Rejected / All are **four destinations** — each has its own title, filter and empty state |

### The simplification rules

- **Three money facts, one component.** `SalesMoneyRow` renders **target ·
  achieved · remaining** in that order on every surface. The currency is named
  **once** per row, not three times; each figure `scaleDown`s so a seven-digit
  target cannot clip its column.
- **The shared surfaces stay lean.** Employee Home, the employee page, the
  Manager Home card and both admin surfaces show **target · achieved · remaining**
  (plus *Needed per day* where a day is closed) and nothing else — no chart, no
  ring. Simplicity there is deliberate and unchanged.
- **The manager dashboard is the one rich surface (owner-directed, 2026-08-07).**
  It is where a manager runs the month, so it earns more: a **progress ring**
  (the *how far* percentage), and a **Pace** card that pairs the month's
  target-outlook **verdict** with the **last-7-days approved-takings chart** (the
  *how fast*). This re-enriches what an earlier pass had stripped to *Needed per
  day* alone; the enrichment lives **only** here.
- **The achievement figures carry a status tint (ADR-004-compliant).** ACHIEVED,
  the **ring** (arc + %) and the chart's **today** bar take
  `salesOutlookTint(outlook)` — **green** when the month is projected ahead of
  target, **amber** when behind, **white** before there's anything to project.
  This is colour as *status*, the same rule Needed per day follows, so it ties the
  hero numbers to the Pace verdict without breaking monochrome. Target, remaining,
  the edit button, the door and the other bars stay neutral. (A chromatic *brand*
  accent — indigo, regardless of status — was tried on these figures and reverted
  on 2026-08-07; the status tint is what stuck.)
- **The four filtered tiles are now one door.** Pending / Approved / Rejected /
  History each opened the **same** history screen with a different `?status=`, so
  as four `MetricTile`s they read as four destinations that were one. A single
  *All submissions* row opens the unfiltered ledger; the counts survive as an
  inline breakdown. Pending work is still acted on in the *Waiting on you* queue
  above, so the row is reference, not the primary action.
- **Colour stays status-only.** Two derivations own every coloured pixel:
  `salesDayPace` (Needed per day) and `salesTargetOutlook` (the Pace verdict **and**
  the achievement-figure tint via `salesOutlookTint`). Both are
  success / amber / red for a real judgement and neutral when there is nothing to
  judge. Colour is carried by a hairline, a glyph, a ring arc and the figure —
  never a filled surface. An unsubmitted or not-yet-projectable state is never a
  failure. There is **no chromatic brand accent** (ADR-004 holds).
- **Money is grouped from the right.** `formatEgp` counts in threes from the
  last digit. A lookahead once matched at index 0 whenever the digit count was a
  multiple of three, so `945000` shipped to users as **`,945,000`**.
- **The target is the branch's, never the viewer's.** Every role's destination is
  labelled **Branch Sales**; the employee page says "TEAM TARGET". Nothing is
  framed as a personal quota — "My Sales" mis-stated what the feature measures.
- **Brand is the logo, never the word.** Where a surface carries a mark it is
  `BrandWatermark(assetLogo: true)` — the real artwork at low opacity, not a
  typographic "DROP".

**Routes** — role-guarded in `app_router.dart` + `route_names.dart`:

| Route | Who | Notes |
| --- | --- | --- |
| `/sales` | manager · admin | branch dashboard. Admin may steer with `?branchId=`; a manager is always pinned to their own branch |
| `/sales/history` | manager · admin | branch ledger; `?branchId=` · `?status=` |
| `/sales/admin` | admin | all-branches overview |
| `/sales/submit` | employee | close of day; `?correct=<submissionId>` for a resubmission |
| `/sales/mine` | employee | the employee's own sales page |
| `/sales/submission/:id` | role-shared | rules scope what each role may read |

> ⚠️ `isManagerArea` matches `/sales` **exactly**, never by prefix. Every other
> sales path lives under `/sales/`, and a prefix match here once made all of them
> manager-only — silently bouncing every employee back to Home from their own
> submit screen, their own records, and the sales deep link. `sales_route_access_test.dart`
> is the regression guard.

## Audit ([AUDIT_LOG](AUDIT_LOG.md))

Reuse `audit_logs` + `EventTrackingService` + `AuditLogEntry`; **do not** create a
sales audit collection. Add `sales_month` / `daily_sales_submission` entity types and
event ids: `sales.submitted` · `sales.recorded` (manager/admin direct record) ·
`sales.approved` · `sales.rejected` ·
`sales.correction_requested` · `sales.resubmitted` · `sales.approved_amount_edited` ·
`sales.target_changed` · `sales.reopened`. Metadata carries branch/month/date keys,
submission/target id, actor id/name/role, old/new amount & target piastres & revision,
old/new status, mandatory reason, server timestamp, schema version. Client submission
may write via `EventTrackingService` after its Firestore write; **callable decisions
write the same `audit_logs` schema from the Admin SDK** (a client cannot author a
manager's approval fact).

## Notifications ([NOTIFICATIONS](NOTIFICATIONS.md))

Extend `resolveNotificationRoute`, not a second push path.

| Event | Producer | Recipient | `route` |
| --- | --- | --- | --- |
| New submission | server create trigger | own-branch manager(s) **+ every active admin**, minus the submitter | `sales_submission` |
| Sales recorded | `recordApprovedDailySales` callable | own-branch manager(s) + branch employees **+ every active admin**, minus the actor | `sales_submission` |
| Corrected submission | resubmit callable | own-branch manager(s) **+ every active admin**, minus the actor | `sales_submission` |
| Approved / Rejected / Correction requested | decision callable | submitting employee | `sales_submission` |
| Target updated | target callable | branch employees + manager(s) **+ every active admin**, minus the actor | `sales_target` |
| Target achieved | approval/correction callable, **only on a `< target → >= target` crossing** | manager(s) + branch employees **+ every active admin**, minus the actor | `sales_submission` (it names the crossing submission) |
| Month completed | deferred scheduled job (00:05 Cairo, day 1) — build only if genuinely wanted | manager(s), optionally admin | `sales_target` |

Recipients come from one place: the pure `selectSalesRecipients`
(`functions/sales_target.js`), read into by `salesRecipients` in `index.js`.

> ⚠️ **Admins are an ADDITION, never a fallback (fixed 2026-08-07).** An admin has
> no `branchId` — the role is global — so `where("branchId", "==", …)` can never
> return one. The original resolver consulted admins *only when the branch query
> came back empty*, which on every real branch is never, so an admin received
> **nothing at all** from this feature. This is the same shape
> `resolveRequestApprovers` / `resolveAttendanceReviewers` have always had.
> `managersOnly` narrows the **branch** side only; an admin can decide any
> submission, so they are a reviewer in both shapes.
>
> **Nobody is notified of their own action.** Every call passes the acting uid as
> `excludeUid` — otherwise adding admins would page the admin who just edited the
> target about their own edit.

`sales_submission` carries `salesSubmissionId` → `/sales/submission/:id`.
`sales_target` carries only `monthKey` — there is no per-month screen, so every
role lands on the sales surface it owns (`/sales` for admin·manager, `/sales/mine`
for an employee), which is where the month's target and pace render. An id-less
`sales_submission` resolves the same way, so the pre-2026-08-06 docs already in
users' inboxes stay tappable.

All five events share **one** `NotificationType.salesSubmission`, because
`writeSalesNotifications` is their single producer. Priority `normal`, filter pill
**Sales** — see the `type`-fallback warning in
[NOTIFICATIONS §5](NOTIFICATIONS.md#5-notification-model) for what went wrong
while that enum value was missing.

Server-originated docs → existing `onNotificationCreated` FCM mirror, which must
forward `salesSubmissionId` in the push `data` or a background tap loses the
record. Clients never construct sales notification docs.

## KPIs (derived-on-read only)

`computeSalesKpis` derives the full set (pure, `now` injected, unit-tested). The
shared surfaces render only *Needed per day*; the **manager dashboard** renders
the rest through the ring and the Pace card (see the manager-dashboard note).

| Figure | Formula | Rendered? |
| --- | --- | --- |
| **Achieved** | Σ approved `amountPiastres` | ✅ everywhere |
| **Remaining** | `max(0, target − achieved)` | ✅ everywhere |
| **Days left** | `daysInMonth − dayOfMonth + 1` — **includes today** | ✅ (beside Needed per day) |
| **Needed per day** | `ceil(remaining / daysLeft)` | ✅ — a coloured figure (`salesDayPace`) |
| **Progress %** | `achieved / target`, capped at 100% | ✅ manager dashboard **ring** |
| **Average per day** | `achieved ÷ distinct days with an approved record` | ✅ manager dashboard Pace card |
| **Expected month end** | `achieved + average × days with no record at all` | ✅ feeds the Pace **verdict** |
| **Month outlook** | `salesTargetOutlook`: forecast `≥ target` → ahead, else behind, `tooEarly` with no approved day | ✅ manager dashboard Pace card (coloured) |
| **7-day trend** | `computeSalesTrend`: per-day approved takings, this window's avg vs the prior window's | ✅ manager dashboard Pace chart |

Formula choices, each reversing a wrong one:

- **Days left includes today.** The exclusive count made *Needed per day* read
  `0 EGP` on the last day of every month while the branch was still short.
- **Every "per day" average divides by approved DAYS, not elapsed calendar
  days.** Approvals lag, so the newest day or two never has an approved record;
  dividing by elapsed days understated the pace daily. This holds for the KPI
  average **and** for the 7-day trend's window average. Distinct business days,
  not documents — a corrected-and-resubmitted day is still one day.
- **The forecast only projects days with no record at all.** Recorded days count
  at their real value and are never re-projected.
- **The outlook is read off the forecast, never achieved-to-date vs. elapsed
  days.** Because approvals lag, an achieved-vs-elapsed comparison reads "behind"
  every day even for a branch comfortably on pace; the forecast-based verdict does
  not.

`completionDateEstimate` stays **removed** (it returned *today* whenever the target
was met). The month-level pace verdict returned, rebuilt as the forecast-based
`salesTargetOutlook`, when the Pace card was reintroduced (2026-08-07).

**No** `sales_analytics`, rollups, scorecards, leaderboards, exports, or per-read
write aggregation — that is an ADR decision, not a default (ADR-009/010, ADR-022).

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

## Locked decisions (owner sign-off 2026-08-05)

1. **Peer visibility — approved only.** An employee MAY read own-branch **approved**
   daily records (so Home shows the live achieved total), and NEVER other employees'
   `pending` / `rejected` / `correctionRequested` records. This is the read rule P2
   enforces.
2. **Back-date window — current + previous 3 Cairo days.** An employee may submit a
   close for the current business day or any of the previous three completed Africa/
   Cairo days. Older records are entered/changed only by a manager/admin, always with
   a reason. This is the create-window validation P2 enforces (callable-side; rules are
   defense-in-depth).

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
