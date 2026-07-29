<!-- AUTO-GENERATED mechanical inventory. Regenerate: python3 .nav/gen_atlas.py
     Hand-authored intelligence lives BELOW the marker. Do not delete that section. -->
# 📍 FEATURE CARD — `audit`

> `lib/features/audit/` · **7 files** · layer-complete clean-architecture slice

## Entry points (route → screen)
_No direct routes — reached via shared widgets or another feature._

## Owner files (by layer)
**domain:entity**
- `lib/features/audit/domain/entities/audit_actor.dart`
- `lib/features/audit/domain/entities/audit_log_entry.dart`

**domain:repository-contract**
- `lib/features/audit/domain/repositories/audit_repository.dart`

**domain:other**
- `lib/features/audit/domain/services/event_tracking_service.dart`

**data:repository-impl**
- `lib/features/audit/data/repositories/audit_repository_impl.dart`

**data:datasource**
- `lib/features/audit/data/datasources/audit_remote_datasource.dart`

**data:model**
- `lib/features/audit/data/models/audit_log_model.dart`

## Backend surface
- **Firestore collections:** `audit_logs`
- **Cloud Functions:** —
- **Security rules:** `firestore.rules` (search the collection names above) · `storage.rules` if it uploads media
- **Design spec(s):** `docs/design/AUDIT_LOG.md`

## Tests
- `test/audit_event_type_test.dart`
- `test/audit_log_model_test.dart`
- `test/audit_repository_test.dart`

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