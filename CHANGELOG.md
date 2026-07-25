# Changelog

> **Chronological record.** Entries are summarized as they age — an entry earns
> detail while it is still actionable and collapses to a line once it is settled
> history. **Git has the full detail**; this file exists to answer *when* and
> *roughly what*, not to reproduce a diff.
>
> Current status is [CURRENT_STATE.md](CURRENT_STATE.md). Why a decision was made
> is [docs/decisions/](docs/decisions/). How a feature works is
> [docs/design/](docs/design/).

Format: loosely [Keep a Changelog](https://keepachangelog.com). Nothing has been
released — DROP ships from branches and has no version tags.

---

## Unreleased

### 2026-07-25

- **Code-quality & refactoring sprint (behavior-preserving; no UI/logic change).**
  Baseline held throughout: `flutter analyze` = 1 info; `flutter test` moved from
  1061 pass / 5 fail to **1066 pass / 2 fail** (the 2 remaining are the pre-existing
  splash-centering failures).
  - **Dead code removed.** Deleted the temporary `core/network/debug_auth_probe.dart`
    + its two `AuthCubit` call sites (self-labeled "DO NOT COMMIT"; the 401 chat
    investigation it served is done) — this also greened the 3
    `notification_tap_flow_probe` tests, which had failed only because the probe
    touched `FirebaseAuth.instance` in a Firebase-less test. Removed the 4 unused
    legacy social counters from `ProfileEntity`/`ProfileModel` and the unread
    `savedAudiencesCollection` constant.
  - **Logging consolidated onto `AppLog`.** Converted `developer.log` → `AppLog` in
    15 feature files (cubits + datasources) so their failures reach the crash-report
    breadcrumb ring. Left 4 sites intentionally: `main.dart` + `notification_service`
    (deliberate FCM diagnostics for the open iOS-push issue) and the two
    `domain/usecases/` notify events (kept pure — must not import Flutter-coupled
    `AppLog`).
  - **Unused dependency removed.** Dropped `flutter_secure_storage` (^9.2.2) — zero
    references app-wide; updated the PROJECT_CONTEXT tech-stack table to match.
  - **Reclassified as *not* safe refactors:** the "duplicate" confirm dialogs
    (chat/automation) deliberately use `darkSurfaceElevated` + distinct radii vs.
    `showConfirmDialog`'s `darkSurface`/r20 — consolidating would change pixels, so
    they were left as-is per the no-UI-change / owner-sign-off rule.

### 2026-07-24

- **Chat final UX/UI polish pass (P16).** Presentation-only; no architecture,
  API, or backend change.
  - **Conversation options** — a three-dot AppBar menu on the thread:
    Conversation info · Search in conversation · Mute (local, UI-ready — no
    backend mute exists) · Clear chat history · Delete conversation. Both
    destructive actions confirm first.
  - **Conversation Info screen** (`conversation_info_screen.dart`) — avatar ·
    name · position/role · branch (resolved from the Firebase directory +
    `BranchCubit`), shared **media** / **documents** counts, and the same
    actions. **Online/last-seen is deliberately omitted** — the backend exposes
    no presence and DROP does not fabricate it.
  - **In-conversation search** — AppBar search field, live (200 ms debounce),
    monochrome tone-aware match highlighting inside bubbles, an emphasized
    active match auto-scrolled into view, `n/total` counter with prev/next
    (Enter = next), and a "No matching messages." bar.
  - **Clear chat history** — `ChatConversationCubit.clearChatForMe()`: a bulk
    delete-for-me over the loaded window via the **existing** per-message
    endpoint, pooled 3-at-a-time (`mapPooled`). The counterpart keeps their
    copy. Delete conversation reuses it, then pops.
  - **Desktop** — right-click context menu on any message
    (`showChatMessageContextMenu`: Reply · Copy · Forward *(UI placeholder)* ·
    Delete for me / for everyone) sharing one action handler with the mobile
    long-press sheet; pointer cursor on every tappable bubble.
  - **Loading** — the inbox's generic spinner is now a shimmering
    conversation-tile skeleton list.
  - `AppSnackbar.info` + `context.showInfo` added (neutral notices);
    `ChatThreadArgs` carries `counterpartExternalId` so Info can resolve
    role/branch. +2 tests.
- **Chat feature improvements (P15).** Six product upgrades, all additive; no
  UI-architecture, state-management, realtime, or backend-contract change.
  1. **Document preview** — tapping a document (PDF/DOC/DOCX/XLS/XLSX/PPT/PPTX/
     TXT) downloads it to an on-disk cache (dedup by attachment id — no repeat
     downloads) and opens it with the platform default app (`open_filex` on
     mobile; the OS opener via `Process` on desktop). Loading indicator +
     friendly error snackbar with **Retry**. New `ChatDocumentService`; bytes
     live in the OS temp dir, never the Drift cache. (An in-app PDF *renderer*
     was intentionally deferred — bundling a native PDF engine is build-risky and
     unverifiable here; the spec's "platform default" path is used.)
  2. **Conversation search** — a search icon in the inbox AppBar expands to a
     live, debounced (220 ms) search over counterpart name/role + last message,
     O(n) client-side; scroll preserved (PageStorageKey); "No conversations
     found." empty state.
  3. **Unread badge** — the desktop sidebar Chat row shows the live total unread
     (`ChatListCubit.totalUnread`), hidden at zero, reactive.
  4. **Recent Messages dashboard widget** — `RecentMessagesCard` (avatar · name ·
     last message · time · unread), capped at 5, tap opens the thread, "No recent
     conversations" empty state; added to the employee + manager homes.
  5. **In-app notifications** — a new message raises a tappable banner from any
     screen (`ChatNotificationListener` over a new `ChatListCubit.incoming`
     stream), suppressed for the conversation on screen (tracked via
     `AppDependencies.activeChatConversation`); tapping opens it. Works on
     desktop too; a true OS-level local notification (native plugin + per-platform
     setup) is out of scope.
  6. **Document bubble redesign** — compact card with a format-specific icon and
     a `PDF • 577 KB` meta line; desktop hover reveals **Open**/**Download**.
  `open_filex` added. `AppSnackbar.error/success` gained an optional action
  (retry). +5 tests; full suite 1059 pass / 5 pre-existing fail; analyze clean.
  **Not device-verified this session** (`pod install` needed for open_filex).
- **Chat offline cache — Drift/SQLite (P14).** A production-grade local cache
  under `features/chat/data/local/` gives the thread and inbox WhatsApp/Telegram
  behaviour: instant open (incl. cold start), offline reads, and background
  sync. `drift`/`sqlite3_flutter_libs` added (pinned 2.26.0 to keep `drift_dev`'s
  analyzer on the freezed-compatible line). `ChatDatabase` (3 tables:
  conversations · messages with **reply + attachment metadata** flattened in ·
  a durable send outbox) + `ChatLocalDataSource` own all row↔entity mapping,
  conflict-safe upserts (idempotent by id, ordered by server `seq`), cache
  pagination, and invalidation. **No image/attachment BYTES are ever persisted**
  — metadata + on-demand brokered URLs only. `ChatRepositoryImpl` gains an
  *optional* local datasource (null ⇒ the exact REST-only original, so all
  existing fakes/tests are untouched): read-through / write-through, offline
  fallback to cache when the network is unreachable, cache-first back-pagination
  via a `local:<seq>` cursor, and a text-send outbox (enqueue-before-POST,
  drain-on-ack). `ChatThreadCache` became two-tier (in-memory hot + durable
  Drift) so re-open survives a restart and realtime-delivered messages persist
  through the existing `_emit → put` path. Cubit changes are additive only:
  cold-restore-from-disk, keep local bubbles across a refresh, adopt the durable
  outbox and auto-retry failed sends on load + reconnect. Cache is wiped on
  sign-out (`AppDependencies.clearChatCache`, via the pre-sign-out hook).
  **No UI, composer, realtime, or backend-contract change.** +15 tests
  (`chat_offline_cache_test.dart`); full suite 1053 pass / 5 pre-existing fail.
- **Chat P0 image-send fix + production-readiness pass.**
  - **Image sending fixed (root cause proven, backend).** `drop-api`: the
    NestJS/Express default JSON body limit is 100 KB, but chat sends attachment
    bytes as base64 in the JSON body and the attachment domain allows 25 MiB —
    so every real photo was 413'd *before* validation/storage. Proven against
    Railway prod (300 KB body → 413, tiny → 401). Fix: take over body parsing
    and size the JSON limit to the configured attachment cap + base64 overhead
    (`main.ts`); `express` declared as a direct dep. Verified locally
    (300 KB/5 MB → 401, 40 MB → 413). Committed on `drop-api` (`746a804`);
    **needs a Railway deploy** to take effect in production.
  - **No internal IDs in the UI (P1):** removed the user-id line from the New
    Chat card; `chatCounterpartLabel` no longer embeds a UUID fragment (was
    "Teammate 019F8F") — it's a neutral id-free "Teammate"; Message Info drops
    Message/Conversation/Reference IDs and Sequence. Only avatar · name · role
    surface anywhere.
  - **Delivery status (P2):** WhatsApp pattern — clock (sending) → double **grey**
    check (delivered) → double **green** check (read). Owner override of the
    prior monochrome-ticks ruling.
  - **Composer redesigned (P3):** a single cohesive pill with the attachment `+`
    and send controls *inside* the field (no detached satellite buttons),
    focus-animated border, bottom-aligned controls that track multiline growth.
    Fixed a theme-border leak (the global `inputDecorationTheme.focusedBorder`
    drew a second outline around the text) by nulling every `*Border` state on
    the field — the pill now reads as one unit.

- **Chat UX overhaul — inbox, previews, composer, attachment sheet
  (uncommitted, presentation-only).** No backend/contract/cubit/repo changes.
  - **Empty conversations are now hidden** (WhatsApp/Telegram behavior): the
    inbox filters out never-messaged conversations (no `lastMessageAt` and no
    live preview). Returning from a thread re-pulls the list so your *own* first
    message surfaces (the socket never echoes your sends back to you).
  - **Real last-message previews** replace the "Tap to open"/"No messages yet"
    placeholders: resolved from the live socket preview → in-memory thread cache
    → a one-item history fetch (reusing `LoadChatHistory`), formatted as the
    body / "Photo" / file name / "You: …". New `ChatPreview` + `chatMessage
    PreviewText` in `chat_format.dart`; `AppDependencies.latestChatMessage`.
  - **Redesigned inbox tile**: 56px avatar, name + right-aligned time, real
    preview + unread badge, subtle role, iOS-style press highlight (no ripple),
    inset hairline separators.
  - **Attachment sheet** rebuilt premium (icon-chip rows with labels/subtitles).
    Videos intentionally omitted — the API accepts no video attachment format,
    so it would need a backend/contract change to work.
  - **Composer** press-scale feedback on the `+` and send buttons.

- **Chat directory rules DEPLOYED + card polish.** The flat `users` read rule
  (`allow read: if isSignedIn()`, ADR-012) was **deployed to production**
  (`bazic-d9ad7`) — this is what actually makes company-wide chat work at
  runtime. **Root cause of the "Teammate 019F8F" placeholder** (audited, not
  guessed): the client resolves counterpart names via a Firestore directory
  (`getAllUsers`), but the flat rule was undeployed, so a non-admin's unfiltered
  `users` query was denied, the directory stayed empty, and every counterpart
  fell back to a label built from the backend's internal UUID. The logged-in
  user was an *employee*; an admin never hit it. Backend was never implicated —
  `counterpartExternalId` (the counterpart's Firebase uid) is correctly returned.
  Presentation: the teammate picker card now shows the **user id** (with photo ·
  name · role, nothing private beyond that); the inbox fallback avatar is now an
  **initials chip** instead of the generic grey person glyph (`UserAvatar`
  already did initials — only the tile's unresolved branch used the icon).

- **Chat mobile UI refinement (uncommitted).** Presentation-only; no backend
  or contract change. **Fixed own-message alignment** — my messages were
  rendering on the left. Root cause: `_SwipeToReply` wraps a confirmed bubble in
  a `Stack`, which shrink-wraps and pins to `topStart`, collapsing the bubble
  Column's `crossAxisAlignment`; swipe-enabled (sent) messages aligned left
  while `local:`/tombstone bubbles aligned right. Side is now set by an `Align`
  at the list-item level, robust in both paths. Grouping keys on side/ownership
  instead of raw `senderId` (folds optimistic bubbles into my run; a side change
  always forces a tail + gap so two people's runs never merge). Softer bubble
  radii (20 + 6pt tail), roomier padding, tighter within-group spacing, wider
  max width. **Composer** gains an animated focus state (border brightens and
  thickens on focus), a 24pt pill, and refined padding. Delivery ticks unchanged
  (monochrome, per the design ruling). Verified on the iPhone 17 simulator.

- **Changed — chat's participant directory is now flat (uncommitted).**
  [ADR-012](docs/decisions/ADR-012-chat-directory-is-flat.md). Every
  authenticated user may message every other **active** user; the directory
  carries **no branch and no role predicate** in any layer.
  `GetChatDirectory` is a single unfiltered `getAllUsers` read whose only
  filters are self-exclusion and `isActive` — the latter applied in the use case,
  not as a query predicate, so a legacy doc missing the field keeps
  `UserEntity`'s `true` default instead of being silently dropped. One source of
  truth, shared by the picker and the inbox's name/avatar resolution.
  `AuthRepository.getUsersByRole` (added earlier the same day) is **removed** —
  it existed only to reconstruct "everyone" out of scoped reads.
  **`firestore.rules` — NEEDS DEPLOY:** `users` read is now `if isSignedIn()`,
  replacing the owner · admin · same-branch disjunction, which a flat directory
  subsumes entirely. Compensation stays private (owner + admin subdoc) and all
  writes are unchanged. Until deployed, the chat directory fails for non-admins.

  This supersedes the earlier fix the same day, which kept branch scoping and
  special-cased admins via a role read. The bug it fixed: an admin's picker was
  empty and staff never saw admins, because **admins are provisioned branchless**
  (`create_account_screen._needsBranch` — the role is global), so a
  `where('branchId', ==, …)` read returned nothing for an admin and could never
  contain one for anyone else. Confirmed against live data (1 branchless admin,
  8 employees over 2 branches, 1 manager). The NestJS backend was never
  implicated — it has **no role or branch concept at all**, and conversation
  creation only rejects self-chat.

- **Chat V1 polish (uncommitted).** Premium composer (paperclip + attachment
  sheet, reactive circular send, staged-attachment preview). Reply via
  WhatsApp swipe-right (`_SwipeToReply`, haptic + spring-back) and the
  long-press menu (Reply · Copy · Message info · Delete); quoted preview in
  bubble + composer banner. Attachments (Camera/Gallery/Documents) behind a
  `ChatAttachmentSource` seam over `image_picker` + new `file_picker` dep, with
  preview-before-send, premium file cards, and a full-screen `ImageViewerScreen`.
  New Message-info screen (backend fields only). **Optimistic send** — instant
  `SENDING` bubble, background POST, replace-on-success / `FAILED`+tap-to-retry.
  Instant re-open via in-memory `ChatThreadCache` + skeleton cold-load. All
  presentation/cubit; REST stays the only write path. New iOS dep needs
  `pod install`. Not yet device-verified.
- **Chat V1 UX polish (uncommitted).** Hero transition into the full-screen
  image viewer; **inline thumbnails for received images** (lazy brokered-URL
  fetch, fixed-footprint placeholder); date-separator pill (Today/Yesterday/
  date — already Today/Yesterday-aware); real **upload-progress ring** for
  attachments (dio `onSendProgress` threaded through repo→usecase→cubit, a new
  client-only `ChatMessage.uploadProgress`, throttled to whole-percent);
  `RepaintBoundary` per bubble so progress ticks / read receipts / the swipe
  translate don't re-rasterize the whole thread. No backend/contract change.
- **Chat ordering correctness fix (uncommitted).** `_replaceLocal` now drops the
  optimistic placeholder and re-inserts the confirmed message by its authoritative
  `seq` (`_insertBySeq`) instead of reusing the placeholder's slot — so rapid/
  concurrent sends, realtime interleavings, and retries always render in server
  order and self-heal. +3 ordering tests in `chat_realtime_sync_test.dart`.

### 2026-07-23

- **Chat: real profiles, premium composer/thread, and LAN dev networking
  (Phase 10).**
  - **Real conversation identities.** `GET /conversations` now returns each
    row's `counterpartExternalId` (the counterpart's Firebase uid), resolved
    server-side via a new read-only `USER_DIRECTORY` port (reverse of the
    identity resolver: internal UUID → provider subject, one batched query).
    The Flutter inbox loads the branch directory (`GetUsersByBranch`) and renders
    the teammate's real **avatar · name · role**; the thread header shows the
    counterpart's avatar + name. Backend internal UUIDs are never shown.
  - **Premium composer.** Rounded 46px pill, generous padding, multiline growth,
    a circular send button that reactively lights up when there's text (taps
    always route through the send guard so it's never a dead target).
  - **Premium thread.** Consecutive same-sender messages group (timestamp only
    on the run's tail, tight spacing, tail corner only there) and a warmer empty
    state.
  - **LAN dev networking.** Backend binds `0.0.0.0:3000`; a debug-only Android
    manifest enables cleartext HTTP; one
    `--dart-define=API_BASE_URL=http://<mac-lan-ip>:3000` points REST **and**
    Socket.IO at the same backend from both the iOS Simulator and a physical
    Android device (localhost never works from a real Android device). No
    production hardcoding — release keeps cleartext off.
  - **Real error surfaced.** `ApiClient` logs the underlying transport error
    (connection refused / host unreachable / status + body) before mapping it,
    and `ChatListCubit` logs the failure — ending the silent loading→error loop.
  - +2 widget tests (title resolution); backend suite still green.

### 2026-07-22

- **Chat: new-conversation entry flow (Phase 9).** Empty-state "Start Chat" CTA
  + an always-present inbox FAB open a `/chat/new` teammate picker
  (`NewChatScreen`/`NewChatView` + `NewChatCubit` over the existing
  `GetUsersByBranch`): own-branch teammates, search, current user excluded,
  each row avatar · name · role. Selecting a teammate calls `StartConversation`
  and `pushReplacement`s to the thread (Back → inbox); the server's idempotent
  get-or-create means picking someone you already chat with opens the existing
  thread, never a duplicate. **Backend (`drop-api`) contract change:**
  `POST /conversations` `targetUserId` is now the teammate's Firebase uid
  (external subject) — a client never holds another user's internal UUID — which
  the use case resolves to the internal participant via the existing identity
  resolver (get-or-create, so a teammate who's never opened chat is provisioned
  on demand); self-start stays a 400. `ChatListCubit.startChatWith` refreshes the
  inbox after starting so the row carries the server's real counterpart id.
  Verified live end-to-end; backend suite still 84 green. +6 widget tests.

- **Chat WebSocket "auth" failure root-caused — a DB migration gap, not a token
  bug.** The reported `socket auth rejected: Invalid or expired authentication
  token` was traced end-to-end: the Flutter client attaches the Firebase ID
  token correctly (`setAuth({token})` → handshake `auth.token`), the gateway
  reads it, and the verifier accepts a valid token (confirmed by minting a real
  token and calling `verifyIdToken` directly). The real cause was three unapplied
  chat migrations — critically `20260720130000_add_app_user` — so identity
  resolution threw *after* `verifyToken`, surfacing as a socket reject and REST
  500s on Chat. `prisma migrate deploy` fixed it; the socket then connects and
  authenticates cleanly. No client or gateway auth code changed.

- **Chat promoted to a primary navigation destination.** The mobile bottom
  nav's fourth tab changed from **Profile** to **Chat** (`chat_bubble` icon →
  `/chat` inbox, never a specific thread); Home/Tasks/Schedule are unchanged.
  Profile moved into the existing **Settings** hub (which already holds Profile ·
  Change Password · Sign Out), now reached by the app-bar avatar. Chat was also
  added to the desktop sidebar for every role (beside Cases). No Chat icon
  existed in the app bar, so none was removed; the app bar's Cases (forum) icon
  is a separate feature and stays. GoRouter/ShellRoute architecture and all deep
  links are unchanged. +3 nav widget tests.

- **Chat inbox realtime (Phase 8).** The conversation list now stays live off
  the *same* socket (no second service): the `ChatRealtime` port gains
  `attachInbox`/`detachInbox` — inbox-level interest that keeps
  `ChatSocketService`'s connection alive with **no room join**, since the
  server's auto-joined personal `user:{id}` room already delivers
  `message:new` for every conversation. `ChatListCubit` (optional additive
  `realtime` seam, attached on first load) applies live messages as: row
  bumped to the top with fresh `lastMessageAt`, a client-held last-message
  preview, and a client-counted unread badge (the backend pushes no counts;
  opening a conversation clears its badge via the new `clearUnread`, wired to
  tile tap). Events are deduped by per-conversation `seq`; a message for a
  conversation outside the loaded window triggers a full refresh rather than
  a client-invented row; a reconnect re-pulls page one (reconciliation —
  pagination resets by design, the documented refresh contract); a live
  delete-for-everyone tombstones the previewed line. The loaded state gains
  `previews` + `unreadCounts` maps feeding the tile's Phase-4 override slots.
  +8 tests.

- **Chat message deletion UI (Phase 7).** Long-press on a bubble opens a
  bottom-sheet context menu (`chat_message_actions.dart`, house sheet chrome)
  with Cases-style confirmation dialogs, driving the already-existing
  `DeleteChatMessageForMe` / `DeleteChatMessageForEveryone` use cases (now
  DI-registered and wired into `ChatConversationCubit`). *Delete for me* is
  always offered (sent, received, and tombstoned messages alike — per the
  backend contract); *Delete for everyone* is offered only on the caller's own
  non-deleted messages — an identity fact the bubbles already render, while
  the actual rules (original sender only, 1-hour window,
  `delete-for-everyone.policy.ts`) stay entirely server-enforced and a 403
  surfaces the server's own message as a snackbar. New loaded-state field
  `deletingMessageId` dims the in-flight bubble and serializes deletes.
  Delete-for-me removes the row; delete-for-everyone swaps in the server's
  tombstone; the live `message:deleted` / `message:deleted-for-me` socket
  events (parsed since Phase 6) are now applied — tombstone-in-place with the
  mirrored `"This message was deleted"` placeholder, and cross-session hide.
  +9 tests (7 widget + 2 realtime).

- **Chat realtime over Socket.IO (Phase 6).** Protocol taken verbatim from the
  `drop-api` gateway (`chat/realtime/interface/socket/`): namespace `/chat`,
  Firebase ID token in the handshake `auth.token`, `conversation:join`/`leave`
  acked `{ok, error?}`, server events `message:new` (REST-shaped message,
  sender excluded) / `message:read` / `message:deleted` /
  `message:deleted-for-me`, auth rejection via `connection:error` + server
  disconnect, rooms cleared on every disconnect. New `ChatRealtime` domain
  port + `ChatSocketService` (`socket_io_client ^3.1.6`; the only file allowed
  to import it): socket lives only while threads are joined, reconnection is
  self-owned (each attempt rebuilds the socket with a fresh token; exponential
  backoff capped at 30s; force-refresh after an auth reject), rooms re-joined
  on reconnect. `ChatConversationCubit` gains an optional `realtime` seam —
  live messages insert by `seq` (deduped), read receipts upgrade status to
  READ, and a reconnect triggers a newest-page REST reconcile. REST remains
  the only write path and the source of truth; without a socket the thread
  behaves exactly as before. +9 tests (cubit sync + wire-payload parsing).

- **Chat Conversation (thread) UI (Phase 5).** The `/chat/:conversationId`
  placeholder became the real thread: `ChatConversationScreen` builds a
  per-thread `ChatConversationCubit` (DI factory) around the shared
  `ChatConversationView` — `ChatMessageList` (bottom-anchored left/right
  bubbles, date separators, relative timestamps, tombstone + attachment-chip
  rendering, Cases' "New messages" jump pill, top scroll-back pagination with
  preserved scroll offset, post-frame visible→`markVisibleRead`) + a text-only
  `ChatComposer` (send spinner, clears only on success so a failed send never
  loses typed text, desktop autofocus + Enter-to-send). REST only — new
  messages arrive on open until the socket phase. +7 widget tests.

- **Chat Conversation List UI (Phase 4).** New `/chat` inbox over the existing
  `ChatListCubit`: `ChatScreen` (loading / branded empty / full-screen retry /
  loaded, pull-to-refresh, scroll-driven cursor pagination, transient errors as
  snackbars) + `ChatConversationTile` (avatar placeholder · counterpart label ·
  preview line · relative time · monochrome unread pill, with
  `title`/`preview`/`unreadCount` override slots for when the backend exposes
  them). Row tap pushes the new `/chat/:conversationId` route → a placeholder
  `ChatConversationScreen` (thread UI is the next phase). `ChatListCubit`
  provided app-wide beside `CaseListCubit`. +11 widget tests; also cleared 10
  chat-layer analyzer style infos (`dart fix`).

- **Networking foundation for the upcoming Chat feature (NestJS backend) —
  Phase 1.** New single HTTP seam `core/network/` (`ApiClient` on `dio` +
  `NetworkConfig` base URL via `--dart-define=API_BASE_URL`): Firebase stays the
  identity provider — every request carries the caller's Firebase ID token, with
  one force-refresh-and-replay on a 401 — and all HTTP failures map to the
  existing `ServerException`/`AuthException`/`ConflictException` vocabulary.
  Registered in `AppDependencies.init()`; **no feature consumes it yet** (cases
  and all other features stay on Firebase, UI untouched). +9 unit tests.

### 2026-07-19

- **Recurring shift tasks now end at their real shift deadline.** Every generated
  instance persists `instanceDate` + `startsAt` + `deadline` from the saved weekly
  schedule (per-day `shiftHours` override → frozen `shiftPlan` → standard hours;
  overnight windows included). The new `autoEndRecurringShiftTasks` Cloud Function
  runs every 15 minutes, queries the indexed due shift instances, and transactionally
  changes only still-open source-template tasks to terminal **Missed** — with
  `missedAt`, a system timeline entry, a version bump, and `task.auto_missed` audit
  evidence. It never converts unperformed work into completed/approved, and a
  simultaneous submit wins through transaction revalidation. A duplicate created by
  an older client is repaired only when its window is missing.
- **Missed is visible, truthful, and protected.** `TaskStatus.missed` is a closed,
  server-owned outcome: it leaves active queues and overdue metrics, shows as
  Missed in task surfaces/timelines, and cannot be forged, reopened, or deleted by a
  client. The Automation Center now says the missed policy is enabled. Retention
  archives missed records using the same window as approved work. Added the
  recurring-expiry composite index and pure Node coverage for resolved weekly
  shift windows / auto-end eligibility.

### 2026-07-18

- **Schedule default hours updated + "Today" highlight bug fixed + overnight
  weekend hardened.** `ShiftHours.standard` (the single source every surface and
  attendance derive from via `WeeklyScheduleEntity.hoursFor` + `ShiftWindow`) now
  reads: morning 08:30–16:30 all days; weekday night **15:00–23:00** (was
  16:30–23:00); operational-weekend (Thu/Fri/Sat) night **16:00–00:00** (was
  16:30–00:30), ending exactly at midnight (`endMinutes` 1440). `ShiftPlan.standard`
  and the shift-template seed already derive from this, so templates track the new
  defaults with no extra change; attendance (worked/late/early/overtime/missed +
  the early-clock-in window) picks them up automatically — no attendance code
  touched. **"Today" highlight bug:** the grid and My Week compared *weekday only*
  (`day == ScheduleDay.today()`), so every displayed week lit the matching weekday
  — a wrong day whenever you browsed another week. Both now use the new pure
  `ScheduleWeek.isToday(weekStart, day, {now})` (exact year/month/day match against
  the displayed week; no highlight on any other week). Styling unchanged. The grid's
  weekend "till HH:MM" header tag is now data-driven from the resolved night hours
  (shows for any night that crosses midnight) instead of a hardcoded "till 00:30".
  `ScheduleShift` display strings (`timeRange`/`timeRangeOn`/`startMinutes`/
  `endMinutesOn`) realigned to the new defaults.
- **Shift-swap timing contract synchronized to the new defaults (all four
  layers).** The swap "is this slot still in the future" / rest-gap contract
  previously hardcoded a night start of 16:30 in four synced places; all now read
  the day-aware default (weekday night **15:00**, weekend night **16:00**, end
  **00:00** = `1440`): client `SwapEligibility.slotStart` +
  `SwapValidation.shiftMinutes` derive from `ShiftHours.standard` (now day-aware);
  `firestore.rules` `swapShiftMinutes(s, d)` gained a `swapIsWeekendDay` split;
  `functions/index.js` `swapShiftMinutes(s, day)` mirrors it at both call sites
  (`approveSwap` future check + rest-gap). No legacy 16:30/00:30 shift-timing
  literals remain (the surviving 16:30 is the unchanged morning **end**). Schedule
  is now the single source of truth across Schedule, Attendance, Shift Swap, and
  backend validation. Tests updated; suite **957 pass / 2** known splash fails;
  Cloud Functions **28 pass**. **`firestore.rules` + `functions` still need the
  standing deploy** for the server side to take effect.

- **Schedule creation `permission-denied` diagnosed — deployment drift, not an
  admin-role bug.** Read-only verification of the active production Firestore
  ruleset found `weekly_schedules` deployed but no `shift_templates` match. Create
  Schedule reads the branch template set first, so Firestore default-denies that
  prerequisite for every role and never reaches the weekly-schedule write. The
  correct local rule already exists; no product code or production deployment was
  changed. Documentation self-check refreshed the live baseline to 1 analyzer info,
  954 passing / 2 known splash failures, and 28 passing Cloud Functions tests.

- **Automation execution snapshot + correlation id ([ADR-011](docs/decisions/ADR-011-automation-observability.md) extension).**
  Made every run historically accurate forever and traceable across resources —
  no generation-logic change, only enriched metadata. Each run now embeds an
  **immutable `snapshot`** (automation/template identity+version, schedule, branch
  id+name, lightweight recipients: `uid·displayName·role·assignedShift`) so a past
  run renders from the snapshot, never the live definition — old history is
  unaffected when templates/branches/employees/schedules/checklists change.
  Written on the `created` outcome only (once per run id → never overwritten); one
  branch read, no full user/branch docs copied. Added a **deterministic
  correlation id** `AUT-{yyyymmdd}-{hash}` stamped on the run, the generated
  `tasks/{id}`, its notifications, and its execution audit events — trace any one
  back to the whole execution; retry-safe (no counter). Client: `snapshot` +
  `correlationId` on the run model/entity, `correlationId` on `TaskEntity`, and
  `getAutomationRunByCorrelationId` (no new index — two equality filters). Pure
  `buildExecutionSnapshot` + `correlationId` helpers (+5 node tests → 28). +5
  Flutter tests. **Deploy pending** (functions).

- **Automation observability backend — Tier 1 ([ADR-011](docs/decisions/ADR-011-automation-observability.md)).**
  Made every automation execution fully observable without rewriting the engine.
  `generateShiftTaskInstances` now writes a rich **execution record** to
  `automationRuns/{templateId}_{dateKey}` (same one write/day, richer payload):
  identity/version, schedule + execution delay, `validations[]` (pass/fail/skipped),
  `target` (uids + **names** + explicit `matched`), generation/generated,
  notification, a structured `error` (stage · code · retryable · recovered), and an
  **embedded chronological `logs[]`** step timeline. Pure record logic extracted to
  `functions/automation_run.js` (+14 node tests). Added cumulative **health
  counters** on the template (run/success/failed/skipped/totalDuration/lastSuccess/
  lastFailure/configVersion), O(1) per run — success rate & avg duration are derived
  on read (`AutomationHealth`), never stored. New **`onRecurringTemplateWritten`**
  function derives lifecycle audit (created/paused/resumed/config_changed/deleted)
  into `audit_logs` server-side (ADR-005), idempotent & non-looping. Thin client
  read layer (`AutomationRunEntity`/`AutomationRunModel`/`TaskRepository.getAutomationRuns`,
  paginated) — foundation for a future Details screen, **no screen built**. Two
  `automationRuns` composite indexes. Retires the `automationRuns` no-reader debt.
  Tier 2 envelope (per-run I/O counters, replay, analytics surface) declined.
  +9 Flutter tests. **Deploy pending** (functions + rules + indexes).

- **Automation Task UI Phases 2–4 implemented (owner-approved).** Polished the
  Automation Center over the existing cubit/repository/design system — no new
  routes, packages, or backend. Added card-shaped **skeleton loading**
  (`Skeleton`), an icon-led **premium header**, a summary **"needs attention"**
  failure count, and slimmer tap-through cards. Extracted one **`_AutomationOutcome`**
  resolver so the status pill, card meta and details sections never drift. New
  per-routine **details sheet** (modal, not a route) with Overview / Schedule /
  Next execution / History / Failure information / Generated task / Actions,
  showing **real shift-window times** derived from `ShiftHours.standard` (replacing
  the "not available yet" placeholder). **Delete now confirms** via a dialog
  (card and details). Details toggle/delete reuse `TaskCubit`; the manage sheet
  loops back after details so a card reflects any change. Focused widget tests
  rewritten + one added for the failure-info path (7 pass).

- **Automation Task UI Phase 1 audit (product code read-only).** Verified the
  existing Center, Branch Operations entry, task preview path, Cubit/repository
  flow and focused coverage. The implementation plan is held at the owner gate;
  its production blockers are the unsafe generic create path (unawaited save plus
  silently discarded schedule/attachment input), the unconfirmed one-tap template
  delete, full-list loading resets, repeated template reads, and the missing read
  path for truthful run history/failure detail. Backend execution, routes, packages and frozen shift
  windows remain out of scope. The audit also recorded—but did not patch—a rules
  gap that lets managers read recurring templates outside their branch.
  Documentation self-check corrected the live
  baseline to 1 analyzer info and 939 passing / 2 known splash failures, and
  removed the stale claim that Attendance actions were still unreachable.

- **Automation Center UX refresh — visible, manager-first operations surface.**
  Replaced the basic recurring-template rows with responsive premium cards showing
  Active/Paused/Error state, human cadence, the advisory next automation check,
  shift-window availability, the truthful current Missed policy, generator outcome,
  failures and a tappable last generated task. Added active/paused/next summary
  metadata, a polished empty state and manager language (`Create Automation` /
  `New Automation`). Branch Operations now has a dedicated Automation summary card
  that opens the existing sheet and refreshes after changes; the old unlabeled
  repeat icon was removed. **No backend, route, DI, package or feature-module
  change.** Automatic Missed closure and frozen shift windows remain explicitly
  unavailable rather than being implied. Added phone-width interaction/overflow
  coverage and deterministic Today/Tomorrow formatting tests. Template read
  failures now surface as retryable errors instead of appearing as an empty
  branch. **Verified:** 936 pass / 2 pre-existing splash-centering failures;
  the Automation-focused analyzer is clean.

- **Attendance final UI wiring** — the five write actions that had a complete
  engine but no UI entry point are now reachable, completing the "every workflow
  from the UI" criterion. One reusable `AttendanceActionSheet`
  (`presentation/widgets/`) collects proposed times + a reason with loading and
  success/error feedback, delegating all validation to the existing cubits (which
  now return `Future<bool>` so the UI can confirm vs. stay open — a presentation
  signal, no business-logic change). **Employee** (clock screen): *Request a
  correction* on the shift summary, *Worked but forgot to clock in?* once the shift
  has ended → `requestCorrection` / `requestMissedPunch`. **Manager** (board-row
  detail sheet, now tappable for record-less rows): *Resolve shift* on a
  needs-review record, *Add record* + *Excuse absence* on an absent/late row →
  `resolveDirectly` / `addRecord` / `excuseAbsence`. Monochrome DROP design
  (`PremiumButton`, existing sheet shape); overnight clock-outs handled. +3 widget
  tests; 939 pass / 2 pre-existing splash; analyze clean. Only deploy + on-device
  GPS QA remain before the module closes.

- **Attendance R7 max-session auto-close + deployment/E2E verification** (final
  attendance phase). `autoCloseAttendance` now closes a session that lacks a
  scheduled end (an unscheduled clock-in) or runs past a **16h cap from clock-in**,
  not just scheduled-end + grace. The decision was extracted into the pure,
  firebase-free `functions/attendance_auto_close.js` (`isAutoCloseDue`) — the single
  source of the rule — and covered by 9 `node --test` cases (`functions/test/`; added
  a `test` script; no new dependency — Node 22's built-in runner). Idempotent (query
  is `status == inProgress`; a close flips it) and never overwrites a manual close or
  a soft-delete. Added `AttendanceConfig.maxSessionMinutes` (default 960) mirroring
  the server constant, per the existing `autoCloseGraceMinutes` pattern. **Verified:**
  all attendance Firestore indexes + rules + the three attendance Cloud Functions are
  present and correct for deploy. **Found (reported, not fixed — needs owner design
  sign-off):** the Phase 1–2 write actions (employee file-correction / missed-punch;
  manager Add-record / Resolve / Excuse) have complete engine + cubit + rules + CF +
  tests but **no UI entry point** — only clock-in/out, too-early, and approve/reject
  are reachable from a screen. Dart 929 pass / 2 pre-existing splash; CF 9/9; analyze
  clean.

- **Documentation self-check + automation-doc drift corrected.** Re-verified the
  live branch: 43 routes, 17 feature modules, 21 exported Cloud Functions,
  analyzer at the documented one pre-existing info, and 927 passing / 2
  pre-existing splash failures. Updated the stale `CURRENT_STATE.md` verification
  expectation from 897 to 927 passes, and corrected the Automation Engine doc:
  the current Center does not yet surface `lastStatus` / `lastGeneratedTaskId` or
  read `automationRuns`. No product code changed.

- **Attendance spec Phase 3 — compatible slice** (owner-chosen after a scope
  conflict was surfaced). The Phase 3 brief (History screen · Details · Timeline ·
  Summary · Filters · Metadata) was found to be **already built** (2026-07-17), and
  parts of it (extra metadata fields — timezone/appVersion/platform/syncStatus —,
  historical-snapshot blobs, and analytics/reports/payroll/CSV-PDF/score
  "foundation") **contradict** [ADR-009](docs/decisions/ADR-009-no-analytics-pipeline.md) +
  [ADR-010](docs/decisions/ADR-010-lean-over-enterprise.md) and the standing
  "metadata shows only recorded fields" ruling. Those were **declined** (no engine
  or data-model change — the record already snapshots the scheduled instants, so
  history is already independent of today's schedule). The genuine gap — the new
  **Excused** outcome not yet reflected in History — was wired in: an `excused`
  facet on `AttendanceStatusFilter` (+ matcher), an `excusedCount` on
  `AttendanceStats` (excluded from the attendance-rate denominator, like leave), an
  Excused summary stat (shown only when non-zero), and a record-card refinement
  (suppress the "Corrected" chip on an excused record since the badge already says
  it). +3 tests; 929 pass / 2 pre-existing splash; analyze clean.

- **Attendance spec Phase 2 implemented** (engine-level; **no new UI**, wiring
  awaits sign-off). (1) **Early clock-in window** — `AttendanceValidation.checkClockIn`
  now enforces `clockInLeadMinutes` (default aligned to the locked spec's **15 min**,
  was an unused 30): a rostered clock-in before `scheduledStart − lead` is refused
  with an "Opens at HH:MM" message; enforcement is centralized in the validation
  engine, wired through the employee cubit's `clockInCheck`. (2) **Worked-minute
  clamp** — `AttendanceCalculator` measures work from `max(clockIn, scheduledStart)`,
  so early arrival never inflates worked minutes or overtime (still one calc source;
  lateness continues to measure the real clock-in). (3) **Lazy Absent** — confirmed:
  no attendance document is created for a no-show (the board derives `absent`
  virtually); materialization happens only via manager Add record / Excuse or an
  employee missed-punch. (4) **Excused** — new terminal `AttendanceStatus.excused`
  (zero worked minutes, mandatory reason) via `AttendanceAdminCubit.excuseAbsence` +
  `AttendanceValidation.checkExcuse`, applied through the existing approved-correction
  path (no CF change); surfaced on the board (`AttendanceBoardStatus.excused`) and
  the status badge. +~20 tests; 927 pass / 2 pre-existing splash; analyze clean.

- **Attendance spec Phase 1 implemented** (critical items — engine + cubit API +
  rules + CF + tests; **no new UI**, wiring awaits design sign-off). (1) **Missed-
  punch recovery**: `checkCorrection` now allows a null record (asserting a start
  time) instead of `recordMissing`; employees file via new
  `AttendanceCubit.requestMissedPunch`; the correction carries a `scheduledStart`/
  `scheduledEnd` window. (2) **Manager direct action**: `AttendanceAdminCubit.addRecord`
  / `resolveDirectly` write an already-`approved` correction (new
  `AttendanceRepository.createResolvedCorrection` + model `toResolvedCreateMap`);
  the resolution is computed through the new single-source `AttendanceResolution.fromRecord`.
  (3) **One server apply path**: `onAttendanceCorrectionWritten` now **upserts** —
  a missing record is materialized (dayKey lifted from the deterministic id) and a
  create-with-`approved` correction applies immediately (skips reviewer notify);
  guarded against concurrent soft-delete. (4) **Validation**: one open correction
  per record (`duplicateOpen`) + a manager `checkManagerEntry` gate (mandatory
  reason, start time, no self-approval). `firestore.rules` gains a reviewer
  approved-create branch. +17 tests (validation, resolution, decide, employee +
  admin cubits); 914 pass / 2 pre-existing splash. **Needs the standing functions +
  rules deploy** to activate server-side.

- **Attendance product spec locked** — [docs/design/ATTENDANCE_SPEC.md](docs/design/ATTENDANCE_SPEC.md).
  Following a full workflow audit, the Attendance module's product behavior was
  frozen: final state machine (adds **Excused**; Absent stays virtual, materialized
  lazily), 20 business rules (early-clock-in window + clamp, missed-punch recovery,
  managers act directly while employees request, one open correction per record,
  auto-close every open session, exception-driven notifications), edge-case rulings,
  and a decision log. Product decisions / technical constraints / future
  enhancements are kept separate. Docs-only; no code changed. The shipped engine
  does not yet implement every locked rule — `clockInLeadMinutes` enforcement,
  missed-punch/manual creation, direct manager resolve, and the Excused outcome are
  the known deltas. [ATTENDANCE.md](docs/design/ATTENDANCE.md) now points to the spec
  as the behavior source of truth.

### 2026-07-17

- **Attendance History ledger + record Details.** The longitudinal history the
  clock screen only hinted at (a 30-row bottom sheet). A summary strip
  (present/late/absent/rate/avg-arrival/worked), a composable filter bar (date
  range · status · shift · reviewer employee search) and a lazy list of per-day
  record cards → an audit-log Details screen (scheduled window · clock in/out +
  GPS · durations · **Timeline** from the server `events` with a record-derived
  fallback · corrections · an expandable **Metadata** block of recorded fields
  only). Two entries share one screen: `/attendance/history` (self, any role) and
  `/attendance/review` (branch ledger, **admin‖manager** via a new
  `_isAttendanceReviewArea` guard — managers' first attendance-oversight surface);
  a record opens `/attendance/record/:id`. **Presentation-only** — reuses the
  existing repository reads (`watchUserHistory`/`watchBranchRange`/`watchEvents`/
  `watchRecordCorrections`) + the pure `AttendanceStats` and a new pure
  `AttendanceHistoryQuery`; no parallel data stack. Summary reflects the date
  window, facets narrow only the list. Entry points: the employee "View history"
  button (→ self); the admin board's new "History" action + "View full record"
  sheet button; and — since managers had no attendance surface at all — a new
  manager sidebar entry (+⌘K) and home-screen tile (→ branch review). **Held
  ADR-009 + ADR-010**: performance score, analytics/heatmaps,
  CSV/PDF export and payroll were declined (the ledger is shaped to feed them
  later), and Metadata shows only recorded fields — no invented
  timezone/appVersion/syncStatus. +22 tests (query · status filter · cubit ·
  widget render). The list uses a plain `ListView` (the pattern every other DROP
  list screen uses).

### 2026-07-16

- **Admin dashboard → calm, state-aware command center** (owner-directed
  refinement of Admin Dashboard V2). The hero eyebrow now carries data freshness
  ("date · Synced 3m ago") and the subtitle is **one** live state sentence off a
  single needs-attention total — calm "All caught up" (grey pulse) vs
  "N tasks need your attention" (amber pulse), so hero and grid never disagree
  (`dashboard_mood.dart` collapsed from a 3-tone model to two states). **Needs
  attention** is now **one grouped box** (owner-approved from a live A/B/C
  preview): a calm "all clear" summary when every queue is empty, otherwise
  triage **rows** most-urgent-first inside a single living border — a fresh signal
  slides in as a row (`LiveListItem`) instead of the whole grid re-appearing, and
  cleared signals collapse to a quiet footer. **Today** counts up its figures
  (`Stat.count`, ~650ms), Delayed
  reads warning (was error) and Approval rate reads success. Desktop centres in a
  ~1260 column with a 360px right rail; **Manage** trims to Tasks / Schedules; the
  **staffing banner** and **branch pulse** were dropped (owner ruling). Strictly
  monochrome, dark-only, existing primitives only (ADR-004).
- **Task create speed-up.** Added and refined Schedule quick deadline presets
  (`Tomorrow`, `2 days`, `Week`) that start at creation time and set the due
  window without opening the date/time pickers; the presets now use a compact
  duration rail with an animated thumb and animated duration line.
- **Create Task sheet visual polish.** Kept DROP's strict monochrome direction,
  then added neutral tonal depth, a composed animated header, softer picker hover
  lift, richer segmented controls, and a staggered final CTA. All new motion
  collapses under reduced-motion settings; task save/data flow is unchanged.

### 2026-07-15

- **Documentation restructured.** The doc set had reached 16,669 lines across 23
  files and was contradicting itself (it claimed indigo `#5B5FEF` was the accent
  months after deletion, and gave three different test counts in one file). Rebuilt
  around single responsibility: PROJECT_CONTEXT (architecture) · CURRENT_STATE
  (today) · CHANGELOG (history) · `docs/design/` (per-feature) · `docs/decisions/`
  (ADRs). ~90% smaller on the read-before-every-task path.
- **Removed: Schedule Health** — the `domain/health/` analyzer, its 5 rules, the
  facade, the below-grid overview surface, and 4 test files (−2,769 lines). The
  insight strip above the grid is now the only staffing signal. Per-employee stats
  keep *days worked*, drop the morning/night split.
  → [ADR-007](docs/decisions/ADR-007-schedule-health-removed.md)
- **Attendance Phase 3 (engine + UI): GPS-verified clock in/out.** `geolocator` +
  pure `attendance_gps.dart` (Haversine + `AttendanceVerification`), `BranchGeofence`
  per branch, separate clock-in/clock-out verifications, server-timestamped times,
  `checkGpsFix` gate. Employee clock screen (`/attendance`), admin schedule ×
  attendance board (`/admin/attendance`), geofence editor. Clock-out records
  verification but is never GPS-blocked.
- **Removed: attendance breaks** — descoped for MVP; `AttendanceBreak` and the
  calculator's netting kept as dormant extension points.
- **Removed: Community Hub / DROP Events** — the feature, 4 tests, 3 enums, all
  routes/nav/DI wiring, and its Firestore + Storage rules. Live data untouched.

### 2026-07-14

- **Attendance Phase 2: corrections + server-authoritative audit.** The audit trail
  (`attendance/{id}/events`) is now derived and written **only** by the Admin SDK —
  clients cannot forge it. `attendance_corrections/` is a first-class
  Pending → Approved/Rejected approval object reusing `RequestStatus`, with
  self-approval forbidden server-side. Functions `onAttendanceWritten`,
  `onAttendanceCorrectionWritten`, `autoCloseAttendance`.
  → [ADR-005](docs/decisions/ADR-005-server-authoritative-writes.md)

### 2026-07-13

- **Automated Task Engine hardening.** Fixed a duplicate-task bug on
  reopen → re-approve via deterministic `rec_{sourceTaskId}` ids
  (`createTaskWithId`). `generateShiftTaskInstances` made atomic, notifying, and
  roster-filtered. ⚠️ The Automation Center it exposes sits behind one unlabeled
  icon and has never been seen by the owner. **Resolved by the 2026-07-18 UX
  refresh.**

### 2026-07-11

- **Task lifecycle hardening.** New `TaskRepository.transitionTask` — a transaction
  that verifies the expected predecessor status, appends the `ActivityEntry` to the
  **server's** log, and bumps an additive `TaskEntity.version`. Fixes the
  concurrent-reviewer race. Rules freeze review fields and require a non-decreasing
  `activityLog`. Declined as over-engineering: `schemaVersion`, `deviceInfo`.
- **Media upload V2.** New `core/media/` seam — `MediaUploadService` is the single
  Storage upload for task/case/request, plus `media_processing.dart` (crop/compress,
  mobile-gated), `mapPooled` (concurrency cap 3), `UploadCanceller`, partial-retry
  cache, and upload analytics.

### 2026-07-10

- **Notifications V2.** New pure resolver `notification_deep_link.dart` —
  `resolveNotificationRoute` is the single seam for both the tile tap and the FCM
  tap (`null` = safe no-op → inbox). Fixed 5 routing bugs. Broadcast deep-links now
  self-resolve when opened cold. ⚠️ iOS push still unconfigured.

### 2026-07-08

- **Requests: settled as approvals, not tickets.** Statuses reduced to
  Pending → Approved/Rejected; create made employee-only (so self-approval is
  structurally impossible — no guard needed); admin gets soft delete + reopen.
  Fixed an infinite-height freeze in the empty state.
  → [ADR-008](docs/decisions/ADR-008-requests-are-approvals.md)
- **Design System V2** — `PageHero` · `AttentionTile` · `StatStrip` · `ActivityCard`;
  the 4-step grey ramp; Admin Dashboard V2 closed and owner-signed-off.
- **Task Scheduling V2** — additive `startsAt`/`dueAt`, derived `TaskSchedulePhase`
  (not a persisted status), roster-aware smart shift defaults, never locked.
- **Work Details design system** — one language, composed per work type.
- Community Hub / DROP Events shipped (removed a week later, 2026-07-15).

### 2026-07-07

- **Work-type framework** — polymorphic tasks via Strategy + Registry: adding a type
  is 1 file + 1 line. Unknown types degrade to `general`. `workType` + `data` are
  additive, no migration.
- **Configurable shift hours** — shift end times became *data, not code*
  (`ShiftHours`, `end > 1440` = overnight), with per-week overrides.
  → [ADR-006](docs/decisions/ADR-006-schedule-shift-plan-snapshots.md)
- **Employee My Week frozen by owner ruling** — premium UI kept; in-language
  improvements only.
- Multi-line day notes + premium employee shift sheet. Fixed a desktop sidebar idle
  freeze and a My Schedule shift-window API mismatch.

### 2026-07-06

- Task Details activity timeline rework — hero current-status head + ledger rows.
- Schedule 5.0 — day-level leave + notes, Final View.
- `LiveStatusBorder` per-state colour palette. **Motion is load-bearing — do not
  change it.**

### 2026-07-05

- Schedule Final View + real PNG export. One-time employee Welcome screen. Branch
  Operations premium KPI drill-downs. Communications feed bulk selection. Mobile
  splash premium pass. Fixed a recurring shift-task save freeze.

### 2026-07-04

- **Case Management System** — Reports reframed as private employee ↔ manager/admin
  conversations, with a rule-enforced confidential reporter split
  (`cases/{id}/reporter/identity`) and a realtime `messages` subcollection.
- Premium animated cold-start intro. Admin Task Management Active/Done pages. Admin
  dashboard risk-first review + Sync control.

### 2026-07-03

- Home Dashboard redesign (P1–P3 + R1) — global task feed, Attention strip, Smart
  Queue, task retention lifecycle. *Superseded on Admin Home by Design System V2
  five days later.*
- Compensation moved to the private subdoc `users/{uid}/private/compensation`.
- M1/M2/M3 hardening + C1 deployments.

### 2026-07-02

- **Phase 2 premium desktop UX** — Schedule 3.0 grid, executive dashboard, person
  inspector, ⌘K command palette.
- **Phase 3 observability** — `CrashReporter` (4 funnels → a report persisted across
  launches, even in release) + `CrashContext` + `AppLog`.
- **Fixed: total macOS navigation freeze** — the `ShellRoute` child was wrapped in an
  `AnimatedSwitcher`, duplicating go_router's shell Navigator `GlobalKey`. Never do
  this; the desktop fade lives at the page level instead.
- Schedule 4.0 (overflow · mobile actions · undo · validation) and 3.1
  (drag-to-switch). macOS app icon. DROP logo rollout. Production audit + beta plan
  + auto-schedule design exploration.

### 2026-07-01

- **Shift Assignment** — a task can target a *shift* rather than named people,
  visible only to whoever is rostered on it that day (`canUserAccessTask`).
  Recurring shift routines use a template → generated-instance split.
- **Monochrome revert** — the desktop-first redesign's indigo accent was reverted.
  → [ADR-004](docs/decisions/ADR-004-monochrome-design.md)
- Desktop punch-list: 10 screens onto `AdaptiveScaffold`. macOS keychain login fix
  (`DebugProfile.entitlements` `keychain-access-groups`), photo-upload sandbox
  entitlement, window sizing, responsive card grids.

---

## June 2026 — foundation

Summarized. Detail is in git.

### 2026-06-30
- ✓ Full rebrand: Dart package `fbro` → `drop` (repo folder + iOS bundle id still `fbro`).
- ✓ Desktop-first UI — `ShellRoute` + persistent role-aware sidebar. *(Its indigo accent was reverted the next day.)*
- ✓ Premium macOS desktop foundation + polish (schedule grid, task ticket, comms command-center).
- ✓ Fixed macOS login "No internet connection" (sandbox networking).

### 2026-06-28
- ✓ Branch cover photo on the admin task overview.
- ✓ Input validation on user-detail fields.
- ✓ Fixed account-switch push failure on a shared device.

### 2026-06-27
- ✓ Branch identity in tasks — cover banner + logo chip.
- ✓ Permanent delete for a sent broadcast (not the old soft-delete).
- ✓ Per-token FCM dispatch diagnostics. Fixed a stuck iOS keyboard in the template sheet.

### 2026-06-26
- ✓ **Auth & account provisioning redesign** — admin-only accounts; registration, OTP, Google, email verification, and the approval flow all removed. `isActive` became the sole access gate.
- ✓ **FCM token ownership** made exclusive, enforced server-side by `claimFcmToken` — fixes cross-user leak on a shared device.
- ✓ **Shift Swap hardening** — server-authoritative atomic exchange via the `approveSwap` callable; rules deny any client write setting `managerApproved`.
- ✓ Admin-editable user contact details. Token-leak audit. Activity timeline V2.

### 2026-06-25
- ✓ **Premium UX/Logic Refactor** (slices 1–2b, §5, §8–§9b) — correctness fixes, the premium component system (`AppGlassCard`, `MetricPill`, `PremiumButton`), branch media + `BranchAvatar`, brand primitives (`DropWordmark`, `DropEmptyState`, `DropLoadingState`), and the notification **operational inbox**.
- ✓ Shift Swap System — exchange model + swap notifications.
- ✓ **De-flash: premium ≠ flashy** — owner ruling; monochrome + subtle status glows only.
- ✓ Realtime polish — animated counters, smooth Pending Review list. Release stabilization + FCM routing audit.

### 2026-06-24
- ✓ **Performance Phases A–D** — reload/refetch guards, repository-level branch + template caches, warm-start preload, rebuild scoping. Plus regression fixes (offline admin stats, task stream scope).
- ✓ Simplification slices 3b–4b — dropped broadcast soft-delete, collapsed comms nav, merged categories 4→3, and **removed the Priority + Delivery-channel selectors** (delivery is derived from category).
- ✓ Schedule grid premium redesign — faces + names per shift.

### 2026-06-23
- ✓ **Killed the analytics pipeline** — open/read rate, monthly rollups, and charts deleted as vanity. Kept minimal delivery diagnostics. → [ADR-009](docs/decisions/ADR-009-no-analytics-pipeline.md)
- ✓ Lean Notification Center; task notifications open the exact task. `NotificationType` trimmed to the 11 values with a live producer.

### 2026-06-22
- ✓ **Communications Center Phase 2, Commits 1–6** — schema foundation + Broadcast History, templates + placeholder engine + premium composer, advanced recipient targeting, scheduled/recurring broadcasts, the task reminder engine, and analytics aggregation. *(Commit 6's analytics was deleted the next day.)*

### 2026-06-21
- ✓ **Communications Center Phases 1–3** — broadcast vertical slice, the `sendBroadcast` Cloud Function send engine, and the role-gated Center UI. End-to-end.
- ✓ **Branch Operations cockpit** — shift tag + workload aggregation, cubit, screens.
- ✓ Task submission media: loading UX + progress, the Submission Details review sheet, real video thumbnails. Assign employees while creating a task.

### 2026-06-20
- ✓ Task submission media upgrade — multiple images & videos per submission, attached to task events.
- ✓ Schedule assignment-grid redesign — **no staffing quotas**; assigned head-count only.
- ✓ Shift-swap hardening + Admin Pending Actions. Premium UI redesign (Branch Schedule, Admin Home, Task timeline).

### 2026-06-19
- ✓ Admin command-center redesign + reusable component library.
- ✓ Employee schedule premium redesign.
- ✓ Task proof upload + admin task experience.

### 2026-06-18
- ✓ **Task Workflow Architecture: single-write state machine** — status + activity in one write. Never split them again.
- ✓ **Operations Workflow Upgrade** — `RecurrenceConfig`, `ActivityEntry`, Task Details screen, My Tasks redesign.
- ✓ Employee Home Screen redesign v2. Inline checklist editor; task form simplified. App icon & name. Proof submission error visibility.
- ✓ Task UX overhaul — monochrome cards, "Assigned by", username removed as a legacy social field.

### 2026-06-17
- ✓ DROP THE SHOP UI redesign + Tasks crash fix.
- ✓ Shared component system — `StatusBadge`, `AppCard`, context helpers, form & layout primitives.
- ✓ Architecture de-duplication & shared utilities. Stability & UX audit.

### 2026-06-16
- ✓ **Phase 7 — Weekly Schedule & Shift Swap** (the production roster).
- ✓ **Phase 8** — QA, hardening & UI polish. **Phase 9** — task UX, admin UX & design overhaul (checklists, multi-assignee).
- ✓ **Phase 10** — production hardening; deleted the dead Phase 2 `shift` feature.
- ✓ Stabilization & workflow integration — fixed a broken build (`pubspec.yaml` name), the admin branch dropdown, realtime task streams, task templates.

### 2026-06-15
- ✓ **Phase 2** — Shift Management foundation *(later deleted as dead code)*.
- ✓ **Phase 3** — Task Management foundation. **Phase 4** — Task Workflow & Review System.
- ✓ **Phase 5** — Admin Management module. **Phase 6** — Operations Dashboards & Notifications.
- ✓ Rebrand to DROP.

### 2026-06-14
- ✓ **Phase 1 — Roles & Foundation**: `UserRole`, role-based routing + guards, role shells, security rules.
- ✓ Design system: **monochrome B&W/grey — indigo reverted**. → [ADR-004](docs/decisions/ADR-004-monochrome-design.md)
- ✓ Account approval flow *(removed 2026-06-26)*. Production profile system.

### 2026-06-13
- ✓ Authentication feature set — sign-in, forgot password, change password, profile module, settings.
- ✓ Project bootstrapped: Flutter + Firebase, Clean Architecture, Cubits.
  → [ADR-001](docs/decisions/ADR-001-firebase-backend.md) · [ADR-002](docs/decisions/ADR-002-cubit-only.md) · [ADR-003](docs/decisions/ADR-003-clean-architecture.md)
