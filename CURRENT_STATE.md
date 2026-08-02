# DROP — Current State

> **Today's snapshot. Nothing historical.** The moment something here becomes
> history, it moves to [CHANGELOG.md](CHANGELOG.md) and leaves this file.
>
> **Last verified against the code:** 2026-08-02.

## At a glance

| | |
| --- | --- |
| **Branch** | `release/v1-preparation` |
| **Build** | `flutter analyze`: 1 info, no errors/warnings (pre-existing test style) |
| **Tests** | **1441 pass · 2 fail** (~32s) — the 2 remaining are the pre-existing splash-centering failures. Cloud Functions: **82 pass** (`cd functions && node --test`); **Firestore rules: 61 pass** (`cd firestore-tests && npm test` — needs the Firebase CLI + a JDK); NestJS chat backend: **84 pass** (`cd ~/Desktop/Developer/drop-api && npx jest`). All four verified 2026-08-02 |
| **Blocking release** | ~~Firebase deploy~~ **re-deployed 2026-08-02 — see below.** Remaining: recurring-template manager read isolation · APNs credential for iOS push · attendance on-device GPS QA. **(Chat P0-1 read-receipts + P1-1 unread counts are now LIVE on Railway `main`, commit `2513c89`, via PR #7/#8.)** |
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
| **`fix-bugs`** ← current | Current stabilization and UI-polish worktree | In progress |
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
| **Auth** | Admin-provisioned email/password. No registration/Google/OTP/approval. First-login gate: force password change → profile completion → (employees) Welcome → role home |
| **Roles & routing** | 49 routes, role-guarded. admin ⊇ manager |
| **Profile** | View/edit, avatar/cover upload, contact + payment (payment in a private subdoc; hidden for admin) |
| **Tasks** | Full workflow: create → execute (checklist · notes · proof) → review. Multi-assignee, recurrence, activity timeline, templates, shift assignment, work-type framework, Scheduling V2 (start/due windows + quick deadline presets). Upcoming tasks are visible immediately but `Start Task` / `Start Rework` stays disabled until `startsAt` (client gate + Firestore rules; no rework exception). Generated recurring shift tasks now persist their resolved weekly window and unfinished `pending`/`started` instances automatically close as server-owned **Missed** at shift end; the status is closed, visible, and excluded from active/overdue queues. **Automation business-day fix** (2026-07-30, uncommitted): recurring-shift generation keys and windows now use the Egypt business civil day, the generator is pinned to 01:00 Africa/Cairo, the client refuses to materialize a shift instance after its deadline, and per-task recurrence rolls successors forward until their deadline is future. **Requires a functions deploy for the server path.** **Cancelled** (2026-07-28, uncommitted) is the third terminal outcome — a manager/admin business decision taken from `pending`/`started` only, carrying a mandatory picklist reason, excluded from every count. The recurring-shift Automation Center is productionized: skeleton loading, premium header, slim tap-through cards, a per-routine details sheet (overview/schedule/next execution/history/failure info/generated task/actions), and confirmed delete. |
| **Schedule** | Weekly roster, shift swaps, leave, day notes, configurable shift hours, shift templates, Final View + PNG export |
| **Branches** | CRUD, soft delete, swap policy, GPS geofences |
| **Admin** | User administration, account provisioning, Admin Home V2 command center. **Employees P19** (2026-07-27, uncommitted): a presentation-only, scalable directory pass — compact desktop header summary + Create Employee CTA, horizontal Branch/Role/Status/Sort/View controls, lazy list/natural-height two-column rendering (no fixed card extent), inline task KPIs, and Details/Edit with existing secondary actions in an overflow menu. The desktop FAB is removed while mobile keeps it; routing, cubits, repositories, and account semantics remain unchanged. **"Today" strip fix (2026-08-01, committed `fdaf66d`):** `admin_dashboard_screen.dart`'s `_today()` gained an `Open` stat (pending/started/completed/rejected — the same definition Task Management's "Active" uses) to answer "how much is on the table", since `Running now` (`started` only) was being misread as that number. `Delayed` renamed to **`Late`** with `AppColors.error` (was amber) — one concept, one name, one colour with Task Management's `Late` and Operations' `Late tasks`; grepped for other `Delayed` task copy, found none. `Approval rate` (a second, disagreeing completion formula — `Approved ÷ (Approved + Rejected)` from `StatisticsCubit`, next to §10.1's `Approved ÷ (Approved + Missed)`) is removed. `_today()` no longer subscribes to `StatisticsCubit` at all — `Completed today` now derives from the task stream (`completedTodayCount`, new in `task_metrics.dart`, reusing `isTaskInActiveWindow` so it can't drift from what a drill-down would list) instead of the lifetime-scoped `StatisticsCubit.completedTasksToday`. Every cell except `Due soon` is now tappable (`Stat.onTap` → `FilteredTasksScreen`, with a one-line `description`); `Due soon` stays inert on purpose — no `TaskFeedFilter` can reproduce `schedulePhase`'s dueSoon precedence (it excludes `completed`/`waitingReview` even though the active window includes them) without either an over-counting filter or a reverse dependency from `task_feed.dart` into `task_schedule.dart`. `manager_home_screen.dart`'s own `Completed today` (line ~130) reads the same `StatisticsCubit` field but isn't tappable, so it has no count-vs-list risk today — left unchanged, report-only per this pass's scope. |
| **Operations** | Branch Operations cockpit, workload derivation, KPI drills, and a visible branch-scoped Automation summary opening the existing Center sheet |
| **Communications** | Broadcasts, templates, custom audiences, scheduler, reminders |
| **Notifications** | In-app inbox + deep-link resolver. **Android has a named high-importance `drop_default` FCM channel; iOS app-side APNs entitlement/background-mode wiring is complete, awaiting only the APNs credential.** Inbox rows redesigned 2026-08-01, two passes (owner: *"looks bad and messy"*, then *"all the tasks look the same"*). Rows are now **subject-led**: `kicker (event, 10px uppercase, semantic tint) → subject (14.5px, ONE line) → context (12px grey)`. Every producer writes the event into `title` and the thing into `body`, so the old headline was the one line guaranteed to repeat; `title` is now the kicker and `body` the headline, split on its first ` • `/` — ` by pure `splitNotificationBody`. Case status, request lifecycle/comment, and attendance correction/auto-close bodies now lead with their subject; requests use the requester's own `details.message` (**not** the rolling `lastEventPreview`, which by approval time may hold the latest comment) then `REQ-######`, and attendance uses `Shift, d Mon`. Employee broadcast rows are non-navigable reading text with **no line cap**, so the inbox retains the full message; navigable subjects remain one line. No stored data changed. The duplicated category pill is gone, read/unread is carried by row brightness, and only a **critical unread** item keeps the semantic halo. Day headers are a labelled hairline with that day's unread count; the filter rail is edge-masked and each pill carries its unread count. **`route: "attendance"` was a dead tap** (the resolver had no case for the string `writeAttendanceNotifications` has always stamped) — now opens `/attendance/record/:id`, falling back to `/attendance/review` · `/attendance/history` by role; **client-side, no deploy needed**. **Delivery hardening (2026-08-02, DEPLOYED):** scheduled broadcasts claim their due instant before dispatch (no duplicate after an uncertain finalize; a claimed failed run is consumed), `approveSwap` server-writes both `swapApproved` inbox docs after the roster transaction, case reopen suppresses the manager actor via `statusChangedBy`, and inline broadcast pushes retry one transient Admin Messaging failure while retaining inbox-first delivery. |
| **Cases** | Private employee ↔ manager/admin conversations, confidential reporter split |
| **Requests** | Employee → manager yes/no approvals |
| **Statistics** | Live role-scoped counts on all three dashboards |
| **Employee Home** | **Hero reworked 2026-08-01.** The progress ring counted *in review* as finished, so it showed "3 of 3" beside "1 in review · 2 done"; it now uses the same `done = approved + completed` as the strip's Done cell. (It was deleted in the first pass and **owner-restored** the same day at 78px beside the shift — kept on the condition that it counts what the strip counts, and it is the **only** place the ratio is drawn.) The green **"All caught up!"** banner is deleted — third restatement of a finished day, and the only colour on screen; its "Open all tasks" row stays. The card also holds the **clock state** (`Clocked in 8:04 · 6h 30m on shift` / amber `Not clocked in` once the shift is underway / grey `Clocked out`), which had **no presence on Home before** despite being a twice-daily action reachable only via an unlabelled fingerprint icon. The button **hands off to the Attendance screen** — it does not clock in (GPS + geofence rules stay in one place), and Home never calls `previewLocation()` so it can't provoke a location prompt. ⚠️ Home now holds two Firestore attendance listeners while open. Strip zero-columns collapse to *"Nothing to do"* |
| **Design system** | Monochrome V2 primitives. Admin Dashboard V2 owner-signed-off. **Task card border language** (ADR-014) live on Employee Home: the 1px edge is the state and never moves; only an unopened `pending` task gets the attention treatment |
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
| P6 — Realtime (Socket.IO) | Done, **uncommitted** (2026-07-22). Protocol read from the `drop-api` gateway (namespace `/chat`, handshake `auth.token` = Firebase ID token, `conversation:join`/`leave` with `{ok,error?}` acks, server events `message:new`/`read`/`deleted`/`deleted-for-me`, auth reject = `connection:error` + disconnect). New `ChatRealtime` domain port + `ChatSocketService` (`socket_io_client ^3.1.6`, the only file importing it): refcounted connect (first join) / teardown (last leave), **self-owned reconnect** (rebuilt socket + fresh token each attempt, exp. backoff ≤30s, force-refresh after auth reject), room re-join on reconnect. `ChatConversationCubit` (additive `realtime:` param): live `message:new` inserted by `seq` + deduped, `message:read` → status READ, reconnect → newest-page REST reconcile. **REST stays the only write path & source of truth** |
| P7 — Message deletion UI | Done, **uncommitted** (2026-07-22). Long-press → bottom-sheet menu (`chat_message_actions.dart`) → Cases-style confirm → the existing use cases. **Delete for me** always offered; **Delete for everyone** offered only on own non-deleted messages (identity fact — the real rules, sender-only + 1h window, stay server-enforced; a 403 surfaces the server's message). In-flight delete dims the bubble (`deletingMessageId`, one at a time). Live `message:deleted` now tombstones in place (client mirrors the backend placeholder constant) and `message:deleted-for-me` removes cross-session |
| P8 — Inbox realtime | Done, **uncommitted** (2026-07-22). Same shared socket (no second service): `ChatRealtime` gains `attachInbox`/`detachInbox` — inbox interest that keeps the connection alive with **no room join** (the personal `user:{id}` room already delivers `message:new` for every conversation). `ChatListCubit` (additive `realtime` seam, attached on first load) bumps the row to top with fresh activity, seeds its unread map from the server-computed `unreadCount` in `GET /conversations`, then applies socket deltas; opening a conversation clears that count via `clearUnread`. It dedupes by per-conversation `seq`, refreshes on an unknown-conversation message or a reconnect, and tombstones a previewed line on live delete-for-everyone. Loaded state carries `previews`/`unreadCounts` maps into the Phase-4 tile slots. **REST stays the source of truth**; pagination unchanged |
| P9 — New-conversation flow | Done, **uncommitted** (2026-07-22; directory scope superseded by P12). Inbox FAB (always) + empty-state "Start Chat" CTA → `/chat/new` teammate picker (`NewChatScreen`/`NewChatView` + `NewChatCubit` over `GetChatDirectory`): every active user except the current user, search, avatar · name · role. Selecting one calls `StartConversation` and `pushReplacement`s to the thread (Back → inbox); server get-or-create means an existing pair opens the same thread, no duplicate. **Backend contract change (`drop-api`):** `POST /conversations` `targetUserId` is now the teammate's **Firebase uid** (external subject), resolved server-side to the internal participant via the existing identity resolver (get-or-create — provisions a teammate who's never opened chat); clients never hold other users' internal UUIDs. Self-start rejected 400 |
| P10 — Real profiles + polish + LAN | Done, **uncommitted** (2026-07-23; directory scope superseded by P12). **Real titles:** `GET /conversations` returns `counterpartExternalId` (Firebase uid, resolved through the flat `GetChatDirectory` Firebase lookup); the inbox renders real **avatar · name · role**, and the thread header shows the counterpart avatar+name — no backend id is ever a UI key. **Composer** redesigned premium (rounded 46px pill, reactive send button, multiline). **Thread** gets message grouping (time on the run tail only) + a premium empty state. **Networking:** backend binds `0.0.0.0:3000`; a debug-only Android manifest allows cleartext; one `--dart-define=API_BASE_URL=http://192.168.1.8:3000` wires REST + socket for both the iOS Simulator and a physical Android device. `ApiClient` + `ChatListCubit` now log the real transport error (no more silent loading→error loop). Composer refined (reactive send button + lifted bar + safe-area anchor), empty state personalized ("Say hello to {first name}"). **Verified live on the iOS Simulator via the LAN IP: real profiles, inbox, thread, and a live message send all work end-to-end** |
| P11 — V1 polish (composer · reply · attachments · optimistic · perf) | Done, **uncommitted** (2026-07-24). **Composer** rebuilt premium (r26 pill, left paperclip → attachment sheet, circular send that animates in only when there's text/an attachment, staged-attachment preview). **Reply** two ways: WhatsApp swipe-right (`_SwipeToReply` — bubble tracks the drag, reply glyph + one haptic at threshold, spring-back) **and** long-press menu (Reply · Copy · Message info · Delete-for-me/everyone); quoted preview renders in the bubble and as a composer banner. **Attachments** (`ChatAttachmentSource` seam + `ChatAttachmentPicker` over image_picker/**file_picker**): Camera/Gallery/Documents sheet, preview-before-send, premium file cards, optimistic image thumbnail from local bytes, full-screen `ImageViewerScreen` (local bytes now, brokered URL via `GetChatAttachmentUrl` for received). **Message info** screen — only backend-provided fields (sent time, status, sender, ids, seq, attachment, reply ref), IDs tap-to-copy. **Optimistic send** (`sendMessage` returns immediately, inserts a `SENDING` bubble, background POST → replace with server msg / mark `FAILED` + tap-to-retry reusing the idempotency key). **Perf:** `ChatThreadCache` (in-memory) paints a re-opened thread instantly, then refreshes; skeleton loader for a cold open. All presentation/cubit — REST stays the only write path. **NOT device-verified this session** (user reviews on-device) |
| P12 — Flat participant directory | Done, **uncommitted** (2026-07-24), [ADR-012](docs/decisions/ADR-012-chat-directory-is-flat.md). The picker was a bare own-branch Firestore read, but **admins are provisioned branchless** (the role is global) — so an admin's picker was empty and no staff member ever saw an admin (confirmed against live data: 1 branchless admin, 8 employees over 2 branches, 1 manager). Rather than special-case admins, chat's access model is now **flat: every authenticated user may message every other active user**. `GetChatDirectory` = ONE unfiltered `getAllUsers` read, filtered only by self-exclusion + `isActive` (applied in the use case so a legacy doc missing the field keeps its `true` default); shared by the picker *and* the inbox directory. **No branch or role predicate anywhere in the chat path.** New `AuthRepository.getAllUsers`. **Requires a rules deploy** — `users` read is now `if isSignedIn()`, replacing the owner/admin/same-branch disjunction |
| P16 — Final UX/UI polish | Done, **uncommitted** (2026-07-24). Presentation-only; no architecture / API / backend change. **Conversation options** three-dot menu (info · search · mute · clear · delete; both destructive actions confirm). **Conversation Info screen** — avatar · name · position/role · branch (Firebase directory + `BranchCubit`) · shared media/document counts · the same actions; **online/last-seen deliberately omitted** (no backend presence — DROP doesn't fabricate it). **In-conversation search** — live (200ms debounce) tone-aware match highlighting, emphasized active match auto-scrolled into view, `n/total` + prev/next (Enter = next), "No matching messages." bar. **Clear chat history** = `clearChatForMe()`, a bulk delete-for-me over the loaded window via the **existing** per-message endpoint, pooled 3 (`mapPooled`); counterpart keeps their copy; Delete conversation reuses it then pops. **Desktop** — right-click context menu (Reply · Copy · Forward *(placeholder)* · Delete for me/everyone) sharing one action handler with the mobile sheet; pointer cursor on tappable bubbles. **Inbox loading** is now a tile skeleton list. Added `AppSnackbar.info`/`context.showInfo`; `ChatThreadArgs.counterpartExternalId`. **Not device-verified this session** |
| P15 — Feature improvements | Done, **uncommitted** (2026-07-24). Six additive upgrades, no UI-architecture / realtime / backend-contract change: **(1) document preview** — `ChatDocumentService` downloads (cached, dedup by attachment id) + opens PDF/DOC/DOCX/XLS/XLSX/PPT/PPTX/TXT via the platform default app (`open_filex` mobile · OS `Process` desktop), loading + error-with-**Retry** (in-app PDF renderer deferred as build-risky); **(2) inbox search** — AppBar search → debounced O(n) live filter on name/role/last-message, scroll-preserved, "No conversations found." empty state; **(3) unread badge** — sidebar Chat row shows live `ChatListCubit.totalUnread` (hidden at 0); **(4) Recent Messages** dashboard widget (`RecentMessagesCard`, top-5, avatar·name·preview·time·unread, on employee + manager homes); **(5) in-app notifications** — tappable banner from any screen via new `ChatListCubit.incoming` stream + `ChatNotificationListener`, suppressed for the on-screen conversation (`AppDependencies.activeChatConversation`); desktop uses the same banner (OS-level local notif out of scope); **(6) document bubble** redesign (format icon + `PDF • 577 KB` + desktop hover Open/Download). `open_filex` added. **Not device-verified this session** (`pod install` for open_filex) |
| P14 — Offline cache (Drift/SQLite) | Done, **uncommitted** (2026-07-24). Production-grade local cache under `features/chat/data/local/` (`ChatDatabase` + `ChatLocalDataSource`): persists conversations, messages, **reply + attachment metadata**, and a durable text-send outbox — **never image/attachment bytes** (metadata + on-demand brokered URLs only). `ChatRepositoryImpl` takes an *optional* local datasource (null ⇒ REST-only original, so fakes/tests are untouched): read-through / write-through, offline fallback to cache, cache-first back-pagination (`local:<seq>` cursor), conflict-safe upserts (idempotent by id, ordered by server `seq`). `ChatThreadCache` is now two-tier (in-memory + durable Drift) ⇒ instant open survives a restart and realtime messages persist via the existing `_emit → put`. Cubit changes additive only (cold-restore, keep local bubbles across refresh, adopt outbox + auto-retry failed sends on load/reconnect). Cache wiped on sign-out. **No UI / composer / realtime / backend-contract change.** +15 tests. **Not device-verified this session** |
| P13 — Mobile UI refinement | Done, **uncommitted** (2026-07-24). Presentation-only polish pass, no backend/contract change. **Alignment root-cause fix:** own messages were rendering LEFT — `_SwipeToReply`'s `Stack` shrink-wraps the bubble and pins it `topStart`, collapsing the bubble Column's `crossAxisAlignment`, so swipe-enabled (confirmed) sends aligned left while `local:`/tombstone bubbles aligned right. Side is now enforced by an `Align` at the list-item level (works in both the swipe and non-swipe paths). Grouping keys on **side/ownership** not raw `senderId` (folds optimistic `local:` bubbles into my run; a side change always forces a tail + gap, so two people's runs can't merge). Bubble radii 20 + 6pt tail, padding 14×9, within-group gap 3 / between-group 12, max width 0.76·w cap 560. **Composer:** animated focus (border brightens/thickens on focus), 24pt pill, tightened padding. Ticks unchanged (monochrome per the design ruling). Verified on the iPhone 17 simulator |
| P17 — Blocker pass + prod verification | Done (Flutter **uncommitted**; backend **committed+pushed**, not yet live), 2026-07-25. Owner re-flagged the original blockers over new features; ran the full matrix on two iOS sims against Railway prod (`ziad@arkandrop.com` ↔ `test@drop.com`). **Composer rebuilt iMessage-style** (`chat_composer.dart`): one hairline-outlined capsule with a **transparent interior** (stroke defines the field, not a filled slab), `+` glyph + 30px send disc both inside, disc inset 4px, focus brightens the stroke without thickening. **Scroll-to-latest fix** (`chat_message_list.dart`): opening a thread landed mid-history because inline images grow after the single first-frame jump; a `NotificationListener<ScrollMetricsNotification>` now re-pins to bottom while the reader is at the bottom. **Backend read-receipt fix** (`drop-api` `9c4cd2a`): "seen" reverted to grey on restart because the history read path dropped the persisted `message_receipt.read_at` and the DTO hardcoded `status:'SENT'` — now joined onto the page (`MessageHistoryPage.readReceipts`), carried via `MessageView.readAt`, derived `status:'READ'`; +3 tests, 87 backend tests pass. **Verified live cross-device:** text both ways, image A→B inline in realtime + green "seen" tick, fullscreen viewer on the receiver, inbox real names/roles/timestamps/`You:` previews with no IDs. **Gated:** "seen survives restart" needs Railway to serve `9c4cd2a` (see below); `GET /conversations` now supplies server-computed `unreadCount`, which seeds persistent inbox and navigation badges while realtime applies deltas |
| P18 — macOS Chat list polish | Done, **uncommitted** (2026-07-27). Presentation-only. `/chat` keeps its existing list → route-to-thread navigation while its desktop header opts into a compact title area and persistent dark `Search conversations...` field. Rows retain 56px avatars while gaining 16/600 titles, one-line previews, inset dividers, soft hover/selected treatment, and compact circular unread badges; the empty inbox is now icon-led with the requested no-selection copy. Sidebar selection and the profile footer are calmer and lower-depth. `AppSearchField` gains reusable compact/focus support. No cubit, router, API, backend, model, or data-layer behavior changed |
| Notifications | ❌ Not started |

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

⚠️ **Opening matters more than saving on mobile.** `getDownloadsDirectory()` is
desktop-only, so on a phone both exports land in the app sandbox where nobody
would find them; mobile therefore opens the file through `open_filex` so it can
actually be sent on. Desktop skips that — it already writes to Downloads.

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

### Analyzer info (1)

The remaining `use_null_aware_elements` info is the pre-existing test-style lint
in `task_submission_gate_test.dart`. It is not an Automation Center finding.

### Failing tests (2)

Both reproduce with the working tree stashed — neither is caused by current work.

> The three `notification_tap_flow_probe_test.dart` failures were **fixed
> 2026-07-25** by deleting the temporary `debug_auth_probe.dart` and its two
> `AuthCubit` call sites (the 401 chat investigation it served is long done). That
> probe touched `FirebaseAuth.instance` during `restoreSession` in a Firebase-less
> test; removing it is dead-code cleanup that also greened those cases.

`test/splash_centering_test.dart` — both cases fail. The splash lockup's optical
centering is off: the combined logo→bar bounding box centre sits at **375.5** where
the test expects **400 ±1** (and **291.7** vs **310 ±1** at 1024×720). Either the
splash layout regressed or `kSplashOpticalLift` changed without the test following.
**Pre-existing and unrelated to any current work** — but it means `flutter test` is
not green, so a real regression could hide behind it. Worth fixing or deleting.

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
  config describes what ships. **Still open:** `AttendanceService.configFor`
  returns one constant for everyone, so `soft` is reachable but unselectable —
  per-branch `branches/{id}/attendanceConfig` is the follow-up.
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

Nothing below works in production until it is deployed. The missing live
`shift_templates` rule was confirmed on 2026-07-18; treat the remaining targets as
**believed-pending and worth verifying against the console** before assuming.

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

### Then

1. **On-device attendance QA** — GPS clock in/out on real hardware, both platforms.
2. **Fix or delete `splash_centering_test.dart`** so the suite is green.
3. **Supply the iOS APNs credential** — app-side Push/Background-Modes configuration is complete.
4. **Merge `feature/attendance-management`** once deployed and QA'd.
5. **Prune ~15 stale branches.**

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

1. **Deploy.** Everything else is downstream of it. A growing share of the app is
   inert in production and fails at runtime rather than at compile time.
2. **Close out attendance** — on-device QA, then merge.
3. **Get the suite green** — 2 failures is 2 too many to notice a third.
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
flutter test                             # expect: 1440 pass, 2 fail (pre-existing: 2 splash-centering)
(cd functions && node --test)            # expect: 68 pass
(cd firestore-tests && npm test)         # expect: 37 pass — needs the Firebase CLI + a JDK
grep -c "static const String" lib/core/routes/route_names.dart   # expect: 51
ls lib/features | wc -l                  # expect: 18
```

Routes live in [route_names.dart](lib/core/routes/route_names.dart) — read them
there rather than duplicating the table here. Firestore/Storage schema lives in
[docs/design/DATA_MODEL.md](docs/design/DATA_MODEL.md).
