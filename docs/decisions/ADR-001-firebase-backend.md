# ADR-001 — Firebase as the backend

**Status:** Accepted · **Date:** 2026-06-13

## Context

OpsHub is an internal operations tool for a small, known set of users across a
handful of branches. It needs auth, a realtime document store, file storage, push
notifications, and a little server-side logic. It has no dedicated backend team.

## Decision

Use Firebase for the whole backend: **Auth** (email/password), **Cloud Firestore**
(realtime documents), **Storage** (media), **Cloud Messaging** (push), and **Cloud
Functions** (Node.js, `functions/`) for anything that must be server-authoritative.

Security is enforced in `firestore.rules` / `storage.rules`, not in the client.

## Consequences

- Realtime streams come free — the entire UI is live with no polling or sockets.
- Offline persistence comes free, which matters for clock-in on a weak signal.
- No server to operate, patch, or pay for at idle.
- **Cost:** queries are weak. No joins, no aggregation; a filter + `orderBy` needs a
  composite index. Joins are done client-side in pure domain functions, and list
  ordering is done in Dart (`task_ordering.dart`) rather than in the query.
- **Cost:** vendor lock-in is real. The repository layer (ADR-003) is the seam —
  Firebase types never escape `data/`, so a migration would rewrite datasources
  only.
- Anything a client must not forge (audit trails, approvals) goes in a Function —
  see [ADR-005](ADR-005-server-authoritative-writes.md).
