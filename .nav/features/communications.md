<!-- AUTO-GENERATED mechanical inventory. Regenerate: python3 .nav/gen_atlas.py
     Hand-authored intelligence lives BELOW the marker. Do not delete that section. -->
# 📍 FEATURE CARD — `communications`

> `lib/features/communications/` · **38 files** · layer-complete clean-architecture slice

## Entry points (route → screen)
| Route const | Path | Guard/notes |
|---|---|---|
| `RouteNames.communications` | `/communications` |  |
| `RouteNames.communicationsDetailPattern` | `/communications/:broadcastId` |  |
| `RouteNames.communicationsCompose` | `/communications/compose` |  |
| `RouteNames.communicationsSchedules` | `/communications/schedules` |  |
| `RouteNames.communicationsTemplates` | `/communications/templates` |  |

## Owner files (by layer)
**presentation:page**
- `lib/features/communications/presentation/pages/broadcast_detail_screen.dart`
- `lib/features/communications/presentation/pages/broadcast_schedules_screen.dart`
- `lib/features/communications/presentation/pages/broadcast_templates_screen.dart`
- `lib/features/communications/presentation/pages/communications_screen.dart`
- `lib/features/communications/presentation/pages/compose_broadcast_screen.dart`

**presentation:cubit**
- `lib/features/communications/presentation/cubit/broadcast_cubit.dart`
- `lib/features/communications/presentation/cubit/broadcast_schedule_cubit.dart`
- `lib/features/communications/presentation/cubit/broadcast_schedule_state.dart`
- `lib/features/communications/presentation/cubit/broadcast_schedule_state.freezed.dart`
- `lib/features/communications/presentation/cubit/broadcast_state.dart`
- `lib/features/communications/presentation/cubit/broadcast_state.freezed.dart`
- `lib/features/communications/presentation/cubit/broadcast_template_cubit.dart`
- `lib/features/communications/presentation/cubit/broadcast_template_state.dart`
- `lib/features/communications/presentation/cubit/broadcast_template_state.freezed.dart`

**presentation:widget**
- `lib/features/communications/presentation/widgets/broadcast_card.dart`
- `lib/features/communications/presentation/widgets/template_card.dart`

**presentation:other**
- `lib/features/communications/presentation/communications_format.dart`

**domain:entity**
- `lib/features/communications/domain/entities/broadcast_entity.dart`
- `lib/features/communications/domain/entities/broadcast_entity.freezed.dart`
- `lib/features/communications/domain/entities/broadcast_schedule_entity.dart`
- `lib/features/communications/domain/entities/broadcast_template_entity.dart`
- `lib/features/communications/domain/entities/broadcast_template_entity.freezed.dart`

**domain:usecase**
- `lib/features/communications/domain/usecases/send_broadcast.dart`

**domain:repository-contract**
- `lib/features/communications/domain/repositories/broadcast_repository.dart`
- `lib/features/communications/domain/repositories/broadcast_schedule_repository.dart`
- `lib/features/communications/domain/repositories/broadcast_template_repository.dart`

**domain:other**
- `lib/features/communications/domain/broadcast_permissions.dart`
- `lib/features/communications/domain/recurrence_rule.dart`
- `lib/features/communications/domain/template_renderer.dart`

**data:repository-impl**
- `lib/features/communications/data/repositories/broadcast_repository_impl.dart`
- `lib/features/communications/data/repositories/broadcast_schedule_repository_impl.dart`
- `lib/features/communications/data/repositories/broadcast_template_repository_impl.dart`

**data:datasource**
- `lib/features/communications/data/datasources/broadcast_remote_datasource.dart`
- `lib/features/communications/data/datasources/broadcast_schedule_remote_datasource.dart`
- `lib/features/communications/data/datasources/broadcast_template_remote_datasource.dart`

**data:model**
- `lib/features/communications/data/models/broadcast_model.dart`
- `lib/features/communications/data/models/broadcast_schedule_model.dart`
- `lib/features/communications/data/models/broadcast_template_model.dart`

## Backend surface
- **Firestore collections:** `broadcasts`, `broadcastTemplates`, `broadcastSchedules`
- **Cloud Functions:** `broadcastHousekeeping`, `runBroadcastSchedules`, `sendBroadcast`
- **Security rules:** `firestore.rules` (search the collection names above) · `storage.rules` if it uploads media
- **Design spec(s):** `docs/design/COMMUNICATIONS.md`

## Tests
- `test/broadcast_card_test.dart`
- `test/broadcast_category_test.dart`
- `test/broadcast_lifecycle_test.dart`
- `test/broadcast_model_test.dart`
- `test/broadcast_permissions_test.dart`
- `test/broadcast_schedule_model_test.dart`
- `test/broadcast_template_model_test.dart`

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