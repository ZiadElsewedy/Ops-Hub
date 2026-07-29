# Firestore rules tests

Executable checks for `firestore.rules`, run against the **Firestore emulator**
with the real rules file and the **real payloads the app sends**.

```bash
cd firestore-tests && npm install   # once
npm test
```

Requires the Firebase CLI and a JDK (the emulator is a Java process). Nothing
here talks to production; the emulator runs on a throwaway project id.

## Why this directory exists

A rules regression shipped to production on 2026-07-28 that denied **every task
creation**. The 1100+ Dart tests could not catch it: they exercise `TaskCubit`
against a fake repository and never evaluate `firestore.rules` at all. Rules were
the one production-critical artifact in this repo with no test.

The bug was a single wrong default:

```
request.resource.data.get('cancelReason', '') == ''    // ✗ always false
```

`map.get(key, default)` returns the default **only when the key is absent**.
`TaskModel.toMap()` always emits every key, so an unset optional arrives as
*present-with-null* — the call returns `null`, and `null == ''` is false.

**The rule for this codebase: nullable task fields default to `null`, never
`''`.** `get(key, null) == null` is correct for both a legacy document (key
absent) and a current one (key present, value null), which is also what keeps the
rules backwards-compatible.

## What is covered

- **Backwards compatibility** — the same operation is asserted against both a
  current document (every key present, optionals null) and a legacy one (the new
  keys absent entirely).
- **Task creation** with the exact `TaskModel.toMap()` payload.
- **Cancellation** (spec §5) — allowed from `pending`/`started` with a picklist
  reason; denied from `waitingReview`, without a reason, and for employees.
- **Report incorrect** (§5.2) — an employee may file under their own uid only,
  never over an open report, and never clear one.
- **Admin terminal correction** (§6.4) — admin only, `missed`/`cancelled` →
  `pending`.
- **Standing guarantees** — `missed` is server-only, terminals are frozen and
  undeletable, employees cannot forge review attribution, and reads stay scoped.

Add a case here whenever you touch `firestore.rules`.
