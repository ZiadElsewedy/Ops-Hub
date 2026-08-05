# 🛠️ 04 · "WHAT DO I EDIT IF I WANT TO…"

Intent → the exact, ordered file list. Follow top to bottom. `▸` = do this step. `⚠️` = don't forget.
Entities/states use **freezed** — after editing any `*.freezed.dart`-backed file you MUST run codegen:

```bash
dart run build_runner build --delete-conflicting-outputs
```

---

## ➕ Add a new FIELD to an existing entity (e.g. a task gets `tags`)

Pick the feature (`<F>`). Touch these in order:
```
▸ 1. lib/features/<F>/domain/entities/<entity>.dart      add the field (freezed ctor param)
     → run build_runner (regenerates <entity>.freezed.dart)
▸ 2. lib/features/<F>/data/models/<name>_model.dart       fromJson + toJson for the field
▸ 3. firestore.rules  (only if the field is validated/required on write)
       ⚠️ default optionals to null: get(data,'field', null) — NEVER == '' (see 05_DANGER)
       ⚠️ add a case in firestore-tests/ if you changed rules
▸ 4. presentation/ (page or widget)                       show/edit the field
▸ 5. docs/design/<FEATURE>.md + DATA_MODEL.md             record the field (docs = source code here)
```
Additive & nullable = no migration. Making it required on existing docs = you own a backfill.

## 🎴 Change a CARD (the list-item UI)

Cards live in `presentation/widgets/`. Common ones:
| Card | File |
|---|---|
| Task card | `lib/features/task/presentation/widgets/` (`task_card*.dart`) — border language = ADR-014 ⚠️ |
| Request card | `lib/features/requests/presentation/widgets/request_card.dart` |
| Case list tile | `lib/features/cases/presentation/widgets/` (`case_list_tile.dart`) |
| Chat conversation tile | `lib/features/chat/presentation/` (`chat_conversation_tile.dart`) |
| Broadcast card | `lib/features/communications/presentation/widgets/broadcast_card.dart` |
| Employee card | `lib/features/admin/...` (`employee_card.dart`) |
```
▸ edit the widget file ▸ if it needs new data, add the field first (recipe above)
⚠️ shared primitives live in lib/core/widgets/ (43) — changing one hits every feature. Check callers first.
⚠️ Task card border/animation is a debated, owner-signed design (ADR-014 + memory). Don't "simplify" it.
```

## 🔔 Modify NOTIFICATIONS

```
Content / when a notification is created   → the feature that emits it (calls sendNotification / writes notifications/)
Push delivery (FCM)                        → functions/index.js  onNotificationCreated  🖥️
Create-notification server logic           → functions/index.js  sendNotification (onCall)
Where a tap lands (in-app tile OR push)    → lib/features/notifications/.../notification_deep_link.dart
                                             🧠 resolveNotificationRoute — ONE seam, null = safe no-op
Foreground banner / token / channel        → lib/core/services/notification_service.dart
FCM token ownership (one-owner rule)        → functions/index.js  claimFcmToken  🖥️  (don't self-heal on client)
In-app inbox UI                            → lib/features/notifications/presentation/
Reminder scheduling                        → functions/index.js runTaskReminders + reminderConfig/ taskReminders/
```
⚠️ iOS push is **not configured** (missing entitlements/aps-environment) — Android-first. Server changes need `firebase deploy --only functions`.

## ⏱️ Change ATTENDANCE logic

```
Minute math / worked-minutes (🧠 single source)  → lib/features/attendance/domain/ (attendance_calculator.dart)
GPS / geofence (pure Haversine)                  → lib/features/attendance/domain/ (attendance_gps.dart, branch_geofence)
Record id scheme  attendance/{uid}_{date}_{shift}→ attendance id builder (domain)
Clock in/out flow (UI + cubit)                    → presentation/ + attendance_cubit.dart
Corrections / approvals                          → attendance_corrections/ + attendance_admin_cubit + onAttendanceCorrectionWritten 🖥️
Server-derived events / apply corrections         → functions/index.js onAttendanceWritten  🖥️
16h auto-close                                   → functions/index.js autoCloseAttendance + attendance_auto_close.js  🖥️
Rules                                            → firestore.rules @806 (attendance) / @860 (corrections)
```
⚠️ Times are server-authoritative (ADR-005). Don't trust client clocks for the stored time. Add tests — attendance has 20.

## 🔐 Change AUTHENTICATION / first-login flow

```
The redirect gate (who goes where)   → lib/core/routes/app_router.dart  _redirect (~407)  🧠
Role guards                          → app_router.dart _isAdminArea/_isManagerArea/... 
Sign-in / password use cases         → lib/features/auth/domain/usecases/ (sign_in_with_email, forgot_password, change_password...)
Auth state (the app-wide cubit)      → lib/features/auth/presentation/cubit/auth_cubit.dart  (wired in DI, drives redirect)
Repository / Firebase Auth calls     → lib/features/auth/data/repositories/auth_repository_impl.dart + datasources
First-login gates (temp pw, profile) → auth screens: ForcePasswordChangePage, ProfileCompletionPage + user flags mustChangePassword/isProfileCompleted
Account provisioning (admin creates) → functions/index.js createUserAccount / adminResetPassword 🖥️
```
⚠️ `_redirect` must stay **pure & synchronous** — never `await`. A blocked redirect freezes all navigation.

## 🧑‍💼 Add a new ROLE

Highest-blast-radius change in the app. `UserRole` is switched exhaustively in many places.
```
▸ 1. lib/core/enums/user_role.dart              add the enum value + helpers (isX)
▸ 2. lib/core/routes/route_names.dart           homeForRole / tasksForRole / scheduleForRole switches
▸ 3. lib/core/routes/app_router.dart            _redirect + a new *Shell + guard if it has a private area
▸ 4. firestore.rules                            every role check (grep the rules for existing roles)
▸ 5. functions/index.js                         any server-side role gating
▸ 6. role shell/home screen + bottom nav (core/widgets RoleScaffold / AppBottomNav)
⚠️ grep the whole repo for an existing role name to find every switch you must extend.
⚠️ This reverses/extends ADR-002-era assumptions — write an ADR.
```

## 📈 Add ANALYTICS

```
STOP — read docs/decisions/ADR-009-no-analytics-pipeline.md first.  The product deliberately has
NO analytics pipeline (lean-over-enterprise, ADR-010). usageStats/ exists but has no consumer.
If truly needed: statistics feature (lib/features/statistics/) computes dashboards from live reads.
Add a computed metric there, not a new event-tracking system. Audit trail already exists → audit feature.
```

## 🗃️ Add a new FIREBASE COLLECTION

```
▸ 1. firestore.rules            add match /<collection>/{id} { ... }  (read/create/update/delete verbs)
      ⚠️ default optionals to null (get(...,null)); add firestore-tests/ cases
▸ 2. firestore.indexes.json     add composite indexes if you query by >1 field / orderBy
▸ 3. lib/features/<F>/data/models/<x>_model.dart   fromJson/toJson
▸ 4. domain/entities + domain/repositories (contract) + data/repositories (impl) + data/datasources
▸ 5. lib/core/di/injection.dart AppDependencies   construct & expose the repo/cubit
▸ 6. functions/index.js         any triggers (on*), then firebase deploy --only firestore:rules,functions
▸ 7. docs/design/DATA_MODEL.md  document the new collection
```

## 🌐 Add an API ENDPOINT (chat / NestJS only)

```
Everything non-chat is Firestore — you don't add REST endpoints, you add collections (recipe above).
For chat (the only external API):
  Backend  → the drop-api repo (NestJS)  [additional working dir: /Users/ziad/Desktop/Developer/drop-api]
  Client transport → lib/core/network/api_client.dart (ApiClient) + network_config.dart
  Chat datasource  → lib/features/chat/data/datasources/chat_remote_datasource.dart
  Realtime (socket)→ lib/features/chat/data/realtime/chat_socket_service.dart (delivery only; REST = truth)
  Local cache      → lib/features/chat/data/local/chat_database.dart (Drift) ⚠️ never cache image bytes
```

## 🧭 Add a new SCREEN / ROUTE

```
▸ 1. lib/core/routes/route_names.dart   add the path const (+ a helper for :params)
▸ 2. lib/core/routes/app_router.dart    add the GoRoute inside the right area; pick a guard
▸ 2b. use _pushPage (NOT _fadeTransition) — it gives iOS a CupertinoPage, i.e. the swipe-back
▸ 3. lib/features/<F>/presentation/pages/<x>_screen.dart   the screen
▸ 4. build the cubit via AppDependencies (or a BlocProvider in the route builder)
```

⚠️ Pushing a page **imperatively** instead? Use `appPageRoute` (`lib/core/routes/app_page_route.dart`),
never a raw `PageRouteBuilder`. iOS has no app-bar back chevron — only a Cupertino route carries the
edge-swipe, so a plain `PageRouteBuilder` leaves the screen with no way back. See DANGER §8.

## ➕ Add a new WORK TYPE (task polymorphism — the cheapest extension in the app 🧩)

```
🧠 OCP by design: 1 new file + 1 registration line, no migration.
▸ 1. lib/features/task/domain/work_types/definitions/<type>.dart   implement the strategy
▸ 2. register it in the work-type registry (1 line)
Unknown types fall back to `general`. workType + data are additive. See features/task.md.
```

## 🎨 Change the LOOK (theme / colors / typography)

```
lib/core/theme/ (5 files) — monochrome B&W/grey by owner ruling (ADR-004). Colour only for destructive.
⚠️ No indigo/purple. Grey ramp is a 4-step system (see memory: no two ADJACENT texts share a grey).
Shared primitives: lib/core/widgets/ — change once, changes everywhere.
```

Can't find your intent here? → [`features/<feature>.md`](features/) card → its "Common modifications".
