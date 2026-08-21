# ADR-006 — A week snapshots its shift plan

**Status:** Accepted · **Date:** 2026-07-09

## Context

Shift end times are **data, not code** — a branch's night shift might end at 01:00,
and that changes over time. If a week read its hours live from the branch's current
template, editing the template would silently rewrite history: last month's roster
would re-render with this month's hours, and the payroll figures derived from it
would change retroactively.

## Decision

A new week **snapshots** the branch's shift plan onto its own document
(`weekly_schedules/{id}.shiftPlan`). Hours resolve through one function,
`WeeklyScheduleEntity.hoursFor(day, shift)`, in a fixed order:

1. the week's **per-slot override** (`shiftHours`), then
2. the week's **`shiftPlan` snapshot**, then
3. `ShiftHours.standard`.

A legacy week with no snapshot resolves to standard, unchanged. Managers edit hours
with an explicit 3-way scope (`ShiftHoursScope`): **This week** (per-slot override)
· **Future** (updates the template) · **Global** (template + `restampShiftPlan`
onto current/future weeks).

Overnight shifts are expressed as `end > 1440`. All slot timing lives in
`domain/shift_window.dart`.

## Consequences

- History is immutable by construction — no migration, no backfill, no "as-of" query.
- The 3-way scope makes the blast radius of an hours edit a deliberate choice
  instead of a surprise.
- **Cost:** shift hours are stored redundantly per week. At OpsHub's scale (a handful
  of branches × 52 weeks) this is free.
- **Cost:** three resolution layers must be kept in one place. They are — never read
  `shiftHours` or `shiftPlan` directly; always go through `hoursFor`.
