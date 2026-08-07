# ADR-024 — Attendance minutes are computed server-side; the client may never write them

**Status:** Accepted · **Date:** 2026-08-07

## Context

Attendance minutes feed payroll. The whole module is designed around that one fact
— a deterministic record id, a single `AttendanceCalculator`, a snapshot persisted
at clock-out and never recomputed on read, an Admin-SDK-only audit trail. The design
docs call the record "forgery-resistant."

It was not. Every forgery-resistance property lived on the **client write path**:

- `clockOut` wrote a server timestamp, but the *worked / late / early / overtime*
  minutes were computed by the Flutter `AttendanceCalculator` and written directly by
  the client.
- `firestore.rules` let the record's **owner** update it as long as `userId` was
  unchanged, with no restriction on *which* fields changed.
- The **create** rule pinned only `status == 'inProgress'`; it did not pin the minute
  fields or `clockOut`.

So a user talking to Firestore directly with their own auth token (not through the
app) could:

- set `workedMinutes` to any value at clock-out,
- backdate `clockIn` to erase lateness,
- clock **in** with a record that already claimed `workedMinutes: 600` and a
  `clockOut`.

Those numbers are copied verbatim into the `attendance_expectations` reporting ledger
([ADR-017](ADR-017-attendance-reporting-ledger.md) — the sweep copies persisted
minutes, it never recomputes them) and flow straight into every report and the
CSV/PDF a manager hands to payroll. `onAttendanceWritten` *audited* the change but
did not reject or correct it.

Firestore rules cannot run the calculator, so there is no middle option: either the
client is trusted to write minutes (forgeable), or the client is forbidden from
writing them and the **server** computes them. There is no "validate the client's
number" path.

## Decision

**Payroll minutes are computed only by the Admin SDK. The client is forbidden by
rules from writing any minute field or backdating a clock time.**

1. **Server computes the snapshot.** `functions/attendance_totals.js` is a line-for-line
   port of `AttendanceCalculator.compute`. `onAttendanceWritten` recomputes the
   authoritative totals over the server-stamped `clockIn`/`clockOut` and writes them
   back with the Admin SDK, guarded on `source: 'clock'` (the correction-apply and
   auto-close paths own their own minutes). It only writes when the values changed, so
   the re-trigger settles in one extra write with no loop.
2. **Client stops persisting minutes.** The clock-out write sends `clockOut`, `status`
   and `clockOutVerification` — never a minute field. The totals are still *computed*
   client-side and returned for instant UI feedback (the summary recomputes worked/OT
   live via the same calculator, so nothing on screen waits for the server, offline
   included).
3. **Rules pin the payroll-sensitive fields.**
   - **Create:** an open clock-in must carry zero minutes and no `clockOut`.
   - **Update (owner):** the *only* legal owner update is the clock-out transition —
     `inProgress → completed` with a `clockOut` set, `clockOutVerification`/`updatedAt`
     free to change, and `userId`, `branchId`, `shift`, `dayKey`, `clockIn`,
     `scheduledStart/End`, `presenceOnly`, `source`, `resolvedBy`, all five minute
     fields and `breaks` **frozen**. Self-updates by any role go through this pin;
     reviewers acting on *another* user's record keep the broad path (e.g. soft-delete).

## Consequences

- An employee — or a manager on their own record — can never choose their own pay or
  erase their own lateness. The "forgery-resistant" claim is now enforced by rules,
  not merely honored by the app.
- The persisted snapshot lands a beat after clock-out (and on the next sync when
  offline). The display is live-computed, so this is invisible to the person; the
  ledger reads minutes only at slot close (hours later), long after finalization.
- Two implementations of the minute math now exist (Dart + JS). This is the same
  accepted parity tax as the expectation ledger; both carry mirror-comments and unit
  tests (`attendance_totals.test.js`, `attendance_calculator_test.dart`).
- **Requires a functions deploy + a rules deploy** to take effect. Until both land,
  the old client-trusted path remains in production. Pinned by
  `firestore-tests/attendance.rules.test.mjs` (17) and
  `functions/test/attendance_totals.test.js` (11).

Supersedes the client-writes-minutes half of the original attendance write path
described in [ADR-005](ADR-005-server-authoritative-writes.md); it is the same
principle (anything a client must not forge is written by the Admin SDK), extended to
the one field that had slipped through.
