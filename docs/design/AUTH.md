# Auth & Profile — admin-provisioned identity

OpsHub has **no public registration**. An admin creates every account. There is no
sign-up, no Google sign-in, no phone/OTP, no email-verification gate, and no
approval queue — all of those existed once and were removed (2026-06-26).

The unauthenticated landing screen is **Login**.

## Provisioning

```
Admin → CreateAccountScreen → callable `createUserAccount`  (Admin SDK)
                                   ├── creates the Auth user
                                   └── seeds users/{uid}
```

`firestore.rules` has `users` **`create: if false`** — the function is the only path.
It runs Admin-SDK-side specifically so the acting admin's own session is never
replaced (calling `createUser` client-side would sign them out).

The **first admin** is bootstrapped out of band in the Firebase console
(`role: admin`, `isActive: true`).

`adminResetPassword` sets a temp password and re-arms the force-change flag.

## First-login gate

Ordered, evaluated before role dispatch. The ordering is the pure, unit-tested
**`firstLoginLocation(user)`**:

```
mustChangePassword        → /force-password-change
!isProfileCompleted       → /complete-profile
!hasCompletedOnboarding   → /welcome        (employees only, one time)
otherwise                 → RouteNames.homeForRole(role)
```

`hasCompletedOnboarding` **defaults `true`** so existing users are never interrupted,
and is seeded `false` at profile completion — so a new employee sees the Welcome
exactly once. Each gate screen flips its flag then calls `refreshUser()`, and the
router advances on its own.

## Access

`UserEntity.hasAppAccess` is just `isActive`. A deactivated account never reaches the
router as authenticated: `AuthCubit` signs it out at login **and** mid-session via
`watchCurrentUser`, surfacing "This account has been disabled".

The redirect **only** bounces an *explicitly* `unauthenticated` session to Login —
transient `loading` / `passwordChanged` / `error` states do not redirect, so an
in-flight forced password change never flickers the user out.

Because a Firebase sign-in doesn't know role or flags, `AuthCubit` re-reads Firestore
(`_withStoredProfile`) so the emitted authenticated state carries the authoritative
role/branch + gates.

## Single active session

**One account = one signed-in device.** A newer sign-in evicts every older one.

```
sign-in ─→ generateSessionId()          128 bits, 32 hex chars
        ─→ users/{uid}.activeSessionId  the claim (AuthRepository.claimSession)
        ─→ SessionStore.write(id)       this device, in the platform keystore
        ─→ watchCurrentUser()           the existing user-doc stream

every emission: remote activeSessionId != local id  ⇒  evict
```

**It is enforced in exactly one place** — `AuthCubit.watchCurrentUser`, the stream
the app already ran to catch deactivation and hard-deletion. So enforcement costs
**no extra listener**, and **no feature implements it** — Chat, Tasks, Attendance
and the rest inherit it because they only ever see an authenticated session.

Three entry points check the claim, because each can re-emit `authenticated`
without passing through the watcher: `signInWithEmail`, `restoreSession` (the
takeover that happened while the app was closed — Firebase restores its own
session silently, so this is the only place it becomes visible), and
`refreshUser` (the first-login flows each end in one).

| Piece | Where |
| --- | --- |
| Mint the id | `auth/domain/session_id.dart` — `generateSessionId` (pure) |
| Store it on this device | `core/services/session_store.dart` — `SessionStore` contract, `SecureSessionStore` (Keychain / `EncryptedSharedPreferences`), `InMemorySessionStore` (tests) |
| Claim it on the account | `AuthRepository.claimSession` → `UserRemoteDataSource.claimSession` |
| Enforce it | `AuthCubit._isSessionTakenOver` + `_endSession` |
| Tear down | `AuthCubit._signOutInternal` → the DI `onPreSignOut` hook → `AppDependencies.clearUserScopedState()` |
| Tell the user | `AuthState.unauthenticated(signedOutReason:)` → `LoginPage`, consumed once via `acknowledgeSignOutReason` |

### Rules that keep it from misfiring

- **Neither null is an eviction.** A null *remote* id means "no claim on record" —
  every legacy document, and every account that has not signed in since this
  shipped. Treating it as a mismatch would sign the whole company out the moment
  the build lands. A null *local* id means an unreadable keystore or a device from
  before the feature; a keychain hiccup must never look like a hostile login.
- **A failed claim fails the sign-in.** Entering the app holding an id the server
  never recorded means evicting yourself on the very next document snapshot — which
  reads to the user as *"it signed me out instantly"*.
- **The claim is written by one method.** `activeSessionId` is deliberately absent
  from `UserModel.toMap()`, so a routine profile save cannot re-stamp a stale id and
  let an evicted device steal the session back.
- **A deliberate sign-out clears the LOCAL id only.** Clearing the remote one would
  *release* the account for whichever stale device still holds a matching id.
- **Eviction and sign-out share one teardown** (`_signOutInternal`), so an eviction
  can never clean up less than the Settings button does.
- **Only a server-confirmed snapshot may evict** (fixed 2026-08-07). `snapshots()`
  replays the locally cached document on subscribe, so a device that has signed in
  before receives its *previous* session's id as the watcher's first emission —
  which evicted the device that had just signed in. `watchUser` now filters
  `metadata.isFromCache`, and `AuthCubit` additionally forgives the **one** id it
  superseded until its own claim comes back. Any other mismatch still evicts on the
  spot. **A cached snapshot is not evidence.**

**No rules change and no deploy.** `activeSessionId` is not in the privileged
freeze-list of the `users` update rule, so the existing owner-update clause already
permits the self-write.

> ⚠️ **This is session hygiene, not a security boundary.** It is client-enforced: a
> modified client could simply not watch the document. Real revocation is
> `admin.auth().revokeRefreshTokens(uid)` in a Cloud Function, which is the upgrade
> path if this ever needs to survive a hostile client.

Why it lives here and nowhere else:
[ADR-023](../decisions/ADR-023-single-active-session.md). Pinned by
[test/single_active_session_test.dart](../../test/single_active_session_test.dart).

## Chain

```
LoginPage · ForgotPasswordPage · ForcePasswordChangePage · ProfileCompletionPage
        ↓  context.read<AuthCubit>()
AuthCubit
        ↓  one use case per action (+ flag writes via the repo)
SignInWithEmail · ForgotPassword · ChangePassword · GetUser · SignOut
        ↓
AuthRepository  →  AuthRepositoryImpl
        ↓                    ↓
AuthRemoteDataSource   UserRemoteDataSource
  (FirebaseAuth,          (users/{uid})
   email only)
```

`AuthRepositoryImpl` holds **two** datasources and maps `UserModel ⇄ UserEntity`.
Contract: `signInWithEmail` · `signOut` · `getUser` · `getUsersByBranch` ·
`getAllUsers` · `watchUser` · `sendPasswordResetEmail` · `changePassword` ·
`claimSession`, plus the self-flag setters `setMustChangePassword` /
`setProfileCompleted`.

`getUsersByBranch` serves the branch-scoped features (task assignee, roster,
schedule). `getAllUsers` is the unfiltered read backing the **chat directory**,
whose access model is flat — anyone may message anyone
([ADR-012](../decisions/ADR-012-chat-directory-is-flat.md)).

`AuthState`: initial · loading(AuthAction) · authenticated(UserEntity) ·
unauthenticated({signedOutReason}) · passwordResetSent · passwordChanged · error.
`signedOutReason` is set **only** when the app ended the session on the user's
behalf (today: single-active-session eviction) and is consumed once by Login.
`AuthAction` = {emailSignIn, forgotPassword, changePassword} — it exists so the UI
spins only the button that was pressed.

## Roles

Parse with **`UserRole.fromString`**, which **defaults unknown/missing to
`employee`** — a malformed document can never escalate privileges. Use the
`isAdmin` / `isManager` / `isEmployee` / `isGlobal` getters rather than re-comparing.

Privileged fields (`role`, `branchId`, `isActive`, `assignedShift`, `position`,
`employmentStatus`, `createdBy`, `mustChangePassword`, `isProfileCompleted`) are kept
**out of `UserModel.toMap()`** so a routine profile write cannot reset admin-owned
state — and rules enforce the same freeze independently. `activeSessionId` is
excluded for a different reason (see [Single active session](#single-active-session)):
it has exactly one writer, `claimSession`.

Full rule matrix: [DATA_MODEL](DATA_MODEL.md).

## Profile

`users/{uid}` is **shared** between `auth` (`UserModel`) and `profile`
(`ProfileModel`) — one document, two mappers. `ProfileModel` is back-compat: it falls
back to the legacy `displayName`/`photoUrl` keys and `editMap` keeps them in sync on
write.

`ProfileRepositoryImpl` also depends on `AuthRemoteDataSource` to mirror
`fullName`/`profileImage` into the Firebase Auth profile — best-effort, never fatal,
so Home stays current without a re-login.

**`ProfileCubit.loadProfile(uid)` is idempotent.** Once a uid is in memory (loaded
*or* updated via `save` — both stamp `_loadedUid`), revisiting the screen skips the
Firestore re-read and the skeleton flash. `forceRefresh` overrides, and the Profile
screen's **pull-to-refresh** and its error-state **Retry** are the only callers that
pass it — ordinary navigation must not.

### The account hub, and Profile's place in it

**Settings is the hub. Profile is a leaf of it.**

```
mobile app-bar avatar ─┐
                       ├─→ /settings ──→ /profile ──→ /profile/edit
desktop sidebar footer ┘        │
                                ├─→ /settings/notifications · /settings/change-password
                                ├─→ /cases · /settings/about
                                └─→ Sign out          ← the ONLY one in the app
```

Every account destination hangs off Settings, and Settings' identity card is the only
route to Profile. **Profile therefore carries no navigation rows and no Sign out.**
Before 2026-08-07 it carried both, so Settings → Profile → Settings was a closed loop
and the app's one destructive action existed on two screens. Adding an account
destination means adding it to Settings — never to Profile.

The desktop sidebar footer opens **Settings**, not Profile, for the same reason: it is
the only account door on desktop (the sidebar has no Settings destination), so pointing
it at a leaf both made Profile top-level on one platform and a leaf on the other, and
left desktop with no route to Sign out.

`ProfilePage` shares Settings' row vocabulary (`core/widgets/settings_tiles.dart` — one
grouped glass card, inset hairlines, 40px medallions) so the two read as one system.
What is specific to it:

- **`ProfileIdentityCard`** — cover (`coverImage`) under a scrim, overlapping avatar,
  the name on its own line, `[ROLE] @handle` beneath it, `bio`, and the screen's one
  CTA. Role comes from the **auth session**, never the profile document: privileged
  fields are deliberately kept off `ProfileEntity`. It is deliberately compact, and
  the layout is **width-driven, not taste** — at 390pt a chip row beside the CTA
  wraps, and a role chip beside the name truncates it. Keep the name alone on its
  line; put any new fact in a group, not here.
- **`ProfileDetailRow`** — caption above, value in the bright step of the ramp.
  **Tapping a row the user owns opens Edit Profile**, whether or not it has a value;
  **copying is a separate 44pt trailing button**, so the two never contend for one
  gesture. `onEdit: null` (email, branch, account facts, and *every* contact row for
  an admin) makes the row inert, with no `InkWell` to press.
- Facts group as **Workplace · Contact · Account**.
- **An admin has no `branchId`**, so the Workplace group states *All branches ·
  organisation-wide* rather than rendering an empty branch row.

### Contact & compensation

`address` / `emergencyContact` / `paymentNumber` live on `ProfileEntity`. Contact
fields sit on `users/{uid}`; **`paymentNumber` lives in
`users/{uid}/private/compensation`** — the datasource overlays it on read and writes
it there (`editMap` never emits the key).

Edit Profile exposes Contact details + Salary payment number **for managers and
employees only — hidden for admin**. Owner ruling: the admin manages compensation and
has no manager to be reached by. An admin save never writes those fields, and the
Profile page offers an admin no *add* door on an unset contact row — the form they
would land on has no such field. The admin-only salary fields (amount/type/method)
are **not** part of the profile contract.

### The username

`username` is the `@handle` every profile surface shows and the only profile field
with a **uniqueness** rule: `CheckUsername` queries `users` for the lowercased value,
`ProfileRepositoryImpl` lowercases on write, and `ProfileCubit.save` refuses a taken
handle *before* any upload or write. It is edited in **Edit Profile**, validated by
`Validators.username` (3–20 chars of letters · digits · `.` · `_`, starting with a
letter — ASCII on purpose; the Unicode display name is `fullName`).

> ⚠️ It had **no input anywhere in the app** until 2026-08-07, while
> `ProfileEntity.isComplete` requires it — so every account read as incomplete
> forever and the Profile prompt could never be satisfied. If you add another
> field to `isComplete`, add its input in the same change.

**Profile never states `paymentNumber`** (owner ruling, 2026-08-07) — for any role.
It is set and changed in **Edit Profile** only; the read-only profile has no payroll
section. The field itself is unchanged in the schema and in `users/{uid}/private/compensation`.

## Known gaps

- **Account deletion** removes the Auth user but leaves `users/{uid}` — needs an
  `auth.user().onDelete` function.
- **Legacy social fields** (`followersCount` / `followingCount` / `postsCount` /
  `likesCount`) are unused. Read defensively; safe to delete.

## Related

[DATA_MODEL](DATA_MODEL.md) · [ADR-005](../decisions/ADR-005-server-authoritative-writes.md)
