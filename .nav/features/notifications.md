<!-- AUTO-GENERATED mechanical inventory. Regenerate: python3 .nav/gen_atlas.py
     Hand-authored intelligence lives BELOW the marker. Do not delete that section. -->
# 📍 FEATURE CARD — `notifications`

> `lib/features/notifications/` · **18 files** · layer-complete clean-architecture slice

## Entry points (route → screen)
| Route const | Path | Guard/notes |
|---|---|---|
| `RouteNames.notifications` | `/notifications` |  |
| `RouteNames.notificationSettings` | `/settings/notifications` |  |

## Owner files (by layer)
**presentation:page**
- `lib/features/notifications/presentation/pages/notifications_screen.dart`

**presentation:cubit**
- `lib/features/notifications/presentation/cubit/notification_cubit.dart`
- `lib/features/notifications/presentation/cubit/notification_state.dart`
- `lib/features/notifications/presentation/cubit/notification_state.freezed.dart`

**presentation:widget**
- `lib/features/notifications/presentation/widgets/notification_tile.dart`

**presentation:other**
- `lib/features/notifications/presentation/notification_format.dart`
- `lib/features/notifications/presentation/notification_navigation.dart`

**domain:entity**
- `lib/features/notifications/domain/entities/notification_entity.dart`
- `lib/features/notifications/domain/entities/notification_entity.freezed.dart`

**domain:usecase**
- `lib/features/notifications/domain/usecases/mark_notification_read.dart`
- `lib/features/notifications/domain/usecases/notify_swap_event.dart`
- `lib/features/notifications/domain/usecases/notify_task_event.dart`

**domain:repository-contract**
- `lib/features/notifications/domain/repositories/notification_repository.dart`

**domain:other**
- `lib/features/notifications/domain/notification_deep_link.dart`

**data:repository-impl**
- `lib/features/notifications/data/repositories/notification_repository_impl.dart`

**data:datasource**
- `lib/features/notifications/data/datasources/notification_remote_datasource.dart`
- `lib/features/notifications/data/datasources/notification_sweep.dart`

**data:model**
- `lib/features/notifications/data/models/notification_model.dart`

## Backend surface
- **Firestore collections:** `taskReminders`, `reminderConfig`, `notifications`
- **Cloud Functions:** `claimFcmToken`, `onNotificationCreated`, `runTaskReminders`, `sendNotification`
- **Security rules:** `firestore.rules` (search the collection names above) · `storage.rules` if it uploads media
- **Design spec(s):** `docs/design/NOTIFICATIONS.md`

## Tests
- `test/delivered_notifications_test.dart`
- `test/features/settings/notification_preferences_test.dart`
- `test/features/settings/notifications_settings_screen_test.dart`
- `test/notification_cubit_test.dart`
- `test/notification_deep_link_test.dart`
- `test/notification_grouping_test.dart`
- `test/notification_model_test.dart`
- `test/notification_sweep_test.dart`
- `test/notification_tap_flow_probe_test.dart`
- `test/notification_tap_navigation_test.dart`
- `test/notification_task_copy_test.dart`
- `test/reminder_rules_test.dart`

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