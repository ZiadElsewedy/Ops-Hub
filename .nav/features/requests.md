<!-- AUTO-GENERATED mechanical inventory. Regenerate: python3 .nav/gen_atlas.py
     Hand-authored intelligence lives BELOW the marker. Do not delete that section. -->
# 📍 FEATURE CARD — `requests`

> `lib/features/requests/` · **29 files** · layer-complete clean-architecture slice

## Entry points (route → screen)
| Route const | Path | Guard/notes |
|---|---|---|
| `RouteNames.requestDetailPattern` | `/request/:requestId` |  |
| `RouteNames.requests` | `/requests` |  |
| `RouteNames.requestsCreate` | `/requests/create` |  |

## Owner files (by layer)
**presentation:page**
- `lib/features/requests/presentation/pages/create_request_screen.dart`
- `lib/features/requests/presentation/pages/request_detail_screen.dart`
- `lib/features/requests/presentation/pages/requests_screen.dart`

**presentation:cubit**
- `lib/features/requests/presentation/cubit/request_detail_cubit.dart`
- `lib/features/requests/presentation/cubit/request_detail_state.dart`
- `lib/features/requests/presentation/cubit/request_detail_state.freezed.dart`
- `lib/features/requests/presentation/cubit/requests_list_cubit.dart`
- `lib/features/requests/presentation/cubit/requests_list_state.dart`
- `lib/features/requests/presentation/cubit/requests_list_state.freezed.dart`

**presentation:widget**
- `lib/features/requests/presentation/widgets/request_card.dart`
- `lib/features/requests/presentation/widgets/request_composer.dart`
- `lib/features/requests/presentation/widgets/request_timeline.dart`

**presentation:other**
- `lib/features/requests/presentation/request_format.dart`

**domain:entity**
- `lib/features/requests/domain/entities/request_entity.dart`
- `lib/features/requests/domain/entities/request_entity.freezed.dart`
- `lib/features/requests/domain/entities/request_event.dart`
- `lib/features/requests/domain/entities/request_event.freezed.dart`

**domain:usecase**
- `lib/features/requests/domain/usecases/add_request_comment.dart`
- `lib/features/requests/domain/usecases/change_request_status.dart`
- `lib/features/requests/domain/usecases/create_request.dart`
- `lib/features/requests/domain/usecases/upload_request_attachment.dart`

**domain:repository-contract**
- `lib/features/requests/domain/repositories/request_repository.dart`

**domain:other**
- `lib/features/requests/domain/request_access.dart`
- `lib/features/requests/domain/request_metrics.dart`
- `lib/features/requests/domain/request_ordering.dart`
- `lib/features/requests/domain/request_thread.dart`

**data:repository-impl**
- `lib/features/requests/data/repositories/request_repository_impl.dart`

**data:datasource**
- `lib/features/requests/data/datasources/request_remote_datasource.dart`

**data:model**
- `lib/features/requests/data/models/request_model.dart`

## Backend surface
- **Firestore collections:** `requests`
- **Cloud Functions:** `onRequestCreated`, `onRequestEventCreated`, `onRequestUpdated`
- **Security rules:** `firestore.rules` (search the collection names above) · `storage.rules` if it uploads media
- **Design spec(s):** `docs/design/REQUESTS.md`

## Tests
- `test/request_access_test.dart`
- `test/request_create_picker_test.dart`
- `test/request_detail_cubit_test.dart`
- `test/request_model_test.dart`
- `test/request_ordering_test.dart`
- `test/request_status_test.dart`
- `test/request_thread_test.dart`

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