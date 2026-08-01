# 🗺️ 01 · THE WORLD MAP

The whole app on one screen. Every row links to a full location card. Sizes are live file counts.

## The layer cake (read bottom-up = how data arrives, top-down = how a tap travels)

```
┌───────────────────────────────────────────────────────────────────────────┐
│  main.dart → AppDependencies.init() → createRouter()                        │  boot
├───────────────────────────────────────────────────────────────────────────┤
│  PRESENTATION   pages · cubits(Bloc/Cubit + freezed state) · widgets       │  Flutter UI
│                 lib/features/*/presentation/     +  lib/core/widgets/ (43)   │
├───────────────────────────────────────────────────────────────────────────┤
│  DOMAIN         entities(freezed) · usecases(43) · repository CONTRACTS      │  pure Dart, no Firebase
│                 lib/features/*/domain/                                        │
├───────────────────────────────────────────────────────────────────────────┤
│  DATA           repository IMPLs · datasources · models(fromJson/toJson)     │  the wiring
│                 lib/features/*/data/                                          │
├───────────────────────────────────────────────────────────────────────────┤
│  BACKEND        Firestore (27 collections) · Cloud Functions (23) ·          │  🖥️ server-authoritative
│                 Storage · NestJS chat API   ·  firestore.rules / storage.rules│
└───────────────────────────────────────────────────────────────────────────┘
```

**Golden dependency rule:** `presentation → domain → data`. Domain imports **nothing** from Flutter or
Firebase. `core/` never imports a `feature/`. A feature never imports another feature's `data/` or
`domain/` internals — cross-feature reuse happens through `core/` or through a public cubit exposed in DI.

## 📍 Feature atlas (18 slices)

| Feature | Files | What it owns (one line) | Backend | Card |
|---|--:|---|---|---|
| **task** | 101 | Tasks: create/assign/transition, work-types, recurrence, templates, proof upload | `tasks` `task_templates` `recurringTaskTemplates` `taskReminders` + 4 fns | [→](features/task.md) |
| **chat** | 56 | Direct 1:1 staff chat — **on the external NestJS API, not Firebase** ↕️ socket | NestJS + Drift local cache | [→](features/chat.md) |
| **schedule** | 55 | Weekly schedule grid, shift assignment, shift swaps, shift templates | `weekly_schedules` `shift_swaps` `shift_templates` + `approveSwap` | [→](features/schedule.md) |
| **attendance** | 54 | GPS clock-in/out, corrections/approvals, history ledger, auto-close | `attendance` `attendance_corrections` + 3 fns | [→](features/attendance.md) |
| **communications** | 38 | Broadcasts (compose/templates/schedules) to staff audiences | `broadcasts` `broadcastTemplates` `broadcastSchedules` + fns | [→](features/communications.md) |
| **cases** | 31 | Case management — private employee↔manager conversations ↕️ | `cases` + `messages` subcol + 3 `onCase*` fns | [→](features/cases.md) |
| **requests** | 29 | Employee approval requests (NOT ticketing) — file → manager decides | `requests` + `events` subcol + 3 `onRequest*` fns | [→](features/requests.md) |
| **auth** | 28 | Login, first-login gates, password, profile-completion, account provisioning | `users` + `createUserAccount`/`adminResetPassword`/`claimFcmToken` | [→](features/auth.md) |
| **admin** | 22 | User administration: managers/employees/pending approval | `users` (shared) | [→](features/admin.md) |
| **profile** | 17 | User profile view/edit, avatar/cover upload | `users` (shared) | [→](features/profile.md) |
| **notifications** | 16 | In-app inbox + FCM tap routing (deep-link resolver) | `notifications` + `sendNotification`/`onNotificationCreated` | [→](features/notifications.md) |
| **branch** | 13 | Branch directory, branch identity/media (cover/logo) | `branches` | [→](features/branch.md) |
| **operations** | 12 | Branch Operations screen + the Automation Center (automated tasks) | `automationRuns` + `generateShiftTaskInstances` | [→](features/operations.md) |
| **statistics** | 11 | Role dashboards (admin/manager/employee KPIs) | `usageStats` (read) | [→](features/statistics.md) |
| **audit** | 7 | Audit-log write seam + event tracking | `audit_logs` | [→](features/audit.md) |
| **settings** | 2 | Settings shell (delegates to profile/auth/notifications) | — | [→](features/settings.md) |
| **employee** | 2 | Employee role home shell | — (composes task/schedule) | [→](features/employee.md) |
| **manager** | 2 | Manager role home shell | — (composes task/schedule) | [→](features/manager.md) |

> **Tiny features (`employee`, `manager`, `settings`) are shells** — they compose widgets from the
> big features. Start in the big feature, not the shell.

## 🧱 The `core/` layer (shared, feature-agnostic — 15 folders)

| Folder | Owns | Go here to change… |
|---|---|---|
| `core/di` | `injection.dart` = `AppDependencies` | how anything is constructed/wired |
| `core/routes` | `app_router.dart`, `route_names.dart` | navigation, auth redirect, role guards |
| `core/theme` | colors, typography, design tokens (5 files) | look & feel (monochrome — see ADR-004) |
| `core/widgets` | 43 shared primitives (cards, empty-states, chrome) | reusable UI used across features |
| `core/enums` | 35 enums (task/attendance/case/… statuses) | any status/type vocabulary |
| `core/media` | `MediaUploadService` (one Storage upload seam) | any image upload path |
| `core/network` | `ApiClient`, `NetworkConfig` (NestJS seam) | the external chat API transport |
| `core/services` | `NotificationService`, seen-stores | FCM, task/case "seen" state |
| `core/utils` | `AppDateFormatter` (🧠 the only Date→String) | any date/time formatting |
| `core/observability` | `AppLog` | logging |
| `core/errors`, `core/extensions`, `core/responsive`, `core/config`, `core/constants` | cross-cutting helpers | — |

## 🌍 Backend at a glance

- **Firestore:** 27 top-level collections + subcollections (`cases/*/messages`, `requests/*/events`,
  `attendance/*/events`, `users/*/private`). Contract lives in `docs/design/DATA_MODEL.md`; rules in `firestore.rules`.
- **Cloud Functions:** 23 exports. `functions/index.js` (most) + `attendance_auto_close.js`,
  `automation_run.js`, `recurring_task_deadline.js`. Full map: [`03_DATA_MAP.md`](03_DATA_MAP.md).
- **External API:** the **chat** feature only — NestJS (`drop-api` repo), Bearer-token REST + Socket.IO.
  Everything else is Firebase.

## 📚 Where the *decisions* live (why things are the way they are)

- `docs/decisions/ADR-001..016` — the 16 architecture decision records (Firebase, Cubit-only,
  clean-architecture, monochrome, server-authoritative writes, requests-are-approvals, lean-over-enterprise, …).
- `docs/design/*.md` — 16 frozen product/design specs (one per major feature).
- `PROJECT_CONTEXT.md` / `CURRENT_STATE.md` / `CHANGELOG.md` (repo root) — treated as source code; read first.

Next: [`02_ENTRYPOINTS.md`](02_ENTRYPOINTS.md) to trace any user action to its backend.
