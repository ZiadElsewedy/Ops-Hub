# Attendance — GPS clock in/out · corrections · admin board

> **This file describes the shipped *engine*.** For locked **product behavior**
> (state machine, business rules, edge-case rulings, decision log) the source of
> truth is **[ATTENDANCE_SPEC.md](ATTENDANCE_SPEC.md)** (locked 2026-07-18). Where
> the two disagree on behavior, the spec wins. The early-clock-in window
> (`clockInLeadMinutes`, spec R1/R2) **is now enforced in code** — see the
> `AttendanceBlock.tooEarly` gate in
> [attendance_validation.dart:108](../../lib/features/attendance/domain/attendance_validation.dart).
> (This note previously said it was unenforced; that was stale, corrected
> 2026-07-30.)
>
> **Status:** code complete (P1–P3), **not deployed, not QA'd on device**. See
> [CURRENT_STATE](../../CURRENT_STATE.md).
>
> **Attendance minutes feed payroll.** That single fact drives every design choice
> below: the record is forgery-resistant, the audit trail is server-only, and the
> minute math has exactly one implementation.

## The shape

A record is one person, one shift, one day:

```
attendance/{uid}_{yyyyMMdd}_{shift}
  └── events/{eventId}     ← audit trail, Admin SDK ONLY
attendance_corrections/{id} ← Pending → Approved/Rejected
```

The **deterministic id** ([`domain/attendance_id.dart`](../../lib/features/attendance/domain/attendance_id.dart))
is the core trick: clock-in is idempotent and offline-safe by construction. A retry,
a double-tap, or a queued offline write all address the same document — there is no
path that creates two records for one shift, so no de-duplication logic exists
anywhere.

## Domain (pure, no Flutter/Firebase)

| File | Owns |
| --- | --- |
| `attendance_calculator.dart` | **The single source of worked / late / early / overtime minutes.** Nothing else computes them |
| `attendance_validation.dart` | `checkClockIn` (eligibility) · `checkClockOut` · `checkCorrection` |
| `attendance_gps.dart` | `gpsDistanceMeters` (Haversine) + `AttendanceVerification` |
| `attendance_board.dart` | `computeAttendanceBoard(roster, records, now, config)` — the admin board |
| `attendance_config.dart` | Grace / geofence / photo policy + the **module dark-switch** + role-resolved schedule enforcement |
| `attendance_feed.dart` | `AttendanceFeed` — records + offline/pending-write metadata |
| `attendance_id.dart` | The deterministic id |
| `attendance_resolution.dart` · `attendance_location.dart` · `attendance_break.dart` | Value objects |
| `attendance_analytics.dart` | Derived stats |
| `attendance_service.dart` · `attendance_location_service.dart` | Config + location seams |

**`AttendanceCalculator` is the whole point.** Worked minutes are computed in one
place and persisted as a **snapshot only at clock-out or correction-approve** —
never recomputed on read, so a config change cannot retroactively alter a closed
shift's pay. If you need minute math, call the calculator. Do not inline it.

Managers use the same attendance, account, leave, duplicate-punch, and GPS gates
as employees, but `AttendanceService.configFor` resolves
`enforceSchedule: false` for them. Their punch is presence tracking — an **open
shift**: clock in and out at any time, with or without a rostered slot, and no
scheduled window (so nothing to be late for) even on a day they happen to be
rostered. Employees retain schedule-required and early-window validation. This
does not alter worked-minute calculation.

- **The clock target always exists for a presence role.** `AttendanceCubit._resolveContext`
  synthesizes a presence-only target (the time-of-day bucket via
  `unscheduledShiftFor`, no scheduled window) whenever a manager has no rostered
  slot — so the **primary** Clock In writes a record directly. Without this the
  primary path fell through (`clockIn` needs a `targetRecordId`/`shift`) and a
  manager's only route was the deliberate "unscheduled shift" action. The screen
  frames this as an **OPEN SHIFT / Manager shift** ready state.
- **`branches/{id}.managersCanClock`** is the per-branch switch. False ⇒
  `configFor` resolves `enabled: false` for a manager, and the personal clock
  screen renders an explanatory *"Clocking is off for managers here"* state (a
  live session still wins, so the flag can never trap someone mid-shift) — the
  manager keeps attendance review and approval. Edited in the branch form sheet;
  employees are always enabled. A manager reaches their own clock from the mobile
  role app-bar (fingerprint) and the desktop sidebar's **My Clock** door.

## Verification

Clock-in and clock-out carry **separate** verifications
(`clockInVerification` / `clockOutVerification`) — a single field could not express
"arrived on site, left early from elsewhere", which is exactly what matters.

`AttendanceVerification` snapshots the branch's radius and accuracy floor **at the
time of the punch**, so later editing a geofence never rewrites history — the same
principle as [ADR-006](../decisions/ADR-006-schedule-shift-plan-snapshots.md).

- `BranchGeofence` (lat · lng · radius · `minGpsAccuracy`) lives on the branch —
  [`branch/domain/branch_geofence.dart`](../../lib/features/branch/domain/branch_geofence.dart),
  edited via `BranchRepository.setGeofence`.
- Clock **times are server timestamps**. `effectiveClockIn` covers the live timer
  until the server value syncs back, so the UI never shows a client clock.
- `checkGpsFix` is the gate: it rejects service-off · permission-denied ·
  no-geofence · low-accuracy · outside-radius.

> **Clock-out is never GPS-blocked.** It records verification and lets you leave.
> Trapping someone at work because their GPS drifted is not a feature.

## Corrections

A correction is an approval object, deliberately the same shape as a Request —
see [ADR-008](../decisions/ADR-008-requests-are-approvals.md). It reuses
`RequestStatus`.

```
employee files          → RequestCorrection
reviewer decides        → DecideCorrection   (computes the corrected snapshot
                                              via AttendanceCalculator)
server applies + audits → onAttendanceCorrectionWritten
```

**Self-approval is forbidden server-side**, not hidden in the UI.

## Server authority

The client writes a **deliberately narrow slice** of the record: a clock-in creates
an open, zero-minute record; a clock-out sets `clockOut` + `status` +
`clockOutVerification`. **It never writes a worked/late/early/overtime/break minute**
— those feed payroll and are computed by the Admin SDK, so the client cannot choose
its own pay or backdate its arrival ([ADR-024](../decisions/ADR-024-server-authoritative-attendance-minutes.md)).
The audit trail is derived by diffing, in a Function — see
[ADR-005](../decisions/ADR-005-server-authoritative-writes.md).

| Function | Does |
| --- | --- |
| `onAttendanceWritten` | Derives audit events by diffing the record **and finalizes the authoritative minute snapshot** (`attendance_totals.js`, a port of `AttendanceCalculator`, guarded on `source: 'clock'`) |
| `onAttendanceCorrectionWritten` | Correction lifecycle → apply → audit → notify |
| `autoCloseAttendance` | Scheduled: never-clocked-out sessions → `pendingReview` |

The `attendance` **create** and owner **update** rules pin every payroll-sensitive
field (minutes, clock-in, the scheduled window, `source`), so a client write can only
ever be a genuine clock-in or clock-out — pinned by
`firestore-tests/attendance.rules.test.mjs`. Clients **cannot write
`attendance/{id}/events` at all.** That is what makes "nothing silently modifies
attendance" an enforceable claim rather than a hope.

## Presentation

**Employee** — `attendance_screen.dart` (`/attendance`). `AttendanceCubit` drives the
entire surface from **one** realtime history stream, resolving today's shift through
the existing `ScheduleRepository` seam rather than re-deriving the roster. The feed
exposes today · session · loading · **syncing** · **offline** · clock-availability ·
validation errors.

Flow: Today's Shift → GPS-gated Clock In → live `HH:MM:SS` Working → Today's Summary.
A state-driven GPS card reads a live `previewLocation()`: Checking · At-branch ·
Outside · Permission · Off.

**Admin** — `admin_attendance_screen.dart` (`/admin/attendance`). The **schedule ×
attendance board**: `AttendanceAdminCubit` fuses the roster (`getSchedule` +
`employeesFor` + `ShiftWindow` + `GetUsersByBranch`) with live `watchBranchDay` +
`watchBranchPendingCorrections`. `computeAttendanceBoard` derives Not-started → Late
→ Absent by time, plus Working / Completed / On-leave / Needs-review. Branch picker ·
filterable KPIs · details sheet · corrections approve/reject · GPS-area shortcut.

**Geofence editor** — `branch/presentation/pages/branch_geofence_editor_screen.dart`.

> The admin cubit and screen are **branch-scoped**, so a future manager view is the
> same code pinned to one branch. Descoped for V1 — don't rebuild it.

**History** — the longitudinal ledger (`presentation/history/` +
`presentation/details/`), built **entirely on the existing reads**
(`watchUserHistory` · `watchBranchRange` · `watchEvents` ·
`watchRecordCorrections`) plus the pure `AttendanceStats` and the new pure
`AttendanceHistoryQuery` (date-range preset incl. **Today/Yesterday** + a
**multi-select** status facet set combined with OR + shift + a name search that is
**Arabic- and diacritic-insensitive** via `attendanceSearchNormalize` → resolve +
`apply`) — no new data path, no parallel repository. One `AttendanceHistoryScreen`
serves two entries: `.self()` (`/attendance/history`, any authenticated role — the
caller's own history) and `.review()` (`/attendance/review`, **admin‖manager** via
the `_isAttendanceReviewArea` guard — the branch ledger, with an admin branch
picker + employee-name search). A record card opens the audit-log Details screen
(`/attendance/record/:id`, seeded via go_router `extra` for an instant paint):
scheduled window · clock in/out + GPS · worked/late/early/overtime · **Timeline**
(the server `events` through the shared `TimelineTile`, with a record-derived
fallback until `onAttendanceWritten` is deployed) · corrections · an expandable
**Metadata** block that shows **only recorded fields** (no invented
timezone/appVersion/syncStatus). The summary strip reflects the date *window*;
status/shift facets narrow only the list. Cubits are built on demand
(`AppDependencies.createAttendanceHistoryCubit` / `createAttendanceDetailsCubit`,
the requests-detail pattern). **Entry points:** the employee clock screen's *View
history* → the self ledger; the admin board gains a *History* action + a *View full
record* sheet button; a **manager** reaches the branch ledger from the desktop
sidebar (+⌘K) and a home-screen tile — their first attendance-oversight surface.
**Weekly & monthly reports and their exports have since shipped** (client-side
CSV timesheet + PDF summary, gated by `attendance_export_gate.dart`; see
[ADR-019](../decisions/ADR-019-operational-exports-and-week-review.md)) — the
"Report generation" surfaces under `presentation/reporting/`. The hub also carries a
**Rankings** board (`attendance_rankings.dart` + `AttendanceRankingsCard`) that ranks
the streamed ledger by a chosen metric — overtime · lateness · absences · missing
punches · hours worked — answering "*who* has the most X this period", with no extra
read. Still deferred, holding
[ADR-009](../decisions/ADR-009-no-analytics-pipeline.md) +
[ADR-010](../decisions/ADR-010-lean-over-enterprise.md): a performance score,
analytics/heatmaps/trends, and a machine-readable payroll export — the ledger data
already supports them.

## Removed — dormant extension points

**Breaks** were cut for the MVP. `AttendanceBreak`, the `breaks` field, and the
calculator's netting remain as extension points. `attendance_break_test.dart` still
covers them. Re-enabling is additive; do not delete these to "clean up".

## Tests

17 files: `attendance_calculator` · `attendance_gps` · `attendance_board` ·
`attendance_validation` · `attendance_id` · `attendance_entity` · `attendance_model` ·
`attendance_correction_model` · `attendance_correction_validation` ·
`attendance_status` · `attendance_analytics` · `attendance_break` ·
`attendance_cubit` · `attendance_history_query` · `attendance_status_filter` ·
`attendance_history_cubit` · `attendance_history_widgets`.

## Before shipping

1. **Deploy** — `functions,firestore:rules,firestore:indexes`. Until then the audit
   trail is not written and corrections do not apply.
2. **QA on real hardware, both platforms.** A simulator cannot validate a geofence.
