# ADR-004 — Strictly monochrome UI; indigo is rejected

**Status:** Accepted · **Date:** 2026-06-14, reaffirmed 2026-06-25, 2026-07-08 and 2026-08-07

> This decision has been reversed and re-reversed more than any other in DROP.
> It is written down so it stops being re-argued. **Read this before proposing a
> brand colour.**
>
> A brand accent (periwinkle indigo) was tried once more on the Branch Sales
> figures on **2026-08-07** and **reverted the same day** — the owner did not like
> it on device. The app is monochrome. Do not reintroduce a chromatic brand accent
> without a new, explicit decision.

## Context

An early iteration introduced indigo `#5B5FEF` as a brand accent for active nav,
primary CTAs, FABs and links. It was reverted. It was proposed again as an "active
glow" on card surfaces and rejected again. Documentation kept describing indigo as
the accent for weeks after it was gone from the code, and agents kept reintroducing
it because the docs told them to.

## Decision

The UI is **strictly monochrome** — black / white / grey, dark mode only.

- `AppColors.primary` is **white** (`0xFFFFFFFF`). It is the *only* accent, and it
  carries every primary action, focus state, active nav tab, and key highlight.
- The **only** chromatic colours are the semantic `success` / `error` / `warning`,
  and they may express **status only** — never brand, never decoration.
- Calm comes from **hierarchy, not reduction**. DROP is premium, not minimal:
  a 4-step grey ramp (`FFFFFF` / `A7A7AF` / `6E6E77` / `48484E`) does the work a
  colour would, and **no two adjacent texts share a grey**.
- Never write raw `Color(...)` or `TextStyle(...)` in a feature. Reference
  `AppColors` / `AppTypography` / `AppSpacing` / `AppRadius`.

## Consequences

- Status reads instantly precisely *because* colour is scarce. Spending colour on
  branding would cost the one signal that matters operationally.
- Motion and elevation carry the affordances a colour accent normally would — see
  `LiveStatusBorder`, whose orbit is load-bearing and must not be "simplified".
- **Cost:** the UI can look austere in a screenshot next to a competitor's. That is
  the intended trade (ADR-010).
- The only permitted references to indigo in the codebase are the comments in
  `app_colors.dart` and `app_glass_card.dart` recording its removal. Keep them —
  they are the tripwire.
