# ADR-015 — Automation uses the Egypt business civil day

**Status:** Accepted · **Date:** 2026-07-30

## Context

Automated Shift Task instances could be born already past their deadline. Two
paths caused the same operational lie:

**1. The generator's "today" was UTC and its schedule was unpinned.** Around
Egypt's local midnight, UTC still addressed the previous calendar date. The
deterministic id, weekly weekday match, weekly schedule key, and resolved window
could therefore point at yesterday. Separately, `schedule: "every 24 hours"` did
not guarantee a pre-shift run; if the tick landed after a shift window closed,
the task could be created already overdue and then auto-ended as Missed after
grace.

**2. The client materializer created today's instance whenever a routine was
saved.** A manager saving a morning routine at 18:00 could create an instance for
the already-closed morning shift. The Cloud Function sweep then correctly saw an
unfinished generated shift task whose deadline plus grace had passed, but the
wrongness happened at birth.

The product spec already carries the ruling that makes this solvable without a
branch setting: OpsHub operates in **Egypt only, on one timezone**
([spec §12.2](../design/AUTOMATED_TASKS_PRODUCT_SPEC.md)). Multi-timezone support
is explicitly a future prerequisite, not a present requirement.

## Decision

The automation day boundary is the **business civil day in `Africa/Cairo`**.

This applies to the recurring-shift generator's deterministic key
(`rt_{templateId}_{yyyy-MM-dd}`), weekly weekday match, `weekly_schedules` week
key, generated run id, correlation date, and shift-window midnight anchor. The
pure Functions policy module owns the timezone primitive so the generator and
the auto-end window tests share one definition.

`generateShiftTaskInstances` is pinned to **01:00 Africa/Cairo** with
`maxInstances:1`, `retryCount:0`, and `timeoutSeconds:300`. That is before the
earliest configured shift start (08:30) and avoids the arbitrary wall-clock time
of `"every 24 hours"`.

No automation engine may create a task whose resolved deadline is already in the
past:

- The client save-time materializer uses device-local today (the device is in
  the single business timezone) and returns without creating if the resolved
  shift window has already closed. The server remains authoritative if a device
  clock or timezone is wrong.
- The per-task recurrence successor rolls forward from the later of the source
  deadline and now until the next deadline is in the future.

Date stepping that means "civil days" uses calendar arithmetic, not fixed
24-hour durations, so Egypt DST transitions do not move the configured wall
clock hour.

## Consequences

- The UTC-key convention is reversed. During deployment transition, the
  generator checks the legacy UTC-derived id before creating the new
  business-date id; if it exists, the run is recorded as the existing
  `alreadyExists` skip and no duplicate task or notification is produced. That
  guard is temporary and can be deleted after no live UTC-keyed instance can
  remain.
- `nextRunAt` now points at the next 01:00 Africa/Cairo generation tick. It is
  still an advisory Automation Center rollup, not a guarantee that a task will
  be created.
- Client and server agree only under the current single-timezone business
  assumption. A multi-timezone estate requires a branch timezone model, a new
  deterministic key convention, and a migration plan before expansion.
- Saving a routine after its shift deadline has passed will not produce a task
  immediately. The next eligible occurrence is created by the 01:00 server run.

## Supersedes

The UTC-day convention documented in
[AUTOMATION_ENGINE](../design/AUTOMATION_ENGINE.md) before this ADR.
