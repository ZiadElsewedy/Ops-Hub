<!-- AUTO-GENERATED mechanical inventory. Regenerate: python3 .nav/gen_atlas.py
     Hand-authored intelligence lives BELOW the marker. Do not delete that section. -->
# 📍 FEATURE CARD — `sales`

> `lib/features/sales/` · **52 files** · layer-complete clean-architecture slice

## Entry points (route → screen)
| Route const | Path | Guard/notes |
|---|---|---|
| `RouteNames.salesManage` | `/sales` |  |
| `RouteNames.salesAdminOverview` | `/sales/admin` |  |
| `RouteNames.salesHistory` | `/sales/history` |  |
| `RouteNames.salesMine` | `/sales/mine` |  |
| `RouteNames.salesSubmissionDetailPattern` | `/sales/submission/:submissionId` |  |
| `RouteNames.salesSubmit` | `/sales/submit` |  |

## Owner files (by layer)
**presentation:page**
- `lib/features/sales/presentation/pages/employee_sales_screen.dart`
- `lib/features/sales/presentation/pages/sales_admin_overview_screen.dart`
- `lib/features/sales/presentation/pages/sales_history_screen.dart`
- `lib/features/sales/presentation/pages/sales_manager_dashboard_screen.dart`
- `lib/features/sales/presentation/pages/sales_submission_detail_screen.dart`
- `lib/features/sales/presentation/pages/sales_submission_screen.dart`

**presentation:cubit**
- `lib/features/sales/presentation/cubit/sales_admin_overview_cubit.dart`
- `lib/features/sales/presentation/cubit/sales_manager_dashboard_cubit.dart`
- `lib/features/sales/presentation/cubit/sales_month_cubit.dart`
- `lib/features/sales/presentation/cubit/sales_month_state.dart`
- `lib/features/sales/presentation/cubit/sales_submission_detail_cubit.dart`

**presentation:widget**
- `lib/features/sales/presentation/widgets/admin_branch_sales_summary.dart`
- `lib/features/sales/presentation/widgets/sales_money_row.dart`
- `lib/features/sales/presentation/widgets/sales_month_overview.dart`
- `lib/features/sales/presentation/widgets/sales_needed_per_day.dart`
- `lib/features/sales/presentation/widgets/sales_pace_card.dart`
- `lib/features/sales/presentation/widgets/sales_progress_ring.dart`
- `lib/features/sales/presentation/widgets/sales_reason_sheet.dart`
- `lib/features/sales/presentation/widgets/sales_submission_tile.dart`
- `lib/features/sales/presentation/widgets/sales_submissions_door.dart`
- `lib/features/sales/presentation/widgets/sales_target_card.dart`
- `lib/features/sales/presentation/widgets/sales_target_editor_sheet.dart`

**presentation:other**
- `lib/features/sales/presentation/sales_format.dart`

**domain:entity**
- `lib/features/sales/domain/entities/branch_sales_month_entity.dart`
- `lib/features/sales/domain/entities/branch_sales_month_entity.freezed.dart`
- `lib/features/sales/domain/entities/daily_sales_submission_entity.dart`
- `lib/features/sales/domain/entities/daily_sales_submission_entity.freezed.dart`
- `lib/features/sales/domain/entities/sales_kpis.dart`
- `lib/features/sales/domain/entities/sales_kpis.freezed.dart`
- `lib/features/sales/domain/entities/sales_month_snapshot.dart`
- `lib/features/sales/domain/entities/sales_month_snapshot.freezed.dart`

**domain:usecase**
- `lib/features/sales/domain/usecases/approve_sales_submission.dart`
- `lib/features/sales/domain/usecases/edit_approved_sales_submission.dart`
- `lib/features/sales/domain/usecases/get_current_sales_month.dart`
- `lib/features/sales/domain/usecases/reject_sales_submission.dart`
- `lib/features/sales/domain/usecases/reopen_sales_submission.dart`
- `lib/features/sales/domain/usecases/request_sales_correction.dart`
- `lib/features/sales/domain/usecases/resubmit_corrected_sales.dart`
- `lib/features/sales/domain/usecases/set_branch_monthly_target.dart`
- `lib/features/sales/domain/usecases/submit_daily_sales.dart`
- `lib/features/sales/domain/usecases/watch_sales_submissions.dart`

**domain:repository-contract**
- `lib/features/sales/domain/repositories/sales_repository.dart`

**domain:other**
- `lib/features/sales/domain/sales_branch_scope.dart`
- `lib/features/sales/domain/sales_business_time.dart`
- `lib/features/sales/domain/sales_calculator.dart`
- `lib/features/sales/domain/sales_kpis_calculator.dart`
- `lib/features/sales/domain/sales_submission_id.dart`
- `lib/features/sales/domain/sales_trend.dart`

**data:repository-impl**
- `lib/features/sales/data/repositories/sales_repository_impl.dart`

**data:datasource**
- `lib/features/sales/data/datasources/sales_remote_datasource.dart`

**data:model**
- `lib/features/sales/data/models/branch_sales_month_model.dart`
- `lib/features/sales/data/models/daily_sales_submission_model.dart`

## Backend surface
- **Firestore collections:** `branch_sales_months`, `branch_sales_submissions`
- **Cloud Functions:** `decideDailySalesSubmission`, `editApprovedDailySalesSubmission`, `onDailySalesSubmissionCreated`, `resubmitCorrectedSales`, `setBranchSalesTarget`
- **Security rules:** `firestore.rules` (search the collection names above) · `storage.rules` if it uploads media
- **Design spec(s):** `docs/design/SALES_TARGETS.md`

## Tests
- `test/features/sales/data/branch_sales_month_model_test.dart`
- `test/features/sales/data/daily_sales_submission_model_test.dart`
- `test/features/sales/domain/sales_branch_scope_test.dart`
- `test/features/sales/domain/sales_business_time_test.dart`
- `test/features/sales/domain/sales_calculator_test.dart`
- `test/features/sales/domain/sales_submission_id_test.dart`
- `test/features/sales/domain/sales_trend_test.dart`
- `test/features/sales/presentation/sales_admin_overview_cubit_test.dart`
- `test/features/sales/presentation/sales_dashboard_widgets_test.dart`
- `test/features/sales/presentation/sales_format_test.dart`
- `test/features/sales/presentation/sales_manager_dashboard_cubit_test.dart`
- `test/features/sales/presentation/sales_month_cubit_test.dart`
- `test/features/sales/presentation/sales_submission_detail_cubit_test.dart`
- `test/features/sales/sales_route_access_test.dart`

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