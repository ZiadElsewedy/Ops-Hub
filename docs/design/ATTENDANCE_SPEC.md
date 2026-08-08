# DROP Attendance — Official Product Specification (LOCKED)

> **Status:** Product decisions locked 2026-07-18. This document is the source of
> truth for the Attendance module. Every future implementation follows it. It
> supersedes ambiguity in [ATTENDANCE.md](ATTENDANCE.md) (which remains the
> *engineering* description of the shipped engine); where the two disagree, **this
> document wins on behavior**.
>
> Scope guardrails (unchanged, non-negotiable): **no payroll, no analytics**
> (ADR-009/010). Attendance produces an auditable minute record; consuming it for
> pay or trends is a different, out-of-scope system.

Everything below is filed under one of three headers, never mixed:
**Product Decisions** (how it behaves) · **Technical Constraints** (forced by the
architecture) · **Future Enhancements** (deliberately postponed).

---

## 1. Attendance Philosophy

**Purpose.** Attendance answers one operational question honestly and defensibly:
*who was where, and for how long, against what they were scheduled to do.* It is a
**record of truth for a small team**, not a surveillance tool and not a payroll
engine.

**The five principles, in priority order.** When two conflict, the higher one wins.

1. **Honesty over optimism.** The record reflects what actually happened. Never
   project, never round in the employee's or the company's favor, never show a
   number the system can't defend. Open sessions show live truth, not a guess.
2. **No dead ends (recoverability).** Every real-world event — forgot to punch,
   lost GPS, quit mid-dispute — has exactly one defined path back to a valid,
   settled state. A shift is never permanently lost and never permanently stuck.
3. **Accountability with fairness.** Every change to a record is attributable to a
   person and a reason, server-side. But the employee is never *trapped*: they can
   always end a shift, always contest a record, always see why something was
   marked.
4. **Operational visibility.** A manager opening the app sees what needs a
   decision *now*, above everything else. Actions rank over statistics.
5. **Lean.** The smallest set of states, rules, and screens that satisfies 1–4.
   Every added concept must earn its place against deletion (ADR-010).

---

## 2. Final State Machine

Attendance has **one record per person, per shift, per day** (deterministic id —
Technical Constraint T1). A record moves through the states below. States marked
*virtual* are **computed from the roster + clock, not stored** — they exist only
on the board until a real record materializes.

### Virtual (no document yet)

| State | Description | Entry | Exit | Actions | Who | Notifications | UI |
|---|---|---|---|---|---|---|---|
| **Not Started** | Rostered, shift not yet due (or within grace), no clock-in | Roster has a shift for today; `now < start + lateGrace` | Employee clocks in → **Working**; grace passes → **Late (virtual)**; leave set → **On Leave** | Clock in (employee) | Optional shift reminder (§7 N1) | Employee: enabled Clock-In once inside the lead window; countdown to window otherwise |
| **Late (virtual)** | Rostered, past grace, still no clock-in, shift still running | `start + lateGrace ≤ now ≤ end`, no record | Clocks in → **Working** (late flagged); `now > end` → **Absent (virtual)** | Clock in (employee); Nudge (manager) | Manager "overdue" digest (N4) | Board row red-flagged; employee still sees Clock-In |
| **Absent (virtual)** | Rostered, shift end passed, never clocked in | `now > end`, no record | Manager excuses → **Excused** (materializes); Manager/employee files missed-punch → **Working/Completed** (materializes) | Mark excused; Create record (manager); Missed-punch request (employee) | — | Board row: "Absent" with **Excuse** + **Add record** actions |
| **On Leave** | Schedule marks leave today | `schedule.leaveTypeOf != null`, no record | End of day; or employee clocks in anyway → **Working** (leave yields) | (none required) | — | Board row muted "On leave" |

### Real (document exists)

| State | Description | Entry | Exit | Actions | Who | Notifications | UI |
|---|---|---|---|---|---|---|---|
| **Working** | Clocked in, not out (may be overnight) | Clock-in write succeeds | Clock out → **Completed**; scheduledEnd+grace passes with no out → **Pending Review**; unscheduled + max-session passes → **Pending Review** | Clock out (employee) | "Marked late" toast on entry if late (N2) | Live `HH:MM:SS` timer; Clock-Out button (never GPS-blocked) |
| **Completed** | Clocked out; totals snapshotted | Clock-out write | Correction approved → **Corrected**; admin soft-delete → **Deleted** | File correction (employee); Decide correction (reviewer); Soft-delete (admin) | — | Summary: worked/late/early/overtime, GPS distances |
| **Pending Review** | Auto-closed (never clocked out) or flagged; needs a human | `autoClose` flips open→pendingReview; or manager flags | Correction approved → **Corrected**; manager resolves directly → **Corrected**; excuse → **Excused** | File correction (employee); Resolve directly / Decide (manager) | "Shift needs review" to employee (N3); appears in manager review queue | Board row "Needs review", top priority; employee prompted to file correction |
| **Corrected** | A correction/override was applied; totals recomputed | `onAttendanceCorrectionWritten` applies resolution; or manager manual edit | Terminal (further corrections allowed, loops back through Pending/Completed semantics) | File another correction; Soft-delete (admin) | Approved/Rejected notice to employee (N5/N6) | Summary shows "Adjusted by <name>" + audit timeline |
| **Excused** | An expected shift with no work, officially forgiven | Manager excuses an Absent/Pending record (materializes with `status=excused`, zero minutes, reason) | Terminal; correction may reopen | File correction; Soft-delete | Optional: employee informed | Board/history: "Excused — <reason>" |
| **Deleted** | Admin soft-delete; retained as history, filtered from lists | Admin soft-delete with reason | Terminal (admin reopen restores prior state) | Reopen (admin) | — | Hidden from active lists; visible in audit |

**Removed as a first-class state:** none added beyond the shipped set except the
formal promotion of **Excused** and the materialization rule. Lateness / early /
overtime remain **derived facts, not states** (Technical Constraint T2).

---

## 3. Final Workflows (every path ends in a valid state)

1. **Normal day.** Not Started → (within window) Clock In → Working → Clock Out →
   **Completed**.
2. **Late arrival.** Not Started → Late (virtual) → Clock In (late flagged, "marked
   late" toast) → Working → Clock Out → **Completed** (lateMinutes > 0).
3. **Early arrival.** Not Started shows a countdown until the lead window opens
   (`start − clockInLeadMinutes`). Before the window: Clock-In disabled with "Opens
   at HH:MM". Inside the window: Clock In → Working. **Worked minutes are counted
   from `max(clockIn, scheduledStart)`** — arriving early never inflates worked time
   or creates overtime. → **Completed**.
4. **Forgot clock-in (worked anyway).** Shift becomes Absent (virtual). Recovery,
   two doors, both end valid:
   - Employee files a **Missed-Punch request** (a correction of kind *create*),
     proposing in/out times + reason → reviewer approves → record materializes →
     **Corrected**.
   - Manager uses **Add record** on the Absent row → materializes immediately as a
     manager entry (audited, no approval) → **Corrected**.
5. **Forgot clock-out.** Working → `autoCloseAttendance` at scheduledEnd + grace →
   **Pending Review** + employee nudge. Employee files a correction with the real
   clock-out → approved → **Corrected**. (Or manager resolves directly.)
6. **GPS rejected at clock-in.** *(Amended by [ADR-020](../decisions/ADR-020-location-policy-is-real.md).)*
   The gate runs only under the branch's **effective location policy**
   (`AttendanceService.resolveLocationPolicy`), which is `none` wherever the branch
   has no geofence:
   - **`strict`** (the default for a geofenced branch) — eligibility passed but the
     gate fails (off / denied / low accuracy / outside radius). **No record is
     written.** Employee sees the specific reason and a retry. If genuinely on-site
     but GPS won't cooperate, the shift falls through to the forgot-clock-in
     recovery (workflow 4).
   - **`soft`** — the fix is captured and stored on the record, and **never refuses
     the punch**. An unverifiable or out-of-fence fix is evidence for review.
   - **`none`** — no location is captured and nothing is checked. A branch with **no
     geofence configured** resolves here, so it runs a pure time clock rather than
     being locked out of attendance entirely (the pre-ADR-020 behaviour).

   Clock-**out** is never GPS-blocked under any policy.
7. **Offline.** Clock-in/out queue against the deterministic id (idempotent). UI
   shows *syncing* / *offline*. The live timer runs on the GPS capture time until the
   server timestamp syncs back, then the server time wins. End state identical to
   online.
8. **Overnight shift.** Clock In before midnight → Working (record dated to the
   start day) → Clock Out after midnight → **Completed**. Instant subtraction; no
   special-casing.
9. **Overnight session still open next morning.** If a session from yesterday is
   still open when today's shift is due, the clock UI **targets the open session and
   prompts "You're still clocked in from <shift> — clock out to start today."**
   Clocking out closes yesterday (→ Completed/Pending Review per timing); the button
   then targets today. An open session **never blocks** today (Principle 3) but must
   be resolved before today's clock-in.
10. **Leave.** Schedule marks leave → **On Leave**, no action expected. If the
    employee works anyway, clocking in yields a normal Working record (leave loses to
    a real punch).
11. **Excused absence.** Manager opens an Absent/Pending row → **Excuse** with a
    reason → materializes as **Excused** (zero minutes). Ends valid; visible in
    history with the reason.
12. **Manager intervention (direct resolve).** Any Pending Review row → manager
    **Resolve** with corrected times/outcome + reason → applied immediately (manager
    is the authority; no self-approval problem because it's an override, not a
    request) → **Corrected**.
13. **Manual attendance creation.** Manager **Add record** on an Absent/no-record
    shift → enters in/out + reason → materializes → **Corrected**. Same server apply
    path as an approved correction (upsert).
14. **Correction approval.** Employee files → reviewer approves → server applies the
    client-computed resolution (single calculator) → **Corrected** + employee
    notified.
15. **Correction rejection.** Reviewer rejects with a note → **record untouched**,
    stays in its prior state (Completed / Pending Review) → employee notified.
    Employee may file again (workflow does not dead-end).

---

## 4. Final Business Rules (one answer each)

| # | Question | **Decision** |
|---|---|---|
| R1 | Early clock-in? | **Accepted within the lead window, refused before it.** Clock-in allowed from `scheduledStart − clockInLeadMinutes` (default **15 min**). Earlier → refused with "Opens at HH:MM". |
| R2 | Do early minutes count? | **No.** Worked time counts from `max(clockIn, scheduledStart)`. Early presence is never worked time or overtime. |
| R3 | Late grace? | **5 minutes** (unchanged). Beyond it, lateness is recorded, honestly, and the employee is told. |
| R4 | Clock in / out twice? | **Blocked** (already the case; structurally impossible via deterministic id). |
| R5 | Clock out next day? | **Allowed** (overnight). |
| R6 | Forgot clock-out? | **Auto-close to Pending Review** after `scheduledEnd + autoCloseGrace` (120 min). |
| R7 | Unscheduled open session (no scheduledEnd)? | **Auto-close via a max-session cap** (default **16h**) → Pending Review. No session stays open forever. |
| R8 | Start today while yesterday open? | **Allowed, but yesterday must be closed first.** The UI targets and prompts to close the stale session; it never hard-blocks (workflow 9). |
| R9 | Does an incomplete session block new attendance? | **Never.** |
| R10 | Auto-close open sessions? | **Yes** (R6 + R7). |
| R11 | Managers create attendance directly? | **Yes — manager manual entry and direct resolve apply immediately with audit.** Managers are the branch authority. |
| R12 | Do employees still file requests? | **Yes.** Employee-filed corrections/missed-punch requests **require reviewer approval**. Self-approval is forbidden server-side, and every correction's deterministic `attendanceId` must name the same `userId` as the correction owner; a correction can never target another employee's record. The branch attendance UI mirrors this: on a reviewer's **own** shift row the direct-action buttons are hidden (they'd only fail server-side) and replaced by a notice pointing to the correction path — a manager files for their own record like anyone else, and a *different* reviewer approves it. |
| R13 | Do absent shifts create records? | **No — lazily.** Absent stays virtual until a manager excuses/creates or an employee files a missed-punch. No phantom documents. |
| R14 | Excused absence? | **Yes, a real outcome** (`status=excused`, zero minutes, reason). Materialized only when acted on. |
| R15 | Duplicate corrections? | **No.** At most **one open correction per record**. A new one is blocked while one is pending. |
| R16 | Reminders? | **Minimal.** "Marked late" (on late clock-in), "shift needs review" (auto-close), correction decisions — yes. A pre-shift reminder — **off by default**, opt-in per branch (Future). |
| R17 | Overtime automatic? | **Derived and displayed** past `overtimeGrace` (15 min). Never auto-approved, never fed anywhere (no payroll). |
| R18 | Whose time is authoritative? | **Server timestamps** for clock in/out. Device clock is never trusted for the record. |
| R19 | Which config governs a closed shift? | **The snapshot at the time of the punch** (grace/geofence/window). Later config edits never rewrite history (ADR-006). |
| R20 | GPS at clock-out? | **Recorded best-effort, never blocking.** |

---

## 5. Daily Manager Workflow

**Before shift.** Nothing required. The board shows today's roster as **Not
Started** with expected counts. The manager may glance at coverage. No manual setup.

**During shift.** The board updates against `now`. **Late** and **Absent (virtual)**
rows surface at the top. The manager's only *required* attention is a row that asks
for a decision — everything else is passive. Available actions on a live board:
**Nudge** a late employee, **Add record** / **Excuse** an absent one. Clocking is the
employee's job; the manager never clocks for a present employee.

**After shift.** **Pending Review** rows (forgot-to-clock-out, flagged) rank to the
top. The manager either waits for the employee's correction or **Resolves directly**
with the real times + a reason. Corrections filed by employees appear in one
**review queue** — approve or reject with a note.

**Next morning.** Yesterday should be fully settled. Anything still **Pending
Review** is the first thing shown. The manager clears it (resolve/excuse). Then the
new day's board is clean.

**Never manual:** creating routine records, computing minutes, closing normal
shifts, chasing overnight sessions (auto-close handles them), de-duplicating. The
manager only acts on **exceptions**.

---

## 6. Employee Journey

- **Opening the app.** One attendance surface. It shows today's shift, the state,
  and exactly one primary action.
- **Buttons.** Before the window: a disabled **Clock In** with "Opens at HH:MM".
  Inside the window: **Clock In** (runs the GPS gate). Working: a live timer +
  **Clock Out**. Settled: a **Summary** + **View history**.
- **Clock-in errors (each specific, actionable):** location off / permission denied
  / weak GPS / outside radius / no shift / already done. Never a generic failure.
  The location errors appear **only under `strict`** — under `soft` the same states
  are shown on the GPS card but read as recorded-for-review, and under `none` the
  card is not rendered at all ([ADR-020](../decisions/ADR-020-location-policy-is-real.md)).
  *"Branch not geofenced" is no longer a clock-in error*: that branch resolves to
  `none` and clocks in normally.
- **Feedback that used to be silent, now explicit:** clocking in late shows a
  "You're marked late" acknowledgement. This prevents disputes.
- **Forgot to punch.** The Absent state offers **"I worked but forgot to clock in"**
  → a missed-punch request (times + reason) → pending a manager.
- **Forgot to clock out.** Employee gets a "shift needs review" nudge and files a
  correction with the real time.
- **History.** The employee sees their own ledger: each shift, its outcome, GPS
  distances, and — once functions are deployed — the server audit timeline showing
  *who* changed *what* and *why*.
- **Corrections/requests.** File against a settled or pending record; one open at a
  time; see approved/rejected with the reviewer's note; may refile if rejected.
- **Guarantee:** the employee can **always end a shift** and **always contest a
  record**. No screen traps them.

---

## 7. Notification Strategy

| ID | Trigger | Recipient | Purpose | Priority | Default |
|---|---|---|---|---|---|
| N1 | Shift start approaching | Employee | Reminder to clock in | Low | **Off** (opt-in) |
| N2 | Clocked in after grace | Employee (in-app toast) | Acknowledge lateness, prevent disputes | Low | On |
| N3 | Session auto-closed | Employee | Prompt to file real clock-out | **High** | On |
| N4 | Employee overdue / absent | Branch manager | Flag a coverage gap needing action | Medium | On |
| N5 | Correction approved | Employee | Close the loop | Medium | On |
| N6 | Correction rejected | Employee | Explain + allow refile | Medium | On |
| N7 | Correction filed | Reviewers (branch mgr + admins) | New item in review queue | Medium | On |

**Deliberately absent** (noise): per-clock-in confirmations to managers, "employee
clocked out" pings, daily summaries, streaks. N4 is a **digest**, not one push per
late person.

---

## 8. Operational Reporting Ledger

> **Amended 2026-07-30 by [ADR-017](../decisions/ADR-017-attendance-reporting-ledger.md).**
> This section was *"Operational Dashboard (not analytics)"*. Reports are now the
> primary attendance surface; the board below remains exactly as ruled — it is the
> **live today** view, and nothing in it changes. What changed is that the
> "explicitly excluded" list at the end of this section is superseded: periodic
> reports, trends over **closed** periods, and PDF/CSV export are now in scope,
> fenced by ADR-017's metric bar (formula · denominator · computation owner ·
> gameability · the decision it changes). Composite employee scores and
> leaderboards remain refused. The rest of this spec is unchanged and still wins on
> behaviour.

### 8.1 The live board (unchanged)

**One board, ranked by what needs a decision.** Order is fixed:

1. **Needs review** — Pending Review records + pending corrections. Actionable:
   Resolve / Approve / Reject. *This is the top of the screen.*
2. **Absent / Overdue** — expected, not here. Actionable: Nudge / Excuse / Add
   record.
3. **Working now** — count + who. Passive.
4. **Completed today** — collapsed count; expand on demand.

**Supporting chrome:** branch picker (admin), an **"as of HH:MM"** stamp with
auto-refresh (the board is time-derived), and a present/expected ratio. KPIs are
**filters into the row list**, never standalone vanity numbers.

**Explicitly excluded from *this* surface** (they belong to the reporting surfaces,
not the live board): attendance-rate trends, average lateness, overtime totals over
time, punctuality scores, heatmaps.

> Before [ADR-017](../decisions/ADR-017-attendance-reporting-ledger.md) this list was
> excluded from the *product* as analytics. It is now a **placement** rule: the live
> board stays decision-ranked and free of trend chrome, while trends and periodic
> totals live on the report surfaces over closed periods. Punctuality *scores* as a
> composite ranking remain refused outright; a named punctual-arrival **rate** with a
> stated denominator is permitted on a report.

---

## 9. Edge Case Resolution (one official behavior each)

| Edge case | **Official behavior** |
|---|---|
| Forgot clock-in | Missed-punch request (employee) **or** Add record (manager) → materializes. |
| Forgot clock-out | Auto-close → Pending Review → correction / direct resolve. |
| Clock in before window | **Refused**, "Opens at HH:MM". |
| Clock out after midnight | Allowed (overnight, instant math). |
| Unscheduled open session | Max-session cap (16h) auto-close → Pending Review. |
| Multiple devices | Deterministic id → one document; server timestamp wins. |
| Offline | Queue idempotently; timer on capture time until sync; server time authoritative. |
| GPS unavailable at clock-in | Blocked with reason; recover via missed-punch if truly on-site. |
| GPS at clock-out | Recorded, never blocks. |
| Clock spam / double-tap | Idempotent doc + busy guard. |
| Duplicate corrections | One open correction per record; extras blocked. |
| Deleted schedule | Record's snapshot protects it. A clock-in with **no shift is accepted as unscheduled work** — deliberate action, mandatory reason, full GPS gate, counts in nothing until a manager approves it ([ADR-018](../decisions/ADR-018-unscheduled-clock-in.md), amends this row). |
| Shift modified mid-shift | Snapshot at punch wins. |
| Two shifts same day, both open | UI targets the open one, prompts to close before the next. |
| Timezone / DST | Instant math immune mid-shift; date/week resolved from device local date (documented assumption T5). |
| Network retry / partial write | Idempotent; client writes only the record; audit is server-derived. |
| Server (functions) not deployed | **Ship-blocker.** Corrections don't apply and audit isn't written until deployed (T3). |
| Concurrent soft-delete during correction apply | Apply guards on record existence / `deletedAt` before writing. |
| Overnight session next morning | Prompt to close yesterday; never hard-block today. |

---

## 10. Decision Log

**D1 — Early clock-in: window + clamp, not free-for-all (R1/R2).**
*Reason:* honesty (Principle 1) — worked time must mean scheduled work. *Alternatives:*
(a) accept freely and count everything — rejected: inflates hours, invites gaming;
(b) refuse hard at scheduledStart — rejected: punishes the punctual-early worker and
creates avoidable "can't clock in" friction. *Impact:* a small window absorbs normal
early arrival; minutes stay truthful.

**D2 — Managers act directly; employees request (R11/R12).**
*Reason:* accountability + no dead ends. The audit named the "employee never files →
stuck forever" trap. *Alternatives:* approval-only for everyone — rejected: leaves
Pending Review records unresolvable and Absent shifts unexcusable when the employee
won't or can't act. *Impact:* managers own their branch's record; employees retain
voice via requests; self-approval stays forbidden.

**D3 — Absent is virtual, materialized lazily (R13/D-state machine).**
*Reason:* lean (Principle 5) — don't write a document for every no-show. *Alternatives:*
auto-create an "absent" record per missed shift — rejected: write amplification, phantom
docs, and most absences are routine (leave/coverage) needing no record. *Impact:* the
board computes absence; a document appears only when someone excuses or fixes it.

**D4 — Excused is a real outcome, not a note (R14).**
*Reason:* fairness + auditability — an excused absence and a lost punch are different
truths. *Alternatives:* free-text note on a fake record — rejected: not queryable, not
honest. *Impact:* one clear terminal state with a reason.

**D5 — One open correction per record (R15).**
*Reason:* reviewer clarity, no conflicting approvals. *Alternatives:* allow many —
rejected: race conditions and duplicate work. *Impact:* the review queue stays
unambiguous.

**D6 — Every open session auto-closes; nothing blocks tomorrow (R6/R7/R8/R9).**
*Reason:* no dead ends + never trap the employee. *Alternatives:* block a new day until
yesterday is resolved — rejected: punishes the employee for a system/forgetfulness
gap. *Impact:* stale sessions become Pending Review exceptions the manager clears;
work is never stopped.

**D7 — Server time is authoritative; config snapshots at the punch (R18/R19).**
*Reason:* forgery resistance + auditability; a closed shift's pay-relevant math must
never move. *Alternatives:* trust device clock / recompute on read — rejected: both let
history change after the fact. *Impact:* records are defensible in a dispute.

**D8 — Clock-out is never GPS-blocked (R20).**
*Reason:* fairness (Principle 3) — trapping someone at work over GPS drift is not a
feature. *Alternatives:* require on-site clock-out — rejected: punishes GPS failure.
*Impact:* verification is *recorded* (a manager can see an off-site exit) but never
gates ending a shift.

**D9 — Notifications are exception-driven (N-table).**
*Reason:* signal over volume. *Alternatives:* confirm every punch to managers — rejected:
noise that gets muted. *Impact:* people trust the few notifications they get.

**D10 — The dashboard ranks actions, not statistics (§8).**
*Reason:* operational visibility (Principle 4) for a small team. *Alternatives:* a KPI/
metrics dashboard — rejected: that's analytics, out of scope, and not what a manager
needs at 9am. *Impact:* the manager's eye lands on the one thing needing a decision.

---

# Categorization

## Product Decisions (behavior)
R1–R20, the Excused state, lazy materialization (D3), manager direct-action (D2),
one-open-correction (D5), auto-close everything (D6), exception-driven notifications
(D9), action-ranked dashboard (D10), the "marked late" acknowledgement, and the
overnight-session prompt.

## Technical Constraints (forced by architecture)
- **T1 — Deterministic id** `attendance/{uid}_{yyyyMMdd}_{shift}` makes clock-in
  idempotent and offline-safe; all dedup logic is unnecessary and must not be added.
- **T2 — Late/early/overtime are derived** from snapshot minute fields, not stored
  states. One calculator (`AttendanceCalculator`) is the only minute-math source.
- **T3 — Audit trail + correction apply are server-only** Cloud Functions. Until
  `functions, firestore:rules, firestore:indexes` are deployed, the audit isn't
  written and approvals don't apply. **Deployment is a ship-blocker.**
- **T4 — Clients write only the record**; the `events` subcollection is Admin-SDK
  only. Manual entry / direct resolve therefore go through the same
  correction-apply (upsert) path, not a client write to `events`.
- **T4a — Correction target ownership is bound twice.** Firestore creation rules
  require the first `_`-separated segment of deterministic `attendanceId` to equal
  correction `userId` (including missing-record materialization); the server apply
  path independently refuses an existing record whose `userId` differs or a missing
  record id with a different owner prefix. A refused target sends no lifecycle
  notification.
- **T5 — Date/week resolved from device local date** (calendar), not device clock
  instants; wrong device *date* resolves the wrong schedule week (low-likelihood,
  documented).
- **T6 — Config is a snapshot** at punch time; per-branch `attendanceConfig` is the
  future home for the same knobs with no refactor.

## Future Enhancements (postponed)
- Per-branch opt-in pre-shift reminder (N1) and per-branch attendance config doc.
- Clock-in selfie / face verification (`photoUrl` extension point already dormant).
- Breaks (`AttendanceBreak` extension point dormant; calculator already nets them).
- Analytics/reporting, performance scores, CSV/PDF export, payroll — **held under
  ADR-009/010; not in this module.**
- Manager live board is in-scope *now* (reuse the branch-scoped admin cubit); richer
  manager tooling beyond it is future.

---

*End of locked specification. A senior engineer implements from this without further
product questions; disputes about behavior are resolved by the Decision Log.*
