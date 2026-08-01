# ADR-018 — An employee may always record real work; the roster decides whether it counts

**Status:** Accepted · **Date:** 2026-07-31

**Amends:** [ATTENDANCE_SPEC.md](../design/ATTENDANCE_SPEC.md) §9 ("Deleted
schedule") and the clock-in eligibility half of R1. Everything else in the locked
spec — the state machine, the minute math, R2–R20, the decision log — is
untouched and still wins on behaviour.

## Context

The locked spec refuses a clock-in with no rostered shift: *"a new clock-in
without a shift is refused (no unscheduled by default)"* (§9). The client
implements it — `attendance_screen.dart` resolves `_Phase.noShift` and offers no
action — and `AttendanceValidation.checkClockIn` blocks with `noActiveShift`.

Three facts make that ruling look less like a decision than an unfinished edge.

**The rest of the system already expects unscheduled work.** `AttendanceConfig`
carries `allowUnscheduledClockIn` (defaulted `false`, never set anywhere).
`AttendanceLedgerRow` carries `isUnscheduledWork`, and every reporting aggregate
already excludes it from expected/present/absent counts.
`AttendanceExceptionCode.unscheduledWork` exists and is classified. R7's
16-hour max-session cap exists *specifically* to close a session with no
scheduled end — a session only an unscheduled clock-in can create. Every layer
contemplates this except the one that would produce it.

**The wording is a deferral, not a ruling.** "No unscheduled *by default*" names
a default, and a flag already exists to change it. The Decision Log (D1–D10) does
not argue the case anywhere.

**The workaround produces worse data than the thing it replaces.** When someone
covers a sick colleague on a stale roster, today's path is manager **Add record**
(workflow 13). That record is a *reconstruction*: times typed from memory or from
what the employee said, with no location evidence and no server timestamp at the
moment of presence. An unscheduled clock-in is a *live punch* — server-timestamped
(R18) and GPS-verified (R20's sibling gate on clock-in).

Retail rosters are stale daily; that is the normal condition, not the edge case.
At scale, a blocked punch does not prevent the work — it prevents the record, and
pushes the truth off-system.

## Decision

**Capture permissively; classify afterwards; let a human decide.**

An employee with no rostered shift may start an **unscheduled shift**. It is
recorded immediately and counts in nothing until a manager approves it.

Five constraints, all binding:

1. **Deliberate, never accidental.** The no-shift state offers a *secondary*
   action ("Start an unscheduled shift"). The primary button is never an
   unscheduled clock-in. Opening the app on a day off must not be able to
   produce a shift.
2. **A reason is mandatory at clock-in.** It is what makes the shift approvable
   later, and what deters casual use.
3. **The GPS gate applies in full**, identical to a scheduled clock-in. When the
   roster does not vouch for someone, location is the only remaining proof of
   presence. A branch with no geofence still refuses (unchanged).
4. **It surfaces in Daily Review** as its own item: approve, or reject with a
   reason.
5. **It counts in nothing until approved.** Not in hours, not in the expected
   denominator, not in any export. `isUnscheduledWork` already enforces this in
   the aggregates; that exclusion is now a permanent invariant with a test.

`AttendanceConfig.allowUnscheduledClockIn` **defaults to `true`.** The flag stays
so a branch can switch the behaviour off, but the product's default is now
permissive.

Unchanged by this ADR: worked minutes for an unscheduled shift are measured from
the real clock-in (there is no scheduled start to clamp to, so R2 does not
apply); lateness is not computed (nothing to be late for); and the session closes
under R7's 16-hour cap rather than R6's scheduled-end grace.

## Consequences

- **The engine's honesty guarantee completes.** No screen can now stop someone
  recording work they actually did. This is Principle 2 (no dead ends) applied to
  the one case that still had one.
- **Reporting gets *more* accurate, not less.** Work that previously entered the
  system as a manager's reconstruction now arrives as evidence. The category
  becomes visible instead of being papered over.
- **The denominator gets more complicated, permanently.** Expected shifts come
  from the roster; unscheduled work sits outside it until approved. Every future
  report must keep respecting `isUnscheduledWork`. This was already true and
  dormant; it is now load-bearing, and is guarded by a test.
- **A new abuse surface exists.** GPS proves presence, not authorisation, so an
  employee could in principle manufacture hours. Mitigated by the mandatory
  reason, the GPS gate, and approval-before-counting. **If unscheduled punches
  are ever created faster than managers reject them, that is the signal to
  reverse this ADR**, not to add more gates.
- **It is less useful than it looks until the Functions deploy lands.** An
  unapproved unscheduled shift sits unresolved, which is honest but inert (T3).
- **`ATTENDANCE_SPEC` §9's "Deleted schedule" row is amended**: a clock-in with
  no shift is accepted as unscheduled work, not refused. The record's config
  snapshot (R19) still protects a closed shift from later roster edits.

## Alternatives considered

- **Keep the gate.** Rejected. It makes the app the obstacle in the one situation
  where the employee is demonstrably doing the right thing — showing up — and it
  degrades the record by forcing the work through a reconstruction.
- **Allow it with no approval.** Rejected outright. GPS proves presence, not
  authorisation. Recorded immediately, counted only after approval, is the
  correct split.
- **Require a manager to pre-authorise before the punch.** Rejected: it needs a
  manager reachable at that exact moment, which fails the precise scenario that
  motivates the change — short-notice cover with no manager on the floor.
- **Leave the flag and let each branch opt in.** Rejected as the *default*. A
  safety-relevant default that every branch must discover and enable is a default
  that stays off. The flag survives for the branch that genuinely wants the
  stricter behaviour.
