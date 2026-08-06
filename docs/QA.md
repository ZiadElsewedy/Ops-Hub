# QA — release verification

> Run on a **real device** against the live Firebase project. Not a simulator —
> attendance GPS and push cannot be validated on one.
>
> Replaces the three overlapping checklists (`QA_CHECKLIST` · `RELEASE_QA` ·
> `BETA_CHECKLIST`), which had drifted into testing flows that no longer exist
> (registration, email verification, pending-approval). **If a step here contradicts
> the app, the app is right — fix this file.**

## 0 · Preconditions — blocking

Most failures below are one of these, not a bug.

> Release gating (signing, store identity, backups, channel) lives in
> [RELEASE_V1.md](RELEASE_V1.md), not here. This file is the **device test
> script** only.

| # | Step | Without it |
| --- | --- | --- |
| P1 | **Deploy:** `firebase deploy --only functions,firestore:rules,firestore:indexes,storage` (Blaze). ✅ As of **2026-08-05 18:32–18:40 UTC** rules, all 24 functions, indexes and storage rules are **live and verified in sync** — re-run only after a server change | Attendance audit, corrections, cases, requests, automation, and **all push** are inert. Shift-task streams fail `failed-precondition` |
| P2 | **Enable Firebase Storage** in the console | Every media upload fails with "not authorized" — this is *not* a code bug |
| P3 | **Bootstrap the first admin** — set `role: admin`, `isActive: true` on one user doc | No one can provision accounts |
| P4 | **Auth providers:** Email/Password **only** | — |
| P5 | *(iOS push)* APNs key + Push/Background-Modes capability | **Currently unconfigured** — iOS push cannot be tested. Android only |

**Test accounts:** `admin@…` (bootstrapped) · `mgr@…` (promoted) · `emp1@…`,
`emp2@…` (same branch).

## 1 · Onboarding — per new user

There is **no registration**. An admin creates every account.

| # | Step | Expect |
| --- | --- | --- |
| N1 | Admin: Create Account (email, name, role, branch) | Account created; admin **stays signed in** (the callable runs Admin-SDK-side) |
| N2 | New user signs in with the issued temp password | → **Force Password Change**, cannot skip |
| N3 | Set a new password | → **Profile Completion** |
| N4 | Complete profile | Employees → the one-time **Welcome**; manager/admin → role home |
| N5 | Sign out, sign back in | Straight to role home. Welcome never shows again |
| N6 | Admin deactivates the account mid-session | User is signed out with "This account has been disabled" |

## 2 · Employee — daily workflow (phone)

| # | Step | Expect |
| --- | --- | --- |
| E1 | Open **My Week** | Today's shift / "Off today" + the week. Unpublished week → "No schedule published…" |
| E2 | Check a shift you're on | Coworkers + branch manager render by **name**, never a uid or "Unknown" |
| E3 | Manager assigns you a task elsewhere | Appears **automatically** — task lists are live streams. No pull-to-refresh |
| E4 | Open the task → **Start** | → In Progress |
| E5 | Tick the checklist | "Mark Complete" only activates when every **required** item is done |
| E6 | Complete → notes → attach photo/video → **Submit** | → In Review in one action; moves out of Active |
| E7 | Cancel an in-flight upload | Uploads abort, media is **kept**, no error noise. Cancel hidden during "finalizing" |
| E8 | Re-submit after a partial failure | Only the un-uploaded files re-upload |
| E9 | Manager rejects it | You can restart; `revisionNumber` increments |
| E10 | File a **Request** | Pending → your manager decides |
| E11 | Open a **Case**, send a reply | Reply appears; a **failed** send keeps your text + attachments |
| E12 | Open a confidential Case as the manager | You **cannot** see who filed it |

## 3 · Attendance — real hardware only ⚠️

Minutes feed payroll. Test this properly.

| # | Step | Expect |
| --- | --- | --- |
| T1 | Open `/attendance` while **on site** | GPS card: At-branch. Clock In enabled |
| T2 | Clock in | Live `HH:MM:SS` timer. Time is the **server's**, not the device's |
| T3 | Clock in **off site** | Blocked, with a reason (outside radius) |
| T4 | Deny location permission | Clear "Permission" state, no crash |
| T5 | Turn location services off | Clear "Off" state, no crash |
| T6 | Clock in twice (double-tap / retry) | **One** record. Deterministic id makes this idempotent |
| T7 | Clock in **offline**, then reconnect | Syncs; still one record; "syncing"/"offline" surfaced |
| T8 | Clock **out** while off site | **Succeeds** — clock-out is never GPS-blocked, but records the verification |
| T9 | File a correction | Pending → a reviewer decides |
| T10 | Try to approve **your own** correction | Rejected server-side |
| T11 | Admin `/admin/attendance` | Board derives Not-started → Late → Absent by time, plus Working/Completed/On-leave/Needs-review |
| T12 | Never clock out; wait for `autoCloseAttendance` | Session → `pendingReview` |

## 4 · Manager

| # | Step | Expect |
| --- | --- | --- |
| M1 | Schedule → create the week | Empty Sun→Sat × Morning/Night grid |
| M2 | Assign / remove employees | Immediate |
| M3 | Check the **insight strip** | open · one-person · short-rest · double-booked · leave-clash. Each **filters the grid** on tap |
| M4 | Edit shift hours → pick a scope | This week (slot only) · Future (template) · Global (restamps current/future weeks). **A past week never changes** |
| M5 | Set leave + a day note | Renders on the grid and in the employee's sheet |
| M6 | **Final View** → export PNG | Lands in Downloads (macOS needs the downloads entitlement) |
| M7 | Approve a coworker-accepted swap | Slot rewrites atomically (server-side) |
| M8 | Create a **shift task** (not a person) | Only today's rostered crew sees it |
| M9 | Review a submission → Approve / Rework | Status moves; the timeline records actor + note |
| M10 | Two managers approve the **same** task at once | One wins; the other gets a conflict, **no lost decision** |
| M11 | Manager Home on an **opted-in** branch | A **Branch monthly sales** card under *On shift today*: target · achieved · remaining. Tapping it opens `/sales` |
| M12 | Approve a sales close, return Home | The **achieved** figure moved without a manual refresh |
| M13 | Manager Home on an **opted-out** branch (`salesTargetEnabled: false`) | **No sales card and no gap where it was.** Operations still lists *Branch attendance*, and there is no *Branch sales* row anywhere |

## 5 · Admin

| # | Step | Expect |
| --- | --- | --- |
| A1 | Create a branch | Appears in every branch picker |
| A2 | Set a branch **GPS area** | Current location prefills; validation rejects a bad radius |
| A3 | Promote an employee → manager | **Branch is kept**, not wiped |
| A4 | Move an employee's branch | They see the new branch's schedule |
| A5 | Admin Home | "Needs attention" tiles are live; each drills to a filtered view; a cleared tile shows ✓, never a bare "0" |
| A6 | Reopen an approved task, then re-approve | **One** recurrence spawns, not two |
| A7 | Soft-delete + reopen a Request | Both work; hard delete is denied |

## 6 · Cross-cutting

| # | Check | Expect |
| --- | --- | --- |
| R1 | **Realtime:** tasks | Push. Appear with no refresh |
| R2 | **Realtime:** schedule / branch / admin / swap lists | Correct **after pull-to-refresh** — by design. Not a bug |
| O1 | Load screens, go Airplane Mode, reopen | Cached data renders |
| O2 | Mutate offline | UI updates from cache; write queues |
| O3 | Upload media offline | Fails or queues **without crashing** — Storage has no offline cache |
| O4 | Reconnect | Queued writes sync; lists reconcile |
| U1 | **Monochrome** throughout | White is the only accent. **Any colour that isn't success/error/warning is a bug** |
| U2 | Role guards | An employee deep-linking `/admin/*` is bounced home |
| U3 | Notification tap (every type) | Opens the right screen; an unknown type lands on the inbox, never a crash |
| U4 | Desktop | Sidebar, ⌘1–⌘9, ⌘K. No stretched-mobile layouts |
| U5 | Errors | Red snackbar; the screen keeps its last data. No infinite spinners |

## Known limitations — do NOT file as bugs

- **Schedule / admin / swap / branch lists** refresh on pull, not push. Deliberate.
- **iOS push** does not work — unconfigured, tracked in
  [CURRENT_STATE](../CURRENT_STATE.md).
- ~~**`splash_centering_test.dart`** fails (2 cases).~~ Fixed 2026-08-03; the
  suite is green (1665 pass, 0 fail).
- **Managers cannot administer users.** Admin-only by design.
- **Account deletion** leaves the `users/{uid}` doc behind.
- **A recurring task** spawns as **Pending** and needs assigning if assignees change.
- **A deleted Request** intentionally orphans its `events` subcollection.
- **`activityLog` is embedded** in the task doc — no per-entry analytics.
- **Breaks** are not in the attendance MVP.

## Exit criteria

- [ ] Every P-precondition done.
- [ ] Sections 1–6 pass on a real device, both platforms.
- [ ] Attendance §3 verified **on real hardware** (§T1–T12).
- [ ] `flutter analyze` clean · `flutter test` green.
- [ ] No monochrome violations.
- [ ] No crash reports in `last_crash.log` after a full pass.

| Suite | Tester | Date | Pass/Fail | Notes |
| --- | --- | --- | --- | --- |
| Onboarding | | | | |
| Employee | | | | |
| **Attendance (device)** | | | | |
| Manager | | | | |
| Admin | | | | |
| Cross-cutting | | | | |
