<!-- AUTO-GENERATED mechanical inventory. Regenerate: python3 .nav/gen_atlas.py
     Hand-authored intelligence lives BELOW the marker. Do not delete that section. -->
# 📍 FEATURE CARD — `profile`

> `lib/features/profile/` · **19 files** · layer-complete clean-architecture slice

## Entry points (route → screen)
| Route const | Path | Guard/notes |
|---|---|---|
| `RouteNames.profileCompletion` | `/complete-profile` |  |
| `RouteNames.profile` | `/profile` |  |
| `RouteNames.editProfile` | `/profile/edit` |  |

## Owner files (by layer)
**presentation:page**
- `lib/features/profile/presentation/pages/edit_profile_page.dart`
- `lib/features/profile/presentation/pages/profile_page.dart`

**presentation:cubit**
- `lib/features/profile/presentation/cubit/profile_cubit.dart`
- `lib/features/profile/presentation/cubit/profile_state.dart`
- `lib/features/profile/presentation/cubit/profile_state.freezed.dart`

**presentation:widget**
- `lib/features/profile/presentation/widgets/profile_avatar.dart`
- `lib/features/profile/presentation/widgets/profile_detail_row.dart`
- `lib/features/profile/presentation/widgets/profile_identity_card.dart`

**domain:entity**
- `lib/features/profile/domain/entities/profile_entity.dart`
- `lib/features/profile/domain/entities/profile_entity.freezed.dart`

**domain:usecase**
- `lib/features/profile/domain/usecases/check_username.dart`
- `lib/features/profile/domain/usecases/get_profile.dart`
- `lib/features/profile/domain/usecases/update_profile.dart`
- `lib/features/profile/domain/usecases/upload_cover_image.dart`
- `lib/features/profile/domain/usecases/upload_profile_image.dart`

**domain:repository-contract**
- `lib/features/profile/domain/repositories/profile_repository.dart`

**data:repository-impl**
- `lib/features/profile/data/repositories/profile_repository_impl.dart`

**data:datasource**
- `lib/features/profile/data/datasources/profile_remote_datasource.dart`

**data:model**
- `lib/features/profile/data/models/profile_model.dart`

## Backend surface
- **Firestore collections:** —
- **Cloud Functions:** —
- **Security rules:** `firestore.rules` (search the collection names above) · `storage.rules` if it uploads media
- **Design spec(s):** —

## Tests
- `test/features/profile/profile_page_test.dart`

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