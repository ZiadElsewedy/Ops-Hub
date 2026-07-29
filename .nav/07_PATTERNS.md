# 🧬 07 · PATTERNS — the universal anatomy & recipes

Learn the shape once; every feature obeys it. This is why you can navigate 18 features without reading 18
architectures.

## The anatomy of a feature (the template all 18 follow)

```
lib/features/<F>/
├── presentation/
│   ├── pages/        <X>Screen / <X>Page          ← route target; builds the cubit, renders state
│   ├── cubit/        <X>Cubit  + <X>State(freezed) ← the feature's state machine
│   ├── widgets/      cards, tiles, sheets          ← dumb-ish UI fed by state
│   └── <x>_format.dart                             ← presentation-only formatting/palette (optional)
├── domain/                                          ← PURE Dart. no Flutter, no Firebase.
│   ├── entities/     <X>Entity (freezed)           ← the concept's shape
│   ├── repositories/ <X>Repository (abstract)      ← the contract (seam)
│   ├── usecases/     Verb-noun classes             ← one action each (CreateTask, ApproveSwap…)
│   └── <x>_*.dart    pure helpers (ordering, metrics, access rules)
└── data/
    ├── models/       <X>Model  fromJson/toJson     ← Firestore ↔ entity boundary
    ├── repositories/ <X>RepositoryImpl             ← implements the contract, orchestrates datasources
    └── datasources/  <X>RemoteDatasource           ← raw Firestore/Functions/API calls
```

### The call chain (memorize this — it is the whole app)
```
Widget ──tap──► Cubit.method()
                   └─► UseCase.call()               (domain — one action)
                          └─► Repository (abstract)  (domain — the seam)
                                 └─► RepositoryImpl  (data — orchestration)
                                        └─► RemoteDatasource ──► Firestore / Cloud Function / NestJS
                   ◄── Entity ◄── Model.fromJson ◄── snapshot/response
Cubit.emit(state) ──► Widget rebuilds (BlocBuilder)
```
Realtime reads (↕️) skip the request/response and use `watch*()` streams → cubit subscribes → UI live-updates.

## The rules of the shape (dependency direction)
1. `presentation → domain → data`. Arrows never reverse.
2. `domain/` imports **no** Flutter and **no** Firebase. If you `import 'package:flutter'` in domain, you broke it.
3. `core/` never imports a `feature/`. Features may import `core/`.
4. A feature never reaches into another feature's `domain/`/`data/` internals. Reuse via `core/` or a public
   cubit exposed through `AppDependencies`.
5. Every write that must be trusted is server-authoritative (a Cloud Function), not a client write.

## State management (ADR-002: Cubit-only)
- **Cubit + freezed state**, no `Bloc` events, no other state lib. 25 cubits total.
- App-wide singleton cubits (auth, chat list, case list) are built once in `AppDependencies`; per-thread/
  per-detail cubits are built fresh per screen.

---

## 🍳 RECIPES

### Recipe: add a whole new feature `<F>`
```
▸ 1. mkdir the 3 layers: presentation/{pages,cubit,widgets} domain/{entities,repositories,usecases} data/{models,repositories,datasources}
▸ 2. domain first:  entity (freezed) → repository contract → usecases
▸ 3. data:          model (json) → datasource → repository impl
▸ 4. presentation:  state (freezed) → cubit → screen → widgets
▸ 5. wire:          construct repo+usecases+cubit in lib/core/di/injection.dart
▸ 6. route:         route_names.dart const → app_router.dart GoRoute (+ guard)
▸ 7. backend:       firestore.rules match block (+ firestore-tests/ case) → indexes → any functions
▸ 8. test:          mirror the big features (entity/model/cubit/widget tests)
▸ 9. docs:          docs/design/<F>.md + DATA_MODEL.md, then update .nav (python3 .nav/gen_atlas.py)
```
Copy the closest existing feature of similar size as a skeleton (`requests` is a clean, small exemplar).

### Recipe: add a usecase
```
▸ domain/usecases/<verb_noun>.dart  (single call() method, depends only on the repository contract)
▸ add the method to the repository contract + impl if it needs new data access
▸ construct it in AppDependencies and pass to the cubit
```

### Recipe: add a field  → see [`04_EDIT_IF.md`](04_EDIT_IF.md) (freezed → model → rules → UI → docs).

### Recipe: add a status/type value
```
▸ core/enums/<x>_status.dart  add the value
▸ fix EVERY exhaustive switch (compiler will list them) — colour maps, format files, rules, functions
▸ add/extend the enum test (there is a *_status_test.dart per enum)
```

## Codegen & verification
```bash
dart run build_runner build --delete-conflicting-outputs   # after any freezed/json change
flutter analyze
flutter test                                                # 161 test files
firebase deploy --only firestore:rules,firestore:indexes,functions,storage   # backend changes
```

## Naming conventions (so search always finds it)
`snake_case.dart` files · `PascalCase` classes · usecases are `VerbNoun` · screens end `Screen`/`Page` ·
state end `State` · models end `Model` · contracts are `XRepository`, impls `XRepositoryImpl`.

Next: [`08_AI_PROTOCOL.md`](08_AI_PROTOCOL.md) — how an AI agent should use all of the above.
