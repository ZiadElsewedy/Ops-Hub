# Event Tracking + Audit Log

> Immutable, append-only record of every important business action in DROP.
> **Not analytics** — this is an operational audit trail: *who did what, to which
> entity, when, and from where.* Built as a normal DROP clean-architecture slice
> (`lib/features/audit/`), strictly additive, deploy-light.

**Status:** shipped 2026-07-10 (`feature/notifications-v2`). Client-only (no Cloud
Function). Producers wired: full **Task lifecycle** + **Operations Requests**
decisions. The rest of the taxonomy is declared and one `trackEvent(…)` call away.

---

## 1. What it answers

Every record answers, for a single action:

| Question          | Field(s)                                   |
| ----------------- | ------------------------------------------ |
| **WHO**           | `actorId`, `actorName`, `actorRole`        |
| did **WHAT**      | `eventType` (a stable dotted id)           |
| to **WHICH ENTITY** | `entityType`, `entityId`                 |
| **WHEN**          | `timestamp` (server-stamped, trusted clock)|
| **FROM WHERE**    | `branchId` (+ event-specific `metadata`)   |

Plus record bookkeeping: `schemaVersion`, `isDeleted` / `deletedAt` / `deletedBy`.

---

## 2. Architecture

```
Business action (TaskCubit, Requests cubits, …)
        │   eventTracking.trackEvent(type, actor, entityId, …)     ← the ONE seam
        ▼
EventTrackingService            (domain/services)  — validation · schema version ·
        │                                             actor capture · sanitize · never throws
        ▼
AuditRepository (abstract)      (domain/repositories)
        ▼
AuditRepositoryImpl             (data/repositories) — model⇄entity · drops soft-deleted
        ▼
AuditRemoteDataSource(+Impl)    (data/datasources)  — one `add` (server timestamp) · bounded reads
        ▼
Cloud Firestore  audit_logs/{id}
```

Every write funnels through **one method** — `EventTrackingService.trackEvent`.
No feature ever touches Firestore or the repository directly, so the schema, the
validation, and the immutability guarantees live in exactly one place.

### Files

| Layer      | File |
| ---------- | ---- |
| Enum       | `core/enums/audit_event_type.dart` — the action taxonomy (dotted ids) |
| Enum       | `core/enums/audit_entity_type.dart` — the entity dimension |
| Entity     | `features/audit/domain/entities/audit_log_entry.dart` (+ `kAuditSchemaVersion`) |
| Value obj  | `features/audit/domain/entities/audit_actor.dart` — WHO, captured at event time |
| Service    | `features/audit/domain/services/event_tracking_service.dart` — **the write seam** |
| Repository | `features/audit/domain/repositories/audit_repository.dart` |
| Repo impl  | `features/audit/data/repositories/audit_repository_impl.dart` |
| Model      | `features/audit/data/models/audit_log_model.dart` — Firestore (de)serialization |
| Datasource | `features/audit/data/datasources/audit_remote_datasource.dart` |
| DI         | `core/di/injection.dart` — `AppDependencies.eventTracking` / `.auditRepository` |

The entity + actor are **plain-immutable** (no freezed) — the same deliberate
choice as `EventEntity` / `BroadcastScheduleEntity`: a serialization-heavy value
object reads cleaner without generated-file churn.

---

## 3. Flow

**Write** (fire-and-forget, best-effort):
1. A business write succeeds (a task is approved, a request is filed…).
2. The cubit calls `eventTracking.trackEvent(type, actor, entityId, metadata)`.
3. The service **validates** (non-empty `entityId`, `schemaVersion ≥ 1`),
   captures the actor, sanitizes metadata (drops nulls / non-serializables),
   stamps `schemaVersion`, builds an `AuditLogEntry`.
4. The datasource appends one document with a **server timestamp**.
5. Any failure is swallowed + logged (🔴) — **the business flow never sees it.**

**Read** (an admin/manager audit view — repository is ready; no UI shipped yet):
`recent()` · `watchRecent()` · `forEntity()` · `forActor()` · `forBranch()` ·
`inDateRange()` — all `limit`-bounded, newest-first, with a `before` timestamp
cursor for pagination. Soft-deleted records are excluded unless
`includeDeleted: true`.

---

## 4. Schema

**Collection:** `audit_logs/{autoId}` — the document id **is** the record id.

| Field          | Type                | Notes |
| -------------- | ------------------- | ----- |
| `eventType`    | string              | stable dotted id, e.g. `task.approved` (never the enum name) |
| `entityType`   | string              | `task` / `request` / `shift_swap` / `session` / … |
| `entityId`     | string              | affected doc id (or the acting uid for a session event) |
| `actorId`      | string              | pinned to the authenticated caller by rules |
| `actorName`    | string?             | denormalized at event time |
| `actorRole`    | string              | `admin` / `manager` / `employee` |
| `branchId`     | string?             | scope axis (`''` = all-branches marker) |
| `timestamp`    | server Timestamp    | trusted clock; set by the datasource, never the client |
| `metadata`     | map                 | event-specific payload; `DateTime ⇄ Timestamp` normalized recursively |
| `schemaVersion`| int (`1`)           | this record's shape version |
| `isDeleted`    | bool (`false`)      | soft-delete flag |
| `deletedAt`    | Timestamp?          | set on soft-delete |
| `deletedBy`    | string?             | admin uid that soft-deleted |

**One generic structure serves every event type** — the differences live in
`metadata`, never in a new collection or a new document shape:

```
task.assigned   → { title, assignmentType, priority, shift?, assignedTo? }
task.approved   → { title, reviewNotes? }
task.completed  → { title, attachments }
task.cancelled  → { title, reason, note?, cancelledFrom }
task.reported_incorrect → { title, note }
task.terminal_corrected → { title, correctedFrom, note? }
task.photo_uploaded → { title, count, storagePaths }
request.created → { requestType }
```

### Schema versioning (versions coexist forever)

`schemaVersion` is stored on each record. An audit log is **never migrated in
place** (that would rewrite history). Instead, a reader branches on the stored
version. A newer client may also write an `eventType` this build doesn't know —
`AuditEventType.fromString` maps it to `unknown` instead of crashing, so old and
new clients coexist.

---

## 5. Soft delete (never hard delete)

Audit records are **never edited** and **never hard-deleted** anywhere in the
stack. The only mutation is an **admin soft-delete**:
`EventTrackingService.softDelete(id, actor:)` → `isDeleted:true` + `deletedAt` +
`deletedBy`, and nothing else. The record stays as a retained fact; every
repository read filters it out unless `includeDeleted: true` is passed.

---

## 6. Security rules (`firestore.rules` → `match /audit_logs/{id}`)

- **read** — admin (all) · own-branch manager (their branch's history). Employees
  have no audit-read need.
- **create** — any signed-in user may append an event **as themselves**:
  `actorId == request.auth.uid` (a client can **never forge another user's
  history**), born live (`isDeleted == false`), valid `schemaVersion ≥ 1`.
  `timestamp` is a server timestamp.
- **update** — admin only, and **only** the `isDeleted`/`deletedAt`/`deletedBy`
  field-diff (→ `isDeleted == true`). Immutable otherwise.
- **delete** — `false`. No hard delete, ever.

> Client-direct writes (not a Cloud Function) are the deliberate, deploy-light
> choice — consistent with DROP's "client writes, rules enforce" pattern
> (`usageStats`, the tasks denylist, the broadcast field-restriction). The
> `actorId == uid` rule is the anti-forgery guarantee. Hardening the write behind
> an Admin-SDK callable (like notifications' `sendNotification`) is a documented
> future option if untrusted clients ever need to be assumed.

---

## 7. Performance

- **Writes are lightweight** — one `add`, no read, no transaction, and
  fire-and-forget from the producer (never blocks or slows the business action).
- **Reads are always bounded** — every query is `limit`-capped and ordered by
  `timestamp desc`, with a `before` keyset cursor for pagination. Audit history is
  never loaded eagerly; nothing reads it unless an audit view asks.
- **Designed for tens of thousands of records** — keyset (not offset) pagination,
  and the query axes are backed by composite indexes (`firestore.indexes.json`):
  `entityType+entityId+timestamp`, `actorId+timestamp`, `branchId+timestamp`
  (latest-feed = single-field `timestamp`; date-range = single-field range).
  Soft-deletes are filtered client-side to keep the index set minimal.

---

## 8. Add a new event type (the whole point)

Adding a newly-auditable action is **one enum entry + one call**:

1. Add a value to `AuditEventType` with its stable dotted id, default entity, and
   label:
   ```dart
   shiftSwapApproved('shift_swap.approved', AuditEntityType.shiftSwap, 'Swap approved'),
   ```
   (Add a new `AuditEntityType` only if the entity kind is genuinely new.)

2. Call the seam at the business site, right after the write succeeds:
   ```dart
   _eventTracking?.trackEvent(
     type: AuditEventType.shiftSwapApproved,
     actor: AuditActor.of(user),
     entityId: swap.id,
     branchId: swap.branchId,
     metadata: {'from': swap.requesterId, 'to': swap.targetId},
   );
   ```

That's it — **no** new collection, model, datasource method, repository method,
DI wiring, index, or rule. The service, schema, and immutability guarantees are
untouched.

### Wiring a producing cubit
Give the cubit an optional `EventTrackingService? eventTracking` constructor
param (nullable so existing tests keep compiling), store it, and pass
`AppDependencies.eventTracking` in `injection.dart`. See `TaskCubit`,
`RequestsListCubit`, `RequestDetailCubit` for the reference pattern.

---

## 9. Taxonomy & producer status

**LIVE** (wired this pass):
`task.assigned` · `task.started` · `task.completed` · `task.approved` ·
`task.rejected` · `task.rework_requested` · `task.cancelled` ·
`task.reported_incorrect` · `task.report_dismissed` ·
`task.terminal_corrected` · `task.photo_uploaded` · `request.created` ·
`request.approved` · `request.rejected`.

> `task.cancelled` carries the mandatory `reason` code, so "how often is this
> routine cancelled, and why" is answerable from the audit trail alone — the
> quality signal the Automated Tasks spec (§10.3) relies on.

**Declared, ready for their producer** (each = one `trackEvent` call):
`shift_swap.requested|approved|rejected` (→ `ShiftSwapCubit`) ·
`auth.login|logout` (→ `AuthCubit`) · `profile.updated` (→ `ProfileCubit`) ·
`broadcast.sent` (→ `BroadcastCubit`). Wiring auth was deliberately deferred to
keep this pass off the sensitive session flow.

---

## 10. Testing

- `test/audit_event_type_test.dart` — dotted-id parsing, `unknown` fallback,
  uniqueness, defaults, namespace.
- `test/audit_log_model_test.dart` — serialization round-trip, server-timestamp
  omission, `metadata` `Timestamp⇄DateTime` (recursive), versioning defaults,
  forward-compat, soft-delete fields.
- `test/event_tracking_service_test.dart` — full record build, entity/branch
  override, validation drops, metadata sanitize, **fire-and-forget never throws**,
  soft-delete delegation, actor fallback.
- `test/audit_repository_test.dart` — soft-delete filtering (default + include),
  mapping, pagination cursor pass-through, per-axis delegation.

33 tests, all green. Full suite **780 pass / 2 pre-existing splash-centering
fails** (unrelated). `flutter analyze` — 0 new issues.

---

## 11. Known limitations & future evolution

- **Client-trusted timestamp only via `serverTimestamp()`** — trusted, but the
  write itself is client-initiated; an Admin-SDK callable would add tamper-proof
  attribution if the threat model ever needs it (§6).
- **No audit UI yet** — the read side (repository) is complete and paginated; an
  admin "Activity / Audit" screen is a clean follow-up (feed of
  `watchRecent()` + `forEntity()` drill-downs).
- **Soft-deletes filtered client-side** — fine at DROP's scale; a
  `isDeleted+timestamp` composite index would move it server-side if volume grows.
- **Retention** — records are kept indefinitely; a scheduled
  `auditHousekeeping` function could archive/prune beyond a horizon later.
- **More producers** — see §9; wiring the declared events is incremental and
  low-risk.
```
