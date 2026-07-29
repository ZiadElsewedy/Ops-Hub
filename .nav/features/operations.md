<!-- AUTO-GENERATED mechanical inventory. Regenerate: python3 .nav/gen_atlas.py
     Hand-authored intelligence lives BELOW the marker. Do not delete that section. -->
# 📍 FEATURE CARD — `operations`

> `lib/features/operations/` · **12 files** · layer-complete clean-architecture slice

## Entry points (route → screen)
_No direct routes — reached via shared widgets or another feature._

## Owner files (by layer)
**presentation:page**
- `lib/features/operations/presentation/pages/branch_operations_screen.dart`
- `lib/features/operations/presentation/pages/employee_detail_screen.dart`
- `lib/features/operations/presentation/pages/manager_operations_screen.dart`
- `lib/features/operations/presentation/pages/operations_metric_screen.dart`

**presentation:cubit**
- `lib/features/operations/presentation/cubit/branch_operations_cubit.dart`
- `lib/features/operations/presentation/cubit/branch_operations_state.dart`
- `lib/features/operations/presentation/cubit/branch_operations_state.freezed.dart`

**presentation:widget**
- `lib/features/operations/presentation/widgets/workload_card.dart`

**domain:other**
- `lib/features/operations/domain/branch_summary.dart`
- `lib/features/operations/domain/branch_workload.dart`
- `lib/features/operations/domain/employee_workload.dart`
- `lib/features/operations/domain/shift_filter.dart`

## Backend surface
- **Firestore collections:** `automationRuns`
- **Cloud Functions:** `autoEndRecurringShiftTasks`, `generateShiftTaskInstances`, `onRecurringTemplateWritten`
- **Security rules:** `firestore.rules` (search the collection names above) · `storage.rules` if it uploads media
- **Design spec(s):** `docs/design/AUTOMATION_ENGINE.md`

## Tests
- `test/automation_health_test.dart`
- `test/automation_run_model_test.dart`
- `test/operations_metric_test.dart`

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