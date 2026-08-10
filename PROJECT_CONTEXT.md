# DROP — Project Context

> **How DROP is built.** Architecture, module map, and the conventions every
> contributor (human or AI) must follow. Read this first; read nothing else unless
> the task needs it.

## The documentation set

Each document has **one** responsibility. A fact lives in exactly one of them.

| Document | Answers | Read it when |
| --- | --- | --- |
| **PROJECT_CONTEXT.md** (this) | How is this built? | Always, first |
| [.nav/](.nav/README.md) — **ATLAS** | *Where do I go / what breaks?* | Navigating or modifying code (esp. AI agents → [.nav/08_AI_PROTOCOL.md](.nav/08_AI_PROTOCOL.md)) |
| [CURRENT_STATE.md](CURRENT_STATE.md) | Where are we today? | Starting any task |
| [CHANGELOG.md](CHANGELOG.md) | What happened when? | You need history |
| [docs/design/](docs/design/) | How does *this feature* work? | Touching that feature |
| [docs/decisions/](docs/decisions/) | Why, and don't re-litigate | Proposing a change that reverses something |
| [docs/QA.md](docs/QA.md) | How do we verify a release? | Before shipping |
| [docs/RELEASE_V1.md](docs/RELEASE_V1.md) | What still blocks v1, in what order? | Planning or doing release work. **Temporary — delete when v1 ships** |

**If code and docs disagree, the code wins.** Verify against the code, then fix the
doc in the same task. Never leave a doc contradicting the code — that is how the
previous documentation set grew to 11,000 lines of partly-false claims.

---

## 1. What DROP is

**Drop Operation — Operations Management System.** An internal, role-based operations tool for
**DROP THE SHOP**: branches, shifts, tasks, attendance, approvals, and employee
activity. Three roles — **admin · manager · employee**.

The repository folder is **`Drop-operations`**. The Dart package remains `drop`
(valid package identifiers cannot contain a hyphen); platform-safe identifiers use
`dropoperation` where needed. Two user-facing names, split by surface: the **OS
label is `Drop Ops`** — the short name the operating system shows (iOS/Android
launcher label, macOS/Windows/Linux window & app-switcher title, and the
`MaterialApp` `title`). Everything **inside** the app keeps the full **`Drop
Operations`** — `AppConstants.appName`, the `DropWordmark` logotype, the splash
label, and all in-app copy (About, login, onboarding, notifications, schedule PDF
headers). Only user-invisible identifiers keep the short `drop`/`dropoperation`
forms; code comments still say "DROP" as shorthand.

It is **not** a social network, an ERP, an analytics engine, or a SaaS product. It
has no buyers, only users: a small, known set of people across a handful of
branches.

### Core philosophy

Read [ADR-010](docs/decisions/ADR-010-lean-over-enterprise.md) before proposing
anything large. In short:

- **Workflow over architecture. UX over feature count.**
- **Default to deletion.** The burden of proof is on keeping a feature, not cutting
  it. Schedule Health and the analytics pipeline were both deleted *after* shipping.
- **Simple > clever. Signal > volume.** No abstraction without a second caller.
- **Stability > perfection.** 90% complete with zero regressions beats 100% with
  risk.
- **Premium, not minimal.** Lean is about *count*, not *craft*.
- **Learn from mature products (Deputy, Connecteam, Sling); never copy them** —
  they solve a scale problem DROP does not have.

Classify every change (**bug / polish / refactor / feature**) and label its risk
(**LOW / MED / HIGH**). Lead with operational impact.

### Product shape

- **Admin-provisioned auth.** No public registration, no OTP, no Google sign-in.
  An admin creates accounts via the `createUserAccount` Cloud Function; the
  unauthenticated landing screen is **Login** only.
- **First-login gate**, in order: `mustChangePassword` → Force Password Change ·
  `!isProfileCompleted` → Profile Completion · (employees only)
  `!hasCompletedOnboarding` → one-time Welcome · then the role home. The ordering
  is the pure, unit-tested `firstLoginLocation(user)`.
- **admin ⊇ manager.** An admin can do anything a manager can, across every branch.

> Some legacy social fields (follower/post counters) linger in the profile schema
> from an earlier iteration. They are **unused** — do not build on them.

---

## 2. Tech stack

| Concern | Choice | Notes |
| --- | --- | --- |
| Language | Dart `^3.12.1` / Flutter | |
| State | `flutter_bloc` — **Cubits only** | [ADR-002](docs/decisions/ADR-002-cubit-only.md) |
| Navigation | `go_router` | Auth-aware redirects + role guards |
| Backend | Firebase: Auth · Firestore · Storage | [ADR-001](docs/decisions/ADR-001-firebase-backend.md) |
| Chat API (in progress) | NestJS over `dio` + Socket.IO (`socket_io_client`) | HTTP seam `core/network/api_client.dart`; realtime seam `features/chat/data/realtime/`; Firebase ID token as Bearer / handshake auth |
| Chat offline cache | `drift` (SQLite) + `sqlite3_flutter_libs` | The **only** SQLite in the app; confined to `features/chat/data/local/`. Never import `drift` elsewhere. Drift caches metadata; `ChatRepositoryImpl` session-caches brokered URLs until their server expiry; **never image bytes** |
| Server logic | Cloud Functions (Node.js, `functions/`) | 31 functions; see [DATA_MODEL](docs/design/DATA_MODEL.md) |
| Push | `firebase_messaging` | iOS app-side configuration is present; APNs credential remains — see CURRENT_STATE |
| Device session id | `flutter_secure_storage` | Keychain (iOS/macOS) / `EncryptedSharedPreferences` (Android, `resetOnError: true`). Holds **one** value — this device's single-active-session claim. Seam: `core/services/session_store.dart`; never import it elsewhere, and it is still **not** a place for preferences (those stay JSON files) |
| Android backup | disabled (`allowBackup=false`) | Firebase Auth persists its session in app SharedPreferences on Android (Keychain on iOS). Auto Backup would ship that store + the secure-storage claim — whose keystore master key can't be backed up — through backup/restore/Smart Switch, dropping the session on cold start (Samsung especially). See `android/app/src/main/AndroidManifest.xml` |
| Immutable models | `freezed` + `freezed_annotation` | Entities & states |
| Serialization | `json_serializable` | |
| Media | `image_picker` · `image_cropper` · `video_compress` | Mobile-gated |
| Open documents | `open_filex` | Chat document attachments → platform default app (desktop via OS `Process`); confined to `features/chat/` |
| Share exports | `share_plus` | Attendance/schedule export → OS share sheet; confined to `core/services/export_sharing.dart` |
| Location | `geolocator` | Attendance GPS |
| Codegen | `build_runner` | |

**Platforms:** iOS · Android · macOS. Desktop is a first-class target, not an
afterthought — see [§7](#7-ui-philosophy).

---

## 3. Architecture

**Clean Architecture, sliced by feature.** The dependency rule points **inward**:

```
presentation  →  domain  ←  data
```

```
features/<feature>/
├── data/            # The ONLY place Firebase exists
│   ├── datasources/ #   Talk to Firebase; throw *Exception
│   ├── models/      #   All serialization: toMap/fromMap, toEntity/fromEntity
│   └── repositories/#   Implement domain contracts; *Exception → *Failure
├── domain/          # Pure Dart. NEVER imports Flutter or Firebase.
│   ├── entities/    #   freezed business objects
│   ├── repositories/#   Abstract contracts
│   └── usecases/    #   One class per action, callable via .call()
└── presentation/    # Cubits, pages, widgets. Sees entities only.
```

`domain/` depends on nothing. This is why the full 1665-test suite runs in ~40
seconds with no Firebase and no live backend — business rules are pure functions.

Full rationale and costs: [ADR-003](docs/decisions/ADR-003-clean-architecture.md).

### Composition root

`main.dart` → `AppDependencies.init()` ([lib/core/di/injection.dart](lib/core/di/injection.dart))
wires every datasource, repository, use case, and cubit **by hand** — no DI package.

- **App-wide cubits** are provided in `main.dart` via `MultiBlocProvider`:
  `auth` · `profile` · `task` · `branch` · `adminUsers` · `statistics` · `schedule` ·
  `todayCoverage` · `shiftSwap` · `branchOperations` · `broadcast` ·
  `broadcastTemplate` · `broadcastSchedule` · `notification` · `caseList` ·
  `chatList` · `requestsList` · `attendance` · `attendanceAdmin` · `salesMonth`
  (Employee Home, both employee sales screens **and Manager Home** share it, so
  opening a sales page costs no extra reads and the surfaces cannot disagree
  about "today"; managers enter through `loadForBranch`, which drops the
  own-submissions stream).
- **Per-entity cubits** are built on demand by `AppDependencies.create*` —
  `createCaseConversationCubit`, `createRequestDetailCubit`.

### Cold start

`LaunchApp` in `main.dart` coordinates above the router. Flutter paints a black
frame first, then Firebase → DI → `AuthCubit.restoreSession()` → authoritative
user-doc read → home-critical preload, **in parallel** with `SplashPage` running the
launch intro. The routed app mounts only when **both** complete. `createRouter`
takes a resolved `initialLocation`, so no splash replay.

### Server-authoritative boundary

Anything a client must not forge is written by the Admin SDK — task transitions,
attendance audit, swap approval, account provisioning, broadcast sends. See
[ADR-005](docs/decisions/ADR-005-server-authoritative-writes.md) for the full table.

---

## 4. Module map

19 features in `lib/features/`. Detail lives in the linked design doc — not here.

| Module | Owns | Design doc |
| --- | --- | --- |
| `auth` | Sign-in, forgot/force password change, profile completion, Welcome, roles, **single active session** (one account = one signed-in device) | [AUTH](docs/design/AUTH.md) |
| `profile` | View/edit profile, image uploads, contact details. A **leaf of the Settings hub** — no navigation rows, no sign-out ([AUTH](docs/design/AUTH.md#the-account-hub-and-profiles-place-in-it)) | [AUTH](docs/design/AUTH.md) |
| `task` | Operations tasks: create → execute → review, templates and recurring automation | [TASKS](docs/design/TASKS.md) · [AUTOMATION](docs/design/AUTOMATION_ENGINE.md) |
| `schedule` | Admin Today coverage across branches, weekly roster, attributed swap approval/history, shift templates, leave, Final View | [SCHEDULE](docs/design/SCHEDULE.md) |
| `attendance` | GPS clock in/out, corrections, admin board, geofences | [ATTENDANCE](docs/design/ATTENDANCE.md) |
| `requests` | Employee → manager yes/no approvals | [REQUESTS](docs/design/REQUESTS.md) |
| `cases` | Private employee ↔ manager/admin conversations | [CASES](docs/design/CASES.md) |
| `chat` | Direct 1:1 staff chat over the NestJS API (**in progress** — inbox + thread UI + Socket.IO realtime (thread & inbox; room membership follows app lifecycle so push suppression is honest) + deletion + teammate picker + real profiles (avatar/name/role via Firebase directory) + **Drift/SQLite offline cache** (instant open, offline reads, background sync) + a once-per-launch unread hint banner + a Home Recent-Messages unread pill (no nav badge, by decision) + **durable per-viewer clear/delete** (a `chat_cleared_store` watermark hides a cleared conversation across refresh/restart until a newer message arrives — the list endpoint keeps reporting the old last message) + **inbox row options** (long-press / right-click → Delete conversation, a bulk `ClearChatForMe` delete-for-me + the watermark hide); REST is the source of truth) | — |
| `communications` | Broadcasts, templates, schedules, reminders | [COMMUNICATIONS](docs/design/COMMUNICATIONS.md) |
| `notifications` | Notification inbox + deep-link resolver + **in-app foreground banner** (`InAppNotificationHost`, a top banner for a push that arrives while the app is open; Android/others only — iOS uses its own OS banner) | [NOTIFICATIONS](docs/design/NOTIFICATIONS.md) |
| `operations` | Branch Operations cockpit: workload, KPI drills | [TASKS](docs/design/TASKS.md) |
| `admin` | User administration, Admin Home command center | [DESIGN_SYSTEM](docs/design/DESIGN_SYSTEM.md) |
| `branch` | Branch CRUD, geofences, swap policy, manager clock policy, **sales-target opt-in** | [ATTENDANCE](docs/design/ATTENDANCE.md) |
| `sales` | Per-branch monthly sales target, daily employee closes, manager approval, derived pace KPIs. Opt-in per branch (`branches/{id}.salesTargetEnabled`) | [SALES_TARGETS](docs/design/SALES_TARGETS.md) |
| `statistics` | Role-scoped counts powering all three dashboards | — |
| `audit` | `EventTrackingService` + audit log entities | [AUDIT_LOG](docs/design/AUDIT_LOG.md) |
| `manager` | ManagerShell + manager home | — |
| `employee` | EmployeeShell + employee home | — |
| `settings` | **The** account hub — the single door in (mobile app-bar avatar · desktop sidebar footer) and the only route to Profile. Security/workspace links, the app's **only** sign-out, About + change password, per-device notification switches (presentation-only) | [AUTH](docs/design/AUTH.md#the-account-hub-and-profiles-place-in-it) |

`manager`, `employee`, and `settings` are **presentation-only** — they reuse other
features' cubits.

### Core (`lib/core/`)

| Directory | Owns |
| --- | --- |
| `constants/` | `app_constants.dart` — app name, collection names |
| `di/` | `injection.dart` — the hand-wired service locator |
| `enums/` | Shared enums (`user_role`, `task_*`, `schedule_*`, `attendance_*`, …) |
| `errors/` | `exceptions.dart` (data) · `failures.dart` (domain) |
| `extensions/` | `context_extensions` (currentUser/role) · `firestore_extensions` (`map.date`) |
| `media/` | `MediaUploadService` — the **single** Storage seam for all attachments |
| `network/` | `ApiClient` — the single authenticated HTTP seam for the NestJS chat API (+ `NetworkConfig`). Consumed only by `features/chat/` |
| `observability/` | `CrashReporter` (4 funnels → persisted report) + `CrashContext` |
| `responsive/` | `breakpoints.dart` |
| `routes/` | `app_router.dart` (role dispatch + guards) · `route_names.dart` (59 routes) · `app_page_route.dart` (the back-navigation contract) · `router_extensions.dart` (navigating safely from outside the tree + reading where the user is) |
| `services/` | `notification_service.dart` (FCM) · `session_store.dart` (the device's single-active-session claim, keystore-backed) · `export_sharing.dart` (write + share an export via `share_plus`) · the local JSON stores: `case_seen_store.dart` · `task_seen_store.dart` · `notification_preferences_store.dart` · `chat_cleared_store.dart` |
| `theme/` | `app_colors` · `app_typography` · `app_spacing` · `app_radius` · `app_theme` |
| `utils/` | `validators` · `platform_capabilities` · `app_logger` · `app_date_formatter` · `concurrent` · `dashboard_mood` (the pure one-sentence dashboard state) |
| `widgets/` | Every cross-feature widget — see [§7](#7-ui-philosophy) |

**`core/` is feature-neutral except `app_shell.dart`, the existing
composition-boundary widget that reads auth/chat/notification state to render
authenticated desktop chrome.** Apply feature-specific behaviour at the call
site through an exposed hook (e.g. `AttentionTile.radius`), not inside a generic
primitive.

### Single-source seams

Reuse these. Do not re-implement or duplicate them.

| Concern | The one source |
| --- | --- |
| Any `DateTime` → string | `core/utils/app_date_formatter.dart` |
| Any Storage upload | `core/media/media_upload_service.dart` |
| Writing + sharing an exported file (PDF/CSV/PNG/XLSX) | `core/services/export_sharing.dart` (`writeExportFile` + `shareExportedFile`; never import `share_plus` elsewhere) |
| Any NestJS API call | `core/network/api_client.dart` (never import `dio` elsewhere) |
| Chat realtime (socket) | `features/chat/data/realtime/chat_socket_service.dart` (never import `socket_io_client` elsewhere; consume the `ChatRealtime` port) |
| Chat offline cache (SQLite) | `features/chat/data/local/` — `ChatDatabase` (Drift) + `ChatLocalDataSource` (never import `drift` elsewhere). Wired into `ChatRepositoryImpl` (optional; null ⇒ REST-only) + `ChatThreadCache`'s durable tier. Drift holds metadata only; the repository session-caches brokered attachment URLs through `ChatAttachmentDownload.isExpired`; **never image bytes** |
| Task status → colour | `core/widgets/status_badge.dart` (`taskStatusColor`) |
| Structured logging | `core/utils/app_logger.dart` (`AppLog`) |
| Any per-device, per-user preference or read-state | a small uid-namespaced JSON file in the app-support dir, in `core/services/` (`case_seen_store` · `task_seen_store` · `notification_preferences_store` · `chat_cleared_store`). **Never add `shared_preferences`** — the app already has one local-preference mechanism |
| Whether THIS device still owns the session | `core/services/session_store.dart` (`SessionStore`) + `users/{uid}.activeSessionId`. Enforced **only** in `AuthCubit.watchCurrentUser` — never re-check it in a feature ([AUTH](docs/design/AUTH.md#single-active-session)) |
| Tearing down user-scoped streams/caches on sign-out | `AppDependencies.clearUserScopedState()` (`core/di/injection.dart`), reached through `AuthCubit`'s `onPreSignOut` hook. A new app-wide cubit holding a live stream **must** add a `reset()` and be listed there, or its listener outlives the session |
| Shift slot timing | `schedule/domain/shift_window.dart` |
| Shift hours resolution | `WeeklyScheduleEntity.hoursFor` ([ADR-006](docs/decisions/ADR-006-schedule-shift-plan-snapshots.md)) |
| Worked/late/overtime minutes | `attendance/domain/attendance_calculator.dart` |
| Task visibility | `task/domain/task_access.dart` (`canUserAccessTask`) |
| Was a task made by a person or by the server? | `task/domain/task_origin.dart` (`taskOrigin`) — **never read `createdBy` for this**: a generated instance inherits its template's creator |
| Who reviews a task / who is told it was submitted | `task/domain/task_review_routing.dart` (`taskReviewRecipients` · `canReviewTask`) — **never `createdBy` alone**: that account can be deactivated, deleted, demoted or moved branch, and a generated instance inherits the *template's* creator. `canReviewTask` mirrors the `tasks` update rule; if they disagree, the rule wins |
| Naming an activity-event actor | `task/presentation/activity_format.dart` (`activityActorName` / `activityActorRole`) — `actorId: "system"` is not a uid and must not fall through to the directory |
| Notification routing | `notifications/domain/notification_deep_link.dart` |
| **What screen is the user actually on?** | `core/routes/router_extensions.dart` → `topLocationOrNull`. **Never** the match list's own `uri` (`currentLocationOrNull`): an imperative `push` does not rewrite it, and every chat/notification destination is reached by `push`, so the two disagree exactly when it matters. `currentLocationOrNull` remains the duplicate-push guard it was written for |
| Sidebar + command palette | `AppShell.sectionsForRole` |
| How a screen is pushed / how the user gets back | `core/routes/app_page_route.dart` (`appPageRoute`) |

---

## 5. Where to change things

> Act without scanning. Feature detail is in the design docs.

| To change… | Edit |
| --- | --- |
| A new action in any feature | `domain/usecases/` → repository contract + impl → datasource → cubit → **`core/di/injection.dart`** |
| Any entity or state shape | the `freezed` file, **then run codegen** |
| Routes / navigation guards | `core/routes/app_router.dart` + `route_names.dart` |
| **Any imperative `Navigator.push` of a page** | `appPageRoute` (`core/routes/app_page_route.dart`) — a raw `PageRouteBuilder` silently has no iOS swipe-back |
| Role chrome (bottom nav) | `core/widgets/role_scaffold.dart` + `app_bottom_nav.dart` |
| Desktop chrome (sidebar, ⌘K) | `core/widgets/app_shell.dart` + `app_sidebar.dart` + `command_palette.dart` |
| Colours / type / spacing / radius | `core/theme/` — never inline a `Color(...)` or `TextStyle(...)` |
| The typeface itself | `assets/fonts/` + the `fonts:` block in `pubspec.yaml` + `AppTypography.fontFamily` — all three, or the app falls back per platform |
| Connectivity / offline behaviour | `core/network/connectivity_service.dart` + `core/widgets/connectivity_scope.dart` — never trust the interface alone; the probe is the verdict |
| **Any new repository write** | start it with `NetworkGuard.ensureWritable()` (`core/network/network_guard.dart`) — without it, an offline write is cached, reported as success, and replayed silently an hour later |
| Any "nothing here" state | `core/widgets/app_empty_state.dart` · `drop_empty_state.dart` · `empty_state_medallion.dart` — never a bespoke circle + icon |
| Any failure or retry surface | `core/widgets/app_error_state.dart` (`AppErrorState` full-area · `AppProblemPanel` inline) — never an empty state with an error glyph |
| Any loading placeholder | `core/widgets/list_skeleton.dart` · `skeleton.dart` — a centred spinner only inside a button or sheet action |
| Global component styling | `core/theme/app_theme.dart` |
| Firestore / Storage security | `firestore.rules` · `storage.rules` → add a case in `firestore-tests/` → **deploy** |
| Server logic | `functions/index.js` → **deploy** |
| Collection names / in-app app name (`Drop Operations`) | `core/constants/app_constants.dart` |
| The **OS label** (`Drop Ops`) — launcher/window/app-switcher title | iOS `Info.plist` (`CFBundleDisplayName`/`CFBundleName`) + Android `AndroidManifest.xml` (`android:label`) + macOS `project.pbxproj` (`INFOPLIST_KEY_CFBundleDisplayName`) + Windows `Runner.rc` + Linux `my_application.cc` + both `MaterialApp` `title`s in `main.dart` — **all of them, or the name differs per platform** |
| DI wiring | `core/di/injection.dart` |
| App bootstrap / providers | `main.dart` |
| **Anything about who is signed in, or ending a session** | `features/auth/presentation/cubit/auth_cubit.dart` — including single active session ([ADR-023](docs/decisions/ADR-023-single-active-session.md)). **Never re-check the session inside a feature** |
| **A new app-wide cubit that holds a live stream** | give it a `reset()` **and** list it in `AppDependencies.clearUserScopedState()` — otherwise its listener outlives the session and the next user on the device sees the previous one's data |

---

## 6. Coding standards

Established across the codebase and **must be reused**.

### Folders & naming

- Feature-first: `features/<feature>/{data,domain,presentation}`.
- `snake_case.dart` files, one primary class each. Generated files sit beside their
  source as `*.freezed.dart` / `*.g.dart`.
- Classes `PascalCase`; members `camelCase`; private deps `_underscored`.
- Datasources `XRemoteDataSource` + `Impl`. Repositories `XRepository` + `Impl`.
  Use cases are a **verb phrase** (`SignInWithEmail`). Cubits `XCubit`, states
  `XState`, pages `XPage`, entities `XEntity`.

### Use cases

One class = one action. Stateless, holds only its repository, `const` constructor
taking it positionally, single `call(...)` method invoked as `useCase(...)`. Named
params when there is more than one.

### Repositories & datasources

- Contract in `domain/repositories`, impl in `data/repositories`.
- The impl depends on datasources only — **never on Firebase directly**.
- Wrap every datasource call in `try/catch`, converting `*Exception` → `*Failure`.
- Convert `Model → Entity` before returning. The rest of the app sees entities only.
- Datasources receive the Firebase SDK instance via constructor (injected in
  `injection.dart`), catch `FirebaseException`, and throw a domain-agnostic
  `*Exception` with a user-readable message.

### Cubits

- Extend `Cubit<XState>`; inject use cases (and the repository for streams) via a
  named-param constructor. Start at `XState.initial()`.
- Guard double-submits with a `_busy` getter inspecting current state.
- Emit **loading** → `await` → success or error. Carry an action discriminator on
  loading (`AuthState.loading(AuthAction.x)`) so only the triggering button spins.
- Catch `XFailure` → `XState.error(e.message)`; catch-all → a generic friendly
  message.
- For optimistic flows keep the last-known entity visible across transient states
  (`ProfileState.saving(profile)`), and on error re-emit `loaded(previous)` so the
  UI never flickers or loses data.
- **Cancel stream subscriptions in `close()`.**

### States, entities & models

- States are `freezed` unions; one factory per distinct UI state; success/transient
  states carry their data. Read with `maybeWhen` / `mapOrNull` / `maybeMap`.
- Entities are `freezed` in `domain/entities`, `@Default(...)` for non-null
  optionals, computed getters via a private `const X._()` constructor.
- Models own all (de)serialization, bridge `Timestamp ⇄ DateTime`, tolerate missing
  keys with defaults, and keep legacy keys in sync on write.
- Prefer **additive** schema changes — a new nullable field needs no migration.

### Codegen

After touching any `freezed` file:

```bash
dart run build_runner build --delete-conflicting-outputs
```

### Testing

- Pure domain functions are the unit of test. Inject `now` / `day` so they are
  deterministic.
- Widget tests must **unmount** anything driving a `Timer` (e.g. the live countdown
  pill) or the test hangs.
- `EntranceFade` needs a frame-pump before a timed pump.

---

## 7. UI philosophy

**Strictly monochrome, dark mode only.** `AppColors.primary` is **white** and is the
only accent. The only chromatic colours are semantic `success` / `error` / `warning` /
`info`, and they express **status only** (`info` is hairline-only — never a fill).

This is the single most re-litigated decision in DROP — read
[ADR-004](docs/decisions/ADR-004-monochrome-design.md) **before** proposing a brand
colour. (A brand accent on the Branch Sales figures was tried and reverted on
2026-08-07 — the ADR records it.)

- **Calm through hierarchy, not reduction.** DROP is premium, not minimal. A 4-step
  grey ramp (`FFFFFF` / `A7A7AF` / `6E6E77` / `48484E`) does the work colour would;
  **no two adjacent texts share a grey**.
- **Never replace a lived-in UI without sign-off.** "Work on it more" means
  *enrich*, not *simplify*. Motion is often load-bearing (`LiveStatusBorder`'s orbit
  is a spec, not decoration) — but **not perpetual**: on Employee Home it was
  replaced by a still, per-state 1px edge
  ([ADR-014](docs/decisions/ADR-014-task-card-border-language.md)) after the owner
  signed off on a mockup first. Two standing rules came out of that: **emphasis
  means unseen, never status**, and **nothing on a resting surface animates
  forever**.
- **One typeface, bundled.** `AppTypography.fontFamily` is the single source and
  both `ThemeData`s carry it. The face ships in `assets/fonts/` — never name a font
  that is not bundled, or the app silently renders in a different face per platform
  (that is exactly how it ran on Roboto on Android for months).
- **An empty state is a finished state, not a missing one.** Every "nothing here"
  surface renders through `AppEmptyState` (glyph) or `DropEmptyState` (brand), both
  of which carry their mark in `EmptyStateMedallion`. Don't hand-roll a circle and
  a grey icon per screen. Equally: a container whose every cell is conditional must
  gate **itself and its spacing** on having content — an empty bordered box reads to
  users as a component that failed to load.
- **Empty ≠ failed, and a failure offers a way out.** A failure never renders as an
  empty state: use `AppErrorState` (full area, error-tinted medallion, **Retry**) or
  `AppProblemPanel` (inline, when the screen still has content around it). Both are
  in `core/widgets/app_error_state.dart`.
- **Loading keeps the shape of what is arriving.** A list loads as `ListSkeleton`,
  a panel as `Skeleton` blocks — not a centred `CircularProgressIndicator`, which
  tells the user nothing and makes the screen jump when data lands. Spinners are
  fine *inside* a button or a sheet action, where the shape is already known.
- **A write in flight is not a disabled control.** Every lifecycle action is a
  server round trip (100ms–1s). A button that dims to the disabled 50% and then
  is replaced in one frame reads as a lag, not as work — that is exactly how
  Start task was reported. The tapped control keeps full weight and shows its
  own progress ring (`isLoading`), and the action it becomes arrives through
  `ActionSwap`. Never dim the control the user just pressed.
- **Offline gates the writes, never the app.** Reads stay available from cache
  under a permanent `OfflineBar` that says *when* the connection dropped.
  **Clock in / out is the one write allowed offline** — it happens at a branch,
  where signal is worst, and `attendance/{uid}_{yyyyMMdd}_{shift}` is
  deterministic so a late write cannot duplicate. A launch-blocking gate was
  built and reversed on 2026-08-03; don't reintroduce one without reading that
  entry.
- **One primary CTA per screen.**
- Task action sheets may use neutral tonal depth, restrained entrance/stagger motion,
  and pointer lift feedback; chromatic colour remains semantic-only and reduced
  motion must collapse these transitions.
- Every widget: a Semantics label, ≥44px targets, honours reduced motion, renders
  collections lazily/capped.

### Reuse, don't rebuild

| Need | Use |
| --- | --- |
| Buttons | `AppButton` (`primary`/`secondary`/`ghost`, built-in `isLoading`) · `PremiumButton` (compact inline, also `isLoading`) |
| Handing one action to the next | `ActionSwap` (`core/widgets/app_motion.dart`) — the seam a status change crosses; the child must be **keyed** |
| Card surface | `GlassContainer` — the shared gradient/border/depth surface |
| Page header | `PageHero` (eyebrow · title · subtitle · one CTA) |
| A hero's one CTA | `PrimaryCta` (filled monochrome, hover-lift/press-scale) |
| A hero's live state line | `HeroMood` + `dashboardMood(needsAttention:)` |
| "Act on these first" | `AttentionPanel` + `AttentionSignal` — ONE grouped box: triage rows most-urgent-first, cleared ones in a footer, all-clear summary at zero, one living border |
| "Everything else" doors | `DigestPanel` + `DigestEntry` (a figure is optional) |
| Dashboard refresh control | `SyncButton` (+ pure `syncLabel`) |
| Desktop ⌘K discoverability | `CommandHint` |
| Triage cell | `AttentionTile` (monochrome at zero, tints only when there's work) |
| Tappable figure cell | `MetricTile` + `MetricTileRow` — **every tile must open a list**; never draw an inert cell beside tappable ones |
| Fact row | `StatStrip` (read-only facts; if a cell should drill, use `MetricTile`) |
| Feed row | `ActivityCard` |
| Status pill | `StatusBadge` (`.task` is canonical) |
| Grouped account rows (Settings, Profile) | `SettingsSectionHeader` + `SettingsGroup` + `SettingsRow` / `SettingsSwitchRow` + `SettingsIconMedallion` (`core/widgets/settings_tiles.dart`) — one card, inset hairlines, 40px medallions. A new account surface must not fork it |
| Task card edge | `TaskAttentionSurface` + `taskAttentionTone` (Employee Home) |
| Empty state | `DropEmptyState` |
| Loading | `Skeleton` / `DropLoadingState` |
| Feedback | `AppSnackbar.success/error` — never raw `ScaffoldMessenger` |
| Spacing / radius | `AppSpacing` / `AppRadius` — never hardcode |

New surfaces compose the Design System V2 primitives — see
[docs/design/DESIGN_SYSTEM.md](docs/design/DESIGN_SYSTEM.md).

### Adaptive shell

- **Mobile/tablet:** `RoleScaffold` owns the role-home AppBar (DROP mark + one
  glass role-action capsule + separate account avatar) and `AppBottomNav`.
  Actions remain role-scoped; the manager's five-control worst case must fit at
  320px with every target ≥44px.
- **Desktop:** persistent role-aware `AppSidebar` via `AppShell` (a `ShellRoute`),
  ⌘1–⌘9 jump to destinations, ⌘K opens the command palette.
- Pages use `AdaptiveScaffold` (mobile AppBar ⇄ desktop page header).

### Going back is platform-native

**Every screen keeps its back button.** On iOS the native interactive left-edge
swipe-back works **in addition to** it, exactly as in Apple's own apps — never
instead of it. Android keeps its Material transition and system back gesture;
desktop keeps `AdaptiveScaffold`'s in-header control. The decision lives in
`core/routes/app_page_route.dart`.

The gesture is the half that rots silently, because nothing *looks* broken
without it: it exists only on Cupertino routes. So **push every page through
`appPageRoute`**, or route it in `app_router.dart` (iOS gets `CupertinoPage`).
Never hand-roll a `PageRouteBuilder` for a page — that screen loses the swipe
while every other screen keeps it.

iOS itself gives no gesture to a `fullscreenDialog`, a media viewer (a zoomed
`InteractiveViewer` competes with the edge drag), or a screen blocking pop with
`PopScope(canPop: false)`. Those rely on their button alone, which is correct.

> ⚠️ The platform branch is on **`TargetPlatform`, never on window width**. A
> `Page` subtype is part of route identity; flipping it at runtime (an iPad
> resized into Split View) tears the route down and rebuilds it mid-gesture.

> ⚠️ **Never wrap the `ShellRoute` child in an `AnimatedSwitcher` or keyed
> cross-fade.** It is go_router's shell Navigator (a `GlobalKey`); mounting it twice
> duplicates the key and froze all macOS navigation. The desktop fade lives at the
> page level in `app_router.dart`.

---

## 8. Development workflow

### Adding a feature

Follow it through **all** layers, in order:

```
datasource → repository (contract + impl) → use case → cubit/state → page
          → wire in injection.dart → (if routed) app_router.dart + route_names.dart
```

Then run codegen if any `freezed` file changed.

### Access model

Mirrored in `firestore.rules` — the client is never the enforcement point.

| Role | Scope |
| --- | --- |
| **admin** | Global. Not restricted by `branchId`. Can do everything a manager can, everywhere. |
| **manager** | Exactly one branch; limited to `resource.branchId == manager.branchId`. |
| **employee** | Own assigned data and profile. **Read-only exception:** any signed-in user may *read* any `users` doc (flat directory — see below). Writes to user docs stay admin-only. |

> **An admin has no `branchId`.** The role is global, so account provisioning
> deliberately omits the branch (`create_account_screen._needsBranch`). It follows
> that **no `where('branchId', ...)` query can ever return an admin, or return
> anything at all *for* an admin** — a branch read is not a directory.
>
> ⚠️ **This is how a whole feature goes silent for admins.** Any recipient set
> for a branch event must add admins **explicitly and unconditionally** —
> `resolveRequestApprovers` · `resolveAttendanceReviewers` ·
> `selectSalesRecipients` all do. Adding them as a *fallback* ("use admins if the
> branch query returned nobody") looks correct and is not: on a branch that has
> anyone at all, the fallback never fires, so the admin is never told. That was
> the sales bug of 2026-08-07. The one deliberate exception is
> `selectMissedNotifyTargets`, whose fallback is the documented policy.
>
> **Exception — `users` READS are flat** ([ADR-012](docs/decisions/ADR-012-chat-directory-is-flat.md)):
> any signed-in user may read any user document, because chat's directory is
> org-wide (anyone may message anyone). The table above still governs every other
> collection, and still governs all `users` **writes**. Chat's directory is
> `GetChatDirectory` — one unfiltered read, filtered only by self-exclusion and
> `isActive`. Do not re-introduce branch or role scoping into it. The same read
> also yields the set of **deactivated** uids (`GetChatDirectory.resolve` →
> `ChatDirectorySnapshot`), which the inbox uses to hide an existing conversation
> with a turned-off teammate and the thread uses to refuse to open — so a
> deactivated account disappears from chat, not just from the picker.

- Parse roles with `UserRole.fromString`, which **defaults unknown/missing to
  `employee`** so a bad document can never escalate privileges. Use the
  `isAdmin`/`isManager`/`isEmployee`/`isGlobal` getters.
- **Never gate role access in the UI only.** Add a role area as a path prefix with an
  `_isXArea` helper + a guard line in the router, and extend `RouteNames.homeForRole`.
- Privileged fields (`role`, `branchId`, `isActive`, `position`, `createdBy`,
  `mustChangePassword`, `isProfileCompleted`, …) are kept **out of
  `UserModel.toMap()`** so routine profile writes cannot reset admin-owned state.

Rule detail per collection: [docs/design/DATA_MODEL.md](docs/design/DATA_MODEL.md).

### Before finishing any task

1. `flutter analyze` — clean.
2. `flutter test` — no **new** failures (see CURRENT_STATE for known ones).
2b. If you touched `firestore.rules`: `cd firestore-tests && npm test`.
   **Rules are production code and the Dart suite cannot see them** — it runs
   against fake repositories and never evaluates a rule. A rule regression once
   denied every task creation in production while all 1100+ Dart tests passed.
3. Update **CURRENT_STATE.md** if status, gaps, or priorities moved.
4. Append a **CHANGELOG.md** line.
5. Update the **design doc** if you changed how a feature works.
6. Write an **ADR** if you made or reversed an architectural decision.
7. Update **this file** only if the architecture, a convention, or a module changed.

### Documentation rules

These exist because the previous doc set reached 11,000 lines and started
contradicting itself — it claimed indigo was the accent months after it was deleted,
and gave three different test counts in one file.

- **One fact, one home.** Never restate a feature's design in more than one doc. Link
  instead.
- **Summarize on the way out.** A CHANGELOG entry loses detail as it ages; it does
  not live at full length forever. Git has the detail.
- **CURRENT_STATE.md is today only.** The moment something is history, it belongs in
  the CHANGELOG.
- **Deleted docs are not lost** — `git show <sha>:<file>` recovers anything. Never
  keep a stale doc "just in case", and never create an archive directory.
- **Prefer bullets over paragraphs, tables over prose.**
