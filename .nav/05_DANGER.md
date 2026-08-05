# ⚠️ 05 · DANGER MAP — invariants, source-of-truth, do-not-touch

Read this before editing anything load-bearing. Each entry: **what it is · what breaks · the rule.**

## 🧠 Source-of-truth registry (the canonical owner of each fact — never fork these)

| Fact | 🧠 Single owner | Never duplicate it in… |
|---|---|---|
| How anything is constructed/wired | `lib/core/di/injection.dart` (`AppDependencies`) | ad-hoc `new` in screens |
| Navigation + auth/role gate | `lib/core/routes/app_router.dart` `_redirect` + guards | scattered `if (role)` nav checks |
| Route strings | `lib/core/routes/route_names.dart` | hard-coded path literals |
| How a page is pushed / how the user gets back | `lib/core/routes/app_page_route.dart` (`appPageRoute`) | a hand-rolled `PageRouteBuilder` (silently loses the iOS swipe-back) |
| Where a notification tap lands **and its back stack** | `notifications/presentation/notification_navigation.dart` | a bare `go`/`push` from a tap handler |
| Backend security | `firestore.rules` / `storage.rules` | client-side "trust" |
| Privileged writes | `functions/index.js` (🖥️) | client writing server-owned fields |
| Date → String formatting | `lib/core/utils/app_date_formatter.dart` | inline month arrays (18 were deleted — don't re-add) |
| Worked-minute / attendance math | `attendance/domain/attendance_calculator.dart` | recomputing minutes in a widget |
| Notification tap routing | `notifications/.../notification_deep_link.dart` `resolveNotificationRoute` | per-caller route logic |
| FCM token ownership | `functions/index.js` `claimFcmToken` (🖥️ one-owner) | client self-healing tokens |
| Task status transitions | `task` repository `transitionTask` (txn) | splitting status + activity into 2 writes |
| Media upload | `core/media/media_upload_service.dart` | a second Storage `putFile` path |
| Data-model contract | `docs/design/DATA_MODEL.md` (+ `firestore.rules`) | — |

## 🔥 Top invariants (violate these and production breaks)

### 1. Firestore rules: optional default is `null`, never `''`
Models emit **every** key, so an unset optional arrives **present-with-null**.
```
✅ get(data, 'field', null) == null
🚫 get(data, 'field', '')  == ''      // this DENIED EVERY TASK CREATE in production
```
Any rule change → add a case in `firestore-tests/` (emulator harness).

### 2. Server-authoritative writes (ADR-005)
Times, derived events, applied corrections, FCM sends, notification fan-out, swap approval, account
creation — the **Function owns the write**, rules lock the client out. Don't move this logic client-side to
"make it faster". 🖥️ marks these in [`03_DATA_MAP.md`](03_DATA_MAP.md).

### 3. `_redirect` is pure & synchronous
`app_router.dart` `_redirect` must **never `await`**. A blocked redirect stalls *all* navigation.
Error/initial auth states must **not** redirect (an in-flight action would be interrupted).

### 4. Status transitions are single atomic writes
Never split a task status change and its activity-log append into two writes (caused a double-write bug).
Use the repository transition seam. Freeze review fields + non-decreasing `activityLog` in rules.

### 5. Cancelled counts NOWHERE
For automated/recurring tasks: **Cancelled is never summed with Missed**, never wears the error-red that
Missed wears, and **nothing may ever compute Missed + Cancelled**. (Automated-tasks frozen spec.)

### 6. Grace period is on the CLOSE, not the deadline (ADR-013)
Fixed global **30-min** grace before a task becomes *Missed*. **Late still fires at the raw deadline.**
Not configurable. There is no "Completed-Late" state.

### 7. Chat is not Firebase
Direct chat lives on the **NestJS API** + **Drift** cache. REST = truth, socket = delivery only.
⚠️ **Never cache image bytes** in Drift. Never fabricate presence. Imports in chat are confined to
`dio` · `socket_io_client` · `drift`.

### 8. A pushed page must carry the iOS swipe-back
Every screen keeps its app-bar back button; on iOS the native left-edge swipe works **in addition** to it.
The gesture exists only on Cupertino routes, so push pages with `appPageRoute`
(`core/routes/app_page_route.dart`) or route them in `app_router.dart` (iOS gets a `CupertinoPage`).
A hand-rolled `PageRouteBuilder` silently loses the swipe — nothing looks broken, the app is just
inconsistent. Android/desktop unchanged. Pinned by `test/back_navigation_contract_test.dart`.

### 9. A notification tap must never `go` to a leaf page
`go` replaces the whole stack, so the page becomes the only route: it cannot pop, only the three role
shells carry the bottom nav, and the user is stuck. Every tap goes through `openNotificationDeepLink`
(or `openChatDeepLink`), which does `go(home)` **then** `push(target)`.
⚠️ And never read `router.state` from a tap handler — a cold-start tap runs before the router attaches,
where it throws `Bad state: No element` and kills the navigation. Use
`router.currentLocationOrNull` / `router.whenReady` (`core/routes/router_extensions.dart`).
Pinned by `test/notification_tap_navigation_test.dart`.

## 🚫 Do-NOT-EDIT / handle-with-care

| Path | Why |
|---|---|
| `**/*.freezed.dart`, `**/*.g.dart` | 🚫 generated — edit the source, run `build_runner` |
| `lib/firebase_options.dart` | 🚫 generated by FlutterFire |
| `build/`, `node_modules/`, `functions/node_modules/` | 🚫 artifacts |
| `docs/design/AUTOMATED_TASKS_PRODUCT_SPEC.md` | **FROZEN** product spec |
| `docs/decisions/ADR-*.md` | append a *new* ADR to reverse one; don't rewrite history |
| Schedule **mobile** UI (My Week) | owner-FROZEN 2026-07-07 — in-language improvements only |
| Task card border/animation | ADR-014, owner-signed — "work on it more" means *enrich*, not simplify |
| Admin Dashboard V2 | owner-signed-off & CLOSED |

## 🧨 High-blast-radius edits (grep all callers first)

| If you touch… | It hits… |
|---|---|
| `lib/core/widgets/*` (43 shared) | every feature using that primitive |
| `lib/core/enums/user_role.dart` | dozens of exhaustive `switch`es + rules + functions |
| any `*_status.dart` enum | UI colour maps, rules, functions, tests |
| `firestore.rules` | every read/write live in prod — deploy carefully, test in emulator |
| `AppDependencies.init()` | app boot — a throw here = white screen |
| `MediaUploadService` | task + case + request + chat uploads |

## ✅ Owner engineering discipline (memory: feedback_working_rules)

Before you change anything, state: **(1) classification** — bug / polish / refactor / feature; and
**(2) risk** — LOW / MED / HIGH. **Stability > perfection** (a 90% fix with zero regressions beats a 100%
fix that risks them). **Guard intentional/previously-debated UX.** No needless abstraction. Operational
impact first. Product is a **premium lean internal ops tool — NOT Jira/Slack/Linear.** Default to deletion,
signal over volume, simple over clever.

Next: [`06_REVERSE.md`](06_REVERSE.md) — start from a file instead of an intent.
