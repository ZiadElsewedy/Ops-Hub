# DROP Design System V2 — Foundation

> The inheritance contract for every DROP surface. Phase 1 established this while
> redesigning the Admin dashboard; Branches, Requests, Cases, Communications,
> Inventory, Analytics and every future module compose the **same** primitives so
> the product reads as one system.

## Philosophy — calm through hierarchy

The dashboard answers one question: **"what needs my attention right now?"** — not
"here is every row in the database." The fix for visual competition is **ranking,
spacing and grouping**, never removing richness. Keep the crafted DROP identity
(glass surfaces, living-border motion, rich metrics, monochrome + single accent).
The goal is **premium**, not minimal. Do **not** flatten into a generic
Linear/Jira/Notion clone.

### Progressive disclosure (the layer ladder)

Every module home is arranged as layers, top to bottom:

1. **L1 — Needs attention.** The dominant layer, rendered as **one grouped box**:
   a calm "all clear" summary when every count is zero, otherwise triage **rows**
   (overdue · pending review · sent back · unassigned · swaps) most-urgent-first
   inside a single living border — a fresh signal slides in as a row (`LiveListItem`,
   never the whole surface re-appearing), and cleared signals collapse to a quiet
   footer. `AttentionTile` remains the compact single-cell variant of the same idea.
2. **L2 — Today's health.** Light supporting metrics (completed today · running ·
   delayed · approval rate). No charts.
3. **L3 — Recent activity.** A clean vertical feed of what's happening.
4. **L4 — Deep navigation.** Quick actions, module directory, pulses.

## Tokens (already canonical — reuse, don't redeclare)

| Concern | Source |
| --- | --- |
| Spacing | `AppSpacing` (`xs 4 · sm 8 · md 12 · lg 16 · xl 24 · xxl 32 · xxxl 48`) |
| Radius | `AppRadius` (`card 20 · button 18 · full 999`, + `*All` `BorderRadius`) |
| Colour | `AppColors` — **strictly monochrome**; `accent`/`primary` = white; semantic `success`/`warning`/`error`/`info` **only for status**, used sparingly (`info` = work in flight, hairline only — never a fill) |
| Type | `AppTypography` (`display · h1 28 · h2 · h3 18 · labelLarge · label · labelSmall · caption`) |

### Text hierarchy — a 4-step ramp (2026-07-09)

Rank importance with **brightness before colour**. The neutral ladder is four
clearly-separated steps, each visibly darker than the last — no two share a
brightness, so a title never competes with its supporting line. Reach for the
faintest level that still reads; **never place two adjacent text elements on the
same grey** (a label and its value, a title and its subtitle must step apart).

| Level | Token | Hex | Use |
| --- | --- | --- | --- |
| White | `textPrimary` | `#FFFFFF` | page/task titles · primary values & important metrics · the thing the eye should hit first |
| Light grey | `textSecondary` | `#A7A7AF` | section subtitles · secondary info · **assignee / branch names** · supporting + metric labels |
| Medium grey | `textTertiary` | `#6E6E77` | metadata · **relative timestamps** · helper text · sublabels · eyebrows/kickers · contextual notes |
| Dark grey | `textQuaternary` | `#48484E` | disabled / inactive · **placeholders** · decorative meta · zero-state numbers |

The canonical pattern for a metric cell is a clean 3-step ramp — **white value →
light-grey label → medium-grey sublabel** (`AttentionTile`, `StatStrip`, digest
rows all follow it). A field is **light-grey label → white value → dark-grey
placeholder** (the placeholder only shows when empty, so it never sits beside the
value).

## Surfaces & cards

- **`GlassContainer`** — the one premium surface (gradient + hairline border + soft
  depth). `onTap` for press/hover feedback; `highlight`+`accent` to flag "act on
  this"; `glow` for a subtle status halo; `elevated:false` for a flat inset tile.
  On **desktop hover** a tappable card gently **elevates** (−2px lift + deeper
  shadow + warmed border; a flat tile picks up a soft hover shadow) — pointer
  feedback is on by default, honours reduced motion. Don't re-roll hover per card.
- **`AppGlassCard`** — status-glow card wrapper over `GlassContainer`.
- Never re-declare the card `BoxDecoration` — compose `GlassContainer`.
- **Date/time pickers** are themed monochrome (`DatePickerTheme`/`TimePickerTheme`
  in `AppTheme.dark`) — never drop a raw Material picker; the app theme dresses it.

## CTA hierarchy (one primary per screen)

| Tier | Component | Use |
| --- | --- | --- |
| **Primary** | the hero's filled monochrome CTA (`_PrimaryCta` pattern — white fill, dark label) — **exactly one per screen** | the single action the screen exists to drive (e.g. *Create Task*) |
| **Secondary** | `PremiumButton` | inline card actions |
| **Tertiary** | `ActionCard` (vertical) / `ActionCard(secondary:true)` (horizontal) / text buttons | quick actions + module directory |

## V2 primitives (`lib/core/widgets/`)

Generic + module-agnostic — entity mapping stays in features. **Every primitive:**
a `Semantics` label, ≥44px targets, text-scale-safe layout, honours reduced motion
(`MediaQuery.disableAnimations`), and lazy/`.builder` + capped visible count for any
collection (safe at 100 branches / 5,000 employees / multi-tenant).

- **`PageHero`** — eyebrow · title (`h1`) · subtitle · one `primaryAction` · quiet
  `trailing`. The header lockup of every module surface. Stacks the CTA full-width
  on narrow widths.
- **`AttentionTile`** — a priority triage cell: soft-accent glyph · big
  `AnimatedCount` · label · optional sublabel · `onTap`. Stays monochrome at zero,
  tints only when there's work. `AttentionTile.radius` is exposed so a feature can
  wrap the single most-urgent tile in `LiveStatusBorder` (the primitive itself does
  **not** depend on the task feature).
- **`StatStrip` / `Stat`** — a quiet single-`GlassContainer` row of `value/label`
  facts (the "Today" layer). Divided row when it fits, 2-up wrap when it doesn't.
  A `Stat` takes either a `count` (an int that **counts up** ~650ms when it moves)
  or a formatted string `value` (e.g. `96%`, `—`, which cross-fades) — a live
  number moves rather than snapping.
- **`ActivityCard`** — a clean vertical feed row (`leading · title · subtitle ……
  trailing · meta`). The V2 replacement for the horizontal "spreadsheet" feed;
  generic slots, feature code maps its entity onto them.

### Command-center chrome (shared 2026-08-03)

These were private classes inside `admin_dashboard_screen.dart` until Manager
Home became a second caller. They are the **whole** dashboard language — a role
home should compose them and derive its own counts, never re-draw them.

- **`PrimaryCta`** — a hero's one filled monochrome action (hover-lift,
  press-scale, key-light shadow). At most **one** per screen.
- **`HeroMood`** + `dashboardMood(needsAttention:)` (`core/utils/`) — the hero's
  one live state sentence beside a breathing pulse dot, plus the quiet scope
  line. Pure derivation from a single total, so the sentence and the attention
  layer below it **cannot disagree**.
- **`AttentionPanel`** / **`AttentionSignal`** — the dominant "act on these
  first" layer: ONE grouped box that never moves. Signals are passed in urgency
  order; those with work render as triage rows (glyph · label + sublabel ·
  counting-up figure · chevron), the cleared ones collapse into a single quiet
  footer, and at zero the whole box becomes an all-clear summary whose proof
  line (`0 late · 0 pending review · …`) is **derived from the signals given**,
  never hardcoded. A fresh signal slides in as a *row*; one unified
  `LiveStatusBorder` orbits the box, reading the most-urgent signal's tone.
- **`DigestPanel`** / **`DigestEntry`** — the quiet "everything else" layer: one
  grouped surface of module doors. Rows report a figure, they never count up,
  pulse, or wear a living border — anything needing a decision belongs in the
  attention panel above. `DigestEntry.value` is optional so a door with no
  honest number renders label + chevron instead of a placeholder dash.
- **`SyncButton`** (+ pure `syncLabel`) — the manual refresh escape hatch and
  the "Synced 3m ago" freshness label. Dashboards stay live without it.
  ⚠️ It drives a 30s `Timer.periodic`, so a widget test hosting a hero **must
  unmount the tree**; `pumpAndSettle` will hang on the pulse dot by design.
- **`CommandHint`** — the desktop "Search or run a command ⌘K" pill, so the
  palette is discoverable rather than merely known.
- **`MetricTile`** / **`MetricTileRow`** — the light, **always tappable** figure
  cell: a counting-up number, a glyph + label, and an `arrow_outward`
  affordance, laid out one row on desktop and 2-up on mobile. The quieter
  sibling of `AttentionTile` (which is the *triage* layer and rewards a cleared
  queue with a reassurance instead of a number); a `MetricTile` always shows its
  figure, because its job is a fact you can open.
  **Every tile opens something.** A figure no list can reproduce does not belong
  here — a cell identical to its tappable neighbours that does nothing is worse
  than one that isn't drawn. Where a count and its drill-down could disagree,
  derive the count with the same predicate the drill-down filters on (Manager
  Home's `Due today` counts with the very `applyFeed` call its list renders).

## Navigation — preview, never lose context

**Pattern:** tap → **preview sheet** → optional **full details** → back to exactly
where you were (scroll + state preserved).

- Tasks: `showTaskPreviewSheet(context, task:, directory:)` opens a draggable
  preview with quick actions; "Open full details" → `openTaskDetails(...)` (a local
  `Navigator.push`, so the dashboard stays mounted underneath).
- Filtered drills: push a small reusable screen (e.g. `FilteredTasksScreen(title:,
  filter:)`) on the caller's navigator — **never** a route swap that loses the
  dashboard.
- Put a `PageStorageKey` on the dashboard scroll view; use `push` (never `go`) for
  drills, so scroll offset + filters survive round-trips.

## Live & reactive

Surfaces update themselves. Each section is a scoped `BlocSelector` over the live
streams (task stream · statistics · shift swaps · requests · cases), so a stream
emit rebuilds **only** the section whose number moved. Manual refresh (a "Sync"
control) is a quiet escape hatch — **never** the update mechanism.

## States

- **Empty:** `DropEmptyState` / `AppEmptyState` (branded / routine). ⚠️ Only as a
  **direct `RefreshIndicator`/body child** (bounded height). Inside an unbounded
  `ListView`, use a compact inline empty (see `RecentActivityFeed._AllClear`) — a
  full-bleed empty forces an infinite-height layout.
- **Zero ≠ empty.** A zero value is a *healthy* state, not a switched-off one —
  reward it. An `AttentionTile` at zero shows a check + a reassuring line
  (`clearedMessage`: "No overdue tasks") instead of a bare "0"; an empty feed reads
  "All clear / everything is handled", not "no data". Never leave a lone grey "0".
- **Loading:** `DropLoadingState` (full page) / structure-suggesting **skeleton
  rows** shaped like the real content (`Skeleton`), not a bare spinner, for an
  inline list.

## Living system (the dashboard is never static)

Even at zero work the surface should feel alive and under control. Two devices:

- **Live state sentence** (`dashboard_mood.dart`): the hero subtitle reads the
  live operational state as **one of two** lines off a single needs-attention
  total — calm ("All caught up — nothing needs you right now", grey pulse) vs
  attention ("3 tasks need your attention", warning pulse) — rather than a static
  greeting. The **same** total drives the L1 section, so hero and grid never
  disagree. Derive it from counts you already have; keep it a pure function.
- **A "live" pulse:** a small breathing dot (a slow expanding ring) says the system
  is awake. Its colour is *meaningful* (calm vs attention), never decoration.
- **Depth over colour:** build layering with a **two-layer shadow** (tight contact +
  soft ambient) on `GlassContainer`, not with tint. The eye should know what's near
  and what's background without any new hue.

## Motion

Motion **communicates**, never decorates — animate entrance (`EntranceFade` +
`staggerDelay`), metric changes (`AnimatedCount` count-up, or an `AnimatedSwitcher`
cross-fade for a formatted value like `96%`), hover elevation (`GlassContainer`),
button press-scale, previews, and state changes only. Live feed rows use
`LiveListItem` (keyed reuse ⇒ only a genuinely new row animates in — natural
inserts, settled rows stay put). **Gate every animation on reduced motion**
(`MediaQuery.disableAnimations`) — provide a static fallback, don't just shorten
the duration. `LiveStatusBorder` is reserved for the single most-urgent actionable
signal on a surface — its motion/colours are frozen; don't modify it. **It no
longer runs on Employee Home** — see the border language below.

### The task card border language (Employee Home, [ADR-014](../decisions/ADR-014-task-card-border-language.md))

**The 1px edge *is* the state, and it does not move.** `taskAttentionTone` maps a
status to one soft, desaturated hairline — white (new) · blue `info` (started) ·
amber (in review) · green (approved) · red (missed/rejected) · grey (cancelled).

Exactly one card ever gets more: a `pending` task this viewer has **never
opened**, wrapped in `TaskAttentionSurface` — ambient white bloom (~5.5%), a 3%
bevel highlight over the top 46%, a specular hairline peaking at the top-left,
and one shimmer across **20%–66% of the top edge only, every 9s**. The shimmer
never reaches a corner; that is what stops it reading as an orbit. Opening or
starting the task clears all four in 200ms, permanently.

Two standing rules come out of this and apply beyond task cards:

- **Emphasis means unseen, never status.** Nothing is brighter than its
  neighbours for merely *being* in a state.
- **Nothing on a resting surface animates forever.** Stop the controller when a
  card settles — don't just hide it.
