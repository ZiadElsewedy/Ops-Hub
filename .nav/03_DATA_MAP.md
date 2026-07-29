# 🗄️ 03 · DATA MAP — Firestore ↔ Rules ↔ Functions ↔ Features

The backend nervous system. For any collection: who reads/writes it, which rule guards it, which
function reacts to it, and which Dart model shapes it.

🧠 **Canonical contract:** `docs/design/DATA_MODEL.md` (field-level). Security truth: `firestore.rules`
(line numbers below) + `storage.rules`. Server logic: `functions/index.js` (+ 3 sibling files).

## 🧩 Legend
`onCreate/onUpdate/onWritten` = Firestore trigger · `onCall` = client-invoked callable · `onSchedule` = cron.
🖥️ = server-authoritative (clients cannot write this directly; rules lock it, a Function owns it).

## 📊 Collection registry (27 top-level + subcollections)

| Collection | rules @ | Owner feature | Reacting Cloud Functions | Model |
|---|--:|---|---|---|
| `users/{uid}` | 75 | auth / admin / profile | `claimFcmToken` (onUpdate) 🖥️ | `user_model.dart` (auth) |
| `users/{uid}/private/{doc}` | 143 | auth | — | — |
| `tasks/{taskId}` | 239 | task | `taskHousekeeping` (cron) | `task_model.dart` |
| `task_templates/{id}` | 372 | task | — | `task_template_model.dart` |
| `recurringTaskTemplates/{id}` | 387 | task/operations | `onRecurringTemplateWritten`, `generateShiftTaskInstances` (cron), `autoEndRecurringShiftTasks` (cron) | — |
| `automationRuns/{runId}` | 401 | operations | written by automation fns · ⚠️ **no in-app reader** (ADR-011) | `automation_run_model.dart` |
| `branches/{branchId}` | 411 | branch | — | `branch_model.dart` |
| `weekly_schedules/{id}` | 423 | schedule | `generateShiftTaskInstances` reads it | `weekly_schedule_model.dart` |
| `shift_templates/{id}` | 439 | schedule | — | `shift_template_model.dart` |
| `shift_swaps/{swapId}` | 493 | schedule | `approveSwap` (onCall) 🖥️ | `shift_swap_model.dart` |
| `broadcasts/{id}` | 549 | communications | `sendBroadcast` (onCall), `broadcastHousekeeping` (cron) | `broadcast_model.dart` |
| `broadcastTemplates/{id}` | 587 | communications | — | `broadcast_template_model.dart` |
| `broadcastSchedules/{id}` | 603 | communications | `runBroadcastSchedules` (cron) 🖥️ | `broadcast_schedule_model.dart` |
| `taskReminders/{taskId}` | 620 | task/notifications | `runTaskReminders` (cron) 🖥️ | — |
| `reminderConfig/{id}` | 628 | notifications | read by `runTaskReminders` | — |
| `notifications/{id}` | 644 | notifications | `sendNotification` (onCall), `onNotificationCreated` (onCreate→FCM) 🖥️ | `notification_model.dart` |
| `cases/{caseId}` | 667 | cases | `onCaseCreated`, `onCaseUpdated` | `case_model.dart` |
| `cases/{id}/messages/{msgId}` | 692 | cases | `onCaseMessageCreated` | `case_message_model.dart` |
| `cases/{id}/reporter/identity` | 720 | cases | — (Confidential split) | — |
| `requests/{requestId}` | 748 | requests | `onRequestCreated`, `onRequestUpdated` | `request_model.dart` |
| `requests/{id}/events/{eventId}` | 773 | requests | `onRequestEventCreated` | `request_event` |
| `attendance/{recordId}` | 806 | attendance | `onAttendanceWritten`, `autoCloseAttendance` (cron) 🖥️ | `attendance_model.dart` |
| `attendance/{id}/events/{eventId}` | 833 | attendance | derived by `onAttendanceWritten` 🖥️ | — |
| `attendance_corrections/{id}` | 860 | attendance | `onAttendanceCorrectionWritten` 🖥️ | `attendance_correction_model.dart` |
| `counters/{counterId}` | 905 | core | — | — |
| `usageStats/{doc}` | 914 | statistics | — (⚠️ no analytics pipeline — ADR-009) | — |
| `audit_logs/{id}` | 935 | audit | — (append-only) | `audit_log_model.dart` |

> ⚠️ **chat has NO Firestore collection.** Direct chat lives on the external **NestJS API** (`drop-api`)
> with a **Drift** local cache (`chat_database.dart`). Do not look for chat data in Firestore.

## ⚡ Cloud Functions catalogue (23) — grouped by trigger

`functions/index.js` unless noted.

**Callable (client → server, 🖥️ privileged writes)**
| Function | Does | Called from |
|---|---|---|
| `createUserAccount` | provisions a user (auth + `users` doc, temp password) | admin CreateAccountScreen |
| `adminResetPassword` | admin-issued password reset | admin |
| `sendBroadcast` | fan-out a broadcast to audience | communications |
| `sendNotification` | create a notification doc (→ FCM) | many features |
| `approveSwap` | atomically approve a shift swap | schedule |
| `claimFcmToken` | 🧠 enforce **one-owner** FCM token (anti-leak on shared devices) | on `users` update |

**Firestore triggers (server reacts to a write)**
| Function | Trigger path |
|---|---|
| `onNotificationCreated` | `notifications/{id}` create → push FCM |
| `onCaseCreated` / `onCaseUpdated` | `cases/{id}` |
| `onCaseMessageCreated` | `cases/{id}/messages/{msgId}` |
| `onRequestCreated` / `onRequestUpdated` | `requests/{id}` |
| `onRequestEventCreated` | `requests/{id}/events/{eventId}` |
| `onAttendanceWritten` | `attendance/{id}` → derive `events`, apply corrections |
| `onAttendanceCorrectionWritten` | `attendance_corrections/{id}` |
| `onRecurringTemplateWritten` | `recurringTaskTemplates/{id}` |

**Scheduled (cron)**
| Function | Cadence | Job |
|---|---|---|
| `runBroadcastSchedules` | 5 min | fire due broadcast schedules |
| `runTaskReminders` | 30 min | send task reminders from `taskReminders`/`reminderConfig` |
| `generateShiftTaskInstances` | (cron) | spawn recurring shift-task instances from schedule |
| `autoEndRecurringShiftTasks` | (cron) | close recurring shift tasks at shift end |
| `autoCloseAttendance` | 30 min | 16h max-session auto-close (also `attendance_auto_close.js`) |
| `broadcastHousekeeping` / `taskHousekeeping` | 24 h | GC / lifecycle sweeps |

Sibling files: `functions/automation_run.js`, `functions/recurring_task_deadline.js`,
`functions/attendance_auto_close.js` (each has a `functions/test/*.test.js`).

## 🔐 Rules reading protocol

1. Open `firestore.rules`, jump to the line in the table above.
2. Each block gates `read` / `create` / `update` / `delete` independently — check the exact verb you touch.
3. 🧠 **The `get(key, null) == null` invariant** (see [`05_DANGER.md`](05_DANGER.md)): optional fields are
   *present-with-null*, never absent. A `== ''` default **denied every task create in production**. Always
   default optionals to `null`.
4. Rules have an emulator harness at `firestore-tests/` — **add a case whenever you touch `firestore.rules`.**

## 🖼️ Storage (media)

- One upload seam: `core/media/media_upload_service.dart` (`MediaUploadService`) — used by task/case/request/chat.
- Rules: `storage.rules` → `validMedia()`. Processing (crop/compress): `core/media/media_processing.dart`.

Next: [`04_EDIT_IF.md`](04_EDIT_IF.md) — turn an intent into an edit list.
