# Environments

There are exactly **two** environments, and the app picks one **automatically
from the build mode**. There is nothing to configure, no dart-defines to
remember, and no files to edit per build.

| Build                              | Environment | Backend                                      |
| ---------------------------------- | ----------- | -------------------------------------------- |
| `flutter run` (Debug/Profile)      | Development | `http://localhost:3000`                      |
| `flutter build … --release`        | Production  | `https://drop-api-production.up.railway.app` |

The single source of truth is [`lib/core/config/app_environment.dart`](../lib/core/config/app_environment.dart).
A **release binary is locked to Railway** — no dart-define or config file can
point it at localhost or an emulator IP.

## Development

```bash
flutter run
```

Uses the local backend. Hot reload works as usual.

**Physical device on the LAN** (optional) — point a *debug* build at your Mac's
local backend by IP. This define is ignored in release, so it can never leak
into production:

```bash
flutter run --dart-define=DEV_API_BASE_URL=http://192.168.1.8:3000
```

## Production

```bash
flutter build apk --release
flutter build appbundle --release
flutter build ipa --release      # or: flutter build ios --release
```

Every release artifact targets Railway automatically. Install it once and open
the app normally — no `flutter run`, no debug server, no manual switching.

## Changing the production host

Edit the one constant `_productionBaseUrl` in
[`lib/core/config/app_environment.dart`](../lib/core/config/app_environment.dart).
