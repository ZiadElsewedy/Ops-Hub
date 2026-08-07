<!-- AUTO-GENERATED mechanical inventory. Regenerate: python3 .nav/gen_atlas.py
     Hand-authored intelligence lives BELOW the marker. Do not delete that section. -->
# 📍 FEATURE CARD — `auth`

> `lib/features/auth/` · **29 files** · layer-complete clean-architecture slice

## Entry points (route → screen)
| Route const | Path | Guard/notes |
|---|---|---|
| `RouteNames.adminCreateAccount` | `/admin/users/create` |  |
| `RouteNames.profileCompletion` | `/complete-profile` |  |
| `RouteNames.forcePasswordChange` | `/force-password-change` |  |
| `RouteNames.forgotPassword` | `/forgot-password` |  |
| `RouteNames.login` | `/login` |  |
| `RouteNames.changePassword` | `/settings/change-password` |  |
| `RouteNames.splash` | `/splash` |  |
| `RouteNames.welcome` | `/welcome` |  |

## Owner files (by layer)
**presentation:page**
- `lib/features/auth/presentation/pages/force_password_change_page.dart`
- `lib/features/auth/presentation/pages/forgot_password_page.dart`
- `lib/features/auth/presentation/pages/login_page.dart`
- `lib/features/auth/presentation/pages/onboarding_welcome_page.dart`
- `lib/features/auth/presentation/pages/profile_completion_page.dart`
- `lib/features/auth/presentation/pages/splash_page.dart`

**presentation:cubit**
- `lib/features/auth/presentation/cubit/auth_cubit.dart`
- `lib/features/auth/presentation/cubit/auth_state.dart`
- `lib/features/auth/presentation/cubit/auth_state.freezed.dart`

**presentation:widget**
- `lib/features/auth/presentation/widgets/app_button.dart`
- `lib/features/auth/presentation/widgets/app_dropdown_field.dart`
- `lib/features/auth/presentation/widgets/app_password_field.dart`
- `lib/features/auth/presentation/widgets/app_text_field.dart`
- `lib/features/auth/presentation/widgets/auth_scaffold.dart`

**presentation:other**
- `lib/features/auth/presentation/animations/fade_slide_transition.dart`

**domain:entity**
- `lib/features/auth/domain/entities/user_entity.dart`
- `lib/features/auth/domain/entities/user_entity.freezed.dart`

**domain:usecase**
- `lib/features/auth/domain/usecases/change_password.dart`
- `lib/features/auth/domain/usecases/forgot_password.dart`
- `lib/features/auth/domain/usecases/get_user.dart`
- `lib/features/auth/domain/usecases/get_users_by_branch.dart`
- `lib/features/auth/domain/usecases/sign_in_with_email.dart`
- `lib/features/auth/domain/usecases/sign_out.dart`

**domain:repository-contract**
- `lib/features/auth/domain/repositories/auth_repository.dart`

**domain:other**
- `lib/features/auth/domain/session_id.dart`

**data:repository-impl**
- `lib/features/auth/data/repositories/auth_repository_impl.dart`

**data:datasource**
- `lib/features/auth/data/datasources/auth_remote_datasource.dart`
- `lib/features/auth/data/datasources/user_remote_datasource.dart`

**data:model**
- `lib/features/auth/data/models/user_model.dart`

## Backend surface
- **Firestore collections:** `users`
- **Cloud Functions:** `adminResetPassword`, `claimFcmToken`, `createUserAccount`, `deleteUserAccount`
- **Security rules:** `firestore.rules` (search the collection names above) · `storage.rules` if it uploads media
- **Design spec(s):** `docs/design/AUTH.md`

## Tests
- `test/admin_users_delete_test.dart`
- `test/admin_users_directory_invalidation_test.dart`
- `test/first_login_gate_test.dart`
- `test/onboarding_welcome_page_test.dart`
- `test/splash_centering_test.dart`
- `test/splash_mobile_test.dart`
- `test/splash_visual_centering_test.dart`
- `test/user_admin_update_details_test.dart`
- `test/user_compensation_test.dart`
- `test/user_model_test.dart`

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