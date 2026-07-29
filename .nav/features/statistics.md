<!-- AUTO-GENERATED mechanical inventory. Regenerate: python3 .nav/gen_atlas.py
     Hand-authored intelligence lives BELOW the marker. Do not delete that section. -->
# 📍 FEATURE CARD — `statistics`

> `lib/features/statistics/` · **11 files** · layer-complete clean-architecture slice

## Entry points (route → screen)
| Route const | Path | Guard/notes |
|---|---|---|
| `RouteNames.adminAnalytics` | `/admin/analytics` |  |

## Owner files (by layer)
**presentation:cubit**
- `lib/features/statistics/presentation/cubit/statistics_cubit.dart`
- `lib/features/statistics/presentation/cubit/statistics_state.dart`
- `lib/features/statistics/presentation/cubit/statistics_state.freezed.dart`

**presentation:widget**
- `lib/features/statistics/presentation/widgets/dashboard_section.dart`
- `lib/features/statistics/presentation/widgets/stat_grid.dart`

**domain:entity**
- `lib/features/statistics/domain/entities/statistics_entity.dart`
- `lib/features/statistics/domain/entities/statistics_entity.freezed.dart`

**domain:repository-contract**
- `lib/features/statistics/domain/repositories/statistics_repository.dart`

**data:repository-impl**
- `lib/features/statistics/data/repositories/statistics_repository_impl.dart`

**data:datasource**
- `lib/features/statistics/data/datasources/statistics_remote_datasource.dart`

**data:model**
- `lib/features/statistics/data/models/statistics_model.dart`

## Backend surface
- **Firestore collections:** `usageStats`
- **Cloud Functions:** —
- **Security rules:** `firestore.rules` (search the collection names above) · `storage.rules` if it uploads media
- **Design spec(s):** —

## Tests
- `test/attendance_analytics_test.dart`

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