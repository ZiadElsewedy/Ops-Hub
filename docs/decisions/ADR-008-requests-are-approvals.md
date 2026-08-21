# ADR-008 — Requests are approvals, not tickets

**Status:** Accepted · **Date:** 2026-07-08

## Context

Operations Requests drifted toward a ticketing system — richer statuses, assignment,
priority, the shape of Jira or a service desk. OpsHub has a handful of users per
branch. A ticket queue is a coordination tool for teams too large to just ask each
other, which is not this.

## Decision

A Request is an **employee asking their own-branch manager for a yes/no approval.**

- **Statuses are exactly** `Pending → Approved | Rejected`. Nothing else.
- **Create is employee-only.** An admin has global visibility and *may decide*, but
  **cannot create** — which makes self-approval structurally impossible and means
  **no guard is needed**.
- One message field, optional attachments, server-written timeline events.
- Admin escape hatches only: soft delete (`deletedAt`) and reopen.

The same shape governs **attendance corrections** (`attendance_corrections/`), which
reuse `RequestStatus` and forbid self-approval server-side.

## Consequences

- The feature is understandable in one sentence, which is the point.
- Self-approval is prevented by structure rather than by a rule that could be
  missed — the strongest kind of guard.
- **Cost:** no queue, no assignment, no SLA, no priority. All deliberate. A request
  that needs discussion is a **Case**, which is the conversation feature; do not
  merge the two.
- Do not re-add complexity here. This has been simplified once already.
