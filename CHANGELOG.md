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

## 2026-08-03 — Manager Home rebuilt as a branch command center (feature + polish + bug; MED risk)

Owner review of the manager role on device: *"it looks trash and not premium…
the UI didn't give the answer of their questions."* Two concrete faults sat
behind that, and both were structural rather than cosmetic:

- **Nothing was ranked.** Home drew ten equal-weight `StatGrid` cards —
  `Employees 8` had the same visual authority as `Waiting reviews 0` — then an
  embedded `TaskFeedSection` (its own search · filter chips · sort · grouped
  list) below them. The screen answered *how many rows exist*, never *what
  needs you first*.
- **The numbers disagreed on screen.** A `Active tasks 4` hero card sat above a
  feed strip reading `Late 1 · Pending review 0 · Unassigned 0`, from a
  different source.

**Manager Home is now the same ranked ladder the Admin command center was
signed off on**, scoped to one branch: hero (greeting · one live state sentence
· *branch name* · employees · running · one **New Task** CTA) → **Needs
attention** (one grouped `AttentionPanel`: late · pending review · sent back ·
unassigned · swaps, most-urgent-first, cleared ones collapsed to a footer, each
a branch-pinned drill) → **Today** → **On shift today** → **Recent activity**
→ **Operations** · **Quick actions** · Recent messages. Desktop puts the
operational story in a flexible main column beside a fixed 360px launch rail.

Every count now derives from the one live `TaskCubit` stream via
`task_metrics.dart`, so a figure and the list its tap opens cannot drift apart;
`StatisticsCubit` is left only for roster context, which no drill-down lists.
The hero sentence and the attention panel read the **same** total through
`dashboardMood(...)`. `Late` is drawn exactly once. The task browser was not
deleted — it lives where it belongs, Branch Operations and its All-tasks list,
reachable from *Recent activity → See all* and the Branch tasks quick action.

**The V2 command-center chrome is now shared, not admin-private.** It had been
~600 lines of private classes inside `admin_dashboard_screen.dart`; with a
second caller it moved to `core/widgets/`: `PrimaryCta` · `SyncButton` (+ pure
`syncLabel`) · `HeroMood` · `AttentionPanel`/`AttentionSignal` · `DigestPanel`/
`DigestEntry` · `CommandHint`, plus `live_status_border.dart` (already used by
three features) and `dashboard_mood.dart` → `core/utils/`. Admin Home renders
identically — it now composes the primitives instead of owning them. Two
behaviour improvements fell out of the extraction: the all-clear panel's
"0 late · 0 pending review · …" proof line is **derived from the signals** the
board actually watches instead of hardcoded, and a `DigestEntry` may omit its
value so a door with no honest figure renders label + chevron rather than a
placeholder dash.

Fixed alongside, all found on device:

- **Branch Operations: the FAB covered a real control (bug).** The extended
  `New Task` FAB parked on top of the shift toggle, so the **Night** lens was
  unreachable on a phone. New Task is now the screen's single `PrimaryCta` in a
  labelled action row under the branch hero, beside **All tasks** (promoted out
  of an unlabelled app-bar glyph — which also gave the branch name room). No
  FAB, no collision.
- **Attendance: `Working anyway? Start an unscheduled shift` overflowed by
  7.6px (bug).** A min-sized `Row` with an unbounded `Text`; the label is now
  `Flexible` inside a padded, min-height button and wraps.
- **Workload cards: four zeros per idle employee (polish).** A caught-up branch
  rendered one bordered box of `0 0 0 0` per person — a component that reads as
  failed, repeated down the page. The strip and its spacing are now gated on
  `EmployeeWorkload.hasFigures`; idle people collapse to a slim identity row so
  the ones carrying work stand out by height alone. A zero cell also steps down
  the grey ramp.
- **`RoleScaffold`: the role word truncated to "Mana…" (polish).** It was the
  first thing the manager's crowded action cluster ate, and it is redundant now
  that every home opens with a hero that greets by name and names its scope.
  The mobile app bar leads with the DROP mark alone; `title` survives as the
  bar's accessible label and the desktop page-header title.

New `test/manager_home_test.dart` (7 tests) pins the ladder on **both** tiers,
the hero↔panel agreement, the all-clear state, `Late` appearing once, the
branch-pinned drill, and `loadBranch` (not `loadAll`) for swaps.

`macos/Podfile.lock` picked up `connectivity_plus` — a genuine lockfile
catch-up from the first macOS build since the offline-gating work landed.

**Two ATLAS tooling bugs found and fixed while syncing the cards** (`.nav/gen_atlas.py`):

- **`ROOT` was a hardcoded absolute path.** The repo is worked in through git
  worktrees under `.claude/worktrees/`, so *any* run from a worktree silently
  regenerated the **main** checkout's cards from the **main** checkout's code —
  dirtying a tree nobody was editing while leaving the worktree's own cards
  stale. It now resolves from the script's own location.
- **It erased the hand-authored half of every card on every run**, despite each
  card's own header promising *"Hand-authored intelligence lives BELOW the
  marker. Do not delete that section."* It emitted the `_TODO:` placeholders
  unconditionally. That is why every card's judgment section was a field of
  TODOs — the protocol's own "read the card first" step had nothing to read.
  Regeneration now keeps anything below the marker that isn't still the seed.

`.nav/features/manager.md` is the first card with real hand-authored
intelligence: purpose, the invariants above, extension points, and its
relationship to `features/admin` and `features/operations`.

### Second pass — clickability, density, and the task info page

Owner review of the rebuilt Home: *"why everything in 1 page in manager UI
mobile? quick actions and operations … make the On shift today and Today's
tasks way more clear and clickable … is that really nice to see too much text?
this application is for a high-end company so care for every small detail."*

**Everything on Home is now a door.**

- **Today** was a `StatStrip`: number-and-label text on one flat surface, with
  nothing saying it could be opened — and one cell, `Due soon`, that genuinely
  couldn't be (no `TaskFeedFilter` reproduces `schedulePhase`'s precedence). It
  is four `MetricTile`s, 2×2 on a phone and one row on desktop, each with an
  `arrow_outward` affordance. The deadline cell is now **`Due today`**, counted
  by the very `applyFeed(…, FeedPreset.dueToday, …)` call its drill-down
  renders — the figure and the list are one computation, not two kept in step.
- **On shift today** was four cells (`Team · On today · Morning · Night`) —
  eight strings for one fact, and **none of them clickable**, on the half of a
  manager's job that is entirely roster. It is one card: the count on shift,
  the team as its denominator, the morning/night split as two hairline pills,
  and a chevron into the weekly schedule.
- `MetricTile` + `MetricTileRow` are new `core/widgets/` primitives, extracted
  from Branch Operations' private `_StatTile` — that header now composes them,
  so the two surfaces cannot drift into two dialects of one metric cell.

**Less text.** The hero was four stacked lines before any control (eyebrow with
`· Synced just now`, a two-line greeting, the mood sentence, and a scope line).
The branch moved into the eyebrow, the scope line is gone (the Sync control
already carries freshness; `8 employees · 0 running` is what the Today row is
for), and `HeroMood` now omits its scope line entirely when passed an empty
string. Section headers lost their subtitles.

**Fewer sections.** **Quick actions is deleted on both tiers** — Branch tasks
and Weekly schedule are bottom-nav destinations (sidebar + ⌘K on desktop) and
Broadcast is the app-bar megaphone, so it was three cards of duplicated
navigation at the foot of a long page. **Recent messages is desktop-only**:
Chat is the fourth bottom-nav tab, and five conversation previews under an
operations board was the page trying to be every screen at once. The
attention panel's cleared footer wraps to two lines instead of truncating
mid-word.

**Task details — the info page (feature + polish; MED risk).** Owner: *"the
header or the description of the task not clear, and assignment — from who? all
of this needs to be way more easy to read."* Three faults, all structural:

- **The task title was not on the page.** It lived only in the app bar, at
  app-bar size, above a full-bleed branch cover. The body opened on a status
  pill and seven metadata chips — you could not read what the work *was*. The
  title is now the header's headline (`h2`, wraps, never ellipsized).
- **The description was a separate section further down**, separated from its
  own title by the whole assignment block. It now sits directly under the
  title, and the standalone section is gone.
- **The meta row printed everything it had** — up to eleven equal-weight chips,
  including the branch (already named by the banner directly above it), the raw
  `type` string ("special"), a `Normal` priority that is the default on every
  task, an `Active` phase that only restates that an unfinished task is
  unfinished, and a `Starts` date already in the past. Each of those is now
  conditional; in the owner's own screenshot the row drops from **seven chips to
  two**.
- **Assignment answered only half its own question.** A name and role, a
  hairline divider, then an orphan grey caption `Assigned by  Admin` — two
  facts stacked with nothing tying them together. It is one lockup now:
  the assignee, then an indented handover line (`↳ Assigned by **Admin**`) with
  the giver's name reading white. The section is renamed **Assignment**, since
  "Assigned to" named only one side of it.

The activity timeline — the part the owner said works — is untouched.

Gates: analyze clean (1 pre-existing test-style info) · Dart **1482 pass / 0
fail**; `manager_home_test.dart` grew to 10 (every Today tile is a door · the
coverage card is one tap target · the hero carries one supporting line), and
`task_start_gate_widget_test.dart` now expects the task title **twice** on
Task Details (app bar + body headline). Re-verified on the iPhone 17 simulator.

Gates: analyze clean (1 pre-existing test-style info) · Dart **1479 pass / 0
fail**. Verified on the iPhone 17 simulator; the desktop tier is covered by the
widget test rather than a screenshot.

---

## 2026-08-03 — Merge conflict repair on PR #25 (bug; LOW risk)

Merging `claude/ui-fix-608998` into `release/v1-preparation` (PR #25, `6584808`)
had five conflicting files. Three resolved correctly; two silently dropped one
side's content, and neither loss produced an error — the tree compiled and the
suite stayed green, so only a side-by-side diff against both parents found them.

- **`broadcast_templates_screen.dart` (bug).** The resolution took the release
  side's rewrite of the file wholesale but kept the feature side's *import* of
  `app_error_state.dart` — so the error branch fell back to `AppEmptyState`
  while carrying an unused import. This was one of the **six surfaces** the
  entry below claims got `AppErrorState` + Retry; the code no longer matched
  that claim. Restored to `AppErrorState` with
  `onRetry: () => context.read<BroadcastTemplateCubit>().load()`.
- **`firestore-tests/README.md` (doc).** Both sides appended a bullet to the
  coverage list; the resolution kept only the feature side's **Notifications**
  bullet and dropped the release side's **Attendance corrections** one. Restored.
- **Verified intact:** `functions/index.js` (both sides carried the same
  `isReminderEligibleStatus` extraction, so taking one was lossless),
  `CHANGELOG.md`, and `CURRENT_STATE.md` — whose dropped *"Failing tests (2)"*
  section is a correct removal, not a loss, since the splash failures were
  fixed the same day.

Gates, all re-run on the merged tree: analyze 1 pre-existing info · Dart **1472
pass / 0 fail** · functions **83** · rules **61**.

> **Also corrected: every test count in `CURRENT_STATE.md` was stale**, and the
> file disagreed with *itself* — the At-a-glance table claimed 72 functions / 53
> rules while the verification block below it claimed 68 / 37, the exact
> "three different test counts in one file" failure the doc rules were written
> to prevent. Real figures are above; route-name count corrected 51 → **53**.

---

## 2026-08-03 — Bundled typeface + premium empty / error / loading states (polish + bug; LOW risk)

Branch `claude/ui-fix-608998`, **merged into `release/v1-preparation`** via PR
#25 (`6584808`). Presentation only — no cubit, repository, rules or payload
change.

- **Typeface is now bundled (bug).** Every style pointed at the string
  `'SF Pro Display'` while `pubspec.yaml` shipped **no font at all**, so the name
  resolved to the system face on Apple platforms and fell back to **Roboto on
  Android** — the app rendered in two different typefaces depending on platform.
  **Inter** (400/500/600/700) now ships in `assets/fonts/`, `AppTypography`
  exposes one public `fontFamily` constant, and both `ThemeData`s carry it so
  unstyled text inherits it too. The five widgets that hardcoded the family
  string now reference the constant. ⚠️ **Inter is an unconfirmed stand-in** for
  the face in the owner's redesign mockup — the swap is one constant if wrong.
- **Empty bar on a first-run Home (bug).** Every cell of the employee Home stat
  strip is gated on a non-zero count, and its "Nothing to do" phrase needs
  `total > 0` — so an employee with no tasks (or whose only open item is a
  *rejected* task, which has no chip) got a bordered container with nothing in
  it, reading as a component that failed to load. `_StatStrip.hasContent` now
  gates the strip **and its spacing**, and shares the cell-building helpers with
  `build` so the gate cannot drift from what is drawn.
- **Rework has a figure of its own (polish).** Rejected work counted toward
  `open` but had no chip, which is *why* the rejected-only case produced a blank
  strip — and meant the strip stayed silent while work sat below waiting to be
  redone. A **Rework** chip now leads the strip (ahead of To do / Active), using
  the same `replay_rounded` glyph as the "Needs attention" section it refers to.
  Verified at the five-column worst case: no ellipsis at 402pt.
- **New `test/employee_home_stat_strip_test.dart`** (3 cases) pins all of it —
  strip absent on a first run, present-with-Rework on a rejected-only day, and
  collapsing to "Nothing to do" when there is history but nothing open. The first
  two were confirmed to **fail against the pre-fix code**; text assertions alone
  could not catch this bug, since the broken strip rendered no text either.
- **Empty states are one crafted object (polish).** New
  `core/widgets/empty_state_medallion.dart` — halo, two concentric hairlines and
  a top-lit disc, strictly monochrome — replaces the flat grey glyph in
  `AppEmptyState` and the bare faded mark in `DropEmptyState`. New public
  `EmptyStateBody` holds the shared title/message/action rhythm and a 264px
  measure. Because the two core states kept their APIs, all **~39** call sites
  (task lists, pending review, My Tasks tabs, inbox, cases, requests, branch
  lists) inherit it; Home's bespoke in-card empty state now composes the same
  pieces at `size: 84`.

- **A failure looked exactly like an empty screen (bug-adjacent).** Screens
  rendered errors through `AppEmptyState` with an error glyph, so "the request
  failed" and "you have nothing" were the same picture — and most offered no way
  out. New `core/widgets/app_error_state.dart`:
  - `AppErrorState` — full-area failure. Same medallion silhouette, tinted with
    the semantic error tone (status colour expressing status, ADR-004), plus a
    **Retry** control. Adopted in notifications, communications, broadcast
    templates + schedules, branch operations and cases — **six surfaces that had
    no retry, or a bare `TextButton`, now have the same one.**
  - `AppProblemPanel` — the inline banner that existed as **three byte-identical
    private `_ProblemPanel` copies** in the attendance weekly / monthly / daily
    screens. Deduped into core, with optional retry.
  - `EmptyStateMedallion` grew an optional `tone` so one silhouette serves both
    "nothing here" (monochrome) and "this failed" (error-tinted).
- **Loading states (polish).** `Skeleton`'s sweep ran `darkSurface` →
  `darkSurfaceElevated` — a 6-value step, invisible on a card already painted
  `darkSurface`, so every skeleton read as a dead grey slab. It now rests one
  surface above its card and sweeps through a real highlight. Centred
  `CircularProgressIndicator` bodies in cases, swap view, the attendance admin
  workspace and daily review were replaced with the skeleton language so the
  screen keeps the shape of what is arriving. In-button and in-sheet spinners
  were deliberately left alone.

### Offline policy: gate the actions, never the app (feature; MED risk)

Asked for as a hard "the app does not open without internet", then **reversed
the same session** once the consequence was spelled out — the shipped behaviour
is the second design.

**Why the wall was wrong here.** Clock-in happens *at a branch*, which is
exactly where signal is worst — and attendance was built to survive that:
`attendance/{uid}_{yyyyMMdd}_{shift}` is deterministic, so a write that replays
late cannot duplicate. A launch gate broke the highest-value, lowest-risk
offline case in the product, made the (deliberately enabled) Firestore cache
useless, and had no override: the reachability probe is a DNS lookup, so a
network throttling that one host would strand a user outside the app entirely.

What shipped instead:

- **`core/network/connectivity_service.dart`** — unchanged from the first pass
  and the hard part. ⚠️ `connectivity_plus` reports the network *interface*, so
  a captive portal or a dead upstream both report `wifi`. The interface is the
  **trigger**; a DNS lookup of `firestore.googleapis.com` (5s) is the
  **verdict** — "can this app reach its backend", not "is the internet up". No
  interface short-circuits the probe.
- **`core/widgets/connectivity_scope.dart`** — `ConnectivityScope` (inherited
  state, mounted outermost in `main.dart`'s router builder), `OfflineBar`, and
  the `requireOnline(context, action:)` guard.
- **`OfflineBar`** is permanent while offline and names *when* the connection
  dropped ("Offline since 18:15 — showing saved data"). A snackbar cannot stop a
  manager trusting a stale roster ten minutes later; the timestamp answers the
  question stale data actually raises. It takes the status-bar inset itself and
  removes it from the child, so screens below lay out exactly as they do online.
- **Gated:** every review decision — approve / request rework / reject — across
  all four surfaces that carry them (`submission_details_sheet`,
  `task_details_screen`, `task_action_sheets/review_sheet`,
  `task_feed_expansion`). **Not gated:** reads, and clock in / out.
- `requireOnline` defaults to **allowing** the action when no scope is above it,
  so a widget tested in isolation is never accidentally offline.
- New `test/connectivity_scope_test.dart` (8 cases) covering the false-online
  verdict, that the app is never blocked, and both sides of the action gate.

**The write guard (the part that actually closes this).** Gating UI buttons was
never enough: with persistence on, *any* write issued offline is accepted into
the cache, reported as a success, and replayed later — so a manager creates a
task, sees it confirmed, nobody receives it, and it arrives an hour on. That is
the silent delay the whole exercise was about.

- **`core/network/network_guard.dart`** — `NetworkGuard.ensureWritable()` throws
  the new `OfflineFailure` when there is no connection. Placed as the first
  statement of every **write** repository method: **58 explicit call sites**,
  plus the admin repository's `_run` helper which covers a further 9 in one
  place. Reads never call it — serving a cached roster is the point of the cache.
- It lives at the repository layer on purpose. Cubits already `catch (Failure)`
  and emit their error state, so this surfaces on every screen with **zero
  per-screen work** — and any *future* UI calling an existing repository method
  is covered automatically. Guarding the 81 UI call sites instead would have been
  complete today and decayed on the next screen.
- ⚠️ **A cached flag, not a live probe.** The DNS lookup takes seconds; running
  one in front of every write would put that on the happy path. `ConnectivityScope`
  keeps the flag fresh from the same stream the bar uses.
- ⚠️ **Defaults to online.** A test or script that never installs a status must
  behave exactly as before — failing closed would turn a missing wire-up into
  "every write in the app is broken".
- **Exempt: `clockIn` / `clockOut`.** Pinned by a test, not just a comment.
- **Not guarded, deliberately:** the three chat methods on the NestJS backend
  (`startConversation`, `deleteMessageForMe`, `deleteMessageForEveryone`). They
  go over HTTP, not Firestore, so they already fail loudly offline — there is no
  silent queue to prevent.
- New `test/offline_write_guard_test.dart` (4 cases): the online default, a
  guarded write throwing and **never reaching the datasource**, clock-in still
  writing while offline, and recovery.

Still open: **Firestore offline persistence stays enabled** and now agrees with
this design rather than contradicting it — the cache serves reads, and writes are
refused honestly. Not exercised against a real radio — airplane mode and a
captive portal on device are still untested.

### Chat inbox N+1 removed — server now serves the preview (feature; MED risk)

**Cross-repo.** Backend `~/Desktop/Developer/drop-api` (branch
`feature/chat-backend`) + this app. **Not deployed** — the server half must ship
first, but the client works either way (see below).

The inbox issued one extra request per visible row because
`ConversationListItemResponseDto` carried `lastMessageAt` but not the message,
with the comment *"Last-message preview is intentionally absent"*. Checking the
spec, that was not a decision: **FR-021 already requires the list to indicate a
preview of the latest message.** The DTO was a deviation, so this implements the
spec rather than reversing anything — no ADR needed.

The cost turned out to be near-zero: `conversation.last_message_id` is a real FK
the write side already maintains, so the preview is a **join**, not a query per
row. Ten conversations went from **eleven requests to one**.

- **Backend:** `LastMessagePreview` on the repository port; `include:
  { lastMessage: true }` on the list query; the field threaded through view →
  use case → DTO. One extra batched lookup honours **delete-for-me** — a message
  the requester deleted for themselves is still the conversation's
  `lastMessage` for everyone else and must be withheld from *their* inbox.
  Payload is unformatted (`type` / `body` / `deletedForEveryoneAt`) so preview
  wording stays in one language, on the client. +3 spec cases; **92 pass**.
- **Client:** additive `ChatLastMessage` on the summary + `chatLastMessagePreviewText`.
  ⚠️ **The per-row fallback was kept on purpose** — the deployed server does not
  send the field yet, and removing the fallback would blank every preview until
  the API ships. +8 cases covering both the served and the omitted shape.

### Chat inbox state churn (bug; LOW risk)

Owner report: "every time I open chat it keeps requesting things, and something
changes every second." Diagnosed by reading the path, not by profiling a live
session — the API was not available here.

**Root cause is structural: the inbox is N+1.** `ChatConversationSummary`
carries `lastMessageAt` but **not the message**, so `ChatScreen` fires one
`latestChatMessage(id)` per visible row on open. Ten conversations = ten extra
requests. That is by design today (`chat_conversation.dart`: *"Last-message
previews remain client-resolved"*), and the real fix belongs in the NestJS list
DTO — **not done here**.

Three client-side defects sat on top of it and were fixed:

- **A retry loop.** A lookup returning `null` removed the id from
  `_previewFetching` but never recorded a result, so `containsKey` stayed false
  and the row re-queued its fetch on **every rebuild** — and since each landing
  lookup triggered a rebuild, the two fed each other. `ChatListCubit` now
  distinguishes *resolved-empty* from *not-yet-resolved*.
- **N full-screen repaints.** Every resolved preview called `setState`
  individually, so a ten-row inbox repainted itself ten times in under a second
  — the visible "everything keeps changing". Results are now written to the
  cache as they land and a **single** repaint is scheduled for the batch (60ms
  coalescing window).
- **The memo died with the screen.** It lived on `_ChatScreenState`, so walking
  into a conversation and back re-fetched every row. It now lives on the
  app-wide `ChatListCubit` — resolved once per session. ⚠️ Deliberately placed
  where `reset()` already clears it, so one account's previews can never appear
  in the next account's inbox on a shared device.

Not changed: `ChatListCubit.load()` (already idempotent, cache-paints before the
network, and freezed's `DeepCollectionEquality` suppresses duplicate emits) and
`ChatMessageList` (its `didUpdateWidget` guards are sound). The churn was not
there.

New `test/chat_preview_cache_test.dart` (5 cases), including the account-switch
clear.

### Splash centering — the suite is green again (bug; LOW risk)

`splash_centering_test.dart` had been failing for weeks, written off in the docs
as "either the layout regressed or `kSplashOpticalLift` changed". Neither guess
was right: there were **two independent bugs**, one on each side, and they
partly masked each other.

- **The test mixed coordinate spaces.** `getRect` reports a box *as painted*, so
  it already carries the centre-anchored `kLogoManualScale` (1.5×). The test then
  added the **unscaled** artwork inset to that already-scaled rect — the dead
  space above the artwork is magnified too. Worth ~9px.
- **The page's lift formula never knew about the scale.** It predated
  `kLogoManualScale` (owner-tuned by eye 2026-07-05), so the framing it produced
  **drifted with window size** — a real 65.5px lift at 1440×900 but 61.6px at
  1024×720 — while `kSplashOpticalLift` claimed 50 at both. The formula also
  still carried a `kLogoVisualCenterOffset` term left over from an earlier
  "centre the artwork" approach, which is not what the bbox framing needs.

Fixed on both sides. The lift is now derived from the **visible** geometry
(artwork inset × scale, minus the box's centre-anchored growth), and
`kSplashOpticalLift` was set to **65.5** — the measured value of the framing the
owner actually signed off. Net effect: **zero pixel change at 1440×900**, and
1024×720 moves up ~4px to match it instead of drifting. The owner tuned pixels,
so the pixels were treated as the specification and the constant was corrected to
tell the truth about them.

`kLogoVisualCenterOffset` is retained — it is still documented and separately
pinned by `splash_visual_centering_test.dart` — but no longer feeds the lift.

**`flutter test` is now fully green: 1457 pass, 0 fail.** That matters beyond
this test: with two permanent failures, a genuine regression had somewhere to
hide.

Verified: `flutter analyze lib test` at the documented baseline (1 pre-existing
test-style info); suite **1470 pass / 0 fail** (+30 new this branch); backend `npx jest` **92 pass** — no
regressions. Geometry was confirmed by measuring the real widget at both window
sizes, not by algebra alone. Not device-verified.
## 2026-08-03 — Explicit broadcast delivery and premium templates (feature + polish; MED risk)

- The New Broadcast composer now defaults to the visible **Push + Inbox** delivery
  choice, with **Inbox only** as the only alternative. `sendsPush` travels through
  the callable and schedules; the Cloud Function retains category-based fallback
  for legacy payloads. Emergency keeps its separate high-priority treatment.
- The composer leads with title and message, puts delivery before the nested
  routing configuration, and retains the sticky send action. Templates now have
  a structured monochrome library summary without changing library/picker/editor
  behavior.

Risk: MED — delivery wiring spans client, schedules, and the server; the fallback
keeps existing scheduled broadcasts compatible.

---

## 2026-08-02 — Notification subjects and complete employee broadcasts (polish + bug; LOW risk)

Because `title` is a pure `switch (type)` in every producer, `body` is the only
line that can say *which* thing a row is about — so a body naming nothing gives
you a column of identical rows. Tasks were fixed for this on 2026-08-01; cases,
requests and attendance never were.

- Case status, request lifecycle/comment, and attendance correction/auto-close
  bodies now lead with their subject, then the event context after ` • `.
  Attendance gains the shift and Cairo business date (`Morning shift, 2 Aug`),
  so two missed clock-outs are no longer indistinguishable rows.
- **Requests use the requester's own `details.message`, deliberately not
  `lastEventPreview`.** That field is a *rolling* preview of the most recent
  timeline event, so by the time a request is approved it may hold the latest
  comment — giving "sounds fine to me • Approved". `details.message` is written
  once and is the same string the opening notification used, so every row for
  one request names the same thing. `lastEventPreview` stays as a fallback (it
  equals the reason at creation), then the durable `REQ-######`.
- Case notifications remain identity-free — only `subject` is used, never a
  reporter name or uid.
- An employee broadcast has no Communications detail route to open, so its
  non-navigable row was truncating the message at five lines with nowhere to
  read the rest. It now renders in full. Navigable subjects remain exactly one
  line — that cap is load-bearing, a wrapping subject makes every card a
  different height.

Gates: analyze clean (1 pre-existing info) · Dart 1441 pass / 2 pre-existing
splash failures · functions 82 pass · rules 61 pass.
✅ The server-side body changes are **deployed 2026-08-02**; the tile change
ships with the app build.

---

Gates: analyze clean (1 pre-existing info) · Dart **1442 pass / 2 pre-existing
splash failures** · functions **83 pass** · rules **61 pass**.
⚠️ The `sendsPush` field is honoured server-side — **needs a Cloud Functions
deploy**. Deploy the server before shipping an app build that sends it;
until then broadcasts fall back to the old category-derived delivery.

---

## 2026-08-03 — iOS push: UIScene silently swallowed the APNs token (bug; MED risk)

APNs keys correct, Bundle ID correct, entitlement signed, permission
`authorized` — and `getAPNSToken()` still returned null forever. The cause was
the **UIScene lifecycle**, which ships in the stock Flutter 3.44.2 template.

`firebase_messaging` receives the APNs token only through
`[_registrar addApplicationDelegate:self]` — Flutter's `UIApplicationDelegate`
forwarding — and sets it via `[FIRMessaging setAPNSToken:]`. Flutter 3.44 added a
*separate* `addSceneDelegate:` path for scene-based apps, and
firebase_messaging 15.2.10 **never calls it** (zero occurrences in the plugin).
With `UIApplicationSceneManifest` active the callback never reaches the plugin,
so the token is never set and every later step is dead. Android was untouched —
none of this exists there.

**Proven by A/B on the physical iPhone**, not by inspection:

| Run | Config | `getAPNSToken()` |
| --- | --- | --- |
| 1 | DROP, scenes ON | null ×10 |
| 2 | brand-new `flutter create` 3.44.2 + fbm 15.2.10, scenes ON | null ×10 — identical, so **not DROP-specific** |
| 3 | same control, **scenes OFF** (only variable changed) | **token on attempt 1**, FCM token minted |
| 4 | same control, scenes ON + manual `Messaging.apnsToken` in AppDelegate | null ×10 — the AppDelegate override is **not** sufficient |

Run 4 is why the fix is removing the manifest rather than a three-line
AppDelegate forward: under scenes the callback does not execute at all, so there
is nothing to forward.

- **Fix:** removed `UIApplicationSceneManifest` from `ios/Runner/Info.plist`.
  `SceneDelegate.swift` is left on disk but is never instantiated without the
  manifest, so it is inert — that is exactly how run 3 was configured.
- **Trade-off:** DROP opts out of iOS 26 multi-window / multi-scene. It was
  already opted out functionally (`UIApplicationSupportsMultipleScenes: false`)
  and is a single-window app, so nothing observable is lost. Revisit when
  firebase_messaging adopts `addSceneDelegate:`.

Verified on the physical iPhone: `APNs token acquired` on the first attempt ·
`FCM token` minted · `token written to users/{uid}.fcmTokens` · Firestore
`fcmTokens` 0 → 1 · a real push logged `tokenCount:1 successCount:1
failureCount:0`, which also confirms the APNs key on `com.ziad.drop`.

Gates: analyze clean (1 pre-existing info) · Dart 1441 pass / 2 pre-existing
splash · functions 82 · rules 61.

---

## 2026-08-03 — iOS push: the app was registering as the wrong Firebase app (bug; MED risk)

APNs keys were uploaded, yet iOS still could not have received a push. The cause
was not the credential — it was identity.

**Xcode builds `com.ziad.drop`. Both `lib/firebase_options.dart` and
`ios/Runner/GoogleService-Info.plist` described `com.example.fbro`** — a
*different* Firebase iOS app (`…f1d3167839a737155a0bc0`). The project has three
registered iOS apps, which is how this went unnoticed. Because `main.dart`
initializes with `DefaultFirebaseOptions.currentPlatform`, the Dart values win
over the plist, so **fixing only the plist would not have helped.** An APNs key
is attached per iOS app, so tokens were minted against an app the sender never
targets, and every push silently went nowhere. Android was unaffected — its own
`google-services.json` was always correct — which is exactly why this looked like
"Android works, iOS doesn't".

Both now point at `1:450092605249:ios:c938624f6a08c77d5a0bc0` (`com.ziad.drop`),
with the correct `iosClientId`. macOS shared the same wrong id and the same
bundle id, so it was corrected too.

- **iOS foreground notifications** now appear: `NotificationService.init` calls
  `setForegroundNotificationPresentationOptions`, gated to Apple platforms. The
  in-app snackbar is suppressed there so the OS banner cannot double-notify;
  **Android keeps the snackbar exactly as before**, since a foreground push on
  Android reaches `onMessage` only and the OS shows nothing.
- **APNs token race fixed.** `registerToken` aborted whenever `getAPNSToken()`
  returned null — routine on a cold start, since the auth listener fires the
  moment sign-in completes. The old comment claimed `onTokenRefresh` would
  re-register later, but that stream fires only when the **FCM** token *changes*;
  on a returning device it never fires, so the token never reached
  `users/{uid}.fcmTokens` and every push to that device vanished. Now polls up
  to ~5s before giving up.

Audited and deliberately left alone: `AppDelegate.swift` (firebase_messaging
15.2.10 has swizzling enabled — it calls `registerForRemoteNotifications` and
implements `didRegisterForRemoteNotificationsWithDeviceToken` itself, so adding
them would duplicate or conflict), and `aps-environment=development` (Xcode
rewrites it to `production` when exporting a distribution archive).

Verified in the built artifact: the `.app` carries `CFBundleIdentifier`
`com.ziad.drop`, a `GoogleService-Info.plist` whose `BUNDLE_ID` matches it,
`UIBackgroundModes: [remote-notification]`, `MinimumOSVersion 13.0`.
Gates: analyze clean · Dart 1441 pass / 2 pre-existing splash · functions 82 ·
rules 61 · `flutter build ios --no-codesign` succeeds.

⚠️ **Still unverified from here:** actual delivery needs a physical iPhone, and
the APNs key must sit on the **`com.ziad.drop`** app in Firebase — not one of the
other two iOS entries.

---

## 2026-08-02 — Notification delivery guarantees (bug; MED risk)

- **Scheduled broadcasts:** claim the queried due instant transactionally before dispatch and finalize only after it. A failed claimed dispatch is deliberately consumed and logged at error level; if finalization is uncertain, the durable claim prevents an org-wide duplicate.
- **Approved swaps:** `approveSwap` now server-writes one `swapApproved` inbox doc per party after its atomic roster exchange, so manager app termination cannot lose both notices. The duplicate client producer was removed; notification-write failure remains best-effort.
- **Cases:** `changeStatus` stamps the authenticated manager/admin in `statusChangedBy`; reopen notices exclude that actor without exposing an identity in any notification content.
- **Broadcast pushes:** one retry is allowed only for transient/thrown Admin Messaging sends. Dead/invalid tokens remain prune-only, and final delivery logs include real success/failure counts.

The client half of the swap change ships with the app build; everything else is
server-side. ✅ **Deployed 2026-08-02** — functions went out *ahead* of any app
build carrying the client change, which is the correct order: shipping the build
first would have left approved swaps announced to nobody.

Gates: analyze clean (1 pre-existing info) · Dart 1440 pass / 2 pre-existing
splash failures · functions 80 pass · rules 61 pass.

---

## 2026-08-02 — A correction could overwrite someone else's attendance (bug; MED risk)

Found while auditing attendance *notifications* — the notification deep-linked the
employee to a record they could not read, which is what exposed it.

`attendance_corrections` bound `userId`, `requestedBy`, `status` and `branchId` on
create, but **never `attendanceId`**, and `applyCorrectionResolution` trusted it:
it fetched that record and called `ref.update()` with no check that the record's
owner matched the correction's. Since record ids are deterministic
(`{uid}_{yyyyMMdd}_{shift}`) and branch members can read own-branch users, a
victim's id is constructible — so an employee could file a correction carrying
their own `userId` and someone else's `attendanceId`, and a manager approving it
would overwrite that person's clock times, worked minutes, lateness and overtime.
The same gap let a manager evade the no-self-approval rule (rule (b) only checked
`uid != userId`) by naming their own record.

- **Rules:** both create branches now require the `attendanceId`'s owner prefix to
  equal the correction's `userId`, and deny a malformed id outright. This is an
  id-prefix check rather than a `get()` of the attendance doc **on purpose** —
  manager "Add record" legitimately files against a record that does not exist yet,
  which an `exists()` check would deny.
- **Server (defence in depth):** `applyCorrectionResolution` returns a boolean and
  refuses when an existing record declares a different `userId`, or when a
  to-be-materialized id's prefix does not match. Both call sites now suppress the
  approval notification on refusal — telling someone their correction was applied
  when it was not is worse than silence.
- **Tests:** new `firestore-tests/attendance_corrections.rules.test.mjs` (8 cases;
  the collection previously had **no** rules test at all) plus pure Functions
  coverage of the guard.

Gates: analyze clean · Dart 1440 pass / 2 pre-existing · functions 76 · rules 61.
✅ **Rules + functions deployed 2026-08-02** — the hole is closed in production.

---

## 2026-08-02 — Task notification path hardening (bug; HIGH risk)

Found by an end-to-end audit of the task-notification path (backend + client,
both platforms). Four fixes; the reminder bug and the rules hole were both live
in production.

- **Notification rules (P0):** the `notifications` update rule checked only the
  OLD doc and restricted no fields, so a recipient could rewrite `recipientUid`,
  `title`, `body`, `type`, and `payload` — moving forged content into another
  user's inbox with a deep link of their choosing. Updates are now confined to
  `readAt` / `archivedAt` / `pinnedAt`. New `firestore-tests/notifications.rules.test.mjs`
  pins it (6 cases) alongside the unchanged read/delete/create behaviour.
- **Task reminders (P1):** the terminal set was only `{approved, rejected}`, so
  `runTaskReminders` kept sending "Task Late" pushes for work already auto-closed
  as **Missed** or explicitly **Cancelled** — contradicting the Automated Tasks
  spec §8. `missed` and `cancelled` are now excluded. The predicate moved to its
  own `functions/task_reminders.js` (matching `recurring_task_deadline.js`) so a
  test can reach it without loading the whole functions entry point. `rejected`
  stays excluded on purpose — the reviewer owns rework — and the module comment
  now says why, so it does not get "simplified" into `isTerminalTaskStatus`.
- **iOS push app configuration:** added the development APNs entitlement,
  Runner signing wiring, and `remote-notification` background mode. AppDelegate
  is unchanged: Firebase Messaging swizzling handles APNs forwarding, and the
  app deliberately retains its own foreground snackbar rather than doubling it
  with an OS banner. Delivery still awaits the APNs credential.
- **Android push:** FCM now uses the named, high-importance `drop_default`
  channel created at app launch. A monochrome notification icon remains design
  work; no placeholder asset was added.

---

## 2026-08-01 — Three controls on the reports that could never work (bug; LOW risk)

Owner asked whether the weekly/monthly reports and the PDF export actually work.
Auditing them found the reports themselves sound and three controls that were not.

**"Close week" / "Close month" deleted.** Both were the *primary action* of their
report — filled style, padlock icon, top of the page — and both were hardcoded
`onPressed: null`. They could never do anything. Worse, they advertised the one
behaviour the product deliberately refuses:
[ADR-019](docs/decisions/ADR-019-operational-exports-and-week-review.md) decides a
week is **reviewed, never locked** — *"no write is rejected, no rule enforces it,
no period becomes immutable."* The real mechanism already ships as the **Week
review** section at the foot of the weekly report: it records who looked and when,
and is reversible by Reopen. A padlock at the top contradicted it.

**Two stale "Daily review is coming next" toasts wired up.** Daily Review shipped;
the weekly report's own day table opens it. Yet both "Review these" buttons still
toasted that it was coming.
- Weekly → jumps to the **earliest day that still has a blocking decision**, and
  disables itself when nothing is open rather than sending a manager to a settled
  day.
- The coverage widget's button is now **slot-based** (`onReviewOpen`); it knows a
  count, not a branch or a period. **Null hides the button** instead of rendering
  one that cannot act. The reports hub supplies the destination.

Verified working and untouched: **the weekly PDF and timesheet CSV are real** —
`buildWeeklyAttendancePdf` / `attendanceTimesheetCsv`, written via `path_provider`
and handed to the system viewer, covered by three test files. They are gated by
`attendanceExportAvailability`: manager/admin, rows exist, and **zero unsettled
shifts** — a deliberate refusal to emit a document that would change later.

Still genuinely not built (labelled honestly in the UI): the **monthly** PDF and
spreadsheet.

Suite **1440 pass / 2 fail** (the 2 pre-existing splash-centering failures).

---

## 2026-08-01 — History showed "No matches" for a person it had just counted (bug; MED risk)

Owner screenshot: searched **"ziad"** in Attendance history. The summary strip
said **1 Absent**. The list underneath said **"No matches — try widening the date
range or clearing a filter."** The range was fine.

The two halves of that screen read different sources. The summary comes from the
**expectation ledger**, which has a row for every rostered shift including the
ones nobody worked. The list comes from **attendance records** — and an absence
deliberately has no record (`ATTENDANCE_SPEC` R13: *"Absent stays virtual… No
phantom documents"*). That is the right storage decision and the wrong reading
decision: the one day a manager asks about is the one day that renders nothing,
under an empty-state that blames the filters.

- New pure `attendanceHistoryGaps()` (`attendance_history_gap.dart`) — the
  rostered shifts in the already-streamed ledger that have **no record**, narrowed
  by the same text / shift / status facets the record list uses, so the two halves
  can never disagree again. No new read, no new query, no minute math.
- The list interleaves records and gaps chronologically, newest first. A gap
  renders as a quieter, **deliberately non-tappable** card — there is no record to
  open, and a dead tap target teaches a manager the screen is broken.
- A gap can only satisfy facets that describe *not working*; asking for "Late" or
  "Overtime" is asking about a record, so gaps drop out rather than padding a
  filtered list with rows that cannot match it.

**Removed "Payroll blockers"** from the summary strip. DROP does no payroll — it is
a named scope guardrail (ADR-009/ADR-010) — so putting the word on a ledger the
owner reads daily promised something the product does not do. The same count now
reads **"Needs a decision"** and appears only when it is non-zero.

**Removed the Today subtitle** *"Who is here, late, absent, or needs a decision"* —
the counts and the grouped rows underneath already say it.

Tests: `test/attendance_history_gap_test.dart` (8 cases), including the literal
reproduction — search "ziad" against a ledger holding one absence and no record.
Suite **1440 pass / 2 fail** (the 2 pre-existing splash-centering failures).

---

## 2026-08-01 — Attendance starts with Today (feature; LOW risk)

Attendance & Reports now opens the existing live board rather than the reporting
hub. Managers see their own branch; admins explicitly choose a branch. The board
groups people into needs a decision, present/working, late, and absent, with
Reports and Person history as direct next steps. An unscheduled clock-in now has
plain **Mark present** copy that reuses the existing audited direct-resolution
path; an explicit **Leave unapproved** action preserves the exception. `/admin/attendance` redirects to
Today, avoiding two live board destinations. [ADR-021](docs/decisions/ADR-021-attendance-today-first.md)
records the IA decision.

Follow-up: Person history now has rolling Last 7 days / Last 30 days presets,
and a Today row's History action carries that employee and branch into the
existing reviewer ledger. Today bootstrap also retries when auth resolves late.

---

## 2026-08-01 — Daily Review: don't spend the one-shot on a pass that bailed out (hardening; LOW risk)

Follow-up to the workspace hang. Auditing every screen for the same shape turned
up one more latch with the same failure mode, reached differently:

```dart
if (_started) return;
_started = true;                              // burned before it did anything
if (date == null || user == null) return;     // …and never retried
```

A deep link that opens Daily Review before auth finishes restoring would spend the
latch on a pass that loaded nothing, and the board would sit on its spinner for
the life of the screen.

Moving the flip below the guard is necessary but **not sufficient**, and the first
draft of this fix was wrong about why: `context.currentUser` reads `AuthCubit`
with `read`, registering **no dependency**, so a late session never re-triggers
`didChangeDependencies` on its own. The latch would simply stay unspent forever.

So it now uses the same two-path shape as the other correct screens: the already
signed-in case starts from `didChangeDependencies`, and a `BlocListener<AuthCubit>`
covers the session arriving late. `_maybeStart()` is idempotent, so the two can
never double-dispatch.

Unreachable in practice today — the route guard makes a null user very unlikely,
and a malformed `dayKey` already renders an explicit "not a valid day link" panel
rather than loading. Fixed anyway because the latch was one routing change away
from mattering.

Tests: `test/attendance_daily_review_bootstrap_test.dart` (4 cases), verified to
**fail against the old ordering** — the late-session and load-exactly-once cases
both break, the already-live and malformed-link cases still pass. Suite **1421
pass / 2 fail** (the 2 pre-existing splash-centering failures).

**Audit result, for the record:** across all 19 `BlocListener` + 21 `BlocConsumer`
files, all 13 per-screen `create:` cubits, and every screen rendering an app-level
singleton, the Admin workspace was the **only** true instance. Every other
listener is error- or navigation-driven; the one that starts work
(`manager_schedule_view`) keys off a busy→idle transition that cannot be
pre-satisfied at mount. `attendance_history_screen._bootstrapReview()` and
`chat_notification_listener.initState` already implement the correct pattern.

---

## 2026-08-01 — Admin workspace hung on its spinner forever (bug; LOW risk)

Owner sent a screenshot of `/admin/attendance/workspace` spinning with no content.
Reproducible 100% of the time by the **only** navigation path that exists.

`_WorkspaceView.didChangeDependencies` called `BranchCubit.loadIfNeeded()` and
then relied on a `BlocListener` to start the ledger fan-out. But `BranchCubit` is
an **app-level singleton** (`main.dart` provides one instance for the session) and
the Attendance & Reports hub — the tile you arrive from — already calls
`loadIfNeeded()`. So the directory was always already loaded, `loadIfNeeded()`
emitted nothing, **a `BlocListener` never fires without a state change**,
`AdminAttendanceOverviewCubit.watch()` was never called, `overview` stayed null,
and `_Body` rendered its `CircularProgressIndicator` forever.

The codebase had already met this exact trap and written it down —
`attendance_history_screen.dart` awaits `loadIfNeeded()` and then reads the cubit
precisely because *"a `BlocListener` alone would miss the [already-loaded] case"*.
The workspace was the one screen that didn't get the memo (and it echoes the
standing macOS rule about never gating on a bloc-listener alone).

- `_bootstrap()` awaits `loadIfNeeded()` and then reads `BranchCubit.state`
  directly, covering the already-loaded case as well as the cold one.
- The listener stays, for the cold path and for later directory refreshes — it
  just can no longer be the only trigger.
- `_watchBranches` is idempotent over the active-branch id set, so both paths can
  call it without tearing down and re-subscribing an identical fan-out.
- It now refuses to fan out on a **non-loaded** state. Previously an error state
  would have produced `watch(branchIds: [])` → an empty overview reading as
  *"every branch reported nothing"*, which is the one lie this screen exists to
  prevent. Loading keeps the (honest) spinner.

Tests: `test/attendance_admin_workspace_bootstrap_test.dart` (3 cases). Verified
to **fail against the old code** — the "already loaded" case reproduces the hang
while the "loads after mount" case passes, which is exactly the bug's shape. Suite
**1417 pass / 2 fail** (the 2 pre-existing splash-centering failures).

---

## 2026-08-01 — The geofence policy actually governs the punch (bug + feature; MED risk)

Owner: *"fix the geofence policy so it actually works."*

`AttendanceLocationPolicy` — `none` / `soft` / `strict`, with `blocksOutside`,
`capturesLocation` and a `fromString` parser, calling itself *"the single knob for
the whole geofence behaviour"* — **was read by nothing.** Not the client, not
`functions/`, not the rules. What ran instead was hardcoded in two places that
could not disagree because neither consulted anything: `checkGpsFix` rejected
`noGeofence`/`lowAccuracy`/`outsideRadius` unconditionally, and the clock screen
disabled the button unless `geofenceReady && atBranch`.

So every branch behaved as `strict` while the config's default said `none` — and
**a branch with no geofence configured could never clock in at all.** The locked
`ATTENDANCE_SPEC` workflow 6 said exactly that (*"no geofence … No record is
written"*), so the code was faithful; the rule was the defect. `soft` and `strict`
both mean "compare the fix to the geofence" — with no geofence the question is
*undefined*, not failed, and the cost landed on someone standing at work unable to
record it.

**[ADR-020](docs/decisions/ADR-020-location-policy-is-real.md)** — amends the
locked spec (workflow 6 + the clock-in error list).

- `AttendanceService.resolveLocationPolicy({configured, hasGeofence})` is the one
  seam. **No geofence → `none`**, so that branch runs a pure time clock instead of
  being locked out. Draw the fence and it becomes `strict` with no other change.
- `checkGpsFix` takes the resolved policy: `none` never refuses · `soft` captures,
  stores, never refuses · `strict` is the full gate, **byte-for-byte unchanged**.
  A `strict` branch whose fence vanishes still fails loudly rather than passing.
- Default flipped `none` → `strict`, so the config describes what ships and an
  un-migrated caller keeps the gate instead of silently losing it.
- The cubit collapses the resolved policy into `_config` once the geofence is
  known, so the validation gate, the UI and the record's config snapshot (R19) all
  read one value.
- UI: under `none` the GPS card isn't rendered at all; under `soft` it still shows
  every state but stops saying *"move closer, then tap to retry"* next to an
  enabled button — an unverifiable fix reads *"Recorded with your punch for a
  manager to review."*

**The trade, stated plainly:** a non-geofenced branch can now punch from anywhere.
That is weaker than perfect enforcement — but the status quo was not enforcement,
it was *no attendance at all* plus manager-typed reconstructions with no location
evidence, which is the worse evidence ADR-018 already rejected once. Nothing
changes at any branch that has a fence.

Still open: `AttendanceService.configFor` returns one constant for everyone, so
`soft` is reachable but unselectable. Per-branch `branches/{id}/attendanceConfig`
is now data entry rather than another gate rewrite.

Tests: 12 new cases across `attendance_validation_test.dart` (each policy's
refuse/allow behaviour, the strict default, and `resolveLocationPolicy` over every
enum value both ways). **One existing test changed meaning** —
`attendance_cubit_test.dart`'s *"clockIn when the branch has no geofence is blocked
(no write)"* now asserts the punch is recorded with a null verification; that is
the reversal made visible. Suite **1414 pass / 2 fail** (the 2 pre-existing
splash-centering failures).

---

## 2026-08-01 — Attendance reports: open one person from a "By person" row (feature; LOW risk)

Owner question: *"is it easy to get an employee report or see all his history?"*
For the employee themselves, yes. For a manager, **no** — and the audit found why:

- The "By person" tables in both the weekly and monthly reports were plain text
  rows. No `onTap`, no `InkWell`. You could read `Ziad Elsewedy · 4 · 0 · 4 ·
  Absent` and had no way to open him.
- The one screen that *can* answer it — reviewer-mode Attendance History, which
  already has a branch-wide **"Search employee"** field — was reachable only from
  `/attendance/review`, pushed only from `admin_attendance_screen.dart:57`, on a
  route (`/admin/attendance`) that **nothing in the app navigates to**.

So the capability existed and the door didn't. This adds the door.

**A row now opens that person's own ledger, pinned to the branch and period the
row was read in.** That pinning is the point: carrying only the name would land
the reviewer on their own branch's default window and quietly show different
numbers than the row they just tapped.

- New `AttendanceReviewLink` (pure Dart) — name + optional `branchId` + optional
  `start`/`end`. `hasWindow` is true only when **both** bounds are present; one
  alone would half-apply a range the resolver falls back on anyway.
- The `/attendance/review` route already accepted a bare `String` name as `extra`.
  It now accepts the typed link and still accepts the String, so any hand-built or
  older link keeps working.
- `AttendanceHistoryScreen.review` gains `initialStart`/`initialEnd`; the DI
  factory turns them into an `AttendanceDateRange.custom` query. The filter bar
  already renders a custom window as its dates, so the chip reads **"26 Jul – 1
  Aug"** on arrival with no extra work.
- `AttendanceWeeklyEmployeeRows` gains a slot-based `onOpenEmployee`. Null leaves
  the rows exactly as inert as before — the widget stays presentation-only and
  never learns which branch or period it is inside.
- Row affordance: pointer cursor plus a hover step where the **name** brightens,
  not the numbers. The header row is never tappable.
- **The reviewer search box is now seeded** from the query it filters. It was
  rendering empty while the ledger was filtered, so a deep-linked list looked
  mysteriously short with no visible cause and no obvious way back. Seeding a
  caller-owned controller also gives the shared field's clear button something
  real to clear.
- Because hover and a cursor don't exist on a phone, the section says *"Open
  anyone to see their own records for this period."* — but only when the rows
  actually open.

Not addressed here, and now written down in CURRENT_STATE under *Attendance gaps*:
the dead `AttendanceLocationPolicy` (every branch behaves as `strict`; a branch
with no geofence cannot clock in at all), the orphaned `/admin/attendance` route,
a stale *"Daily review is coming next"* stub sitting next to a working Daily
Review, and the still-missing period close + export.

Tests: `test/attendance_person_drilldown_test.dart` (7 cases) — the row reports
its own employee, the header never opens, rows stay inert **and unadvertised**
without a callback, `hasWindow` needs both bounds, and the search box shows the
name it is filtered to. Suite **1407 pass / 2 fail** (the 2 pre-existing
splash-centering failures).

---

## 2026-08-01 — Employees directory: an identity-only row card (polish; LOW risk)

Owner ask, verbatim: *"redesign the card of the employees and remove the
complete and rate and all of this — just the name and branch, I don't need all
of this."*

The card had been carrying four inline KPIs (Completed · Pending · Rate · Late)
since the 2026-07-27 density pass. In a real directory they were **nine zeros in
a row** — every employee scored identically, so the numbers said nothing while
costing the tallest band of every card. `EmployeeCard` is now identity-only:

```
⬤  Mohamed khaled                                    Active  [Details] [Edit] [⋯]
MK 🏪 Drop the shop | Arkan
```

- **Removed** the `metrics` parameter and the whole `_InlineMetrics` block. Row
  height drops from ~140px to ~68px, so roughly twice as many people fit on a
  screen and the eye runs down one column of names.
- **Removed** the role from the subtitle. It read "Employee ·" on nearly every
  row; the Role filter and the Details inspector both still carry it.
- **The branch is the second line on its own**, behind a storefront mark and one
  step down the grey ramp. An unassigned employee reads *No branch* in italic
  quaternary grey — a gap to fill, deliberately not an error red.
- Access state, Details / Edit, the ellipsis menu and the desktop right-click
  menu are **unchanged**; the card is still presentation-only.
- Radius tightened to 16 (20 reads as a pill at this height); wide/narrow
  breakpoint moved 620 → 520, since the row no longer has a KPI band to fit.

**Nothing was lost.** `computeEmployeeMetrics` is untouched and still feeds the
Details inspector, which has the room to present performance honestly. Removing
the card's dependency on it also let `_body` stop `watch`ing `TaskCubit`, so the
directory no longer rebuilds on every task-stream tick — the inspector reads the
cubit on demand when it opens.

Tests: `test/employee_card_test.dart` rewritten around the new contract (name ·
branch · access · actions, "No branch", KPI labels absent, no overflow at
280px). Suite **1400 pass / 2 fail** — the 2 are the pre-existing
splash-centering failures.

---

## 2026-08-01 — Notification inbox: readable rows + the dead attendance tap (polish + bug; LOW/MED risk)

## 2026-08-01 — Employee Home: the ring goes, the clock arrives (polish + bug; MED risk)

Owner asked what Home was missing and what should go. Both answers were in the
same 92 pixels.

**The progress ring's arithmetic was wrong, and is fixed.** It drew
`approved + completed + inReview / total`, so it rendered a *complete* circle
"3 of 3" beside a strip reading "1 in review · 2 done" — two elements, one
dataset, disagreeing. It now takes the same `_Counts.done`
(`approved + completed`) the strip's own Done cell uses: a submission has left
the employee's hands but a reviewer can send it straight back, so it is not
closed.

> The ring was **deleted** in the first pass and **restored by the owner** the
> same day, at 78px beside the shift instead of 92px alone. Restored on the
> condition above — it counts what the strip counts. Because the ring carries
> the ratio, nothing else on Home draws it: the interim `_DayProgressBar` (a
> 3px base line under the strip) is gone, and it had a flaw of its own — at
> 100% a filled hairline is indistinguishable from the card's border.
>
> The green **"All caught up!"** banner went with it (owner). It was the only
> coloured thing on the screen and the third element restating a finished day
> after the ring and the strip. Its "Open all tasks" row stays — that is the way
> through to the list, not a restatement. `_EmptyTaskState` ("No tasks yet") is
> untouched: never-assigned is a different case from finished.

**Its space went to the clock state.** DROP has a full GPS attendance engine,
and clocking in/out is the thing an employee does twice a day at a fixed time —
yet Home showed *"TODAY'S SHIFT · Morning shift"* and then never said whether
they were on it. The only way in was an **unlabelled fingerprint icon** in the
app bar. The card now reads `Morning shift 08:00 – 16:00` over a state row:
green *"Clocked in 8:04 · 6h 30m on shift"*, amber *"Not clocked in · Shift
started 34m ago"*, or a grey *"Clocked out 16:02"* with no action left. A day
off drops the row entirely and the card shrinks.

The action is a **hand-off, not a clock-in** — it opens the Attendance screen.
Clocking in needs a verified GPS fix inside the branch geofence and fails in
several distinct ways; a second copy of those rules on Home would drift. For the
same reason Home calls `AttendanceCubit.load` but **never `previewLocation()`**:
Home must not provoke a location prompt. `load` is idempotent, so opening
Attendance afterwards reuses the subscription. ⚠️ **Cost:** two Firestore
listeners (history + corrections) now run whenever an employee's Home is open.

Zero columns are gone from the strip — `0 To do · 0 Active` spent half of it
saying nothing; with no open work the two collapse to *"Nothing to do"* and
return as figures the moment work exists.

Two bugs found while wiring it:

- `_Today.from` originally destructured the loaded state **positionally** — 17
  fields, silently re-bound if anyone inserts one. Switched to `maybeMap`.
- An attendance **stream error** left the card shimmering its skeleton forever —
  an animation running permanently on a resting surface, claiming data was
  coming when it was not. `error` now resolves to *"Shift unavailable"*. The
  same fault is what made two Employee Home widget tests hang on
  `pumpAndSettle`; their fake cubit now starts `loaded`, as reality does.

Verified on an iPhone 17 simulator against a throwaway preview of all five
states before any production file was touched — the owner asked for the preview
explicitly and an HTML mock was not accepted in its place. `_SummaryPill`,
`_ShiftBlock` and `_AllDoneCard` deleted; `AppDateFormatter` gained
`hoursMinutes`.

## 2026-08-01 — Task proof: a camera capture could be dropped in silence (bug; MED risk)

Owner report: taking a photo to complete a task adds nothing — choosing from
the gallery works, the camera doesn't, **on a real iPhone, with no error shown**.

`AttachmentPickerField._takePhoto` had **two `if (!context.mounted) return;`
guards placed after the capture**: one after `pickImage`, one after the cropper.
Either one firing threw away a photo the user had already taken, with no
message and no log — indistinguishable from the camera doing nothing. The
gallery path has only the first guard and no cropper at all, which is exactly
why it survived.

The guards were there to satisfy `use_build_context_synchronously`, but they
were guarding the wrong thing: **committing a pick needs `onChanged`, which the
parent owns — not this widget's context.** `_commit` is now free of
`BuildContext` and returns the rejection reason instead of showing it; each
caller shows that reason behind its own `mounted` check. A pick can no longer
be lost because the tree underneath the picker was rebuilt while the native
camera was in front.

Two more silent failures in the same file:

- **`catch (_)` swallowed every exception** on all three pick paths. They now
  log the real error (`AppLog.error`) and map `image_picker`'s actionable
  `PlatformException` codes to something a user can act on —
  `camera_access_denied` → *"Camera access is off. Enable it for DROP in
  Settings."*, `no_available_camera` → *"No camera on this device."* — instead
  of a flat "Could not take a photo."
- **`_rejectReason` called `file.length()` unguarded**, so one unreadable pick
  (a reclaimed temp, a bad path back from the cropper) threw and took the whole
  batch down. It is now reported as a normal rejection.

⚠️ **Not reproduced on the reporting device.** The two dropped-capture paths are
real and fit the symptom exactly (silent, camera-only, gallery unaffected), but
the failure has not been observed first-hand — the iOS Simulator has no camera,
so this cannot be verified from here. If it recurs, the console now names the
cause under the `attachments` scope. The build is unverified on a physical
device.

Owner report: the Notification Center *"looks bad and messy"*, and navigation
from it needed fixing.

### Second pass — the subject leads the row

First pass removed the duplicated pill but left the deeper fault, which the
owner named immediately: *"all the tasks look the same."* They did, and the
reason is in the producers. **Every one of them — `NotifyTaskEvent` and the six
`functions/index.js` sites alike — writes the event type into `title` ("New Task
Assigned") and the thing it is about into `body` ("Fridge check • Due 2:59
PM").** Rendering `title` as the headline therefore made the loudest line on
every card the one line *guaranteed to repeat*; the only text that told three
assigned tasks apart sat in 12px grey beneath it. Apple's own list guidance is
the inverse — the subtitle exists *to distinguish rows from one another*.

So the row is inverted:

```
NEW TASK ASSIGNED                    41m ●     ← kicker: 10px uppercase, semantic tint
Restock the front cooler                        ← subject: 14.5px, ONE line, never wraps
Due today 2:59 PM                               ← context: 12px, grey ramp
```

Nothing is discarded and **no stored data changes** — `title` is a pure function
of `type` in every producer, so it was always a label and is now set as one. The
kicker also carries the semantic accent, which is how the deleted category
pill's *meaning* returns at a quarter of its weight.

The subject holds **one line**. A wrapping headline gave every card a different
height and the column read ragged, so the trailing context is split off into its
own quieter line: new pure `splitNotificationBody` in `notification_format.dart`
cuts on the first ` • ` or ` — ` (the separators every producer already uses),
falling back to "all subject" when there is none — 7 cases in
`notification_grouping_test.dart`. The one exception is a row with **nowhere to
go**: it is not a pointer to the message, it *is* the message, so it is set as
reading text (lighter, looser, up to 5 lines) instead of a headline that happens
to be long.

Client task copy was fixed to match: `taskApproved` said only *"Task approved"*
and `taskRejected` / `taskRework` said only the reason, so those rows named
nothing at all. Every branch of `_bodyFor` now leads with `task.title`.
**Client-side only — no deploy.** (The server producers already name their
subject; they were left alone.)

### First pass — the duplicated pill

**The mess was duplicated information.** Every row spent three stacked lines on
three words: a tinted glyph, a title, a body, and then a coloured category pill
on its own line — a pill reading "Task" beneath a title already reading "New
Task Assigned", and the loudest element on the card. The filter pills own
category and the glyph owns type, so the pill is gone; the age moved from the
bottom-left meta row into the **right corner of the title line**, where an inbox
is read. Rows came down ~40% in height (eight fit an iPhone screen where six
did), and nothing that carried meaning was dropped.

**Read/unread is now carried by brightness, not a lone 8px dot.** An unread row
wears an accent-tinted glyph, a white title and a live dot; a read row goes
quiet — flat glyph, grey title, no elevation. The list ranks itself before a
word is read. A **critical unread** item (overdue · emergency · a swap awaiting
approval) additionally carries the standard `AppGlassCard` semantic halo, and
loses it once seen — emphasis marks the unseen, never the status forever
([[feedback_task_card_hairline]]'s standing rule).

Also: day headers became a labelled hairline carrying that day's unread count
(`TODAY ──── 3 new`); the filter rail is masked at both ends so it fades instead
of being sliced mid-word at the screen edge (the single thing that most made the
bar read as broken); each pill carries its unread count, so *Requests 4* is
visible without opening the filter; and the swipe-reveal radius was corrected to
`AppRadius.cardAll` (20, not 16) so it lines up with the card sliding over it.

**The navigation bug — `route: "attendance"` was a dead tap.**
`writeAttendanceNotifications` in `functions/index.js` has always stamped it,
but `resolveNotificationRoute` had no case for it, so every correction-filed /
approved / rejected and every auto-closed-session notification fell through to
`default → null`: tapping did nothing, in the inbox and on an FCM tap alike. It
now opens the exact record (`/attendance/record/:id` — all four producers stamp
`recordId`), falling back to `/attendance/review` for a reviewer and
`/attendance/history` for an employee. Four cases added to
`test/notification_deep_link_test.dart`.

**The in-app tap is fixed by the app build.** The *push* tap needed the other
half — `onNotificationCreated` was also dropping `recordId` / `correctionId`
from the push `data`, so a background/cold-start tap had no id to resolve. Both
are now forwarded — ✅ **deployed 2026-08-02**, so a background/cold-start
attendance tap now reaches the exact record instead of the ledger fallback.
Functions tests: 68 pass.

The tile now also *tells the truth about* a tap that can't go anywhere: the
screen resolves each notification through the same resolver and passes
`navigable`, and a notification with no destination (an employee's broadcast)
shows its body in full rather than clamping it to two lines behind a dead tap.

`AppDateFormatter.relativeShort` was added alongside `relative` (`now · 5m ·
3h · 2d · 6 Jul`) — the corner slot implies "ago", and the shorter string keeps
the title from being squeezed on a narrow phone.

Verified on an iPhone 17 simulator against the real screen over fakes.

## 2026-08-01 — Shift task streams bind from cache, not a round trip (bug; MED risk)

An employee's shift tasks — and therefore the Late and Missed counts that
include them — appeared roughly a second after the rest of My Tasks. Not a cache
miss and not a duplicate request: a **sequential dependency**. A shift task
carries no `assigneeIds`, so it arrives only via `watchShiftTasks`, and that
stream could not be opened until an **awaited** server read of the weekly
schedule said which shift the employee was on today.

The roster is now read cache-first (`ScheduleRepository.getScheduleCacheFirst`,
a new method — `getSchedule` is unchanged, and anything that *displays* or edits
the roster must keep using it), so the streams bind in the same frame.

The obvious version of this is a trap: a plain cache-first read pins whatever
roster is on disk, so an employee moved to another shift would silently stop
seeing shift tasks for the whole session. So the authoritative server read still
runs — **unawaited**, behind the fast path — and re-binds the shift sources only
when today's roster actually differs. Fast path never more than one round trip
stale; no stream churn in the common case where the cache was right.

`TaskCubit._subs` became a map keyed by source, so shift sources can be
re-bound without disturbing the assignee stream, and `_cancelSubsWhere` drops a
cancelled source's last snapshot so `_updateSource`'s merge cannot resurrect its
tasks.

Tests: +7 (`task_shift_stream_binding_test.dart` — binding proved against a
server read that *never completes*, re-bind on a changed roster, no churn on an
unchanged one, stale-source tasks dropped, and the no-branch / read-failure
degradations). The `ScheduleRepository` fakes in three existing task tests now
implement the cache-first read too — left to `noSuchMethod` they threw, which
silently routed every test onto the slow path and left the new one uncovered.

## 2026-08-01 — Late and Missed each get their own tab in My Tasks (polish; LOW risk)

Owner ruling: *"add missed tasks on their own like Done and Active — and Late the
same. I don't want it all together."*

The employee task screen went from two segments to four — **Active · Late ·
Missed · Done**. Late was a pinned section at the top of Active; Missed was a
pinned section at the top of Done. Both are now tabs, so each of the four
readings is one tap and nothing else is stacked on top of it. The two words keep
the meanings [TASKS.md](docs/design/TASKS.md) already defines: **Late** is *open*
work past its deadline (still actionable), **Missed** is the server's terminal
verdict on work that closed unfinished. Done is now Approved + Cancelled.

What a tab costs is visibility, so two things pay it back:

- `SegmentedTabBar` gained an optional `counts` — Late and Missed carry their
  number on the segment itself (dimmed, inheriting the tab colour, drawn only
  when non-zero). Active/Done stay plain words; the overview card above already
  summarises them.
- The all-clear state has **two readings**. An empty Active list means "caught
  up" only when nothing is late; with late work waiting it reads *"Nothing new —
  but you are behind"* over a button to that tab. Claiming "You're all caught up"
  beside overdue work was the one real regression the split could have shipped.

Tab membership is now three tested top-level predicates (`lateTasks` ·
`missedTasks` · `finishedTasks`) instead of filters inlined in two widgets, and
`_groupByRecency` / `_taskGrid` are shared rather than duplicated per tab.

Tests: +17 (`my_tasks_tabs_test.dart` pins the partition — including that no task
appears in two tabs, that Cancelled is never absorbed into Missed, and that Late
never reads a closed task — plus `allClearCopy`, extracted pure precisely so the
"you are behind" wording is testable without live overdue data;
`segmented_tab_bar_test.dart` covers zero-count suppression and four counted
segments on a 320pt phone).

Also by owner ruling: the **"3m late" line on a completed card is now amber**
(`AppColors.warning`) instead of tertiary grey — it was too quiet to register
next to a green *Completed*. It remains a timeliness signal and deliberately
does **not** take the error red that Missed wears; ADR-013 never fixed a colour
for it (the grey was a code-comment convention), so nothing there is reversed.
Changed on the employee card only — the manager task card and Task Details still
render lateness as a neutral meta chip.

Verified on the simulator: all four tabs, the count on the Missed segment
(legible both selected and unselected), Done no longer carrying a Missed
section, and the amber lateness line.

## 2026-08-01 — Employee Home stat strip: one surface, not four boxes (polish; LOW risk)

Owner: *"more premium, and decrease the size a little bit."*

**To do · Active · In review · Done** was four bordered cards sitting side by
side, each with icon-over-number-over-label. Four boxes in a row read as a
dashboard; it is one glance, so it is now **one surface with hairline dividers**
— the Design System V2 fact-row language already used by core `StatStrip`
(not reused directly: that primitive carries no icons and no per-cell
highlight, and its type is larger, not smaller).

Height drops ~20% (≈81pt → ≈65pt): three rows became two, with the icon moved
down beside its label so the **number leads**, which is what the eye is there
for.

The live-cell highlight moved from a tinted card to the **grey ramp** — number
to white, label and icon up one step. Inside a shared surface a per-cell tint
patches the row; hierarchy says the same thing more quietly (ADR-004 holds —
still strictly monochrome).

Verified on the simulator with a live highlighted cell (1 To do).

---

## 2026-08-01 — Checklist Templates become a real screen (polish + feature; MED risk)

Owner on the New Checklist Template form: *"too old, make it more detailed, not
a bottom sheet, make it premium, change the icon."*

It was a **sheet opened from inside another sheet** (`_TemplateForm` via
`showSheet` from `_ManageTemplatesState._add`). Both it and `_ManageTemplates`
now push `CupertinoPageRoute(fullscreenDialog: true)` — the same presentation
the task form already used (`task_action_sheets.dart:78`), so the two creation
flows finally match. Public entry points (`showManageTemplatesSheet`, the
`_add` flow popping `true`) kept their names and signatures, so every call site
is unchanged.

The "old" feel was literal: `_SimpleDropdown` was called with
`labelOf: (t) => t.value`, and `value` returns the enum's `name` — so the form
displayed the raw Firestore strings `daily` and `normal`, lowercase.
`TaskType`/`TaskPriority` gained an **additive `label` getter**; `value` is the
persisted wire string and was not touched.

Also: checklist steps are drag-reorderable (order *is* the procedure), the
unlabelled required-star became a legible **Required / Optional** control, and
the Templates icon is one shared `kTemplatesIcon`
(`Icons.checklist_rounded` — the old `dashboard_customize_outlined` read as
"customize dashboard") used everywhere Templates appears.

`_save` is byte-for-byte unchanged, and now has tests pinning it: title
required, blank steps dropped, and `branchId: isAdmin ? '' : defaultBranchId`
— where `''` is the persisted "global, every branch" value.

**Bug found and fixed on the way:** `_ManageTemplatesState._reload` was
`setState(() => _future = _load())`. Arrow syntax returns the assignment's
value — a `Future` — and `setState` asserts on that. Asserts are stripped in
release, so this only ever bit **debug** builds, on every template create and
delete. Pre-existing (byte-identical to the previous revision); it survived
because nothing tested that path until now.

---

## 2026-08-01 — The Admin Dashboard "Today" strip stops lying by omission (polish + bug-fix; MED risk)

Owner used the dashboard on real data and asked "why is active 0 when there IS
a task?". The number was correct — `Running now` counts `started` only, and
the task in question was `pending`, never started — but the strip had **no
number for outstanding work at all**, so `Running now` got read as that number
by default. Added `Open` (pending/started/completed/rejected — the same
definition Task Management's "Active" uses, so the two screens agree) and put
it first, in the slot `Approval rate` freed.

Second finding: `Delayed` (dashboard), `Late` (Task Management), and
`Late tasks` (Operations) are the exact same `isTaskOverdue` predicate wearing
three names and two colours (amber here, red everywhere else). Renamed to
`Late`, recoloured to `AppColors.error`. Grepped the rest of the app for
"Delayed" task copy — this was the only one.

Third: `Approval rate` is gone, and it wasn't just decluttering — it was a
second, disagreeing completion formula (`Approved ÷ (Approved + Rejected)`,
from a separate `StatisticsCubit` aggregate) sitting next to Task
Management's `Approved ÷ (Approved + Missed)` (§10.1). Removing it leaves one
completion figure in the product. `_today()` no longer subscribes to
`StatisticsCubit` at all as a result — `Completed today` is now derived from
the task stream (`completedTodayCount`, `task_metrics.dart`, built on the same
`isTaskInActiveWindow` `applyFeed` uses) instead of the lifetime-scoped
`StatisticsCubit.completedTasksToday`, so the stat and its drill-down list can
never disagree.

Every cell except `Due soon` is now a real tap target into
`FilteredTasksScreen`, each with a one-line "how does this count" description.
`Due soon` stays deliberately inert: no `TaskFeedFilter` can reproduce
`schedulePhase`'s dueSoon precedence (it excludes `completed`/`waitingReview`
even though the active window includes them) without either an over-counting
filter or a reverse dependency from `task_feed.dart` into `task_schedule.dart`
— a cell that doesn't open beats one whose count and list could disagree.

`manager_home_screen.dart` reads the same `StatisticsCubit.completedTasksToday`
for its own "Completed today" tile, but it isn't tappable there, so it carries
no count-vs-list risk today. Left unchanged — out of scope for this pass.

---

## 2026-08-01 — Task card outcome legibility, a redesigned preview sheet, and self-explaining stats (polish + feature; MED risk)

Follow-up from the owner using the previous change on real data. Three findings:

1. **The card's "by X" named the wrong person.** `TaskCard`'s footer showed the
   task's *creator* even on a decided card, so "Approved" next to "by Admin"
   read as "Admin approved this" — the wrong person answering a question
   nobody asked. It now names the **decider** once a task is decided
   (`Approved by <name>` / `Rejected by <name>` / `Cancelled by <name>`, via
   the new shared `resolveDeciderName` in `activity_format.dart`, reused by
   both the card and the new preview sheet so the two surfaces can't drift).
   `Missed` has no decider — an automated sweep closed it — so it says
   `Missed — closed automatically` and never falls back to the creator, on
   purpose (that fallback was the exact bug). Undecided statuses are
   byte-for-byte unchanged. A finished-late task's timeliness note moved from
   a buried chip up next to the status pill (`_LatenessNote`, always neutral
   grey — Late stays a timeliness signal, never pass/fail, per §10.4; never
   the Missed/error red). The reference-attachment count chip was cut: it told
   you material existed but gave you nothing to act on from the card itself.

2. **The preview sheet read like a debug dump.** `showTaskPreviewSheet` used
   to stack `TaskFeedRow` + `TaskFeedExpansion` — a dense monitoring row, then
   a flat label/value grid. Rebuilt **locally** in `task_preview_sheet.dart`
   (that pair is shared with the dashboard's live feed accordion and stays
   untouched): a plain-language **situation sentence first** (state +
   consequence — `Approved by Ziad · 1m late`, `Missed · deadline passed 21h
   ago, closed automatically`), a 3-row facts card (branch+shift merged,
   due+lateness merged, assignee), a one-line checklist summary, and a
   hierarchy-first timeline (an emphasised head row for the newest event, a
   muted ledger below, capped at 4 rows + a Full-Details pointer). The sticky
   footer (`TaskFeedActions`) — approve/reject/reassign/note/open-full-details
   — is unchanged; this is a presentation rebuild, not a new action path.

3. **"How does Late count?" was a fair question nobody could answer from the
   UI.** Verified against the code (not assumed): Late = active work only
   (`pending`/`started`/`rejected`) past its deadline, with **no time
   window** — a task three weeks overdue still counts, every day, until it's
   closed; once finished it drops out of Late entirely and becomes a
   "finished late" note on the task itself. `_BranchMetrics._overdue`
   (admin overview), `isTaskOverdue` (`task_feed.dart`) and
   `isOperationalOverdueTask` (`branch_workload.dart`) were checked side by
   side and agree exactly — no predicate drift found. `FilteredTasksScreen`
   gained an optional `description` (same slot `OperationsMetricScreen`
   already uses) so every stat-row drill-down states, in one line, what it
   counts and why — Late's line names the "no window, until closed" rule
   explicitly.

---

## 2026-08-01 — Admin Task Management: a tappable stat row instead of two tabs (feature + polish; MED risk)

Owner request: "I want to click on missed to see all missed tasks" — and one
row can carry Active/In review/Late/Missed/Cancelled/Done without a segmented
`Active | Done` toggle that only relabelled the same branch grid.
`admin_task_overview_screen.dart` drops the tabs, the `_TaskLens` split, and the
wordy `_OutcomeBreakdown` panel; every task-typed cell in the stat row is now a
real tap target into `FilteredTasksScreen` with exactly those tasks. The branch
grid keeps only its former "Active" framing (Active / Pending review / Late +
the completion caption).

**The trap this was built to avoid:** `FilteredTasksScreen` runs its filter
through `applyFeed`, whose first line drops anything `isTaskInActiveWindow`
excludes — Missed, Cancelled, and any task approved before today. A naive
`status: missed` filter would have rendered an empty "All clear" page.
`TaskFeedFilter` gained `activeWindowOnly` (default `true`, so every existing
caller — the dashboard's Needs-Attention tiles, `task_feed_test.dart` — is
byte-identical) and the Missed/Cancelled/Done stats set it `false`. Also added
a `statuses` set (composes AND with the single `status` field) so "Active" can
mean four statuses without adding a `FeedPreset` case (which would have grown
the dashboard's chip row for free). `FeedPreset` itself is untouched.

Cancelled still hides at zero, still never wears Missed's error-red, and
nothing sums the two — the §8 hard invariant the deleted panel used to enforce
is now enforced in the row instead. `StatStrip`'s `Stat` gained an optional
`onTap` (press/hover + a `Semantics` button label); every other `StatStrip`
caller is unaffected. `FilteredTasksScreen` gained an `emptyTitle` override
(so an empty Missed page reads "No missed tasks", not "All clear") and a quiet
task-count line. `TaskActivityCard` gained an opt-in `showDeadline` flag, on
only for these drill-downs — the dashboard's Recent Activity feed is unchanged.

---

## 2026-07-31 — Daily review: settle yesterday before it becomes a weekly surprise (feature; HIGH risk)

Phase 2 of [ATTENDANCE_PRODUCT_REDESIGN_PLAN.md](docs/design/ATTENDANCE_PRODUCT_REDESIGN_PLAN.md)
— the layer whose absence is why the weekly report was trying to be three
products at once.

New `/attendance/daily/:branchId/:dayKey`, reachable from a day row on the weekly
report. Three zones: **Needs you** (the only zone with verbs, ordered by cost of
being wrong — an unknown clock-out outranks a no-show because unknown hours are a
payroll problem), **The day** (one line, counts not percentages), **Everyone**
(collapsed). A clean day renders one line and nothing else; that is the common
case and it should be the fastest to read.

Rows name a person and state a fact — "Sara didn't clock out" — never a record
id, a severity label, or an exception code. Priority is expressed by order.

**A real bug fixed on the way.** Every manager write (`addRecord`,
`resolveDirectly`, `excuseAbsence`) resolved its document id from `_today()` at
*action* time. A board left open across midnight, or any review of a past day,
would write against the wrong date — on data that feeds pay. The business date is
now pinned when the board is scoped; the live board is unchanged and both halves
are tested.

The three write helpers moved out of the admin board into
`attendance_manager_actions.dart` so both surfaces share one path — two copies of
a pay-affecting write is how they drift. No decision semantics changed:
validation, the approved-correction apply path, and no-self-approval are all
still the cubit's.

**Partial by design.** Three of the six exception kinds are built (missing
clock-in, missing clock-out, no-show) — the ones that stop a week settling.
Pending corrections already have a working queue; overtime review needs a
threshold nobody has set; unscheduled work does not exist until §11 D1 is
decided. The daily notification is server-side and waits on the standing
functions deploy; 48-hour escalation belongs to Phase 3's Admin Workspace.

**The actions no longer report success they cannot see.** A manager write
creates an approved correction; a Cloud Function applies it and stamps
`resolvedAt`. Undeployed, the record never moves — yet the UI said "Absence
excused.", telling a manager a shift was settled while the person was still
absent. Pre-existing on the live board; Daily Review would have made it a daily
occurrence. The three actions now return `AttendanceWriteOutcome` and the cubit
confirms by re-reading the record for a **new** `resolvedAt`. Unconfirmed reads
"Saved, but not applied yet — nothing is lost", which is deliberately not an
error: the correction is durable and applies on deploy.

Verified: analyze clean, **1289 pass / 2 pre-existing splash failures**, +15
tests.

## 2026-08-01 — The weekly PDF, and payroll leaves the UI too

Completes Phase 4 under [ADR-019](docs/decisions/ADR-019-operational-exports-and-week-review.md).

**One new dependency, `pdf`.** `printing` was deliberately not added: it brings
platform plugin code for a print dialog nobody asked for, when the file can be
written beside the Schedule PNG export and opened with `open_filex` — exactly
what the chat document service already does for downloads.

The document carries **the same five sections in the same order as the screen**.
A PDF with its own information architecture would be a second one to keep in
sync, and that order was argued for once already. It renders coverage *and*
review in the header as two facts, never merged into one verdict — the rule the
whole redesign turns on. Show-up rate is absent for the same reason it left the
screen.

⚠️ **On mobile, opening matters more than saving.** `getDownloadsDirectory()` is
desktop-only, so on a phone both exports would land in the app sandbox where
nobody could find them. Mobile now hands the file to the system viewer so it can
actually be sent on; desktop skips that, having written to Downloads.

**Payroll is now gone from the UI as well as the backend** — `payrollCsv`, the
`notLocked` and `notDeployed` blocks, the `isLocked` and `serverReady` gate
parameters, and the admin workspace's Payroll hand-off section. The gate is down
to one rule worth keeping: an unsettled week must not be shared as though it were
final, because a document outlives the screen that qualified it.

Tested structurally rather than by string-matching a compressed binary: valid
`%PDF-` header, `%%EOF` tail, and a populated week producing a larger file than
an empty one. Empty weeks, blocked weeks and a name that would break a CSV all
render without failing.

Verified: **1335 pass / 2 pre-existing**, analyze clean, build succeeds.

## 2026-08-01 — Exports become operational documents; a week is reviewed, not locked

[ADR-019](docs/decisions/ADR-019-operational-exports-and-week-review.md), after
the owner retired the premise Phase 4 was built on: **DROP is an operations
management system, not a payroll system, and payroll integration is not
planned.**

The reasoning collapsed in sequence. No machine ingests a file, so there is no
machine schema to satisfy; nothing downstream consumes a figure, so nothing needs
freezing; the artifact is not financial, so it needs no audit chain; and with no
audit chain, server generation buys nothing a client cannot do. **Phase 4's
deploy dependency disappeared with it.**

**The timesheet CSV replaces the payroll CSV — a different artifact, not a
trimmed one.** Payroll wanted `2026-07-29T05:30:00.000Z` and `487`, because a
machine rounds for itself. A manager wants `29 Jul`, `08:37`, `7h 52m`. Eleven
columns instead of thirty-seven, generated on the client and written beside the
Schedule PNG export.

**Week review kept, as an assertion rather than a lock.** The first plan removed
the whole notion of finishing a week; the owner pushed back, correctly — closing
and locking had been treated as one thing. A manager can now mark a branch-week
reviewed, recording who and when, reversible by Reopen. Nothing is restricted:
the rules carry no `locked` field by design.

It is deliberately **orthogonal** to the derived coverage status and rendered
apart from it. Coverage answers *is the record complete?*; review answers *has a
person signed off?* — which cannot be computed, because a week can be Settled and
never opened by anyone. Merging them is how "Fully closed" once appeared over a
week that was 86% empty. Post-review changes are **derived** from timestamps, so
"later changes are intentional and visible" needs no history collection at all.

**Deleted:** the payroll CSV and its 18 node tests (functions 86 → 68), period
lock, the export ledger, restatement versioning, and `AttendancePeriodStatus`,
which never had a reader in `lib/`. IA §12.6 retired.

Also fixed on the way: the review widget reached straight into a `late final` DI
singleton, which crashed it under test. It is now injectable like the screen's
cubit — a widget that cannot be pumped is a design problem, not a test problem.

Rules deployed. Firestore rules **47 pass** (was 37), Dart **1330 pass / 2
pre-existing**, functions **68 pass**, build succeeds.

Still open: the weekly PDF, the one export that adds dependencies.

## 2026-07-31 — Deployed to production, and found the backlog was mostly a myth

Deployed to `bazic-d9ad7` (the only project — there is no staging): Firestore
indexes, all 24 Cloud Functions, Firestore rules, Storage rules.

**Only the functions actually changed.** Firestore rules, Storage rules and the
indexes all reported *"already up to date"*. The standing "rules have never been
deployed" item — the supposedly-missing `shift_templates` rule, the task
`startsAt` enforcement, `storage.rules` `validMedia()` — was **stale in our own
docs**. All of it was already live. What genuinely lagged was the deployed
*function source*, and every one of the 24 was running older code.

Closing that activates the automation business-day fix (ADR-015), the widened
`closeAttendanceExpectations` sweep, the task Missed/Cancelled server paths, and
`onAttendanceCorrectionWritten` — so a manager's Resolve / Add record / Excuse
should now report **applied** instead of *saved, not applied yet*.

Gates run before deploying: Firestore rules 37/37 on the emulator against the
repo's own rules file, Cloud Functions 86/86, Dart 1312 pass / 2 pre-existing.

⚠️ Not verified at runtime: `firebase functions:log` returned "Failed to retrieve
log entries" for this login, so the deploy's own success reports are the only
confirmation. First real proof is the next 01:00 Cairo close run and the next
manager correction.

## 2026-07-31 — The payroll file, and an honest reason it cannot be sent yet (feature; MED risk)

Phase 4 of the attendance redesign plan, partially — and the part that is missing
is missing for a reason worth stating.

ADR-005 and ADR-017 make a payroll artifact server-authored: a file the client
assembled cannot be audited, because nothing outside the client saw the inputs.
So the file has to come from a Cloud Function writing to Storage with an export
ledger beside it, and none of that is verifiable without the deploy that has been
the standing blocker throughout. Shipping it unverified on top of a backlog that
already has 2 of 23 functions missing in production would add risk, not value.

**What landed instead is the part that must be correct.**
`functions/attendance_export.js` builds the payroll CSV: the 37-column §12.6
schema in contract order, RFC4180 escaping, and **whole unrounded minutes**,
because payroll owns 5/10/15-minute rounding and rounding twice is how two
systems come to disagree about a person's pay. It is Firebase-free like
`attendance_auto_close.js`, so 18 `node --test` cases cover it without an
emulator or a deploy — including that an employee named `Amal, "A"` does not
silently shift every later column by one.

`AttendanceExportGate` mirrors the rule in Dart so the UI can be honest; the
server remains the authority. Manager *Share this week* and the new admin
**Payroll hand-off** now say why they are unavailable instead of "coming next",
and payroll stays admin-only, lock-gated, and nowhere near the manager's PDF
button.

⚠️ Before deploying: the CSV names GPS columns and `correction_ids` that the
close Function does not currently materialize, so they export empty. Either it
starts writing them or the schema drops them — an empty column that looks like a
value is worse than no column.

Verified: build succeeds, analyze clean, **1312 pass / 2 pre-existing splash
failures**, Cloud Functions **86 pass**.

## 2026-07-31 — Give the audit trail its own room (feature; MED risk)

Phase 3 of the attendance redesign plan. Operational UX and audit UX are opposite
design targets — one optimises for speed and ruthless incompleteness, the other
for completeness and permanence — and a single screen serving both serves
neither. That was the original weekly report's defect. This is the other half.

New admin-only `/admin/attendance/workspace`, covered by the existing
`_isAdminArea` guard and reachable from an admin-only tile on the reports hub.
Four sections: **Needs chasing** (branches whose oldest blocker is two days old
or more) · **Data completeness** (per-branch days covered, worst first — the
signal that used to be the loudest thing on a store manager's screen) · **Across
branches** (the pooled rollup) · **Evidence** (the row-level table, relocated
from Weekly intact, per-record link and all).

**Show-up rate now has a home again.** Phase 1 removed it from the store surface
because at one expected shift `0%` is meaningless and alarming. Pooled across
every branch there is volume for a percentage to mean something, and comparing
branches is a question only an admin has.

`AdminAttendanceOverview` folds one weekly report per branch plus one summary
over the union of rows, so the cross-branch rate cannot drift from the per-branch
ones. The cubit fans out one branch stream per branch and merges — no
collection-wide query, **no new index**. A branch with zero rows is seeded
explicitly, because "this branch reported nothing" is the point and a missing key
would render as a missing branch. All four new files join the reporting source
guard.

Deferred honestly: locks, restatement history and the export ledger do not exist
yet, so there was nothing to relocate — they come with Phase 4. GPS detail stays
on the admin live board, which is already an admin surface.

Verified: build succeeds, analyze clean, **1304 pass / 2 pre-existing splash
failures**, +7 tests.

## 2026-07-31 — An employee may always record real work (feature; MED risk)

The two open product decisions, decided and recorded.

**Overtime threshold: there is none.** Confirming overtime in DROP changes no
record, no payment and no export — ADR-017 keeps pay out of scope and R17
already says overtime is never fed anywhere — so an approval step fails ADR-017's
own metric bar. The queue exists for shifts whose record is *wrong or missing*;
an overtime row is complete and correct. Overtime is the most common
non-standard outcome in retail, so making it an exception would have been the
fastest way to flood a surface designed to stay at zero to three items. Struck
from the plan, which proposed it in its first draft. Reverses the day a payroll
export carries overtime hours.

**Unscheduled clock-in: allowed** ([ADR-018](docs/decisions/ADR-018-unscheduled-clock-in.md),
amending `ATTENDANCE_SPEC` §9, whose own wording — "no unscheduled by default" —
was a deferral, not a ruling). `allowUnscheduledClockIn` defaults true; the flag
stays for a branch that wants the stricter behaviour.

The deciding argument was evidence quality, not convenience. Today's workaround
is manager *Add record* — times typed from memory, no location proof. An
unscheduled clock-in is server-timestamped and GPS-verified at the moment of
presence, so the permissive path produces strictly better evidence than the one
it replaces.

Capture is permissive; counting is not. Deliberate secondary action on the
no-shift state, mandatory reason, full GPS gate, and it counts in **nothing**
until a manager approves it in Daily Review — `isUnscheduledWork` already
excluded it from every reporting aggregate, and that exclusion is now guarded.

⚠️ `computeAttendanceBoard` now appends records with no roster slot. It walks the
roster, so without that pass the punch existed in Firestore and was invisible on
every manager surface. Also: geofence resolution moved ahead of the schedule
lookup, so an unpublished week no longer blocks the GPS gate for the wrong
reason.

Verified: build succeeds, analyze clean, **1297 pass / 2 pre-existing splash
failures**, +10 tests.

## 2026-07-31 — Weekly attendance answers a manager's four questions (feature; MED risk)

Phase 1 of [ATTENDANCE_PRODUCT_REDESIGN_PLAN.md](docs/design/ATTENDANCE_PRODUCT_REDESIGN_PLAN.md).

**The spec changed first, on purpose.** `ATTENDANCE_REPORTS_IA` §6.4–§6.10 are
replaced in full, because the shipped eight sections were a faithful build of
§6.4 and would have regenerated from it. §6.1–§6.3 and ADR-017 are unchanged.

Weekly now renders five sections instead of eight: **Needs your attention**
(only when something blocks — the page's only verb, absent in a healthy week),
**The week in one line** (`42 of 45 shifts worked · 312h · 4h overtime` — counts,
never a store-level percentage), **By person**, **By day**, **Share this week**.

Four KPIs replace six: Hours worked · Overtime · Unexcused absences · Late
arrivals as a **count**. Show-up rate and punctual arrivals leave the store
surface — at one expected shift a percentage is the least reliable and most
alarming number on the page; both survive on the hub headline, where volume
exists. New `AttendanceWeeklyKpis` is owned by Weekly, so Monthly's
`AttendanceReportMetrics` grid is untouched.

**Person rows are ordered exceptions-first** (`AttendanceAttentionBand`:
needs-decision → absent → late → clean, alphabetical inside each band), with a
Status column. This reverses the old alphabetical rule and deletes its
disclaimer. Ordering is not scoring — no weight, no composite, no rank — and
alphabetical order was never what prevented ranking; refusing to compute a score
is, and that refusal stands. All alphabetical order achieved was seating the one
person who did not show up several rows down.

The exception summary and shift evidence table leave the manager surface for
Daily Close/Exception Queue (Phase 2) and Admin Workspace (Phase 3). ⚠️ The
evidence table carried this screen's only per-record link; managers reach records
through `/attendance/review` until the per-employee report is built. Monthly is
deliberately untouched (§11 D2 defers it).

Verified: analyze clean, **1274 pass / 2 pre-existing splash failures**, +3 tests
including one pinning the ordering reversal. The ledger-only source guard is
still green — the roster is still not read here, which is why the report still
cannot tell "nobody was scheduled" from "scheduled but never captured".

## 2026-07-31 — Attendance reports speak to a manager (polish; LOW risk)

Phase 0 of [ATTENDANCE_PRODUCT_REDESIGN_PLAN.md](docs/design/ATTENDANCE_PRODUCT_REDESIGN_PLAN.md).
Presentation copy and state rendering only — no cubit, repository, rule, index,
or Function touched, and **no aggregate or denominator changed value**.

Internal vocabulary retired at the manager boundary: *ledger rows* → shifts,
*phantom row* → **No clock-in recorded**, *blocking / informational* → **Needs a
decision / Worth knowing**, *close readiness* → **Week status**, *export and
restatement* → **Share this week**. New `AttendanceLedgerOutcome.label` stops the
Outcome column printing wire values (`workedLate`, `noRecordYet`); `wireValue`
remains the persisted contract and is no longer rendered anywhere.

Two honesty fixes matter more than the wording. **A week with rows on one day of
seven no longer reads "Fully closed"** — new `AttendanceCoverageStatus` (No data
yet · Needs attention · In progress · Settled) is the single manager-facing
status for Weekly and Monthly. `isFullyClosed` is unchanged and still means what
the close pipeline means; it is simply not the manager's word. And **a day with
nothing recorded is no longer amber** — it renders quiet grey, because it is the
absence of a result, not a bad one. Only a day that was scheduled and worked by
nobody is toned error-red. This is what made a week where six of seven days had
no roster read as a catastrophic week.

Also: metric cards that cannot be computed no longer render `--`; empty exception
sections no longer render at all; the defensive captions are deleted.

**Not in this change** (Phases 1–3): section inventory, KPI selection,
exception-first sorting, and moving audit surfaces to an admin audience.

Verified: analyze clean, **1272 pass / 2 pre-existing splash failures**, +7 tests.

## 2026-07-31 — Attendance redesign PRD (docs only; no risk)

Added [ATTENDANCE_PRODUCT_REDESIGN_PLAN.md](docs/design/ATTENDANCE_PRODUCT_REDESIGN_PLAN.md),
a proposed PRD + roadmap for the Attendance presentation layer, after a real
store manager could not read the shipped Weekly Report.

The finding worth recording: the screen is a **faithful build of its own spec**
(`ATTENDANCE_REPORTS_IA` §6.4 specifies exactly those eight sections, §6.5 those
six KPIs), so screen-level fixes would regenerate it — the spec is the artefact
that must change. Second finding: the IA's build order was skipped from step 2 to
step 5, so Weekly is doing the job of the never-built Daily Close and Exception
Queue.

Proposes five phases, five sections replacing eight, four KPIs replacing six, a
new **Daily Review** surface, and relocation of ledger/audit/restatement to an
admin audience. **Presentation only** — ADR-017's ledger scope and metric bar and
every rule in `ATTENDANCE_SPEC.md` are explicitly out of scope. Documents three
deliberate reversals (show-up rate demoted, alphabetical sorting replaced by
exception-first, Monthly deferred) and eight open decisions for owner sign-off.

Nothing implemented; no code, rules, or functions touched.

## 2026-07-31 — Per-task lateness, rendered and findable (feature; LOW risk)

A finished task carried its lateness only as raw timestamps — visible in the
Approved-only aggregate on Admin's branch overview, invisible on the task
itself, and unrecoverable once submitted (the Operations "Late tasks" drill-down
only lists *active* overdue work, which drops to zero the moment the employee
finishes). The owner could tell a branch's completion rate but not point at
which finished tasks had been late.

This **implements** [ADR-013](docs/decisions/ADR-013-task-grace-period.md)'s
existing "lateness is measured, never stated" position — it does not reopen or
reverse it. No new `TaskStatus`, no schema/rules/Functions change; everything is
derived at read time from `submittedAt`/`approvedAt`/`deadline`, already on
every task document.

- `taskLateness(TaskEntity)` (`task_outcomes.dart`) — the one source: the
  positive overshoot past `deadline` for `completed`/`waitingReview`/`approved`
  tasks (submitted-not-yet-reviewed reads late immediately), null for
  `missed`/`cancelled`/on-time/no-deadline. `taskOutcomes()`'s Approved branch
  now calls it instead of re-deriving the same comparison, so the aggregate and
  the per-task signal can never drift apart; its counts are byte-identical to
  before (regression-tested).
- `formatLateness(Duration)` (`activity_format.dart`) — the one phrase (`45m
  late` / `3h 12m late` / `2d 4h late`), used by every call site below.
- Rendered as one quiet **secondary-grey** line (never `AppColors.error`, never
  worded as a failure) on: the task card (`task_card.dart`), the activity feed
  row (`task_activity_card.dart`), Task Details' status header, and the My
  Tasks **Done** tab outcome badge.
- `isOperationalFinishedLateTask(TaskEntity)` (`branch_workload.dart`, beside
  `isOperationalOverdueTask`) + a new **"Finished late"** section on the
  Operations "Late tasks" drill-down, below the existing "Past deadline" list,
  sorted most-late-first — the actual fix for "I can't find which tasks were
  late and still got done." The hero count and `_FactStrip` figures stay
  active-overdue only; the section renders nothing when empty (no zero panel),
  and the old "Nothing late" empty state now only shows when both lists are
  empty.

---

## 2026-07-31 — Attendance & Reports hub: information-architecture redesign (polish; LOW risk)

Owner-commissioned IA pass on `/attendance/reports` only. **Presentation-only** —
no cubit, state, domain, repository, route, rule, index, or function change, and
no threshold, rounding, or classification change.

The hub rendered a *multi-branch* design in a *single-branch* reality (the
`ATTENDANCE_REPORTS_IA` §13.5 wireframe was drawn for an estate view that does
not exist), so components built to compare branches always rendered one row.
~12 unique facts were rendered ~18 times across ~2.5 screens.

Five sections became four, in the order the page's question implies:

- **Header** — the duplicate `PageHero` title/eyebrow is gone; the chrome header
  already names the page. Only the question line survives, as the lead-in.
- **Scope & period** — `AttendanceReportScopeBar` keeps its exact function but is
  reframed as a control bar (no `GlassContainer`, closing hairline, quieter
  legends) so it stops competing with data.
- **The verdict** — `_NeedsAttention` and `AttendanceReportCoverage` merged into
  one card: a trust line (`Fully closed · 3 of 3 ledger rows closed`, or
  `Awaiting close · No ledger data`) and an action line. **Exceptions are
  reported by exception:** zero blockers cost one muted line, a real blocker
  earns weight, amber and the Exception-queue affordance.
- **The numbers** — show-up rate as the headline with its denominator inline,
  Expected · Present · Absent beneath it as its *components*, and punctual
  arrivals / worked time only when they have a real denominator (they used to
  show `--` over `0 / 0` at full tile weight).
- **Go deeper** — Weekly and Monthly as two real actions; the three unbuilt
  surfaces collapse to one muted line instead of three inert tiles.

**Removed:** `_BranchPeriodPreview` (the single-row "Branch periods" table),
which carried no information not already above it. A code comment records that a
branch-comparison table returns only if an "All branches" scope is added.

`AttendanceReportMetrics` is **untouched** — it is shared with the Weekly and
Monthly reports, which must stay visually unchanged, so the hub got its own
`AttendanceReportHeadline` instead of a new variant on the shared widget.

The owner's rule is unchanged and now has paired coverage: rows with zero
clock-ins are a real **0%** with its denominator disclosed; no rows at all is
**No ledger data**, never a zero-valued figure.

## 2026-07-31 — Attendance: absence rows show a name, not a uid (bug; LOW risk)

`attendance_expectations.userName` was copied from the attendance record, but a
phantom no-show has no record by definition — so every absence, the rows ADR-017
exists to surface, rendered a raw Firebase uid in the Weekly and Monthly reports.
The roster stores uids only, so nothing downstream could recover the name.

Fixed on both sides, because neither half is sufficient alone:

- **Server** — `closeAttendanceExpectations` resolves the closable slots' uids
  against `users/{uid}` (`displayName`, then `fullName`, matching the client
  model) and freezes the name onto the row at close. Required regardless, since
  ADR-017 puts CSV/PDF export in a Cloud Function and those artifacts need names.
  **Needs a functions deploy.**
- **Client** — `AttendanceReportCubit` resolves the branch directory through the
  existing `GetUsersByBranch`, so the rows already in production stop showing
  uids immediately without a backfill or a restatement. Best-effort: a directory
  failure leaves the uid fallback and logs, never breaking a report whose numbers
  are already right.

Precedence is ledger name → directory → uid. The frozen value wins because a
payroll artifact must reproduce the name as of close, not the name today. A
missing name stays null rather than becoming the uid, so a reader can tell "no
name known" from a person actually called that. The directory is a **label
only** — every denominator still comes from the ledger, and the ADR-017 source
guard is untouched.

## 2026-07-31 — Attendance: the Monthly Report (feature; LOW risk)

The second per-period reporting destination, `/attendance/reports/monthly/:periodId`,
under [ADR-017](docs/decisions/ADR-017-attendance-reporting-ledger.md) and the
decided IA §7. Ledger-exclusive like Weekly: one `attendance_expectations`
branch/dayKey range over the calendar month, served by the already-deployed
`(branchId, dayKey)` composite — **no new function, rule, or index**.

- **Monthly is not "Weekly with more days" (IA §7.1).** The month is partitioned
  into the Schedule weeks (Sunday→Saturday) that overlap it, and a week that only
  partly overlaps is marked **Partial** and never read as a full week.
- **Structured for the rollup swap.** Every aggregate is folded by the single
  row-scanning factory `MonthlyAttendanceReport.fromLedger` and handed to a
  private constructor that scans nothing, so the future rollup Function adds a
  `fromRollup(...)` factory additively with no UI change. Deliberately no
  interface or strategy seam with one implementation.
- **The owner's rule holds:** rows present with zero clock-ins render a real
  **0%**; a date or month with no rows renders **No ledger data** and no
  percentage. Both directions are asserted in the widget tests.
- **Two Africa/Cairo DST defects found and fixed** — a month is the first surface
  that walks every date and groups by week, so `Duration`-based week math became
  visible here for the first time. Clocks back (Thu 29 Oct 2026) resolved one
  Schedule week to both `00:00` and `01:00`, splitting it into a phantom sixth
  bucket; clocks forward (Fri 24 Apr 2026, when `00:00` does not exist) landed on
  `Apr 18 23:00`, forking a sixth bucket out of a five-week month and counting 37
  days in a 30-day month. Week grouping is now pure calendar arithmetic and the
  covered-day count is measured in UTC. Both months are locked in as regression
  tests. Shared `ScheduleWeek.startOf` is untouched — repairing it is wider than
  this report.
- **Two latent overflow bugs fixed** in shared widgets that only a long label
  exposed: the metric card's label and `PremiumButton`'s label now ellipsize
  instead of painting overflow stripes at a 390pt viewport.
- Month-over-month comparison, the restatement log, per-employee drill-down, and
  export stay deferred and render as disabled affordances.

## 2026-07-30 — Chat: the five audited defects fixed (bug; LOW–MED risk)

All findings from the chat workflow/cache audit, implemented behind the existing
architecture — REST stays the source of truth, the socket stays delivery-only,
the Drift cache stays metadata-only, and no backend contract moved.

- **Reconnect no longer strands messages (HIGH).** `_reconcile` merged only the
  newest page, so an outage that buried more than one page left a hole in the
  middle of the thread that scroll-back could never reach — it pages from
  `_nextCursor`, which points *below* the loaded window and walks away from the
  gap. Reconcile now keeps paging older until the two windows meet (bounded at 5
  pages); if the gap is wider it hands `_nextCursor` to the deepest page fetched
  so scroll-back walks *into* the gap instead of past it. `seq` is allocated
  globally by the server, so the gap test is window overlap, not arithmetic.
- **A rejected send can be discarded (HIGH).** There was no local-only discard:
  "Delete for me" called the REST endpoint with a `local:<key>` id the server has
  never seen, so the bubble and its outbox row survived and `_retryFailedSends`
  re-dispatched it on every app open and every reconnect, forever. New
  `discardFailedSend` drops the bubble and drains the outbox row via
  `ChatThreadCache.discardPending`. Both menus now hide every server-addressed
  action (reply/forward/info/deletes) on an unsent message and offer Discard,
  with its own confirmation copy.
- **The unread badge is coupled to the mark-read ack (MED).** It still clears
  instantly on open — the clear is now recorded, and `restoreUnread` puts it back
  when the mark-read never lands, so the inbox stops showing "read" for a thread
  the server still counts unread. A newer count always outranks a pending
  rollback. Wired thread→inbox via a DI callback; no UI coupling.
- **Cached inboxes show real unread counts (MED).** `unreadCount` was never
  persisted, so every cold/offline paint reported zero. Added as a column
  (schemaVersion 1→2, additive `ALTER TABLE`, existing rows default to 0 and are
  corrected by the next list read, which is server-authoritative).
- **Offline scroll-back stops lying about the start of history (MED).** Running
  out of cached messages was read as reaching the beginning of the thread. An
  exhausted cache now falls back to the stored server cursor, so scroll-back
  resumes from the server; null — a real stop — only when the last online fetch
  reported no further page.

A follow-up self-review caught three more defects, now also fixed:

- **`reset()` leaked the unread rollback record**, so a previous account's
  in-flight mark-read could restore its count into the next session's inbox
  after an account switch — the exact leak `reset()` exists to prevent.
- **Caching `unreadCount` introduced its own staleness**: a thread read offline
  and reopened offline kept showing its pre-read badge. A confirmed mark-read now
  zeroes the cached count (`clearCachedUnread`), so the cache follows the server.
- **A failed catch-up page discarded the pages already merged** — reconcile now
  emits what it successfully fetched instead of dropping it.

+15 tests (multi-page reconnect, reconcile stop condition, partial catch-up
failure, discard paths, unread rollback and its two precedence rules, the
account-switch leak, cached unread, mark-read cache sync, both end-of-history
sides, and a real **v1→v2 migration test** that downgrades a file database and
lets drift upgrade it — the upgrade path every other test skipped via
`.memory()`/`onCreate`). Every new test was verified to fail without its fix.
Analyze clean; 1218 pass with the 2 known `splash_centering_test.dart` failures
unchanged.

## 2026-07-30 — Chat/network: stop logging Bearer tokens in release (bug; LOW risk)

`core/network/api_client.dart` was printing every outgoing request's full
`Authorization: Bearer <token>` header, plus every response status and every
networking error, through `debugPrint` — three sites left over from the 401
investigation and marked `⚠️ TEMPORARY DEBUG — remove after 401 probe`.
**`debugPrint` is not compiled out in release builds**, so a signed-in staff
member's live Firebase ID token was written to the device/OS log (`adb logcat`,
Console.app, any log-scraping crash reporter) on every chat action in production.

Deleted `_debugLogOutgoing` and its two call sites, the `onResponse` override
(which did nothing but log and forward — removing it restores the identical
default behaviour), the `onError` probe line, and the now-unused
`package:flutter/foundation.dart` import. Pure deletion — the auth-retry
contract (single force-refresh + replay via `extra['authRetried']`) is
untouched. Found by a read-only audit of the chat workflow; the audit's other
findings (reconnect history gap, undiscardable failed sends, offline
end-of-history inference, uncached `unreadCount`) are recorded but **not** fixed
here.

## 2026-07-30 — Notifications: richer two-line header (polish; LOW risk)

The Notification Center's app-bar title is now a two-line lockup — "Notifications"
over a **live status line**: `N unread notification(s)` in the inbox, or
`N archived` in the Archived view (and "You're all caught up" / "Nothing
archived" at zero). It watches the cubit, so the count stays current as items are
read, archived, or arrive; the subtitle line height is always reserved so the app
bar never jumps on first load. Presentation only — no data/cubit/rules change.

## 2026-07-30 — My Tasks: pinned "Late" and "Missed" groups (polish; LOW risk)

The employee **My Tasks** screen now surfaces the two failure-adjacent readings
as their own groups instead of scattering them:

- **Active tab** — a dedicated **Late** section is pinned to the very top (above
  "Needs attention"): every actionable task already past its deadline. Those
  tasks are pulled out of "In progress" / "Today's tasks" so they no longer
  appear twice. Rejected rework keeps its own "Needs attention" home.
- **Done tab** — **Missed** tasks are pinned in their own group above the
  recency buckets; Completed and Cancelled stay grouped by recency below.

Presentation only — no new data, cubit, or rules; reuses the existing
`_isOverdue` reading (Late fires at the raw deadline per ADR-013) and the
terminal `missed` status. Also tightened "Upcoming" to strictly-future days so a
task due later *today* no longer showed in both "Today's tasks" and "Upcoming".

## 2026-07-30 — UI label: "Overdue" → "Late" (polish; LOW risk)

Every user-facing "Overdue" string now reads **"Late"**, so the product shows
exactly two overdue-ish words: **Late** (open task past its deadline) and
**Missed** (closed, unfinished). The label "Overdue" no longer appears in any
screen — task cards, feed group headers, feed preset, `TaskSchedulePhase` chip,
admin/branch dashboards, operations metric, workload cards, and pending-actions.
The push-notification title also changes ("Task Overdue" → "Task Late",
"is overdue" → "is late") — **needs a functions deploy to take effect.**

Presentation only: internal identifiers keep the name `overdue`
(`TaskSchedulePhase.overdue`, `FeedPreset.overdue`, `isTaskOverdue`,
`OperationsMetric.overdue`, group/preset keys, `usage_tracker` keys) so analytics
keys and logic are untouched. Aligns the UI with the spec's own primary term —
`AUTOMATED_TASKS_PRODUCT_SPEC.md` §3.1 already calls the derived visual
"Late (Overdue)". Affected tests updated; 94 in the touched suites pass.

## 2026-07-29 — ATLAS developer navigation system (`.nav/`)

Added `.nav/` — a code-navigation "operating system" (not prose docs): a boot README, 8 cross-cutting
maps (world map, entry points, data map, "what do I edit if…", danger/invariants, reverse navigation,
patterns, AI protocol), one location card per feature (18), and a machine-readable `atlas.index.json`.
Mechanical facts (file inventories, route/collection/function/test associations) are **generated** by
`.nav/gen_atlas.py` from the live code; judgment sections are hand-authored. Regenerate after structural
changes: `python3 .nav/gen_atlas.py`. Docs-only; no code behavior changed.


## Unreleased

### 2026-07-30

- **Attendance expectation sweep widened to the current business week** (bug; HIGH
  operational importance, LOW implementation risk — payroll-reporting denominator
  recovery). Added pure `businessDaysToSweep(nowMs)` in
  `functions/attendance_expectation.js`: newest-first Africa/Cairo business days
  from the current Schedule week Sunday through today, plus the previous business
  day for the Sunday boundary, deduplicated and hard-capped at 8 entries. The
  scheduled `closeAttendanceExpectations` consumer now uses that helper while
  keeping the same schedule reads, deterministic attendance ids, single `getAll`,
  chunked correction query, locked-row skip, and restatement signature. This makes
  the sweep self-healing after a missed run or deploy delay for rostered days still
  in the active business week; weeks entirely in the past still need a separate
  backfill. **Requires a functions deploy before production behavior changes.**

- **Attendance reporting zero-attendance semantics** (bug/product semantics; MED
  risk — payroll-adjacent wording and close readiness). Owner rule recorded:
  a materialized expected shift with no clock-ins is a real **0%** attendance
  result, not unknown attendance and not a day-level close problem; a day or
  period with no `attendance_expectations` rows is still a ledger data gap with
  no denominator. Removed the Weekly report's closure-marker prescription and
  the "known limitation" framing. `WeeklyAttendanceReport.isFullyClosed` now
  requires ledger rows and no blocking exceptions, so a row-present no-show week
  can reach **Fully closed**; blocking missing-punch / pending-correction /
  unknown exception rows still keep it **Partially closed**. The hub, weekly
  report, daily rhythm table, coverage card, and history summary now distinguish
  **No ledger data** from row-backed `0%`, and tests assert both sides of that
  rule.

- **Weekly Attendance Report** (feature; MED risk — first per-period report
  destination over payroll-adjacent ledger facts). Added
  `/attendance/reports/weekly/:periodId` for admin/manager, wired the hub's
  Weekly entry to a real route using the current branch + Sunday-Saturday period
  id, and kept employees behind the existing Attendance & Reports guard. The
  report reads only `attendance_expectations` through the existing
  `AttendanceReportCubit` branch/dayKey stream; no rollup collection, period
  document, Cloud Function, roster read, or raw attendance reconstruction was
  added. A new pure `WeeklyAttendanceReport` aggregates the seven-day ledger
  window into summary metrics, daily buckets, employee facts, exception groups,
  evidence rows, and conservative coverage. The UI renders IA §6's weekly
  sections, hides rates for an empty ledger, marks row-present weeks without
  blockers as **Fully closed**, and shows zero-row days as **No ledger data**.
  Monthly,
  per-employee, exception queue, branch comparison, close/lock, and PDF/CSV
  export remain disabled **Coming next** surfaces.

- **Attendance Reports Dashboard** (feature; MED risk — first manager/admin
  reporting surface over payroll-adjacent ledger facts). Added
  `/attendance/reports` as the Attendance & Reports hub for admin and manager,
  wired into the desktop sidebar label while employees keep the plain Attendance
  entry and are route-guarded away. The screen reads only the
  `attendance_expectations` reporting ledger via the existing
  `AttendanceReportCubit`: branch scope lives in the header, managers are pinned
  to their branch, branchless admins must choose one explicitly, Week/Month
  windows use the reporting period helpers, and future-period navigation is
  disabled. Empty ledger coverage renders **Awaiting close** with no rate or
  zero-valued metric grid; rows present render denominated cards for expected
  shifts, present, absent, show-up, punctual arrivals, worked time, and excluded
  context. Later Weekly/Monthly/per-employee/export/exception surfaces are shown
  as disabled **Coming next** entries. The reporting source guard now covers the
  new screen and widgets.

- **Attendance reporting read layer** (feature; HIGH operational importance,
  MED risk — payroll-facing numbers now depend on the materialized ledger).
  Added the client read path for `attendance_expectations`: persisted
  `AttendanceLedgerRow` + defensive Firestore model parsing, read-only
  datasource/repository streams over the deployed `(branchId, dayKey)` and
  `(userId, dayKey)` composites, `AttendanceReportSummary.fromLedger`, a plain
  Cubit/state with explicit `LedgerCoverage`, and DI wiring. The existing
  Attendance History summary strip now reads ledger-derived show-up and punctual
  arrival metrics and renders **No ledger data** for an empty ledger window
  instead of dangerous real-looking zeroes. Added source-guard tests so reporting
  files cannot re-import `AttendanceStats`, roster reconstruction, board code, or
  schedule reads. Weekly/Monthly reports and export remain future slices; the
  close Function still requires deployment before production periods have rows.

- **Attendance expectation close pipeline** (feature; HIGH operational importance,
  MED risk — payroll-relevant server materialization, additive collection). Added
  the Cloud Functions pure module `functions/attendance_expectation.js`, mirroring
  the Dart reporting core's expected-row outcomes and exception codes while copying
  persisted minute snapshots rather than recalculating payroll minutes. New
  scheduled export `closeAttendanceExpectations` runs every 30 minutes in
  `Africa/Cairo`; the initial version scanned only the current and previous
  business day before the week-wide self-healing window later the same day. It resolves
  rostered slots from `weekly_schedules`, materializes one
  `attendance_expectations/{uid}_{yyyyMMdd}_{shift}` row per closed expected slot
  (including phantom no-shows), skips locked rows, and restates changed rows with a
  bumped version + `restatedAt`. Added read-only client rules for the new collection
  (admin any, manager own branch, employee own row), denied every client write, and
  added only the branch/day and user/day composites the future report queries need.
  Cloud Functions tests are **60 pass** (was 46); Firestore rules are **37 pass**
  (was 31), verified against the emulator. Requires a functions/rules/indexes
  deploy. The legacy History/`AttendanceStats` reader still
  ignores the expectation ledger until a later slice rewires it.

- **Attendance Reporting Ledger P0 pure domain core** (feature; LOW risk — purely
  additive pure domain, no call sites yet, no existing file's behaviour changed).
  Added plain Dart value objects under
  `features/attendance/domain/reporting/`: `AttendancePeriodWindow` and
  deterministic period ids; roster-derived `ExpectedShiftRow`s that turn a
  finished no-record roster slot into a phantom `absent` row; derived exception
  codes including missing-punch, unscheduled-work, and implausible-record review
  flags; and `AttendanceReportSummary` rates that carry numerator and
  denominator. The implementation reuses `AttendanceCalculator`, `ShiftWindow`,
  `ScheduleWeek`, `WeeklyScheduleEntity.hoursFor`, and attendance deterministic
  ids. No Cloud Function, Firestore collection, rules/indexes, export, or UI was
  added, and nothing imports the new files yet. +4 domain test files (+19 tests):
  `flutter test` 1179 pass · 2 fail (the same pre-existing splash-centering pair),
  `flutter analyze` unchanged at 1 pre-existing info.

- **Scheduled tasks are visible but not startable before their start time**
  (feature; MED risk — client workflow + Firestore rules). Upcoming `pending`
  tasks already stayed in active/upcoming lists and read Scheduled rather than
  Overdue/Missed; this now has coverage. The actual start path is gated by one
  pure `task_schedule.dart` predicate, reused by Employee Home, Task Details,
  and `TaskCubit.startTask`: null `startsAt` remains startable, the boundary is
  inclusive, and **rework has no exception** (`rejected → started` is blocked
  before `startsAt` just like first start). The UI disables and explains the
  action ("Starts at …") and arms a one-shot timer so it enables itself without
  refresh. Firestore rules now deny employee writes whose destination status is
  `started` while the stored `startsAt` is still in the future. +14 Flutter
  tests and +5 Firestore rules tests. **Requires a rules deploy.**

- **Fixed: automated tasks can no longer be born already overdue** (bug; HIGH
  severity, MED risk — two recurrence engines plus scheduler semantics). The
  recurring-shift generator now treats "today" as the Egypt business civil day
  (`Africa/Cairo`) instead of UTC, anchors shift windows to that local midnight
  with DST-safe calendar arithmetic, and runs at **01:00 Africa/Cairo** before
  any shift starts. A temporary legacy UTC-key guard prevents a duplicate on the
  deploy transition. The client save-time materializer now uses the local
  business date and refuses to create a shift instance after its resolved
  deadline, while still allowing creation mid-window. Per-task recurrence rolls
  successors forward until their deadline is in the future and uses calendar
  stepping for daily/weekly rules. +5 Cloud Functions tests and +3 Flutter tests.
  **Requires a functions deploy** for the server generator/sweep behavior to
  take effect in production.

### 2026-07-29

- **Create/Edit Task graduated from a bottom sheet to a first-class full-screen
  route** (UX/architecture; MED risk — new container for a core daily workflow,
  business logic untouched). Owner ruling: the modal `showModalBottomSheet` read
  as temporary and buried its primary action. `showTaskFormSheet` now
  `Navigator.push`es a **`CupertinoPageRoute(fullscreenDialog: true)`** (bottom-up
  modal, own back stack). The form's state, `_save`, validation, and scheduling
  are **byte-for-byte unchanged** — only the container and presentation were
  elevated: a pinned nav bar (Cancel + a title that condenses in on scroll), a
  hero header with stronger identity, the Work Type reframed as the workflow's
  opening move, **assignment as interactive segmented cards**, a rewarding
  checklist builder (autofocus-on-add + a filled add affordance), a **sticky
  Create bar with live validation** (dims until the essentials are set, states
  what you're about to make), a Cupertino discard-guard on Cancel, and inline
  errors. Strictly monochrome (ADR-004). `_SheetHeader` retired in favour of the
  new page hero; other sheets (Assign/Review/Cancel/Report) stay sheets. No test
  pumps the form; task suite + full `flutter analyze` green. Concept mockup:
  design artifact (Create Task full-screen redesign).
  - **Follow-up: Required vs Optional restructure (dependency-driven disclosure,
    not a wizard).** After weighing a linear step-by-step wizard and rejecting it
    (serial gating taxes the expert manager who creates tasks all day), the
    required workflow stays always-visible and ordered: **Work Type** leads (the
    framing decision — it determines the form's structure, so it sets context
    before data entry) → **Task Details** (title · the type's own fields ·
    optional description, grouped) → **Assignment** → **Schedule**. The optional
    enhancements — **Checklist · Priority · Repeat · Attachments** — fold into a
    single secondary **"Additional Details"** disclosure (`_OptionsPanel`),
    collapsed by default with a live summary ("3 steps · High priority · 2
    photos"), revealed via `AnimatedSize` + fade. So the common task is a short
    screen (Work Type default General + Title + assignee → Create). It auto-opens
    when editing/prefilling a task that already has optional content, and a failed
    submit auto-expands it so no folded-field error hides. Business logic still
    untouched (`_save`/validation/scheduling/cubit). **Future direction:** Work
    Type should carry *smart presets* that auto-populate checklist templates +
    defaults per type (extends the existing `WorkTypeRegistry` seam).
  - **Follow-up: V1 ship-blocker polish pass (presentation-only, no behaviour
    change).** Four fixes from a cold design review, all with logic preserved and
    the full suite green (1132 pass · 2 pre-existing splash fails):
    1. **Work Type is inline, no more sheet.** For a small catalogue (≤6; today
       5) the picker renders inline selectable cards (`_WorkTypeInlineCards`) —
       the first decision no longer opens a bottom sheet. Above the threshold it
       auto-falls-back to the searchable sheet, so the architecture still scales.
    2. **Inline validation.** Title now validates on blur and shows a red inline
       error on the field (`AppTextField` gained additive `errorText` +
       `onFocusChange`); the bottom banner is reserved for the cross-field
       work-type setup error only. Create stays disabled until valid; the footer
       names the blocker (title / branch / shift).
    3. **Native scheduling picker.** Replaced the Material `showDatePicker` /
       `showTimePicker` with a monochrome Cupertino `CupertinoDatePicker`
       (date+time, dark theme). Same value range and returned `DateTime` — the
       scheduling engine is untouched.
    4. **Accessibility.** Checklist icon buttons 32→44px (+ a "Remove step"
       label); `Semantics` (button/selected) on the segmented control, assignment
       cards, and work-type cards; segmented touch height nudged up. Deferred V2
       ideas recorded as `TODO(create-task-v2)` in `task_action_sheets.dart`
       (Create & Add Another, Smart Templates, Draft Recovery, AI Suggestions,
       Create from Template, Better Schedule Presets).
  - **Follow-up: the assignment model says what the business actually does —
    Individual · Group · Shift** (UX + one new rule; LOW risk — labels are
    presentation, the one behaviour change is gated to new tasks). Owner ruling:
    "Team" implied a standing organisational unit, but the mode is really an
    ad-hoc set of 2–3 people a manager hand-picks for one task, and "Employee"
    was a noun for a person pretending to be a mode.
    - **Labels only — no data migration.** `TaskAssignmentType.label` now reads
      **Individual / Group / Shift**. The enum *names* are the persisted values
      and were deliberately **not** renamed, so every existing
      `tasks/{id}.assignmentType` document, `fromString`, the
      `assignmentType == 'shift'` check in `firestore.rules`, the composite
      indexes, and the Cloud Functions keep working untouched. New
      `test/task_assignment_type_test.dart` (6 tests) pins that invariant.
    - **The mode is DERIVED from the pick, not asked before it** (owner ruling,
      same day — this deliberately reverses the "never infer the mode from the
      count" position taken earlier in the session). Previously `individual` and
      `team` were *behaviourally identical*: both opened the same multi-select,
      both wrote `assigneeIds`, and nothing in the codebase ever read `team`
      (every consumer only branches on `== shift`). Rather than make Individual
      a separate single-select, there is now **one people picker, always
      multi-select, that never closes on a tap** — you keep adding while it's
      open — and the mode follows the final count via the new pure
      `TaskAssignmentType.forAssigneeCount` (1 → Individual, 2+ → Group). Shift
      is never derived; it targets the roster, so it stays a deliberate choice.
    - **The derivation is shown, not hidden.** The picker's subtitle names the
      outcome live while you build the selection — "1 selected — Individual: one
      person owns this" / "3 selected — Group: they share the work" — reading
      the label from `forAssigneeCount` itself, so the copy can't drift from the
      rule. That was the condition for accepting inference at all: the magic has
      to be visible while it happens.
    - **The cards are still a control, and still don't discard work.** An
      explicit tap wins until the next selection change. Group → Individual with
      several people picked keeps the person picked **first** and says so inline
      ("Kept 1 of 3 — an Individual task has a single owner"); Individual →
      Group carries that person in as the group's first member; Shift leaves the
      pick untouched, so coming back restores it.
    - **A new people-mode task now requires at least one assignee.** Empty
      `assigneeIds` reaches **nobody** (`canUserAccessTask`), so Create stays
      disabled with "Choose who this task is for". This also removes a false
      promise: the Team card claimed *"Everyone in the branch"* and the footer
      claimed *"Assigned to the whole team"* on an empty pick, neither of which
      anything implemented. **Edit mode is exempt** (an existing task's
      assignment isn't re-litigated in the form) — note this closes the
      create-time "assign later" path; pre-existing unassigned tasks still show
      in the Unassigned feed filter.
- **Employee "My Tasks" premium polish pass** (polish; LOW risk — one screen,
  in-language, no behaviour change). Enriches
  [`my_tasks_screen.dart`](lib/features/task/presentation/pages/my_tasks_screen.dart)
  while honouring the monochrome ruling (ADR-004) and the card attention model
  (ADR-014 — the `LiveStatusBorder` orbit and per-state status dot are kept):
  two-line header (title over today's date), a compact monochrome completion
  overview (ring + done/remaining + "N Active Tasks" / "You're all caught up"),
  a slimmer 38px sliding segmented control (local override — shared primitive
  untouched), richer cards (larger title, shift · due subtitle, restrained
  "High" marker, press spring-back), **date-grouped closed tasks**
  (Today · Yesterday · This week · Earlier) that fade slightly and swap the
  progress bar for an outcome badge, and a calmer ringed-check all-clear state.
  Indigo from the design brief was **declined** — it reverses ADR-004; owner
  confirmed monochrome. No tests reference the screen; task suite still green.
- **The task card's edge is now the state, and it stopped moving** (polish;
  MED risk — replaces a lived-in UI on one surface). Owner-approved from a
  high-fidelity mockup before any code was written; ruled in
  [ADR-014](docs/decisions/ADR-014-task-card-border-language.md).
  - **`LiveStatusBorder`'s perpetual orbit is gone from Employee Home.** Every
    actionable card used to run a comet around its full border forever, so
    nothing on the screen was ever still and nothing could be emphasised. Now a
    single soft 1px hairline carries the status (`taskAttentionTone`), and it
    does not animate: white (new) · blue (started) · amber (in review) · green
    (approved) · red (missed/rejected) · grey (cancelled).
  - **Only a genuinely new task gets attention** — new `TaskAttentionSurface`
    gives an unopened `pending` card an Apple-quiet treatment: ambient white
    bloom, a 3% bevel highlight, a specular hairline, and **one shimmer across a
    short section of the top edge every 9 seconds**. It never reaches a corner,
    which is what keeps it from reading as an orbit or a spinner. Reduced motion
    drops the shimmer and keeps the static layers.
  - **Opening or starting the task clears it permanently** (200ms). New
    `TaskSeenStore` — a per-uid JSON file mirroring `CaseSeenStore`, so this is
    **client-only: no schema change, no rules deploy**.
  - New `AppColors.info` (the fourth and final semantic colour, hairline only);
    `LiveStatusBorder` still runs on My Tasks, the admin dashboard, and
    `AttentionTile` — deliberately out of scope. **On-device visual sign-off
    still pending.**

- **Fixed: the deployed rules denied every task creation** (bug; HIGH severity,
  LOW-risk fix). Reported from the running app as *"The caller does not have
  permission to execute the specified operation"* — a task would appear briefly,
  vanish, and Active Tasks would fall to 0.
  - **Root cause: one wrong default.** `map.get(key, default)` returns the
    default **only when the key is ABSENT**. `TaskModel.toMap()` always emits
    every key, so an unset optional arrives as *present-with-null* — and
    `get('cancelReason', '')` therefore returns `null`, not `''`. The Phase-1
    create rule compared it to `''`, which is never true, so **every task
    creation was denied for every role**, deterministically.
  - The "appears then disappears" symptom is Firestore offline persistence
    (`main.dart`): the SDK applies the write to the local cache, the listener
    renders it, the server rejects it, and the SDK rolls it back.
  - **Two further operations were broken by the same defect** and are also
    fixed: the employee **report-incorrect** path (`filesOwnIncorrectReport`)
    and the **admin terminal correction** (§6.4), both of which tested a
    null-valued field against `''`.
  - **Fix:** nullable task fields now default to `null` and compare against
    `null` throughout. This is also what restores **backwards compatibility** —
    `get(key, null) == null` is correct for a legacy document (key absent) *and*
    a current one (key present, value null), whereas the `''` default was wrong
    for both. No product behaviour, spec, or Flutter model changed.
  - **New permanent test harness: `firestore-tests/`** — 26 emulator-backed
    checks against the real `firestore.rules` using the **real
    `TaskModel.toMap()` payload**, including an explicit legacy-document suite.
    Run with `cd firestore-tests && npm test`. Rules were the one
    production-critical artifact in the repo with no test at all: the 1117 Dart
    tests exercise `TaskCubit` against a fake repository and never evaluate a
    rule, which is precisely why this shipped.
  - Verified: task creation ✓, report-incorrect ✓, admin terminal correction ✓,
    and every standing guarantee still denies (employee-cannot-cancel,
    terminals frozen and undeletable, no cancel from Waiting Review, cancel
    without a picklist reason rejected, missed server-only, employees cannot
    forge review attribution or shrink the activity log).

### 2026-07-28

- **Grace period ruled: a fixed, global 30 minutes**
  ([ADR-013](docs/decisions/ADR-013-task-grace-period.md); spec §3.6). The owner
  ruled the question §10.2 gated branch scorecards on. A generated shift task is
  now evaluated for Missed **30 minutes after its resolved shift end**.
  - **The old rule was never actually "zero grace".** The sweep runs every 15
    minutes, so a task submitted at 16:32 against a 16:30 end survived or died
    depending on where the cron tick fell — a random, invisible, irreproducible
    tolerance. The decision replaces it with a deterministic one.
  - **Grace is a tolerance on the close, not a deadline.** `dueAt` is unchanged
    and the task still reads **Late from the shift end** — the employee feels the
    urgency immediately; they are simply not *recorded as failed* until the
    tolerance expires. Still no notification on Late.
  - **Not configurable, and no "Completed Late" state.** A per-branch grace would
    be a dial on the headline KPI held by the person that KPI evaluates;
    lateness is *measured* from timestamps we already store, never *stated* as a
    fourth outcome.
  - One constant, mirrored: `TASK_GRACE_MINUTES` (enforcing, Cloud Functions) and
    `kTaskGracePeriod` (client). The sweep's **query cutoff and its transaction
    re-check now share one rule**, so the cron cadence can never be the effective
    policy again. Automation Center copy states the grace explicitly.
  - Verified the flagged edge: the operational-weekend night shift ends 00:00, so
    its grace expires 00:30 **the next calendar day** — pinned by test.

- **Automated Tasks Phase 3 — Reporting & analytics** (feature; MED risk). The
  four-way classification, now unblocked by the grace ruling.
  - **New pure `domain/task_outcomes.dart`** — the single derivation of spec
    §8/§10 over the already-in-memory task list. No stored aggregates, no
    pipeline (ADR-009, §13).
  - **Completion rate is now `Approved ÷ (Approved + Missed)`**, replacing
    `approved ÷ total`. Cancelled is excluded from **both** sides, which is what
    makes it ungameable — a manager cannot lift the number by cancelling work
    they expect to fail (asserted directly in test). It reads null, not 0%, until
    something has actually closed.
  - **Hard invariant enforced by omission:** there is deliberately no field or
    helper anywhere that sums Missed + Cancelled. The moment such a number
    exists, someone renders it and the distinction is destroyed.
  - **Cancellations report on their own line, broken down by reason code**, most
    frequent first — a single cancel is legitimate, a cluster is the smell that
    catches a misconfigured template or a routine that should be paused. A
    cancellation with an unreadable code counts under `unknown` rather than
    vanishing, so the breakdown always reconciles with the total.
  - **Late is timeliness on completed work** — "% completed after deadline" +
    average lateness (averaged over late work only, so the signal isn't diluted).
    Coaching data; it never touches the completion rate.
  - **Missed wired into the branch surfaces**, safe now that grace stops it
    over-reporting at shift boundaries: a Missed stat (hidden at zero) and a
    breakdown panel on the admin task overview, using existing primitives — no
    new route, no new screen. Fixed a consequence of the formula change: a branch
    with only open work now reads "Nothing closed yet" instead of the false "No
    tasks yet", and the card distinguishes the reliability *rate* from backlog
    *progress* in copy.
  - +14 Flutter tests, +4 Cloud Functions tests. **1117 pass / 2 pre-existing
    splash failures**; Cloud Functions **41 pass**; analyze unchanged at 1
    pre-existing info.

- **Automated Tasks Phase 2 — Visibility & trust** (feature; MED risk). The
  half of the spec that makes Phase 1 humane rather than merely correct.
  - **Notify on Missed (§9.1)** — the sweep used to close work silently, with
    the audit log as the only trace and nobody watching it. `taskMissed` is now
    written server-side by `autoEndRecurringShiftTasks` to the branch's active
    managers, **falling back to admins when a branch has none** (a manager-less
    branch would otherwise be silent again, which is the exact gap this closes;
    a covered branch never also pages every admin, or the signal dies). Ids are
    deterministic (`taskmissed_{taskId}_{uid}`), so a retried sweep can't
    double-notify. Deliberately **not** in the client whitelist.
  - **Notify on Cancel (§9.2/§9.3)** — targeted at the assignee(s), never
    branch-wide, with the mandatory reason in the body so nobody is left
    guessing. A shift broadcast has no named assignee, so it resolves the
    **rostered crew** exactly as a review outcome does; nobody rostered is a
    valid no-op, not a failure.
  - **Employee "report incorrect task" (§5.2)** — the release valve. New
    additive `reportedIncorrectBy` / `At` / `Note` fields, a quiet
    "Something's wrong with this task" link under the employee's real action,
    and a **required** explanation (a bare "this is wrong" gives the manager
    nothing to decide on). It **does not change the task's status** — the work
    stays put until a manager acts. Managers get a warning-tinted banner
    carrying the reporter, the note and both decisions inline: *Cancel task* or
    *Task stands*. Cancelling clears the report, because cancelling is the
    answer. Rules let an employee file only under their own uid, never over an
    open report and never clearing one.
  - **Admin terminal correction (§6.4)** — `correctTerminal` returns a
    `missed`/`cancelled` task to `pending`, clearing every trace of the undone
    outcome. Admin-only and always audited (`task.terminal_corrected`), because
    a mistimed terminal — a cancel that lost the race to the sweep by seconds,
    a miss recorded against work that was done — is otherwise a permanent lie in
    the reporting. Deliberately narrow so it stays a safety valve, not a routine
    escape hatch. The existing manager-or-admin *reopen approved* is untouched
    (the spec's §6 table treats them as separate permissions).
  - New audit events `task.reported_incorrect` · `task.report_dismissed` ·
    `task.terminal_corrected`, and three timeline-only activity kinds. +11
    Flutter tests (**1103 pass / 2 pre-existing splash failures**), +1 Cloud
    Functions test (**37 pass**), analyze unchanged at 1 pre-existing info.
  - **`firestore.rules` NEEDS DEPLOY** — carries the terminal-correction
    carve-out and the incorrect-report guards.
  - **Still not built:** Phase 3 (four-way reporting/KPIs, §10).

- **Automated Tasks Phase 1 — Cancelled core** (feature; MED risk). Implements
  Phase 1 of the frozen
  [AUTOMATED_TASKS_PRODUCT_SPEC](docs/design/AUTOMATED_TASKS_PRODUCT_SPEC.md):
  a third terminal outcome that is neither success nor failure.
  - **`TaskStatus.cancelled`** — terminal, reachable from `pending`/`started`
    **only** (a submitted task must be reviewed, never voided — §5.4), and
    manager/admin only. New `TaskStatus.isCancellable` is the one predicate the
    UI, the cubit and the rules all read.
  - **Mandatory structured reason.** New `core/enums/task_cancel_reason.dart`
    with the five frozen picklist codes (`duplicate` · `wrong_generated` ·
    `no_longer_needed` · `shift_cancelled` · `management_decision`) plus an
    optional free-text note. The **wire ids are frozen and the record is
    immutable once written**, so relabelling an option never rewrites history;
    an unrecognised code round-trips as `unknown` rather than silently becoming
    a *different* reason. Additive `TaskEntity` fields (`cancelledAt`,
    `cancelledBy`, `cancelReason`, `cancelNote`) — no migration.
  - **Counted nowhere (§8).** Cancelled is excluded from the active window, the
    feed, the overdue count and the branch completion rate's numerator *and*
    denominator. This is the invariant that stops Cancel becoming a way to
    launder work that simply wasn't done; it is asserted from every angle a
    number is derived.
  - **`firestore.rules` (NEEDS DEPLOY).** Cancelling requires `canReachBranch`
    (so an employee never can), a `pending`/`started` predecessor, a picklist
    reason and a timestamp. A cancelled task is then frozen — no update, no
    delete, and no forging `cancelled` at create time. Outside that one
    transition every cancel field must be byte-identical to what is stored.
  - **No resurrection (§4.4).** The generator's window-repair path now skips any
    terminal instance (new pure `isTerminalTaskStatus`), so a cancelled task can
    never be handed a fresh deadline and pulled back onto the auto-end sweep's
    radar. Cancel-vs-miss is a race with a deterministic winner: **first terminal
    to land wins, the other is a no-op**.
  - **UI** — a monochrome Cancel sheet (radio picklist + optional note; the CTA
    stays disabled until a reason is chosen, and the dismiss action is labelled
    *Keep Task* so "Cancel" never means two things in one sheet), reached from a
    Task Details action shown only while the task is cancellable. A cancelled
    task's locked banner now carries the reason and note. Cancelled reads
    neutral grey everywhere — never the error red Missed wears.
  - Audit: new `task.cancelled` event carrying `reason` / `note` /
    `cancelledFrom`. +19 Flutter tests (**1092 pass / 2 pre-existing splash
    failures**), +2 Cloud Functions tests (**36 pass**), analyze unchanged at 1
    pre-existing info.
  - **Not yet built (later spec phases):** notify-on-cancel and notify-on-missed,
    the employee "report incorrect task" path, the admin terminal correction
    (§6.4), and the four-way reporting/KPI rework (§10).

### 2026-07-27

- **Employees directory density pass (P19; presentation-only).** `/admin/employees`
  now has a compact desktop header with live employee/active/branch counts and a
  header-level Create Employee CTA (the desktop FAB is gone; mobile keeps it),
  one horizontal search/filter/sort/view toolbar, and lazy list/natural-height
  two-column rendering for large directories (no fixed card-height overflow).
  Employee cards now pair a softer 48px avatar and
  compact access badge with inline Completed/Pending/Rate/Late metrics, keeping
  only Details and Edit visible; Change Branch, Position, Reset Password, and
  Activate/Deactivate remain available in the ellipsis and desktop context menus.
  Existing routes, cubits, repositories, action sheets, and `isActive` access
  semantics are unchanged; the design remains monochrome apart from semantic
  status colors. Added focused widget coverage for the compact card and overflow
  behavior.

- **Chat List macOS polish (P18; presentation-only).** `/chat` now uses a
  compact opt-in desktop header with a persistent native dark search field
  (`Search conversations...`), tighter 56px-avatar rows, 16/600 names,
  one-line previews, inset dividers, soft hover/selection, circular unread
  badges, and an icon-led `No conversation selected` empty state. Desktop chrome
  now has calmer selected navigation rows, a compact circular Chat badge, and a
  low-depth profile card. Reused `AppSearchField` for compact,
  focus/reduced-motion-aware geometry; routes, cubits, API/backend, and data
  behavior are unchanged.

- **Fixed iOS Simulator builds failing with "Unable to find a destination
  matching the provided destination specifier."** Removed the non-standard
  `SUPPORTED_PLATFORMS = iphoneos;` line from the Runner project's **Release**
  and **Profile** build configs in `ios/Runner.xcodeproj/project.pbxproj` (the
  stock Flutter template never sets it). Because scheme destination-eligibility
  is computed via the project's `defaultConfigurationName = Release`, that line
  stripped iOS Simulator from the Runner scheme's eligible destinations for
  **every** invocation — including `flutter run` (Debug) and even
  `generic/platform=iOS Simulator` — while `xcodebuild -showdestinations` still
  listed the simulator (it enumerates real devices rather than filtering by the
  scheme). Verified with `flutter build ios --debug --simulator` → built
  `Runner.app`. (Separate red herring in the original report: the hardcoded
  destination UUID `…E8506BD8CD12` did not match the live device
  `…E8506BD8C012` — always let Flutter pick the device instead of pinning a
  stale UUID.)

### 2026-07-26

- **Environment system rebuilt around build mode — no dart-defines, no manual
  switching.** The backend URL is now a pure function of how the binary was
  compiled (`lib/core/config/app_environment.dart`): Debug/Profile →
  `http://localhost:3000`, Release → Railway (`https://drop-api-production.up.railway.app`).
  A release artifact is **locked** to Railway — the URL is a hardcoded `const`
  and no define or config file can point it at localhost or an emulator IP.
  Removed the `config/{local,staging,production}.json` dart-define files and the
  `API_BASE_URL`/`APP_ENV` defines; the `staging` environment is gone (two
  environments only: Development, Production). Optional dev-only LAN override
  `--dart-define=DEV_API_BASE_URL=...` (ignored in release). `.vscode/launch.json`
  simplified; iOS `Info.plist` gains a **localhost-only** ATS exception (release
  unaffected — it only ever uses HTTPS). Startup logs a one-line banner with
  Environment · Build Mode · API Base URL.

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
