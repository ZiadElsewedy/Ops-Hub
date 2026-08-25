# OpsHub — Auto-Generate Weekly Schedule: Feasibility & Architecture (2026-07-02)

> **Design exploration only — no implementation.** The next major feature
> after beta: one tap turns an empty week into a publishable draft roster.
> This report settles the data model, the engine choice, and the UX shape so
> implementation can start without re-litigating architecture.

---

## 1 · Problem size (this decides everything)

A OpsHub week is **14 slots** (7 days × Morning/Night) per branch, staffed from
a branch roster of realistically **5–25 employees**. That is a *tiny* search
space by scheduling-literature standards (hospital rostering solves thousands
of slots). Every architectural decision below follows from this: **the
smartest possible engine is the simplest one that explains itself.**

## 2 · Scheduling inputs (new data, minimal schema)

| Input | Where it lives | Shape | Notes |
|---|---|---|---|
| Days off (recurring) | `users/{uid}.scheduling.daysOff` | `['friday', …]` | Weekly pattern, e.g. student works weekends only |
| Shift preference | `users/{uid}.scheduling.preferredShift` | `morning\|night\|null` | Soft preference, never a guarantee |
| Max shifts / week | `users/{uid}.scheduling.maxShiftsPerWeek` | `int?` (null = branch default) | Hard cap |
| Vacations / time off | `timeOff/{id}` collection | `{uid, branchId, from, to, status}` | Dated ranges; needs a small request→manager-approve flow (reuses the swap-workflow pattern). **V1 can ship without it** (manager just knows) |
| Role requirements | `branches/{id}.staffingTemplate` | per (day, shift): `{min, positions: {Cashier: 1, Supervisor: 1}}` | See §5 — generator input, NOT a grid overlay |
| Rest / position rules | `branches/{id}.swapPolicy` | **exists** | `minRestHours`, `restrictToSamePosition` reused as-is |
| Fairness baseline | prior weeks' `weekly_schedules` | **exists** | Read 2–4 past weeks to balance who got what |

One new map on the user doc (admin/manager-editable, frozen on self-update
like the other privileged fields), one optional template map on the branch
doc, and (later) one small `timeOff` collection. **No new infrastructure.**

## 3 · Engine evaluation

| Option | Verdict | Why |
|---|---|---|
| **Constraint solver** (CP-SAT / OR-Tools via FFI or a cloud service) | ❌ Rejected | Industrial machinery for a 14-slot problem; heavyweight dependency or a server round-trip; produces answers that can't explain themselves; violates the lean ruling |
| **Rule engine** (declarative rules + inference) | ❌ Rejected | Indirection without payoff — the rules ARE code either way; a DSL is a second language to maintain |
| **Greedy weighted scoring + repair passes** (pure Dart) | ✅ **Chosen** | Milliseconds on-device, fully deterministic + seedable, every assignment carries its reasons, unit-testable like `move_validation.dart`, zero dependencies |

### Chosen algorithm (greedy + repair)

```
ScheduleGeneratorService.generate(GeneratorInput) → GeneratorResult

1. Order slots most-constrained-first (fewest eligible candidates first —
   classic MRV heuristic; prevents painting into corners).
2. For each slot, score every eligible candidate:
     eligible  = passes ALL hard constraints
     score     = Σ weighted soft constraints
3. Assign the top scorer; track per-person running load.
4. Repair pass: try pairwise trades that strictly improve the global
   fairness/preference score (bounded, e.g. ≤50 attempts).
5. Emit the draft + per-assignment reasons + unfilled-slot explanations.
```

**Hard constraints** (a candidate is out, with the reason recorded):
day off · approved time off · already on the day's other shift
(double-booking) · `maxShiftsPerWeek` reached · `minRestHours` violated ·
position requirement unmet. **These reuse the exact semantics of
`MoveValidation`/`SwapValidation`** — the generator can never produce a
roster the manual tools would flag.

**Soft constraints** (weighted, tunable constants — not user-facing knobs in
v1): shift preference match (+3) · fairness — distance from the branch-mean
shift count (−2 per shift above) · weekend equity across recent weeks (−2) ·
consistency — same slot as last week (+1, people like routine) · spread —
avoid 6 consecutive days (−3).

**Output is a DRAFT, never a write:**

```dart
class GeneratorResult {
  final WeeklyScheduleEntity draft;        // in-memory only
  final Map<SlotKey, List<AssignmentReason>> reasons;
  final List<UnfilledSlot> unfilled;       // slot + which constraint starved it
  final GeneratorStats stats;              // per-person counts, fairness delta
}
```

## 4 · UX shape (reuses Schedule 4.0 wholesale)

1. Empty week → the existing `OpsHubEmptyState` gains a second action:
   **"Generate draft"** (next to Create Schedule).
2. The grid renders the draft in a **review mode** — a quiet "DRAFT — not
   published" banner; chips carry a small ✨ marker; tapping a chip's reason
   shows *why* ("preferred morning · 3rd shift this week").
3. The manager **edits the draft with the existing tools** — drag-move,
   switch, action sheet, undo, validation all work unchanged because the
   draft is a `WeeklyScheduleEntity` like any other.
4. **Publish** writes the schedule (one `createSchedule` + batched assigns,
   or a single doc `set` — implementation detail); **Discard** throws the
   draft away. Nothing touches Firestore until Publish.
5. Unfilled slots stay visibly open with their explanation — the generator
   states facts and leaves judgment to the manager (consistent with the
   facts-not-quotas ruling).

**Client-side, not a Cloud Function**: generation is instant at this scale,
needs no privileged data beyond what the manager already reads, and the
human-review step means there's no unattended server run to schedule.

## 5 · Product-ruling reconciliation (staffing template vs. "no quotas")

The owner has rejected quota/coverage-% **framing in the monitoring UI**
(settled, twice). A generator, however, literally cannot run without a
target ("how many people should Monday morning have?"). Resolution:

- `staffingTemplate` is a **generator input**, edited inside the branch form
  (like `swapPolicy`), defaulting to `min: 1` everywhere.
- It **never** renders on the schedule grid, the insight strip, or any
  monitoring surface — no bars, no percentages, no "understaffed" badges.
  The grid stays facts-only exactly as today.

## 6 · Phased implementation plan (post-beta)

| Phase | Scope | Est. |
|---|---|---|
| **A — inputs** | `scheduling` map on users + admin/manager availability editor (Edit-Info-sheet pattern); `staffingTemplate` section in the branch form; rules update (freeze on self-update) | ~1 day |
| **B — engine** | `ScheduleGeneratorService` + `GeneratorResult` in `features/schedule/domain/` (pure Dart) + exhaustive unit tests (the whole engine is testable without Firebase) | ~1.5 days |
| **C — draft UX** | Generate-draft entry, review-mode grid, reasons popover, Publish/Discard | ~1.5 days |
| **D — later** | `timeOff` request/approval flow; weight tuning from real usage; multi-week generation | post-v1 |

**Feasibility verdict: HIGH.** No new dependencies, no server work, no schema
migration risk (all new fields are additive with permissive defaults), and
the hard-constraint layer is already written and battle-tested as
`MoveValidation`/`SwapValidation`. The main open product question for the
owner is §5 (confirm the staffing template as a hidden generator input) and
whether v1 needs `timeOff` or ships with recurring days-off only.
