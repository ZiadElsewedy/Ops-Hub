# ADR-023 — One account, one signed-in device, enforced only in the auth layer

**Status:** Accepted · **Date:** 2026-08-06

## Context

OpsHub is admin-provisioned: an admin creates each account and hands over a temporary
password. Nothing stopped that password from being used on five phones at once — so
one employee's credentials could put five people inside the branch's operational
data, and an account handed to a departing employee stayed live on their personal
device until someone thought to deactivate it. Attendance makes this concrete: the
clock-in write is deliberately allowed offline at a branch, so a second signed-in
device is a second thing that can punch.

The request was **single active session**: a newer sign-in wins, every older device
is signed out immediately and told why.

Three forces shape where this lives:

- **It must not be a per-feature concern.** The obvious wrong shape is "Chat checks
  the session, then Attendance checks it too" — that is N places to forget, N places
  to disagree, and exactly the duplication [ADR-010](ADR-010-lean-over-enterprise.md)
  exists to refuse.
- **The stream already exists.** `AuthCubit.watchCurrentUser` has streamed
  `users/{uid}` since day one, to catch an admin deactivating an account mid-session
  and to catch a hard-deleted document. A session claim on that same document is a
  field on a snapshot the app is already paying for.
- **The failure mode is an outage, not a bug.** Every mistake in this feature signs
  real people out of a tool they are standing in a shop using. The design has to
  fail *closed on eviction* and *open on uncertainty*.

## Decision

**Enforce single active session in exactly one place: the auth layer's existing
user-document watcher. No feature implements any part of it.**

Sign-in mints a 128-bit id (`auth/domain/session_id.dart`), claims it on
`users/{uid}.activeSessionId`, and stores it on the device in the platform keystore
(`core/services/session_store.dart`, `flutter_secure_storage`). Every emission of the
watcher compares the two; a mismatch runs the same teardown a deliberate sign-out
runs, then emits `unauthenticated(signedOutReason:)` so Login can say why.

Three corollaries follow, each of which is the decision as much as the rule above:

**1. Uncertainty is never an eviction.** A null *remote* claim (every legacy
document, and every account that has not signed in since this shipped) and a null
*local* claim (an unreadable keystore) both mean "stay signed in". The alternative
signs the entire company out on upgrade day, and makes a keychain hiccup
indistinguishable from a hostile login.

**2. A failed claim fails the sign-in.** If the claim write does not land, the device
holds an id the server never recorded and would evict itself on the very next
snapshot. Refusing the sign-in with *"Could not start your session"* is honest;
entering the app and being ejected a second later is not.

**3. Eviction and sign-out share one teardown.** Both go through
`AuthCubit._signOutInternal`, so an eviction can never clean up less than the
Settings button does. Building that path exposed and fixed a pre-existing leak: the
app-wide cubits are singletons built once at `init()`, so **ordinary sign-out** left
their Firestore listeners and `AttendanceCubit`'s ticker running against a
signed-out user, and showed the next person on that device the previous user's
tasks, cases, requests and attendance. `AppDependencies.clearUserScopedState()` is
now the one answer to "what is torn down when a session ends".

**This is deliberately client-enforced.** No Cloud Function, no
`revokeRefreshTokens`, no rules change — `activeSessionId` is not in the privileged
freeze-list of the `users` update rule, so the owner-update clause already permits
the self-write.

## Consequences

**What we get.** One account is one device. The whole feature is one field, one
comparison, and one teardown path; a new feature inherits it for free by doing
nothing. It costs zero additional Firestore listeners and one extra document write
per sign-in.

**What it costs.**

- **It is session hygiene, not a security boundary.** A modified client can simply
  not watch the document, or not claim. Anyone who genuinely needs revocation must
  add `admin.auth().revokeRefreshTokens(uid)` server-side; this ADR is not superseded
  by that, it is the client half of it.
- **One new native dependency** (`flutter_secure_storage`). It holds exactly one
  value and is confined to `core/services/session_store.dart`. It is **not** a new
  home for preferences — those stay uid-namespaced JSON files, and
  `shared_preferences` stays banned.
- **A legitimately shared device is now friction.** Two people alternating on one
  branch iPad sign each other out every time. That is the intended behaviour, and it
  is worth stating plainly because it is the first complaint this will generate.
- **Losing the keystore value loses the claim.** A device that cannot read the
  keychain does not evict itself (rule 1), so it keeps its session until its next
  sign-in re-claims. Failing open here is chosen over locking someone out of a shift.
- **Every app-wide cubit that gains a live stream now has an obligation** — a
  `reset()`, listed in `clearUserScopedState()`. Forgetting it reintroduces the leak
  this change fixed, and nothing will fail to compile.

## Amendment (2026-08-07) — the comparison needs a server-confirmed snapshot

The first field report was a **false eviction**: sign in on device A, sign out on
A, sign in on device B → B announced *"Your account has been signed in on another
device"* the instant it entered the app, with no second device involved.

Firestore's `snapshots()` replays the **locally cached** document the moment you
subscribe, before the backend says anything. A device that has been signed in
before therefore receives its *previous* session's `activeSessionId` as the
watcher's first emission, while it already holds the id it just claimed — and the
comparison read that as a hostile login. The very first device on a fresh account
never hit it: its cached document carried a null id, which rule 1 already ignores.
That is why the feature looked correct until a second device existed.

Two changes, both narrow:

1. **`watchUser` emits server-confirmed snapshots only** (`!metadata.isFromCache`).
   Every consumer of that stream acts destructively — deactivated, hard-deleted,
   taken over — so none of them should ever act on a cached copy. Offline simply
   means no emissions, which matches *offline gates the writes, never the app*.
2. **The superseded id is forgiven once.** `AuthCubit` remembers the id it
   replaced at sign-in and ignores a snapshot still reporting exactly that value,
   until its own claim comes back. Deliberately one value and not a blanket grace
   period: any *other* mismatch still evicts on the spot, so a genuine takeover
   racing a sign-in is enforced live rather than deferred to the next cold start.

The general lesson, worth more than this feature: **a cached snapshot is not
evidence, and any rule that ends a session must be server-confirmed.**

## Related

[AUTH § Single active session](../design/AUTH.md#single-active-session) ·
[ADR-005](ADR-005-server-authoritative-writes.md) ·
[ADR-010](ADR-010-lean-over-enterprise.md)
