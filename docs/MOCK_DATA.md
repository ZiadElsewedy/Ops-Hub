# Realistic local mock data

The mock dataset runs against the Firebase Emulator Suite only. It cannot write
to the production project: the seed command exits unless both the Firestore and
Auth emulator hosts are present.

It creates 10 login accounts and 210 linked documents across branches,
users and private compensation, tasks and templates, schedules and swaps,
attendance and reporting ledgers, attendance audit events and week reviews,
corrections, requests, cases, sales, broadcasts, notifications, reminder
configuration and ledgers, usage counters, audit history, and automation
history. Dates are relative to the day the command runs, so current dashboards
do not go stale.

## Run it

Terminal 1 — start the local Firebase services:

```bash
firebase emulators:start --only auth,firestore,storage
```

Terminal 2 — seed or refresh the data:

```bash
FIRESTORE_EMULATOR_HOST=127.0.0.1:8088 \
FIREBASE_AUTH_EMULATOR_HOST=127.0.0.1:9099 \
GCLOUD_PROJECT=bazic-d9ad7 \
npm --prefix functions run seed:mock
```

Terminal 3 — run the app against those services:

```bash
flutter run \
  -d macos \
  --dart-define=USE_FIREBASE_EMULATORS=true \
  --dart-define=FIREBASE_EMULATOR_HOST=localhost
```

You can also choose **OpsHub (Mock data / Firebase emulators)** from VS Code's
Run and Debug menu instead of typing the `flutter run` command.

Open `http://localhost:4000` to inspect Auth and Firestore while the emulators
are running. Log in to the app with one of the accounts below; the admin account
is the quickest way to see every populated workflow. Changes made in the app
stay local and are visible immediately in the Emulator UI.

The preview command intentionally leaves the Functions emulator off. Reading,
navigating, and client-owned edits work, while server-authoritative buttons
(for example account creation and sales approval) report that their local
function is unavailable. This keeps the basic demo isolated from scheduled or
push-producing backend code. Run Functions separately only when testing those
flows, with the repository's declared Node 22 runtime.

For an Android emulator use `10.0.2.2` instead of `localhost`. An iOS simulator,
macOS app, or web app on the development machine uses `localhost`. A physical
device additionally requires the Firebase emulators to listen on the LAN rather
than their default loopback interface; the checked-in setup is intentionally
loopback-only, so use a simulator/desktop run for the safe default workflow.

## Demo accounts

Every account uses the password `MockPass123!`.

| Role | Email | Scope |
| --- | --- | --- |
| Admin | `admin@opshub.test` | All branches and all workflows |
| Manager | `manager.downtown@opshub.test` | Downtown Flagship |
| Manager | `manager.maadi@opshub.test` | Maadi |
| Employee | `salma@opshub.test` | Downtown, morning shift |
| Employee | `youssef@opshub.test` | Downtown, night shift |
| Employee | `layla@opshub.test` | Downtown, morning shift |
| Employee | `karim@opshub.test` | Downtown, night shift |
| Employee | `dina@opshub.test` | Maadi, morning shift |
| Employee | `ahmed@opshub.test` | Maadi, night shift |
| Employee | `hana@opshub.test` | Maadi, morning shift |

The seed is idempotent: rerunning it merges the same stable mock IDs and refreshes
date-relative records. It does not delete other emulator documents.

## Validate without emulators

```bash
npm --prefix functions run seed:mock:dry
npm --prefix functions test
```

Chat is backed by the separate NestJS service rather than Firebase, so this
Firebase fixture does not create chat conversations.
