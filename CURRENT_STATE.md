# DROP — Current State

> **Today's snapshot. Nothing historical.** The moment something here becomes
> history, it moves to [CHANGELOG.md](CHANGELOG.md) and leaves this file.
>
> **Last verified against the code:** 2026-08-08.

> **Pending Review drill-down collapses single-choice levels (2026-08-08,
> polish, client-only, NOT device-verified):** The admin Pending Review flow
> (`PendingReviewScreen`) is Summary → Branch → Employee → task, and it never
> collapsed — reviewing one task cost 4 taps even when there was one branch and
> one employee. It now **auto-descends any level with a single option** (one
> branch with pending work, or one employee in it), on entry *and* on back
> (`_back` + `PopScope.canPop` skip auto levels via the recomputed
> `_singleBranch` / `_singleEmpInBranch` flags), so the common case opens the
> task directly. The full drill-down returns unchanged the moment a level has
> more than one row. Effective branch/employee ids are derived from the same
> `waitingReview` grouping already built — no new cubit/reads/schema/rules/
> functions. Pinned by `test/pending_review_collapse_test.dart` (3).
> `flutter analyze` clean.

> **Admin Home Branch-sales rows now match the manager card (2026-08-08, polish,
> client-only, NOT device-verified):** The Admin Home `AdminBranchSalesSummary`
> per-branch line dropped its flat text row (*name … 111,700 of 1,000,000 EGP*)
> for the same layout the manager Home `SalesTargetCard` leads with — a compact
> emerald progress ring (`_MiniRing`, reusing `SalesRingPainter`) beside the
> branch name, the rolling achieved figure over the target, and a rolling
> *… EGP remaining* line. No-target and loading rows updated to match. Render
> layer only — no new reads, no cubit/state/schema/rules/functions change; still
> the sales emerald accent (ADR-004 as already softened on sales surfaces).
> `flutter analyze` clean; no test references the widget.

> **Home Branch-sales card redesigned with a mini ring (2026-08-08, polish,
> client-only, NOT device-verified):** The employee Home `SalesTargetCard`
> dropped the flat `SalesMoneyRow` for a small **progress ring** + achieved-over-
> target (`112,000 / 1,000,000`) + `… EGP remaining`. Achieved rolls in (shared
> premium count-up + light sweep), the ring sweeps on `kPremiumSettle`, remaining
> rolls a beat later. DROP corner mark removed from this card to match the mockup
> (chevron only). `SalesMoneyRow` retained for the admin overview.

> **Employee Branch-sales screen leads with an animated target hero (2026-08-08,
> polish, client-only, NOT device-verified):** `EmployeeSalesScreen`'s month card
> now opens with a **hero gauge** instead of the flat `SalesMoneyRow` — a large
> centred progress ring (arc sweeps + centre % counts up together) over **Target
> · Achieved · Remaining** as three labelled columns. New `sales_target_hero.dart`
> (`SalesTargetHero`) on the shared `AnimatedCountText` / `kPremiumSettle` motion
> (cascade + rise + light sweep on Achieved). The ring painter is now reusable
> (`_RingPainter` → **`SalesRingPainter`**) so the compact manager ring and the
> big employee hero share one gauge. Manager dashboard keeps its compact ring —
> the hero is employee-only for now. **Odometer + premium-palette update
> (2026-08-08):** the count-up was replaced by a **slot-machine / odometer** —
> new reusable `core/widgets/rolling_number.dart` (`RollingDigit` +
> `RollingNumber`): each digit is an independent vertical reel keyed by place
> value, rolling *forward* (with a multi-turn flourish that spins harder toward
> the units) and settling exactly on the value; commas/decimal stay static, and
> leading digits roll in from 0 as the number grows. No opacity/scale/whole-string
> rebuilds; reels settle left→right in ~0.5–0.9 s; honours reduce-motion. It now
> drives **every** sales figure (hero, Home `SalesTargetCard`, `SalesNeededPerDay`,
> manager `SalesMonthOverview`, admin `SalesMoneyRow` + `AdminBranchSalesSummary`)
> and the ring percentages; the admin per-branch rows roll snappier (~0.7–1.0 s).
> `salesOutlookTint` returns the muted sales accents (emerald ahead / gold behind
> / white early), so the manager ring + Achieved + Pace card go premium while
> keeping the ahead/behind *status* meaning; `SalesProgressRing` now draws the
> hero's gradient+halo arc in that tint. `AnimatedCountText` is
> retired from the sales feature (still defines `kPremiumSettle`, used by nothing
> sales-side now). Palette moved off the raw `success`/`warning`/`error` to muted
> **sales accents** (`AppColors.salesEmerald`/`salesEmeraldGlow`/`salesAmber`/
> `salesCoral`): emerald gauge+%+Achieved, gold Remaining, softened-coral pace
> danger, Target on the grey ramp. Ring sweeps shortened to ~1.2 s on `kReelSettle`.
> Hero brand watermark moved to the **top-right** corner (was bottom-right, behind
> Remaining) via a new `BrandWatermark.corner`. Render layer only; ADR-004 still
> softened on sales surfaces only, by owner ruling.

> **Editing an approved sales record notifies its submitter (2026-08-08, fix,
> server-side, needs deploy):** Closed a gap where editing an approved record's
> amount notified nobody, while recording a new day and editing the target both
> notify the whole branch. `editApprovedDailySalesSubmission` now sends a
> **targeted** push to the record's `submittedById` (*"{name} changed your
> approved sales to {X} EGP."*) — not branch-wide, since an edit is a correction
> and broadcasting every fix is noise. Skipped when editor == submitter or the
> amount is unchanged; the target-achieved crossing still notifies the branch.
> Reuses the `salesSubmission` type + `sales_submission` route. **Requires a
> Cloud Functions deploy.**

> **Branch-sales hero figures roll to their new value (2026-08-08, polish,
> client-only, NOT device-verified):** The manager Branch-sales dashboard hero
> animates instead of snapping — Achieved, Remaining, Target and Needed-per-day
> count up, and the progress ring's arc + centre percentage sweep in together.
> They roll on first reveal and whenever a sale is recorded or the target is
> edited. New reusable `core/widgets/animated_count_text.dart`
> (`AnimatedCountText`): tweens between values, reformats each frame so
> grouping/suffix stay right, continues from the current value on rapid changes,
> and respects the platform **reduce-motion** setting. Wired into
> `sales_month_overview.dart`, `sales_progress_ring.dart` and
> `sales_needed_per_day.dart`; figures use tabular numerals for steady width. No
> domain/data/state change — render layer only. `flutter analyze` clean.

> **A manager can mark their own day off in the schedule (2026-08-08, feature,
> client-only, NOT device-verified):** A manager works an open/presence shift and
> so is (and stays) unassignable to a Morning/Night slot — the shift picker was
> already `role.isEmployee`-only. The gap was that employees couldn't see the
> **manager's day off**, because the day sheet's Leave picker was *also*
> employees-only. Now `day_details_sheet._showLeavePicker` includes the **editing
> manager themselves**, forced to **`LeaveType.dayOff`** (no type choice).
> **Self only** — an admin editing the branch can't mark the manager off, and
> employees keep the full leave-type choice. The day off is a plain `leave`
> entry, so it shows everywhere leave already renders (day-sheet leave list +
> Final-view Off row / export). No rules/schema/functions change; the branch
> roster read already returns the manager. `flutter analyze` clean, +3 tests
> (`schedule_manager_day_off_test.dart`). Design doc
> [SCHEDULE](docs/design/SCHEDULE.md) amended.

> **OS label split to "Drop Ops"; in-app name stays "Drop Operations"
> (2026-08-08, polish, NOT device-verified):** The short name the operating
> system shows was changed **Drop Operations → Drop Ops** on the OS-level surfaces
> only — iOS `CFBundleDisplayName`/`CFBundleName`, Android `android:label`, macOS
> `INFOPLIST_KEY_CFBundleDisplayName` (the stray trailing space was also dropped),
> Windows `FileDescription`/`ProductName`, Linux window/header-bar titles, and both
> `MaterialApp` `title`s (the desktop/web window & app-switcher title). Everything
> **inside** the app is deliberately **unchanged** and still reads *Drop
> Operations*: `AppConstants.appName`, the `DropWordmark` logotype, the splash
> label, and all copy (About, login, onboarding, notifications, schedule
> Final-view + PDF headers). No logic, schema, rules, or functions changed;
> `flutter analyze` clean (only `main.dart` is a Dart edit — the rest are platform
> config). No tests changed (the 3 name tests assert the wordmark/copy, all kept).
> ⚠️ **NOT device-verified** — the launcher label and window-title rendering need a
> real build per platform. *(Supersedes the earlier same-day DROP → Drop
> Operations rename, which had made the OS labels "Drop Operations" too.)*

> **Reviewer attendance search is now directory-backed (2026-08-07, feature,
> presentation + pure domain + one bounded read, client-only, NO deploy, NOT
> device-verified):** The manager/admin review ledger search matched only
> employees who had a record **or** a rostered-absence gap in the window, so
> "Mohamed's attendance for July" read *No matches* whenever Mohamed had neither —
> even though he's a real, active teammate. The review cubit now loads the
> branch's active employees once per branch (`GetUsersByBranch`, cached, re-emits
> on arrival so a **deep-linked** person search still resolves), carried on the
> loaded state as `directory`. New pure `attendanceDirectoryOnlyMatches`
> (`attendance_directory_match.dart`) returns the searched-for teammates with no
> attendance surface this period — **gated on a non-empty search term** (no term ⇒
> no rows, so the ledger never floods) and using the **same** `attendanceSearchNormalize`
> fold as the record/gap search. They render as quiet, non-tappable *"No attendance
> recorded in this period"* rows below the dated records/gaps, so the search
> resolves against the whole directory. One bounded `where('branchId'==)` users
> read per branch (already permitted — `users` reads are flat, ADR-012); **no
> rules/functions/schema change.** Pinned by `attendance_directory_match_test` (5)
> + a review-mode `attendance_history_cubit_test` case. `flutter analyze` clean,
> 1917 Dart tests green. This closes the window-bound caveat noted below.

> **Attendance history gained curated quick-view presets (2026-08-07, feature,
> presentation + pure domain, client-only, NO deploy, NOT device-verified):** A
> "Quick views" chip row atop the history/review filters applies a whole view in
> one tap — *Problems this week* · *Late this week* · *Absent this week* ·
> *Overtime this month* — setting the date range + status set together and
> clearing the shift facet while keeping any name search (so "Mohamed's late days
> this week" is a search plus a preset). Deliberately **curated, not user-saved**
> (ADR-010 signal-over-volume): a short fixed `kAttendanceHistoryPresets`, not a
> filter-builder with persistence. Pure `attendance_history_preset.dart`
> (`apply`/`isActive`) + `AttendanceHistoryCubit.applyPreset` + one filter-widget
> row; a chip highlights only while the query exactly matches it. No new read, no
> schema/rules/functions change. Pinned by `attendance_history_preset_test` (7) +
> an `applyPreset` cubit case. `flutter analyze` clean, 1924 Dart tests green.

> **Exports now open the real OS share sheet (2026-08-07, feature, client-only,
> NO deploy, NOT device-verified):** Attendance (PDF summary · CSV timesheet) and
> schedule (PNG · PDF · XLSX) exports opened the file in a local viewer
> (`open_filex`) — so *sending* one to WhatsApp/Mail took an extra hop through
> Quick Look. New single seam `core/services/export_sharing.dart`
> (`writeExportFile` + `shareExportedFile`) writes the file to a findable place
> and hands it to the OS **share sheet** via `share_plus` (^12.0.2). Both
> screens' duplicated `_writeExport`/`_open` helpers were deleted in favour of
> the seam; `share_plus` is imported **only** there. **Owner-approved exception**
> to the dependency-light stance (the same rung as the deliberately-rejected
> `printing`); iPad/macOS popover is anchored to the button's render box. Docs +
> the stale `pdf` pubspec comment updated. `flutter analyze` clean, 1917 Dart
> tests green (no test exercises the platform channel). ⚠️ **NOT device-verified**
> — the share sheet, the Android FileProvider and macOS entitlements need a real
> run on each of iOS/Android/macOS. `open_filex` stays (chat still uses it).

> **Attendance reports gained ranked exception boards (2026-08-07, feature,
> presentation + pure domain, client-only, NO deploy, NOT device-verified):** The
> reports hub answered "which periods need attention" but not "**who** — who has
> the highest overtime, who's late the most, who's missing clock-outs" without
> scanning the table. New pure `attendanceRankings` (`attendance_rankings.dart`)
> ranks the ledger rows the hub **already streams** by a chosen
> `AttendanceRankingMetric` — Overtime · Lateness · Absences · Missing punches ·
> Hours worked — summed per employee, highest-first, zero-value people left off
> (a leaderboard shows who *has* the thing), ties broken by name. A new
> `AttendanceRankingsCard` (metric chip row + ranked list, strictly monochrome per
> ADR-004 — "most overtime" is a fact, not a status) sits under the report
> headline, scoped to the same branch + period the hub is showing. **Zero new
> reads, no cubit, no route, no schema/rules/functions change.** Pinned by
> `attendance_rankings_test` (7) + `attendance_rankings_card_test` (3).
> `flutter analyze` clean, 1911 Dart tests green.

> **Attendance history filters & search, sharpened (2026-08-07, feature,
> presentation + pure domain, client-only, NO deploy, NOT device-verified):**
> Three P1 gaps from the attendance audit, all in the History/Review ledger.
> (1) **Status is now multi-select** — the facet moved from a single
> `AttendanceStatusFilter` to a `Set` combined with **OR**, so a reviewer can ask
> for "Late **or** Absent" in one view; the *All* chip clears it, `activeStatuses`
> collapses the `all` sentinel to empty. (2) **Today / Yesterday date presets**
> were added to `AttendanceDateRange` (single-day windows) so the common "who was
> absent yesterday" needs no custom picker. (3) **Employee search is now Arabic-
> and diacritic-insensitive** — new pure `attendanceSearchNormalize` folds case,
> Arabic tashkeel/tatweel, alef/hamza/ta-marbuta letter forms and common Latin
> accents, applied to **both** the needle and each record's `userName` (and the
> same fold now drives the absence-gap list, so `مُحَمَّد` matches `محمد`). All
> pure-domain (`attendance_history_query.dart`, `attendance_history_gap.dart`) +
> the filter widget/cubit; **no new read, no schema/rules/functions change.**
> Pinned by expanded `attendance_history_query_test`, `_cubit_test`, `_gap_test`.
> `flutter analyze` clean, 1901 Dart tests green. ✅ **The window-bound gap is now
> closed** — the reviewer search is directory-backed (see the entry above).

> 🔴 **ATTENDANCE MINUTES WERE CLIENT-FORGEABLE — FIXED, ⚠️ NEEDS A FUNCTIONS
> **AND** A RULES DEPLOY (2026-08-07, security, NOT device-verified).** The module's
> own promise is that the record is "forgery-resistant" because attendance minutes
> feed payroll. It wasn't: every mitigation lived on the client write path. The
> `attendance` **owner-update** rule pinned only `userId`, so an employee talking to
> Firestore directly could set `workedMinutes` to anything, backdate `clockIn` to
> erase lateness, or set `status`/`clockOut` freely; the **create** rule pinned only
> `status`, so a clock-**in** could be born already claiming `workedMinutes: 600` +
> a `clockOut`. Those numbers copy verbatim into the `attendance_expectations`
> ledger and every report/CSV/PDF. Now: **payroll minutes are computed only by the
> Admin SDK.** New `functions/attendance_totals.js` (a line-for-line port of
> `AttendanceCalculator`, 11 node tests) + a finalize step in `onAttendanceWritten`
> recompute the snapshot over the server-stamped clock times (guarded on
> `source: 'clock'`, writes only on change so no loop). The client clock-out stops
> writing minutes (the summary recomputes worked/OT live via the calculator, so the
> screen never shows 0h, offline included). `firestore.rules` now pin every
> payroll-sensitive field on **both** create (zero minutes, no clock-out) and owner
> update (only the `inProgress → completed` clock-out transition; minutes, `clockIn`,
> the scheduled window and `source` frozen; reviewers keep the broad path for
> soft-delete). [ADR-024](docs/decisions/ADR-024-server-authoritative-attendance-minutes.md).
> Pinned by `firestore-tests/attendance.rules.test.mjs` (17). `flutter analyze`
> clean, 1893 Dart + 155 node + 89 rules tests green. ⚠️ **Inert until
> `firebase deploy --only functions,firestore:rules`** — until then production keeps
> the old client-trusted path. **NOT device-verified.**

> **A deactivated account disappears from chat (2026-08-07, feature,
> client-only, NOT device-verified):** Owner: *"when I make an account inactive
> its chat should disappear, no one can message it, and you can't send it a task
> — anything it's used in should no longer be valid."* Most of that was already
> true — the assignee picker (`task_cubit.branchEmployees`), the new-chat
> teammate picker (`GetChatDirectory`), schedule/roster pickers, broadcasts and
> login all already exclude `isActive == false`. The one real gap was an
> **existing** chat conversation: the inbox is built from past conversations, not
> the (already-filtered) picker, so a teammate you'd already chatted with stayed
> in the inbox and remained messageable after being turned off. Now: the chat
> directory read yields, from the **same single `getAllUsers` query**, a set of
> deactivated uids (`GetChatDirectory.resolve` → `ChatDirectorySnapshot`, cached
> beside the name directory in `AppDependencies`). `ChatListCubit` hides any
> conversation whose counterpart is in that set — dropped from the inbox list,
> excluded from the `totalUnread` sidebar badge, and ignored for live
> bump/notify — and `ChatConversationScreen` refuses to open such a thread
> (person-off empty state, no history, no composer) even via a stale deep link.
> The filter is a **positive** signal (a uid is hidden only when a document says
> it's off), so an unloaded directory never blanks the inbox; a mid-session
> deactivation (or reactivation) takes effect on the next directory (re)load via
> `refilter()`, already wired through `invalidatePeopleDirectories`. **Task
> assignment needed no change** — new assignments already exclude inactive users;
> an already-assigned inactive user still resolves for display, by decision.
> Pinned by `test/chat_deactivated_counterpart_test.dart` (5). `flutter analyze`
> clean, 1893 Dart tests green. No rules/functions/schema change. ⚠️ **Client-side
> only** — the chat backend (`drop-api`, a separate repo not in this project)
> does not yet reject a send to a deactivated user; enforcement here is the UI the
> user sees. **NOT device-verified.**

> **Managers & admins can record sales directly, with a celebratory overlay
> (2026-08-07, feature, ⚠️ NEEDS A FUNCTIONS DEPLOY, NOT device-verified):**
> Sales were employee-submit-only; a manager/admin could approve but not enter a
> day. New `recordApprovedDailySales` callable lets an own-branch **manager or
> admin** record a day **directly** — it lands already `approved` and counts
> toward the target immediately (a manager can't *self-approve* a pending doc, so
> a direct record is the right shape: the actor is both `submittedBy` and
> `decisionBy`, stamped `recordedDirectly:true`, guarded by the Admin SDK, not a
> client write). Accepts today or any past Cairo day (never the future), refuses a
> day that already has a record (`already-exists` → edit it instead) and a month
> with no target. The manager dashboard gains a **Record sales** button →
> `showSalesRecordSheet` (amount · business-day picker · optional note) → on
> success a `showSalesRecordAddedOverlay` **counts up** to "**+ {amount} EGP**
> added to the branch total" over a slim achieved-of-target bar. Strictly
> monochrome (ADR-004): the sole chromatic pixel is the **success** tint shown
> only when *this* record **reached** the target ("Monthly target reached"). The
> result rides a one-shot `justRecorded` channel on the loaded state (separate
> from `message`, so it's an overlay not a snackbar); reduced motion rests on the
> final frame. Notifications reuse `selectSalesRecipients` (branch + every admin,
> minus the actor) with a *Sales recorded* body and the same target-achieved
> crossing as an approval. New pure `isRecordableSalesDate` (+2 node tests),
> `SalesRecordResult`, `RecordDailySales`, audit `sales.recorded`. Pinned by 2 new
> `sales_manager_dashboard_cubit_test` cases + `sales_record_added_overlay_test`
> (2). `flutter analyze` clean, 1888 Dart + 144 node tests green. ⚠️ **Inert until
> `firebase deploy --only functions:recordApprovedDailySales`** — the callable
> does not exist in production yet, so the button errors on device until deployed.
> No rules/index change (Admin-SDK write). Design doc
> [SALES_TARGETS](docs/design/SALES_TARGETS.md) updated.

> 🔴 **THE ADMIN BUG: `sendNotification` refused every client notification
> aimed at an admin. FIXED, ⚠️ NEEDS A FUNCTIONS DEPLOY (2026-08-07).**
> Owner: *"the admin isn't receiving notifications — just chat; other things
> no, and it doesn't appear in the inbox."*
>
> The callable is the **only** path a client has for writing a
> `notifications/{id}` doc, and its reachability rule read:
> ```js
> const reachable = callerIsAdmin || (callerBranch !== "" && recipientBranch === callerBranch);
> if (!reachable) throw new HttpsError("permission-denied", …);
> ```
> **An admin has no `branchId`**, so for an admin recipient this compares
> `"" === "b1"` → false → `permission-denied`. A rule written to stop a
> cross-branch leak was catching the one role that is in no branch. Both
> callers (`NotifyTaskEvent`, `NotifySwapEvent`) are best-effort and swallow
> the error, so **it failed completely silently** — no doc, no push, no inbox
> row, no log on the device.
>
> What it removed: **an employee submitting a task for review notifies
> `task.createdBy`**, and an admin creates most tasks — the single most common
> admin notification in the product, refused every time. Same for every task
> event where an admin is an assignee (assigned · approved · rejected · rework
> · cancelled · reported-incorrect).
>
> **Blast radius beyond admins:** it threw *before* committing, so one
> unreachable recipient discarded the **whole batch** — a task assigned to
> three people, one of them an admin, notified **nobody**. Unreachable
> recipients are now skipped, counted, and returned as `skipped` (the doc is
> withheld exactly as before; it just no longer takes the legitimate
> recipients down with it).
>
> Policy is the pure `canNotify`
> ([functions/notification_reach.js](functions/notification_reach.js)) — admin
> reaches anyone, admin is reachable **by** anyone, everyone else same-branch;
> a blank branch never matches a blank branch. 9 tests.
>
> ℹ️ **Two branches found this independently and it merged into one fix.** The
> reachability half arrived with `claude/single-active-session-aedee1`
> (`canNotify`, kept); the **skip-instead-of-throw** half arrived with
> `claude/cursor-chat-visibility-notifications-003328`, whose duplicate
> `canReachRecipient` was dropped when both were cherry-picked onto
> `release/v1-preparation`. One predicate, one call site.
>
> ✅ **Push itself is healthy — owner-confirmed 2026-08-07.** Pushes arrive on
> the lock screen and tapping one opens the right screen. An earlier read of
> this bug blamed the missing APNs credential; that was wrong and is retracted
> (see [RELEASE_V1 B5](docs/RELEASE_V1.md), which now needs re-verification —
> delivery working implies the credential is in place).

> **Sales notifications reached no admin at all — FIXED, ⚠️ NEEDS A FUNCTIONS
> DEPLOY (2026-08-07):** `salesRecipients` resolved recipients from
> `where("branchId", "==", branchId)` and consulted admins only as a
> **fallback** when that came back empty. An admin has no `branchId`, so a
> branch query can never return one — meaning on every real branch an admin
> received nothing from the whole feature: no *New sales submission*, no
> *Corrected sales submission*, no *Sales target updated*, no *Sales target
> achieved*, in push **or** inbox. Admins are now an addition, matching
> `resolveRequestApprovers` / `resolveAttendanceReviewers`; the policy is the
> pure `selectSalesRecipients` in `functions/sales_target.js` (7 tests).
> `managersOnly` narrows the branch side only — an admin decides submissions,
> so they are a reviewer in both shapes. The **actor is now excluded** from
> sales notifications (a manager was previously told about their own target
> change). Inert until `firebase deploy --only functions`.
>
> ⚠️ **The admin is still absent from other event classes — by owner decision,
> not by oversight.** The same audit found: **task lifecycle** events
> (submitted / approved / rejected / rework / cancelled / reported-incorrect)
> reach assignees and `task.createdBy` only; **task reminders**
> (`runTaskReminders`) and **generated shift-task assignment** reach the
> rostered crew only; a **`branch`-audience broadcast** uses the same
> branch-query blind spot. **Missed tasks** keep admins as a deliberate
> fallback (`selectMissedNotifyTargets` — a manager-covered branch must not
> page an admin, or every miss in the estate lands in one inbox). If the owner
> later wants admins on task events, that is a one-line addition to
> `NotifyTaskEvent._recipientsFor` plus the `sendNotification` reachability
> path — but it is a **noise** decision, not a bug.

> **New Chat is search-first (2026-08-07, presentation only, NOT
> device-verified):** The teammate picker opened onto the entire org directory
> (org-wide by ADR-012), so a new conversation began with a scroll past
> everyone. It now opens on a focused search field and lists people only once
> something is typed — three distinct empty states (*No teammates yet* ·
> *Search for a teammate* · *No matches*). The directory read, its flat scope
> and the start-conversation path are unchanged; this is the view's filter
> only. Pinned by the rewritten `test/chat_new_conversation_test.dart`.

> 🚦 **V1 RELEASE GATE — [docs/RELEASE_V1.md](docs/RELEASE_V1.md).** The full
> release runbook, audited against code *and* live production on 2026-08-05.
> Read it before planning any release work; it is the authority on what blocks
> v1 and in what order. Short version: every automated gate is green, both
> platforms build a release artifact, and **the rules + functions deploy is now
> done and verified** — what still blocks v1 is the Android application ID
> (`com.example.*`, Play-rejected) and debug signing, the missing APNs
> credential, **no Firestore backups/PITR at all**, no production crash
> reporting, and QA that has never run on real hardware.

> ✅ **AUTOMATION P0 — FIXED *AND* DEPLOYED (2026-08-05).** Daily recurring
> routines had generated **nothing** since the 2026-07-31 functions deploy.
> `generateShiftTaskInstances`'s "temporary UTC-key transition guard" probed a
> legacy-keyed id before creating; at the pinned 01:00 Africa/Cairo tick the UTC
> date is always *yesterday*, and both key conventions share one id format — so
> it was reading **yesterday's ordinary instance**, finding it, and recording
> `skipped / alreadyExists`. Every run looked healthy: clean `automationRuns`
> row, `failureCount` 0, Automation Center saying "Already generated". Weekly
> routines were unaffected. The guard is deleted and the id convention now has
> one source (`recurringInstanceId`), pinned by tests.
> **The deploy landed 2026-08-05 13:16 UTC** — `generateShiftTaskInstances`
> (`00014-rob`), `runTaskReminders` (`00021-ges`) and
> `autoEndRecurringShiftTasks` (`00010-sab`) are all `ACTIVE`, verified via
> `gcloud functions describe`; the fix commit (`71792e7`) is 02:38 UTC, so the
> deployed source carries it.
> ⚠️ **Never observed working in production.** Watch one 01:00 Africa/Cairo tick
> end to end before calling it closed. Days missed before the deploy cannot be
> backfilled: generation is per-business-day and there is no catch-up path.
>
> **Automated shift tasks now get reminders (2026-08-05, deployed 13:16 UTC):**
> `runTaskReminders` skipped every task with an empty `assigneeIds` — which is
> every generated shift task — so the most important task class had one 01:00
> notification and nothing after. It now resolves the rostered crew via the
> generator's own `eligibleRecipients`, against the task's `instanceDate`. Quiet
> hours moved from UTC to Africa/Cairo (the 22→07 default was silencing
> 00:00–09:00 Cairo, i.e. the 08:30 morning-shift start) and fail **open**. The
> unbounded 30-minute scan is floored at 7 days and paged at 500. Notification
> ids are deterministic.
>
> **Rejected shift instances now close (2026-08-05, deployed 13:16 UTC, owner-ruled):**
> They previously reached no terminal at all — Late forever, never out of the
> active window, still surfacing for later days' crews, and absent from
> Approved ÷ (Approved + Missed), which made rejection score better than a miss.
> `rejected` joins `pending`/`started` in `AUTO_END_ELIGIBLE_STATUSES`, one
> constant now shared by the predicate **and** the sweep's query (drift between
> them is what caused the leak). `waitingReview`/`completed` deliberately stay
> out. `task.auto_missed` carries `fromStatus`. Second ruling: a rejected shift
> instance is the sole exception to "rejected is reminder-ineligible" — it gets a
> **Rework Needed** nudge on the existing ladder, because closing work
> automatically against an unsent message is not acceptable. Spec §3.7 + §9.5.
> No index change.
>
> ⚠️ **Still open from the same audit, not fixed** (reported 2026-08-05): the
> **auto-end sweep can starve**: one
> `limit(500)` slice ordered by deadline, from which manually-created shift tasks
> (no `sourceTemplateId`) are skipped but never leave — accumulate ~500 and Missed
> stops working. A **failed generation pages nobody** (a Missed task does).
> Routines **cannot be edited** (add/pause/delete only) though the server-side
> config-diff audit fully supports it. The ADR-011 execution record is **written
> daily and read by no screen**.
>
> **Edit-approved-amount reason is now optional (2026-08-07, feature, ⚠️ NEEDS
> FUNCTIONS DEPLOY):** On the sales submission detail's *Edit approved amount*
> sheet the reason is no longer required — owner call. Changed in both halves:
> the shared `showSalesTargetEditorSheet` gained `reasonRequired` (default true,
> so **Set/Edit target is unchanged**; edit-approved passes false) and
> `editApprovedDailySalesSubmission` now uses `salesReason(reason, false)` with the
> audit row storing `reason: null` when blank. Reject/correction/reopen/target
> reasons stay mandatory. ⚠️ **Inert until
> `firebase deploy --only functions:editApprovedDailySalesSubmission`** — the live
> callable still rejects a blank reason, so a blank save errors on device until
> deployed. Weakens the audit trail for a monetary edit (noted in SALES_TARGETS).

> **Branch sales manager dashboard re-enriched (2026-08-07, presentation + two
> pure domain helpers, owner-directed, NOT device-verified):** The manager
> branch-sales dashboard (`/sales`) was redesigned from a mockup signed off
> before any Dart. The month card now leads with **achieved · a monochrome
> progress ring · remaining**, then the target; the four Pending/Approved/
> Rejected/History `MetricTile`s — which all opened the **same** history screen
> with a different `?status=` — collapsed to **one** *All submissions* door with
> an inline count breakdown; and the previously-deleted pace strip returned as a
> single **Pace** card pairing a forecast-based target-outlook **verdict** with a
> **last-7-days approved-takings chart**. New pure, unit-tested
> `salesTargetOutlook` (in `sales_calculator.dart`) and `computeSalesTrend`
> (`sales_trend.dart`); both average over **approved days**, not elapsed calendar
> days, and the outlook reads off the forecast so a lagging approval can't fake
> "behind". New widgets `SalesProgressRing` · `SalesMonthOverview` ·
> `SalesPaceCard` · `SalesSubmissionsDoor`; `SalesMoneyRow` and every other sales
> surface are untouched, so the re-enrichment is this screen only. **Zero new
> reads** (derived from the snapshot already streamed), **strictly monochrome**
> (ADR-004 — ring/bars white/grey, colour status-only), no schema/rules/server
> change. Pinned by `sales_trend_test.dart`, new `salesTargetOutlook` cases in
> `sales_calculator_test.dart`, and `sales_dashboard_widgets_test.dart` (a 375pt
> overflow guard). Design doc [SALES_TARGETS](docs/design/SALES_TARGETS.md)
> updated. **Verified running on macOS desktop and iOS** (the dashboard renders
> end to end); GPS/hardware-specific QA still pending. A brand-accent (indigo)
> experiment was tried and **reverted**; what stuck is a **status tint**
> (`salesOutlookTint`): ACHIEVED, the ring and the today bar go **green ahead /
> amber behind / white too-early** — colour as status (ADR-004 holds, no brand
> accent). Not device-verified in its tinted state on iOS/Android hardware.

> **iOS swipe-back added; every back button kept (2026-08-05, NOT
> device-verified):** A pushed screen on iOS now carries the native interactive
> left-edge swipe **in addition to** its app-bar back button — both, always, as
> in Apple's own apps. The theme had been overriding Flutter's iOS default with
> `ZoomPageTransitionsBuilder`, which carries no gesture, and the 85 go_router
> pushes used `CustomTransitionPage`, which cannot. Seam:
> `core/routes/app_page_route.dart` (`appPageRoute`) + `CupertinoPage` in the
> router. Android and desktop unchanged.
> ⚠️ **What rots silently:** the gesture exists only on Cupertino routes, so a
> page pushed on a hand-rolled `PageRouteBuilder` loses it while every other
> screen keeps it — nothing *looks* broken. Pinned by
> `test/back_navigation_contract_test.dart`.
> Needs on-device QA: the edge swipe over horizontally scrolling content
> (`SegmentedTabBar` tabs, the schedule week strip) and inside the chat thread.

> **Notification taps: dead end, cold-start crash, silent drop — all fixed
> (2026-08-05, NOT device-verified):** Three reported symptoms, one root area —
> navigating a router that has no stack yet.
> - **"It opens the notifications page and I can't get Home."** The unresolved-tap
>   fallback was `go('/notifications')`, which replaces the whole stack. The inbox
>   carries no bottom nav (only the three role shells do) and could not pop, so no
>   back button was drawn on any platform. Every tap now goes through
>   `openNotificationDeepLink` — `go(home)` **then** `push(target)`.
> - **"Sometimes it errors."** `router.state` throws `Bad state: No element` on an
>   empty match list. Both tap paths read it, so the handler died mid-way.
> - **"Sometimes it doesn't open at all."** A cold start resolves the tap before
>   the routed app mounts (the splash intro is ~2s), and `push` onto an unattached
>   router is dropped — while `go` works, which is why the dead-end fallback was
>   the one path that landed.
> New `core/routes/router_extensions.dart`: `currentLocationOrNull` (never
> throws) + `whenReady` (defers the tap until the router has a stack, bounded at
> 120 frames). `openChatDeepLink` had the same two faults and is fixed with it.
> Pinned by `test/notification_tap_navigation_test.dart`.

> **Schedule stops re-reading on every visit (2026-08-05):** The admin Today
> board fired one **uncached roster query per branch** on every entry, behind a
> skeleton that blanked it each time, and screen entry called
> `BranchCubit.load()` unconditionally — emitting `loading()`, which blanked
> every branch-identity surface in the app. Entry now uses `loadIfNeeded()`;
> `TodayCoverageCubit` has a 5-minute window keyed on the branch set **and** the
> day, and a forced refresh no longer blanks the board it is refreshing.
> `ScheduleCubit._freshFor` 60s → 5 min (a minute is shorter than one trip
> through the app, so every return still paid for a full reload). Refresh,
> pull-to-refresh, a scope change, any local mutation, and `SwapRosterSync` on an
> approved swap all still bypass the windows. Returning to the Today tab after
> editing forces a re-derive, deliberately. Pinned by
> `test/schedule_read_caching_test.dart`.

> **Premium mobile role-home bar (2026-08-05, presentation only):** The shared
> admin/manager/employee `RoleScaffold` header now uses a restrained gradient +
> bottom hairline, groups daily actions inside one flat glass capsule, and gives
> the account avatar its own surfaced control. Every destination and role-based
> action remains unchanged. All controls have ≥44px targets and tooltips;
> notifications announce their unread count and the avatar announces whose
> settings it opens. The manager worst case (four actions + avatar) is covered at
> 320px with no overflow. Desktop chrome is untouched.

> **Automation details sheet redesign (2026-08-05, presentation only):** The
> routine details sheet now respects the device safe area and keeps a labelled
> 44px Close action pinned above its scrollable content. Its first view is a
> compact schedule/next-check snapshot, latest outcome and last generated task;
> priority, checklist, assignment, timing notes and the Missed policy move under
> collapsed **More details**. Pause/resume, confirmed delete and last-task
> navigation keep their existing behavior and data paths.

> **Manager open-shift clock + honest managersCanClock toggle + branch settings
> redesign (2026-08-06, feature/bug/polish, NOT device-verified):** Three owner
> asks about manager attendance and branch settings.
> - **Managers now have a real open shift.** A manager's clock is presence
>   tracking (`enforceSchedule: false`), but the **primary** Clock In fell
>   through silently for a shift-less manager (`_resolveContext` set no
>   `targetRecordId`/`shift`), so their only route was the buried "unscheduled
>   shift" button behind a "No shift today" message. `_resolveContext` now
>   synthesizes a presence-only target (time-of-day bucket, no scheduled window)
>   for a presence role with no rostered slot, and drops the window even when a
>   manager *is* rostered. The screen reframes to an **OPEN SHIFT / Manager
>   shift** ready state with Clock In as the primary action.
> - **"Managers can clock in / out" now actually does something.** The screen
>   never read `config.enabled`, so the branch toggle changed nothing on device.
>   New `disabled` phase: a switched-off branch shows an explanatory *"Clocking is
>   off for managers here"* card + a Review-branch-attendance door. A live session
>   always wins the phase check, so flipping the flag can't trap someone mid-shift.
> - **Branch settings sheet redesigned** into grouped, labelled sections with a
>   grab handle and per-row glyphs. The two rules the owner flagged now read in
>   plain language: **Same role only** and **Minimum rest** (both with concrete
>   examples). No behaviour/data change — same `createBranch`/`editBranch`.
> - Managers gain a **My Clock** desktop sidebar door; the self-hosted Phosphor
>   subset gained the `clock` glyph (0xe19a — TTFs are full fonts, no re-subset).
> Pinned by 4 new `attendance_cubit_test` cases +
> `test/attendance_open_shift_screen_test.dart` (open-shift ready vs. disabled).
> **Branch-attendance oversight for managers was already shipped** (Manager Home →
> *Branch attendance* → the live Late/Early/Absent board, branch-pinned) and is
> unchanged.
>
> **Opening a chat clears its delivered OS notifications (2026-08-06,
> feature/bug, NOT device-verified):** 5 messages from one conversation arrive
> while backgrounded/closed; opening it left all 5 in iOS Notification Center.
> Root cause: nothing cleared delivered notifications, and `firebase_messaging`
> can't. The backend already stamped `apns.thread-id`/`android.collapseKey` with
> the conversation id, so this was a missing client step. New native channel
> `drop/notifications` (the app's first): iOS `UNUserNotificationCenter` removes
> by `threadIdentifier`, Android `NotificationManager` cancels by `tag`; `clearAll`
> on sign-out. Backend now also sets `android.notification.tag = conversationId`
> (⚠️ **Android clearing is inert until drop-api is redeployed**; iOS needs no
> backend change). Wired into the existing read-state seam — the
> `createChatConversationCubit` `onReadSync` closure clears the thread's
> notifications when the server confirms mark-read; other conversations keep
> theirs. New `core/services/delivered_notifications.dart` (swallows
> `MissingPluginException` → desktop/test no-op). Note: shared Android `tag`
> collapses a conversation to one notification. Pinned by
> `test/delivered_notifications_test.dart` + updated backend
> `chat-push.subscriber.spec`. ⚠️ **NOT device-verified** — needs a real
> background→open→read cycle on iOS + Android hardware, and the drop-api redeploy
> for Android.

> **Chat reconnects on app resume — inbox no longer goes silent (2026-08-06,
> bug, NOT device-verified):** Investigating the reported "messages don't arrive
> live / a message disappears." Root cause of the **not-live** half: the app had
> **no global app-lifecycle observer** (the only one was the open-thread screen).
> The shared inbox socket is an app-wide singleton; the OS suspends its transport
> in the background, and **when no thread is open nothing reconnected it on
> resume** — it stayed dead until a manual refresh. New `ChatRealtime.onAppResumed()`
> (port + `ChatSocketService`, with `_ensureConnected(forceReconnect:)`) force-
> reconnects a stale/dead socket on resume (leaving a healthy one untouched);
> `ChatListCubit.onAppResumed()` forwards it; `ChatNotificationListener` (the one
> global chat host) now observes lifecycle and calls it on resume. A reconnect
> re-joins rooms and fires `ChatRealtimeConnected(isReconnect)`, which already
> refreshes the inbox and reconciles any open thread. **The "disappear" half:**
> text sends are durable (Drift outbox written *before* dispatch, dedupe-retried),
> so they reappear on reopen/refresh — the visible vanish is the same not-live
> staleness. ⚠️ **Attachment (photo) bytes are still never persisted** — a photo
> caught mid-send by a crash is lost (noted, unchanged). Pinned by
> `test/chat_list_realtime_test.dart`. Needs a real background/resume cycle on
> hardware to confirm.

> **New/renamed teammates resolve without an app restart (2026-08-06, bug,
> NOT device-verified):** A just-provisioned employee showed as **"Teammate"**
> in chat and **"Someone"** on a task assigned to them until the app was
> relaunched. Two in-memory people-directory caches lived the whole session:
> the chat directory (`AppDependencies._chatDirectory`, cached to sign-out) and
> the task directory (`TaskCubit._directory`, memoized per branch). The chat one
> now has a **5-minute TTL** + `forceRefresh`; the task one gains
> `refreshDirectory()` (drops the `_fetchedBranches` memo, re-enriches from the
> open task set). **Both are invalidated immediately** on any admin user-set
> change via new `AppDependencies.invalidatePeopleDirectories()`, wired through
> a new optional `AdminUsersCubit(onUsersChanged:)` fired after `createAccount`
> and every `_mutate`. Chat is stale-while-revalidate (kept warm, no "Teammate"
> flash) and proactively force-refreshed for the caller. Pinned by
> `test/admin_users_directory_invalidation_test.dart`. ⚠️ **Realtime
> "message disappears / not live" and the notification/APNs work from the same
> report are NOT addressed here** — only the directory-staleness half.

> **Task Details attributes and schedules honestly (2026-08-06, presentation +
> one new pure domain file, NOT device-verified):** A generated shift task now
> says it was made by **System · Automated task** (with the template's owner kept
> as a *"Set up by …"* footnote) instead of showing only `Morning Shift`, and the
> activity timeline signs the server's own events *System* + an **AUTOMATED**
> chip instead of the anonymous *"Someone"* — `actorId: "system"` is not a uid and
> never resolved in the directory. Origin is decided by the new pure
> `task/domain/task_origin.dart`, because `createdBy` is inherited from the
> template and therefore cannot answer the question. The three date-only schedule
> chips (`Starts 6 Aug 2026 · Due 6 Aug 2026 · Est. 8h`) became one banded
> **Starts · Due · Window** row with 24-hour clock times and a relative day line
> (new shared `AppDateFormatter.relativeDay`); *Window* replaces the misleading
> *Est.*, since the value is `dueAt − startsAt`, not an effort estimate. Pinned by
> `test/task_origin_test.dart` + `test/task_details_origin_test.dart`.

> **Submission overlay is now just an animated Lottie loader (2026-08-06,
> presentation only, NOT device-verified):** The full-screen "Submitting task"
> overlay shown while a completion's media uploads
> (`task/presentation/widgets/submission_loading_overlay.dart`) was stripped
> (owner: *"just … put the lottie file no text nothing else"*) to **only** the
> centered Lottie over the input-absorbing dim barrier — no title, progress bar,
> stage text, dot indicator, or Cancel. Owner-supplied `assets/LKSRCGVJH6.json`
> was renamed to `assets/submission_loading.json` and registered in
> `pubspec.yaml`. The export's animated fill colours are forced to
> `AppColors.primary` via `LottieDelegates` so it stays monochrome (ADR-004);
> reduced motion collapses it to a still frame. The cubit-driven
> `SubmissionProgress` contract is retained on the widget but unused visually.
> Only appears during a real upload, so it is not device-verified.
>
> **Branch-sales notifications were impersonating tasks, and their push lost the
> record (2026-08-06; client half live, ⚠️ SERVER HALF NEEDS A FUNCTIONS
> DEPLOY):** `writeSalesNotifications` stamps `type: "salesSubmission"`, which the
> `NotificationType` enum never had — so `NotificationModel.fromMap`'s
> unknown-type fallback made every sales notification a `taskAssigned`: clipboard
> glyph, **Tasks** filter pill, `high` priority above genuinely overdue work.
> Fixed with the enum value, a **Sales** pill, a point-of-sale glyph and `normal`
> priority. Two server-side halves went with it and are **inert until
> `firebase deploy --only functions`**: a month event ("target updated" /
> "achieved") now writes `route: "sales_target"` instead of a `sales_submission`
> route it had no id for (the id-less `sales_submission` case is kept, so inbox
> docs written before today still resolve), and `onNotificationCreated` now
> forwards `salesSubmissionId` + `monthKey` in the push `data` — without them a
> *New sales submission* tapped from the OS reached the branch dashboard, never
> the record to review, while the in-app inbox worked because it reads the
> Firestore payload directly.

> **Starting a task reads as instant (2026-08-06, presentation only, NOT
> device-verified):** The reported "delay that seems like lag but works" was the
> UI, not the write: for the 100ms–1s of the Firestore transaction the **Start
> task** button dimmed to the disabled 50% and sat dead, then the new action
> replaced it in a single frame. The tapped button now acknowledges the press on
> the frame it happens — full weight, a progress ring where its glyph was
> (`PremiumButton.isLoading`, new; `AppButton` already had one) — and the next
> action arrives through the new `ActionSwap` (`core/widgets/app_motion.dart`,
> 200ms in / 130ms out over an `AnimatedSize`). It carries Start → Continue on
> Employee Home, Start Task → Mark Complete → Submit for Review on Task Details,
> the *Mark Complete* → submission-form expansion, and the card status pill;
> `TaskAttentionSurface` eases its 1px tone over 240ms instead of cutting.
> **The round trip is unchanged — no status is written optimistically.** The
> in-flight ring is per-card local state (the cubit's `busy` is global) and ends
> on whichever arrives first, the new status or the mutation ending without one,
> so a refused start cannot strand a spinner. Reduced motion collapses every one
> of these to an instant swap. Pinned by
> `test/task_start_transition_test.dart`.

> **Settings — Notifications preferences + Appearance placeholder (2026-08-06,
> NOT device-verified):** A **Preferences** section under the account card opens
> a new `NotificationsSettingsScreen` (`/settings/notifications`) with six
> switches — Enable Notifications · Task Reminders · Schedule Updates · Case
> Messages · Announcements · Sound. The master switch dims and disables the
> other five **without clearing them**.
> ⚠️ **Local-only and not yet connected to delivery.** Values live in a
> uid-namespaced JSON file via `core/services/notification_preferences_store.dart`
> (the `CaseSeenStore` mechanism; no `shared_preferences`, no Firestore, no
> rules change). **Nothing consumes them** — an employee who turns Task
> Reminders off still receives them. Wiring `NotificationService` / the server
> reminder ladder to the store is the open follow-up, and the moment
> preferences must survive a reinstall or apply across devices they need a
> Firestore home.
> **Appearance is a deliberately inert row** — a monochrome COMING SOON label,
> no screen, no theme switching (DROP is dark-only, ADR-004).
> The Settings row widgets moved unchanged to
> `features/settings/presentation/widgets/settings_tiles.dart` so both screens
> share one row. Pinned by `test/features/settings/` and the extended
> `test/settings_page_test.dart`.

> **Profile screen rebuilt (2026-08-07, presentation only, NOT device-verified):**
> The account's own page was a 64px avatar, a flat list of label→value rows and
> three action tiles; it now reads as the sibling of the Settings hub. New
> compact identity lockup (cover + overlapping avatar + name + `[ROLE] @handle`
> + bio + one CTA), facts grouped into **Workplace · Contact · Account**, and
> rows that act: **tapping a self-service detail opens Edit Profile** (set or
> not) while **copy is its own 44pt button**, so reading a value out and
> correcting it no longer compete for one gesture.
> - **Two fields that existed but were never shown now are:** `coverImage` (was
>   uploadable from Edit Profile and visible nowhere) and `bio` (editable, never
>   rendered).
> - ✅ **The username had no input anywhere in the app**, while
>   `ProfileEntity.isComplete` requires it — so **every account was permanently
>   "incomplete"** and the prompt could never be satisfied, even though the
>   datasource, repository, `CheckUsername` and the cubit's taken-handle
>   rejection were all wired. Edit Profile now has the field
>   (`Validators.username`: 3–20 chars, letters · digits · `.` · `_`, starts
>   with a letter, stored lowercase). The prompt also names what is *actually*
>   missing rather than always asking for both.
> - ✅ **Settings is the account hub; Profile is a leaf of it** (owner ruling,
>   same day). Profile had a **Settings** row while Settings' identity card
>   opens Profile — a closed loop — and both carried their own **Sign out**, so
>   the app's one destructive action lived on two screens. Profile now carries
>   neither, and the **desktop sidebar footer opens Settings** instead of
>   Profile, so both platforms have one door in. Do not re-add a navigation row
>   to Profile; add it to Settings.
> - **Profile never states `paymentNumber`** (owner ruling, same day) — for any
>   role. It is set and changed in **Edit Profile** only; the schema and the
>   private compensation subdoc are unchanged.
> - **`settings_tiles.dart` moved to
>   [core/widgets/](lib/core/widgets/settings_tiles.dart)** — Profile shares the
>   grouped-row vocabulary and a feature must not import another feature's
>   widget. Classes/behaviour unchanged; the two Settings screens changed one
>   import each.
> - An admin is offered no *add* door onto a form field they do not get. A
>   **global admin has no `branchId`**, so the branch row states *All branches ·
>   organisation-wide* rather than sitting empty.
> - Also: pull-to-refresh (`forceRefresh`), the shared `AppErrorState` replacing
>   a bespoke failure surface, a skeleton matching the new shape, and
>   `ProfileEntity.initials` replacing the duplicated private helper.
> Pinned by `test/features/profile/profile_page_test.dart` (9, including one
> that fails if Profile grows a second hub or a second Sign out) +
> `test/features/profile/edit_profile_username_test.dart` (3).

> **Task review notifications now find a live reviewer (2026-08-07, client-only,
> NOT device-verified):** `taskSubmitted` routed to `task.createdBy` and stopped,
> which is **silence** — a task left in `waitingReview` with nobody told and no
> error anywhere — whenever that account was deactivated, hard-deleted, demoted
> to employee, or moved branch. The last two are worse than silence: rules refuse
> their approval, so it notified the one person who *cannot* act and nobody who
> can. A generated shift task made it routine, not exotic: it inherits the
> **template's** `createdBy`, so a template set up by someone who has since left
> produced a task **every day** whose submission notified a dead account.
> New pure ladder (`task/domain/task_review_routing.dart`): **creator, if they
> can still review it → the branch's active managers → active admins.** The gate
> mirrors the `tasks` update rule in `firestore.rules`. **No new business rule
> was invented** — the escalation is the same shape as the server's existing
> `salesRecipients(managersOnly: true, adminsFallback: true)`. Reads stay on the
> rare paths: one branch read, an individual creator lookup only for a
> (branchless) admin creator, and the org-wide read only when the branch has
> nobody. Pinned by `test/task_review_routing_test.dart` +
> `test/task_submitted_recipients_test.dart`.
> ⚠️ Its tier-3 admin escalation reaches nobody until the
> `functions:sendNotification` deploy below lands.
>
> **The paged notification sweep is now verified rather than manually QA'd
> (2026-08-07):** the paging moved into `sweepPages`
> (`notifications/data/datasources/notification_sweep.dart`), generic over the
> page item, so it is testable apart from Firestore. 23 tests run it over 5,000-
> and 15,000-item sets, across page boundaries, and with a commit that *deletes*
> what it touched. **It caught a real off-by-one**: a collection ending exactly
> on the 15,000 ceiling threw "too many notifications" after successfully
> sweeping all of them. The ceiling is now checked after the fetch. Also pinned:
> no batch approaches Firestore's 500-op cap (the page size *is* the batch
> ceiling), and the cursor advances off the last item **fetched**, not the last
> **committed**.

> ✅ **Trunk now matches production (2026-08-07).** The 03:12 UTC functions
> deploy was run from the `claude/single-active-session-aedee1` worktree, which
> briefly left `release/v1-preparation` carrying the **old branch-only
> reachability check** — so a deploy from trunk would have silently reinstated
> the outage where no employee or manager can notify an admin. The branch is
> **merged**, so trunk is safe to deploy functions from again.
> Worth keeping as a standing hazard: deploying from a worktree puts production
> ahead of trunk, which is the inverse of the 2026-07-31 incident (deployed
> source lagging the repo) and the more dangerous direction, because nothing
> about it looks broken.

> ✅ **Notification audit — a silent delivery outage, FIXED AND DEPLOYED
> (2026-08-06, deployed 2026-08-07 03:12 UTC):** `sendNotification`'s reachability check was a
> branch comparison only, and **an admin has no `branchId`** (the role is
> global). So `recipientBranch === callerBranch` compared `""` against the
> caller's branch and **no employee or manager could ever notify an admin** —
> meaning **every task an admin created was submitted for review and the admin
> was never told.** The callable threw `permission-denied` and
> `NotifyTaskEvent`'s catch-all swallowed it to a log, so the employee saw a
> normal successful submission. Generated shift tasks whose template an admin
> set up were affected too (the instance inherits the template's `createdBy`).
> The rule is now pure and tested in `functions/notification_reach.js` — **admin
> → anyone · anyone → an admin · otherwise same branch**; cross-branch stays
> denied and nothing about what may be *sent* changed.
> ✅ **DEPLOYED AND VERIFIED (2026-08-07 03:12 UTC).** `sendNotification` rolled
> to `sendnotification-00013-hum`, state `ACTIVE`. Verified the hard way, not
> from the CLI's report: the deployed `function-source.zip` was pulled from
> `gcf-v2-sources-450092605249-us-central1` and both `index.js` and
> `notification_reach.js` are **byte-identical** to the repository, with
> `canNotify`'s `to.isAdmin` clause present. The **second** pending functions
> change (branch-sales push payload + `sales_target` route, 2026-08-06) shipped
> in the same run — `onNotificationCreated` → `00005-foh`,
> `setBranchSalesTarget` → `00004-kij`, all `ACTIVE` at 03:12:4x–5x.
> ⚠️ **Never observed working in production.** An employee submitting an
> admin-created task for review is the end-to-end confirmation; it has not been
> watched happen.
>
> **Four client-side correctness fixes shipped with it (live in the next build,
> no deploy):**
> - **`markAllRead` was broken past 500 unread** — one unbounded read plus a
>   single `WriteBatch`, and Firestore hard-caps a batch at 500. Past that it
>   failed with `INVALID_ARGUMENT` and, because the cubit swallowed errors, the
>   button silently stopped working *forever*. `runTaskReminders` fires every 30
>   minutes per task, so 500 is reachable.
> - **`Clear archived` only cleared the loaded page** (30) while its dialog
>   promised *"delete all archived notifications"*. Both now use one paged sweep
>   over the **existing** index (no new index, no deploy), are
>   `NetworkGuard`-guarded, and **report failure** instead of swallowing it.
> - **An unknown `type` impersonated a task** — `fromMap` fell back to
>   `taskAssigned`, which drives glyph + pill + priority. That is the mechanism
>   behind the sales-notification bug; adding `salesSubmission` fixed the
>   symptom only. New `NotificationType.unknown` ranks `low`, shows under **All**
>   and no pill, and **still deep-links** (routing keys off `payload.route`).
>   This matters because functions-first deploys are the *correct* order, so a
>   window always exists where the server writes types the app doesn't know.
> - **The due label was on a different clock** from Task Details (`Due today
>   4:30 PM` vs `16:30`). Now `AppDateFormatter` + an injected clock; earns
>   `Tomorrow` for free.
> ✅ **Both follow-ups from this audit are now closed (2026-08-07)** — the
> reviewer ladder and the sweep's test coverage; see the entry below.

> **Clear chat drains the whole history (2026-08-07, client-only, NOT
> device-verified):** `clearChatForMe()` deleted only the messages already paged
> in, while its dialog promised *"removes **every** message from your view"* — so
> on any thread longer than the first page the older ones came back on scroll-up.
> *Delete conversation?* ran the same call and had the same gap. It now pages
> back through the full history via the existing `LoadChatHistory` use case,
> collects every server-confirmed id, then makes one pooled delete-for-me pass.
> **All or nothing on the collect step** — if the history can't be drained
> completely, nothing is deleted and the failure is retryable; a half-clear
> against "every message" is the bug being fixed. A cursor that doesn't advance
> raises, and a 500-page bound catches any other non-terminating history (both
> mean the pagination is wrong, not that the chat is long). `loadOlder` and
> single-message delete stand down while a clear runs. No new backend endpoint.
> Per-message *Delete for me* was already correct across all four tiers (REST →
> in-memory → Drift row → session cache) and is unchanged.

> 🔴 **FALSE EVICTION — FIXED (2026-08-07, client-only, NOT device-verified).**
> First field report of the feature below: *"I open my account, log out on the
> device, then log in on another device and it says your account has been signed
> in on another device."* No second device was involved.
> **A cached Firestore snapshot was being read as a hostile login.**
> `snapshots()` replays the **locally cached** document the instant you
> subscribe, so a device that had been signed in before received its *previous*
> session's `activeSessionId` as the watcher's first emission — while it already
> held the id it had just claimed. Mismatch → teardown → Login with the takeover
> message. The very first device on a fresh account never reproduced it, because
> its cached document carried a **null** id, which the back-compat rule already
> ignores; that is why this shipped looking correct.
> Fixed in two narrow places: `watchUser` now emits **server-confirmed snapshots
> only** (`!metadata.isFromCache` — every consumer of that stream ends a session,
> so none of them may act on a cached copy), and `AuthCubit` **forgives the one
> id it superseded** until its own claim comes back. Any *other* mismatch still
> evicts on the spot, so a genuine takeover racing a sign-in is enforced live.
> ⚠️ **The test fake is why this shipped green:** it returned a bare
> `StreamController`, which emits nothing on subscribe, so no test ever
> exercised Firestore's replayed first snapshot. It now models the cached
> replay. +6 tests, including the reported A-signs-out → B-signs-in sequence.
> Amendment recorded on [ADR-023](docs/decisions/ADR-023-single-active-session.md).

> **Single active session — one account, one signed-in device (2026-08-06, NOT
> device-verified):** A newer sign-in now evicts every older one. `AuthCubit`
> mints a session id at sign-in, claims it on `users/{uid}.activeSessionId`, and
> keeps it on this device in the platform keystore
> (`core/services/session_store.dart`, new `flutter_secure_storage`). Enforcement
> rides **the stream that already existed** — `watchCurrentUser`, run since day
> one for deactivation/hard-deletion — so it costs no extra listener and **no
> feature carries a copy** (Chat included). The evicted device signs out, tears
> everything down, and lands on Login saying *"Your account has been signed in on
> another device."* Design:
> [AUTH § Single active session](docs/design/AUTH.md#single-active-session) ·
> [ADR-023](docs/decisions/ADR-023-single-active-session.md).
> - **Neither null is an eviction.** A null remote id is every legacy document
>   and every account that has not signed in since this shipped — treating it as
>   a mismatch would sign the whole company out on upgrade day. A null local id
>   is an unreadable keystore, which must not look like a hostile login.
> - **A failed claim fails the sign-in.** Entering the app on a claim the server
>   never recorded self-evicts on the next snapshot, which reads as *"it signed
>   me out instantly"*.
> - **No rules change, no deploy** — `activeSessionId` is not in the `users`
>   update rule's privileged freeze-list, so the owner-update clause already
>   permits the self-write. **Verified against the emulator**, not reasoned: a
>   denied claim would mean a failed sign-in for *everyone*, and the Dart suite
>   never evaluates a rule. New `firestore-tests/user_session.rules.test.mjs`
>   (6 cases) pins that the owner may claim and that **nobody may claim someone
>   else's** — the write that would sign a stranger out.
>
> **Sign-out now actually tears the session down (same change).** New
> `AppDependencies.clearUserScopedState()` resets every app-wide cubit holding a
> user-scoped Firestore stream (`task` · `caseList` · `requestsList` ·
> `attendance` · `shiftSwap` · `salesMonth` · `notification`; each gained a
> `reset()`). **This fixed a pre-existing leak on ORDINARY sign-out:** those
> cubits are singletons built once at `init()`, so their listeners — and
> `AttendanceCubit`'s live ticker — kept running against a signed-out user, and
> the next person to sign in on the same device saw the previous one's tasks,
> cases, requests and attendance until each screen's first refresh landed.
> Eviction and sign-out now share one teardown path.
> ⚠️ **Client-enforced — session hygiene, not a security boundary.** A modified
> client could simply not watch the document; real revocation is
> `admin.auth().revokeRefreshTokens(uid)` server-side.
> ⚠️ **The two-device eviction has NOT been run on hardware**, and this adds one
> native dependency. `flutter build macos --debug` succeeds with it; macOS
> already carries the `keychain-access-groups` entitlement and Android `minSdk`
> 24 clears the `encryptedSharedPreferences` floor (23) — but **no iOS or
> Android build has been made with the plugin**. Pinned by
> `test/single_active_session_test.dart` (18 tests).

> **Launch hint: "You have N unread messages" (2026-08-06, presentation +
> one additive router-extension getter, NOT device-verified):** Unread chat had
> no launch-time signal at all — the bottom nav carries no badge (deliberately,
> and it must not grow one), so a message that arrived while the app was closed
> was invisible until the user opened Chat. New `ChatUnreadLaunchHint`
> (`features/chat/presentation/widgets/`) is mounted above the router beside
> `ChatNotificationListener`: on the **first settled** `ChatListState.loaded` of
> a launch it slides one small glass banner down from the top — *"You have 4
> unread messages." · "Tap to open Chat."* — holds 3.5s, then dismisses itself.
> Tapping pushes `/chat`, the same destination the bottom nav's Chat tab pushes,
> so Back returns where the launch landed. **Zero new reads:** it observes the
> inbox load `ChatNotificationListener` already triggers on authentication.
> - It waits for the *settled* load on purpose — the durable-cache paint arrives
>   first with `refreshing: true` and no server counts, so announcing off it
>   would read "no unread" on every cold start that had a cache.
> - Consuming exactly one settled emission is also what makes it once-per-launch;
>   a message arriving later is `ChatNotificationListener`'s banner, not this one.
>   A sign-out + second sign-in inside one launch does **not** re-arm it.
> - Reduced motion collapses the slide to an instant show/hide.
> ⚠️ **The suppression check needed a new router reader.** "Don't show it if the
> user is already on Chat" cannot be answered by `currentLocationOrNull`: it
> reports the match list's `uri`, which an imperative `push` never rewrites, and
> **every** chat destination is reached by `push` — so after the cold-start chat
> deep link (`go(home) → push(/chat) → push(thread)`) it still says `/manager`
> while the thread is on screen. New additive `topLocationOrNull` reads the top
> match instead; `currentLocationOrNull` is untouched and keeps its duplicate-push
> guard. Pinned by `test/chat_unread_launch_hint_test.dart` (8 tests, including
> the pushed-on-top-of-home case the old reader gets wrong).

> **Premium Settings account hub (2026-08-05, presentation only):** Settings now
> leads with a tappable signed-in identity card (real avatar, name, email and
> role), then separates Security, Workspace and Drop Operation information into
> shared glass surfaces with clearer supporting copy. Sign out is isolated as a
> deliberate destructive action, version metadata stays visible, and the page
> enters with the shared restrained stagger motion. All existing routes/actions
> are unchanged.

> **Branch Monthly Sales Target — built, audited, awaiting redeploy + QA (2026-08-05):**
> Per-branch monthly targets, daily employee closes, manager/admin approval,
> derived-on-read progress, admin all-branches management, notification routing and
> derived pace KPIs. Design: [SALES_TARGETS](docs/design/SALES_TARGETS.md) +
> [ADR-022](docs/decisions/ADR-022-branch-sales-monthly-ledger.md). A **derived
> ledger** — deterministic `branch_sales_months` / `branch_sales_submissions` docs,
> approved total re-summed on read, no stored accumulation; **server-authoritative**
> callables for every monetary transition; **`Africa/Cairo`** keys; piastres money;
> reused audit + notification seams.
>
> **A post-implementation audit on 2026-08-05 fixed nine real defects** — see the
> CHANGELOG entry for the full list. The load-bearing ones:
> - `isManagerArea` matched `/sales` by **prefix**, so `/sales/submit`,
>   `/sales/mine`, `/sales/history` and `/sales/submission/:id` were all
>   manager-only. **Every employee was bounced to Home** from their own submit
>   screen, their own records, and the sales notification deep link. The whole
>   employee half of the feature was unreachable.
> - **Resubmit-after-correction had no caller.** `ResubmitCorrectedSales` was wired
>   into DI but no cubit or screen used it, so `correctionRequested` was a dead end.
> - **"Needed per day" read `0 EGP` on the last day of every month** while the
>   branch was still short (exclusive day count), and **"Average per day" divided by
>   elapsed calendar days**, understating pace daily because approvals lag.
>
> **New: per-branch opt-in.** `branches/{id}.salesTargetEnabled` (**admin-only,
> default `false`**). Off ⇒ the feature does not exist for that branch: no Home
> card (and no gap where it was), no sales pages, no target management, no
> submissions. Enforced in the client, in `firestore.rules`, and in
> `setBranchSalesTarget`. Deciding **already-open** records stays allowed when a
> branch is switched off, so nothing is stranded.
>
> Owner sign-off (P0) stands: peer visibility = **approved-only**; employee
> back-date = **current + 3 Cairo days**.
>
> **UX pass (same day):** everything collapses to **target · achieved ·
> remaining** via one shared `SalesMoneyRow`; the only statistic left is **Needed
> per day**, which is also the only colour (today's close vs. what a day needs —
> ≥100% green, ≥50% amber, below red, monochrome when there is nothing to judge).
> Progress bars/percentages, the Pace strip, the recent-approved list and the
> employee history table are gone. Pending/Approved/Rejected/History are now four
> separately filtered destinations. Admin Home gained a self-gating Branch sales
> summary. **`formatEgp` shipped a leading-comma bug** (`945000` → `,945,000`) —
> fixed and regression-tested. Naming corrected throughout: the target belongs to
> the **branch**, so every role's destination is "Branch Sales" and the employee
> page reads "TEAM TARGET".
>
> Gates green: `flutter analyze` clean · `flutter test` **1670 pass** (1641 when the feature landed) ·
> `functions` node --test **112** · `firestore-tests` **68**.
> ✅ **The server half is DEPLOYED and verified (2026-08-05).** Rules released
> **18:32:57 UTC** and re-read from the Rules API as **byte-identical to
> `firestore.rules`** (so the `branchRunsSalesTargets()` gate is live); all 5
> sales callables rolled to revision `…-00002-*`, `ACTIVE`, **18:34 UTC**, after
> the audit commit. The 4 `branch_sales_submissions` composite indexes were
> already live and `READY`. **What remains is shipping the client build, then
> on-device QA** — production carries the server contract already.
> ⚠️ **Production branch state:** `Drop The shop | Arkan` has
> `salesTargetEnabled: true`; `Marassi` and `LMD` are opted out **and inactive**.
> So today the feature exists for exactly one branch.
> **Manager Home now states the month (2026-08-05, NOT device-verified):**
> Employee Home and Admin Home both carried the figures while the one role
> accountable for them — the manager sets the target and approves every close —
> got a *Branch sales* digest row with **no amount**. Manager Home now renders
> the same `SalesTargetCard` (target · achieved · remaining) under *On shift
> today*, on mobile and desktop, opening `/sales`. The digest row is **deleted**:
> it was duplicated navigation, and it was the one sales surface that never
> consulted `salesTargetEnabled`, so an opted-out manager was offered a door onto
> the Disabled screen. The card gates itself **and its spacing** — an opted-out
> branch shows nothing, not even a gap.
> Fed by the new `SalesMonthCubit.loadForBranch` — `loadForEmployee` minus the
> own-submissions stream, since a manager never closes a day, so Home costs two
> listeners rather than three. ⚠️ The submission getters on `SalesMonthLoaded`
> are **meaningless in branch mode**: `canSubmitToday` reads `true` off the
> target alone because it is asking about an employee the cubit does not have.
> Home renders `snapshot` only; never drive a submit CTA off a branch-mode
> state. Pinned by `test/features/sales/presentation/sales_month_cubit_test.dart`
> and `test/manager_home_test.dart`.
> ⚠️ **Known divergence:** the Dart client hand-rolls Cairo DST (last Friday of
> April/October) while the callables use `Intl` with real tzdata, which also
> suspends DST during Ramadan. The two can disagree on the civil date for a few
> hours a year. The server is authoritative for validation; a shared tz source is
> the open recommendation.

> **Swap workflow reliability + history (2026-08-05):** The manager/admin swap
> sheet captures its height before opening, avoiding the deactivated-context
> `MediaQuery` crash during a schedule rebuild. It is always reachable as **Swap
> history**, separates open requests from resolved records, and approved swaps
> name the manager/admin and decision time. `approveSwap` persists that reviewer
> attribution atomically with the roster exchange and includes it in the employee
> approval notification.
> Legacy records without stored actor attribution intentionally show no invented
> person; a real name is shown only when it was persisted with the decision.
> The mobile schedule always exposes the Swap history control, including when
> there are no pending requests.
> ✅ **The server half is DEPLOYED (2026-08-05 00:35 UTC).** It was the reason no
> name appeared on device: the attribution write landed in `functions/index.js`
> at `b76cbac` (00:04 UTC) while production still ran `approveswap-00013-taz`
> from **2026-08-04 13:16 UTC**, so approvals were stored with no
> `managerApprovedById/Name/At` and the card honestly rendered nobody.
> `firebase deploy --only functions:approveSwap` rolled it to
> **`approveswap-00014-ceq`, state `ACTIVE`** — verified via
> `gcloud functions describe`, not just reported by the CLI.
> ⚠️ **Swaps approved before that moment stay unattributed forever** — the
> fields are written only at decision time and there is no backfill source. The
> first *newly* approved swap is the real end-to-end confirmation. Those records
> now read **Approver not recorded** instead of showing nothing at all.
>
> **The "sometimes it approves, sometimes it doesn't" bug is FIXED (2026-08-05,
> client-only).** It was never the callable failing at random: a **stale roster**
> produced requests the server can never approve, and the refusal was invisible.
> `ScheduleCubit` is a one-shot read and only refreshed on a *local* mutation
> settling, so the device that did not press Approve kept the pre-swap week; a
> swap requested off it names a shift its requester no longer holds and
> `approveSwap`'s slot-integrity check refuses it permanently. Verified in
> production: the 00:23:33Z approval rewrote
> `weekly_schedules/DDwedTHvI1sPHrMz06PI_2026-08-02` (Thursday night ⇄ morning),
> and the 00:46:39Z request still claimed the requester's old night slot. New
> `SwapRosterSync` refetches the week whenever a swap on the loaded
> (branch, week) reaches `managerApproved`, off the **realtime** swap stream, so
> both parties update — mounted on the manager/admin view and on
> `MyScheduleScreen`, which had no refresh at all. The swap list now states a
> refused decision **inline** (`Not applied` + the server's sentence): the queue
> is a modal sheet and its snackbar was rendering in the page `Scaffold`
> underneath it, so Approve looked like it did nothing. **Not device-verified.**

> **Project identity alignment (2026-08-05):** The repository folder is
> **`Drop-operations`** and the user-facing product name is **Drop Operation**.
> Android/Linux use the valid identifier `com.example.dropoperation`; iOS/macOS
> continue to use `com.ziad.drop`. The Android Firebase registration/configuration
> must be regenerated for the new identifier before a Firebase-enabled release.

> **Today coverage: skeleton-hang fixed + inactive branches skipped (2026-08-05,
> bug + perf):** The admin Schedule *Today* board could sit on its loading
> skeletons **forever** (reported as "it loads too much the first time"). It was
> a regression from the same-day read-caching change: `_load()` moved to
> `BranchCubit.loadIfNeeded()`, but coverage fires only from the branch
> `BlocListener`, which reacts to a state *change* — so when the directory was
> already loaded (admin opened another screen first), nothing emitted, the
> listener never fired, and coverage stayed `Initial`. `_load()` now triggers
> coverage directly when branches are already present. Same pass: the board now
> filters to `isActive` branches before loading (inactive branches aren't
> operating today), cutting first-entry reads. The Week editor still sees the
> full directory and can edit any branch. Pinned by
> `test/admin_today_coverage_screen_test.dart`.

> **Final schedule reshaped to the owner's spreadsheet + Excel export
> (2026-08-05, NOT device-verified):** The published Final view was transposed to
> **Morning · Night · Off rows down the side, days across the top, people named
> inside each cell** (previously employee-per-row with `M`/`N`/`OFF` tokens) —
> owner-approved, matching the spreadsheet they already keep. All three outputs
> now share one pure source, `schedule/domain/reporting/final_schedule_grid.dart`
> (`buildFinalScheduleGrid`): the on-screen `FinalScheduleSheet`, the PDF, and a
> new **Excel (`.xlsx`)** export (third choice in the export chooser). The Off
> row lists only people **explicitly** marked off/on-leave that day (from the
> leave record), tagging `(V)` vacation / `(L)` leave — it does not dump everyone
> not rostered, and is omitted entirely in an all-working week. **On macOS all
> three exports now open after saving** (Excel/Numbers · Preview) via the same
> `open` path chat uses — the desktop code previously saved to Downloads but
> never opened the file, so the export looked inert. The `.xlsx` is
> hand-written OOXML zipped with `archive` (the `excel` package pins an `archive`
> major that conflicts with `lottie`), delivered through the ADR-019
> write-beside + `open_filex` path. One new dependency (`archive`, already
> transitive). Closes Schedule V2 brief #20 (Excel half; CSV still out). Verified
> well-formed through a real XML parser; **needs on-device QA of the actual file
> opening in Numbers/Excel and the share sheet.** Pinned by
> `test/features/schedule/final_schedule_grid_test.dart`,
> `test/features/schedule/schedule_final_xlsx_test.dart`, and the rewritten
> `test/schedule_final_view_test.dart`.

> **Schedule — mobile Final view, exports, caching, roster fix (2026-08-04):**
> The Final view splits by width: **macOS keeps the landscape print sheet**
> (`FinalScheduleSheet`, 1600px), a **phone shows `FinalScheduleMobileView`** — a
> day-by-day card list (Morning/Night, each person an **avatar · name · role**
> row, hours + leave + notes inline; a "Final schedule" title in the bar), no
> zoom. The split is `context.isDesktop` (≥1024). The published sheet,
> the mobile view and the PDF all list **only people actually scheduled that week**
> via `scheduledRoster()` (≥1 shift, orphans dropped) — not the whole branch
> directory; the editor still assigns from everyone. **Export is a chooser (PNG +
> PDF):** PNG rasterises an off-screen `RepaintBoundary` of the landscape sheet,
> PDF is the new vector `buildScheduleFinalPdf` (`pdf` pkg, landscape A4); both go
> through the **ADR-019 write-beside + `open_filex`** delivery (iOS share/preview →
> Save to Photos/Files/send). **On mobile `_writeExport` writes to the app
> documents dir, never `getDownloadsDirectory()`** — on iOS that returns a
> never-created sandbox `Downloads` path, so the write threw "Could not save" for
> **both** exports; the identical bug in the **attendance** weekly export was fixed
> the same way. `ScheduleCubit.load` now has a **60s
> freshness window** — a same-(branch, week) revisit within it is a no-op, not a
> refetch; scope changes, Refresh, pull-to-refresh (`force`) and mutations still
> refetch. **The mobile weekly editor is `ScheduleDayEditor`** (one day at a time:
> day selector + roomy Morning/Night cards with add/move/remove + Notes & leave)
> — it replaced the cramped horizontal grid on phones. Pure presentation: every
> edit routes through the **same validated handlers as the desktop grid**
> (`_moveChip`/`_removeChip`/`_openChipActions`/`cubit.assign` via
> `_openAssignPicker` + `showEmployeePicker`). On a phone the controls block leads
> the scroll (**scrolls up and away**, not pinned) so the editor gets the screen;
> desktop keeps its toolbar pinned. On mobile the shift filter is gone (dead with
> the day editor) and **Final view moved into the app bar** as an icon
> (`ScheduleFinalViewAction`); both stay on desktop. **Desktop keeps the grid +
> inspector.**
>
> **Task Management production polish (2026-08-04, presentation only):**
> **Missed is a first-class `MetricTile`** on Task Management (Active · In review
> · Late · Missed), hidden at zero, never summed with Cancelled, and drawn
> exactly once — the record door under the reliability panel is gone. Every task
> list in the app now renders through the shared **`TaskSectionList`**, including
> `FilteredTasksScreen`, which had been stacking `TaskActivityCard`s (that card
> survives on the dashboard's Recent Activity feed only); `showDeadline` is
> deleted. Rows lost the per-row chevron, suppress the divider on a section's
> last row, and **date a record by when it closed**. `MetricTileRow` stretches an
> odd last tile instead of leaving a hole; a branch with nothing open says
> *Nothing open* rather than printing three zeros. The row's touch surface is a
> **rounded, inset** rectangle with the separator under it (never a sharp
> full-bleed band), and `TaskBrowser` owns its horizontal rhythm via
> `horizontalPadding` — **host pages must not wrap it in page padding**. The
> branch cockpit's Tasks preview lives in a `GlassContainer`.
>
> **Task Management UX refinement (2026-08-04, presentation only):**
> The task row is now **two lines** — title alone on the first (truncating only
> against the date), everything supporting on one meta line that ellipsizes as a
> single string — replacing a single line where a branch chip, an avatar and a
> date could all take width from the title. The branch chip, the assignee avatar
> and the 2px checklist track are gone (checklist reads `3/5 steps`); a deadline
> today renders as a time. `TaskBrowser` gained match-count search feedback with
> a Clear action, wrapped lens chips carrying counts **derived from the same
> filter that builds the list**, four distinct empty states, and a loading
> skeleton. Closed work is sectioned by **when it closed** (Closed today ·
> Yesterday · Earlier this week · Last week · Older) via the new pure
> `task_browser_groups.dart` — open work still delegates to `task_feed`'s own
> buckets, which are unchanged. This fixed a real defect: the engine's
> forward-looking grouping labelled every finished task *Done today*, whatever
> its age. Branch Operations shares one `AdminSectionHeader` and one spacing
> rhythm across Tasks · Automation · Team, previews the **active window** rather
> than the archive, and uses the shared `AppEmptyState` / `AppErrorState`.
>
> **Task operations mobile redesign (2026-08-04):**
> Admin Task Management leads with a tappable reliability record panel
> (Approved ÷ (Approved + Missed)) at headline scale, replacing the 11px caption
> strip that printed the company's only failure figure smaller than the zeros
> above it; Missed stays the sole error signal and Cancelled remains
> neutral/excluded/hidden at zero. Branch and employee task lists now share one
> `TaskBrowser` — live search over title, description, branch and assignee,
> status lenses, and due-date groups from the existing `task_feed` engine, all
> in memory over the live `TaskCubit` stream (**zero new reads**). Its closed
> lens is named **Closed**, not "Done": it spans approved, missed and cancelled
> work, and a missed task is not a completed one. Branch Operations previews six
> branch tasks; employee workload rows dropped ~160pt → ~64–78pt and build their
> metric line from non-zero figures only.

> **Admin mobile hierarchy pass (2026-08-04):**
> Admin Home now matches Manager Home's ranked command-center language: its
> eyebrow carries date + loaded company scope, Today is four drillable
> `MetricTile`s (Open · Running now · Due today · Done today), and a mobile-only
> compact Manage directory preserves Branches, Managers, Employees, Analytics and
> New account outside the bottom nav. Desktop keeps only Operations in its rail.
> Admin Task Management now leads with three actionable metric doors and a quiet
> record strip, then a named branch grid; branch covers are compact and cards show
> the operational triple plus one completion statement. Missed and Cancelled stay
> hidden at zero; Cancelled is neutral and excluded from completion.

> **Admin schedule Today coverage + Final View phone overflow fix (2026-08-04):**
> Admin Schedule now lands on a current-day, problems-first branch coverage list;
> each row is derived independently from the current-week cache-first schedule
> read plus branch members, and opens the existing roster peek. Week remains the
> existing editor behind an explicit segment/Edit action. The Final View export
> toolbar reduces its actions to labelled icons below 560pt, keeping all export
> controls reachable on phone widths.

## At a glance

| | |
| --- | --- |
| **Branch** | `release/v1-preparation` — `claude/ui-fix-608998` merged in via PR #25 (`6584808`) |
| **Build** | `flutter analyze`: exactly 1 pre-existing info (`use_null_aware_elements` in `test/task_submission_gate_test.dart`), no errors/warnings — re-verified **2026-08-06**. Both release artifacts build: `flutter build ios --release --no-codesign` → `Runner.app` 87.4 MB · `flutter build appbundle --release` → `app-release.aab` 93.1 MB |
| **Tests** | **1884 pass · 0 fail** (~41s) — re-run **2026-08-07**, after `claude/single-active-session-aedee1` and `claude/cursor-chat-visibility-notifications-003328` were both cherry-picked onto `release/v1-preparation` (+27 over the 1857 pre-merge: the session stale-snapshot fix, the clear-chat history drain, and the search-first chat picker). ✅ **`splash_visual_centering_test.dart` is GREEN (fixed 2026-08-05).** It had thrown `FormatException: Invalid character (at character 65630)` while `base64Decode`-ing the Lottie's embedded WebP frames — the root cause was **not** whitespace but **5 frames (39/47/55/68/69) corrupted by a stray `-`** (invalid in standard base64) when `b260c39` "Change the name fbro" re-exported `assets/0704.json`. Fixed by restoring the pre-`b260c39` blob `7bd8d6a` (all 102 frames valid); the stray `-` could not be stripped in place (invalid resulting lengths). This corruption was also the real reason the **cold-start launch animation misrendered** at runtime, since the `lottie` player uses the same strict decode. Cloud Functions: **143 pass** (`cd functions && node --test`) — re-run **2026-08-07** (+7 sales recipients over 136; the previously-recorded 112 was stale, the measured baseline was 127); **Firestore rules: 74 pass** (`cd firestore-tests && npm test` — needs the Firebase CLI, a JDK, **and `npm ci` in that directory**, which a fresh worktree does not have) — re-run **2026-08-06** (+6: the single-active-session claim). NestJS chat backend: **105 pass** (`cd ~/Desktop/Developer/drop-api && npx jest`) + `tsc --noEmit` clean — separate repo, re-run 2026-08-06 |
| **Tests** | **1744 pass · 0 fail** (~42s) — re-run **2026-08-07** (+3 net: the search-first chat picker replaced one always-listed assertion with four). ✅ **`splash_visual_centering_test.dart` is GREEN (fixed 2026-08-05).** It had thrown `FormatException: Invalid character (at character 65630)` while `base64Decode`-ing the Lottie's embedded WebP frames — the root cause was **not** whitespace but **5 frames (39/47/55/68/69) corrupted by a stray `-`** (invalid in standard base64) when `b260c39` "Change the name fbro" re-exported `assets/0704.json`. Fixed by restoring the pre-`b260c39` blob `7bd8d6a` (all 102 frames valid); the stray `-` could not be stripped in place (invalid resulting lengths). This corruption was also the real reason the **cold-start launch animation misrendered** at runtime, since the `lottie` player uses the same strict decode. Cloud Functions: **143 pass** (`cd functions && node --test`, re-run 2026-08-07 — the recorded 112 was stale; measured baseline 127); **Firestore rules: 68 pass** (`cd firestore-tests && npm test` — needs the Firebase CLI + a JDK) — both re-run 2026-08-05. NestJS chat backend: **105 pass** (`cd ~/Desktop/Developer/drop-api && npx jest`) — separate repo, verified 2026-08-03 |
| **Blocking release** | 🚦 **See [docs/RELEASE_V1.md](docs/RELEASE_V1.md) for the full gate.** Headline blockers: Android `applicationId` is `com.example.dropoperation` (Play-rejected) and release builds use the **debug keystore** · **no Firestore backups, PITR or delete protection** · APNs credential for iOS push · attendance on-device GPS QA · the app has **never been run on Android**. ✅ The automation P0 functions deploy **is done** (13:16 UTC), and ✅ **rules + all 24 functions are deployed and verified** (18:32–18:40 UTC) — the stale-deploy blockers B3/B4 are closed. ⚠️ H3 (`recurringTaskTemplates` read is not branch-scoped) was meant to ride that rules deploy and **did not** — it still needs its own. **(Chat P0-1 read-receipts + P1-1 unread counts are LIVE on Railway `main`, commit `2513c89`, via PR #7/#8.)** |
| **Platforms** | iOS · Android · macOS |

DROP is **feature-complete for its intended scope** and now gated on QA, not on
deployment.

**Firebase deploy DONE 2026-07-31** to `bazic-d9ad7` (the only project; there is no
staging). What the deploy actually revealed is worth recording, because the docs
had been wrong about it for weeks:

| Target | Before | Result |
| --- | --- | --- |
| **Functions** | All 24 present but running **stale source** | **All 24 updated.** This is the real change |
| **Firestore rules** | Believed missing | *"already up to date"* — the live ruleset already matched `firestore.rules` |
| **Firestore indexes** | Believed missing | Deployed |
| **Storage rules** | Believed missing | *"already up to date"* |

So the long-standing "rules have never been deployed" claim — including the
supposedly-missing `shift_templates` rule, the task `startsAt` enforcement, and
`storage.rules` `validMedia()` — was **stale**: all of it was already live. The
genuine gap was that the deployed *function source* lagged the repository. That
is now closed, which activates the automation business-day fix (ADR-015), the
widened `closeAttendanceExpectations` sweep, the task Missed/Cancelled server
paths, and — for this module — `onAttendanceCorrectionWritten`, so a manager's
Resolve / Add record / Excuse should now report **applied** rather than *saved,
not applied yet*.

Pre-deploy gates that did pass: Firestore rules **37/37** against the repo's own
rules file via the emulator, Cloud Functions **86/86**, Dart **1312 pass / 2
pre-existing splash failures**.

---

### Deploy 2026-08-02 — notification hardening + the attendance-correction P0

Everything from the 2026-08-02 audit work is **live** on `bazic-d9ad7`:

| Target | Result |
| --- | --- |
| **Firestore rules** | Released. Carries the `notifications` update restriction and the `attendance_corrections` `attendanceId` ownership binding |
| **Functions** | **All 24 updated** — task reminders, `approveSwap`'s server-owned notice, the broadcast schedule claim + push retry, the case-reopen actor exclusion, the correction ownership guard, and every subject-led body |

✅ **Verified at runtime this time, not just reported.** `onNotificationCreated`'s
`firebase-functions-hash` changed (`5cc7b753…` → `a154bf53…`), it rolled to a new
revision (`onnotificationcreated-00019-qif` → `00020-bek`), the startup probe
succeeded and state is `ACTIVE`.

⚠️ **The earlier note that `firebase functions:log` fails for this CLI login is
no longer true** — it works, and it is how the above was confirmed. Use it.

⚠️ **Deploy-order hazard, now resolved in the safe direction.** The client no
longer produces `swapApproved` (the server does). Functions are deployed *ahead*
of any app build carrying that change, which is the correct order — shipping the
build first would have left approved swaps announced to nobody.

---

## Branches

| Branch | Holds | State |
| --- | --- | --- |
| **`release/v1-preparation`** ← current | Everything below, plus `claude/ui-fix-608998` (bundled Inter typeface · premium empty / error / loading states · Home stat-strip empty-bar fix · **offline write-gating**) merged in via PR #25 (`6584808`) | Merged, **not device-verified**. The offline policy is a behaviour change, not polish — see Known issues |
| `fix-bugs` | Stabilization and UI-polish worktree | In progress |
| `feature/chat-nestjs` | Chat (new feature, NestJS backend) — Phase 1 networking foundation done | In progress; carries everything from `feature/attendance-management` |
| `feature/attendance-management` | Attendance P1–P3 (data · corrections · GPS · UI) | Committed, **not merged**, deploy + QA pending |
| `main` | Trunk | Behind this branch |
| `feature/media-upload-v2` | Media hardening + Automation Engine | Committed (`e3bf049`), needs deploy |
| `core/optimization` | Design System V2, Task Scheduling V2 | Merged to `main` via PR #14 |
| `feature/macos-desktop` | Desktop shell, Schedule 3.0–4.0, ⌘K | Landed |
| `feature/notifications-v2` | Notifications V2 pilot | Committed, functions undeployed |

~15 other stale feature branches exist from earlier phases and are candidates for
pruning. `Community-Hub` is **dead** — the feature was removed 2026-07-15.

---

## Features

### Complete

| Feature | Notes |
| --- | --- |
| **Auth** | Admin-provisioned email/password. No registration/Google/OTP/approval. First-login gate: force password change → profile completion → (employees) Welcome → role home. **Single active session** — a newer sign-in evicts every other device (client-enforced; not device-verified) |
| **Roles & routing** | 59 routes, role-guarded. admin ⊇ manager |
| **Profile** | View/edit, avatar/cover upload, contact details. `paymentNumber` is **edit-only** (a private subdoc; the read-only profile never states it, and Edit Profile hides it from an admin) |
| **Tasks** | Full workflow: create → execute (checklist · notes · proof) → review. Multi-assignee, recurrence, activity timeline, templates, shift assignment, work-type framework, Scheduling V2 (start/due windows + quick deadline presets). Upcoming tasks are visible immediately but `Start Task` / `Start Rework` stays disabled until `startsAt` (client gate + Firestore rules; no rework exception). Generated recurring shift tasks now persist their resolved weekly window and unfinished `pending`/`started` instances automatically close as server-owned **Missed** at shift end; the status is closed, visible, and excluded from active/overdue queues. **Automation business-day fix** (2026-07-30, uncommitted): recurring-shift generation keys and windows now use the Egypt business civil day, the generator is pinned to 01:00 Africa/Cairo, the client refuses to materialize a shift instance after its deadline, and per-task recurrence rolls successors forward until their deadline is future. **Requires a functions deploy for the server path.** **Cancelled** (2026-07-28, uncommitted) is the third terminal outcome — a manager/admin business decision taken from `pending`/`started` only, carrying a mandatory picklist reason, excluded from every count. The recurring-shift Automation Center is productionized: skeleton loading, premium header, slim tap-through cards, and a safe-area per-routine details sheet with a pinned Close action, compact schedule/outcome summary, collapsed technical details, last-task navigation, pause/resume and confirmed delete. |
| **Schedule** | Weekly roster, shift swaps, leave, day notes, configurable shift hours, shift templates, Final View + PNG export |
| **Branches** | CRUD, soft delete, swap policy, GPS geofences |
| **Admin** | User administration, account provisioning, Admin Home V2 command center. **Employees P19** (2026-07-27, uncommitted): a presentation-only, scalable directory pass — compact desktop header summary + Create Employee CTA, horizontal Branch/Role/Status/Sort/View controls, lazy list/natural-height two-column rendering (no fixed card extent), inline task KPIs, and Details/Edit with existing secondary actions in an overflow menu. The desktop FAB is removed while mobile keeps it; routing, cubits, repositories, and account semantics remain unchanged. **"Today" strip fix (2026-08-01, committed `fdaf66d`):** `admin_dashboard_screen.dart`'s `_today()` gained an `Open` stat (pending/started/completed/rejected — the same definition Task Management's "Active" uses) to answer "how much is on the table", since `Running now` (`started` only) was being misread as that number. `Delayed` renamed to **`Late`** with `AppColors.error` (was amber) — one concept, one name, one colour with Task Management's `Late` and Operations' `Late tasks`; grepped for other `Delayed` task copy, found none. `Approval rate` (a second, disagreeing completion formula — `Approved ÷ (Approved + Rejected)` from `StatisticsCubit`, next to §10.1's `Approved ÷ (Approved + Missed)`) is removed. `_today()` no longer subscribes to `StatisticsCubit` at all — `Completed today` now derives from the task stream (`completedTodayCount`, new in `task_metrics.dart`, reusing `isTaskInActiveWindow` so it can't drift from what a drill-down would list) instead of the lifetime-scoped `StatisticsCubit.completedTasksToday`. Every cell except `Due soon` is now tappable (`Stat.onTap` → `FilteredTasksScreen`, with a one-line `description`); `Due soon` stays inert on purpose — no `TaskFeedFilter` can reproduce `schedulePhase`'s dueSoon precedence (it excludes `completed`/`waitingReview` even though the active window includes them) without either an over-counting filter or a reverse dependency from `task_feed.dart` into `task_schedule.dart`. `manager_home_screen.dart`'s own `Completed today` (line ~130) reads the same `StatisticsCubit` field but isn't tappable, so it has no count-vs-list risk today — left unchanged, report-only per this pass's scope. |
| **Operations** | Branch Operations cockpit, workload derivation, KPI drills, and a visible branch-scoped Automation summary opening the existing Center sheet. **2026-08-03:** the extended `New Task` FAB is gone — it parked on the shift toggle and made the **Night** lens unreachable on a phone; New Task is now the screen's single `PrimaryCta` in a labelled action row under the branch hero, beside **All tasks** (promoted out of an unlabelled app-bar glyph). Workload cards gate their metric strip on `EmployeeWorkload.hasFigures`, so an idle employee collapses to a slim identity row instead of a bordered box of four zeros |
| **Communications** | Broadcasts, templates, custom audiences, scheduler, reminders. **Feed card minimized 2026-08-04 (presentation-only):** the history card was de-noised to one calm block — the 40px bordered category tile → a quiet 34px borderless glyph (colour only for an emergency), the coloured category subtitle + bordered audience pill + `person`/`send`/`error` glyphs are gone, folded into one muted meta line (`category · audience · sender`); the message preview dropped 2 lines → 1; the footer is now just the right-aligned delivery figure (failed count still red) with the time. Tighter padding. `BroadcastCard` API, actions menu and `broadcast_card_test.dart` strings unchanged |
| **Notifications** | In-app inbox + deep-link resolver. **Android has a named high-importance `drop_default` FCM channel; iOS app-side APNs entitlement/background-mode wiring is complete, awaiting only the APNs credential.** Inbox rows redesigned 2026-08-01, two passes (owner: *"looks bad and messy"*, then *"all the tasks look the same"*). Rows are now **subject-led**: `kicker (event, 10px uppercase, semantic tint) → subject (14.5px, ONE line) → context (12px grey)`. Every producer writes the event into `title` and the thing into `body`, so the old headline was the one line guaranteed to repeat; `title` is now the kicker and `body` the headline, split on its first ` • `/` — ` by pure `splitNotificationBody`. No stored data changed. The duplicated category pill is gone, read/unread is carried by row brightness, and only a **critical unread** item keeps the semantic halo. Day headers are a labelled hairline with that day's unread count; the filter rail is edge-masked and each pill carries its unread count. **`route: "attendance"` was a dead tap** (the resolver had no case for the string `writeAttendanceNotifications` has always stamped) — now opens `/attendance/record/:id`, falling back to `/attendance/review` · `/attendance/history` by role; **client-side, no deploy needed** |
| **Cases** | Private employee ↔ manager/admin conversations, confidential reporter split |
| **Requests** | Employee → manager yes/no approvals |
| **Statistics** | Live role-scoped counts on all three dashboards |
| **Employee Home** | **Hero reworked 2026-08-01.** The progress ring counted *in review* as finished, so it showed "3 of 3" beside "1 in review · 2 done"; it now uses the same `done = approved + completed` as the strip's Done cell. (It was deleted in the first pass and **owner-restored** the same day at 78px beside the shift — kept on the condition that it counts what the strip counts, and it is the **only** place the ratio is drawn.) The green **"All caught up!"** banner is deleted — third restatement of a finished day, and the only colour on screen; its "Open all tasks" row stays. The card also holds the **clock state** (`Clocked in 8:04 · 6h 30m on shift` / amber `Not clocked in` once the shift is underway / grey `Clocked out`), which had **no presence on Home before** despite being a twice-daily action reachable only via an unlabelled fingerprint icon. The button **hands off to the Attendance screen** — it does not clock in (GPS + geofence rules stay in one place), and Home never calls `previewLocation()` so it can't provoke a location prompt. ⚠️ Home now holds two Firestore attendance listeners while open. Strip zero-columns collapse to *"Nothing to do"* |
| **Task details** | **Info page reworked 2026-08-03.** The task **title** now leads the body (it lived only in the app bar, above a full-bleed branch cover — the page opened on a status pill and seven metadata chips without ever saying what the work was), with the **description directly under it** (its standalone section is deleted). The meta row is conditional rather than exhaustive: no branch chip when the cover banner already names it, no raw `type` string, no `Normal` priority (the default on every task), no `Active` phase beside a Due chip, no past `Starts` date — seven chips down to two on a typical task. **Assignment** (renamed from "Assigned to") is one lockup: assignee, then an indented `↳ Assigned by **Admin**` handover line, replacing a name/role block, a divider, and an orphan grey caption. The activity timeline is unchanged |
| **Manager Home** | **Rebuilt 2026-08-03** into the branch command center — the same ranked ladder Admin Home was signed off on, scoped to one branch: hero (greeting · one live state sentence · branch name · one **New Task** CTA) → **Needs attention** (`AttentionPanel`) → **Today** → **On shift today** → **Recent activity** → Operations digest · quick actions · recent messages, with a fixed 360px right rail on desktop. Replaced ten equal-weight stat cards plus an embedded task browser, where nothing was ranked and a hero `Active tasks 4` disagreed with the feed strip beneath it. Every count now comes from the live `TaskCubit` stream via `task_metrics.dart` (a figure and its drill-down list cannot drift); `StatisticsCubit` supplies only roster context. The hero sentence and the panel read the **same** total; **`Late` is drawn exactly once**. The full search/filter/sort browser was **moved, not deleted** — it lives in Branch Operations, reached from *Recent activity → See all*. **Second pass the same day** (owner: *"why everything in 1 page on mobile … way more clear and clickable … too much text"*): Today is four `MetricTile` doors (2×2 on a phone) with `Due soon` replaced by a drillable **`Due today`**; On shift today is **one tappable card** instead of four unclickable cells — and (third pass) it opens a read-only **roster peek** naming who is on each shift with its hours (`showTodayRosterSheet`, backed by the pure `schedule/domain/today_roster.dart`), **not** the weekly editor; the peek restores whatever (branch, week) the app-wide `ScheduleCubit` was showing, so it never moves the Schedule tab behind the user; the hero lost a whole text line (branch moved into the eyebrow, scope line and `Synced just now` dropped) and section subtitles are gone; **Quick actions is deleted** (duplicated the bottom nav + app bar) and **Recent messages is desktop-only**. The **all-clear panel is compact** — one row (check · title · the derived list of what was checked), down from ~230px of check + headline + sentence + zeroes, which made *nothing to do* the tallest thing on a calm board; `AttentionPanel.clearMessage` is gone and Admin Home gets the same treatment. Covered by `test/manager_home_test.dart` (10 tests) on both tiers + `today_roster_test.dart` (7) |
| **Design system** | Monochrome V2 primitives. Admin Dashboard V2 owner-signed-off. **The V2 command-center chrome is shared as of 2026-08-03** — `PrimaryCta` · `SyncButton` (+ pure `syncLabel`) · `HeroMood` · `AttentionPanel`/`AttentionSignal` · `DigestPanel`/`DigestEntry` · `CommandHint` moved out of `admin_dashboard_screen.dart`'s private classes into `core/widgets/`, with `live_status_border.dart` and `dashboard_mood.dart` following into `core/`. Admin Home renders identically and now composes them. **Task card border language** (ADR-014) live on Employee Home: the 1px edge is the state and never moves; only an unopened `pending` task gets the attention treatment. `RoleScaffold`'s mobile app bar leads with the DROP mark alone — the role word remains hidden because it truncated to "Mana…" and each home's hero already names the user and scope. Its role actions now share one flat glass command capsule beside a surfaced account avatar, with 44px targets and unread/account semantics |
| **Observability** | `AppLog` + `CrashReporter` (4 funnels, persisted across launches) |

### In progress

**Automated Tasks (product spec)** — behaviour is frozen in
[docs/design/AUTOMATED_TASKS_PRODUCT_SPEC.md](docs/design/AUTOMATED_TASKS_PRODUCT_SPEC.md);
it is the authority for the task lifecycle, cancellation, and the four-way
reporting classification.

| Phase | State |
| --- | --- |
| P1 — Cancelled core | Done, **uncommitted** (2026-07-28). `TaskStatus.cancelled` + the five-code `TaskCancelReason` picklist (frozen wire ids, immutable once written) + additive entity/model fields + `TaskCubit.cancelTask` (from `pending`/`started` only) + `task.cancelled` audit + branch-scoped rules with the cancelled record frozen + the generator's no-resurrection guard + the Cancel sheet & locked-banner reason. Cancelled counts **nowhere** (§8). **Rules need the standing deploy.** |
| P2 — Visibility & trust | Done, **uncommitted** (2026-07-28). Server-side notify-on-Missed (branch managers, admins as fallback, deterministic ids) · targeted notify-on-Cancel (assignees, or the rostered crew for a shift broadcast) · the employee **report-incorrect** path (required explanation, status unchanged, manager banner with Cancel / Task-stands inline) · **admin terminal correction** (`missed`\|`cancelled` → `pending`, audited). **Rules need the standing deploy.** |
| P3 — Reporting & analytics | Done, **uncommitted** (2026-07-28). Pure `domain/task_outcomes.dart` locks the four-way classification: completion rate = **Approved ÷ (Approved + Missed)** with Cancelled excluded from both sides (ungameable), cancellations on their own line **by reason code**, Late as timeliness on completed work, and Missed surfaced on the admin task overview. No new route or screen. **Per-task lateness (2026-07-31, uncommitted):** new `taskLateness(TaskEntity)` (`task_outcomes.dart`) derives the same signal for one task — `completed`/`waitingReview`/`approved` only, null for `missed`/`cancelled` — and `taskOutcomes()` now calls it so the two can't drift. Rendered as a quiet secondary-grey `formatLateness()` line (`activity_format.dart`) on the task card, Task Details, and the My Tasks Done tab. Findable via a new **"Finished late"** section on the Operations "Late tasks" drill-down (`isOperationalFinishedLateTask`, `branch_workload.dart`), below the existing "Past deadline" list — the hero count and `_FactStrip` figures are unchanged, still active-overdue only. No status/schema/rules change; implements ADR-013, does not reopen it. **Admin overview rebuild (2026-08-01, committed `fdaf66d`):** `admin_task_overview_screen.dart` dropped the `Active \| Done` segmented tabs and the wordy `_OutcomeBreakdown` panel in favour of one tappable `StatStrip` row (Branches · Active · In review · Late · Missed · Cancelled · Done · Complete) — every task-typed cell pushes `FilteredTasksScreen` with exactly that set of tasks (Missed/Cancelled/Done pass the new `TaskFeedFilter.activeWindowOnly: false`, since `isTaskInActiveWindow` otherwise excludes closed statuses and would render an empty page). Missed/Cancelled still hide at zero and Cancelled still never wears Missed's red or sums with it (§8). `TaskFeedFilter` gained `activeWindowOnly` (default `true`, preserves every existing caller) and a `statuses` set (composes AND with the single `status` field) — additive, `FeedPreset` untouched. `StatStrip`'s `Stat` gained an optional `onTap`. `FilteredTasksScreen` gained an `emptyTitle` override and a task-count caption; `TaskActivityCard` gained an opt-in `showDeadline` (used only by the drill-downs, not the dashboard's Recent Activity feed). The branch grid keeps only its former "Active" framing. **Outcome legibility + preview sheet redesign (2026-08-01, committed `fdaf66d`):** `task_card.dart`'s footer now names the **decider** once a task is decided (`Approved by <name>` / `Rejected by <name>` / `Cancelled by <name>`, resolved via the new shared `resolveDeciderName` in `activity_format.dart`), not the creator — Missed says `Missed — closed automatically` and never falls back to a person, since the automated sweep decided it, nobody did. A finished-late task's timeliness note moved from the bottom chip row to sit beside the status pill (`_LatenessNote`, always neutral grey — never the Missed/Late red, per §10.4); the reference-attachment count chip was cut (told you material existed, gave you nothing to act on from the card). `showTaskPreviewSheet` (`task_preview_sheet.dart`) is rebuilt **locally** in that file rather than reused from `TaskFeedRow`/`TaskFeedExpansion` (which stay exactly as-is — they're shared with the dashboard's live feed accordion): a plain-language situation sentence first (state + consequence, e.g. `Approved by Ziad · 1m late`), a 3-row facts card (branch+shift merged, due+lateness merged, assignee), a one-line checklist summary, and a hierarchy-first timeline (emphasised newest event, muted ledger below, capped at 4 + a Full-Details pointer). The sticky footer (`TaskFeedActions`) is unchanged. Every `FilteredTasksScreen` drill-down from the admin overview's stat row now carries a one-line `description` (new optional field, same slot as `OperationsMetricScreen.description`) answering "how does this count" — verified against the code: Late = active work only (pending/started/rejected) past its deadline, no time window, counted until closed; confirmed `_BranchMetrics._overdue`, `isTaskOverdue`, and `isOperationalOverdueTask` (`branch_workload.dart`) agree exactly. **Checklist Templates fullscreen (2026-08-01, committed `7a215b6` + working-tree fixes):** `_TemplateForm` and `_ManageTemplates` (`task_template_sheets.dart`) moved from `showSheet` — the form was a sheet nested inside another sheet — to `CupertinoPageRoute(fullscreenDialog: true)`, matching the task form. `_save` is byte-for-byte unchanged and now pinned by tests (title required, blank steps dropped, `branchId: isAdmin ? '' : defaultBranchId`). `TaskType`/`TaskPriority` gained an additive `label` getter because the form was rendering the raw wire `value` (`daily`, `normal`); `value` is untouched. Steps are drag-reorderable, the required-star is a legible Required/Optional control, and one shared `kTemplatesIcon` (`Icons.checklist_rounded`) replaces `dashboard_customize_outlined` everywhere. **Fixed a pre-existing debug-only crash:** `_ManageTemplatesState._reload` used `setState(() => _future = _load())`, whose arrow body returns a `Future` — `setState` asserts on that, so every template create/delete threw in debug (stripped in release, which is why it survived). |

> **The §10.2 scorecard gate is CLEARED** — the grace period is ruled
> ([ADR-013](docs/decisions/ADR-013-task-grace-period.md)): a fixed, global **30
> minutes** after shift end before Missed is evaluated. Grace is a tolerance on
> the close, not a deadline — tasks still read **Late from the original
> deadline**. Not configurable; no *Completed Late* state.
>
> **Completion rates from before this change are not comparable to figures
> after it.** Treat the switchover as a baseline reset, not an improvement.

**Chat (NestJS backend)** — a NEW staff-chat feature (distinct from Cases, which
stays on Firebase untouched), backed by an external, already-verified NestJS API.
Base URL is chosen **automatically by build mode** (`lib/core/config/app_environment.dart`):
Debug/Profile → `http://localhost:3000`, Release → Railway (`https://drop-api-production.up.railway.app`).
No dart-defines; a release binary is locked to Railway and can never resolve to localhost.
Optional dev-only LAN override: `--dart-define=DEV_API_BASE_URL=http://<lan-ip>:3000`.

| Phase | State |
| --- | --- |
| P1 — networking foundation | Done, committed (`159d6c9`). `core/network/` `ApiClient` + `NetworkConfig` (dio, Firebase-ID-token Bearer, one 401 force-refresh-and-replay, HTTP → `*Exception` mapping) |
| P2 — domain + data | Done, committed (`159d6c9`). Entities/models/datasource/repository + 8 use cases over the REST API (cursor pagination, send idempotency keys) |
| P3 — cubits | Done, **uncommitted**. `ChatListCubit` (app-wide singleton, mirrors `CaseListCubit`) + per-thread `ChatConversationCubit`; DI-wired |
| P4 — Conversation List UI | Done, **uncommitted** (2026-07-22). `/chat` inbox (`ChatScreen` + `ChatConversationTile`): loading/empty/error/loaded, pull-to-refresh, scroll-driven cursor pagination, transient-error snackbar |
| P5 — Conversation (thread) UI | Done, **uncommitted** (2026-07-22). `ChatConversationScreen` (per-thread cubit via DI factory) → shared `ChatConversationView`: `ChatMessageList` (bottom-anchored bubbles, date separators, relative timestamps, tombstone/attachment-chip rendering, "New messages" jump pill, top scroll-back pagination with preserved offset, post-frame visible→mark-read) + text-only `ChatComposer` (send spinner, clear-on-success-only, desktop autofocus + Enter-to-send). REST only |
| P6 — Realtime (Socket.IO) | Done, **uncommitted** (2026-07-22). Protocol read from the `drop-api` gateway (namespace `/chat`, handshake `auth.token` = Firebase ID token, `conversation:join`/`leave` with `{ok,error?}` acks, server events `message:new`/`read`/`deleted`/`deleted-for-me`, auth reject = `connection:error` + disconnect). New `ChatRealtime` domain port + `ChatSocketService` (`socket_io_client ^3.1.6`, the only file importing it): refcounted connect (first join) / teardown (last leave), **self-owned reconnect** (rebuilt socket + fresh token each attempt, exp. backoff ≤30s, force-refresh after auth reject), room re-join on reconnect. A raw transport connect is **not** treated as an authenticated session (the gateway allows connect, then rejects a bad token via `connection:error` + disconnect): the connection is promoted to healthy — backoff reset, `ChatRealtimeConnected` emitted, rooms re-joined — only after an 800 ms grace window with no rejection, so a bad token backs off quietly instead of a ~1/s reconnect+401+crash loop (fix 2026-08-05; `WebSocketConnectionClosed` from the socket-close path is a non-fatal breadcrumb, not a crash). `ChatConversationCubit` (additive `realtime:` param): live `message:new` inserted by `seq` + deduped, `message:read` → status READ, reconnect → newest-page REST reconcile. **REST stays the only write path & source of truth** |
| P7 — Message deletion UI | Done, **uncommitted** (2026-07-22). Long-press → bottom-sheet menu (`chat_message_actions.dart`) → Cases-style confirm → the existing use cases. **Delete for me** always offered; **Delete for everyone** offered only on own non-deleted messages (identity fact — the real rules, sender-only + 1h window, stay server-enforced; a 403 surfaces the server's message). In-flight delete dims the bubble (`deletingMessageId`, one at a time). Live `message:deleted` now tombstones in place (client mirrors the backend placeholder constant) and `message:deleted-for-me` removes cross-session |
| P8 — Inbox realtime | Done, **uncommitted** (2026-07-22). Same shared socket (no second service): `ChatRealtime` gains `attachInbox`/`detachInbox` — inbox interest that keeps the connection alive with **no room join** (the personal `user:{id}` room already delivers `message:new` for every conversation). `ChatListCubit` (additive `realtime` seam, attached on first load) bumps the row to top with fresh activity, seeds its unread map from the server-computed `unreadCount` in `GET /conversations`, then applies socket deltas; opening a conversation clears that count via `clearUnread`. It dedupes by per-conversation `seq`, refreshes on an unknown-conversation message or a reconnect, and tombstones a previewed line on live delete-for-everyone. Loaded state carries `previews`/`unreadCounts` maps into the Phase-4 tile slots. **REST stays the source of truth**; pagination unchanged |
| P9 — New-conversation flow | Done, **uncommitted** (2026-07-22; directory scope superseded by P12). Inbox FAB (always) + empty-state "Start Chat" CTA → `/chat/new` teammate picker (`NewChatScreen`/`NewChatView` + `NewChatCubit` over `GetChatDirectory`): every active user except the current user, search, avatar · name · role. Selecting one calls `StartConversation` and `pushReplacement`s to the thread (Back → inbox); server get-or-create means an existing pair opens the same thread, no duplicate. **Backend contract change (`drop-api`):** `POST /conversations` `targetUserId` is now the teammate's **Firebase uid** (external subject), resolved server-side to the internal participant via the existing identity resolver (get-or-create — provisions a teammate who's never opened chat); clients never hold other users' internal UUIDs. Self-start rejected 400 |
| P10 — Real profiles + polish + LAN | Done, **uncommitted** (2026-07-23; directory scope superseded by P12). **Real titles:** `GET /conversations` returns `counterpartExternalId` (Firebase uid, resolved through the flat `GetChatDirectory` Firebase lookup); the inbox renders real **avatar · name · role**, and the thread header shows the counterpart avatar+name — no backend id is ever a UI key. **Composer** redesigned premium (rounded 46px pill, reactive send button, multiline). **Thread** gets message grouping (time on the run tail only) + a premium empty state. **Networking:** backend binds `0.0.0.0:3000`; a debug-only Android manifest allows cleartext; one `--dart-define=API_BASE_URL=http://192.168.1.8:3000` wires REST + socket for both the iOS Simulator and a physical Android device. `ApiClient` + `ChatListCubit` now log the real transport error (no more silent loading→error loop). Composer refined (reactive send button + lifted bar + safe-area anchor), empty state personalized ("Say hello to {first name}"). **Verified live on the iOS Simulator via the LAN IP: real profiles, inbox, thread, and a live message send all work end-to-end** |
| P11 — V1 polish (composer · reply · attachments · optimistic · perf) | Done, **uncommitted** (2026-07-24). **Composer** rebuilt premium (r26 pill, left paperclip → attachment sheet, circular send that animates in only when there's text/an attachment, staged-attachment preview). **Reply** two ways: WhatsApp swipe-right (`_SwipeToReply` — bubble tracks the drag, reply glyph + one haptic at threshold, spring-back) **and** long-press menu (Reply · Copy · Message info · Delete-for-me/everyone); quoted preview renders in the bubble and as a composer banner. **Attachments** (`ChatAttachmentSource` seam + `ChatAttachmentPicker` over image_picker/**file_picker**): Camera/Gallery/Documents sheet, preview-before-send, premium file cards, optimistic image thumbnail from local bytes, full-screen `ImageViewerScreen` (local bytes now, brokered URL via `GetChatAttachmentUrl` for received). **Message info** screen — only backend-provided fields (sent time, status, sender, ids, seq, attachment, reply ref), IDs tap-to-copy. **Optimistic send** (`sendMessage` returns immediately, inserts a `SENDING` bubble, background POST → replace with server msg / mark `FAILED` + tap-to-retry reusing the idempotency key). **Perf:** `ChatThreadCache` (in-memory) paints a re-opened thread instantly, then refreshes; skeleton loader for a cold open. All presentation/cubit — REST stays the only write path. **NOT device-verified this session** (user reviews on-device) |
| P12 — Flat participant directory | Done, **uncommitted** (2026-07-24), [ADR-012](docs/decisions/ADR-012-chat-directory-is-flat.md). The picker was a bare own-branch Firestore read, but **admins are provisioned branchless** (the role is global) — so an admin's picker was empty and no staff member ever saw an admin (confirmed against live data: 1 branchless admin, 8 employees over 2 branches, 1 manager). Rather than special-case admins, chat's access model is now **flat: every authenticated user may message every other active user**. `GetChatDirectory` = ONE unfiltered `getAllUsers` read, filtered only by self-exclusion + `isActive` (applied in the use case so a legacy doc missing the field keeps its `true` default); shared by the picker *and* the inbox directory. **No branch or role predicate anywhere in the chat path.** New `AuthRepository.getAllUsers`. **Requires a rules deploy** — `users` read is now `if isSignedIn()`, replacing the owner/admin/same-branch disjunction |
| P16 — Final UX/UI polish | Done, **uncommitted** (2026-07-24). Presentation-only; no architecture / API / backend change. **Conversation options** three-dot menu (info · search · mute · clear · delete; both destructive actions confirm). **Conversation Info screen** — avatar · name · position/role · branch (Firebase directory + `BranchCubit`) · shared media/document counts · the same actions; **online/last-seen deliberately omitted** (no backend presence — DROP doesn't fabricate it). **In-conversation search** — live (200ms debounce) tone-aware match highlighting, emphasized active match auto-scrolled into view, `n/total` + prev/next (Enter = next), "No matching messages." bar. **Clear chat history** = `clearChatForMe()`, a bulk delete-for-me over the loaded window via the **existing** per-message endpoint, pooled 3 (`mapPooled`); counterpart keeps their copy; Delete conversation reuses it then pops. **Desktop** — right-click context menu (Reply · Copy · Forward *(placeholder)* · Delete for me/everyone) sharing one action handler with the mobile sheet; pointer cursor on tappable bubbles. **Inbox loading** is now a tile skeleton list. Added `AppSnackbar.info`/`context.showInfo`; `ChatThreadArgs.counterpartExternalId`. **Not device-verified this session** |
| P15 — Feature improvements | Done, **uncommitted** (2026-07-24). Six additive upgrades, no UI-architecture / realtime / backend-contract change: **(1) document preview** — `ChatDocumentService` downloads (cached, dedup by attachment id) + opens PDF/DOC/DOCX/XLS/XLSX/PPT/PPTX/TXT via the platform default app (`open_filex` mobile · OS `Process` desktop), loading + error-with-**Retry** (in-app PDF renderer deferred as build-risky); **(2) inbox search** — AppBar search → debounced O(n) live filter on name/role/last-message, scroll-preserved, "No conversations found." empty state; **(3) unread badge** — sidebar Chat row shows live `ChatListCubit.totalUnread` (hidden at 0); **(4) Recent Messages** dashboard widget (`RecentMessagesCard`, top-5, avatar·name·preview·time·unread, on employee + manager homes); **(5) in-app notifications** — tappable banner from any screen via new `ChatListCubit.incoming` stream + `ChatNotificationListener`, suppressed for the on-screen conversation (`AppDependencies.activeChatConversation`); desktop uses the same banner (OS-level local notif out of scope); **(6) document bubble** redesign (format icon + `PDF • 577 KB` + desktop hover Open/Download). `open_filex` added. **Not device-verified this session** (`pod install` for open_filex) |
| P14 — Offline cache (Drift/SQLite) | Done, **uncommitted** (2026-07-24; attachment-URL reuse hardened 2026-08-03). Production-grade local cache under `features/chat/data/local/` (`ChatDatabase` + `ChatLocalDataSource`): persists conversations, messages, **reply + attachment metadata**, and a durable text-send outbox — **never image/attachment bytes**. `ChatRepositoryImpl` takes an *optional* local datasource (null ⇒ REST-only original, so fakes/tests are untouched): read-through / write-through, offline fallback to cache, cache-first back-pagination (`local:<seq>` cursor), conflict-safe upserts (idempotent by id, ordered by server `seq`), plus an in-memory per-message brokered-URL cache through `ChatAttachmentDownload.isExpired`; URLs are not persisted. `ChatThreadCache` is now two-tier (in-memory + durable Drift) ⇒ instant open survives a restart and realtime messages persist via the existing `_emit → put`. Cubit changes additive only (cold-restore, keep local bubbles across refresh, adopt outbox + auto-retry failed sends on load/reconnect). Cache wiped on sign-out. **No image bytes or backend-contract change.** +15 original tests; URL-regression coverage added 2026-08-03. **Not device-verified this session** |
| P13 — Mobile UI refinement | Done, **uncommitted** (2026-07-24). Presentation-only polish pass, no backend/contract change. **Alignment root-cause fix:** own messages were rendering LEFT — `_SwipeToReply`'s `Stack` shrink-wraps the bubble and pins it `topStart`, collapsing the bubble Column's `crossAxisAlignment`, so swipe-enabled (confirmed) sends aligned left while `local:`/tombstone bubbles aligned right. Side is now enforced by an `Align` at the list-item level (works in both the swipe and non-swipe paths). Grouping keys on **side/ownership** not raw `senderId` (folds optimistic `local:` bubbles into my run; a side change always forces a tail + gap, so two people's runs can't merge). Bubble radii 20 + 6pt tail, padding 14×9, within-group gap 3 / between-group 12, max width 0.76·w cap 560. **Composer:** animated focus (border brightens/thickens on focus), 24pt pill, tightened padding. Ticks unchanged (monochrome per the design ruling). Verified on the iPhone 17 simulator |
| P17 — Blocker pass + prod verification | Done (Flutter **uncommitted**; backend **committed+pushed**, not yet live), 2026-07-25. Owner re-flagged the original blockers over new features; ran the full matrix on two iOS sims against Railway prod (`ziad@arkandrop.com` ↔ `test@drop.com`). **Composer rebuilt iMessage-style** (`chat_composer.dart`): one hairline-outlined capsule with a **transparent interior** (stroke defines the field, not a filled slab), `+` glyph + 30px send disc both inside, disc inset 4px, focus brightens the stroke without thickening. **Scroll-to-latest fix** (`chat_message_list.dart`): opening a thread landed mid-history because inline images grow after the single first-frame jump; a `NotificationListener<ScrollMetricsNotification>` now re-pins to bottom while the reader is at the bottom. **Backend read-receipt fix** (`drop-api` `9c4cd2a`): "seen" reverted to grey on restart because the history read path dropped the persisted `message_receipt.read_at` and the DTO hardcoded `status:'SENT'` — now joined onto the page (`MessageHistoryPage.readReceipts`), carried via `MessageView.readAt`, derived `status:'READ'`; +3 tests, 87 backend tests pass. **Verified live cross-device:** text both ways, image A→B inline in realtime + green "seen" tick, fullscreen viewer on the receiver, inbox real names/roles/timestamps/`You:` previews with no IDs. **Gated:** "seen survives restart" needs Railway to serve `9c4cd2a` (see below); `GET /conversations` now supplies server-computed `unreadCount`, which seeds persistent inbox and navigation badges while realtime applies deltas |
| P18 — macOS Chat list polish | Done, **uncommitted** (2026-07-27). Presentation-only. `/chat` keeps its existing list → route-to-thread navigation while its desktop header opts into a compact title area and persistent dark `Search conversations...` field. Rows retain 56px avatars while gaining 16/600 titles, one-line previews, inset dividers, soft hover/selected treatment, and compact circular unread badges; the empty inbox is now icon-led with the requested no-selection copy. Sidebar selection and the profile footer are calmer and lower-depth. `AppSearchField` gains reusable compact/focus support. No cubit, router, API, backend, model, or data-layer behavior changed |
| P19 — Thread identity + notification-stack polish | Done, **uncommitted** (2026-08-03; gates green — 1501 pass). The thread listens to `ChatListCubit` emits and resolves its header as soon as a cache/inbox summary exists; it starts a load but **never awaits the network to learn identity it already has cached** (the old `await list.load()` returned only after the server round trip, even though the durable-cache paint had filled `_conversations` much earlier — that wait *was* the "Conversation" flash). Route args remain first-paint only; `ChatThreadArgs` has value equality so warm-directory re-resolution no longer rebuilds. Chat notification navigation runs after the authenticated startup rendezvous and constructs the normal `Home → Chat → Conversation` history from `RouteNames.homeForRole`. ⚠️ **The idempotency guard was reading a stale location** (`routeInformationProvider.value`, which an imperative `push` never updates) and so had never actually worked — it now reads `router.state.uri`. Other notification routes are unchanged. **Not device-verified**: the parity test uses a plain router, not the real `ShellRoute`. |
| P20 — Unread launch hint | Done, **uncommitted** (2026-08-06). `ChatUnreadLaunchHint` above the router: the first *settled* inbox load of a launch slides one self-dismissing banner down from the top (*"You have 4 unread messages." · "Tap to open Chat."*, 3.5s), tapping pushes `/chat`. Once per launch, silent anywhere under `/chat`, no badge anywhere, **no extra reads** (it observes the load `ChatNotificationListener` already triggers). Needed the additive `topLocationOrNull` router reader — `currentLocationOrNull` reports the match list `uri`, which an imperative `push` never rewrites, so it cannot see that a chat deep link put the thread on screen. Pinned by `test/chat_unread_launch_hint_test.dart` (8). **Not device-verified** |
| Notifications (push) | Done, **uncommitted** (2026-08-03) — **gated on a Railway deploy.** Chat had no push at all: the only foreground surface was the socket-driven in-app banner, so a backgrounded or killed app got nothing. **Backend (`drop-api`, uncommitted):** `ChatPushSubscriber` — a sibling to `ChatRealtimeSubscriber` on the same `MessageSentEvent`, exactly the seam both classes' docs already named — plus a `PushNotificationPort` + `FirebasePushAdapter` (`firebase-admin` stays confined to `src/platform/firebase/`). Reads the recipient's `users/{uid}.fcmTokens` from Firestore with the service account it already holds, prunes dead tokens on `registration-token-not-registered`/`invalid-registration-token`, and titles the push with the sender's real name (`displayName → fullName → email → 'New message'`). Best-effort throughout: a push failure can never fail the committed send. **Suppressed only when the recipient has that conversation open** (`ChatGateway.isUserInRoom`) — a recipient merely elsewhere in the app still gets it, which is the WhatsApp behaviour. **Client:** `NotificationRoute.chat = 'chat_message'` + its resolver branch (no role gate; falls back to `/chat` without a `conversationId`). **⚠️ The server half must be deployed to Railway before this does anything on a device.** OUT of scope this pass: persisted mute, badges, grouping, quick-reply |

> The list endpoint exposes no counterpart display profile or last-message
> preview, but it **does** expose the server-computed unread count. The flat
> Firebase chat directory resolves counterpart name/avatar/role; cache, history,
> and the live socket resolve previews while realtime updates unread deltas. Chat
> is a **primary nav destination**: the mobile
> bottom nav's fourth tab (replacing Profile, which moved to the avatar →
> Settings hub) and a desktop sidebar entry for every role. **Verified live
> (2026-07-22):** REST + Socket.IO auth + start-conversation all confirmed
> against the running `drop-api`. **Operational note — the socket "auth"
> failure was a DB migration gap, not a token bug:** three chat migrations
> (critically `20260720130000_add_app_user`) were unapplied, so identity
> resolution threw *after* `verifyToken`, surfacing as a socket auth reject and
> REST 500s on Chat. Fix is `prisma migrate deploy` in `drop-api`; both sides'
> auth code was correct all along.

**Attendance** — the only feature not closed out. Code is complete across all three
phases and committed; what remains is deployment and on-device verification.

> **Product behavior is locked** in [docs/design/ATTENDANCE_SPEC.md](docs/design/ATTENDANCE_SPEC.md)
> (2026-07-18). **Spec Phases 1–2 are implemented** (engine + cubit API + rules +
> CF + tests, with the five write actions now wired through the shared action
> sheet).
> Phase 1: missed-punch recovery (employee request + manager Add record → server
> materialization via one upsert apply path), manager direct-resolve, one-open-
> correction. Phase 2: **early-clock-in window** (`clockInLeadMinutes`, default 15,
> enforced in `checkClockIn`), **worked-minute clamp** (`max(clockIn,
> scheduledStart)` in the one calculator), **lazy Absent** (virtual, no document),
> **Excused** terminal outcome (`AttendanceStatus.excused`, zero minutes, mandatory
> reason, via `AttendanceAdminCubit.excuseAbsence`). Phase 3 (owner-scoped to the
> *compatible slice*, 2026-07-18): the History/Details/Timeline/Metadata system
> **already existed** (2026-07-17) so it was **not rebuilt** — Excused was wired
> into it (filter facet · summary count · card refinement). The request's extra
> metadata fields / historical-snapshot blobs / analytics-payroll foundation were
> **declined** as contradicting ADR-009/010 and the recorded-fields-only ruling (no
> engine/data-model change). Final phase (2026-07-18): **16h max-session auto-close
> (R7) is DONE** — `autoCloseAttendance` now closes an unscheduled/over-long open
> session via a `maxSessionMinutes` cap through the pure, unit-tested
> `functions/attendance_auto_close.js`. **UI wiring DONE** (owner-authorized
> 2026-07-18): the five previously-headless write actions now have entry points —
> employee *Request correction* (summary) + *Missed punch* (post-shift) and manager
> *Add record* / *Resolve* / *Excuse* (board-row detail sheet), via one reusable
> `AttendanceActionSheet` over the existing cubits (loading + success/error + the
> pure validation, no new logic). **Only remaining blockers to closing the module:
> the standing functions/rules/indexes deploy, and on-device GPS QA** (real
> hardware) — no code work left.

| Phase | State |
| --- | --- |
| P1 — data foundation | Done. Deterministic `attendance/{uid}_{yyyyMMdd}_{shift}` id, `AttendanceCalculator` |
| P2 — corrections + audit | Done. Server-authoritative audit + `attendance_corrections/` approval object. **Correction target ownership is bound at create time in the rules and re-checked by the apply trigger** — closing a P0 where a correction could name another employee's `attendanceId` and overwrite their record on approval. Pinned by `firestore-tests/attendance_corrections.rules.test.mjs` (8 cases, emulator-verified). **Rules + functions DEPLOYED 2026-08-02.** |
| P3 — GPS engine | Done. `geolocator`, Haversine verification, separate clock-in/out verifications |
| P3 — UI | Done. Employee clock screen · admin board · geofence editor |
| History | Done. Ledger (`/attendance/history` self · `/attendance/review` branch, admin‖manager) + audit-log record details (`/attendance/record/:id`). Reuses the existing reads + `AttendanceStats`; holds ADR-009/010 (no score/analytics/export) |
| **Deploy** | ❌ **Not done** — functions + rules + indexes |
| **On-device QA** | ❌ **Not done** — GPS needs real hardware; simulators cannot validate this |

> Attendance minutes feed payroll. Do not ship it on a simulator's word.

**Attendance Reporting System — DIRECTION ACCEPTED 2026-07-30, SERVER CLOSE PIPELINE + READ LAYER + FIRST HUB ADDED.**
The owner accepted the reporting reframe, so
[ADR-017](docs/decisions/ADR-017-attendance-reporting-ledger.md) is **Accepted**:
Attendance is an operational reporting ledger, a scoped carve-out of
[ADR-009](docs/decisions/ADR-009-no-analytics-pipeline.md) /
[ADR-010](docs/decisions/ADR-010-lean-over-enterprise.md), and
[ATTENDANCE_SPEC.md](docs/design/ATTENDANCE_SPEC.md) §8 is amended accordingly
(the live board itself is unchanged). Rationale and the full end-to-end audit:
[ATTENDANCE_AUDIT_2026-07-30.md](docs/design/ATTENDANCE_AUDIT_2026-07-30.md).
Still refused: composite employee scores, leaderboards, client-authored payroll
totals, persisted late/overtime statuses, DROP as a payroll processor.

The first pure, additive P0 core exists under
`lib/features/attendance/domain/reporting/`: period windows/ids, roster-derived
expected-shift rows, no-show phantom rows, derived exceptions, and report summaries
with explicit denominators. The server-side close slice now mirrors that contract in
`functions/attendance_expectation.js` and exports `closeAttendanceExpectations`, a
30-minute Cloud Function that scans the current Africa/Cairo business week
(Sunday through today) plus the previous business day for the Sunday boundary,
writes one `attendance_expectations/{uid}_{yyyyMMdd}_{shift}` row per closed
rostered slot, and restates rows by version when attendance inputs change. The
week-wide sweep is self-healing for missed runs inside the active week, so a
rostered day no longer falls permanently out of reach during that week. **The
widened sweep is DEPLOYED** — `closeAttendanceExpectations` was updated in
`us-central1` on 2026-07-30 23:20Z (revision `00005`, Node 22, 2nd Gen), so this
is the one function no longer waiting on the standing backlog. Every *other*
pending function still is. **The later `namesByUid` change (below) landed after
that deploy and needs another one** before the server stamps names. The
previous production pipeline was verified on 2026-07-30 11:39Z with 3 real
20260729 absent phantom no-show rows for branch `DDwedTHvI1sPHrMz06PI`, while
branch `ikMkXApQQFeMsYFFu97X` legitimately had no recent rows because no roster
was published. The two reporting composites are deployed: `(branchId, dayKey)`
and `(userId, dayKey)`.
The client read layer now treats `attendance_expectations` as the only reporting
source: `AttendanceLedgerRow`/`AttendanceLedgerModel`, read-only branch/dayKey and
user/dayKey range streams, `AttendanceReportSummary.fromLedger`, and
`AttendanceReportCubit` with explicit `LedgerCoverage`. The existing History
summary strip is rewired to those ledger-derived numbers and renders **No ledger
data** when a period has no ledger rows, rather than showing `0%` or zero-present
figures. Governing owner rule: a materialized expected shift with no clock-ins is
a real **0%** attendance result; a day or period with no ledger rows is a
data-completeness gap with no denominator. The History list and live board still
read raw `attendance` records by design; the source guard forbids those
reconstruction paths only inside the reporting read path.

The first reporting surface now exists at `/attendance/reports`: the
manager/admin **Attendance & Reports** hub. It is desktop-first with a stacked
mobile form, pins managers to their branch, forces branchless admins to choose an
explicit branch, supports Week/Month period windows, blocks future-period
navigation, and renders the numbers only when `LedgerCoverage.hasRows` is true.
Its Weekly entry now opens `/attendance/reports/weekly/:periodId`, the first
per-period report destination.

**The hub was re-architected for reading order on 2026-07-31** (owner-commissioned,
presentation-only, uncommitted). It had been rendering a multi-branch design in a
single-branch reality — the `ATTENDANCE_REPORTS_IA` §13.5 wireframe assumes an
estate view that does not exist — so components built to compare branches always
rendered one row and ~12 facts appeared ~18 times. Now four sections in the order
the page's question implies: **scope & period** (the scope bar reframed as a
control bar, same function), **the verdict** (`AttendanceReportCoverage`, merging
the old `_NeedsAttention` tiles — one trust line plus one action line, with a zero
blocker count costing a single muted line and a real blocker earning weight, amber
and the Exception-queue affordance), **the numbers** (new hub-only
`AttendanceReportHeadline`: show-up rate as the headline with its denominator
inline, Expected · Present · Absent beneath it as its components, and punctual
arrivals / worked time only when they have a real denominator), and **go deeper**
(Weekly and Monthly as two real actions, the three unbuilt surfaces as one muted
line). The duplicate `PageHero` title and the single-row `_BranchPeriodPreview`
table are removed. **`AttendanceReportMetrics` is deliberately untouched** — it is
shared with the Weekly and Monthly reports, which stay visually unchanged, so its
`weekly: false` dashboard variant now has no app caller and survives only under
`test/attendance_report_metrics_test.dart`. The Weekly Report reads the same branch/dayKey
range from `attendance_expectations`, aggregates the seven-day Schedule week
directly in pure Dart. **Its section inventory is the Phase 1 five — see the
redesign entry below.** Coverage is conservative and ledger-exclusive: a
row-present no-show day is a real result, and a day with no rows reads **No
data** rather than zero attendance.

**Manager-facing status vocabulary changed 2026-07-31 (Phase 0 of the redesign
plan; see below).** `AttendanceCoverageStatus` in
`lib/features/attendance/domain/reporting/attendance_coverage_status.dart` is now
the single source of the word a manager reads, shared by Weekly and Monthly: no
rows → **No data yet** · blocking rows → **Needs attention** · rows with some
dates uncovered → **In progress** · every date covered, nothing blocked →
**Settled**. This **fixes a real data-honesty defect**: `isFullyClosed` is true
whenever any row exists and nothing is blocked, so a week with rows on one day of
seven was labelled *Fully closed*. That getter is unchanged and still means what
the close pipeline means — it is simply no longer the manager's word.
`AttendanceCoverageStatus.isActionable` also fixes the tone: only **Needs
attention** is amber, so a week where nobody was rostered no longer renders as an
alarm. Verified against production on 2026-07-30, the
live roster week `weekly_schedules/DDwedTHvI1sPHrMz06PI_2026-07-26` has no Sunday,
Friday, or Saturday assignments, so reports will show ledger data gaps on those
dates until the roster is published for them. After the functions deploy for the
week-wide sweep, older rostered slots inside the current business week, including
that live Monday/Tuesday, will be materialized on the next close run once past
grace. Weeks entirely in the past still require a separate backfill.

The **Monthly Report** is the second per-period destination, at
`/attendance/reports/monthly/:periodId`. Per the decided IA §7.1 it is not
"Weekly with more days": it reads the same branch/dayKey ledger range over the
calendar month and partitions it into the Schedule weeks (Sunday→Saturday) that
overlap the month, marking a week that only partly overlaps as **Partial** so a
short week is never read as a full one. It renders header, month status,
denominated metrics, weekly buckets, per-person rows, exception groups, and a
disabled share panel. Coverage semantics are identical to Weekly's, including the
owner rule (rows with zero clock-ins → a real `0%`; no rows → **No data** and no
percentage) and the same `AttendanceCoverageStatus` vocabulary.

**Aggregation is client-side by design of the value object, not by accident.**
Every aggregate is folded by the single row-scanning factory
`MonthlyAttendanceReport.fromLedger` and passed to a private constructor that
scans nothing, so the ADR-017 rollup Function can later add a `fromRollup(...)`
factory additively with no UI change. The month range is served by the
already-deployed `(branchId, dayKey)` composite, so this slice added **no
function, rule, or index** and needs no deploy.

**Absence rows now carry a name.** The ledger's `userName` was copied from the
attendance record, but a phantom no-show has none by definition — so every
absence, the rows the whole feature exists to surface, rendered a raw Firebase
uid. Fixed on both sides: `closeAttendanceExpectations` resolves the roster's
uids against `users/{uid}` and freezes the name onto new rows (**needs a
functions deploy**), and `AttendanceReportCubit` resolves the branch directory
via the existing `GetUsersByBranch` so rows already in production stop showing
uids immediately, with no backfill. Precedence is ledger name → directory → uid:
the frozen name wins because a payroll artifact must reproduce the name as of
close. The directory read is a **label only** — every denominator still comes
from the ledger alone, and the source guard is unchanged.

Per-employee report, exception queue, branch comparison, close/lock, export, and
month-over-month comparison remain later slices and appear as disabled **Coming
next** affordances.

**A redesign of the reporting presentation layer is PROPOSED, not accepted.** A
real store manager was shown the Weekly Report on 2026-07-31 and could not read
it: the surface exposes internal vocabulary (*ledger rows*, *phantom row*,
*restatement*, *blocking/informational*), renders a week with no rostered shifts
as six amber "No ledger data" rows plus `0%` and a red absence count, and labels
a week that is 86% empty **Fully closed**. The root cause is that the screen is a
*faithful build* of [ATTENDANCE_REPORTS_IA.md](docs/design/ATTENDANCE_REPORTS_IA.md)
§6.4/§6.5 — so the fix is a spec amendment first, not a screen edit — and that
the IA's own build order (Branch Workspace → Exception Queue → Weekly) was
skipped straight to Weekly, leaving Weekly to absorb a daily surface's job.

[ATTENDANCE_PRODUCT_REDESIGN_PLAN.md](docs/design/ATTENDANCE_PRODUCT_REDESIGN_PLAN.md)
is the PRD: five phases (language/honesty → Weekly rebuild → **Daily Review**, the
missing layer → Admin Workspace → exports), 5 sections replacing 8, 4 KPIs
replacing 6, and audit machinery relocated to an admin audience. It changes
**presentation only** — [ADR-017](docs/decisions/ADR-017-attendance-reporting-ledger.md)'s
ledger scope and metric bar, and every rule in
[ATTENDANCE_SPEC.md](docs/design/ATTENDANCE_SPEC.md), are untouched. Its §11
carries eight open product decisions requiring owner sign-off before Phase 1.

**Phase 0 (language and honesty) is DONE 2026-07-31 — uncommitted.** Presentation
copy and state rendering only; no cubit, repository, rule, index, or Function
touched, and no aggregate or denominator changed value. Five deliverables landed:
(1) internal vocabulary retired at the manager boundary across Weekly, Monthly,
the reports hub, the verdict card, the headline, and History — *ledger rows* →
shifts, *phantom row* → **No clock-in recorded**, *blocking/informational* →
**Needs a decision / Worth knowing**, *close readiness* → **Week status**,
*export and restatement* → **Share this week**, plus a new
`AttendanceLedgerOutcome.label` so the Outcome column stops printing wire values
like `workedLate`; (2) day-state honesty — a day with no rows reads **No data** in
tertiary grey, and only a day that was scheduled and worked by nobody is toned
error-red; (3) the week-status fix described above; (4) uncomputable metric cards
suppressed, so a rate with a zero denominator renders nothing instead of `--`
(the weekly grid had one such card; the hub headline already did this); (5) the
defensive captions deleted — *"Alphabetical facts only. This report does not rank
people…"* and *"data-completeness gaps, not attendance results."* Empty exception
sections and the empty attention panel no longer render at all. Index-missing
error copy now leads with what the reader can act on and keeps the raw cause
after it. Verified: `dart analyze lib test` clean (1 pre-existing test-style
lint), suite **1272 pass / 2 pre-existing splash failures**, +7 tests (new
`attendance_coverage_status_test.dart` incl. a guard that no manager-facing
status label contains internal vocabulary, plus metric suppression cases).

**Phase 1 (Weekly Report rebuild) is DONE 2026-07-31 — uncommitted.** The gating
deliverable landed first: **`ATTENDANCE_REPORTS_IA` §6.4–§6.10 are replaced in
full** (§6.1–§6.3 — week definition, audience, close inputs — unchanged and still
binding, as is ADR-017). Without that amendment the eight sections regenerate
from the spec, which is the root cause the whole plan turns on.

Weekly now renders **five sections**: *Needs your attention* (renders only when
something blocks, carries the page's only verb) · *The week in one line*
(`0 of 3 shifts worked · 0h`, counts never a store-level percentage, plus the
plain-language week status) · *By person* · *By day* · *Share this week*. The
exception summary and the shift evidence table are **gone from the manager
surface, not from the product** — exceptions belong in Daily Close / the
Exception Queue (Phase 2) and row-level evidence is an audit need Phase 3 owns.
⚠️ The evidence table carried the only per-record link on this screen; until the
per-employee report exists, managers reach a record through the history ledger at
`/attendance/review`.

**Four KPIs replace six**, in a new `AttendanceWeeklyKpis` widget that Weekly
owns — Hours worked · Overtime · Unexcused absences · Late arrivals (**count**,
not summed minutes). **`AttendanceReportMetrics` is untouched by this phase and
is now Monthly-only** (its `weekly: false` dashboard variant still has no app
caller). Show-up rate and punctual-arrival rate are **deliberately removed from
the store surface** — at one expected shift a percentage is the least reliable
and most alarming figure available; both survive on the hub headline and belong
at admin/multi-branch level where a denominator exists. The per-day show-up
column went with them.

**Person rows are now ordered exceptions-first** via `AttendanceAttentionBand`
(needsDecision → absent → late → clean), alphabetical inside each band, with a
Status column. This **reverses** the previous alphabetical rule and its
disclaimer. Ordering is not scoring: no weight, no composite, no rank — ADR-017's
refusal of performance scores is untouched, and alphabetical order was never what
enforced it. `WeeklyAttendanceEmployeeAggregate` gained additive
`blockingExceptionCount` + `lateArrivals`; **Monthly keeps the alphabetical
list** (§11 D2 defers Monthly entirely).

Verified: analyze clean, suite **1274 pass / 2 pre-existing splash failures**,
+3 tests including one that pins the ordering reversal (a clean person early in
the alphabet sorts below a no-show late in it) and the source guard still green.

**Phase 2 (Daily Review) is PARTIALLY DONE 2026-07-31 — uncommitted.** New
manager/admin surface at `/attendance/daily/:branchId/:dayKey`
(`presentation/daily/attendance_daily_review_screen.dart`), reachable from a
Weekly day row, guarded like the reports area and scoped to the manager's own
branch. Three zones — **Needs you** (only zone with verbs, ordered by cost of
being wrong via the pure `domain/daily_review.dart`), **The day** (one line,
counts not percentages), **Everyone** (collapsed). A clean day renders one line.

**It reads the roster × records board, not the ledger** — Daily Review is
operational, and `attendance_expectations` is the *reporting* truth for closed
periods. That keeps the ADR-017 source guard untouched: reporting still reads the
ledger only.

⚠️ **A real defect was fixed here.** `AttendanceAdminCubit.addRecord` /
`resolveDirectly` / `excuseAbsence` resolved the attendance document id from
`_today()` **at action time**, so reviewing a past day — or a live board left
open across midnight — would write the correction against the wrong date, on data
that feeds pay. `load(...)` now takes an optional `businessDate` that is pinned
at scope and used everywhere `_today()` was; the live board (no date passed) is
unchanged. Two tests hold both halves. The per-day tick is also skipped for a
past date, which cannot change.

The three write helpers moved from `admin_attendance_screen.dart` into
`presentation/widgets/attendance_manager_actions.dart` so both surfaces share one
path. **No decision semantics changed** — validation, the approved-correction
apply path, and the no-self-approval rule all still live in the cubit.

**Deliberately not built:** exception kinds *pending correction* (already has a
working queue on the live board), *unusual overtime* (needs a threshold nobody
has set), and *unscheduled work* (does not exist until the redesign plan's §11 D1
is decided); the daily notification (server-side, waits on the standing functions
deploy); and 48-hour escalation (its destination is Phase 3's Admin Workspace).
⚠️ **The manager actions no longer claim success they cannot see.** A manager
write creates an approved correction; `onAttendanceCorrectionWritten` is what
applies it to the record and stamps `resolvedAt` (spec T3/T4). Undeployed, the
correction is stored and the record never moves — but the UI said *"Absence
excused."* anyway, so a manager was told a shift was settled while the person
was still marked absent. This is **pre-existing behaviour on the live board**,
surfaced by Daily Review because that screen is meant for daily use.
`addRecord` / `resolveDirectly` / `excuseAbsence` now return
`AttendanceWriteOutcome` (`applied` · `awaitingBackend` · `failed`) instead of
`bool`: after writing, the cubit re-reads the record and looks for a **new**
`resolvedAt` (compared with the value before the write, since a
previously-corrected record already carries one), polling ~5s. Not confirmed →
the manager is told *"Saved, but not applied yet — waiting on an administrator to
finish setup. Nothing is lost."* Deliberately **not** an error: the correction is
durable and applies on deploy, and calling it a failure would push managers to
redo a write that succeeded. Poll interval is injectable so tests do not spend
real seconds per write.

Verified: analyze clean, **1289 pass / 2 pre-existing splash failures**, +15
tests.

**Phase 4 was RESCOPED and SHIPPED 2026-08-01** by
[ADR-019](docs/decisions/ADR-019-operational-exports-and-week-review.md), after
the owner retired its premise: **DROP is an operations system, not a payroll
system, and payroll integration is not planned.**

That collapsed the old reasoning in sequence — no machine ingests a file, so no
machine schema; nothing consumes a figure, so nothing needs freezing; the
artifact is not financial, so it needs no audit chain; and with no audit chain,
server generation buys nothing a client cannot do. **The deploy dependency
disappeared with it.**

**Shipped:** a client-generated **timesheet CSV** — 11 human columns (`29 Jul`,
`08:37`, `7h 52m`), not the 37-column machine schema — written beside the
Schedule PNG export via `path_provider`. And **week review**: a manager's
assertion that they looked, at `attendance_week_reviews/{branchId}_{weekKey}`.

⚠️ **Week review is an assertion, not a lock.** Nothing is restricted by it; the
rules carry no `locked` field by design. It is **orthogonal to
`AttendanceCoverageStatus`** and must never be merged into it — coverage answers
*is the record complete?* (computed), review answers *has a person signed off?*
(underivable: a week can be Settled and never opened). Merging them is how "Fully
closed" once appeared over an 86%-empty week. Post-review changes are **derived**
(`restatedAt`/`closedAt` later than `reviewedAt`), so "later changes are visible"
costs no history collection. A week with open items is still reviewable and says
so.

**Deleted:** the payroll CSV builder + its 18 node tests (functions back to 68),
period lock, the export ledger, restatement versioning, and the dead
`AttendancePeriodStatus`. `ATTENDANCE_REPORTS_IA` §12.6 is retired.

**Rules deployed 2026-08-01** — `attendance_week_reviews` (manager own-branch,
admin any; attribution cannot be forged; Reopen deletes). Firestore rules suite
**47 pass** (was 37).

**The weekly PDF shipped 2026-08-01.** `pdf` is the **one** new dependency —
`printing` was deliberately not added: it brings platform plugin code for a
print dialog that is not needed, when the file can be written beside the
Schedule PNG export and handed to `open_filex`, which the chat document service
already does. The document carries the same five sections in the same order as
the screen, because a PDF with its own information architecture is a second one
to keep in sync. It renders **both** states in the header — coverage *and*
review — never merged into one verdict.

⚠️ **Opening matters more than saving on mobile.** On a phone `_writeExport`
targets the **app documents dir** (never `getDownloadsDirectory()` — on iOS that
returns a never-created sandbox `Downloads` path, which threw "Could not save"),
so the file always writes, then `open_filex` hands it to the share/preview sheet
to be sent on. Desktop uses Downloads and skips the opener.

**Payroll is now fully removed from the UI**, not just the backend:
`AttendanceExportKind.payrollCsv`, `AttendanceExportBlock.notLocked` /
`.notDeployed`, the `isLocked` / `serverReady` gate parameters, and the admin
workspace's Payroll hand-off section are all deleted. The gate is down to the one
rule that still earns its place: **an unsettled week must not be shared as though
it were final**, because a document leaves the app and outlives the screen that
qualified it.

*Superseded (kept for the record): Phase 4 was previously blocked on the deploy.* ADR-005/ADR-017 make a payroll artifact
server-authored, so the file must come from a Cloud Function writing to Storage
with an export ledger — none of which can be verified without the standing
Functions deploy.

Landed and tested: **`functions/attendance_export.js`** — the §12.6 payroll CSV
(37 columns in contract order, RFC4180 escaping, **whole unrounded minutes**
because payroll owns 5/10/15-minute rounding and rounding twice is how two
systems disagree about someone's pay) plus `exportGate`. Firebase-free like
`attendance_auto_close.js`, so **18 new `node --test` cases** cover it with no
emulator (**86 pass**, up from 68). Dart-side `AttendanceExportGate` mirrors the
same rule so the UI is honest; the server stays the authority. Manager *Share
this week* and the new admin **Payroll hand-off** section now name the real
reason they are unavailable rather than saying "coming next" — and the payroll
button is admin-only, lock-gated, and deliberately nowhere near the manager's
PDF button.

**Not landed, needing the deploy + a rules change:** Function→Storage wiring, the
`attendance_exports` ledger, the period-lock write, restatement versioning.
⚠️ **Check before deploying:** the CSV names GPS columns and `correction_ids`
that `attendance_expectation.js` does not currently materialize — they export
empty. Either the close Function starts writing them or the schema drops them.

**Phase 3 (Admin Workspace) is DONE 2026-07-31 — uncommitted, partial.** New
admin-only destination at `/admin/attendance/workspace` (covered by the existing
`_isAdminArea` guard, since it sits under `/admin/`), reachable from an
admin-only tile on the reports hub. Four sections: **Needs chasing** (branches
whose oldest blocker is ≥2 days old — a manager gets the day plus the next one
before silence becomes a signal) · **Data completeness** (per-branch days
covered/7, worst first; the signal that used to be the loudest thing on a store
screen) · **Across branches** (the pooled rollup — **the only place show-up rate
now lives**, because pooled across branches a percentage finally has volume
behind it) · **Evidence** (the row-level table Phase 1 removed from Weekly,
relocated intact with its per-record link, so no audit capability was lost).

New pure `AdminAttendanceOverview` folds one `WeeklyAttendanceReport` per branch
plus one `AttendanceReportSummary` over the union of rows — so the cross-branch
rate cannot drift from the per-branch ones. `AdminAttendanceOverviewCubit`
**fans out one branch range stream per branch and merges**; there is no
collection-wide query and **no new index**, since the deployed
`(branchId, dayKey)` composite already serves each leg. A branch with zero rows
is seeded into the map explicitly — "this branch reported nothing" is the whole
point, and a missing key would render as a missing branch. All four new files
are added to `attendance_reporting_source_guard_test.dart`, so they stay
ledger-only.

**Deferred with reasons:** period locks, restatement history and the export
ledger do not exist anywhere yet, so there was nothing to relocate — they arrive
with Phase 4, which owns the lock. GPS detail stays put: it lives only on the
admin live board's own detail sheet, which is already an admin surface.

**Both remaining product decisions are now DECIDED (2026-07-31, uncommitted).**

*Overtime threshold — there is none, and exception kind #5 is struck.* Confirming
overtime in DROP alters no record, no payment and no export (ADR-017: DROP hands
off a ledger, R17: overtime is "never auto-approved, never fed anywhere"), so an
approval step fails ADR-017's own metric bar. `overtimeGraceMinutes` (15) already
defines when overtime *exists*; a second number for when it needs *approval*
would be invented. Overtime stays a visible fact — weekly KPI, day line,
per-person column. **Reverses this plan's own first draft.** Reversal trigger: a
payroll export carrying overtime hours.

*Unscheduled clock-in — allowed*
([ADR-018](docs/decisions/ADR-018-unscheduled-clock-in.md), amends
`ATTENDANCE_SPEC` §9). `AttendanceConfig.allowUnscheduledClockIn` now defaults
**true**; the flag survives so a branch can switch it off. The deciding argument
was evidence quality: today's workaround is a manager typing times from memory,
where a live punch is server-timestamped and GPS-verified at the moment of
presence. Five constraints — deliberate secondary action on the no-shift state ·
mandatory reason (stored in `notes`) · full GPS gate · Daily Review approval ·
**counts in nothing until approved**. New `AttendanceCubit.clockInUnscheduled`,
`unscheduledShiftFor` (band from the clock; deliberately not a third
`ScheduleShift` value), `AttendanceBoardStatus.unscheduled`, and
`DailyReviewKind.unscheduledWork` ranked above `noShow`. ⚠️ **`computeAttendanceBoard`
now appends records with no roster slot** — it walks the roster, so without that
pass an unscheduled punch existed in Firestore and was invisible on every manager
surface. Geofence resolution moved ahead of the schedule lookup so an unpublished
week does not block the GPS gate for the wrong reason.

**Manager records carry no schedule (2026-08-04).** A manager's record is written with
`scheduledStart`/`scheduledEnd` **null** even when they are rostered, plus
`presenceOnly: true`. Worked hours are clock-in → clock-out; late/early/overtime stay 0
(`AttendanceCalculator` was already correct for a null window — it needed no change).
⚠️ **`presenceOnly` is load-bearing, not decorative:** a null `scheduledStart` alone reads
as `unscheduledWork`, an *exception*, and reporting excludes unscheduled rows from
present/absent — so without the flag every manager day is an anomaly and managers vanish
from the stats. Presence rows contribute worked minutes but stay out of both sides of the
show-up rate (counting them present-without-expected pushes it over 100%). ⚠️ **The ledger
has a server half** — `functions/attendance_expectation.js` mirrors the same rule and the
two must agree; **not yet deployed**.

**Manager attendance is presence-style (2026-08-04).** `AttendanceService` resolves
`enforceSchedule: false` for managers, so roster presence and early clock-in timing
do not refuse their punches. The branch `managersCanClock` toggle, active-account,
leave, duplicate-punch, and GPS/geofence gates still apply. Employees retain the
default schedule enforcement; `AttendanceCalculator` remains unchanged.

### Removed — do not re-add

| Feature | Removed | Why |
| --- | --- | --- |
| **Schedule Health** | 2026-07-15 | [ADR-007](docs/decisions/ADR-007-schedule-health-removed.md) — advice that never gated anything |
| **Community Hub / DROP Events** | 2026-07-15 | Owner request. Live Firestore data left untouched |
| **Analytics pipeline** | 2026-06-23 | [ADR-009](docs/decisions/ADR-009-no-analytics-pipeline.md) — vanity metrics |
| **Attendance breaks** | 2026-07-15 | Descoped for MVP. `AttendanceBreak` kept as a dormant extension point |
| **Shift foundation (Phase 2)** | Phase 10 | Dead code; the weekly schedule is the roster |
| **Public registration / OTP / Google** | 2026-06-26 | DROP is admin-provisioned |
| **Employee-card KPI strip** (Completed · Pending · Rate · Late) | 2026-08-01 | Owner ask. Identical on every row, so it ranked nobody while costing the tallest band of the card. Performance lives in the Details inspector; `computeEmployeeMetrics` is untouched |

---

## Known issues

### Offline behaviour (settled 2026-08-03)

The rule is **gate the writes, never the app**. Reads keep working from cache
under `OfflineBar`; **clock in / out is the one write allowed offline**;
everything else is refused honestly.

Enforced at the **repository** layer by `NetworkGuard.ensureWritable()` (58 write
methods + the admin `_run` helper covering 9 more), which throws `OfflineFailure`
— cubits already catch `Failure`, so it surfaces everywhere for free and future
screens are covered automatically. `requireOnline` in the UI adds an earlier,
friendlier stop on review decisions. ⚠️ The guard is a **cached flag defaulting
to online**; a test that never installs a status behaves exactly as before.

A hard "app does not open offline" gate was asked for and built first, then
reversed the same session: clock-in happens at a branch with the worst signal,
and attendance IDs are deterministic so a late write cannot duplicate — the wall
broke the one case the data model was designed to survive. Firestore offline
persistence stays enabled and is now consistent with this.

⚠️ **Not exercised against a real radio.** The tests cover the logic, not the
platform channel — airplane mode and a captive portal still need a device pass.
Worth an ADR, since the first decision was reversed.

### Chat inbox N+1 — fixed in code, **awaiting a backend deploy**

The list DTO now serves the last-message preview (FR-021), taking a ten-row
inbox from eleven requests to one. Both halves are written and tested
(`drop-api` **92 pass**, app **1501 pass**) but the **server is not deployed**,
so today's app still uses the per-row fallback.

⚠️ **Deploy the API before assuming the inbox is cheap.** The client is additive
and works against either server; the fallback must stay until the deploy lands.

### Analyzer info (1)

The remaining `use_null_aware_elements` info is the pre-existing test-style lint
in `task_submission_gate_test.dart`. It is not an Automation Center finding.

### Failing tests — none (re-verified 2026-08-05)

**`flutter test` is fully green: 1670 pass, 0 fail** (~40s). It first went green
on 2026-08-03 at 1501 pass and has stayed green since.

> The three `notification_tap_flow_probe_test.dart` failures were **fixed
> 2026-07-25** by deleting the temporary `debug_auth_probe.dart` and its two
> `AuthCubit` call sites (the 401 chat investigation it served is long done). That
> probe touched `FirebaseAuth.instance` during `restoreSession` in a Firebase-less
> test; removing it is dead-code cleanup that also greened those cases.

The two long-standing `splash_centering_test.dart` failures were **fixed
2026-08-03**. Neither guess in the old note was right — it was *both* sides, and
they were separate bugs. See CHANGELOG for the full derivation. Short version:
the test added the **unscaled** artwork inset to a rect `getRect` had already
returned **scaled** (paint-time `kLogoManualScale`), and the page's own lift
formula never accounted for that scale either, so the real framing drifted with
window size (65.5px at 1440×900, 61.6px at 1024×720) while the constant claimed
50. Fixed on both sides with **zero pixel change at 1440×900** — the size the
owner tuned by eye — and the framing is now identical at every window size.

### Live deploy state (verified 2026-07-29)

A deploy was attempted on 2026-07-28. It **landed the rules and did not land the
functions** — confirmed read-only against `bazic-d9ad7`:

- **Functions: NOT deployed.** 21 of the 23 exported functions exist in
  production, and the newest deployed revision is **2026-07-15**. Missing
  entirely: **`autoEndRecurringShiftTasks`** and **`onRecurringTemplateWritten`**.
  Consequences today: **no task can ever become Missed** (the sweep does not
  exist, so the grace period and notify-on-Missed are inert and the completion
  rate's denominator can only ever contain Approved), and the deployed
  `sendNotification` predates the whitelist entries for `taskCancelled` /
  `taskReportedIncorrect`, so a cancel commits but the assignee is never told.
  The last recorded failure cause (2026-06-21 log) was a **Cloud Build service
  account permission**, which is worth checking first.
- **Rules: deployed** — which is how the create-denial bug reached the app.
  Fixed 2026-07-29 and covered by `firestore-tests/`; **the fix itself still
  needs a rules deploy**.

### Deployed-rules drift

The active production Firestore ruleset was verified read-only on 2026-07-18. It
contains `weekly_schedules` but **no `match /shift_templates` block**. The Create
Schedule flow reads the branch's templates before writing the weekly schedule, so
that prerequisite query is default-denied for every client role — including admin —
and the schedule write is never reached. The correct local rule exists in
`firestore.rules`; deployment is still pending. This is deployment drift, not an
admin-role or schedule-payload defect.

The **flat `users` read** was **deployed 2026-07-24**
([ADR-012](docs/decisions/ADR-012-chat-directory-is-flat.md)): `allow read: if
isSignedIn()`, replacing the owner/admin/same-branch disjunction. This unblocked the
chat directory for non-admins — the client issues one unfiltered `users` query, now
permitted, so counterpart names/avatars resolve for every role (previously the
directory was denied for non-admins, which is what surfaced the "Teammate XXXXXX"
placeholder). Note the `firestore.rules` file also carries other uncommitted rule
changes from this branch (task-hardening field freezes, etc.) that went live with this
`--only firestore:rules` deploy, since a rules deploy publishes the whole file.

### Access-control gap

The Automation UI queries `recurringTaskTemplates` by its supplied branch, but the
current Firestore rule permits any manager to read the collection across branches.
That contradicts the own-branch manager invariant in `PROJECT_CONTEXT.md`; it is
not exposed by the current UI, but a direct client query can cross the boundary.
The rules repair is deliberately outside the current UI-only phase and must be
handled as a separate backend/security task before the rules deploy.

### Configuration gaps

- **iOS push awaits only the APNs credential** — `Runner.entitlements` now supplies
  `aps-environment`, the Runner target signs it in every configuration, and
  `remote-notification` background mode is declared. FCM cannot deliver to iOS
  until the credential is supplied; no app-side configuration remains.
- **Firebase Storage** must be enabled in the console for proof/media uploads.
  A "not authorized" error on upload is *this*, not a code bug.
- **First admin** is bootstrapped out of band (set `role: admin`, `isActive: true`
  in the console).

### Attendance gaps found 2026-08-01 (code audit, not runtime)

- **Today-first attendance IA is now wired (2026-08-01).** Attendance & Reports
  opens the live Today board, not the reports hub: managers are pinned to their
  branch, admins choose a branch first, and the board groups decision-needed,
  present/working, late, and absent people. Reports and Person history are named
  next steps; an unscheduled clock-in can be marked present through the existing
  audited direct-resolution path. See [ADR-021](docs/decisions/ADR-021-attendance-today-first.md).
  Person-history ranges now include rolling **Last 7 days** and **Last 30 days**;
  a Today row opens that person's branch-pinned ledger.

- ~~**`AttendanceLocationPolicy` is dead.**~~ **Fixed 2026-08-01 —
  [ADR-020](docs/decisions/ADR-020-location-policy-is-real.md)** (amends the locked
  `ATTENDANCE_SPEC` workflow 6). The policy now actually gates the punch: `none`
  never refuses, `soft` captures and never refuses, `strict` runs the full gate
  unchanged. A branch with **no geofence resolves to `none`** instead of being
  locked out of attendance entirely. Default flipped `none` → `strict` so the
  config describes what ships. **Manager clock access is now branch-configurable:**
  `branches/{id}.managersCanClock` defaults true for legacy docs, applies only to
  managers, and fails open while branch data is unavailable. A disabled branch
  still permits an already-open session to clock out so no shift is stranded.
- **A non-geofenced branch clocks in unverified.** The deliberate trade in
  ADR-020. Closed by an admin drawing the fence in Branches → geofence editor;
  nothing changes at a branch that already has one.
- **`/admin/attendance` is a legacy redirect.** It now redirects to Today; the
  geofence editor remains reachable via Branches.
- **Stale stub.** `attendance_weekly_report_screen.dart` says *"Daily review is
  coming next"* on the blockers button while the day table beside it already opens
  the real Daily Review.
- ~~**Admin workspace hangs on a spinner.**~~ **Fixed 2026-08-01.** It gated the
  ledger fan-out on a `BlocListener` that never fires when the app-level
  `BranchCubit` is already loaded — which is always, coming from the reports hub.
  ⚠️ **The pattern, not the screen, is the lesson:** `loadIfNeeded()` on a
  singleton cubit emits nothing, so never make a `BlocListener` the only trigger.
  Await the load and read the state.
  **Audited 2026-08-01 across all 19 `BlocListener` + 21 `BlocConsumer` files, all
  13 per-screen `create:` cubits, and every screen rendering an app-level
  singleton: this was the only instance.** Two screens already do it correctly and
  are the reference — `attendance_history_screen._bootstrapReview()` and
  `chat_notification_listener.initState` (which warms the socket when a session is
  *already* live). The one latent latch found
  (`attendance_daily_review_screen`, which flipped `_started` before checking its
  preconditions) was **fixed the same day** and now uses the same two-path shape.
- Still genuinely missing on the reporting hub: **period close** and **export**
  (the monthly PDF/Spreadsheet buttons are disabled).

### Accepted debt

- **Light theme** exists in `AppTheme.light` but is not wired up — the app is
  hardcoded to dark in `main.dart`.
- **Account deletion** removes the Auth user but leaves `users/{uid}` in Firestore.
  Needs an `auth.user().onDelete` function.
- ~~**`automationRuns` telemetry has no reader.**~~ Resolved 2026-07-18: it is now
  an enriched execution record with a client read layer under
  [ADR-011](docs/decisions/ADR-011-automation-observability.md), which names the
  ADR-009 decision it changes (operational observability in scope; analytics not).
- **`developer.log` bypassing `AppLog`** — the 15 feature files (cubits · datasources)
  were converted to `AppLog` on 2026-07-25, so their failures now reach the crash-report
  breadcrumb ring. Four sites intentionally remain on `developer.log`: `main.dart` and
  `core/services/notification_service.dart` (deliberate FCM diagnostics for the open
  iOS APNs-credential gap — fuzzy category mapping, left for a separate judgment pass), and
  `notify_task_event.dart` / `notify_swap_event.dart` (pure `domain/usecases/` — must
  not import the Flutter-coupled `AppLog`). (`print()` calls: 0.)
- **Non-realtime lists** — tasks are fully streamed; schedule/branch/admin/swap
  lists reload after mutation + pull-to-refresh.
- **Stats aggregate client-side.** If data grows, move to Firestore `count()`.

---

## Pending work

### 🚨 Deploy (the critical path)

> **Deploy state verified read-only against `bazic-d9ad7` on 2026-08-05** — live
> ruleset diffed against `firestore.rules`, live indexes listed via the Firestore
> Admin API, every function's revision read with `gcloud functions describe`.
> This replaces the older "believed-pending, worth verifying" guidance below;
> the four rows are now known, not assumed.
>
> | Target | State |
> | --- | --- |
> | `functions` | **Mixed.** The automation P0 trio is deployed (13:16 UTC). The **5 sales functions are stale** — deployed 10:28 UTC, audit commit `2cf7e13` is 12:29 UTC. **`onNotificationCreated` and `writeSalesNotifications` are now stale too** (2026-08-06 notification-routing fix: `salesSubmissionId` + `monthKey` forwarded in the push `data`; `sales_target` route for month events). Everything else rolled 2026-08-04 13:15–13:16 UTC. |
> | `firestore:rules` | ❌ **STALE.** Live ruleset released 10:28:51 UTC; it is missing `branchRunsSalesTargets()` and the `branch_sales_submissions` create gate. |
> | `firestore:indexes` | ✅ **IN SYNC.** 19 live composites = 19 in the repo, all `READY`. |
> | `storage` | ✅ **IN SYNC.** Live ruleset byte-identical to `storage.rules`. |
>
> ⚠️ **Also missing at the project level: Firestore has no backup schedule, PITR
> is disabled, and delete protection is off.** On a database whose attendance
> minutes feed pay, that is a v1 blocker in its own right — see
> [RELEASE_V1 §B8](docs/RELEASE_V1.md).

The table below records what each target *carries*, and remains accurate as the
inventory of what a deploy delivers.

| Target | Carries | Blocks |
| --- | --- | --- |
| `functions` | 24 functions incl. `onAttendanceWritten`, `onAttendanceCorrectionWritten`, `autoCloseAttendance`, ~~`closeAttendanceExpectations`~~ (**deployed 2026-07-30 23:20Z** — the widened week sweep is live; the rest of this row is not), `generateShiftTaskInstances`, **`autoEndRecurringShiftTasks`** (15-min missed close **+ the new notify-on-Missed**), **`onRecurringTemplateWritten`** (automation lifecycle audit), `onCase*`, `onRequest*`, `sendBroadcast`, `claimFcmToken`; **`sendNotification` now whitelists `taskCancelled` / `taskReportedIncorrect`** | Attendance audit · attendance reporting denominator · recurring deadlines · automation · **cancel + report notifications** · cases · requests · **all push** |
| `firestore:rules` | `shift_templates`; Task review-field freeze + non-decreasing `activityLog` + server-owned Missed lock; **task cancellation** (manager/admin-only, `pending`/`started` predecessor, mandatory picklist reason, cancelled record frozen) + the **admin terminal correction** carve-out + the **incorrect-report** guards + employee scheduled-start enforcement for `started`; attendance + corrections; cases; requests | **Schedule creation/configurable hours** · Task hardening (P0/P1) · recurring deadline integrity · **cancellation integrity + terminal correction + start-time integrity** · attendance · cases |
| `firestore:indexes` | `tasks` composites (`branchId`+`assignmentType`+`shift`; `assignmentType`+`status`+`deadline`); `attendance_expectations` `(branchId,dayKey)` + `(userId,dayKey)`; **`automationRuns` `(branchId,templateId,startedAt)` + `(branchId,status,startedAt)`** | Employee shift-task stream (`failed-precondition` without it) · attendance reports · automatic recurring close · automation run history |
| `storage` | `validMedia()` + orphan GC | Media hardening |

```bash
firebase deploy --only functions,firestore:rules,firestore:indexes,storage
```

Requires the **Blaze** plan.

### Firebase Hosting — the App Store privacy policy only

Hosting serves **one static page**: the public Privacy Policy that App Store
Connect requires. It does **not** serve the Flutter web build, and it must never
be pointed at `web/` or `build/web`.

| | |
| --- | --- |
| **Source** | `hosting/index.html` — self-contained, no build step, no assets |
| **`firebase.json`** | `hosting.public: "hosting"`, catch-all rewrite to `/index.html`, `no-cache` on HTML |
| **Project** | `bazic-d9ad7` (default) |

```bash
firebase deploy --only hosting
```

⚠️ `y/` (the `firebase init` default page, committed in `044ea2e`) is now dead —
Hosting no longer reads it. `.firebase/hosting.*.cache` is a deploy artifact that
was committed by mistake and should be untracked + gitignored.

⚠️ `web/index.html` was overwritten with a privacy policy in `044ea2e`, which
removes the Flutter bootstrap. **Flutter web will not build from it** until it is
restored from `flutter create` or git history. Hosting does not depend on it
either way.

### Then

1. **On-device attendance QA** — GPS clock in/out on real hardware, both platforms.
2. ~~**Fix or delete `splash_centering_test.dart`**~~ — done 2026-08-03; green.
3. **Supply the iOS APNs credential** — app-side Push/Background-Modes configuration is complete.
4. **Merge `feature/attendance-management`** once deployed and QA'd.
5. **Prune ~15 stale branches.**
6. **Run the app on Android.** The bundled-typeface bug (2026-08-03) shipped
   unnoticed for months because nothing exercises Android — that is a QA gap, not
   a font bug.

---

## Active architecture decisions

Full records in [docs/decisions/](docs/decisions/). The ones most likely to be
unknowingly reversed:

| Decision | Don't |
| --- | --- |
| [ADR-004](docs/decisions/ADR-004-monochrome-design.md) — monochrome | Add a brand colour. Indigo has been rejected twice |
| [ADR-007](docs/decisions/ADR-007-schedule-health-removed.md) — no Schedule Health | Re-add scoring. Direction flipped twice already |
| [ADR-008](docs/decisions/ADR-008-requests-are-approvals.md) — Requests are approvals | Add statuses, assignment, or priority |
| [ADR-009](docs/decisions/ADR-009-no-analytics-pipeline.md) — no analytics | Build a metric without naming the decision it changes. [ADR-011](docs/decisions/ADR-011-automation-observability.md) carved out automation *execution observability* (not analytics); don't widen it to a time-series/analytics surface |
| [ADR-005](docs/decisions/ADR-005-server-authoritative-writes.md) — server-authoritative | Let a client write its own audit trail |
| [ADR-010](docs/decisions/ADR-010-lean-over-enterprise.md) — lean | Reach for the enterprise shape |
| [ADR-013](docs/decisions/ADR-013-task-grace-period.md) — fixed 30-min grace | Make grace configurable, add a *Completed Late* status, or let grace delay the **Late** visual (it must fire at the deadline) |
| [ADR-017](docs/decisions/ADR-017-attendance-reporting-ledger.md) — attendance reporting **ledger, not scoreboard** | Read it as licence for analytics generally (it is attendance-only), fuse attendance + tasks into one score, ship a leaderboard, persist late/overtime as statuses, compute payroll totals on the client, or ship a report before absences are durable |
| [ADR-020](docs/decisions/ADR-020-location-policy-is-real.md) — the **effective** location policy gates the punch | Read `config.locationPolicy` raw — always resolve it through `AttendanceService.resolveLocationPolicy`. Never re-add the no-geofence lock-out, and never treat the policy as a security boundary (the server does not enforce it) |

**Owner-frozen surfaces** — improve in-language, never replace without sign-off:

- **Employee My Week** (premium hero + week cards) — frozen 2026-07-07.
- **`LiveStatusBorder` orbit** — motion is load-bearing; per-state colours have been
  changed many times. Confirm before touching colours; never touch the motion.
- **Admin Dashboard V2** — closed and signed off.

---

## Current priorities

0. **Ship v1.** [docs/RELEASE_V1.md](docs/RELEASE_V1.md) is the sequenced runbook
   and supersedes the ordering below for release work.
1. **Finish the deploy.** `firestore:rules` and the 5 sales functions are stale
   in production (verified); indexes and storage rules are in sync.
2. **Turn on Firestore backups + PITR + delete protection.** There are none.
3. **Close out attendance** — on-device GPS QA, then merge.
4. ~~**Get the suite green**~~ — done: 1670 pass, 0 fail.
4. **Recurring shift deadline close — implemented (2026-07-19).** Generator and
   client materializer persist the resolved weekly shift window; the new
   server-authoritative 15-minute sweep changes only unfinished generated shift
   tasks to locked Missed records. **Gated on the standing functions/rules/indexes
   deploy.** No new route or package was added.
5. **Automation observability backend — built (2026-07-18, [ADR-011](docs/decisions/ADR-011-automation-observability.md)).**
   Tier 1: enriched `automationRuns` execution records (schedule · validations ·
   target+names · generation · notification · structured error · embedded step
   logs), cumulative health counters on the template, a server-derived
   `onRecurringTemplateWritten` lifecycle-audit function, and a thin client read
   layer (`AutomationRunEntity`/model/repo, paginated) — the foundation for a
   future Details screen (no screen built). Extended 2026-07-18 with an
   **immutable execution snapshot** (definition/schedule/branch/recipients frozen
   at run time → old history never changes) and a **deterministic correlation id**
   (`AUT-{yyyymmdd}-{hash}`) stamped on the run, generated task, notifications and
   audit for cross-resource traceability (`getAutomationRunByCorrelationId`).
   **Gated on the standing functions/rules/indexes deploy.** Tier 2 envelope
   (per-run I/O counters, replay engine, analytics surface) deliberately declined.

---

## Verifying this file

If you change status, gaps, or priorities, update this file **in the same task**.

```bash
flutter analyze                          # expect: 1 info, 0 errors/warnings
flutter test                             # expect: 1688 pass, 0 fail — GREEN; any red is a real regression
(cd functions && node --test)            # expect: 127 pass
(cd firestore-tests && npm test)         # expect: 68 pass — needs the Firebase CLI + a JDK
grep -c "static const String" lib/core/routes/route_names.dart   # expect: 59
ls lib/features | wc -l                  # expect: 19
```

All six re-verified 2026-08-05. To re-check the **deploy** state rather than the
code, see [docs/RELEASE_V1.md §0](docs/RELEASE_V1.md).

Routes live in [route_names.dart](lib/core/routes/route_names.dart) — read them
there rather than duplicating the table here. Firestore/Storage schema lives in
[docs/design/DATA_MODEL.md](docs/design/DATA_MODEL.md).
