<!-- AUTO-GENERATED mechanical inventory. Regenerate: python3 .nav/gen_atlas.py
     Hand-authored intelligence lives BELOW the marker. Do not delete that section. -->
# 📍 FEATURE CARD — `branch`

> `lib/features/branch/` · **13 files** · layer-complete clean-architecture slice

## Entry points (route → screen)
| Route const | Path | Guard/notes |
|---|---|---|
| `RouteNames.adminBranches` | `/admin/branches` |  |
| `RouteNames.attendanceDailyReviewPattern` | `/attendance/daily/:branchId/:dayKey` |  |

## Owner files (by layer)
**presentation:page**
- `lib/features/branch/presentation/pages/branch_geofence_editor_screen.dart`
- `lib/features/branch/presentation/pages/branch_management_screen.dart`

**presentation:cubit**
- `lib/features/branch/presentation/cubit/branch_cubit.dart`
- `lib/features/branch/presentation/cubit/branch_state.dart`
- `lib/features/branch/presentation/cubit/branch_state.freezed.dart`

**presentation:widget**
- `lib/features/branch/presentation/widgets/branch_form_sheet.dart`

**domain:entity**
- `lib/features/branch/domain/entities/branch_entity.dart`
- `lib/features/branch/domain/entities/branch_entity.freezed.dart`

**domain:repository-contract**
- `lib/features/branch/domain/repositories/branch_repository.dart`

**domain:other**
- `lib/features/branch/domain/branch_geofence.dart`

**data:repository-impl**
- `lib/features/branch/data/repositories/branch_repository_impl.dart`

**data:datasource**
- `lib/features/branch/data/datasources/branch_remote_datasource.dart`

**data:model**
- `lib/features/branch/data/models/branch_model.dart`

## Backend surface
- **Firestore collections:** `branches`, `branch_sales_months`, `branch_sales_submissions`
- **Cloud Functions:** `setBranchSalesTarget`
- **Security rules:** `firestore.rules` (search the collection names above) · `storage.rules` if it uploads media
- **Design spec(s):** —

## Tests
- `test/branch_geofence_test.dart`
- `test/branch_media_test.dart`
- `test/branch_workload_test.dart`
- `test/features/sales/data/branch_sales_month_model_test.dart`
- `test/features/sales/domain/sales_branch_scope_test.dart`

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