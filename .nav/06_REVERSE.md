# 🔎 06 · REVERSE NAVIGATION — start from a file

You're holding a file and asking: *why does this exist, who depends on it, what owns it, may I edit it?*

## 🧰 The universal reverse-lookup protocol (works for ANY file)

```bash
# 1. WHO IMPORTS THIS FILE (its dependents)
grep -rl "features/<F>/<path>/<file>.dart" lib test

# 2. WHAT THIS FILE DEPENDS ON
head -40 <file>.dart          # its imports = its dependencies

# 3. WHERE A CLASS/SYMBOL IS USED
grep -rn "SymbolName" lib test

# 4. WHO CONSTRUCTS IT (ownership)
grep -rn "SymbolName(" lib/core/di/injection.dart lib

# 5. WHICH LAYER → what it may import (the golden rule)
#    presentation → domain → data ;  domain imports no Flutter/Firebase ; core never imports a feature
```
**Layer tells you the answer before you grep:** a file's folder (`presentation/` `domain/` `data/`) fixes
what it may own and depend on. See [`07_PATTERNS.md`](07_PATTERNS.md).

## 🗺️ Reverse cards for the load-bearing files

### `lib/core/di/injection.dart` — `AppDependencies`
- **Why:** hand-rolled static service locator (NOT GetIt). Builds every repo, cubit, service, datasource at boot.
- **Depends on:** basically everything (imports all feature repos/usecases/cubits).
- **Owns:** object lifetimes + the app-wide singleton cubits (`chatListCubit`, `caseListCubit`, `authCubit`…).
- **Owned by:** `main.dart` calls `AppDependencies.init()`.
- **Edit when:** you add a repo/cubit/service, or change how one is constructed.
- **Do NOT:** throw in `init()` (white screen on boot); construct feature objects anywhere else.

### `lib/core/routes/app_router.dart`
- **Why:** the single GoRouter + the `_redirect` auth/role gate.
- **Depends on:** `route_names.dart`, `AuthCubit`, every screen it builds.
- **Owns:** navigation graph, first-login funnel, role guards.
- **Owned by:** `main.dart` → `createRouter(authCubit)`.
- **Edit when:** adding a route, changing access rules, changing the login flow.
- **Do NOT:** make `_redirect` async; redirect on error/initial auth states.

### `lib/core/routes/route_names.dart`
- **Why:** 🧠 every path string + the `*ForRole()` dispatch helpers.
- **Owned by:** router + any screen that navigates. **Edit when:** adding/renaming a route. Never hard-code paths elsewhere.

### `firestore.rules`
- **Why:** the real security boundary (clients are untrusted).
- **Owned by:** Firebase deploy. **Depended on by:** every read/write in the app, live in prod.
- **Edit when:** a collection/field's access changes. **Always:** test in `firestore-tests/` first; default optionals to `null`.

### `functions/index.js`
- **Why:** all privileged/server-authoritative logic + triggers + crons (🖥️).
- **Owned by:** `firebase deploy --only functions`. **Depended on by:** clients (callables) + Firestore writes (triggers).
- **Edit when:** changing server logic. **Do NOT:** move this to the client to "speed it up" (ADR-005).

### `lib/features/*/domain/entities/*.dart` (freezed)
- **Why:** the pure shape of a concept. **Owns:** the field set. **Owned by:** models (map to/from) + cubits/widgets (read).
- **Edit when:** the concept gains/loses a field → then run `build_runner`. **Do NOT:** put Firebase/Flutter here.

### `lib/features/*/data/models/*_model.dart`
- **Why:** the JSON boundary (`fromJson`/`toJson`) between Firestore and the domain entity.
- **Owned by:** the repository impl. **Edit when:** the Firestore shape changes. **Guard:** every optional serializes as `null`, not `''`.

### `lib/features/*/presentation/cubit/*_cubit.dart` (+ `*_state.dart` freezed)
- **Why:** feature state machine; the only thing the UI talks to.
- **Depends on:** usecases (domain). **Owned by:** DI (or a route BlocProvider). **Owns:** emitted state.
- **Edit when:** UI behavior/state changes. **Do NOT:** call Firestore directly from a cubit — go through a usecase/repo.

### `lib/core/widgets/*` (43 shared primitives)
- **Why:** reusable UI (cards, empty states, chrome, RoleScaffold, AppBottomNav).
- **⚠️ Owned by:** many features at once. **Edit when:** a truly shared visual changes — **grep callers first**.

## 🧭 "I only know the symbol" → find its home

| You see… | It lives in… |
|---|---|
| `...Screen` / `...Page` | `features/<F>/presentation/pages/` |
| `...Cubit` / `...State` | `features/<F>/presentation/cubit/` |
| `...Card` / `...Tile` / small widget | `features/<F>/presentation/widgets/` or `core/widgets/` |
| `...Entity` | `features/<F>/domain/entities/` |
| `...Repository` (abstract) | `features/<F>/domain/repositories/` |
| `...RepositoryImpl` | `features/<F>/data/repositories/` |
| a verb-noun class (`CreateTask`, `ApproveSwap`) | `features/<F>/domain/usecases/` |
| `...Model` | `features/<F>/data/models/` |
| `...RemoteDatasource` | `features/<F>/data/datasources/` |
| `RouteNames.x` | `core/routes/route_names.dart` |
| a `*Status`/`*Type` enum | `core/enums/` |
| `AppDependencies.x` | `core/di/injection.dart` |

Next: [`07_PATTERNS.md`](07_PATTERNS.md) — the anatomy every file above obeys.
