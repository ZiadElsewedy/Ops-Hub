<!-- AUTO-GENERATED mechanical inventory. Regenerate: python3 .nav/gen_atlas.py
     Hand-authored intelligence lives BELOW the marker. Do not delete that section. -->
# 📍 FEATURE CARD — `manager`

> `lib/features/manager/` · **2 files** · layer-complete clean-architecture slice

## Entry points (route → screen)
| Route const | Path | Guard/notes |
|---|---|---|
| `RouteNames.adminManagers` | `/admin/managers` |  |
| `RouteNames.managerHome` | `/manager` |  |
| `RouteNames.managerSchedule` | `/manager/schedule` |  |
| `RouteNames.managerTasks` | `/manager/tasks` |  |

## Owner files (by layer)
**presentation:page**
- `lib/features/manager/presentation/pages/manager_home_screen.dart`
- `lib/features/manager/presentation/pages/manager_shell.dart`

## Backend surface
- **Firestore collections:** —
- **Cloud Functions:** —
- **Security rules:** `firestore.rules` (search the collection names above) · `storage.rules` if it uploads media
- **Design spec(s):** —

## Tests
- `test/features/sales/presentation/sales_manager_dashboard_cubit_test.dart`
- `test/manager_home_test.dart`

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

**Presentation-only.** Two files: `ManagerShell` (a `RoleScaffold` wrapper) and
`ManagerHomeScreen`, the manager's **branch command center**. It owns no data —
every number is a scoped `BlocSelector` over app-wide cubits (`TaskCubit`,
`StatisticsCubit`, `ShiftSwapCubit`, `RequestsListCubit`, `CaseListCubit`,
`BranchCubit`), and every visual is a `core/widgets/` V2 primitive.

Rebuilt 2026-08-03 into the same ranked ladder the Admin command center was
signed off on — hero → `AttentionPanel` → Today → On shift today → Recent
activity → `DigestPanel` · quick actions — with a fixed 360px right rail on
desktop. It replaced a flat wall of ten equal-weight `StatGrid` cards plus an
embedded `TaskFeedSection` browser.

## ⚠️ Dangerous areas / invariants

- **The hero sentence and the attention panel must read the same total.** Both
  switch off `reviews + overdue + unassigned + rejected + swaps` via the shared
  `_attentionCounts` / `_openSwapCount` selectors and `dashboardMood(...)`. The
  old screen's headline figure came from a different source than the strip
  beneath it and the two disagreed on screen — do not reintroduce a second
  source for the same number.
- **Counts come from `task_metrics.dart`, never from `StatisticsCubit`**, so a
  cell's figure and the list its tap opens are derived from the one live stream.
  `StatisticsCubit` is used only for roster context (team size, shift coverage),
  which no drill-down lists.
- **`Late` is drawn exactly once** (the attention panel's lead row). It is
  deliberately absent from the Today row — pinned by `manager_home_test.dart`.
- **Every Today tile opens a list.** The row is `MetricTile`s, and a cell that
  looks tappable but isn't is worse than one that isn't drawn — which is why
  Admin Home's inert `Due soon` became **`Due today`** here, counted by the same
  `applyFeed(…, FeedPreset.dueToday, …)` call its drill-down renders. Don't add
  a figure to this row that no `TaskFeedFilter` can reproduce.
- **`On shift today` is one card, not four cells**, and it opens the **roster
  peek** (`schedule/presentation/widgets/today_roster_sheet.dart`) — who is on
  each shift — **not** the weekly editor. The grid is for *changing* a roster;
  it answers "who's in?" only after a navigation and a day/shift hunt.
  ⚠️ The peek reads the app-wide `ScheduleCubit`, so it **restores whatever
  (branch, week) that cubit was showing** when it closes — otherwise opening it
  from Home silently resets the Schedule tab to this week. Keep that behaviour
  if you touch the sheet.
- **There is no Quick actions section, and Recent messages is desktop-only.**
  Both were duplicated navigation on a phone (bottom nav + app bar). Don't
  re-add them without a fresh ask.
- **The hero carries one supporting line.** The branch rides the *eyebrow*
  (uppercased by `PageHero` — match the uppercase form in tests), `HeroMood`'s
  scope slot is passed `''`, and freshness is not printed: `SyncButton` has it.
- **Swaps load `loadBranch`, never `loadAll`** — a manager runs one branch.
- **Every pushed filter passes `branchId` explicitly**, even though the
  manager's `TaskCubit` stream is already branch-scoped: a drill-down should
  state its scope, not inherit it.
- Widget tests **must unmount the tree** (`pumpWidget(SizedBox.shrink())`) — the
  hero's `SyncButton` drives a 30s `Timer.periodic`. `pumpAndSettle` will hang:
  the hero's live pulse dot repeats forever by design. A `scrollUntilVisible`
  fling leaves a ballistic simulation pending for the same reason.

## 🧩 Extension points

- A new triage signal → append an `AttentionSignal` to `_signals(...)` **in
  urgency order**; the panel handles ranking, the cleared footer and the
  all-clear copy from the list itself.
- A new module door → an entry in `_digest()`; `DigestEntry.value` is optional,
  so a door with no honest figure renders label + chevron.
- A new light metric → a `Stat` in `_today()`, derived in `task_metrics.dart`.

## 🔗 Related

- **The same language, one tier up:** `features/admin` →
  `admin_dashboard_screen.dart`. Both compose the shared primitives; changing
  one's *layout* should not silently diverge the other's.
- **Shared V2 primitives** (all in `core/widgets/`): `page_hero` · `primary_cta`
  · `hero_mood` (+ `core/utils/dashboard_mood.dart`) · `attention_panel` ·
  `digest_panel` · `stat_strip` · `sync_button` · `command_hint` ·
  `live_status_border`.
- **Where the manager's work actually happens:** `features/operations` (the
  Branch Operations cockpit at `/manager/tasks`) — Home links into it, it is not
  duplicated on Home.
- ADR-004 (monochrome) · ADR-010 (lean over enterprise).