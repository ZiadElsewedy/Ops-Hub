<!-- AUTO-GENERATED mechanical inventory. Regenerate: python3 .nav/gen_atlas.py
     Hand-authored intelligence lives BELOW the marker. Do not delete that section. -->
# 📍 FEATURE CARD — `admin`

> `lib/features/admin/` · **22 files** · layer-complete clean-architecture slice

## Entry points (route → screen)
| Route const | Path | Guard/notes |
|---|---|---|
| `RouteNames.adminDashboard` | `/admin` |  |
| `RouteNames.adminAnalytics` | `/admin/analytics` |  |
| `RouteNames.adminAttendance` | `/admin/attendance` |  |
| `RouteNames.adminAttendanceWorkspace` | `/admin/attendance/workspace` |  |
| `RouteNames.adminBranches` | `/admin/branches` |  |
| `RouteNames.adminEmployees` | `/admin/employees` |  |
| `RouteNames.adminManagers` | `/admin/managers` |  |
| `RouteNames.adminReview` | `/admin/review` |  |
| `RouteNames.adminSchedule` | `/admin/schedule` |  |
| `RouteNames.adminTasks` | `/admin/tasks` |  |
| `RouteNames.adminCreateAccount` | `/admin/users/create` |  |

## Owner files (by layer)
**presentation:page**
- `lib/features/admin/presentation/pages/admin_analytics_screen.dart`
- `lib/features/admin/presentation/pages/admin_dashboard_screen.dart`
- `lib/features/admin/presentation/pages/admin_shell.dart`
- `lib/features/admin/presentation/pages/create_account_screen.dart`
- `lib/features/admin/presentation/pages/employee_management_screen.dart`
- `lib/features/admin/presentation/pages/manager_management_screen.dart`

**presentation:cubit**
- `lib/features/admin/presentation/cubit/admin_users_cubit.dart`
- `lib/features/admin/presentation/cubit/admin_users_state.dart`
- `lib/features/admin/presentation/cubit/admin_users_state.freezed.dart`

**presentation:widget**
- `lib/features/admin/presentation/widgets/admin_user_card.dart`
- `lib/features/admin/presentation/widgets/admin_user_sheets.dart`
- `lib/features/admin/presentation/widgets/admin_users_list_view.dart`
- `lib/features/admin/presentation/widgets/compensation_fields.dart`
- `lib/features/admin/presentation/widgets/employee_card.dart`
- `lib/features/admin/presentation/widgets/pending_actions.dart`
- `lib/features/admin/presentation/widgets/user_inspector_panel.dart`

**presentation:other**
- `lib/features/admin/presentation/dashboard_mood.dart`
- `lib/features/admin/presentation/employee_metrics.dart`

**domain:entity**
- `lib/features/admin/domain/entities/user_compensation.dart`

**domain:repository-contract**
- `lib/features/admin/domain/repositories/user_admin_repository.dart`

**data:repository-impl**
- `lib/features/admin/data/repositories/user_admin_repository_impl.dart`

**data:datasource**
- `lib/features/admin/data/datasources/user_admin_remote_datasource.dart`

## Backend surface
- **Firestore collections:** —
- **Cloud Functions:** `adminResetPassword`, `createUserAccount`
- **Security rules:** `firestore.rules` (search the collection names above) · `storage.rules` if it uploads media
- **Design spec(s):** —

## Tests
- `test/admin_attendance_overview_test.dart`
- `test/admin_dashboard_today_strip_test.dart`
- `test/admin_task_overview_screen_test.dart`
- `test/attendance_admin_direct_action_test.dart`
- `test/attendance_admin_workspace_bootstrap_test.dart`
- `test/user_admin_update_details_test.dart`

## Standard data flow (this feature follows the universal pattern)
```
UI (page/widget)
  → Cubit.method()            presentation/cubit/
    → UseCase.call()          domain/usecases/
      → Repository (contract) domain/repositories/
        → RepositoryImpl      data/repositories/
          → RemoteDatasource  data/datasources/   → Firestore/Functions/API
  ← Model.fromJson → Entity ← Stream/Future ← Cubit emits state → UI rebuilds
```

<!-- ═══════════════ HAND-AUTHORED INTELLIGENCE (edit freely) ═══════════════ -->

## Purpose
_TODO: one-paragraph what & why. See `docs/design/` spec above if present._

## ⚠️ Dangerous areas / invariants
_TODO: what breaks if you touch this. Cross-check `.nav/05_DANGER.md`._

## 🧩 Extension points
_TODO: where to plug in new behavior without forking._

## 🔗 Related
_TODO: sibling features, shared core widgets, ADRs._