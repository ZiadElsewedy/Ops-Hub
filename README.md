<div align="center">

<img src="assets/drop_logo.png" alt="DROP" width="120" />

# DROP — Operations Management System

**Role-based branch & shift operations for DROP THE SHOP.**
Task assignment with proof · GPS attendance · weekly scheduling & shift swaps · approvals · branch administration · live operations dashboards.

<!-- Badges reflect the repo, not pub.dev — this is a private package. -->
`iOS · Android · macOS`&nbsp;&nbsp;`Flutter · Dart ^3.12`&nbsp;&nbsp;`flutter_bloc (Cubits)`&nbsp;&nbsp;`Firebase`&nbsp;&nbsp;`Clean · feature-sliced`&nbsp;&nbsp;`Monochrome · dark`&nbsp;&nbsp;`1665 tests · ~40s`

</div>

---

## Overview

DROP is an **internal, role-based operations tool** — not a SaaS product. It has no
public sign-up and no buyers, only a small, known set of staff across a handful of
branches. Three roles run the whole system:

| Role | Scope |
| --- | --- |
| **Admin** | Global. Provisions accounts, works across every branch, does everything a manager can. |
| **Manager** | Exactly one branch. Assigns and reviews work, approves swaps and requests, watches coverage. |
| **Employee** | Own work only. Executes tasks with proof, clocks in/out by GPS, requests swaps and approvals. |

Authentication is **admin-provisioned** — an admin creates each account via a Cloud
Function; there is no public registration, OTP, or social sign-in. First login walks a
deterministic gate: force password change → profile completion → one-time welcome →
role home.

### Design philosophy

- **Workflow over architecture. UX over feature count.** Default to deletion — the burden of proof is on *keeping* a feature.
- **Premium, not minimal.** Strictly monochrome, dark-mode-only. White is the only accent; colour is reserved for `success` / `error` / `warning` / `info` status.
- **Simple > clever. Stability > perfection.** No abstraction without a second caller; 90% done with zero regressions beats 100% with risk.

---

## Features

| Module | What it does |
| --- | --- |
| **Tasks** | Operations tasks: create → execute (with proof) → review. Templates and recurring shift-task automation. |
| **Schedule** | Admin cross-branch *Today* coverage, weekly roster, shift templates, leave, and attributed swap approval/history. |
| **Attendance** | GPS-verified clock in/out with geofences, corrections, and an admin board. |
| **Requests** | Lightweight employee → manager yes/no approvals. |
| **Cases** | Private employee ↔ manager/admin conversations. |
| **Chat** | Direct 1:1 staff chat over a NestJS API with Socket.IO realtime and an offline SQLite cache *(in progress)*. |
| **Communications** | Broadcasts, templates, schedules, and reminders. |
| **Sales** | Per-branch monthly sales targets, daily employee closes, manager approval, and derived pace KPIs *(opt-in per branch)*. |
| **Operations** | Branch operations cockpit — workload and KPI drill-downs. |
| **Notifications** | Notification inbox with deep-link resolution. |
| **Admin & Branch** | User administration, branch CRUD, geofences, and policy configuration. |
| **Statistics** | Role-scoped counts powering all three dashboards. |

---

## Tech stack

| Concern | Choice |
| --- | --- |
| Language / UI | Dart `^3.12.1` · Flutter |
| State | `flutter_bloc` — **Cubits only** |
| Navigation | `go_router` — auth-aware redirects + role guards |
| Backend | Firebase: Auth · Firestore · Storage · Cloud Messaging · Cloud Functions |
| Chat API *(in progress)* | NestJS over `dio` + Socket.IO; offline cache via `drift` (SQLite) |
| Models | `freezed` + `json_serializable`, generated with `build_runner` |
| Location | `geolocator` (attendance GPS) |
| Media | `image_picker` · `image_cropper` · `video_compress` |

**Platforms:** iOS · Android · macOS. Desktop is a first-class target, not an afterthought.

---

## Architecture

**Clean Architecture, sliced by feature.** The dependency rule points inward:
`presentation → domain ← data`.

```
lib/
├── core/                 # Feature-neutral: theme, routing, DI, network, widgets
└── features/<feature>/
    ├── data/             # The ONLY place Firebase exists (datasources · models · repositories)
    ├── domain/           # Pure Dart — never imports Flutter or Firebase (entities · repositories · usecases)
    └── presentation/     # Cubits · pages · widgets (sees entities only)
```

`domain/` depends on nothing, which is why the full 1665-test suite runs in ~40s
with no Firebase and no live backend. Dependencies are wired **by hand** in
[`lib/core/di/injection.dart`](lib/core/di/injection.dart) — no DI package.

Full rationale lives in the [Architecture Decision Records](docs/decisions/).

---

## Getting started

**Prerequisites:** Flutter with Dart `^3.12.1`, and the Firebase CLI for backend work.

```bash
flutter pub get
flutter run
```

After changing any `freezed` entity or state, regenerate code:

```bash
dart run build_runner build --delete-conflicting-outputs
```

### Verify

```bash
flutter analyze     # expect: 1 pre-existing info
flutter test        # expect: 1665 pass, 0 fail — any red is a real regression
```

If you touch `firestore.rules`, also run the rules suite (the Dart tests never
evaluate a rule):

```bash
cd firestore-tests && npm test   # expect: 68 pass — needs the Firebase CLI + a JDK
```

And after any change under `functions/`:

```bash
cd functions && node --test      # expect: 112 pass
```

---

## Firebase

Auth · Firestore · Storage · Cloud Messaging · Cloud Functions back the app; the
backend contract is [`docs/design/DATA_MODEL.md`](docs/design/DATA_MODEL.md). Server
logic lives in [`functions/`](functions/).

```bash
firebase deploy --only functions,firestore:rules,firestore:indexes,storage
```

> ⚠️ Deploy status is tracked in [CURRENT_STATE.md](CURRENT_STATE.md). Some rules,
> indexes, and functions may be undeployed at any given time — an undeployed change is
> inert in production and fails at *runtime*, not compile time. **Read CURRENT_STATE
> before shipping.**

---

## Documentation

Each document has **one** responsibility. Start at **PROJECT_CONTEXT**; follow a link
only when the task needs it.

| Document | Answers |
| --- | --- |
| [PROJECT_CONTEXT.md](PROJECT_CONTEXT.md) | **How is this built?** Architecture, module map, coding standards, UI philosophy |
| [.nav/](.nav/README.md) — *Atlas* | **Where do I go / what breaks?** Navigation for contributors and AI agents |
| [CURRENT_STATE.md](CURRENT_STATE.md) | **Where are we today?** Branches, what's done, known issues, priorities |
| [CHANGELOG.md](CHANGELOG.md) | **What happened when?** |
| [docs/design/](docs/design/) | **How does *this feature* work?** One spec per feature |
| [docs/decisions/](docs/decisions/) | **Why, and don't re-litigate.** Architecture Decision Records |
| [docs/QA.md](docs/QA.md) | **How do we verify a release?** |

**If the code and a doc disagree, the code wins** — verify against the code, then fix
the doc in the same task.

---

## Project identity

The repository folder is **`Drop-operations`**; the Dart package is **`drop`** (every
import is `package:drop/…`), and all platform display names read **Drop Operation**.
Platform identifiers are `com.ziad.drop` on iOS/macOS and `com.example.dropoperation`
on Android/Linux.

> This is a private package (`publish_to: none`) and is not distributed on pub.dev.
