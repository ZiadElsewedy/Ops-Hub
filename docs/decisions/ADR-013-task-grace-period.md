# ADR-013 — A fixed 30-minute grace period before a task is Missed

**Status:** Accepted · **Date:** 2026-07-28

## Context

[AUTOMATED_TASKS_PRODUCT_SPEC](../design/AUTOMATED_TASKS_PRODUCT_SPEC.md) §12.1
shipped V1 with **zero grace**: a generated shift task unfinished at the exact
shift end became Missed. That was recorded as a conscious simplification, with
one known cost — "an employee finishing minutes after shift end is recorded
Missed while the store is open" — and one explicit trigger to revisit: **before
Missed carries weight in performance data**. §10.2 turned that into a hard gate
on wiring Missed into branch scorecards, which is exactly what spec Phase 3 does.

So the question had to be answered now. Three facts decided it.

**1. Zero grace was never actually zero.** `autoEndRecurringShiftTasks` runs on a
15-minute schedule. A task submitted at 16:32 against a 16:30 shift end survived
or died depending on where the cron tick happened to fall. The shipped rule was
not "strict" — it was a **random tolerance of up to one sweep interval**, and two
employees finishing at the same minute could get opposite records. We were not
choosing whether to have grace. We were choosing whether the grace we already had
was deliberate and visible, or arbitrary and invisible.

**2. The failure mode was morally inverted.** Under zero grace, the employee who
stayed until 16:35 to finish and the employee who walked away at 16:00 receive
the **identical** record. Identical outcomes for opposite behaviour is the most
corrosive property a metric can have, and it teaches staff not to bother
finishing — the reverse of what the business wants.

**3. The store is not empty at shift end.** Morning runs 08:30–16:30 while the
night shift starts 15:00 (weekday) or 16:00 (operational weekend). At the moment
a morning task "expires," the next crew has been on the floor for 30–90 minutes.
Work completed just after shift end is genuinely completed work, not a fiction.

Business constraints as stated by the owner: **Egypt only, a single timezone,
stores never close.**

## Decision

**A fixed, global grace period of 30 minutes.** A shift task is evaluated for
Missed 30 minutes after its resolved shift end, not at the shift end.

With four boundaries that are part of the decision, not implementation detail:

- **Grace is a tolerance on the close, not a new deadline.** The task's due time
  is unchanged; schedule, reminders and sort order do not move.
- **Late still fires at the original deadline.** The task reads Late from shift
  end (spec §3.1), so urgency is visible immediately; the employee is simply not
  *recorded as failed* until the tolerance expires. Still no notification on Late.
- **30 minutes exactly, everywhere** — not per branch, not per template, not per
  shift, not admin-editable. Changing it is a product decision with an ADR.
- **No "Completed Late" state.** Lateness is *measured* from timestamps we
  already store (§10.4), never *stated* as a fourth outcome.

### Why 30

Three constraints pin the number down. It must **exceed the sweep interval** (15
min), or the cron cadence remains the de facto rule. It must cover a realistic
"finishing up, taking the proof photo, submitting" tail. And it must be far too
short to absorb another shift's work. 30 puts the morning cutoff at 17:00, by
which point the night crew has been present at least half an hour, and it is
nowhere near the next daily occurrence, so a day's instance never bleeds into the
next.

## Alternatives rejected

**Configurable grace (per branch or per template).** Rejected as the worst
option, not merely a worse one. The completion rate's entire claim (§10.1) is
that it is *ungameable*; a per-branch grace is a dial that moves the headline KPI
held by the person the KPI evaluates, and it makes two branches' rates stop
measuring the same thing — removing the only reason to have a branch scorecard.
It also drags in a settings surface, a permissions question and an audit
question, which is the enterprise shape
[ADR-010](ADR-010-lean-over-enterprise.md) exists to refuse. The estate is a
handful of branches and roughly ten people; there is no scale problem that
per-branch tuning solves. The variation that genuinely exists here — seasonal
trading hours, notably Ramadan — is already expressed in **shift hours**, which
are per-week configurable data, and a grace measured in minutes-after-shift-end
follows them automatically.

**A "Completed Late" workflow instead of immediate Missed.** Rejected on two
structural grounds. It **still needs a cutoff** — without one, Missed never fires
and the silent-failure gap closed in spec Phase 2 re-opens — so it is grace *plus*
a fourth outcome, not an alternative to grace. And the extra state encodes
information already held as timestamps (`deadline`, `submittedAt`, `approvedAt`),
while reversing the deliberate §3.1/§11.2 ruling that Late is a derived visual
and never a workflow state. It also has no good answer to "does a Completed-Late
task count in the completion-rate numerator?": yes makes the state decorative, no
invents a punishment harsher than having no grace at all.

**Keeping zero grace.** Rejected because it is not the rule we actually run (see
Context), and shipping a performance metric whose outcome depends on cron timing
is indefensible. It would also push managers to use the §6.4 admin terminal
correction routinely, degrading a deliberately narrow safety valve into a daily
workflow.

## Consequences

- The gate in spec §10.2 is **cleared**; Missed may now carry weight on branch
  scorecards, which unblocks spec Phase 3.
- **Completion rates computed after this change are not comparable to figures
  from before it.** Treat the switchover as a baseline reset, not an
  improvement. Any trend line spanning it is meaningless.
- The cliff moves; it does not disappear. A task finished at grace + 1 minute is
  still Missed, and that is accepted.
- A genuinely-missed task is flagged up to 30 minutes later than before. Given
  the sweep already granted up to 15 minutes of accidental delay, the real change
  in detection latency is smaller than the number suggests.
- One edge to keep in view: the operational-weekend night shift ends at 00:00, so
  its grace expires at 00:30 — in the next calendar day. The window model already
  supports end-of-day overrun and `instanceDate` is persisted; the later
  business-day key ruling is [ADR-015](ADR-015-automation-business-timezone.md).

## Supersedes

The zero-grace position previously held open in
[AUTOMATED_TASKS_PRODUCT_SPEC](../design/AUTOMATED_TASKS_PRODUCT_SPEC.md) §12.1.
That item is now closed, and grace is removed from the V2/V3 candidate list —
it is not an open question to re-litigate.
