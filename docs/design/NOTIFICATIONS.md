# Notifications V2 — DROP

Status: **pilot-hardening pass, 2026-07-10** (branch `feature/notifications-v2`).
Scope of this pass: reliability + one crash-safe deep-link path. The in-app
Notification Center (grouping, read/unread, mark-all, archive, pagination) was
already built and is unchanged here except where a bug fix required it.

This document is the single source of truth for the notification **flow**,
**lifecycle**, **deep-link routing**, and **model**. Keep it in sync with the
code (protocol: PROJECT_CONTEXT / CURRENT_STATE / CHANGELOG).

---

## 1. Architecture

Three cooperating parts, all Clean Architecture / feature-first.

| Part | Where | Responsibility |
|------|-------|----------------|
| **Delivery** | `lib/core/services/notification_service.dart` | FCM engine: permission, token lifecycle, receive routing (`onForeground` / `onMessageTap`). |
| **In-app inbox** | `lib/features/notifications/` | Entity · model · datasource · repo · `NotificationCubit` · Notification Center screen · tile · pure `notification_format.dart` helpers. Producers: `NotifyTaskEvent`, `NotifySwapEvent`. |
| **Server** | `functions/index.js` | `sendNotification` (client→doc), `onNotificationCreated` (doc→push), `dispatchBroadcast`, `runTaskReminders`, `onCase*` / `onRequest*` (server producers), `claimFcmToken` (token exclusivity). |

**Contract:** `notifications/{id}` (Firestore) is the single source of truth.
The FCM push is a *mirror* of the doc, not a separate channel. Clients never
create notification docs directly — `firestore.rules` denies it
(`allow create: if false`); every client-produced notification goes through the
validated `sendNotification` callable, and all server producers use the Admin
SDK (which bypasses rules).

### Who a client may notify — `sendNotification` reachability

The predicate is pure and lives in
[`functions/notification_reach.js`](../../functions/notification_reach.js)
(`canNotify`), tested in `functions/test/notification_reach.test.js`:

- **the caller is an admin** → anyone, any branch (the role is global);
- **the recipient is an admin** → allowed, whoever is calling;
- **otherwise** → same branch only.

> ⚠️ **The middle clause is not a convenience — its absence was a silent outage.**
> Until 2026-08-06 the rule was branch-comparison only, and **an admin has no
> `branchId`** (PROJECT_CONTEXT §8 — the role is global, so provisioning omits
> it). So `recipientBranch === callerBranch` compared `""` against the caller's
> branch and **no employee or manager could ever notify an admin.**
>
> What that cost: `NotifyTaskEvent` routes `taskSubmitted` to `task.createdBy`,
> so **every task an admin created was submitted for review and the admin was
> never told.** The callable threw `permission-denied`, the datasource turned it
> into a `ServerException`, and `NotifyTaskEvent`'s deliberate catch-all
> swallowed it to a `developer.log` — the employee saw an ordinary successful
> submission. The same held for any generated shift task whose template an admin
> set up, since the instance inherits the template's `createdBy`.
>
> Any new branch-scoped check against a user must ask "does this reach an
> admin?" — a branch comparison never does.

Reachability is **not** authorization. What may be *sent* is constrained
separately: the `CLIENT_NOTIFICATION_TYPES` whitelist, the 120/500 title/body
caps, the payload key whitelist, the 50-item cap, and the server-stamped
`senderUid`. Widening reach to admins widens who can be told, not what can be
forged.

---

## 2. Notification flow

```
PRODUCER                        DOC                       PUSH                       RECEIVE / TAP
─────────────────────────────────────────────────────────────────────────────────────────────────
task / swap (client)      →  sendNotification()      →  onNotificationCreated  →   NotificationService
broadcast (server)        →  dispatchBroadcast()     →  (pushes inline,             ├─ foreground → actionable snackbar
case / request /             onCase* / onRequest*        pushedByFunction:true)      ├─ background tap → onMessageTap
 reminder (server)        →  runTaskReminders()      →  onNotificationCreated  →    └─ cold-start → getInitialMessage
```

- **Foreground** (`FirebaseMessaging.onMessage`) → `onForeground(title, body, data)`
  → a polished **top banner** (`InAppNotificationHost`, `core/widgets/`) that
  slides down, self-dismisses, and deep-links via the shared resolver (§4) on
  tap. A foreground push is never a dead end. **Apple platforms skip the in-app
  banner** — iOS draws its own OS foreground banner
  (`setForegroundNotificationPresentationOptions`), so showing both would
  double-notify; Android/others get the in-app banner (a foreground push reaches
  `onMessage` only and the OS shows nothing). *(Was a bottom snackbar until
  2026-08-09, then briefly removed, then restored as this top banner 2026-08-10.)*
- **Background tap** (`onMessageOpenedApp`) → `onMessageTap(data)` → resolver → push route.
- **Terminated / cold-start** (`getInitialMessage`) → same `onMessageTap`.
- **In-app tile tap** → `NotificationsScreen._deepLink` → **the same resolver**.

### Direct-chat push exception

Chat messages are pushed by the NestJS chat backend, not by `functions/index.js`
or a `notifications/{id}` document. Its pinned FCM `data` contract is
`route: "chat_message"` with `conversationId`, `messageId`,
`senderExternalId`, and `recipientUid`; all values are strings. The shared
resolver opens `/chat/:conversationId` for every role and falls back to `/chat`
when a legacy or malformed message has no conversation id.

**Foreground de-duplication.** Chat is the only route with **two** independent
delivery paths — the chat socket and FCM — so both can fire for one message
while the app is open. Exactly one surface must win per platform, and the two
suppressions are exact opposites:

| Platform | Chat surface in the foreground | How the other one stands down |
| --- | --- | --- |
| iOS / macOS | the **OS banner** (FlutterFire presents it for every route) | `ChatNotificationListener` returns early on `suppressesInAppChatBanner` |
| Android | the **in-app socket banner** (the OS draws nothing in the foreground) | `suppressForegroundFcmNotification` drops the chat FCM before `onForeground` |

This deliberately preserves the pre-existing app-wide rule that Apple platforms
rely on the OS banner and Android on the in-app snackbar — chat did not change
foreground behaviour for any other route. Per-message iOS presentation cannot be
selected from Dart, which is why the socket banner (not the OS one) is what
yields there. Background and terminated chat pushes render normally and route
through `onMessageOpenedApp` / `getInitialMessage`.

`pushedByFunction:true` on broadcast docs prevents `onNotificationCreated` from
double-pushing (the broadcast engine already pushed inline). The inline send is
best-effort and retries one time only when the Admin Messaging call fails with a
transient service error (or throws before returning per-token outcomes); dead or
invalid tokens are pruned, never retried. Its final log records success and
failure counts. The inbox doc remains authoritative regardless of push outcome.

**Server-owned transitions:** `approveSwap` writes one `swapApproved` inbox doc
for each swap party only after its roster-exchange transaction commits; the
client no longer produces that event. `onNotificationCreated` mirrors both docs
to FCM. The other swap events remain client-produced through `sendNotification`.

### Recipient safety (defense-in-depth #3)
Every push carries `data.recipientUid`. The client **drops** any push whose
`recipientUid` != the signed-in user and self-heals by re-registering its token
(reclaimed server-side by `claimFcmToken`). This guarantees a notification never
reaches the wrong account even during an account-switch/token-drift race.

---

## 3. Lifecycle

1. **Create** — a producer writes the doc (`createdAt` = server timestamp,
   `readAt` = null). `senderUid` is server-stamped and never forgeable.
2. **Deliver** — `onNotificationCreated` fetches the recipient's `fcmTokens`
   (array + legacy single field), pushes chunked, and **prunes dead tokens**
   (`messaging/registration-token-not-registered`, etc.).
3. **Read** — a tap or swipe sets `readAt` (server timestamp). The live stream
   re-emits; no optimistic write.
4. **Archive** — `archivedAt` set/cleared (hidden from the default inbox, kept
   for history). `pinnedAt` similarly. Firestore rules permit the recipient to
   update **only** `readAt`, `archivedAt`, and `pinnedAt`; `recipientUid`, content,
   type, and payload remain server-owned.
5. **Delete** — the recipient (or an admin) hard-deletes the doc.

### Who is told a task is waiting for review

`taskSubmitted` does **not** route to `task.createdBy`. It walks a three-tier
ladder, pure and unit-tested in
[`task/domain/task_review_routing.dart`](../../lib/features/task/domain/task_review_routing.dart)
(`taskReviewRecipients`), fed by the `ResolveTaskReviewers` use case:

| Tier | Recipients | When |
|---|---|---|
| 1 | **the creator** | they can still review it — active, and admin or manager *of this branch* |
| 2 | **the branch's active managers** | the creator cannot |
| 3 | **active admins** | the branch has no manager who can act |

`canReviewTask` is the gate, and it mirrors the `tasks` update rule in
`firestore.rules` (and the server's own `requireSalesManager`): **active**, and
either a global admin or a manager of *this* branch. If the predicate and the
rule ever disagree, the rule wins and the predicate is the bug.

> **Why a ladder rather than one uid.** `createdBy` alone is silence in four
> situations, all of which leave a task in `waitingReview` with **nobody told**
> and no error anywhere — `sendNotification` skips an absent recipient without
> raising: the creator is **deactivated**, **hard-deleted**, **demoted** to
> employee, or has **moved branch**. The last two are worse than silence: rules
> would refuse their approval, so notifying them tells the one person who
> *cannot* act and nobody who can.
>
> A generated shift task makes this routine rather than exotic. It inherits the
> **template's** `createdBy` (which is exactly why `task_origin.dart` warns that
> `createdBy` cannot answer "who made this"), so a template set up a year ago by
> someone who has since left produces a task **every single day** whose
> submission notifies a dead account.

The escalation is deliberately the same shape as the server's
`salesRecipients(branchId, {managersOnly: true, adminsFallback: true})`, which
already answers this question for branch-scoped review routing — two analogous
decisions must not use two different rules.

Costs stay on the rare paths: the branch directory is read once (a manager
creator is already in it), the creator is looked up individually only when the
branch list does not contain them (in practice an **admin** creator, who is
branchless and can never appear in a branch query), and the org-wide read for
tier 3 happens only when tiers 1 and 2 both come up empty.

Two behaviours worth keeping straight:

- **An empty result is passed through as an empty override, not as null.**
  `NotifyTaskEvent` reads a non-null empty list as "we looked and there is
  nobody". A null would fall back to `[createdBy]`, and an *assignee* fallback
  would tell the person who just submitted the work that it had been submitted.
- **An admin sitting in a branch list does not satisfy tier 2.** Tier 3 is the
  only door for admins, so the escalation stays explicit.

Pinned by `test/task_review_routing_test.dart` (the rule + the use case's read
pattern) and `test/task_submitted_recipients_test.dart` (that `TaskCubit`
actually consults it).

### The bulk actions are swept, not fanned out

**Mark all read** and **Clear archived** both go through one paged sweep: 300
documents per page over the existing `recipientUid + createdAt` index, one
`WriteBatch` per page, newest first, `startAfterDocument` as the cursor. **No new
index, no deploy.**

The paging is separated from Firestore on purpose. The **driver** —
`sweepPages` in
[`notification_sweep.dart`](../../lib/features/notifications/data/datasources/notification_sweep.dart)
— owns cursor advancement, page-boundary arithmetic, termination and the
ceiling, and is generic over the page item so it never inspects a document. The
datasource supplies only the query and the batch. That split is what makes the
risky half testable: `test/notification_sweep_test.dart` exercises it over
5,000- and 15,000-item collections, across page boundaries, and with a commit
that *deletes* what it touched — and it caught a real off-by-one, where a
collection ending exactly on the ceiling was reported as "too many" after having
successfully finished.

Three invariants it pins, each corresponding to a way the old code failed:

- **the page size is the batch ceiling** — no batch can approach Firestore's
  500-operation cap, because a batch is only ever one page's selected items;
- **the cursor advances off the last item *fetched*, not the last committed** —
  a page where nothing matched still moves forward, and a delete sweep does not
  re-read the window it just emptied;
- **the ceiling trips only when work remains** — checked after the fetch, so
  finishing exactly on the boundary is a success, not a false alarm.

Each replaced a broken implementation, and both failures were invisible:

| | Was | Failed at | Looked like |
|---|---|---|---|
| **Mark all read** | one unbounded read + **one** `WriteBatch` | **500 unread** — Firestore's hard batch cap | the button silently stopped working, forever (the error was swallowed into a log) |
| **Clear archived** | client-side fan-out over the **loaded page** | **> one page** archived (30 by default) | confirm "delete all", watch the list refill, conclude it is broken |

Consequences that are now part of the contract:

- Both are **`NetworkGuard`-guarded**. They read pages to decide what to touch,
  and offline those pages come from a partial cache — so they would act on a
  subset while reporting success.
- Both **report failure** (they return a message; the screen snackbars it). A
  bulk action that silently does nothing is indistinguishable from one that
  worked, which is how the 500-cap failure hid.
- The sweep has a **15,000-document ceiling** (50 pages) and **throws** when it
  is exhausted rather than returning quietly — the caller promised the user
  "all", and a silent partial is the exact defect being fixed.
- `markRead` (single) is deliberately **not** guarded — see the impl comment: it
  is a set-once idempotent receipt whose only consumer is a null check, and
  guarding it would make opening a notification fail offline on a screen the
  offline policy keeps readable.

### Token lifecycle
- `registerToken(uid)` on sign-in / app start (Apple: waits for the APNS token
  before `getToken()`); `onTokenRefresh` rotates in place; `forgetUser()` removes
  this device's token on sign-out.
- Tokens are **exclusive** — `claimFcmToken` (a `users/{uid}` update trigger)
  reclaims a token from any prior owner so a shared device never leaks pushes.

---

## 4. Deep-link routing

**One resolver, both tap surfaces.** `resolveNotificationRoute` in
`lib/features/notifications/domain/notification_deep_link.dart` is a pure,
role-aware function fed by BOTH the in-app tile (`NotificationEntity.payload`)
and the FCM push handler (`RemoteMessage.data`). It returns the concrete
`go_router` location, or `null` when there's no safe destination for this
recipient — a **guarded no-op**. The caller falls back safely (in-app: stay on
the inbox; FCM: open the inbox). **Navigation never crashes** on a stale,
unknown, or unauthorized notification.

| `route` | Payload id | Resolves to | Fallback |
|---------|-----------|-------------|----------|
| `task_details` | `taskId` | `/task/:taskId` | role task list, else `null` |
| `broadcast_detail` | `broadcastId` | `/communications/:id` (admin/manager only) | `null` (employees / no id) |
| `schedule` | `swapId` | role schedule (`/my-schedule`, …) | `null` if role unknown |
| `case_details` | `caseId` | `/case/:caseId` | `/cases` |
| `request_details` | `requestId` | `/request/:requestId` | `/requests` |
| `attendance` | `recordId` | `/attendance/record/:id` | `/attendance/review` (admin·manager) · `/attendance/history` (employee) · `null` if role unknown |
| `sales_submission` | `salesSubmissionId` | `/sales/submission/:id` | `/sales` (admin·manager) · `/sales/mine` (employee) · `null` if role unknown |
| `sales_target` | *(none — `monthKey` is context)* | `/sales` (admin·manager) · `/sales/mine` (employee) | `null` if role unknown |
| *unknown / null* | — | — | `null` (caller opens the inbox) |

> **`attendance` was a dead tap until 2026-08-01.** `writeAttendanceNotifications`
> has always stamped `route: "attendance"`, but the resolver had no case for it,
> so every correction-filed / decided / auto-closed notification fell through to
> the `default` → `null` and the tile did nothing when tapped. The row above is
> the fix; covered by `test/notification_deep_link_test.dart`. **The in-app tap
> works with the app build — no deploy needed.** The push tap needs the other
> half: `onNotificationCreated` was also dropping `recordId` / `correctionId`
> from the push `data`, now forwarded — ⚠️ **inert until
> `firebase deploy --only functions`**, until which a *background/cold-start*
> attendance tap lands on the ledger fallback instead of the exact record.

> **Branch sales (2026-08-06).** `writeSalesNotifications` stamped one route
> (`sales_submission`) for all five sales events, so a **month** event ("Your
> branch monthly sales target was updated" / "…target achieved") arrived with a
> route that promises a record and no id to open it with. It now writes
> `sales_target` when there is no `salesSubmissionId`; the id-less
> `sales_submission` case is kept and resolves identically, so the notifications
> already sitting in every inbox do not go dead when the function rolls. The
> push half was the real break: `onNotificationCreated` never forwarded
> `salesSubmissionId`, so a *New sales submission* tapped from the OS reached the
> branch dashboard and never the record to review. ⚠️ **Both halves are inert
> until `firebase deploy --only functions`.**

Route strings are the shared contract, centralized as `NotificationRoute.*` and
referenced by the client producers. **The server producers (`functions/index.js`)
and the FCM push `data` block must mirror these exact strings and forward every
id the resolver reads** — `taskId · caseId · requestId · broadcastId · swapId ·
recordId · salesSubmissionId · conversationId`. `chat_message` is the exception:
it is produced by the NestJS chat backend, not by `functions/index.js`.
(A missing id in the push `data` silently breaks the deep link on a background /
cold-start tap while the in-app inbox keeps working, because the inbox reads the
Firestore payload directly — that asymmetry is why it goes unnoticed. This pass
fixed `salesSubmissionId`; an earlier one fixed `requestId` + `swapId`.)

**Broadcast deep-link self-resolve:** `BroadcastDetailScreen` fetches the single
broadcast by id (`BroadcastRepository.getBroadcast`) when the Communications feed
isn't loaded, so a notification tap opening `/communications/:id` cold shows the
real message instead of "Broadcast unavailable".

---

## 4b. The inbox row (2026-08-01)

**`title` is a label, `body` is the content — and the row is built that way.**
Every producer, client (`NotifyTaskEvent`) and server (`functions/index.js`)
alike, writes the **event type** into `title` via a pure `switch (type)`, and the
**subject** into `body`. `title` therefore carries no information the `type`
doesn't; it is a label, never content.

```
[glyph]  NEW TASK ASSIGNED            41m ●   ← kicker  = title, 10px uppercase, semantic tint
         Restock the front cooler              ← subject = body, 14.5px, ONE LINE
         Due today 2:59 PM                     ← context = body's tail, 12px grey
```

| Rule | Why |
|------|-----|
| The **subject leads**; `title` is demoted to the kicker | Rendering `title` as the headline made the loudest line the one guaranteed to repeat — three assigned tasks read identically |
| The subject holds **one line**, never wraps | A wrapping headline gives every card a different height; the column reads ragged |
| `splitNotificationBody` cuts `body` on its **first** ` • ` / ` — ` | Producers already use these to hang context off a subject; no separator → all subject |
| **Every producer must name its subject in `body`** | A body that only restates the event ("Task approved") leaves a row that names nothing |
| **Case, request, and attendance notifications lead with their specific subject** | Case status notices use the case subject; requests use `lastEventPreview`, falling back to `refCode`; attendance uses a compact `Shift, d Mon` label. The event/result follows the first separator. Case notices remain identity-free. |
| No per-card category badge | The filter pills own category; the kicker's tint carries what the pill meant |
| The unread dot is **always white** | It means "unread" and nothing else — the kicker owns semantic colour |
| `navigable: false` → the subject is set as **reading text**, not a headline, and has no line cap | With nowhere to tap, the row *is* the message, not a pointer to it; employees therefore can read a complete broadcast in the inbox. Navigable subjects remain one line. |

> Widget tests must find a tile by `find.byType(NotificationTile)`, **not** by
> its title text — the kicker is uppercased.

---

## 5. Notification model

`notifications/{id}` — one doc per recipient.

| Field | Type | Notes |
|-------|------|-------|
| `id` | string | == doc id |
| `recipientUid` | string | the reader; drives the read rule + the `recipientUid + createdAt` index |
| `senderUid` | string? | server-stamped; empty for system/confidential |
| `type` | string | `NotificationType.value` (enum name) |
| `title` / `body` | string | length-capped (120 / 500) |
| `createdAt` | Timestamp | server timestamp on create |
| `readAt` | Timestamp? | null = unread |
| `archivedAt` / `pinnedAt` | Timestamp? | inbox lifecycle |
| `payload` | map | deep-link ids + `route`; typed getters on the entity |
| `pushedByFunction` | bool? | broadcast docs — suppresses double-push |

`NotificationType` values all have a **live producer** (task lifecycle · reminders ·
broadcasts · swaps · cases · requests · attendance · sales). Adding a type requires
adding its producer in the same change.

> **A type the enum doesn't know is not a no-op — it is a lie.**
> `NotificationModel.fromMap` used to fall back to **`taskAssigned`** for an
> unknown `type`. That is not a neutral default: `type` drives the glyph, the
> category pill *and* the priority ordering. The sales workflow shipped writing
> `type: "salesSubmission"` with no matching enum value, so for its whole life
> every branch-sales notification took that fallback and *impersonated a task* —
> a clipboard glyph, filed under the **Tasks** pill, ranked `high` above
> genuinely overdue work.
>
> Adding the `salesSubmission` value (2026-08-06) fixed the symptom. The
> **mechanism** was fixed the same day by `NotificationType.unknown`:
>
> - `fromMap` resolves an unrecognised (or missing) `type` to `unknown` — never
>   to a real type. `fromString` still returns `null`, because "I don't
>   recognise this" is the honest answer and the caller decides what to do.
> - `unknown` ranks [`low`] — the floor. It can never outrank real work.
> - It shows under **All** and under **no pill** (`categoryOf` returns `null`
>   for it, and `NotificationCategory.matches` short-circuits). Filing it
>   anywhere would repeat the original defect; inventing an "Other" pill would
>   add a filter for a type no producer writes.
> - It renders a neutral bell with no semantic accent, and its stored
>   `title`/`body` show in full — so it is still **readable**.
> - **It still deep-links.** Routing keys off `payload.route`, never `type`, so
>   a notification from a newer server build opens the right screen regardless.
>
> This matters because the *correct* deploy order is functions-first, then the
> client build — which guarantees a window where the server writes types the
> installed app has never heard of. `unknown` makes that window honest instead
> of misleading.
>
> **Whenever a producer stamps a new `type` string, still add the enum value in
> the same change.** `unknown` is a safety net, not a substitute — a real type
> gets a real pill, glyph and priority. Pinned by
> `test/notification_model_test.dart` + `test/notification_grouping_test.dart`
> (including a case asserting every type *except* `unknown` has a category, so
> the next value cannot silently land in `null`).

### Automated-tasks types (spec §9)

| Type | Producer | Routed to |
| --- | --- | --- |
| `taskCancelled` | client — `TaskCubit.cancelTask` | the assignee(s); for a shift broadcast, the **rostered crew** (nobody rostered = no recipients, which is valid) |
| `taskReportedIncorrect` | client — `TaskCubit.reportTaskIncorrect` | the reporter's **branch managers** |
| `taskMissed` | **server** — `autoEndRecurringShiftTasks` | the branch's managers, falling back to admins when a branch has none |

`taskCancelled` and `taskReportedIncorrect` are in `CLIENT_NOTIFICATION_TYPES`
(a manager cancels and an employee reports from the app). **`taskMissed` is
deliberately absent from that whitelist** — the sweep is its only writer, and
manager routing needs a role lookup no client should perform. Its ids are
deterministic (`taskmissed_{taskId}_{uid}`), so a retried sweep cannot
double-notify.

> **No notification on Late** (§9.4). It is a passive visual; alerting on every
> deadline crossing is noise, and the noise is what makes people stop reading
> the alerts that matter.

### Reminder eligibility

`runTaskReminders` skips `approved`, `missed`, and `cancelled` tasks because
they are closed, and also skips `rejected`: lifecycle-wise rejected remains open
for rework, but the reviewer owns the next move, so reminding the assignee is
noise. `pending` and `started` tasks remain eligible.

---

## 6. Release / deploy checklist (this pass)

The app-side configuration below is complete, and all four gates pass
(`flutter analyze` clean · `flutter test` 1398/2 pre-existing · Cloud Functions
72 · Firestore rules 53). The following require **your machine / accounts** to
take effect:

- [ ] **Deploy Cloud Functions** — the push-data fix lives server-side:
  `firebase deploy --only functions:onNotificationCreated`
  (or all functions). Until deployed, request/swap push taps still lack their id.
- [ ] **Android** — `POST_NOTIFICATIONS` + `INTERNET` are declared and FCM maps
  notifications to the named high-importance `drop_default` channel, created at
  app start. Rebuild the app; on Android 13+ confirm the OS prompt and a push on
  physical hardware. A monochrome notification icon remains owner design work.
- [ ] **iOS** — app-side configuration is complete: `Runner.entitlements` has
  `aps-environment`, all Runner configurations sign it, and `remote-notification`
  is declared. Delivery awaits the APNs credential. Foreground OS presentation
  stays **enabled** (the Apple foreground surface); no native delegate is
  installed, which is why chat yields its in-app banner on Apple rather than the
  OS banner yielding per-message.

---

## 7. Known limitations / future

- **Unread badge counts the loaded window** (≤ page size, grows with pagination).
  At pilot scale unread rarely exceeds a page; a dedicated count query was
  intentionally not added (avoids a second listener). Revisit if needed.
- **Community Event notifications** — the `community` feature and `/event/:eventId`
  route exist, but there is no `communityEvent` `NotificationType` or producer
  yet. The resolver is the extension point (add a `event_details` case + its
  producer together).
- **iOS push credential** — app-side setup is complete; delivery awaits the
  APNs credential. See the checklist.
