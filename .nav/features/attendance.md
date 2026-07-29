<!-- AUTO-GENERATED mechanical inventory. Regenerate: python3 .nav/gen_atlas.py
     Hand-authored intelligence lives BELOW the marker. Do not delete that section. -->
# 📍 FEATURE CARD — `attendance`

> `lib/features/attendance/` · **54 files** · layer-complete clean-architecture slice

## Entry points (route → screen)
| Route const | Path | Guard/notes |
|---|---|---|
| `RouteNames.adminAttendance` | `/admin/attendance` |  |
| `RouteNames.attendance` | `/attendance` |  |
| `RouteNames.attendanceHistory` | `/attendance/history` |  |
| `RouteNames.attendanceRecordPattern` | `/attendance/record/:id` |  |
| `RouteNames.attendanceReview` | `/attendance/review` |  |

## Owner files (by layer)
**presentation:page**
- `lib/features/attendance/presentation/pages/admin_attendance_screen.dart`
- `lib/features/attendance/presentation/pages/attendance_screen.dart`

**presentation:cubit**
- `lib/features/attendance/presentation/cubit/attendance_admin_cubit.dart`
- `lib/features/attendance/presentation/cubit/attendance_admin_state.dart`
- `lib/features/attendance/presentation/cubit/attendance_admin_state.freezed.dart`
- `lib/features/attendance/presentation/cubit/attendance_cubit.dart`
- `lib/features/attendance/presentation/cubit/attendance_state.dart`
- `lib/features/attendance/presentation/cubit/attendance_state.freezed.dart`

**presentation:widget**
- `lib/features/attendance/presentation/widgets/attendance_action_sheet.dart`

**presentation:other**
- `lib/features/attendance/presentation/details/attendance_details_cubit.dart`
- `lib/features/attendance/presentation/details/attendance_details_screen.dart`
- `lib/features/attendance/presentation/details/attendance_details_state.dart`
- `lib/features/attendance/presentation/details/attendance_details_state.freezed.dart`
- `lib/features/attendance/presentation/details/widgets/attendance_correction_section.dart`
- `lib/features/attendance/presentation/details/widgets/attendance_metadata_section.dart`
- `lib/features/attendance/presentation/details/widgets/attendance_shift_section.dart`
- `lib/features/attendance/presentation/details/widgets/attendance_timeline.dart`
- `lib/features/attendance/presentation/history/attendance_history_cubit.dart`
- `lib/features/attendance/presentation/history/attendance_history_screen.dart`
- `lib/features/attendance/presentation/history/attendance_history_state.dart`
- `lib/features/attendance/presentation/history/attendance_history_state.freezed.dart`
- `lib/features/attendance/presentation/history/widgets/attendance_history_filters.dart`
- `lib/features/attendance/presentation/history/widgets/attendance_history_summary.dart`
- `lib/features/attendance/presentation/history/widgets/attendance_record_card.dart`

**domain:entity**
- `lib/features/attendance/domain/entities/attendance_correction.dart`
- `lib/features/attendance/domain/entities/attendance_correction.freezed.dart`
- `lib/features/attendance/domain/entities/attendance_entity.dart`
- `lib/features/attendance/domain/entities/attendance_entity.freezed.dart`
- `lib/features/attendance/domain/entities/attendance_event.dart`
- `lib/features/attendance/domain/entities/attendance_event.freezed.dart`

**domain:usecase**
- `lib/features/attendance/domain/usecases/clock_in.dart`
- `lib/features/attendance/domain/usecases/clock_out.dart`
- `lib/features/attendance/domain/usecases/decide_correction.dart`
- `lib/features/attendance/domain/usecases/request_correction.dart`

**domain:repository-contract**
- `lib/features/attendance/domain/repositories/attendance_repository.dart`

**domain:other**
- `lib/features/attendance/domain/attendance_analytics.dart`
- `lib/features/attendance/domain/attendance_board.dart`
- `lib/features/attendance/domain/attendance_break.dart`
- `lib/features/attendance/domain/attendance_calculator.dart`
- `lib/features/attendance/domain/attendance_config.dart`
- `lib/features/attendance/domain/attendance_feed.dart`
- `lib/features/attendance/domain/attendance_gps.dart`
- `lib/features/attendance/domain/attendance_history_query.dart`
- `lib/features/attendance/domain/attendance_id.dart`
- `lib/features/attendance/domain/attendance_location.dart`
- `lib/features/attendance/domain/attendance_location_service.dart`
- `lib/features/attendance/domain/attendance_resolution.dart`
- `lib/features/attendance/domain/attendance_service.dart`
- `lib/features/attendance/domain/attendance_validation.dart`

**data:repository-impl**
- `lib/features/attendance/data/repositories/attendance_repository_impl.dart`

**data:datasource**
- `lib/features/attendance/data/datasources/attendance_remote_datasource.dart`

**data:model**
- `lib/features/attendance/data/models/attendance_correction_model.dart`
- `lib/features/attendance/data/models/attendance_model.dart`

**data:other**
- `lib/features/attendance/data/services/geolocator_location_service.dart`

## Backend surface
- **Firestore collections:** `attendance`, `attendance_corrections`
- **Cloud Functions:** `autoCloseAttendance`, `onAttendanceCorrectionWritten`, `onAttendanceWritten`
- **Security rules:** `firestore.rules` (search the collection names above) · `storage.rules` if it uploads media
- **Design spec(s):** `docs/design/ATTENDANCE.md`, `docs/design/ATTENDANCE_SPEC.md`

## Tests
- `test/attendance_action_sheet_test.dart`
- `test/attendance_admin_direct_action_test.dart`
- `test/attendance_analytics_test.dart`
- `test/attendance_board_test.dart`
- `test/attendance_break_test.dart`
- `test/attendance_calculator_test.dart`
- `test/attendance_correction_model_test.dart`
- `test/attendance_correction_validation_test.dart`
- `test/attendance_cubit_test.dart`
- `test/attendance_entity_test.dart`
- `test/attendance_gps_test.dart`
- `test/attendance_history_cubit_test.dart`
- `test/attendance_history_query_test.dart`
- `test/attendance_history_widgets_test.dart`
- `test/attendance_id_test.dart`
- `test/attendance_model_test.dart`
- `test/attendance_status_filter_test.dart`
- `test/attendance_status_test.dart`
- `test/attendance_validation_test.dart`
- `test/branch_geofence_test.dart`

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