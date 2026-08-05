# DROP

**DROP — Operations Management System.** A role-based branch/shift operations app
(admin · manager · employee) for running daily branch work: task assignment and
review with proof, attendance, weekly scheduling and shift swaps, approvals, branch
administration, and live operations dashboards.

iOS · Android · macOS. Flutter + Firebase.

> The Dart package identifier is `drop` (every import is `package:drop/…`) and all
> platform display names read **Drop Operation**. The platform identifiers are
> `com.ziad.drop` on iOS/macOS and `com.example.dropoperation` on Android/Linux.
> Register the Android/Linux identifier in Firebase and regenerate its configuration
> before shipping a new Firebase-enabled build.

## Documentation

Each document has **one** responsibility. Start at PROJECT_CONTEXT; follow a link
only when the task needs it.

| Document | Answers |
| --- | --- |
| [PROJECT_CONTEXT.md](PROJECT_CONTEXT.md) | **How is this built?** Architecture, module map, coding standards, UI philosophy |
| [CURRENT_STATE.md](CURRENT_STATE.md) | **Where are we today?** Branches, what's done, known issues, priorities |
| [CHANGELOG.md](CHANGELOG.md) | **What happened when?** |
| [docs/design/](docs/design/) | **How does *this feature* work?** One spec per feature |
| [docs/decisions/](docs/decisions/) | **Why, and don't re-litigate.** Architecture Decision Records |
| [docs/QA.md](docs/QA.md) | **How do we verify a release?** |

**If the code and a doc disagree, the code wins** — verify against the code, then fix
the doc in the same task.

## Getting started

```bash
flutter pub get
flutter run
```

```bash
flutter analyze     # expect: 1 pre-existing info
flutter test        # expect: 878 pass, 2 fail (known — see CURRENT_STATE)
```

After changing `freezed` entities or states:

```bash
dart run build_runner build --delete-conflicting-outputs
```

## Firebase

Auth · Firestore · Storage · Cloud Messaging · Cloud Functions back the app. The
backend contract is [docs/design/DATA_MODEL.md](docs/design/DATA_MODEL.md).

```bash
firebase deploy --only functions,firestore:rules,firestore:indexes,storage
```

⚠️ **Rules, indexes, and functions are currently undeployed**, so a growing share of
the app is inert in production and fails at *runtime* rather than at compile time.
See [CURRENT_STATE.md](CURRENT_STATE.md) before shipping.
