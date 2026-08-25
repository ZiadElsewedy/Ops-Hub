# ADR-002 — Cubits only, no Blocs

**Status:** Accepted · **Date:** 2026-06-14

## Context

OpsHub's state is overwhelmingly "load some documents, stream them, expose a few
actions". The event-driven Bloc pattern adds an event class per action and an
indirection between the call site and the handler, buying replay and event
transformers that OpsHub has never needed.

## Decision

Use `flutter_bloc` but **only `Cubit`** — never `Bloc`. States are `freezed`
unions.

Cubits reach their data through one of two shapes, both in use deliberately:

| Shape | Used by | Why |
| --- | --- | --- |
| Cubit → use case → repository | `auth`, `profile`, `task` (writes) | Writes with real business rules |
| Cubit → repository directly | `branch`, `admin`, `statistics`, `schedule`, `requests`, `cases` | Reads/streams where a use case would be an empty pass-through |

Hybrids are normal and correct: `TaskCubit` uses cases for writes and the
repository directly for realtime streams.

## Consequences

- Less ceremony; the call site names the action (`cubit.approve(id)`).
- No global store. App-wide cubits are provided in `main.dart`; per-entity cubits
  (`CaseConversationCubit`, `RequestDetailCubit`) are built on demand by
  `AppDependencies.create*`.
- **Cost:** no free event log. Where an audit trail matters it is an explicit
  server-side concern, not a state-management side effect (ADR-005).
- **Cost:** the two shapes can look inconsistent to a newcomer. That is accepted —
  a use case that only forwards a call is noise (ADR-010).
