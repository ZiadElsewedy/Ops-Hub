# ADR-016 — A task is visible when upcoming, startable only from `startsAt`

**Status:** Accepted · **Date:** 2026-07-30 · **Scope:** Task lifecycle (all surfaces + rules)

## Context

Generated tasks appear the moment the automation creates them, and that is
deliberate: an employee should see the shift's work coming rather than have it
materialise under them when the shift opens. [ADR-015](ADR-015-automation-business-timezone.md)
pins that creation to 01:00 Africa/Cairo, so a morning task now exists roughly
seven hours before anyone is meant to touch it.

The problem was that **visibility was indistinguishable from availability**. A
task created at 01:00 for an 08:30 shift could be started at 01:05 — the Start
control was unconditionally live on both surfaces that offer it, `TaskCubit.startTask`
accepted `pending → started` at any hour, and `firestore.rules` had no notion of
a start time at all. Nothing anywhere in the stack knew that a task's window had
not opened yet.

The two obvious fixes were both wrong. Hiding upcoming tasks would throw away
the visibility that makes the early generation worth doing. Hiding just the
*button* reads, to the person holding the phone, as a bug or a permissions
problem — it answers none of the question they actually have, which is *when can
I start this?*

## Decision

**A task is visible when upcoming, and startable only from `startsAt`.**

The gate is keyed on the **destination status**: every transition into `started`
passes it, expressed as one condition rather than a set of per-source clauses.
Consequently there are **no exceptions — rework (`rejected → started`) is gated
exactly like a first start (`pending → started`)**. A null `startsAt` means
always startable, which is what keeps manual and legacy tasks working. The
boundary is inclusive: at exactly `startsAt`, starting is allowed.

It is enforced in **three places that must never disagree**:

1. the pure predicate `canStartTaskNow` / `startBlockedReason` in
   `lib/features/task/domain/task_schedule.dart`;
2. `TaskCubit.startTask`, which refuses before writing — the guard that catches
   every caller, including any surface added later;
3. `firestore.rules`, on the employee/assignee branch of `tasks/{taskId}`,
   re-checking the same boundary against `request.time`.

**The control stays visible and disabled, and says when it opens** — "Starts at
08:30", in 24-hour form to match the shift window (`08:30 – 16:30`) rendered
beside it. It enables itself when the time arrives via a one-shot timer, with no
refresh and no interaction.

The owner's framing, which is the reason this is an ADR and not a code comment:
*"Consistency is more important than special-case behavior."*

## Consequences

- **If a manager moves a task's `startsAt` into the future, the task is blocked
  until then — including a task already in rework.** This is intended, not an
  oversight. It is the price of a rule with no special cases, and it was accepted
  explicitly in exchange for one uniform, auditable boundary.
- **Client and server read different clocks.** The client gates on device time;
  the rules gate on server `request.time`. A device running ahead can present an
  enabled button whose write the server then refuses, and a device running behind
  keeps the button disabled slightly too long. The server is always the
  authority. The refusal must reach the employee as a comprehensible message, not
  a raw permission error — if that ever regresses, this is the paragraph that
  says it was a known, handled case.
- Managers and admins keep their existing powers; the gate lives on the employee
  branch that actually performs a start.
- Enforcement is inert until `firestore:rules` is deployed. Until then the gate
  is client-side only.

## Non-goals

This changes **nothing** about the rest of the lifecycle:

- **Late / Overdue** stays derived from `deadline` (spec §3.1) — an upcoming task
  is Scheduled, never Overdue, and that was already true before this ADR.
- **The Missed sweep and the fixed 30-minute grace**
  ([ADR-013](ADR-013-task-grace-period.md)) are untouched. A task that is never
  started still becomes Missed after its deadline + grace. This gate is about the
  *start* boundary only, and the two must not be conflated.
- No new visual language: the disabled state reuses the muted footer idiom that
  already carries "Missed — task closed" and "Awaiting review".
