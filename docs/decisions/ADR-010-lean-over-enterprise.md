# ADR-010 — A lean internal tool, not enterprise SaaS

**Status:** Accepted · **Date:** ongoing; written down 2026-07-15

## Context

OpsHub is repeatedly pulled toward the shape of the tools it superficially resembles —
Jira, Slack, Linear, Deputy, Connecteam. Those are products for organisations large
enough that people cannot simply talk to each other, sold to buyers who compare
feature grids. OpsHub is an internal operations tool for **OpsHub**, used by a
small, known set of people across a handful of branches.

Copying their surface imports coordination overhead that only exists to solve a
scale problem OpsHub does not have.

## Decision

Optimise for **workflow over architecture** and **UX over feature count**.

- **Default to deletion.** When a feature is questioned, the burden of proof is on
  keeping it. Schedule Health (ADR-007) and the analytics pipeline (ADR-009) were
  both deleted after shipping; that is a healthy outcome, not a failure.
- **Simple > clever. Signal > volume.** No abstraction without a second caller.
- **Stability > perfection.** A 90%-complete change with zero regressions beats a
  100% one that risks them.
- **Learn from mature products; do not copy them.** Extract the practice, leave the
  scale assumptions.
- **Guard intentional UX.** Previously-debated behaviour is not "inconsistency" to
  be tidied away — check the ADRs and CHANGELOG before smoothing something over.
- **Premium, not minimal** — leanness is about *count*, not *craft* (ADR-004).

Classify every change (**bug / polish / refactor / feature**) and label its risk
(**LOW / MED / HIGH**). Lead with operational impact.

## Consequences

- Some obviously-useful-sounding features will be refused. That is the decision
  working.
- **Cost:** OpsHub will lose a feature-grid comparison against Deputy or Connecteam.
  Irrelevant — it has no buyers, only users.
- A UI overhaul is never a refactor. The owner's taste is **visible craft over
  minimalist reduction**; "work on it more" means *enrich*, not *simplify*. Never
  replace a lived-in surface without sign-off first.
