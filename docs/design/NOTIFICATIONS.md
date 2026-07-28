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
  → an in-app snackbar with a **"View"** action that deep-links via the shared
  resolver (§4). A foreground push is never a dead end.
- **Background tap** (`onMessageOpenedApp`) → `onMessageTap(data)` → resolver → push route.
- **Terminated / cold-start** (`getInitialMessage`) → same `onMessageTap`.
- **In-app tile tap** → `NotificationsScreen._deepLink` → **the same resolver**.

`pushedByFunction:true` on broadcast docs prevents `onNotificationCreated` from
double-pushing (the broadcast engine already pushed inline).

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
   re-emits; no optimistic write. `markAllRead` batches every unread doc.
4. **Archive** — `archivedAt` set/cleared (hidden from the default inbox, kept
   for history). `pinnedAt` similarly.
5. **Delete** — the recipient (or an admin) hard-deletes the doc.

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
| *unknown / null* | — | — | `null` (caller opens the inbox) |

Route strings are the shared contract, centralized as `NotificationRoute.*` and
referenced by the client producers. **The server producers (`functions/index.js`)
and the FCM push `data` block must mirror these exact strings and forward every
id the resolver reads** — `taskId · caseId · requestId · broadcastId · swapId`.
(A missing id in the push `data` silently breaks the deep link on a background /
cold-start tap; this pass fixed `requestId` + `swapId` being omitted.)

**Broadcast deep-link self-resolve:** `BroadcastDetailScreen` fetches the single
broadcast by id (`BroadcastRepository.getBroadcast`) when the Communications feed
isn't loaded, so a notification tap opening `/communications/:id` cold shows the
real message instead of "Broadcast unavailable".

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
broadcasts · swaps · cases · requests). Adding a type requires adding its
producer in the same change.

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

---

## 6. Release / deploy checklist (this pass)

Code changes verified with `flutter analyze` (clean on touched files) and
`flutter test` (all notification tests pass). The following require **your
machine / accounts** to take effect:

- [ ] **Deploy Cloud Functions** — the push-data fix lives server-side:
  `firebase deploy --only functions:onNotificationCreated`
  (or all functions). Until deployed, request/swap push taps still lack their id.
- [ ] **Android** — `POST_NOTIFICATIONS` + `INTERNET` are now declared in
  `AndroidManifest.xml`. Rebuild the app; on Android 13+ confirm the OS prompt
  appears and a push shows on a physical device.
- [ ] **(Optional, Android polish)** a named default channel + monochrome
  notification icon need `flutter_local_notifications` (or a `drawable`); left
  out to avoid referencing an asset nothing creates. FCM's auto default channel
  is used meanwhile.
- [ ] **iOS (deferred — separate task)** push is **not configured**: no
  `.entitlements`, no `aps-environment`, no `remote-notification` background
  mode. iOS cannot receive push until this is added and signed in Xcode with the
  Apple account (needs an APNs key in the Firebase console too).

---

## 7. Known limitations / future

- **Unread badge counts the loaded window** (≤ page size, grows with pagination).
  At pilot scale unread rarely exceeds a page; a dedicated count query was
  intentionally not added (avoids a second listener). Revisit if needed.
- **Community Event notifications** — the `community` feature and `/event/:eventId`
  route exist, but there is no `communityEvent` `NotificationType` or producer
  yet. The resolver is the extension point (add a `event_details` case + its
  producer together).
- **iOS push** — see the checklist. The single biggest remaining pilot gap.
