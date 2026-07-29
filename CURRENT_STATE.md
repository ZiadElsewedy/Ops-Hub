# DROP — Current State

> **Today's snapshot. Nothing historical.** The moment something here becomes
> history, it moves to [CHANGELOG.md](CHANGELOG.md) and leaves this file.
>
> **Last verified against the code:** 2026-07-29.

## At a glance

| | |
| --- | --- |
| **Branch** | `fix-bugs` |
| **Build** | `flutter analyze`: 1 info, no errors/warnings (pre-existing test style) |
| **Tests** | **1132 pass · 2 fail** across 161 files (~26s) — the 2 remaining are the pre-existing splash-centering failures. Cloud Functions: **41 pass**; **Firestore rules: 26 pass** (`cd firestore-tests && npm test`); NestJS chat backend: **84 pass** (`cd ~/Desktop/Developer/drop-api && npx jest`) |
| **Blocking release** | Firebase deploy (rules · indexes · functions; live `shift_templates` rule missing) · recurring-template manager read isolation · iOS push unconfigured · attendance on-device QA. **(Chat P0-1 read-receipts + P1-1 unread counts are now LIVE on Railway `main`, commit `2513c89`, via PR #7/#8.)** |
| **Platforms** | iOS · Android · macOS |

DROP is **feature-complete for its intended scope** and gated on deployment and QA,
not on code. The largest open risk is that a growing set of features depend on Cloud
Functions and rules that have **never been deployed** — they fail at runtime, not at
compile time.

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
| **Roles & routing** | 46 routes, role-guarded. admin ⊇ manager |
| **Profile** | View/edit, avatar/cover upload, contact + payment (payment in a private subdoc; hidden for admin) |
| **Tasks** | Full workflow: create → execute (checklist · notes · proof) → review. Multi-assignee, recurrence, activity timeline, templates, shift assignment, work-type framework, Scheduling V2 (start/due windows + quick deadline presets). Generated recurring shift tasks now persist their resolved weekly window and unfinished `pending`/`started` instances automatically close as server-owned **Missed** at shift end; the status is closed, visible, and excluded from active/overdue queues. **Cancelled** (2026-07-28, uncommitted) is the third terminal outcome — a manager/admin business decision taken from `pending`/`started` only, carrying a mandatory picklist reason, excluded from every count. The recurring-shift Automation Center is productionized: skeleton loading, premium header, slim tap-through cards, a per-routine details sheet (overview/schedule/next execution/history/failure info/generated task/actions), and confirmed delete. |
| **Schedule** | Weekly roster, shift swaps, leave, day notes, configurable shift hours, shift templates, Final View + PNG export |
| **Branches** | CRUD, soft delete, swap policy, GPS geofences |
| **Admin** | User administration, account provisioning, Admin Home V2 command center. **Employees P19** (2026-07-27, uncommitted): a presentation-only, scalable directory pass — compact desktop header summary + Create Employee CTA, horizontal Branch/Role/Status/Sort/View controls, lazy list/natural-height two-column rendering (no fixed card extent), inline task KPIs, and Details/Edit with existing secondary actions in an overflow menu. The desktop FAB is removed while mobile keeps it; routing, cubits, repositories, and account semantics remain unchanged. |
| **Operations** | Branch Operations cockpit, workload derivation, KPI drills, and a visible branch-scoped Automation summary opening the existing Center sheet |
| **Communications** | Broadcasts, templates, custom audiences, scheduler, reminders |
| **Notifications** | In-app inbox + deep-link resolver. **Android push only** |
| **Cases** | Private employee ↔ manager/admin conversations, confidential reporter split |
| **Requests** | Employee → manager yes/no approvals |
| **Statistics** | Live role-scoped counts on all three dashboards |
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
| P3 — Reporting & analytics | Done, **uncommitted** (2026-07-28). Pure `domain/task_outcomes.dart` locks the four-way classification: completion rate = **Approved ÷ (Approved + Missed)** with Cancelled excluded from both sides (ungameable), cancellations on their own line **by reason code**, Late as timeliness on completed work, and Missed surfaced on the admin task overview. No new route or screen. |

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
| P2 — corrections + audit | Done. Server-authoritative audit + `attendance_corrections/` approval object |
| P3 — GPS engine | Done. `geolocator`, Haversine verification, separate clock-in/out verifications |
| P3 — UI | Done. Employee clock screen · admin board · geofence editor |
| History | Done. Ledger (`/attendance/history` self · `/attendance/review` branch, admin‖manager) + audit-log record details (`/attendance/record/:id`). Reuses the existing reads + `AttendanceStats`; holds ADR-009/010 (no score/analytics/export) |
| **Deploy** | ❌ **Not done** — functions + rules + indexes |
| **On-device QA** | ❌ **Not done** — GPS needs real hardware; simulators cannot validate this |

> Attendance minutes feed payroll. Do not ship it on a simulator's word.

### Removed — do not re-add

| Feature | Removed | Why |
| --- | --- | --- |
| **Schedule Health** | 2026-07-15 | [ADR-007](docs/decisions/ADR-007-schedule-health-removed.md) — advice that never gated anything |
| **Community Hub / DROP Events** | 2026-07-15 | Owner request. Live Firestore data left untouched |
| **Analytics pipeline** | 2026-06-23 | [ADR-009](docs/decisions/ADR-009-no-analytics-pipeline.md) — vanity metrics |
| **Attendance breaks** | 2026-07-15 | Descoped for MVP. `AttendanceBreak` kept as a dormant extension point |
| **Shift foundation (Phase 2)** | Phase 10 | Dead code; the weekly schedule is the roster |
| **Public registration / OTP / Google** | 2026-06-26 | DROP is admin-provisioned |

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

- **iOS push is unconfigured** — no entitlements, no `aps-environment`, no APNs key.
  FCM cannot deliver to iOS. Android works. This has been open since Phase 11.
- **Firebase Storage** must be enabled in the console for proof/media uploads.
  A "not authorized" error on upload is *this*, not a code bug.
- **First admin** is bootstrapped out of band (set `role: admin`, `isActive: true`
  in the console).

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
  iOS-push issue — fuzzy category mapping, left for a separate judgment pass), and
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
| `functions` | 23 functions incl. `onAttendanceWritten`, `onAttendanceCorrectionWritten`, `autoCloseAttendance`, `generateShiftTaskInstances`, **`autoEndRecurringShiftTasks`** (15-min missed close **+ the new notify-on-Missed**), **`onRecurringTemplateWritten`** (automation lifecycle audit), `onCase*`, `onRequest*`, `sendBroadcast`, `claimFcmToken`; **`sendNotification` now whitelists `taskCancelled` / `taskReportedIncorrect`** | Attendance audit · recurring deadlines · automation · **cancel + report notifications** · cases · requests · **all push** |
| `firestore:rules` | `shift_templates`; Task review-field freeze + non-decreasing `activityLog` + server-owned Missed lock; **task cancellation** (manager/admin-only, `pending`/`started` predecessor, mandatory picklist reason, cancelled record frozen) + the **admin terminal correction** carve-out + the **incorrect-report** guards; attendance + corrections; cases; requests | **Schedule creation/configurable hours** · Task hardening (P0/P1) · recurring deadline integrity · **cancellation integrity + terminal correction** · attendance · cases |
| `firestore:indexes` | `tasks` composites (`branchId`+`assignmentType`+`shift`; `assignmentType`+`status`+`deadline`); **`automationRuns` `(branchId,templateId,startedAt)` + `(branchId,status,startedAt)`** | Employee shift-task stream (`failed-precondition` without it) · automatic recurring close · automation run history |
| `storage` | `validMedia()` + orphan GC | Media hardening |

```bash
firebase deploy --only functions,firestore:rules,firestore:indexes,storage
```

Requires the **Blaze** plan.

### Then

1. **On-device attendance QA** — GPS clock in/out on real hardware, both platforms.
2. **Fix or delete `splash_centering_test.dart`** so the suite is green.
3. **Configure iOS push** — APNs key + Push/Background-Modes capability.
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
flutter test                             # expect: 1132 pass, 2 fail (pre-existing: 2 splash-centering)
(cd functions && node --test)            # expect: 41 pass
(cd firestore-tests && npm test)         # expect: 26 pass — needs the Firebase CLI + a JDK
grep -c "static const String" lib/core/routes/route_names.dart   # expect: 46
ls lib/features | wc -l                  # expect: 18
```

Routes live in [route_names.dart](lib/core/routes/route_names.dart) — read them
there rather than duplicating the table here. Firestore/Storage schema lives in
[docs/design/DATA_MODEL.md](docs/design/DATA_MODEL.md).
