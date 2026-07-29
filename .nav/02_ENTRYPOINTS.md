# 🔑 02 · ENTRY-POINT & IGNITION MAP

Every way *into* the app, and the first file each one hits. When you know the URL/tap but not the code,
start here.

## 🚀 App boot sequence (the one true startup path)

```
lib/main.dart
  1. WidgetsFlutterBinding + Firebase.initializeApp(firebase_options.dart)
  2. AppDependencies.init()        lib/core/di/injection.dart   ← builds every repo/cubit/service
  3. createRouter(authCubit)       lib/core/routes/app_router.dart
  4. runApp( MaterialApp.router )   theme = lib/core/theme/
        └─ redirect gate: _redirect()  ← EVERY navigation passes through here
```

🧠 **The redirect gate** (`app_router.dart` `_redirect`, ~line 407) is the single auth/first-login/role
funnel. It is **pure & synchronous — never `await` inside it** (a blocked redirect stalls all navigation).
Order it enforces:
```
not authenticated ──────────────► /login
mustChangePassword == true ─────► /force-password-change
isProfileCompleted == false ────► /complete-profile
employee & !hasCompletedOnboarding ─► /welcome   (once)
wrong role for area ────────────► role home       (guards below)
```

## 🛡️ Role-area guards (the 4 gatekeepers)

| Guard fn (`app_router.dart`) | Protects paths | Allows |
|---|---|---|
| `_isAdminArea` | `/admin/*` | admin only |
| `_isManagerArea` | `/manager/*` | manager + admin |
| `_isCommunicationsArea` | `/communications/*` | admin + manager (blocks employee) |
| `_isAttendanceReviewArea` | `/attendance/review` | admin + manager (blocks employee) |

Shared surfaces (`/notifications` `/cases` `/chat` `/requests` `/task/:id` `/attendance` …) sit **outside**
guards on purpose — they self-scope by role in the cubit and are enforced by `firestore.rules`.

## 🗺️ Route → Screen → Feature (the full switchboard)

> Screen classes are the **entry widget**; from there open the matching `features/<feature>.md` card to
> get the cubit → usecase → repository → collection chain.

### Auth & first-login (pre-shell, no bottom nav)
| Path | Screen | Feature |
|---|---|---|
| `/splash` | `SplashScreen` | auth |
| `/login` | `LoginPage` | auth |
| `/forgot-password` | `ForgotPasswordPage` | auth |
| `/force-password-change` | `ForcePasswordChangePage` | auth |
| `/complete-profile` | `ProfileCompletionPage` | auth |
| `/welcome` | `OnboardingWelcomePage` | auth |

### Role homes (inside `ShellRoute` — bottom nav lives here)
| Path | Screen | Feature |
|---|---|---|
| `/` | `EmployeeShell` | employee (composes task/schedule/home) |
| `/admin` | `AdminShell` | admin / statistics |
| `/manager` | `ManagerShell` | manager |

### Tasks
| Path | Screen | Feature |
|---|---|---|
| `/admin/tasks` | `TaskManagementScreen` | task |
| `/admin/review` | `PendingReviewScreen` | task |
| `/manager/tasks` | `ManagerOperationsScreen` | task |
| `/my-tasks` | `MyTasksScreen` | task |
| `/task/:taskId` | `TaskDetailLoaderScreen` | task |

### Schedule
| Path | Screen | Feature |
|---|---|---|
| `/admin/schedule` | `ScheduleManagementScreen` | schedule |
| `/manager/schedule` | `BranchScheduleScreen` | schedule |
| `/my-schedule` | `MyScheduleScreen` | schedule |

### Attendance
| Path | Screen | Feature |
|---|---|---|
| `/attendance` | `AttendanceScreen` (employee clock) | attendance |
| `/admin/attendance` | `AdminAttendanceScreen` (board + correction queue) | attendance |
| `/attendance/history` | `AttendanceHistoryScreen` (self) | attendance |
| `/attendance/review` | `AttendanceHistoryScreen` (branch, guarded) | attendance |
| `/attendance/record/:id` | `AttendanceDetailsScreen` | attendance |

### Communications (admin+manager)
| Path | Screen | Feature |
|---|---|---|
| `/communications` | `CommunicationsScreen` | communications |
| `/communications/compose` | `ComposeBroadcastScreen` | communications |
| `/communications/templates` | `BroadcastTemplatesScreen` | communications |
| `/communications/schedules` | `BroadcastSchedulesScreen` | communications |
| `/communications/:broadcastId` | `BroadcastDetailScreen` | communications |

### Cases · Chat · Requests · Notifications (shared, self-scoping)
| Path | Screen | Feature |
|---|---|---|
| `/cases` · `/cases/create` · `/case/:caseId` | `CasesScreen` · `CreateCaseScreen` · `CaseConversationScreen` | cases |
| `/chat` · `/chat/new` · `/chat/:conversationId` | `ChatScreen` · `NewChatScreen` · `ChatConversationScreen` | chat 🔗 NestJS |
| `/requests` · `/requests/create` · `/request/:requestId` | `RequestsScreen` · `CreateRequestScreen` · `RequestDetailScreen` | requests |
| `/notifications` | `NotificationsScreen` | notifications |

### Admin module
| Path | Screen |
|---|---|
| `/admin/branches` | `BranchManagementScreen` (branch) |
| `/admin/managers` | `ManagerManagementScreen` (admin) |
| `/admin/employees` | `EmployeeManagementScreen` (admin) |
| `/admin/analytics` | `AdminAnalyticsScreen` (statistics) |
| `/admin/users/create` | `CreateAccountScreen` (auth) |

### Profile & Settings
| Path | Screen |
|---|---|
| `/profile` · `/profile/edit` | `ProfilePage` · `EditProfilePage` (profile) |
| `/settings` · `/settings/change-password` | `SettingsPage` · `ChangePasswordPage` (settings/auth) |

## 📥 The *other* entry points (not routes — easy to miss)

| Entry | First file | Notes |
|---|---|---|
| **FCM push tap** | `core/services/notification_service.dart` → `notifications/.../notification_deep_link.dart` `resolveNotificationRoute` | 🧠 ONE resolver for both the in-app tile and a push tap. `null` = safe no-op → inbox |
| **In-app notification banner** | `NotificationService` foreground listener | suppressed for the on-screen chat conversation via `AppDependencies.activeChatConversation` |
| **Deep links** (`/task/:id`, `/case/:id`, …) | the `*Pattern` routes above | access enforced by `firestore.rules`, not the route |
| **Cloud Function triggers** | `functions/index.js` `on*` handlers | Firestore writes → server reacts (notifications, audit, derived docs). See [`03_DATA_MAP.md`](03_DATA_MAP.md) |
| **Scheduled Functions** | `runBroadcastSchedules`, `runTaskReminders`, `autoCloseAttendance`, `generateShiftTaskInstances` | cron-driven server work |

Next: [`03_DATA_MAP.md`](03_DATA_MAP.md) for the backend side of every arrow above.
