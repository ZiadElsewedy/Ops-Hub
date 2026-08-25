# Requests — employee → manager approvals

An employee asks their own-branch manager for a **yes/no approval**. That is the
entire feature.

**Read [ADR-008](../decisions/ADR-008-requests-are-approvals.md) before changing
anything here.** This has been simplified once already; the pull toward ticketing is
constant.

## Rules of the shape

| | |
| --- | --- |
| **Statuses** | `Pending → Approved \| Rejected`. Nothing else |
| **Create** | **Employee-only** |
| **Decide** | Own-branch manager, or admin (global visibility) |
| **Admin extras** | Soft delete (`deletedAt`) · reopen. **Admin cannot create** |
| **Content** | One message field + optional attachments |

**Self-approval is structurally impossible**, not guarded. Because an admin cannot
create a request and a manager decides only their own branch's, there is no path
where a person decides their own — so **no guard exists, and none is needed**. If
you add admin-create, you break this and inherit the guard.

No queue. No assignment. No SLA. No priority. All deliberate.

## Structure

```
requests/{requestId}
  └── events/{eventId}     ← timeline, immutable
```

Server-written: the `REQ-######` refCode (via `counters/`), lifecycle timeline
events, and notifications — `onRequestCreated` / `onRequestUpdated` /
`onRequestEventCreated`.

Hard delete is **denied** in rules. A client `deleteRequest` removes the doc only and
intentionally orphans the `events` subcollection (rare admin op — documented, not a
bug).

## Composition

- **`RequestsListCubit`** (app-wide) — role-scoped streams + employee-only create;
  `BranchRepository` for branch names.
- **`RequestDetailCubit`** (per request, via
  `AppDependencies.createRequestDetailCubit`) — streams the doc + its `events`;
  owns approve/reject, admin reopen/soft-delete.

Write use cases: `CreateRequest` · `ChangeRequestStatus` · `AddRequestComment` ·
`UploadRequestAttachment`.

Pure: `request_access.dart` · `request_ordering.dart` · `request_metrics.dart` ·
`request_thread.dart`.

## UI

`requests_screen` · `create_request_screen` · `request_detail_screen`, plus
`request_card` · `request_timeline` · `request_composer`.

**Routes:** `/requests` · `/requests/create` · `/request/:requestId`

> The empty state once froze the screen with an infinite-height layout — fixed in
> `OpsHubEmptyState` / `AppEmptyState`. If a list screen hangs on open, suspect the
> empty state.

## The same shape elsewhere

**Attendance corrections** reuse this design and `RequestStatus` verbatim — an
employee files, a reviewer decides, self-approval forbidden server-side. See
[ATTENDANCE](ATTENDANCE.md). Keep them aligned; if this shape changes, that one
should too.

## Related

[DATA_MODEL](DATA_MODEL.md) · [CASES](CASES.md) · [ATTENDANCE](ATTENDANCE.md)
