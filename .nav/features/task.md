<!-- AUTO-GENERATED mechanical inventory. Regenerate: python3 .nav/gen_atlas.py
     Hand-authored intelligence lives BELOW the marker. Do not delete that section. -->
# 📍 FEATURE CARD — `task`

> `lib/features/task/` · **101 files** · layer-complete clean-architecture slice

## Entry points (route → screen)
| Route const | Path | Guard/notes |
|---|---|---|
| `RouteNames.adminTasks` | `/admin/tasks` |  |
| `RouteNames.managerTasks` | `/manager/tasks` |  |
| `RouteNames.myTasks` | `/my-tasks` |  |
| `RouteNames.taskDetailPattern` | `/task/:taskId` |  |

## Owner files (by layer)
**presentation:page**
- `lib/features/task/presentation/pages/admin_task_overview_screen.dart`
- `lib/features/task/presentation/pages/branch_task_list_screen.dart`
- `lib/features/task/presentation/pages/filtered_tasks_screen.dart`
- `lib/features/task/presentation/pages/my_tasks_screen.dart`
- `lib/features/task/presentation/pages/pending_review_screen.dart`
- `lib/features/task/presentation/pages/task_detail_loader_screen.dart`
- `lib/features/task/presentation/pages/task_details_screen.dart`
- `lib/features/task/presentation/pages/task_management_screen.dart`

**presentation:cubit**
- `lib/features/task/presentation/cubit/task_cubit.dart`
- `lib/features/task/presentation/cubit/task_state.dart`
- `lib/features/task/presentation/cubit/task_state.freezed.dart`

**presentation:widget**
- `lib/features/task/presentation/widgets/activity_timeline.dart`
- `lib/features/task/presentation/widgets/attachment_gallery.dart`
- `lib/features/task/presentation/widgets/attachment_picker.dart`
- `lib/features/task/presentation/widgets/attachment_viewer.dart`
- `lib/features/task/presentation/widgets/dynamic_work_form.dart`
- `lib/features/task/presentation/widgets/live_status_border.dart`
- `lib/features/task/presentation/widgets/manager_task_card.dart`
- `lib/features/task/presentation/widgets/recent_activity_feed.dart`
- `lib/features/task/presentation/widgets/recurring_shift_task_sheets.dart`
- `lib/features/task/presentation/widgets/submission_details_sheet.dart`
- `lib/features/task/presentation/widgets/submission_loading_overlay.dart`
- `lib/features/task/presentation/widgets/task_action_sheets.dart`
- `lib/features/task/presentation/widgets/task_action_sheets/assign_sheet.dart`
- `lib/features/task/presentation/widgets/task_action_sheets/assignee_picker_sheet.dart`
- `lib/features/task/presentation/widgets/task_action_sheets/branch_picker_sheet.dart`
- `lib/features/task/presentation/widgets/task_action_sheets/cancel_sheet.dart`
- `lib/features/task/presentation/widgets/task_action_sheets/checklist_builder.dart`
- `lib/features/task/presentation/widgets/task_action_sheets/review_sheet.dart`
- `lib/features/task/presentation/widgets/task_action_sheets/shared/form_primitives.dart`
- `lib/features/task/presentation/widgets/task_action_sheets/shift_pickers.dart`
- `lib/features/task/presentation/widgets/task_action_sheets/task_form_sheet.dart`
- `lib/features/task/presentation/widgets/task_activity_card.dart`
- `lib/features/task/presentation/widgets/task_attention_surface.dart`
- `lib/features/task/presentation/widgets/task_badge.dart`
- `lib/features/task/presentation/widgets/task_card.dart`
- `lib/features/task/presentation/widgets/task_empty_state.dart`
- `lib/features/task/presentation/widgets/task_feed_expansion.dart`
- `lib/features/task/presentation/widgets/task_feed_row.dart`
- `lib/features/task/presentation/widgets/task_feed_section.dart`
- `lib/features/task/presentation/widgets/task_preview_sheet.dart`
- `lib/features/task/presentation/widgets/task_surface.dart`
- `lib/features/task/presentation/widgets/task_template_sheets.dart`
- `lib/features/task/presentation/widgets/video_thumbnail_image.dart`
- `lib/features/task/presentation/widgets/work_detail_sections.dart`
- `lib/features/task/presentation/widgets/work_type_panel.dart`

**presentation:other**
- `lib/features/task/presentation/activity_format.dart`
- `lib/features/task/presentation/attachment_format.dart`
- `lib/features/task/presentation/submission_progress.dart`
- `lib/features/task/presentation/work_type_presenter.dart`

**domain:entity**
- `lib/features/task/domain/entities/activity_entry.dart`
- `lib/features/task/domain/entities/activity_entry.freezed.dart`
- `lib/features/task/domain/entities/automation_health.dart`
- `lib/features/task/domain/entities/automation_run_entity.dart`
- `lib/features/task/domain/entities/checklist_item.dart`
- `lib/features/task/domain/entities/checklist_item.freezed.dart`
- `lib/features/task/domain/entities/recurrence_config.dart`
- `lib/features/task/domain/entities/recurrence_config.freezed.dart`
- `lib/features/task/domain/entities/recurring_task_template_entity.dart`
- `lib/features/task/domain/entities/recurring_task_template_entity.freezed.dart`
- `lib/features/task/domain/entities/task_attachment.dart`
- `lib/features/task/domain/entities/task_attachment.freezed.dart`
- `lib/features/task/domain/entities/task_entity.dart`
- `lib/features/task/domain/entities/task_entity.freezed.dart`
- `lib/features/task/domain/entities/task_template_entity.dart`
- `lib/features/task/domain/entities/task_template_entity.freezed.dart`

**domain:usecase**
- `lib/features/task/domain/usecases/assign_task.dart`
- `lib/features/task/domain/usecases/create_task.dart`
- `lib/features/task/domain/usecases/delete_task.dart`
- `lib/features/task/domain/usecases/update_task.dart`
- `lib/features/task/domain/usecases/upload_task_attachment.dart`

**domain:repository-contract**
- `lib/features/task/domain/repositories/task_repository.dart`

**domain:other**
- `lib/features/task/domain/active_window.dart`
- `lib/features/task/domain/note_category.dart`
- `lib/features/task/domain/reminder_rules.dart`
- `lib/features/task/domain/task_access.dart`
- `lib/features/task/domain/task_feed.dart`
- `lib/features/task/domain/task_metrics.dart`
- `lib/features/task/domain/task_ordering.dart`
- `lib/features/task/domain/task_outcomes.dart`
- `lib/features/task/domain/task_schedule.dart`
- `lib/features/task/domain/work_types/definitions/general_work_type.dart`
- `lib/features/task/domain/work_types/definitions/inspection_work_type.dart`
- `lib/features/task/domain/work_types/definitions/inventory_count_work_type.dart`
- `lib/features/task/domain/work_types/definitions/purchase_errand_work_type.dart`
- `lib/features/task/domain/work_types/definitions/transfer_work_type.dart`
- `lib/features/task/domain/work_types/task_work_x.dart`
- `lib/features/task/domain/work_types/work_context.dart`
- `lib/features/task/domain/work_types/work_draft.dart`
- `lib/features/task/domain/work_types/work_event.dart`
- `lib/features/task/domain/work_types/work_field_spec.dart`
- `lib/features/task/domain/work_types/work_review.dart`
- `lib/features/task/domain/work_types/work_type_definition.dart`
- `lib/features/task/domain/work_types/work_type_registry.dart`
- `lib/features/task/domain/work_types/work_validation.dart`

**data:repository-impl**
- `lib/features/task/data/repositories/task_repository_impl.dart`

**data:datasource**
- `lib/features/task/data/datasources/task_remote_datasource.dart`

**data:model**
- `lib/features/task/data/models/automation_run_model.dart`
- `lib/features/task/data/models/recurring_task_template_model.dart`
- `lib/features/task/data/models/task_model.dart`
- `lib/features/task/data/models/task_template_model.dart`

## Backend surface
- **Firestore collections:** `tasks`, `task_templates`, `recurringTaskTemplates`, `taskReminders`
- **Cloud Functions:** `autoEndRecurringShiftTasks`, `generateShiftTaskInstances`, `runTaskReminders`, `taskHousekeeping`
- **Security rules:** `firestore.rules` (search the collection names above) · `storage.rules` if it uploads media
- **Design spec(s):** `docs/design/AUTOMATED_TASKS_PRODUCT_SPEC.md`, `docs/design/TASKS.md`

## Tests
- `test/admin_task_overview_screen_test.dart`
- `test/my_tasks_tabs_test.dart`
- `test/recurring_shift_task_test.dart`
- `test/task_access_test.dart`
- `test/task_archive_test.dart`
- `test/task_assignment_type_test.dart`
- `test/task_attachment_test.dart`
- `test/task_attention_surface_test.dart`
- `test/task_badge_test.dart`
- `test/task_cancellation_test.dart`
- `test/task_card_layout_test.dart`
- `test/task_card_live_status_test.dart`
- `test/task_checklist_test.dart`
- `test/task_cubit_test.dart`
- `test/task_feed_expansion_test.dart`
- `test/task_feed_row_test.dart`
- `test/task_feed_test.dart`
- `test/task_metrics_test.dart`
- `test/task_model_reference_test.dart`
- `test/task_model_rework_test.dart`
- `test/task_model_schedule_test.dart`
- `test/task_model_shift_test.dart`
- `test/task_model_work_type_test.dart`
- `test/task_ordering_test.dart`
- `test/task_outcomes_test.dart`
- `test/task_preview_sheet_test.dart`
- `test/task_schedule_test.dart`
- `test/task_seen_store_test.dart`
- `test/task_shift_stream_binding_test.dart`
- `test/task_start_gate_widget_test.dart`
- `test/task_status_test.dart`
- `test/task_submission_gate_test.dart`
- `test/task_template_sheets_test.dart`

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