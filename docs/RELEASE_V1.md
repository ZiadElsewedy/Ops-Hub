# DROP — v1.0 Stable Release Plan

> **The runbook for shipping v1.** Everything that must be true before the first
> stable build reaches a real user, in the order it must happen.
>
> **Audited against code and live production:** 2026-08-05.
> Verification method for every claim below is stated inline — where it says
> *verified*, it was read from the live project or run locally in this audit, not
> taken from a doc.
>
> Related: [QA.md](QA.md) is the on-device test script. [CURRENT_STATE.md](../CURRENT_STATE.md)
> is today's snapshot. This file is the **release gate** — it dies when v1 ships.

---

## 0 · Where v1 actually stands

**Verdict: the code is ready and now deployed; the release configuration and the
operational safety net are not.** Every automated gate is green and both
platforms produce a release artifact. The two stale production deploys were
**closed on 2026-08-05 18:32–18:40 UTC** (B3 · B4 below). What still blocks v1 is
packaging (Android identity + signing), no push credential on iOS, no crash
visibility, no database backups, and QA that has never touched real hardware.

### Automated gates — all green (run 2026-08-05)

| Gate | Command | Result |
| --- | --- | --- |
| Analyzer | `flutter analyze` | **1 info**, 0 errors/warnings — the pre-existing `use_null_aware_elements` lint in `test/task_submission_gate_test.dart` |
| Dart suite | `flutter test` | **1884 pass · 0 fail** (~41s, 2026-08-07) |
| Cloud Functions | `cd functions && node --test` | **143 pass · 0 fail** (2026-08-07) |
| Firestore rules | `cd firestore-tests && npm test` | **68 pass · 0 fail** |
| iOS release build | `flutter build ios --release --no-codesign` | **✓ built** — `Runner.app`, 87.4 MB |
| Android release build | `flutter build appbundle --release` | **✓ built** — `app-release.aab`, 93.1 MB |

### Live production state — `bazic-d9ad7` (read directly, 2026-08-05)

| Target | State | Evidence |
| --- | --- | --- |
| **Functions (automation P0)** | ✅ **DEPLOYED** | `generateShiftTaskInstances`, `runTaskReminders`, `autoEndRecurringShiftTasks` all rolled **2026-08-05 13:16 UTC**, state `ACTIVE`. The fix commit (`71792e7`) landed 02:38 UTC — the deploy is later, so it carries the fix. **CURRENT_STATE.md's 🚨 banner was stale.** |
| **Functions (sales)** | ✅ **DEPLOYED** | All 5 rolled to revision `…-00002-*`, state `ACTIVE`, **2026-08-05 18:34 UTC** — after the audit commit (`2cf7e13`, 12:29 UTC). Verified via `gcloud functions describe`. |
| **Functions (broadcast schedules)** | ✅ **DEPLOYED** | `runBroadcastSchedules` failed the batch deploy at 18:34 on a transient Cloud Scheduler API call; redeployed alone → `runbroadcastschedules-00018-nud`, `ACTIVE`, **18:40:27 UTC**. Its Cloud Scheduler job is `ENABLED`, `every 5 minutes`, and firing. |
| **Firestore rules** | ✅ **IN SYNC** | Live ruleset released **2026-08-05 18:32:57 UTC** and **byte-identical to `firestore.rules`** — diffed against the Rules API. Carries `branchRunsSalesTargets()` and the `branch_sales_submissions` create gate. |
| **Firestore indexes** | ✅ **IN SYNC** | 19 live composites, 19 in `firestore.indexes.json`, all matched, all `READY`. |
| **Storage rules** | ✅ **IN SYNC** | Live ruleset byte-identical to `storage.rules`. |
| **Hosting (privacy policy)** | ✅ **LIVE** | `https://bazic-d9ad7.web.app` → 200. |
| **Chat API (Railway)** | ✅ responds 200 | `https://drop-api-production.up.railway.app` — separate repo, not audited here. |
| **Firestore backups** | ❌ **NONE** | PITR `DISABLED` · **zero backup schedules** · delete protection `DISABLED`. |

---

## 1 · Blockers — v1 cannot ship until every one is done

### B1 · Android application ID is `com.example.dropoperation` 🔴

`android/app/build.gradle.kts` still carries the Flutter template's
`applicationId` and `namespace`. **Google Play rejects any `com.example.*`
package outright**, and the ID is permanent after the first upload — this is the
single most expensive thing to get wrong.

Cascade once it changes:

1. Pick a real reverse-DNS you control (e.g. `com.dropheshop.operations`).
2. Update `namespace` **and** `applicationId` in `android/app/build.gradle.kts`;
   delete both `// TODO` template comments.
3. Register a **new Android app** in Firebase under the new package →
   download a fresh `android/app/google-services.json`. The current one is
   registered for `com.example.dropoperation` and will stop matching.
4. Add the **upload keystore SHA-1 + SHA-256** and, once enrolled, the
   **Play App Signing** certificate fingerprints to that Firebase app.
5. Rebuild and confirm FCM token registration works on a real Android device.

> The old `com.example.dropoperation` Firebase app should be left in place until
> the new one is confirmed working, then removed.

### B2 · Android release builds are signed with the debug keystore 🔴

```kotlin
release {
    signingConfig = signingConfigs.getByName("debug")   // template default
}
```

Play rejects debug-signed uploads. Required:

- Generate an upload keystore (`keytool -genkey -v -keystore upload-keystore.jks
  -keyalg RSA -keysize 2048 -validity 10000 -alias upload`).
- Store it **outside the repo**; add `android/key.properties` (path, passwords,
  alias) and **gitignore it** — `.gitignore` does not currently cover it.
- Wire a real `signingConfigs.release` block reading `key.properties`, and point
  the release build type at it.
- Enrol in **Play App Signing** so a lost upload key is recoverable.

### B3 · Firestore rules deploy — ✅ DONE (2026-08-05 18:32:57 UTC)

The live ruleset is now **byte-identical to `firestore.rules`**, read back from
the Rules API and diffed — not taken from the CLI's word. It carries
`branchRunsSalesTargets()` and the `branch_sales_submissions` create gate, so a
client can no longer create a submission for a branch that has not opted into
sales targets.

### B4 · Sales Cloud Functions deploy — ✅ DONE (2026-08-05 18:34 UTC)

`setBranchSalesTarget` · `decideDailySalesSubmission` ·
`editApprovedDailySalesSubmission` · `resubmitCorrectedSales` ·
`onDailySalesSubmissionCreated` all rolled to revision `…-00002-*`, state
`ACTIVE`, **after** the audit commit (`2cf7e13`, 12:29 UTC) — so the opt-in
precondition on `setBranchSalesTarget` is live.

⚠️ **`runBroadcastSchedules` failed in that same batch** and needed a second,
targeted deploy. The error was `Failed to make request to
https://cloudscheduler.googleapis.com/v1/.../jobs/firebase-schedule-runBroadcastSchedules-us-central1`
— **not** a code or permission fault: the container had already rolled, and the
CLI failed on the trailing Cloud Scheduler job upsert. A batch deploy that ends
with *"Deploys failed. Skipping deletes"* for exactly one scheduled function is
this. Redeploy that function alone; do **not** re-run the whole batch.

```bash
firebase deploy --only functions:runBroadcastSchedules --project bazic-d9ad7
```

Whatever the CLI reports, **verify the revision moved** — the CLI reporting
success is not proof (this bit the swap-attribution deploy on 2026-08-05), and
for a scheduled function verify the job as well:

```bash
gcloud functions describe setBranchSalesTarget --region=us-central1 --project=bazic-d9ad7 --gen2 --format="value(state,updateTime,serviceConfig.revision)"
```

```bash
gcloud scheduler jobs describe firebase-schedule-runBroadcastSchedules-us-central1 --location=us-central1 --project=bazic-d9ad7 --format="value(state,schedule,lastAttemptTime)"
```

### B5 · iOS push has no APNs credential 🔴

The **app side is complete and verified**: `Runner.entitlements` supplies
`aps-environment`, `remote-notification` is a declared background mode, and
`notification_service.dart` waits for the APNs token before calling `getToken()`.
What is missing is the credential itself.

- Create an **APNs Auth Key (.p8)** in the Apple Developer portal (Keys → Apple
  Push Notifications service).
- Upload it in Firebase Console → Project Settings → Cloud Messaging → the
  **iOS app** (`com.ziad.drop`), with the Key ID and Team ID (`7Q3PY75VGH`).
- ⚠️ `aps-environment` is `development` in `Runner.entitlements`. Xcode rewrites
  it to `production` when exporting for App Store / TestFlight distribution —
  **but verify it on the actual TestFlight build.** A build that gets push in
  development and silence in TestFlight is exactly this.

Without this, **iOS gets zero push**, which is most of what the notifications,
tasks, cases, requests and chat features are for.

⚠️ **This entry needs re-verification — it may already be done (2026-08-07).**
The owner reports that push **works today**: notifications arrive on the lock
screen and tapping one opens the right screen. FCM cannot deliver to iOS at all
without an APNs credential, so delivery working implies the `.p8` is uploaded
and this blocker is stale. **Confirm in Firebase Console → Project Settings →
Cloud Messaging** before the release checklist counts it as closed, and keep the
`aps-environment` development-vs-production warning above — it is the half that
can still break specifically on TestFlight.

### B6 · Attendance has never been QA'd on real hardware 🔴

Per the project's own rule: *attendance minutes feed payroll — do not ship it on
a simulator's word.* GPS, geofence radius, permission-denied and
location-services-off states cannot be validated on a simulator.

Run [QA.md §3 T1–T12](QA.md) on a real device at a real branch, both platforms.

### B7 · The app has never been run on Android 🔴

The bundled-typeface bug shipped unnoticed for months because nothing exercised
Android. That is a QA gap, not a font bug — and it is still open. A full
[QA.md](QA.md) pass on a physical Android device is a v1 gate, not a nice-to-have.

### B8 · No Firestore backups, PITR, or delete protection 🔴

Verified live: point-in-time recovery **disabled**, **zero** backup schedules,
delete protection **disabled**. A single bad write, a mistaken rules deploy, or
an accidental console delete is unrecoverable today — on a database holding
attendance records that feed pay.

```bash
# daily backups, 7-day retention
gcloud firestore backups schedules create --database='(default)' \
  --recurrence=daily --retention=7d --project=bazic-d9ad7

# point-in-time recovery + delete protection
gcloud firestore databases update --database='(default)' \
  --enable-pitr --enable-delete-protection --project=bazic-d9ad7
```

Both require the **Blaze** plan, which the project is already on.

---

## 2 · Should-fix before v1 — cheap, and each one bites later

### H1 · No production crash reporting

`CrashReporter` persists to `last_crash.log` inside the app's Application Support
directory. Nobody will ever read it — a user's crash is invisible to you.
Firebase is already fully wired, so `firebase_crashlytics` is roughly an hour of
work and is the single largest post-launch safety improvement available.
Route the four existing `CrashReporter` funnels into it rather than replacing
them, so the local report survives as an offline fallback.

### H2 · The version number is hardcoded in two places

- `lib/features/settings/presentation/pages/settings_page.dart:422` → `'1.0.0 (1)'`
- `lib/features/settings/presentation/pages/about_page.dart:368` → `'Version 1.0.0'`

Both will silently lie from 1.0.1 onward, and the App Version row is the first
thing anyone reads when diagnosing "which build are you on?". Add
`package_info_plus` and read the real `version`/`buildNumber`.

### H3 · `recurringTaskTemplates` read is not branch-scoped

[firestore.rules:437](../firestore.rules) — `allow read: if isAdmin() || isManager()`.
Any manager can read **every** branch's automation templates with a direct client
query. It contradicts the own-branch manager invariant in
[PROJECT_CONTEXT §8](../PROJECT_CONTEXT.md). Not reachable through the current
UI, but the rules layer is the boundary.

⚠️ **B3 shipped on 2026-08-05 without this fix** — it was to have ridden that
deploy and did not. It now needs a rules deploy of its own: fix the rule, add a
`firestore-tests/` case, `cd firestore-tests && npm test`, then
`firebase deploy --only firestore:rules` and re-diff the live ruleset.

### H4 · iOS `Info.plist` carries dev-only and dead configuration

| Key | Problem |
| --- | --- |
| `CFBundleURLTypes` | Declares a **Google Sign-In** reversed-client-id URL scheme. DROP has no Google sign-in — auth is admin-provisioned email/password only. Dead config a reviewer may ask about. Delete. |
| `NSAppTransportSecurity` | Allows `NSAllowsLocalNetworking` and insecure HTTP loads to `localhost` — the dev chat backend. Release builds are hard-locked to Railway HTTPS by `AppEnvironment`, so this buys nothing in production and weakens ATS. Remove for release. |
| `NSPhotoLibraryAddUsageDescription` | **Missing.** The schedule and attendance exports hand a PNG/PDF to the iOS share sheet, where *Save Image* is offered — saving without this key **crashes the app**. Add it. |
| `ITSAppUsesNonExemptEncryption` | Missing. Not a blocker; App Store Connect will prompt on every single upload until you set it (`false` for standard HTTPS-only use). |

### H5 · Repo hygiene

- **5,825 `node_modules/` files are tracked in git** at the repo root, plus
  `.firebase/hosting.*.cache`. `.gitignore` already covers both — they were
  committed before it did. `git rm -r --cached node_modules .firebase`.
- **`web/index.html` was overwritten with a privacy policy** (`044ea2e`), which
  removed the Flutter bootstrap. Flutter web will not build. Hosting does not
  read it either way. Restore it from git history or delete `web/` — leaving a
  broken bootstrap in place is the worst of the three.
- **`y/`** is the dead `firebase init` default page. Delete.
- **`compensation_backup_1783036515243.json`** sits untracked in the repo root
  and contains salary data. It is gitignored, but delete it from disk.
- **~15 stale feature branches** — prune after v1 tags.

### H6 · Decide the distribution channel — this changes the work

DROP is an internal tool for one company: **no public registration, no demo
account, nothing a reviewer can do without credentials.** A straight public App
Store submission is very likely to be rejected under Guideline 2.1 unless you
supply a working demo account in the App Review notes.

| Option | iOS | Android | Fit |
| --- | --- | --- | --- |
| **Private/managed** *(recommended)* | Apple Business Manager **custom app** | **Managed Google Play** private app | Matches what DROP is. No public listing, no review theatre. |
| **Testing tracks** | TestFlight | Play **internal testing** | Fastest to first install. Fine if the team is small; TestFlight builds expire in 90 days. |
| **Public stores** | App Store | Play production | Only if DROP will ever have outside users. Requires a demo account, full privacy/data-safety declarations, and public listing copy. |

Also note Apple **5.1.1(v)** (in-app account deletion): DROP has no in-app
account creation, which is the stated exemption — be ready to say so in review
notes rather than being surprised by it.

### H7 · Decide whether Chat ships in v1

Chat is 19 phases deep and marked **in progress**, with several phases explicitly
**not device-verified**, and it depends on an external NestJS backend on Railway
that has **no staging environment**. Its inbox N+1 fix is written but awaits a
`drop-api` deploy. Two honest options:

- **Ship it** — then a `drop-api` deploy and a two-device chat pass become v1
  gates, and a Railway outage becomes a v1 incident.
- **Hide it** — gate the nav destinations behind a flag and cut the whole
  external-backend dependency out of the v1 risk surface. Ship it in 1.1 once
  device-verified.

There is no third option where it ships unverified.

### H8 · macOS in or out?

`PROJECT_CONTEXT` lists macOS as a first-class platform and the desktop shell is
built. Shipping it means notarization, a hardened-runtime pass, and a third
distribution channel. If macOS is not a day-one need, **descope it to 1.1** and
say so — it does not affect the iOS/Android build.

---

## 3 · Sequenced plan

Order matters: server before client, always. A client build carrying a
contract the server has not deployed is how approved swaps got announced to
nobody.

### Phase 1 — Backend, today (½ day)

1. ✅ **Done 2026-08-05 18:32–18:40 UTC.** Rules + all 24 functions are live and
   verified (B3 · B4). **H3 did not make it into that rules change** — it still
   needs its own `firebase deploy --only firestore:rules`.
2. Verify each changed function's revision with `gcloud functions describe` —
   not the CLI's word. For a **scheduled** function also check its Cloud
   Scheduler job: the container can roll while the job upsert fails.
3. Re-fetch the live ruleset and diff it against `firestore.rules` until the diff
   is empty. *(Empty as of 18:32:57 UTC.)*
4. Enable **backups + PITR + delete protection** (B8).
5. Confirm **Firebase Storage is enabled** in the console ([QA.md](QA.md) P2) —
   a "not authorized" upload error is this, not a code bug.
6. Decide H7; if Chat ships, deploy `drop-api` and verify.

### Phase 2 — Release configuration (1 day)

7. **B1** — new application ID, new Firebase Android app, new `google-services.json`.
8. **B2** — upload keystore, `key.properties` (gitignored), real release signing config.
9. **B5** — APNs `.p8` uploaded to Firebase.
10. **H4** — Info.plist cleanup (delete the Google URL scheme + ATS block; add
    `NSPhotoLibraryAddUsageDescription` and `ITSAppUsesNonExemptEncryption`).
11. **H1** — Crashlytics.
12. **H2** — real version strings via `package_info_plus`.
13. **H5** — repo hygiene.
14. Set the release version: `version: 1.0.0+1` in `pubspec.yaml` is correct
    as-is for the first build. **Bump the `+build` on every upload**, never reuse one.
15. Re-run all six gates from §0. They must all still be green.

### Phase 3 — Device QA (2–3 days, the real cost)

16. Build a signed **TestFlight** build and a signed **Play internal testing**
    build.
17. Full [QA.md](QA.md) pass — sections 1–6 — on a **physical iPhone** and a
    **physical Android phone** (B7).
18. **Attendance §3 T1–T12 at a real branch** (B6). Verify a clock-in offline,
    then reconnect, produces exactly one record.
19. **Push on both platforms**, every notification type, foreground / background /
    killed. Confirm every tap lands on the right screen (the notification-tap
    fixes from 2026-08-05 are not device-verified).
20. **iOS swipe-back** over the horizontally-scrolling surfaces the code notes
    call out: `SegmentedTabBar`, the schedule week strip, the chat thread.
21. Confirm the first automation tick generates tasks and sends reminders — the
    P0 fix is deployed but has **never been observed working in production**.
    Watch one 01:00 Africa/Cairo run end to end.
22. Fill in the QA sign-off table at the foot of [QA.md](QA.md). It is empty today.

### Phase 4 — Ship (½ day)

23. Merge `release/v1-preparation` → `main`.
24. Tag `v1.0.0`.
25. Submit through the channel chosen in H6.
26. Update [CURRENT_STATE.md](../CURRENT_STATE.md) and [CHANGELOG.md](../CHANGELOG.md);
    delete this file.

**Realistic total: 4–6 working days**, of which device QA is the majority and
cannot be compressed.

---

## 4 · Exit criteria

v1.0.0 ships when **every** line is true:

- [ ] B1–B8 all closed.
- [ ] All six gates in §0 green on the exact commit being tagged.
- [ ] Live Firestore rules diff cleanly against `firestore.rules`.
- [ ] Every deployed function's revision verified with `gcloud functions describe`.
- [ ] Firestore daily backups + PITR + delete protection on.
- [ ] [QA.md](QA.md) sections 1–6 passed on a physical iPhone **and** a physical Android phone, with the sign-off table filled in.
- [ ] Attendance §3 T1–T12 passed on real hardware at a real branch.
- [ ] Push delivered and correctly routed on both platforms.
- [ ] One automation tick observed generating tasks in production.
- [ ] Crashlytics receiving events from a release build.
- [ ] No `last_crash.log` after a full QA pass.
- [ ] Chat decision (H7) made and executed either way.
- [ ] Distribution channel (H6) chosen; store/enterprise listing complete.

---

## 5 · Explicitly out of scope for v1

Named here so they do not creep in during the release run:

- Light theme (`AppTheme.light` exists, unwired — the app is hardcoded dark).
- Account deletion cleaning up `users/{uid}` (needs an `auth.user().onDelete`).
- The remaining attendance reporting slices — per-employee report, exception
  queue, branch comparison, period close, export ledger.
- Routine **editing** in the Automation Center (add/pause/delete only today).
- The auto-end sweep's `limit(500)` starvation path and the
  "a failed generation pages nobody" gap — both real, both known, neither
  new in v1.
- The Cairo DST divergence between the Dart client's hand-rolled rule and the
  callables' `Intl` tzdata. The server is authoritative for validation; a shared
  timezone source is the standing recommendation.
- macOS distribution, if descoped per H8.
