# 🤖 08 · AI AGENT OPERATING PROTOCOL

You are an AI agent (Claude / Cursor / ChatGPT) about to work in this repo. **Do not explore blindly.**
This file is your fast path from a request to the right ~3 files.

## ⚡ The loop (do this every task)

```
1. CLASSIFY the request  → bug | polish | refactor | feature   +   risk: LOW | MED | HIGH   (state both)
2. LOCATE   → use the decision tree below to reach a feature card or a core file
3. READ     → open only: the feature card + the 2–3 files it names + the relevant DANGER entries
4. VERIFY   → confirm the code matches the card (code wins over docs; if stale, fix the card)
5. EDIT     → follow the 04_EDIT_IF recipe; respect 05_DANGER invariants
6. TEST     → build_runner if freezed changed; flutter analyze/test; firestore-tests if rules changed
7. SYNC     → update PROJECT_CONTEXT/CURRENT_STATE/CHANGELOG if behavior changed; run python3 .nav/gen_atlas.py if structure changed
```

## 🌳 Locator decision tree

```
Is it about NAVIGATION / who-can-see-a-screen / login flow?
    └► core/routes/app_router.dart (+ route_names.dart)         [02_ENTRYPOINTS, 04 §auth]
Is it about DATA SHAPE / a Firestore field / security?
    └► the collection row in 03_DATA_MAP → model + entity + firestore.rules
Is it about WIRING / "where is X constructed"?
    └► core/di/injection.dart (AppDependencies)
Is it SERVER logic / a trigger / push / cron?
    └► functions/index.js (+ 3 sibling files)                   [03_DATA_MAP catalogue]
Is it a UI card / screen / widget?
    └► features/<F>/presentation/  (find <F> via 01_ATLAS grid)
Is it a business rule / an "action"?
    └► features/<F>/domain/usecases/  (+ the repository)
Otherwise → open the matching features/<F>.md card and follow its links.
```

## 🔟 The 10 questions → where each is answered instantly

| Question | Answer source |
|---|---|
| Where should I modify this? | [`04_EDIT_IF.md`](04_EDIT_IF.md) → recipe; or the card's "Common modifications" |
| Which files own this feature? | `features/<F>.md` → **Owner files (by layer)** |
| What will break if I change this? | [`05_DANGER.md`](05_DANGER.md) + the card's **Dangerous areas** |
| What depends on this? | [`06_REVERSE.md`](06_REVERSE.md) universal grep protocol |
| Where is the entry point? | [`02_ENTRYPOINTS.md`](02_ENTRYPOINTS.md) route→screen table |
| Which layer is responsible? | [`07_PATTERNS.md`](07_PATTERNS.md) — folder = layer |
| Which files should I never modify? | [`05_DANGER.md`](05_DANGER.md) → do-NOT-edit table |
| Which file is the source of truth? | [`05_DANGER.md`](05_DANGER.md) → source-of-truth registry |
| How does data flow here? | `features/<F>.md` → data-flow diagram + [`07_PATTERNS.md`](07_PATTERNS.md) call chain |
| If I want X, where do I start? | [`04_EDIT_IF.md`](04_EDIT_IF.md) |

## 📐 Hard constraints you must not violate (product-owner rulings)

- **Firestore optional default = `null`, never `''`** (broke prod). Rule changes → add a `firestore-tests/` case.
- **Server-authoritative writes** (ADR-005): don't move 🖥️ logic to the client.
- **`_redirect` stays pure & sync** — never `await`.
- **Cubit-only** state (ADR-002). **Clean-architecture layering** (ADR-003) — don't shortcut a layer.
- **Monochrome** design (ADR-004) — colour only for destructive. Task-card border language is ADR-014, owner-signed.
- **Lean, not enterprise** (ADR-010): default to deletion; don't add analytics pipelines (ADR-009), abstractions, or
  "Jira/Slack/Linear" features. Product = premium lean **internal ops tool**.
- **Chat ≠ Firebase**: it's the NestJS API + Drift; never cache image bytes; REST=truth, socket=delivery.
- **Guard debated UX**: if a UI looks intentional/polished, confirm before "simplifying". "Work on it more" = enrich.
- Never `edit *.freezed.dart` / `*.g.dart` / `firebase_options.dart` — regenerate.

## 🧾 Deliverable etiquette (this repo's convention)
- Reference files as clickable `path:line`.
- Before finishing: run the doc self-check (PROJECT_CONTEXT §5) and update docs that went stale — **don't ask, just do it** (SessionStart protocol).
- Keep ATLAS honest: if you moved structure, `python3 .nav/gen_atlas.py`; if you changed a truth, edit the hand-authored section.

## 🧠 Minimum context to load for a typical task (token-efficient)
```
.nav/08_AI_PROTOCOL.md   (this)          ~ orientation
.nav/features/<F>.md     (the one feature) ~ the map
+ the 2–3 real files the card names
+ the relevant 05_DANGER rows
```
That is enough to act. You should almost never need to `grep -r` the whole repo — the card already did.
