# Architecture Decision Records

One decision per file. Short, focused, permanent.

An ADR exists to **stop a settled question from being reopened**. If you are about
to argue for a change that contradicts an ADR, read it first — the trade-off was
probably already weighed. Reversing one is fine; doing it *unknowingly* is not.

| ADR | Decision | Status |
| --- | --- | --- |
| [ADR-001](ADR-001-firebase-backend.md) | Firebase as the backend | Accepted |
| [ADR-002](ADR-002-cubit-only.md) | Cubits only — no Blocs, no Riverpod | Accepted |
| [ADR-003](ADR-003-clean-architecture.md) | Clean Architecture, sliced by feature | Accepted |
| [ADR-004](ADR-004-monochrome-design.md) | Strictly monochrome UI — indigo rejected | Accepted |
| [ADR-005](ADR-005-server-authoritative-writes.md) | Audit trails and privileged writes are server-authoritative | Accepted |
| [ADR-006](ADR-006-schedule-shift-plan-snapshots.md) | A week snapshots its shift plan | Accepted |
| [ADR-007](ADR-007-schedule-health-removed.md) | Schedule Health is removed | Accepted |
| [ADR-008](ADR-008-requests-are-approvals.md) | Requests are approvals, not tickets | Accepted |
| [ADR-009](ADR-009-no-analytics-pipeline.md) | No analytics pipeline | Accepted |
| [ADR-010](ADR-010-lean-over-enterprise.md) | Lean internal tool, not enterprise SaaS | Accepted |
| [ADR-011](ADR-011-automation-observability.md) | Automation execution observability (scoped carve-out of ADR-009/010) | Accepted |
| [ADR-012](ADR-012-chat-directory-is-flat.md) | Chat is not org-scoped: a flat participant directory | Accepted |

## Writing a new one

Copy the shape of any existing ADR: **Context** (the forces), **Decision** (what we
do), **Consequences** (what it costs). Number sequentially. Never edit a decided
ADR's Decision — supersede it with a new ADR and mark the old one `Superseded by
ADR-0NN`.
