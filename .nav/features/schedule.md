<!-- AUTO-GENERATED mechanical inventory. Regenerate: python3 .nav/gen_atlas.py
     Hand-authored intelligence lives BELOW the marker. Do not delete that section. -->
# 📍 FEATURE CARD — `schedule`

> `lib/features/schedule/` · **55 files** · layer-complete clean-architecture slice

## Entry points (route → screen)
| Route const | Path | Guard/notes |
|---|---|---|
| `RouteNames.adminSchedule` | `/admin/schedule` |  |
| `RouteNames.communicationsSchedules` | `/communications/schedules` |  |
| `RouteNames.managerSchedule` | `/manager/schedule` |  |
| `RouteNames.mySchedule` | `/my-schedule` |  |

## Owner files (by layer)
**presentation:page**
- `lib/features/schedule/presentation/pages/branch_schedule_screen.dart`
- `lib/features/schedule/presentation/pages/my_schedule_screen.dart`
- `lib/features/schedule/presentation/pages/schedule_final_view.dart`
- `lib/features/schedule/presentation/pages/schedule_management_screen.dart`

**presentation:cubit**
- `lib/features/schedule/presentation/cubit/schedule_cubit.dart`
- `lib/features/schedule/presentation/cubit/schedule_state.dart`
- `lib/features/schedule/presentation/cubit/schedule_state.freezed.dart`
- `lib/features/schedule/presentation/cubit/shift_swap_cubit.dart`
- `lib/features/schedule/presentation/cubit/shift_swap_state.dart`
- `lib/features/schedule/presentation/cubit/shift_swap_state.freezed.dart`
- `lib/features/schedule/presentation/cubit/shift_template_cubit.dart`
- `lib/features/schedule/presentation/cubit/shift_template_state.dart`
- `lib/features/schedule/presentation/cubit/shift_template_state.freezed.dart`

**presentation:widget**
- `lib/features/schedule/presentation/widgets/assignment_chip.dart`
- `lib/features/schedule/presentation/widgets/broken_assignment_banner.dart`
- `lib/features/schedule/presentation/widgets/chip_action_sheet.dart`
- `lib/features/schedule/presentation/widgets/day_details_sheet.dart`
- `lib/features/schedule/presentation/widgets/employee_picker_sheet.dart`
- `lib/features/schedule/presentation/widgets/employee_row.dart`
- `lib/features/schedule/presentation/widgets/final_schedule_sheet.dart`
- `lib/features/schedule/presentation/widgets/manager_schedule_view.dart`
- `lib/features/schedule/presentation/widgets/schedule_grid.dart`
- `lib/features/schedule/presentation/widgets/schedule_helpers.dart`
- `lib/features/schedule/presentation/widgets/schedule_inspector_drawer.dart`
- `lib/features/schedule/presentation/widgets/sheet_chrome.dart`
- `lib/features/schedule/presentation/widgets/shift_cell.dart`
- `lib/features/schedule/presentation/widgets/shift_details_sheet.dart`
- `lib/features/schedule/presentation/widgets/shift_hours_scope_dialog.dart`
- `lib/features/schedule/presentation/widgets/shift_templates_sheet.dart`
- `lib/features/schedule/presentation/widgets/swap_alert_card.dart`
- `lib/features/schedule/presentation/widgets/swap_view.dart`

**presentation:other**
- `lib/features/schedule/presentation/schedule_insights.dart`

**domain:entity**
- `lib/features/schedule/domain/entities/shift_swap_entity.dart`
- `lib/features/schedule/domain/entities/shift_swap_entity.freezed.dart`
- `lib/features/schedule/domain/entities/weekly_schedule_entity.dart`
- `lib/features/schedule/domain/entities/weekly_schedule_entity.freezed.dart`

**domain:repository-contract**
- `lib/features/schedule/domain/repositories/schedule_repository.dart`
- `lib/features/schedule/domain/repositories/shift_template_repository.dart`

**domain:other**
- `lib/features/schedule/domain/employee_week_stats.dart`
- `lib/features/schedule/domain/move_validation.dart`
- `lib/features/schedule/domain/schedule_week.dart`
- `lib/features/schedule/domain/shift_hours.dart`
- `lib/features/schedule/domain/shift_plan.dart`
- `lib/features/schedule/domain/shift_template.dart`
- `lib/features/schedule/domain/shift_window.dart`
- `lib/features/schedule/domain/swap_eligibility.dart`
- `lib/features/schedule/domain/swap_policy.dart`
- `lib/features/schedule/domain/swap_validation.dart`

**data:repository-impl**
- `lib/features/schedule/data/repositories/schedule_repository_impl.dart`
- `lib/features/schedule/data/repositories/shift_template_repository_impl.dart`

**data:datasource**
- `lib/features/schedule/data/datasources/schedule_remote_datasource.dart`
- `lib/features/schedule/data/datasources/shift_template_remote_datasource.dart`

**data:model**
- `lib/features/schedule/data/models/shift_swap_model.dart`
- `lib/features/schedule/data/models/shift_template_model.dart`
- `lib/features/schedule/data/models/weekly_schedule_model.dart`

## Backend surface
- **Firestore collections:** `weekly_schedules`, `shift_templates`, `shift_swaps`, `broadcastSchedules`
- **Cloud Functions:** `approveSwap`, `autoEndRecurringShiftTasks`, `generateShiftTaskInstances`, `runBroadcastSchedules`
- **Security rules:** `firestore.rules` (search the collection names above) · `storage.rules` if it uploads media
- **Design spec(s):** `docs/design/AUTO_SCHEDULE.md`, `docs/design/SCHEDULE.md`

## Tests
- `test/broadcast_schedule_model_test.dart`
- `test/my_schedule_tab_test.dart`
- `test/recurring_shift_task_test.dart`
- `test/schedule_exchange_test.dart`
- `test/schedule_final_view_test.dart`
- `test/schedule_grid_test.dart`
- `test/schedule_helpers_test.dart`
- `test/schedule_insights_test.dart`
- `test/schedule_inspector_drawer_test.dart`
- `test/schedule_silent_reload_test.dart`
- `test/schedule_undo_test.dart`
- `test/shift_hours_scope_dialog_test.dart`
- `test/shift_hours_test.dart`
- `test/shift_template_cubit_test.dart`
- `test/shift_template_model_test.dart`
- `test/shift_template_test.dart`
- `test/shift_window_test.dart`
- `test/swap_eligibility_test.dart`
- `test/swap_policy_test.dart`
- `test/swap_shift_test.dart`
- `test/swap_validation_test.dart`
- `test/task_model_schedule_test.dart`
- `test/task_model_shift_test.dart`
- `test/task_schedule_test.dart`
- `test/weekly_schedule_model_test.dart`

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