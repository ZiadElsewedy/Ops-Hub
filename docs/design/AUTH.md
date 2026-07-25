# Auth & Profile — admin-provisioned identity

DROP has **no public registration**. An admin creates every account. There is no
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
`getAllUsers` · `watchUser` · `sendPasswordResetEmail` · `changePassword`, plus
the self-flag setters `setMustChangePassword` / `setProfileCompleted`.

`getUsersByBranch` serves the branch-scoped features (task assignee, roster,
schedule). `getAllUsers` is the unfiltered read backing the **chat directory**,
whose access model is flat — anyone may message anyone
([ADR-012](../decisions/ADR-012-chat-directory-is-flat.md)).

`AuthState`: initial · loading(AuthAction) · authenticated(UserEntity) ·
unauthenticated · passwordResetSent · passwordChanged · error.
`AuthAction` = {emailSignIn, forgotPassword, changePassword} — it exists so the UI
spins only the button that was pressed.

## Roles

Parse with **`UserRole.fromString`**, which **defaults unknown/missing to
`employee`** — a malformed document can never escalate privileges. Use the
`isAdmin` / `isManager` / `isEmployee` / `isGlobal` getters rather than re-comparing.

Privileged fields (`role`, `branchId`, `isActive`, `assignedShift`, `position`,
`employmentStatus`, `createdBy`, `mustChangePassword`, `isProfileCompleted`) are kept
**out of `UserModel.toMap()`** so a routine profile write cannot reset admin-owned
state — and rules enforce the same freeze independently.

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
Firestore re-read and the skeleton flash. `forceRefresh` overrides. There is no
pull-to-refresh, so `save` is the only in-session mutation.

### Contact & compensation

`address` / `emergencyContact` / `paymentNumber` live on `ProfileEntity`. Contact
fields sit on `users/{uid}`; **`paymentNumber` lives in
`users/{uid}/private/compensation`** — the datasource overlays it on read and writes
it there (`editMap` never emits the key).

Edit Profile exposes Contact details + Salary payment number **for managers and
employees only — hidden for admin**. Owner ruling: the admin manages compensation and
has no manager to be reached by. An admin save never writes those fields, and the
Profile page hides the "Salary sent to" row for admin. The admin-only salary fields
(amount/type/method) are **not** part of the profile contract.

## Known gaps

- **Account deletion** removes the Auth user but leaves `users/{uid}` — needs an
  `auth.user().onDelete` function.
- **Legacy social fields** (`followersCount` / `followingCount` / `postsCount` /
  `likesCount`) are unused. Read defensively; safe to delete.

## Related

[DATA_MODEL](DATA_MODEL.md) · [ADR-005](../decisions/ADR-005-server-authoritative-writes.md)
