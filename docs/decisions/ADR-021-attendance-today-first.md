# ADR-021 — Attendance & Reports starts with Today, not reports

**Status:** Accepted · **Date:** 2026-08-01

## Context

The live attendance board, branch reviewer ledger, and direct-resolution write
path already existed, but the board route was orphaned and the sidebar opened a
reports hub first. A manager had to know several destinations before answering
who is present, late, absent, or needs a decision. An unscheduled clock-in was
visible but its affirmative decision was only discoverable from a past-day review.

## Decision

`/attendance/reports` is the manager/admin Attendance & Reports landing and
renders **Today**. Managers are pinned to their own branch; admins choose a
branch before the board loads. Today groups needs a decision, present / working,
late, and absent, and exposes the existing direct-resolution path as **Mark
present** for an unscheduled clock-in.

Reports and the reviewer ledger remain explicit next steps: **Reports** for the
hub and **Person history** for employee search and a date range. `/admin/attendance`
redirects to Today so old links do not preserve a second live board.

## Consequences

The reporting hub is demoted, not removed; weekly, monthly, and Admin workspace
remain intact. This is presentation and navigation only: board calculation,
ledger, minute math, and the approved-correction write path remain unchanged.

Admins add one deliberate scope choice before Today. The direct-resolution form
still asks for times and an audit note; “Mark present” changes language and entry
point, not write semantics.
