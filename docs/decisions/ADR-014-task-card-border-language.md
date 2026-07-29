# ADR-014 — The task card's 1px edge is the state; only a new task gets attention

**Status:** Accepted · **Date:** 2026-07-29 · **Scope:** Employee Home

## Context

Task cards shipped with `LiveStatusBorder` — a "living edge" that ran a soft
comet (rounded head, long tail, inner bloom) continuously around the **entire**
rounded-rect border of every actionable card, easing into the corners and
accelerating on the straights. It was deliberate, carefully built, and the
reasoning behind it was that motion is load-bearing: an actionable card should
feel alive.

Two things were wrong with that in practice.

**1. It ran forever, on every actionable card.** A screen showing four open
tasks ran four perpetual orbits. Nothing on the screen was ever still, so
nothing on the screen could be emphasised — continuous motion on *every*
card is the same as continuous motion on none. It also cost a repainting
`CustomPainter` per card for the entire life of the screen.

**2. It encoded status, not urgency.** The orbit's colour was the task's state,
so a task that had been sitting untouched for a week orbited exactly as
insistently as one that arrived thirty seconds ago. The thing an employee
actually needs from a dashboard — *which of these is new to me?* — had no
representation at all.

The owner's read on the replacement was explicit: Apple, not gaming; premium,
not flashy; Wallet / Reminders / Fitness. No rotating borders, no neon, no RGB,
no heavy shadows. "So subtle that users almost don't notice it consciously."

## Decision

**The 1px border *is* the state, and it does not move.** One soft, desaturated
hairline per status — white (new), blue (started), amber (in review), green
(approved), red (missed / rejected), grey (cancelled). Nothing animates.

**Exactly one card ever gets more than that: a `pending` task this viewer has
never opened.** It receives four layers, three of them completely static:

1. **Ambient light** — white bloom at ~5.5%, blur 26. Not a glow.
2. **Bevel highlight** — white at 3% falling to nothing over the top 46%.
3. **Specular edge** — the hairline varies along its length, peaking near the
   top-left. Polished aluminium.
4. **Shimmer** — one pass of light across **20%–66% of the top edge only**, once
   every 9 seconds. It never reaches a corner. That constraint is the decision:
   a highlight that rounds a corner reads as an orbit or a spinner, which is
   exactly the thing being replaced.

**Acknowledgement kills it permanently.** Opening the task or pressing Start
clears all four layers in 200ms — perceptually instant, without the harshness of
a snap — and the card becomes an ordinary pending card. A task never re-arms.

Four boundaries are part of the decision, not implementation detail:

- **Emphasis means unseen, never status.** No other state is ever brighter than
  its neighbours. A started task does not out-shout a new one.
- **Nothing on a resting surface animates forever.** The 9s controller is not
  merely hidden when a card settles — it is stopped. Guarded by test.
- **Seen-state is client-only** (`TaskSeenStore`, a per-uid JSON file mirroring
  `CaseSeenStore`). No schema change, no rules deploy, no server read-receipts.
  A shared device never leaks one user's state to another; file failure degrades
  to in-memory.
- **`AppColors.info` is the fourth and final semantic colour**, used only as a
  low-alpha hairline, never as a fill — so ADR-004 (monochrome) holds.

**Scope: Employee Home only.** `LiveStatusBorder` still runs on My Tasks, the
admin dashboard, and `AttentionTile`. This ADR does not settle those surfaces.

## Consequences

- The employee dashboard has a still resting state for the first time, which is
  what makes a single new task legible at all.
- Two border languages coexist until the remaining surfaces are migrated. That
  is a known, deliberate debt, not an oversight — the owner scoped it this way
  to keep the blast radius small on a UI that is lived-in.
- The treatment is tuned to be missed consciously. **If it becomes noticeable,
  it is wrong** — that is the acceptance criterion, and it can only be judged on
  a real device in real light, not in review.
- Seen-state does not survive a reinstall or move between devices. Accepted: the
  cost of being wrong is one extra shimmer on a task you had already read.

## Supersedes

The "living edge" rationale behind `LiveStatusBorder` on Employee Home — motion
as a persistent property of an actionable card. Retained elsewhere pending a
separate ruling.
