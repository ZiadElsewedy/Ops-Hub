# ADR-020 — The location policy governs the punch, and a branch with no geofence is a time clock

**Status:** Accepted · **Date:** 2026-08-01

**Amends:** [ATTENDANCE_SPEC.md](../design/ATTENDANCE_SPEC.md) workflow 6 (the GPS
gate) and the "branch not geofenced" clock-in error in §UI. The state machine, the
minute math, R1–R20 and every other decision in the locked spec are untouched and
still win on behaviour. **R19 still holds:** the policy resolved at the moment of
the punch is the one that governs that record; later edits never rewrite history.

## Context

`AttendanceLocationPolicy` has existed since the module shipped, with three cases
— `none` (no location captured), `soft` (capture and warn), `strict` (capture and
block) — a `blocksOutside` helper, a `capturesLocation` helper, a `fromString`
parser, and a doc comment calling itself *"the single knob for the whole geofence
behaviour."* It is stored on `AttendanceConfig`.

**Nothing read it.** Not the client gate, not `functions/`, not `firestore.rules`.
A grep found it only in its own declaration and in the config that holds it. The
knob was a comment.

What ran instead was hardcoded, in two places that could not disagree because
neither consulted anything:

- `AttendanceValidation.checkGpsFix` rejected `noGeofence` / `lowAccuracy` /
  `outsideRadius` unconditionally.
- `attendance_screen.dart` disabled Clock In unless `geofenceReady && atBranch`.

So every branch behaved as `strict`, while the config's default said `none`. The
two have been in silent contradiction the whole time, and the config lost.

The expensive part is not the dead enum. It is what `strict` means at a branch
that has **no geofence configured**: `checkGpsFix` returned `noGeofence`, the
button stayed dead, and **nobody at that branch could ever clock in**. The spec
says this outright in workflow 6 — *"GPS gate fails (off / denied / no geofence /
low accuracy / outside radius). No record is written."* — so the code was
faithful. The rule itself is the defect.

That rule fails on its own terms. `soft` and `strict` both mean *"compare the
device fix to the branch geofence."* With no geofence there is nothing to compare
against, so neither policy is unsatisfied — it is **undefined**. Refusing the
punch treats an unanswerable question as a failed check, and the cost lands on the
employee, who is standing at work and cannot record that they are there. The
recovery paths (missed-punch, manager Add record) all exist, so the work is
eventually recorded — as a reconstruction typed from memory, which is exactly the
worse evidence [ADR-018](ADR-018-unscheduled-clock-in.md) already rejected once.

An admin can draw the fence in Branches → geofence editor. That does not rescue
the rule: a new branch is unconfigured **by default**, so the failure mode is the
starting state of every branch, not an unlucky one.

## Decision

**1. The effective policy governs the punch, and it is resolved, not read raw.**
`AttendanceService.resolveLocationPolicy({configured, hasGeofence})` is the single
seam. `checkGpsFix` takes the resolved policy and branches on it:

| Policy | Location captured | Can refuse a punch |
| --- | --- | --- |
| `none` | no | never |
| `soft` | yes, stored on the record | never |
| `strict` | yes, stored on the record | yes — the full gate, unchanged |

**2. No geofence resolves to `none`.** Not to `strict`, not to an error. A branch
without a fence runs a pure time clock: the punch is server-timestamped (R18) and
carries no coordinates, because there are none worth capturing. When an admin
draws the fence, that branch becomes `strict` with no further action.

**3. The default is `strict`, not `none`.** The old default was a leftover from
when GPS was planned as opt-in and never matched reality. Defaulting to what
actually ships means the config now describes the product instead of contradicting
it, and an un-migrated caller of `checkGpsFix` keeps the gate rather than silently
losing it.

**4. `soft` tells the truth in the UI.** The GPS card still shows every state, but
its copy stops saying *"move closer, then tap to retry"* next to an enabled
button; an unverifiable fix reads *"Recorded with your punch for a manager to
review."* Under `none` the card is not rendered at all — a GPS panel on a branch
that does not use GPS is noise.

## Consequences

**A branch with no geofence can clock in unverified.** This is the trade and it
should be stated plainly: at such a branch, someone can punch from anywhere. That
is a real weakening against a status quo of *perfect* enforcement — but the status
quo was not enforcement, it was **no attendance at all**, plus a stream of
manager-typed reconstructions with no location evidence whatsoever. An unverified
live punch is better evidence than a remembered one, and the fix is one geofence
away. Nothing changes at any branch that has a fence: `strict` behaves exactly as
before, byte for byte.

**One test changed meaning.** `attendance_cubit_test.dart` asserted
*"clockIn when the branch has no geofence is blocked (no write)"*. That test was
correct against the old spec; it now asserts the punch is recorded, unverified.
This is the one place where the reversal is visible as a deliberate rewrite rather
than new coverage.

**`soft` is now reachable but unused.** No branch selects it, because
`AttendanceConfig` is still a constant (`AttendanceService.configFor` returns one
value for everyone). Wiring `branches/{id}/attendanceConfig` remains the open
follow-up; this ADR makes the destination real so that work becomes data entry
rather than another gate rewrite.

**Server-side is unchanged.** `functions/` and `firestore.rules` never enforced a
geofence, so there is nothing to keep in step. A determined client could always
write an unverified punch; the policy is a product rule about the app's behaviour,
not a security boundary — and it should not be mistaken for one.
