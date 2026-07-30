# DROP Attendance & Reports IA

Date: 2026-07-30

This is the decided information architecture for the Attendance & Reports module
under ADR-017. The pure reporting-domain core started on 2026-07-30
(`features/attendance/domain/reporting/`), and the P0 ledger read layer, reports
hub, weekly report, close pipeline, rules, and indexes now exist. Exports,
locks, monthly, per-employee, and comparison reports remain design only.

Reading guide:

- Read section 1 for the whole structure in one page.
- Read sections 4-5 before touching routes or navigation.
- Read sections 6-9 before building reports, metrics, or filters.
- Read section 12 before building any export.
- Current-behavior claims cite repository paths and lines. Where this document
  infers a future implementation, it says "inferred".

## 1. The decision in one page

### 1.1 Module identity

The module is **Attendance & Reports** for admin and manager.

The employee-facing label stays **Attendance** because employees primarily clock
in, clock out, and verify their own record.

| Role | Desktop nav label | Mobile placement | Primary route |
| --- | --- | --- | --- |
| Admin | Attendance & Reports | Admin Dashboard attention card, not bottom nav | NEW `RouteNames.attendanceReports` |
| Manager | Attendance & Reports | Manager Home close-readiness card, not bottom nav | NEW `RouteNames.attendanceBranch(...)` |
| Employee | Attendance | Existing top action and sidebar item | EXISTING `RouteNames.attendance` |

Decision: the reporting system is not a separate "Analytics" module. It is the
reporting half of Attendance because every report reconciles attendance facts
against the roster.

Considered and rejected: putting reports under the existing admin "Analytics"
destination, because ADR-017 authorizes an attendance ledger, not a generic
analytics surface.

### 1.2 Report hierarchy

```text
Attendance & Reports
|-- Live attendance
|   |-- Employee clock
|   |-- Branch live board
|   `-- Record detail
|
`-- Reporting ledger
    |-- Reports hub
    |   |-- Branch comparison
    |   |-- Export ledger
    |   `-- Branch workspace
    |       |-- Daily close
    |       |-- Exception queue
    |       |-- Weekly report
    |       |   |-- Employee row drill-down
    |       |   `-- Shift row evidence
    |       |-- Monthly report
    |       |   |-- Employee row drill-down
    |       |   `-- Shift row evidence
    |       |-- Pay-period report
    |       `-- Branch ledger evidence
    |
    `-- My attendance
        |-- Clock surface
        |-- My period record
        `-- My ledger evidence
```

### 1.3 Decisions this document makes

1. The canonical manager/admin module label is **Attendance & Reports**; the
   employee label remains **Attendance**.
2. Reports are destinations; history is evidence and drill-down only.
3. The manager lands on a **Branch Attendance Workspace**, not a flat history list.
4. The admin lands on an **Attendance & Reports Hub**, not a one-branch live board.
5. The first-class Weekly Report uses the Schedule week: **Sunday through
   Saturday**, in `Africa/Cairo`.
6. The first-class Monthly Report uses the calendar month in `Africa/Cairo` and
   exists for payroll/accounting readiness, not just a longer weekly view.
7. Daily work is cleared through the **Exception Queue**, not by filtering history.
8. Filters are split into scope, facets, and saved views. Lifecycle status and
   derived facts are no longer mixed in one chip row.
9. CSV exports are server-generated only. PDF exports are offered only where a
   stable summary is useful to read or file.
10. No report ships before the close pipeline materializes durable expected-shift
    rows and no-show rows.
11. A materialized expected shift with zero clock-ins is a real **0%** attendance
    result. A day or period with no ledger rows is **No ledger data**: a
    data-completeness gap with no denominator, not a zero-attendance result.

### 1.4 Current facts this replaces

The current branch review route is a branch ledger with a summary strip, filter
bar, and record cards, built from `AttendanceHistoryScreen.review` and a
`ListView` body (`lib/features/attendance/presentation/history/attendance_history_screen.dart:24`,
`lib/features/attendance/presentation/history/attendance_history_screen.dart:148`).
The current filter widget renders search plus three chip rows
(`lib/features/attendance/presentation/history/widgets/attendance_history_filters.dart:42`,
`lib/features/attendance/presentation/history/widgets/attendance_history_filters.dart:46`).
The current query model is a date range, status facet, shift set, and text match
(`lib/features/attendance/domain/attendance_history_query.dart:37`).

This IA replaces that manager destination with a report hierarchy.

## 2. Module identity

### 2.1 Name and purpose

**Attendance & Reports** has two halves:

| Half | Purpose | Default question |
| --- | --- | --- |
| Attendance | Capture and correct the live attendance record. | Who is working, missing, or needs a decision now? |
| Reports | Close, explain, export, and restate closed attendance periods. | Can the business trust this period and hand it off? |

The halves are one module because the report denominator is the Schedule roster
and the numerator is attendance evidence. The live board can stay virtual; the
reporting ledger cannot.

### 2.2 Role labels

| Role | Label | Reason |
| --- | --- | --- |
| Admin | Attendance & Reports | Admin works across branches, close readiness, exports, and restatements. |
| Manager | Attendance & Reports | Manager clears exceptions, closes branch days, and reads branch reports. |
| Employee | Attendance | Employee must not be made to think they own reports or payroll export. |

The module title inside manager/admin report screens is always
**Attendance & Reports**. The employee clock title stays **Attendance** because
the current employee screen is a clock-in/out surface (`lib/features/attendance/presentation/pages/attendance_screen.dart:25`,
`lib/features/attendance/presentation/pages/attendance_screen.dart:57`).

### 2.3 Desktop navigation

Desktop uses the persistent sidebar and command palette. The sidebar list is the
source for command-palette destinations (`lib/core/widgets/app_shell.dart:53`,
`lib/core/widgets/command_palette.dart:14`).

| Role | Existing slot | Decision |
| --- | --- | --- |
| Admin | Existing Attendance item currently points to `RouteNames.adminAttendance` (`lib/core/widgets/app_shell.dart:117`) | Rename label to Attendance & Reports and point to NEW `RouteNames.attendanceReports`. |
| Manager | Existing Attendance item currently points to `RouteNames.attendanceReview` (`lib/core/widgets/app_shell.dart:182`) | Rename label to Attendance & Reports and point to NEW branch workspace route. |
| Employee | Existing Attendance item points to `RouteNames.attendance` (`lib/core/widgets/app_shell.dart:87`) | Keep label Attendance and route. |

No new sidebar item is added. The module uses the existing Attendance slot.

### 2.4 Mobile navigation

Mobile bottom nav stays Home, Tasks, Schedule, Chat (`lib/core/widgets/role_scaffold.dart:33`).
That bar has four equal destinations (`lib/core/widgets/app_bottom_nav.dart:31`).
Attendance & Reports does not become a fifth bottom item.

| Role | Mobile entry | What gets demoted |
| --- | --- | --- |
| Admin | Admin Dashboard attention card: "Attendance periods blocked" -> Reports hub. | Nothing in bottom nav. Admin Analytics stays in desktop admin section only; reports do not move there. |
| Manager | Manager Home card: "Close attendance" -> Branch workspace. | The old "review history" meaning of Attendance is demoted to evidence. |
| Employee | Existing fingerprint app-bar action -> Attendance (`lib/core/widgets/role_scaffold.dart:118`) | Nothing. Clocking remains a direct action. |

Considered and rejected: replacing Chat in the mobile bottom nav. Chat is a
daily communication destination for every role; Attendance & Reports is reached
from role-home attention when action is needed.

## 3. The report hierarchy

### 3.1 Placement rule

A surface is a **destination** when it answers a role's top-level question and is
reachable from role navigation.

A surface is a **report** when it has a named period, a denominator, a close
state, and metrics that meet ADR-017's metric bar.

A surface is a **drill-down** when it explains one row, employee, branch, or
exception selected from a report.

A surface is a **panel** when it belongs inside another feature and does not own
the attendance workflow.

### 3.2 Tree with classifications

```text
Attendance & Reports                                  destination
|-- Reports hub                                       destination
|   |-- Branch comparison                             report
|   |-- Export ledger                                 report-adjacent destination
|   `-- Branch workspace                              destination
|       |-- Daily close                               report + workflow
|       |-- Exception queue                           workflow destination
|       |-- Weekly report                             report
|       |   |-- Employee row                          drill-down
|       |   |-- Shift row table                       drill-down/evidence
|       |   `-- Attendance record detail              drill-down
|       |-- Monthly report                            report
|       |   |-- Employee row                          drill-down
|       |   |-- Shift row table                       drill-down/evidence
|       |   `-- Attendance record detail              drill-down
|       |-- Pay-period report                         report
|       `-- Branch ledger evidence                    drill-down
|
|-- Live board                                        destination inside workspace
|   |-- Needs review                                  section
|   |-- Absent / Overdue                              section
|   |-- Working now                                   section
|   `-- Completed today                               section
|
`-- My attendance                                     employee destination
    |-- Clock                                         workflow
    |-- My period record                              report-lite
    |-- My ledger                                     evidence drill-down
    `-- Record detail                                 drill-down
```

### 3.3 Parent/child rationale

Weekly, Monthly, Pay-period, and Daily Close sit under Branch Workspace because a
manager owns a branch and admins inspect branches explicitly. Admin branchless
global scope is handled by the Reports Hub; branch-scoped work never infers an
admin's branch from the profile.

Exception Queue sits beside Daily Close, not inside history, because exceptions
are the daily workflow. The manager decides, resolves, or confirms exceptions;
filtering a ledger is not the workflow.

Per-Employee Report is a child of Weekly, Monthly, Pay-period, and My Attendance.
It is not a global ranking screen. ADR-017 refuses composite employee scores and
leaderboards (`docs/decisions/ADR-017-attendance-reporting-ledger.md:77`).

Branch Comparison is admin-only because manager scope is own branch; admin is
global and branchless, so cross-branch scope must be explicit
(`docs/design/DATA_MODEL.md:96`).

### 3.4 What improves on the audit

The audit proposed a catalogue and route concepts. This IA decides the route
ownership: admin uses a Reports Hub; manager uses a Branch Workspace; Weekly and
Monthly are separate report destinations; history dies as a primary destination.

## 4. Route map

### 4.1 Current route facts

Current attendance constants are in `RouteNames`
(`lib/core/routes/route_names.dart:73`, `lib/core/routes/route_names.dart:76`,
`lib/core/routes/route_names.dart:80`, `lib/core/routes/route_names.dart:84`,
`lib/core/routes/route_names.dart:88`).

The router registers the five attendance routes together
(`lib/core/routes/app_router.dart:337`, `lib/core/routes/app_router.dart:343`,
`lib/core/routes/app_router.dart:349`, `lib/core/routes/app_router.dart:356`,
`lib/core/routes/app_router.dart:367`).

Employees are blocked only from the branch review area
(`lib/core/routes/app_router.dart:441`, `lib/core/routes/app_router.dart:570`).

### 4.2 Current route disposition

| Existing constant | Existing path | Disposition | Migration note |
| --- | --- | --- | --- |
| `RouteNames.attendance` | `/attendance` | **Stays** | Employee clock plus My Attendance period record. Managers who personally clock can still use it from the mobile app-bar action. |
| `RouteNames.adminAttendance` | `/admin/attendance` | **Dies as canonical route** | Redirect to NEW `RouteNames.attendanceReports`. Existing admin sidebar changes away from it. |
| `RouteNames.attendanceHistory` | `/attendance/history` | **Dies as destination** | Redirect to NEW `RouteNames.attendanceEmployee(currentUid)` with the ledger tab open. |
| `RouteNames.attendanceReview` | `/attendance/review` | **Dies as destination** | Redirect managers to their branch workspace and admins to reports hub. No notification deep link currently targets an attendance route, so retiring this breaks no existing push target. New report notifications must be added to `lib/features/notifications/domain/notification_deep_link.dart`. |
| `RouteNames.attendanceRecordPattern` | `/attendance/record/:id` | **Stays** | Canonical evidence detail. Add report-period/export/restatement context, but keep route and helper. |

Considered and rejected: keeping `/attendance/review` as the manager workspace
path. The word "review" preserves the old history-list mental model and hides
daily close/reporting.

### 4.3 New route constants

All names follow the existing convention: static string constants for concrete
paths, `Pattern` suffix for parameterized paths, and helper methods for concrete
parameterized paths.

| Constant | Path | Role guard | Parent | Answers |
| --- | --- | --- | --- | --- |
| NEW `RouteNames.attendanceReports` | `/attendance/reports` | admin or manager | Attendance & Reports | Which branches/periods need close, restatement, or export? |
| NEW `RouteNames.attendanceBranchPattern` | `/attendance/branch/:branchId` | admin or manager with scope | Reports hub | What is happening in this branch, and what blocks close? |
| NEW `RouteNames.attendanceDailyClosePattern` | `/attendance/close/:branchId/:date` | admin or manager with scope | Branch workspace | Can this business day close? |
| NEW `RouteNames.attendanceExceptions` | `/attendance/exceptions` | admin or manager | Branch workspace / hub | Which attendance facts need a decision? |
| NEW `RouteNames.attendanceWeeklyPattern` | `/attendance/reports/weekly/:periodId` | admin or manager with scope | Branch workspace | What happened this Schedule week? |
| NEW `RouteNames.attendanceMonthlyPattern` | `/attendance/reports/monthly/:periodId` | admin or manager with scope | Branch workspace | Is the month reconciled for operations/payroll handoff? |
| NEW `RouteNames.attendancePayPeriodPattern` | `/attendance/reports/pay-period/:periodId` | admin, manager scoped if allowed | Branch workspace | What rows should payroll receive? |
| NEW `RouteNames.attendanceEmployeePattern` | `/attendance/employee/:uid` | self, own-branch manager, admin | Reports and My Attendance | Is this person's record correct and fair? |
| NEW `RouteNames.attendanceBranchComparisonPattern` | `/attendance/reports/branches/:periodId` | admin only | Reports hub | Which branch needs operational help before cutoff? |
| NEW `RouteNames.attendanceExports` | `/attendance/exports` | admin or manager scoped | Reports hub | Which files were generated, by whom, and from what version? |

Expected helper methods:

```dart
static String attendanceBranch(String branchId) => '/attendance/branch/$branchId';
static String attendanceDailyClose(String branchId, String date) =>
    '/attendance/close/$branchId/$date';
static String attendanceWeekly(String periodId) =>
    '/attendance/reports/weekly/$periodId';
static String attendanceMonthly(String periodId) =>
    '/attendance/reports/monthly/$periodId';
static String attendancePayPeriod(String periodId) =>
    '/attendance/reports/pay-period/$periodId';
static String attendanceEmployee(String uid) => '/attendance/employee/$uid';
static String attendanceBranchComparison(String periodId) =>
    '/attendance/reports/branches/$periodId';
```

### 4.4 Guard model

| Route family | Guard |
| --- | --- |
| `/attendance` | Any authenticated role, because managers may also clock. |
| `/attendance/employee/:uid` | Self, own-branch manager, or admin. Rules still enforce data access. |
| `/attendance/reports...` | Admin or manager. Employee is redirected home. |
| `/attendance/branch/:branchId` | Admin any branch; manager only own branch. |
| `/attendance/exports` | Admin any export; manager only branch-scoped exports. |
| `/attendance/record/:id` | Route shared; Firestore read scope gates record access, as today (`lib/features/attendance/presentation/details/attendance_details_screen.dart:21`). |

## 5. Navigation

### 5.1 Desktop sidebar

| Role | Sidebar item | Route | Notes |
| --- | --- | --- | --- |
| Admin | Attendance & Reports | NEW `RouteNames.attendanceReports` | Replaces the existing Attendance destination that points to `/admin/attendance`. |
| Manager | Attendance & Reports | NEW `RouteNames.attendanceBranch(manager.branchId)` | Manager does not choose scope by default. |
| Employee | Attendance | EXISTING `RouteNames.attendance` | No report wording. |

Command palette entries mirror the sidebar because it uses the same section list
(`lib/core/widgets/command_palette.dart:86`).

### 5.2 Mobile

| Role | Entry point | First screen |
| --- | --- | --- |
| Admin | Dashboard attention card or notification | Reports hub |
| Manager | Manager Home attention card or notification | Branch workspace, exception tab selected if needed |
| Employee | Fingerprint app-bar action | Attendance clock |

Mobile bottom nav stays unchanged. The role scaffold already explains that the
mobile bar is Home, Tasks, Schedule, Chat (`lib/core/widgets/role_scaffold.dart:24`).

### 5.3 Branch Operations integration

Branch Operations remains the manager's task/operations cockpit. It already uses
a branch-scoped cockpit layout, summary header, shift lens, and employee cards
(`lib/features/operations/presentation/pages/branch_operations_screen.dart:35`,
`lib/features/operations/presentation/pages/branch_operations_screen.dart:206`).

Add a panel, not a new ownership boundary:

| Panel | Where | Opens |
| --- | --- | --- |
| Attendance close status | Branch Operations, below operations summary | Branch workspace |
| Open attendance exceptions | Branch Operations attention group | Exception queue filtered to branch |
| Weekly attendance trend | Branch Operations supporting metrics | Weekly report |

This is additive. It does not replace Branch Operations or Admin Dashboard V2.

### 5.4 Dashboard entry points

| Dashboard | Additive entry |
| --- | --- |
| Admin Dashboard V2 | "Attendance periods" attention row: Ready, Blocked, Restatement required. |
| Manager Home | "Close attendance" card: today's blockers and next cutoff. |
| Employee Home | No new report card; Attendance remains an action. My period status can appear inside the Attendance screen. |

### 5.5 Notification routing

Manager gets from notification to decision in the fewest steps:

```text
Tap notification -> Exception Queue with exception selected -> decision sheet
```

New notification types:

| Notification | Route |
| --- | --- |
| Period ready to close | `attendanceDailyClose(branchId, date)` |
| Exceptions unresolved | `attendanceExceptions` with scope/facet query |
| Export ready/failed | `attendanceExports` with export selected |
| Restatement required | Relevant report route with restatement panel open |

Existing notification deep links contain zero attendance route targets per the
brief. Therefore retiring `/attendance/review` and `/attendance/history` breaks
no current push target. New report notifications must be added to
`lib/features/notifications/domain/notification_deep_link.dart`.

## 6. Weekly Report

### 6.1 Decision

Weekly Report is a first-class report destination, not a date-range preset on a
history list.

The week is **Sunday 00:00 through Saturday 23:59:59.999 in `Africa/Cairo`**.
This matches Schedule's week because the roster is the denominator. Schedule
week math starts on Sunday and weekly schedule docs are keyed by the Sunday date
(`lib/features/schedule/domain/schedule_week.dart:3`,
`lib/features/schedule/domain/schedule_week.dart:21`).

Considered and rejected: Monday-start weekly attendance reports, because today's
history preset starts Monday (`lib/features/attendance/domain/attendance_history_query.dart:86`)
but a Weekly Report that disagrees with roster week cannot reconcile to the
denominator.

### 6.2 Audience and decision

| Audience | Decision |
| --- | --- |
| Manager | Did this roster week close cleanly, and what must be corrected before the next schedule cycle? |
| Admin | Which branch-week needs help before payroll/export? |

### 6.3 Required close inputs

Weekly Report requires:

| Input | Owner | Blocks report? |
| --- | --- | --- |
| Daily expected-shift rows for all seven business dates | Close Function | Yes |
| Durable no-show rows or reporting rows | Close Function | Yes |
| Daily rollups | Rollup Function | Yes |
| Source schedule ids and roster snapshot metadata | Close Function | Yes |
| Open correction count | Function/query | Yes for locked/exportable; shown for partial |
| Calculator version | Function | Yes |
| Timezone `Africa/Cairo` | Function metadata | Yes |

No Weekly Report surface ships before durable absences exist. ADR-017 makes this
a prerequisite (`docs/decisions/ADR-017-attendance-reporting-ledger.md:101`).

### 6.4 Structure

| Section | Content | Decision it drives |
| --- | --- | --- |
| Header | Branch, week label, Sunday-Saturday dates, status, version, timezone | Confirms scope and report trust. |
| Close readiness | Open blockers by type, last close run, CTA to Exception Queue | Decide whether to close/lock. |
| Metric strip | Show-up rate, punctual arrivals, absence count, worked minutes, overtime minutes, exception count | Understand operational reliability. |
| Daily rhythm | Seven-day table: expected, present, absent, late minutes, exceptions | Spot day-specific staffing failures. |
| Exception summary | Grouped blockers and resolved exceptions | Clear remaining work. |
| Employee rows | Employee-level facts, no rank numbers | Coach or verify individuals. |
| Evidence table | Shift rows paginated, link to record details | Audit and resolve disputes. |
| Export/restatement panel | Files, version, generated by/at, restatement status | File handoff and audit. |

### 6.5 Metrics

| Metric | Formula | Denominator | Owner | Decision |
| --- | --- | --- | --- | --- |
| Expected work shifts | Rostered shifts minus leave/excused exclusions | Schedule roster slots | Close Function | Defines rate denominators. |
| Show-up rate | present shifts / expected work shifts | Expected work shifts | Rollup Function | Staffing reliability for the week. |
| Unexcused absences | count unexcused no-show rows | Expected work shifts | Rollup Function | Coverage intervention. |
| Punctual arrival rate | on-time arrivals / present scheduled arrivals | Present scheduled arrivals | Rollup Function using calculator outputs | Coaching and handoff reliability. |
| Late minutes | sum `lateMinutes` | Present scheduled arrivals | AttendanceCalculator then rollup | Lateness severity. |
| Early-leave minutes | sum `earlyLeaveMinutes` | Scheduled records with end time | AttendanceCalculator then rollup | End-of-shift coverage gaps. |
| Overtime minutes | sum `overtimeMinutes` | Completed records with scheduled end | AttendanceCalculator then rollup | Payroll/staffing exposure. |
| Worked minutes | sum `workedMinutes` | Present records | AttendanceCalculator then rollup | Payroll candidate input. |
| Exception count | count actionable exception rows | Expected rows plus unscheduled work rows | Close Function | Triage workload. |

Late, early-leave, and overtime are derived facts, not persisted statuses
(`docs/design/ATTENDANCE_SPEC.md:371`, `lib/core/enums/attendance_status_filter.dart:3`).

### 6.6 Desktop layout

```text
Attendance & Reports / Weekly
Branch: Cairo A      Week: Sun 26 Jul - Sat 1 Aug      Status: Ready
[Close week] [Export] [More]

+--------------------------------------------------------------------------+
| Close readiness                                                          |
| 0 blockers ready to lock     last close run 18:04 Cairo     v1           |
+----------------+----------------+----------------+----------------------+
| Show-up rate   | Punctual       | Absences       | Overtime             |
| 94% 47/50      | 82% 38/46      | 3 unexcused    | 11h 20m              |
+----------------+----------------+----------------+----------------------+

+-----------------------------------------+--------------------------------+
| Daily rhythm                            | Exception summary              |
| Sun  8/8 present  0 absent  1 late      | Pending corrections      0      |
| Mon  7/8 present  1 absent  3 late      | Missing punches          0      |
| Tue  8/8 present  0 absent  0 late      | Implausible records      0      |
| Wed  6/8 present  2 absent  4 late      | Overtime review          2      |
| Thu  8/8 present  0 absent  1 late      |                                |
+-----------------------------------------+--------------------------------+

+--------------------------------------------------------------------------+
| Employee rows                                                             |
| Employee        Expected Present Absent Late min Worked OT  Exceptions    |
| Dina            5        5       0      12       2380   0   -             |
| Omar            5        4       1      50       1900   0   No-show       |
+--------------------------------------------------------------------------+

+--------------------------------------------------------------------------+
| Shift evidence table: Date Employee Shift Scheduled Actual Worked Flags   |
+--------------------------------------------------------------------------+
```

### 6.7 Mobile layout

```text
Weekly report
Cairo A
Sun 26 Jul - Sat 1 Aug
[Status pill] [Export icon]

Close readiness
0 blockers

Metrics carousel
Show-up 94% / Punctual 82% / Overtime 11h

Saved view segmented
Summary | Exceptions | Employees | Rows

Daily cards
Sun ... Sat

Employee row cards
tap -> employee report
```

### 6.8 Drill-downs

| Drill-down | Opens | Reason |
| --- | --- | --- |
| Day row | Daily Close for that date | Resolve day blockers. |
| Exception count | Exception Queue filtered to week/branch/type | Work the decision. |
| Employee row | Per-Employee Report scoped to week | Explain person's record. |
| Shift row | Attendance record detail or reporting row detail | Audit evidence. |
| Export version | Export Ledger selected export | File audit. |

### 6.9 States

| State | UI |
| --- | --- |
| No ledger data | "No ledger data"; no rates, no export. |
| Awaiting close | Period-level empty-ledger state only; explain that rows have not materialized yet. |
| Fully closed | Ledger rows exist and no blocking exception rows remain; row-backed no-shows render `0%`. |
| Partially closed | Ledger rows exist, but blocking exceptions remain; export disabled. |
| Ready | Close CTA enabled for manager/admin. |
| Locked | Export enabled; report version immutable. |
| Exported | File chips and export ledger link visible. |
| Restated | Banner names superseded version and changed facts. |

### 6.10 Exports

Weekly Report offers PDF and CSV only when locked.

PDF is for owner/manager reading: summary, daily rhythm, employee rows,
exceptions, version, and footer.

CSV is for data handoff and audit: one row per shift/report row, using the schema
in section 12.

## 7. Monthly Report

### 7.1 Decision

Monthly Report is a first-class report destination. It is not "Weekly Report with
more days."

The month is the calendar month in `Africa/Cairo`: first business date through
last business date, with overnight shifts assigned to the scheduled-start
business date.

### 7.2 How Monthly differs from Weekly

| Weekly | Monthly |
| --- | --- |
| Operational cadence: close the roster week and prepare the next one. | Accounting/payroll cadence: reconcile a full month. |
| Emphasizes seven daily rows and immediate exception cleanup. | Emphasizes branch totals, employee totals, restatements, and export readiness. |
| Uses Schedule week denominator. | Uses calendar-month denominator. |
| Trend compares to previous week. | Trend compares to previous month and the weekly buckets inside the month. |
| Manager-first. | Admin and payroll-handoff first, manager still scoped. |

Considered and rejected: making Monthly a date-range preset, because the owner
asked for first-class Weekly and Monthly reports and a month has a different
business decision.

### 7.3 Audience and decision

| Audience | Decision |
| --- | --- |
| Admin | Is the month ready for payroll/accounting handoff across branches? |
| Manager | Does my branch month reconcile, and which employees need correction before lock? |
| Owner/operator | What materially changed from last month? |

### 7.4 Required close inputs

Monthly Report requires:

| Input | Owner | Blocks report? |
| --- | --- | --- |
| All daily close rows in month | Daily close pipeline | Yes |
| Weekly rollups inside month | Rollup Function | No for summary; yes for weekly-bucket trend |
| Month period row and employee rows | Rollup Function | Yes |
| Durable no-shows | Close Function | Yes |
| Export/restatement metadata | Export Function | No for preview; yes for exported state |
| Break policy flag | Function metadata | Warning if missing |

### 7.5 Structure

| Section | Content | Decision it drives |
| --- | --- | --- |
| Header | Scope, month, status, version, timezone | Confirm report trust. |
| Payroll readiness | Lock state, blockers, export availability, break-policy warning | Decide if handoff can happen. |
| Metric strip | Show-up, absence, punctual arrival, worked, overtime, exceptions | Month-level operational health. |
| Month-over-month comparison | Prior month deltas for allowed metrics | Spot material change. |
| Weekly buckets | Each Schedule week overlapping month, using scheduled-start date inclusion | Locate change inside month. |
| Branch/employee rows | Branch rows for admin; employee rows for branch scope | Identify where correction or support is needed. |
| Restatement log | Version history and changed totals | Trust exported artifacts. |
| Evidence table | Shift/report rows, paginated | Audit. |

### 7.6 Metrics

Monthly uses the same metric definitions as Weekly, plus:

| Metric | Formula | Denominator | Owner | Decision |
| --- | --- | --- | --- | --- |
| Month close blockers | unresolved blocking exceptions in month | Expected rows plus unscheduled work rows | Close Function | Whether month can lock. |
| Restatement count | count versions after v1 | Locked/exported period | Function | Whether exported files need replacement. |
| Prior-month delta | current metric minus previous locked month metric | Same metric denominator per month | Rollup Function | Whether a change is material enough to inspect. |
| Payroll candidate minutes | worked minutes minus unpaid break policy if configured; else worked minutes with warning | Present records | Export Function | Payroll data handoff. |

Do not carry current `Avg arrival` into Monthly. It is a mean wall-clock time and
breaks across midnight (`lib/features/attendance/domain/attendance_analytics.dart:30`,
`lib/features/attendance/domain/attendance_analytics.dart:103`).

### 7.7 Desktop layout

```text
Attendance & Reports / Monthly
All branches or Cairo A       Month: July 2026      Status: Locked v1
[Export PDF] [Export CSV] [Restatement history]

+--------------------------------------------------------------------------+
| Payroll readiness                                                        |
| Ready for export    0 blockers    break policy: not configured           |
+----------------+----------------+----------------+----------------------+
| Show-up rate   | Absence rate   | Worked minutes | Overtime exposure    |
| 93% 412/443    | 7% 31/443      | 184,320        | 92h 10m              |
+----------------+----------------+----------------+----------------------+

+----------------------------------------+---------------------------------+
| Month-over-month                       | Weekly buckets                  |
| Show-up -2 pts vs Jun                  | W1 95%  W2 91%  W3 94%  W4 92%  |
| Overtime +18h                          | blockers by week: 0 2 0 1       |
+----------------------------------------+---------------------------------+

+--------------------------------------------------------------------------+
| Branch / Employee rows                                                     |
| Name       Expected Present Absent Worked OT Exceptions Restated?          |
+--------------------------------------------------------------------------+

+--------------------------------------------------------------------------+
| Evidence rows and export/restatement log                                   |
+--------------------------------------------------------------------------+
```

### 7.8 Mobile layout

```text
Monthly report
July 2026
Scope selector
Readiness card
Metric strip

Tabs
Summary | Branches/Employees | Exceptions | Rows | Exports

Stacked weekly buckets
Employee/branch row cards
```

### 7.9 States

| State | UI |
| --- | --- |
| Month open | Provisional through last closed day; export disabled. |
| Partial daily close | Show missing close dates as blockers. |
| Ready | Lock CTA visible. |
| Locked | Exports enabled. |
| Exported | Export file list visible. |
| Restated | Banner and version selector. |

### 7.10 Exports

Monthly offers PDF and CSV when locked. CSV is appropriate because monthly is a
payroll/accounting handoff candidate. PDF is appropriate because the month is a
management artifact that may be filed or reviewed.

## 8. Other report surfaces

### 8.1 Daily Close

| Field | Decision |
| --- | --- |
| Audience | Manager, admin |
| Parent | Branch Workspace |
| Drives | Can this business day be closed? |
| Depth | Full workflow surface |

Structure:

| Section | Content |
| --- | --- |
| Header | Branch, business date, timezone, status, close run. |
| Close checklist | Expected rows, missing/no-show rows, pending corrections, auto-closed sessions, implausible records, overtime review. |
| Exception queue preview | Blocking exceptions first. |
| Live board handoff | Link back to today's live board if date is today. |
| Final totals | Expected, present, absent, leave, excused, worked/overtime minutes. |

Close requirements:

- Expected-shift rows for the business date.
- No-show materialization for ended shifts.
- Open sessions evaluated by auto-close.
- Pending corrections counted.
- Source schedule id and calculator version stored.

### 8.2 Exception Queue

| Field | Decision |
| --- | --- |
| Audience | Manager, admin |
| Parent | Branch Workspace and Reports Hub |
| Drives | Who needs a decision now? |
| Depth | Full workflow destination |

Groups:

| Group | Sort | Closes when |
| --- | --- | --- |
| Pending corrections | Payroll-impacting first, oldest first | Approved or rejected with note. |
| Missing/no record | Shift ended, no durable row | Mark absent, excuse, or create corrected record. |
| Auto-closed sessions | Oldest first | Resolve real clock-out or confirm pending review. |
| Implausible records | Highest severity first | Correct, confirm, or annotate. |
| Overtime review | Largest overtime first | Confirm/approve for export policy or flag. |
| Unscheduled work | Date/time | Attach to schedule, approve as exception, or exclude. |

### 8.3 Per-Employee Report

| Field | Decision |
| --- | --- |
| Audience | Employee self, manager own branch, admin |
| Parent | Weekly, Monthly, Pay-period, My Attendance |
| Drives | Is this person's record correct and fair? |
| Depth | Report drill-down |

Structure:

| Section | Content |
| --- | --- |
| Header | Employee, branch, role, period, status. |
| Attendance reliability | Expected, present, absent, leave, excused, show-up rate. |
| Time reliability | Punctual arrivals, late minutes, early-leave, overtime. |
| Exceptions | Missing punches, corrections, implausible records. |
| Payroll candidate | Worked minutes, overtime minutes, break warning. |
| Adjacent task lane | Approved/missed/cancelled/late task facts, no fused score. |
| Evidence | Shift rows and record links. |

Task adjacency follows the fair reporting standard: cancelled tasks are excluded
from the completion-rate denominator (`lib/features/task/domain/task_outcomes.dart:83`).

### 8.4 Per-Branch Comparison

| Field | Decision |
| --- | --- |
| Audience | Admin |
| Parent | Reports Hub |
| Drives | Which branch needs operational help before cutoff? |
| Depth | Summary report |

Structure:

- Scope selector: period type and period id.
- Branch table: readiness, blockers, expected shifts, show-up rate, absence rate,
  punctual arrival, worked minutes, overtime, restatement state.
- Small multiples, monochrome only.
- Drill to Branch Workspace.

No manager access. A manager cannot compare branches because manager scope is
own branch.

### 8.5 Pay-period Report

| Field | Decision |
| --- | --- |
| Audience | Admin, manager if scoped by policy |
| Parent | Branch Workspace and Reports Hub |
| Drives | What should payroll receive? |
| Depth | Full report/export surface |

Structure:

- Header: period boundary, scope, status, version, timezone.
- Payroll-readiness checklist.
- Employee payroll candidate rows.
- Shift row CSV preview.
- Exclusions: leave, excused, no-show, unscheduled, break policy.
- Export actions.

Open question: exact pay-period boundary. Recommendation is calendar month until
the owner provides payroll cutoffs.

### 8.6 Export Ledger

| Field | Decision |
| --- | --- |
| Audience | Admin, manager scoped |
| Parent | Reports Hub |
| Drives | Which files exist and are they still current? |
| Depth | Audit destination |

Structure:

- Export requests table: status, file type, scope, period, version, requester,
  requestedAt, completedAt, file hash, retention expiry.
- Failed export details and retry.
- Restatement links.
- Download links gated by role and scope.

### 8.7 Branch Ledger Evidence

The old branch review list becomes a drill-down table inside reports and the
workspace. It is not a route destination. It uses table columns on desktop and
cards on mobile.

## 9. The filtering model

### 9.1 Decision

Filtering stops being the primary interaction.

The model is:

```text
Scope -> Report -> Saved view -> Facets -> Search/sort
```

### 9.2 Scope

Scope defines what data is allowed to exist in the surface.

| Scope control | Who sees it | Persists? | Deep-linkable? |
| --- | --- | --- | --- |
| Branch | Admin chooses; manager fixed to own branch | Yes in route/query | Yes |
| Branch set | Admin only for comparison/monthly estate views | Yes in query | Yes |
| Period type | Admin/manager | Yes | Yes |
| Period id/date | Admin/manager/employee scoped | Yes in route | Yes |
| Person | Employee self or selected employee | Yes in route | Yes |

Scope is not an advanced filter. It appears in the page header.

### 9.3 Saved views

Saved views are named lenses that answer common questions.

| Saved view | Applies to | Includes |
| --- | --- | --- |
| Overview | Reports | All rows summarized. |
| Open exceptions | Exception queue/report rows | Pending corrections, no-shows, auto-close, implausible, unscheduled. |
| Payroll blockers | Close/pay-period/monthly | Anything preventing lock/export. |
| Overtime review | Reports and queue | Derived overtime flags. |
| Corrections | Queue/evidence | Correction lifecycle rows. |
| Exported rows | Locked/exported reports | Rows included in latest export. |

Saved views persist during navigation within Attendance & Reports. They are
URL/deep-linkable as query params because notifications need to open the exact
decision.

### 9.4 Facets

Facets narrow rows after scope and saved view.

| Facet | Type | Notes |
| --- | --- | --- |
| Lifecycle status | `completed`, `pendingReview`, `absent`, `onLeave`, `excused`, etc. | True persisted status values only. Label-only renames are allowed; wire values frozen. |
| Exception type | late, early_leave, overtime, missing_punch, implausible, unscheduled | Derived facts from close/report rows, never `AttendanceStatus`. |
| Shift | Morning, night, all configured shifts | Facet. |
| Source | clock, manual, correction, system | Facet. |
| Close state | open, ready, locked, exported, restated | Report/period facet. |

This explicitly resolves today's status-vs-derived-fact mixing. The old
`AttendanceStatusFilter` deliberately mixes true statuses and derived facts
(`lib/core/enums/attendance_status_filter.dart:3`), and the query predicate then
branches over entity-derived facts (`lib/features/attendance/domain/attendance_history_query.dart:149`).
The new UI separates lifecycle status from exception type.

### 9.5 Desktop controls

```text
Page hero:
  Branch/scope selector | Period selector | Status/version

Saved view segmented:
  Overview | Open exceptions | Payroll blockers | Overtime | Corrections

Toolbar:
  Search employee/row id | Filter drawer | Sort | Columns | Export

Filter drawer:
  Lifecycle status
  Exception type
  Shift
  Source
  Close/export state
  Date override only where report allows custom evidence search
```

### 9.6 Mobile controls

```text
Top:
  Scope summary
  Period picker

Segmented:
  Overview | Exceptions | Rows | Exports

Actions:
  Search icon -> full-screen search
  Filter icon -> bottom sheet
```

### 9.7 What replaces the 16-pill row

The stacked chip rows are retired. The replacement is:

- Header scope selectors for branch and period.
- Saved view segmented control for the manager's intent.
- Search.
- Table columns and sort.
- Advanced filter drawer.

This is easier to understand because a manager first chooses the business
question, then narrows evidence. The current screen asks the manager to build the
question out of chips before seeing the answer.

## 10. The exception queue as the daily workflow

### 10.1 Decision

The Exception Queue is the daily attendance workflow for managers.

It implements the locked spec principle that the manager acts only on
exceptions: during shift they act on late/absent rows; after shift they clear
Pending Review and corrections (`docs/design/ATTENDANCE_SPEC.md:166`).

### 10.2 Queue order

Default order:

1. Payroll blockers due soon.
2. Pending corrections.
3. No-show/missing row after shift end.
4. Auto-closed sessions.
5. Implausible records.
6. Overtime review.
7. Informational derived facts.

The live board itself preserves its decision-ranked order: Needs review,
Absent/Overdue, Working now, Completed today
(`docs/design/ATTENDANCE_SPEC.md:249`).

### 10.3 Row shape

| Column | Purpose |
| --- | --- |
| Type | What decision is needed. |
| Employee | Who/branch. |
| Business date | Cairo business day. |
| Shift | Roster slot. |
| Scheduled | Denominator evidence. |
| Actual | Current clock facts. |
| Payroll impact | Minutes or exclusion. |
| Action | Resolve, approve, reject, excuse, confirm, inspect. |

### 10.4 Bulk actions

| Bulk action | Decision |
| --- | --- |
| Mark selected no-shows absent | Allowed after confirmation and shared factual reason. |
| Excuse selected absences | Allowed with one mandatory reason. |
| Confirm selected informational late flags | Allowed if no payroll minutes change. |
| Approve selected corrections | Rejected by default; corrections may alter minutes differently. |
| Reject selected corrections | Rejected by default; each needs a reason. |
| Close day/period | Allowed only when blockers are resolved. |

### 10.5 Closure by exception type

| Exception | Closes when |
| --- | --- |
| Pending correction | Reviewer approves or rejects with note. |
| No-show | Manager marks absent, excuses, or creates corrected record. |
| Missing punch | Correction applied or direct manager resolve saved. |
| Auto-close | Clock-out resolved or pending state confirmed with reason. |
| Implausible record | Corrected, annotated as valid, or excluded by policy. |
| Overtime | Confirmed for export policy or corrected. |
| Unscheduled work | Attached, approved as exception, or excluded. |

## 11. Employee-side IA

### 11.1 Decision

Employee Attendance remains action-first, then record-correctness.

The employee screen currently owns the clock workflow in one adaptive surface
(`lib/features/attendance/presentation/pages/attendance_screen.dart:25`).
That remains the first layer.

### 11.2 Employee screen structure

```text
Attendance
|-- Today
|   |-- Current shift
|   |-- Clock action
|   |-- GPS state
|   `-- Correction/missed punch action when relevant
|
|-- My period record
|   |-- Current month/pay period summary
|   |-- Pending corrections
|   |-- Absences/excused/leave
|   |-- Worked/overtime minutes
|   `-- "Is something wrong?" action
|
`-- Evidence
    |-- My ledger rows
    `-- Record detail
```

### 11.3 Employee permissions

| Capability | Employee |
| --- | --- |
| See own clock state | Yes |
| See own period rows | Yes |
| See own corrections and decisions | Yes |
| Filter own evidence by period and exception | Yes, scoped to self |
| Export payroll CSV | No |
| Export manager PDF | No |
| Download own locked-period PDF | Not offered in v1; view in app instead |
| See branch comparison | No |
| See coworkers | No |

### 11.4 Employee filters

Employee filters are not report-building tools. They are:

- Period: current month/pay period, previous month, custom evidence search.
- Saved view: All rows, Needs correction, Absences, Overtime.
- Search is omitted unless the row list becomes long enough to justify it.

## 12. Export matrix

### 12.1 Matrix

| Surface | PDF | CSV |
| --- | --- | --- |
| Reports Hub | Not offered: it is navigation/status, not a closed artifact. | Not offered: no single row contract. |
| Daily Close | Offered after close: manager signoff summary. | Not offered: daily CSV encourages ad hoc payroll off partial periods. |
| Exception Queue | Not offered: queue is live workflow, a PDF would stale immediately. | Offered for audit snapshot when filtered to a closed/locked period. |
| Weekly Report | Offered when locked: readable management report. | Offered when locked: shift-row data contract. |
| Monthly Report | Offered when locked: filing and review artifact. | Offered when locked: payroll/accounting handoff candidate. |
| Per-Employee Report | Offered for locked periods to manager/admin and self-view only if product later wants employee download. | Offered to manager/admin for scoped row audit; not employee self-export in v1. |
| Per-Branch Comparison | Offered for admin locked periods: executive summary. | Offered for admin locked periods: branch summary rows only. |
| Pay-period Report | Offered when locked/exported: signoff cover sheet. | Required when locked/exported: payroll ledger. |
| Export Ledger | Not offered: ledger is already the audit index. | Offered: export request inventory for admins/managers scoped. |
| Record detail | Not offered in v1: details are in-app evidence. | Not offered: single-row export belongs to report CSV. |

### 12.2 Who may request

| Actor | Export authority |
| --- | --- |
| Admin | Any branch, multi-branch, all branches. |
| Manager | Own branch only. |
| Employee | None in v1. Can view own locked facts in app. |

### 12.3 Generation and audit

CSV and payroll-relevant files are generated by a Cloud Function. ADR-005 makes
server-authoritative writes the boundary for anything a client must not forge,
and ADR-017 rejects client-authored payroll totals
(`docs/decisions/ADR-017-attendance-reporting-ledger.md:87`).

Export request document:

| Field | Type |
| --- | --- |
| `exportId` | string |
| `requestedBy` | uid |
| `requestedAt` | server timestamp |
| `scopeKind` | string |
| `branchIds` | array<string> |
| `periodId` | string |
| `periodVersion` | int |
| `format` | `pdf` or `csv` |
| `status` | pending, running, complete, failed |
| `storagePath` | string? |
| `fileHash` | string? |
| `completedAt` | timestamp? |
| `failure` | string? |

Files live in Firebase Storage. Storage already exists as the artifact store for
app files (`docs/design/DATA_MODEL.md:179`).

### 12.4 Retention and naming

Recommendation:

- Retain export request docs indefinitely unless owner later defines retention.
- Retain files for 24 months by default.
- Never mutate a file in place. Restatement creates a new file.

Naming convention:

```text
attendance_{scope}_{periodType}_{startDate}_{endDate}_v{version}_{format}_{exportId}.{ext}
```

Example:

```text
attendance_cairo-a_monthly_2026-07-01_2026-07-31_v1_csv_exp_8h2k.csv
```

### 12.5 UI affordance

Reuse the Schedule Final View export pattern: a full-screen preview/toolbar
surface, isolated export content, and a clear save/download action. Schedule
uses a `RepaintBoundary` export surface with toolbar chrome excluded from the
PNG (`lib/features/schedule/presentation/pages/schedule_final_view.dart:53`,
`lib/features/schedule/presentation/pages/schedule_final_view.dart:103`).

For Attendance:

- PDF preview opens in a report export preview route/sheet.
- CSV export opens an export request status drawer, then download chip.
- Export buttons are disabled until locked.
- Export status appears in the Export Ledger.

### 12.6 Payroll CSV schema

| Column | Type | Rule |
| --- | --- | --- |
| `period_id` | string | Period id. |
| `period_version` | int | Exported version. |
| `export_id` | string | Export request id. |
| `scope_kind` | string | `branch` or `multiBranch`. |
| `branch_id` | string | Row branch id. |
| `branch_name` | string | Snapshot. |
| `employee_uid` | string | UID. |
| `employee_name` | string | Snapshot. |
| `business_date` | date string | `yyyy-MM-dd` in `Africa/Cairo`. |
| `shift` | string | Shift id/name. |
| `overnight` | bool | True when scheduled end crosses midnight. |
| `scheduled_start_at` | ISO timestamp | UTC instant. |
| `scheduled_end_at` | ISO timestamp | UTC instant. |
| `clock_in_at` | ISO timestamp? | Null for no-show/leave. |
| `clock_out_at` | ISO timestamp? | Null when missing/pending. |
| `timezone` | string | Always `Africa/Cairo` in v1. |
| `status` | string | Existing attendance status value where applicable. |
| `expected_shift` | bool | Counts in expected denominator. |
| `excluded_from_show_up_rate` | bool | Leave/excused true. |
| `excluded_reason` | string? | Leave type or excused category. |
| `source` | string | Existing attendance source. |
| `worked_minutes` | int | Calculator output. |
| `break_minutes` | int | Zero unless breaks return. |
| `paid_candidate_minutes` | int | Worked minus unpaid break policy if configured; otherwise worked with warning. |
| `late_minutes` | int | Calculator output. |
| `early_leave_minutes` | int | Calculator output. |
| `overtime_minutes` | int | Calculator output. |
| `exception_codes` | string | Pipe-delimited stable labels. |
| `pending_review` | bool | Blocks payroll finality. |
| `correction_ids` | string | Pipe-delimited. |
| `gps_in_verified` | bool? | From verification snapshot. |
| `gps_in_distance_m` | int? | Rounded meters. |
| `gps_out_verified` | bool? | From verification snapshot. |
| `gps_out_distance_m` | int? | Rounded meters. |
| `attendance_record_id` | string? | Raw record id. |
| `report_row_id` | string | Durable report row id. |
| `restatement_of` | string? | Prior period/export id if applicable. |

Rounding:

- Export whole minutes.
- Do not round to payroll increments.
- Payroll system owns 5/10/15 minute rounding.
- GPS distances are rounded to whole meters.

Break policy:

- Break support is dormant (`docs/design/ATTENDANCE_AUDIT_2026-07-30.md:1192`).
- CSV always includes `break_minutes`.
- If no break policy exists, export marks paid candidate minutes as raw worked
  minutes with warning metadata.

## 13. Premium UI direction

### 13.1 Principles

Reports are desktop-first and mobile-friendly. They are dense, scannable, and
hierarchical. They are not sparse dashboards.

Use monochrome hierarchy. ADR-004 permits white/grey as the dominant palette and
semantic color only for state (`docs/decisions/ADR-004-monochrome-design.md:17`).

### 13.2 Reuse primitives

Real primitives verified in `lib/core/widgets/`:

| Primitive | Use |
| --- | --- |
| `PageHero` | Report headers and primary action. |
| `AttentionTile` | Urgent counts and blockers. |
| `StatStrip` | Compact metric rows. |
| `ActivityCard` | Export/restatement events. |
| `GlassContainer` | Premium surface wrapper. |

The design system defines these primitives and their roles
(`docs/design/DESIGN_SYSTEM.md:83`).

### 13.3 New primitive justified

Add one new primitive when implemented:

| Primitive | Purpose | Why existing primitives are not enough |
| --- | --- | --- |
| `ReportDataTable` | Dense desktop table with sticky header, saved-view integration, selected-row side panel, and responsive card fallback. | Attendance reports need tables as primary evidence; `ActivityCard` is a feed row, not a report table. |

### 13.4 Grid and density rules

- Desktop max content width: use the app's existing desktop shell, not a narrow
  mobile column.
- Header at top, then readiness/metrics, then two-column content, then table.
- Cards are individual repeated items only. Do not place UI cards inside cards.
- One primary CTA per screen: Close, Lock, or Export depending on state.
- Tables use stable column widths and no viewport-scaled font sizes.
- Trend visuals use line weight, dashes, baselines, direct labels, and small
  multiples.
- No purple, indigo, decorative heatmaps, or multi-color chart palette.

### 13.5 Reports hub wireframe

```text
Attendance & Reports
All branches        Period: July 2026        [Run close] [Exports]

+--------------------------------------------------------------------------+
| Needs attention                                                           |
| 3 branches blocked     14 open exceptions     1 restatement required      |
+----------------------+----------------------+----------------------------+
| Ready to export       | Show-up rate         | Overtime exposure          |
| 2 branches            | 93% 412/443          | 92h 10m                    |
+----------------------+----------------------+----------------------------+

+---------------------------------------------+----------------------------+
| Branch periods                              | Close checklist             |
| Branch     Status    Blockers   Show-up     | Pending corrections 5       |
| Cairo A    Blocked   7          91%         | Missing punches 2           |
| Cairo B    Ready     0          96%         | Implausible records 1       |
| Giza       Restate   1          94%         | Overtime review 4           |
+---------------------------------------------+----------------------------+

+--------------------------------------------------------------------------+
| Closed-period trend small multiples                                      |
+--------------------------------------------------------------------------+
```

Mobile:

```text
Attendance & Reports
All branches
[Period selector]
Needs attention card
Metrics carousel
Branch period cards
Exports link
```

### 13.6 Weekly Report wireframe

See section 6.6 and 6.7.

### 13.7 Monthly Report wireframe

See section 7.7 and 7.8.

### 13.8 Exception Queue wireframe

```text
Exception Queue
Cairo A       This week       Saved view: Payroll blockers
[Bulk action] [Filter]

+--------------------------------------------------------------------------+
| Type        Employee  Date       Shift   Impact        Action             |
| Correction  Dina      Jul 28     Morning +42 min       Review             |
| No-show     Omar      Jul 29     Night   absent row    Resolve            |
| Auto-close  Ali       Jul 30     Morning missing out   Set clock-out      |
+--------------------------------------------------------------------------+

Selected row side panel:
  evidence, proposed change, audit, decision form
```

Mobile:

```text
Exception Queue
Cairo A / Payroll blockers
Segmented type group
Exception cards
tap card -> decision screen/sheet
```

### 13.9 Per-Employee Report wireframe

```text
Employee Attendance
Dina Mostafa       Cairo A       July 2026       Locked v1

+--------------------------------------------------------------------------+
| Record correctness                                                        |
| No open corrections     5 expected     5 present     0 absent             |
+----------------------+----------------------+----------------------------+
| Show-up              | Punctual             | Worked                     |
| 100% 5/5             | 80% 4/5              | 39h 40m                    |
+----------------------+----------------------+----------------------------+

+-----------------------------------------+--------------------------------+
| Attendance reliability                  | Adjacent task lane             |
| leave/excused/exceptions                | approved/missed/cancelled      |
+-----------------------------------------+--------------------------------+

+--------------------------------------------------------------------------+
| Shift rows                                                                |
+--------------------------------------------------------------------------+
```

Mobile:

```text
Employee Attendance
Dina / July 2026
Correctness card
Metric cards
Exceptions
Shift rows
```

## 14. What this retires

| Current thing | Retired? | Cost |
| --- | --- | --- |
| Branch review as manager destination | Yes | Existing `/attendance/review` links need redirects and nav updates. |
| "Attendance history" title for manager review | Yes | Users learn "Branch Workspace" instead. |
| Three stacked chip rows | Yes | Need new filter drawer/saved views and table controls. |
| Status chip that mixes statuses and derived facts | Yes | Need report-row exception flags and clearer UI copy. |
| Admin one-branch live board as Attendance root | Yes | Admins need a branch drill to reach the live board. |
| Corrections tab as separate mental model | Yes | Corrections become one Exception Queue group. |
| Summary label "Rate" | Yes | Replace with Show-up rate and denominator disclosure. |
| Avg arrival in reports | Yes | Replace with punctual arrival rate and late minutes. |
| Record-card-only desktop evidence | Yes | Desktop uses table plus side panel. |

The live board is not retired. Its order stays Needs review -> Absent/Overdue
-> Working now -> Completed today per spec (`docs/design/ATTENDANCE_SPEC.md:251`).

## 15. Dependencies and sequencing

### 15.1 Surface dependency matrix

| Surface | Needs close pipeline | Needs export Function | Risk | Type |
| --- | --- | --- | --- | --- |
| Employee clock | No new dependency | No | LOW | Presentation additive |
| My period preview | Yes for durable absences | No | MED | Engine-touching read model |
| Branch workspace shell | Partial | No | MED | Presentation + routing |
| Exception queue | Yes for durable no-shows/report flags | No | HIGH | Engine-touching workflow |
| Daily close | Yes | No | HIGH | Engine-touching |
| Weekly report | Yes | For export | HIGH | Engine-touching |
| Monthly report | Yes | For export | HIGH | Engine-touching |
| Per-employee report | Yes | Optional | MED | Engine-touching |
| Branch comparison | Yes | Optional | MED | Engine-touching |
| Pay-period report | Yes | Yes | HIGH | Engine-touching |
| Export ledger | Yes | Yes | HIGH | Backend/storage/rules |

### 15.2 Build order

1. P0 close prerequisite: materialize expected-shift and no-show facts at daily
   close; store source schedule ids, timezone, calculator version, and durable
   denominators.
2. Add period rows and employee/shift report rows for Daily and Weekly only.
3. Build Branch Workspace shell with live board preserved and Daily Close link.
4. Build Exception Queue for daily blockers.
5. Build Weekly Report without export.
6. Build Monthly Report from daily/weekly rollups.
7. Add server CSV export for locked weekly/monthly/pay-period reports.
8. Add Export Ledger and restatement version visibility.
9. Add PDF summaries.
10. Add Branch Comparison and dashboard/Branch Operations panels.

Each step is independently shippable after P0 because each answers a complete
workflow question without pretending the rest exists.

### 15.3 P0 blocker restated

Current branch range reads attendance documents by branch and day key
(`lib/features/attendance/data/datasources/attendance_remote_datasource.dart:207`).
History summaries count only materialized attendance records
(`lib/features/attendance/domain/attendance_analytics.dart:72`).
Therefore a lazy no-show can be visible on the live board but missing from
history/report denominator. No report surface ships before this is fixed.

## 16. Open questions

### 16.1 Pay-period boundary

Recommendation: use calendar month in `Africa/Cairo` for v1.

Owner decision needed only if payroll uses a non-calendar cutoff, such as
26th-25th or biweekly periods. This changes route ids, close schedule, export
naming, and employee period previews.

### 16.2 Export retention policy

Recommendation: retain export docs indefinitely and files for 24 months.

Owner decision needed for legal/accounting retention. This changes Storage
lifecycle rules and Export Ledger copy.

### 16.3 Break policy

Recommendation: keep `break_minutes = 0` and mark paid candidate minutes as raw
worked minutes until break UX/policy returns.

Owner decision needed before representing paid minutes as payroll-ready if
unpaid breaks are required. Breaks are dormant today per the audit's export
notes (`docs/design/ATTENDANCE_AUDIT_2026-07-30.md:1192`).
