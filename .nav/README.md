# 🛰️ ATLAS — the OpsHub Developer Operating System

> **This is not documentation. It is a navigation system.**
> Documentation explains the project. ATLAS tells you *where to go* and *what will break*.
> Optimized for instant lookup by humans **and** AI agents (Claude, Cursor, ChatGPT).

**Product:** OpsHub — role-based Operations Management System (Flutter + Firebase + one external NestJS chat API).
Dart package id is `opshub`; the project folder is `Drop-operations`, and the user-facing
product name is **OpsHub**.

---

## 🚦 START HERE — pick your entry by intent

| I am… | Open this |
|---|---|
| **An AI agent** told to change something | [`08_AI_PROTOCOL.md`](08_AI_PROTOCOL.md) — the 10-question fast path, then jump |
| Looking for **"where do I edit X?"** | [`04_EDIT_IF.md`](04_EDIT_IF.md) — the "What do I edit if I want to…" maps |
| Trying to understand **one feature** | [`features/<name>.md`](features/) — the per-feature location cards |
| Following a **user action → backend** | [`02_ENTRYPOINTS.md`](02_ENTRYPOINTS.md) — every route → screen → cubit → repo → collection |
| Touching **Firestore / rules / Functions** | [`03_DATA_MAP.md`](03_DATA_MAP.md) — collections ↔ features ↔ rules ↔ functions |
| **Afraid of breaking something** | [`05_DANGER.md`](05_DANGER.md) — invariants, source-of-truth registry, do-not-touch |
| Holding a file and asking **"why does this exist?"** | [`06_REVERSE.md`](06_REVERSE.md) — reverse navigation |
| **Adding** a feature / field / usecase | [`07_PATTERNS.md`](07_PATTERNS.md) — the universal anatomy + copy-paste recipes |
| Wanting the **whole map at a glance** | [`01_ATLAS.md`](01_ATLAS.md) — the world map |
| A **program** that needs structured data | [`atlas.index.json`](atlas.index.json) — machine-readable index |

---

## 🗺️ The one mental model you need

Every feature is the **same shape** — a vertical slice of Clean Architecture:

```
lib/features/<feature>/
├── presentation/   ← WHAT THE USER TOUCHES   pages · cubit (state) · widgets
├── domain/         ← THE RULES (pure Dart)    entities · usecases · repository *contracts*
└── data/           ← THE WIRING               models(json) · repository *impl* · datasources
```

Data flows **down** through the layers and **back up** as state. Cross a layer boundary and you must
cross it through the seam (usecase → repository contract), never around it. Learn this shape once and
you can navigate all 18 features. The full recipe is in [`07_PATTERNS.md`](07_PATTERNS.md).

**Three files rule the whole app — memorize them:**
| Concern | Single source of truth |
|---|---|
| Dependency wiring | `lib/core/di/injection.dart` — `AppDependencies` (hand-rolled static locator, **not** GetIt) |
| Navigation + auth gate | `lib/core/routes/app_router.dart` + `route_names.dart` |
| Backend security | `firestore.rules` · `storage.rules` · `functions/index.js` |

---

## 🧭 How ATLAS is built (so you can trust & maintain it)

- **Mechanical facts are generated, not typed.** File inventories, route tables, collection/function/test
  associations in every `features/*.md` and in `atlas.index.json` come from
  [`gen_atlas.py`](gen_atlas.py), which scans the real code. They cannot drift silently.
- **Judgment is hand-authored.** Purpose / danger / extension sections live *below* the
  `HAND-AUTHORED INTELLIGENCE` marker in each card and in the `0X_*.md` maps.
- **Regenerate after structural changes:**
  ```bash
  python3 .nav/gen_atlas.py
  ```
  Run it whenever you add/rename a feature, route, collection, or Cloud Function. It **preserves the
  generated top half and only that** — hand-authored intelligence you must re-merge if the layout moved.

> ⚖️ **Golden rule of this repo:** *Code wins over docs.* ATLAS points you at the code fast; the code is
> still the truth. If ATLAS and the code disagree, the code is right and ATLAS is stale — fix ATLAS.

---

## 📐 Legend (used everywhere in ATLAS)

| Symbol | Meaning |
|---|---|
| 📍 | A location card / where-to-go |
| 🧠 | Source of truth — the canonical owner of a fact |
| ⚠️ | Dangerous area — read before editing |
| 🚫 | Do NOT edit / generated / frozen |
| 🧩 | Extension point — designed to be added to |
| 🔗 | Cross-reference to another feature/file |
| 🖥️ | Server-authoritative (Cloud Function owns the write) |
| ↕️ | Realtime stream (Firestore snapshots / socket) |

---

*ATLAS covers 18 feature slices, 27 Firestore collections, 23 Cloud Functions, ~50 routes, 161 test files.*
*Generated index: [`atlas.index.json`](atlas.index.json). Last structural scan by `gen_atlas.py`.*
