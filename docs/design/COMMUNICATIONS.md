# Communications — broadcasts

Admin/manager → many. One-way announcements, always delivered to the in-app
inbox and optionally mirrored as push. Employees never send.

## Delivery is explicit

The composer has one visible delivery control, defaulting to **Push + Inbox**:

| Choice | Stored `sendsPush` | Delivery |
| --- | --- |
| Inbox only | `false` | in-app inbox |
| Push + Inbox | `true` | in-app inbox + FCM |

Category remains an independent label (`announcement` / `reminder` / `emergency`).
Emergency alone carries high FCM priority. `dispatchBroadcast()` uses explicit
`sendsPush` when present; legacy schedule/client payloads without it fall back to
the historic category rule (`announcement` inbox-only, others push + inbox).

## Audiences

`BroadcastAudience` = `allBranches` | `branch` | `user` (DM) | `custom`.

- `''` = the all-branches sentinel, so a branch member's
  `where('branchId', whereIn: [branch, ''])` feed is **one index-free, rules-safe
  query**.
- `'__direct__'` = the DM marker, so a DM never appears in a branch/all feed query.
- `custom` carries `targetUserIds` + an optional `roleFilter`, threaded as
  **send-time intents** through the use case → repo → datasource → callable, with no
  entity change.

`domain/broadcast_permissions.dart` (`canSend` / `allowedAudiences` / `validate`) is
the client guard — admin: all/branch/user · manager: own-branch/user-in-branch ·
employee: none. It is **re-enforced** in `functions/index.js` and `firestore.rules`;
the client copy is UX, not security.

## Send path

```
BroadcastCubit.send  →  SendBroadcast (use case)  →  repo  →  datasource
                     →  callable `sendBroadcast`  (Admin SDK — the SOLE writer)
```

All client writes to `broadcasts/{id}` are **denied** except an `archivedAt` diff.
The function validates permissions → resolves recipients → writes the doc → gathers
`users.fcmTokens` → `sendEachForMulticast` → prunes dead tokens → returns
`{success, recipientCount, deliveredCount, broadcastId}`.

`dispatchBroadcast()` is shared with the scheduler; new schedules persist the same
`sendsPush` choice.

## Slices

| Slice | Holds |
| --- | --- |
| `broadcasts` | The feed — **history** (Active / Archived) + per-item actions |
| `broadcastTemplates` | Reusable blueprints + pure `template_renderer.dart` (`{{placeholders}}`) |
| `broadcastSchedules` | Scheduled/recurring, pure `recurrence_rule.dart`, fired by `runBroadcastSchedules` (an onSchedule poller — the chosen architecture) |
| `taskReminders` | Pure `reminder_rules.dart` (lives in `features/task/domain`), fired by `runTaskReminders` with an anti-spam ledger + quiet hours |

## Lifecycle

A broadcast is **active or archived** — the soft-delete/`deletedAt`/Deleted-view was
removed. **Delete is a permanent hard delete** of `broadcasts/{id}` (re-added
2026-06-27), confirm-gated, allowed for admin · original sender · owning-branch
manager. Per-recipient `notifications/{id}` inbox docs are **not** cascaded —
accepted.

Feeds support bulk selection (Select all / Clear all → Archive/Restore/Delete);
`setArchivedMany` / `deleteBroadcasts` just sequence the single-doc repo methods, so
no schema/rules/function change.

## No analytics

Open tracking, read rates, monthly rollups, and the charts screen were **deleted** —
see [ADR-009](../decisions/ADR-009-no-analytics-pipeline.md). What remains on
`broadcast_detail_screen` is minimal delivery diagnostics: **recipients · delivered ·
failed**. Those answer "did it send?", which is a real question. Don't rebuild the
rest.

## UI

`communications_screen` (feed) · `compose_broadcast_screen` (role-gated, `prefill`
for Duplicate) · `broadcast_detail_screen` · `broadcast_templates_screen` ·
`broadcast_schedules_screen`, plus `broadcast_card` + `communications_format.dart`.

**Routes:** `/communications` · `/communications/compose` · `/communications/:id` ·
`/communications/templates` · `/communications/schedules` — admin + manager only
(`_isCommunicationsArea` bounces employees). Declare compose **before** detail or the
`:broadcastId` pattern swallows it.

`getBroadcast(id)` lets a detail screen self-resolve one doc, so a notification tap
opening `/communications/:id` **cold** fetches rather than dead-ending on "Broadcast
unavailable".

## Related

[DATA_MODEL](DATA_MODEL.md) · [NOTIFICATIONS](NOTIFICATIONS.md)
