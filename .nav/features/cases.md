<!-- AUTO-GENERATED mechanical inventory. Regenerate: python3 .nav/gen_atlas.py
     Hand-authored intelligence lives BELOW the marker. Do not delete that section. -->
# 📍 FEATURE CARD — `cases`

> `lib/features/cases/` · **31 files** · layer-complete clean-architecture slice

## Entry points (route → screen)
| Route const | Path | Guard/notes |
|---|---|---|
| `RouteNames.caseDetailPattern` | `/case/:caseId` |  |
| `RouteNames.cases` | `/cases` |  |
| `RouteNames.casesCreate` | `/cases/create` |  |

## Owner files (by layer)
**presentation:page**
- `lib/features/cases/presentation/pages/case_conversation_screen.dart`
- `lib/features/cases/presentation/pages/cases_screen.dart`
- `lib/features/cases/presentation/pages/create_case_screen.dart`

**presentation:cubit**
- `lib/features/cases/presentation/cubit/case_conversation_cubit.dart`
- `lib/features/cases/presentation/cubit/case_conversation_state.dart`
- `lib/features/cases/presentation/cubit/case_conversation_state.freezed.dart`
- `lib/features/cases/presentation/cubit/case_list_cubit.dart`
- `lib/features/cases/presentation/cubit/case_list_state.dart`
- `lib/features/cases/presentation/cubit/case_list_state.freezed.dart`

**presentation:widget**
- `lib/features/cases/presentation/widgets/case_composer.dart`
- `lib/features/cases/presentation/widgets/case_conversation_view.dart`
- `lib/features/cases/presentation/widgets/case_list_tile.dart`
- `lib/features/cases/presentation/widgets/case_message_list.dart`
- `lib/features/cases/presentation/widgets/case_status_control.dart`

**presentation:other**
- `lib/features/cases/presentation/case_format.dart`

**domain:entity**
- `lib/features/cases/domain/entities/case_entity.dart`
- `lib/features/cases/domain/entities/case_entity.freezed.dart`
- `lib/features/cases/domain/entities/case_identity.dart`
- `lib/features/cases/domain/entities/case_message.dart`
- `lib/features/cases/domain/entities/case_message.freezed.dart`

**domain:usecase**
- `lib/features/cases/domain/usecases/change_case_status.dart`
- `lib/features/cases/domain/usecases/create_case.dart`
- `lib/features/cases/domain/usecases/send_case_message.dart`
- `lib/features/cases/domain/usecases/upload_case_attachment.dart`

**domain:repository-contract**
- `lib/features/cases/domain/repositories/case_repository.dart`

**domain:other**
- `lib/features/cases/domain/case_ordering.dart`
- `lib/features/cases/domain/case_participation.dart`
- `lib/features/cases/domain/case_thread.dart`

**data:repository-impl**
- `lib/features/cases/data/repositories/case_repository_impl.dart`

**data:datasource**
- `lib/features/cases/data/datasources/case_remote_datasource.dart`

**data:model**
- `lib/features/cases/data/models/case_model.dart`

## Backend surface
- **Firestore collections:** `cases`, `cases`
- **Cloud Functions:** `onCaseCreated`, `onCaseMessageCreated`, `onCaseUpdated`
- **Security rules:** `firestore.rules` (search the collection names above) · `storage.rules` if it uploads media
- **Design spec(s):** `docs/design/CASES.md`

## Tests
- `test/case_composer_test.dart`
- `test/case_list_tile_test.dart`
- `test/case_message_test.dart`
- `test/case_model_test.dart`
- `test/case_ordering_test.dart`
- `test/case_routing_test.dart`
- `test/case_seen_store_test.dart`
- `test/case_status_test.dart`
- `test/case_thread_test.dart`

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