/**
 * DROP — Communications Center send engine.
 *
 * Callable `sendBroadcast`: the authoritative broadcast write + push pipeline.
 * Responsibilities:
 *   1. validate the sender's permissions (admin / manager matrix),
 *   2. resolve recipients (all users / a branch / one individual),
 *   3. persist the broadcast doc (`broadcasts/{id}`),
 *   4. fetch the recipients' FCM tokens (`users/{uid}.fcmTokens` [+ legacy
 *      single `fcmToken`]),
 *   5. send the push via the Firebase Admin SDK,
 *   6. prune dead tokens, and
 *   7. return a delivery summary `{ success, recipientCount, ... }`.
 *
 * Implemented as a **2nd-gen** callable (`firebase-functions/v2`, the
 * `firebase-functions` v6 default). `firebase deploy --only functions` deploys it
 * and the Firebase CLI grants the public invoker for callable functions
 * automatically. (1st-gen would hit a "Cannot set CPU on GCF gen 1" deploy error
 * with firebase-functions v6.) The signed-in caller's auth arrives in
 * `request.auth`.
 *
 * Recipient-resolution / permission matrix (mirrors `BroadcastPermissions` on
 * the client and the `broadcasts` Firestore rules):
 *   - admin   → allBranches | branch (any) | user (any)
 *   - manager → branch (own only) | user (in own branch only)
 *   - employee → denied
 */

const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { onDocumentCreated, onDocumentUpdated, onDocumentWritten } = require("firebase-functions/v2/firestore");
const { onSchedule } = require("firebase-functions/v2/scheduler");
const { logger } = require("firebase-functions");
const admin = require("firebase-admin");

admin.initializeApp();

const db = admin.firestore();
const messaging = admin.messaging();
const auth = admin.auth();

const USERS = "users";
const BROADCASTS = "broadcasts";
const NOTIFICATIONS = "notifications";
const BROADCAST_SCHEDULES = "broadcastSchedules";
const TASKS = "tasks";
const TASK_REMINDERS = "taskReminders";
const REMINDER_CONFIG = "reminderConfig";
const BRANCHES = "branches";
const WEEKLY_SCHEDULES = "weekly_schedules";
const SHIFT_SWAPS = "shift_swaps";
const RECURRING_TASK_TEMPLATES = "recurringTaskTemplates";
// Operational run telemetry for the recurring-task automation engine (duration,
// execution id, per-run outcome) — the Automation Center's data source. Distinct
// from `audit_logs` (business facts). See docs/design/AUTOMATION_ENGINE.md.
const AUTOMATION_RUNS = "automationRuns";
// The immutable business audit trail (matches `AuditLogModel` in the app).
const AUDIT_LOGS = "audit_logs";
const CONFIG = "config";
const CASES = "cases";
const REQUESTS = "requests";
const COUNTERS = "counters";
const ATTENDANCE = "attendance";
const ATTENDANCE_CORRECTIONS = "attendance_corrections";
const ATTENDANCE_EXPECTATIONS = "attendance_expectations";
const BRANCH_SALES_MONTHS = "branch_sales_months";
const BRANCH_SALES_SUBMISSIONS = "branch_sales_submissions";

// Auto-close grace — mirrors AttendanceConfig.defaults.autoCloseGraceMinutes on
// the client (the single knob until per-branch attendance config lands).
// The pure auto-close decision (unit-tested in test/auto_close.test.js).
const { isAutoCloseDue } = require("./attendance_auto_close");
const {
  AUTO_CLOSE_GRACE_MINUTES,
  businessDaysToSweep,
  buildExpectedShiftRows,
  expectationInputsChanged,
  isSlotClosable,
  summarizeRows,
  weekStartInfoForBusinessDay,
} = require("./attendance_expectation");

const ATTENDANCE_AUTO_CLOSE_GRACE_MINUTES = AUTO_CLOSE_GRACE_MINUTES;

// Max session cap (R7 safety net) — mirrors AttendanceConfig.defaults.maxSessionMinutes.
const ATTENDANCE_MAX_SESSION_MINUTES = 16 * 60;
const {
  BUSINESS_TIME_ZONE,
  TASK_GRACE_MS,
  businessCivilMidnightMs,
  businessDayParts,
  businessWeekStartKey,
  isTerminalTaskStatus,
  resolveRecurringTaskWindow,
  selectMissedNotifyTargets,
  shouldAutoEndRecurringTask,
} = require("./recurring_task_deadline");
const {
  SEVERITY,
  logStep,
  buildValidations,
  classifyError,
  healthDeltas,
  executionDelayMs,
  correlationId,
  buildExecutionSnapshot,
} = require("./automation_run");
const { isReminderEligibleStatus } = require("./task_reminders");
const { isRetryableBroadcastPushError, resolveSendsPush } = require("./broadcast_delivery");
const { canClaimScheduledBroadcast } = require("./broadcast_schedule");
const {
  BUSINESS_TIME_ZONE: SALES_TIME_ZONE, businessMonthKey, isMonthKey, isValidMoney,
  nextStatus, targetAchievedCrossing, canDecideSubmission,
} = require("./sales_target");
const {
  correctionTargetsOwnRecord,
  correctionMatchesExistingRecordOwner,
} = require("./attendance_correction_target");
const { attendanceNotificationSubject } = require("./attendance_notification_subject");

// `branchId` marker for a direct message — never a real branch id and never ''
// (mirrors BroadcastModel.directBranchMarker), so a DM never appears in a
// branch / all feed query.
const DIRECT_BRANCH_MARKER = "__direct__";

// `branchId` marker for a hand-picked multi-recipient (custom) broadcast
// (mirrors BroadcastModel.customBranchMarker).
const CUSTOM_BRANCH_MARKER = "__custom__";

// FCM multicast hard limit per request.
const MULTICAST_CHUNK = 500;

// Firestore batched-write limit.
const BATCH_LIMIT = 500;

// Maps a broadcast category to its notification `type` (mirrors
// NotificationType.fromBroadcastCategory on the client).
function categoryToType(category) {
  switch (category) {
    case "reminder":
      return "broadcastReminder";
    case "emergency":
      return "broadcastEmergency";
    case "announcement":
    default:
      return "broadcastAnnouncement";
  }
}

// FCM error codes that mean a token is permanently dead and should be pruned.
function isDeadTokenError(code) {
  return (
    code === "messaging/registration-token-not-registered" ||
    code === "messaging/invalid-registration-token" ||
    code === "messaging/invalid-argument"
  );
}

// Delivery is derived from the broadcast category (mirrors BroadcastCategory on
// the client — there is no separate priority/channel dial): announcement is a
// quiet inbox-only message; reminder + emergency also push; emergency rides at
// high FCM priority. Every category writes the in-app inbox.
function categorySendsPush(category) { return category !== "announcement"; }
function categoryIsHigh(category) {
  return category === "emergency";
}

/**
 * The authoritative broadcast write + push pipeline, shared by the callable
 * `sendBroadcast` and (Phase 2 Commit 4) the scheduled-broadcast poller. The
 * caller is responsible for permission validation (role → audience, branch
 * ownership); this resolves recipients, persists the doc, writes the per-recipient
 * inbox notifications (when the channel includes inbox), pushes FCM (when the
 * channel includes push), prunes dead tokens, and returns the delivery summary.
 *
 * @returns {Promise<{broadcastId: string, recipientCount: number, deliveredCount: number}>}
 */
async function dispatchBroadcast(params) {
  const title = String(params.title || "").trim();
  const body = String(params.body || params.message || "").trim();
  const category = String(params.category || "general").trim() || "general";
  const sendsPush = resolveSendsPush(params.sendsPush, categorySendsPush(category));
  const audience = String(params.audience || "").trim();
  const senderId = String(params.senderId || "").trim();
  const senderRole = String(params.senderRole || "manager").trim() || "manager";
  const senderBranch = String(params.senderBranch || "").trim();
  const senderName = String(params.senderName || "DROP").trim() || "DROP";
  const targetUserId = String(params.targetUserId || "").trim();
  const roleFilter = String(params.roleFilter || "").trim();
  const targetUserIds = Array.isArray(params.targetUserIds)
    ? params.targetUserIds.map((s) => String(s || "").trim()).filter(Boolean)
    : [];
  let branchId = String(params.branchId || "").trim();
  // Persisted recipient list — set for a custom send (drives the read rule).
  let persistedTargetIds = [];

  // Restrict a fetched user set to a single role (zigzag-merge equality — no
  // composite index). 'all'/'' means everyone.
  const applyRole = (docs) =>
    roleFilter && roleFilter !== "all"
      ? docs.filter((d) => (d.data().role || "employee") === roleFilter)
      : docs;

  // ── Resolve recipients per audience (caller has validated permissions) ──
  let recipientDocs = [];
  if (audience === "allBranches") {
    const snap = await db.collection(USERS).where("isActive", "==", true).get();
    recipientDocs = applyRole(snap.docs);
    branchId = "";
  } else if (audience === "branch") {
    const snap = await db
      .collection(USERS)
      .where("branchId", "==", branchId)
      .where("isActive", "==", true)
      .get();
    recipientDocs = applyRole(snap.docs);
  } else if (audience === "user") {
    const targetSnap = await db.collection(USERS).doc(targetUserId).get();
    if (!targetSnap.exists) {
      throw new HttpsError("not-found", "That recipient no longer exists.");
    }
    recipientDocs = [targetSnap];
    branchId = DIRECT_BRANCH_MARKER;
  } else if (audience === "custom") {
    if (targetUserIds.length === 0) {
      throw new HttpsError("invalid-argument", "Pick at least one recipient.");
    }
    const refs = targetUserIds.map((id) => db.collection(USERS).doc(id));
    const snaps = await db.getAll(...refs);
    let docs = snaps.filter((s) => s.exists);
    // A manager may only message users inside their own branch.
    if (senderRole === "manager") {
      docs = docs.filter((d) => (d.data().branchId || "") === senderBranch);
    }
    if (docs.length === 0) {
      throw new HttpsError("not-found", "None of the recipients are available.");
    }
    recipientDocs = docs;
    persistedTargetIds = docs.map((d) => d.id);
    branchId = CUSTOM_BRANCH_MARKER;
  } else {
    throw new HttpsError("invalid-argument", "Unknown broadcast audience.");
  }

  // ── Never deliver a broadcast back to its own sender for an IMPLICIT
  // audience (everyone / a branch / a role). The sender authored it — pushing
  // it to their own device + inbox is noise. EXPLICIT audiences are honoured as
  // chosen: a direct `user` message or a hand-picked `custom` list delivers to
  // exactly whoever was selected (if the sender deliberately included
  // themselves, they receive it). ──
  if (
    (audience === "allBranches" || audience === "branch") &&
    senderId
  ) {
    recipientDocs = recipientDocs.filter((d) => d.id !== senderId);
  }

  const recipientCount = recipientDocs.length;
  const isHigh = categoryIsHigh(category);
  const notifType = categoryToType(category);

  // ── Persist the broadcast doc (authoritative — schema matches BroadcastModel) ──
  const broadcastRef = db.collection(BROADCASTS).doc();
  await broadcastRef.set({
    id: broadcastRef.id,
    title,
    message: body,
    category,
    sendsPush,
    senderId,
    senderName,
    senderRole,
    audience,
    branchId,
    targetUserId: audience === "user" ? targetUserId : "",
    targetUserIds: persistedTargetIds,
    recipientCount,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  // ── Persist one in-app notification doc per recipient (inbox channel only).
  // Flagged `pushedByFunction:true` so the onNotificationCreated trigger doesn't
  // double-push. Best-effort — a write failure never fails the send. ──
  // Every category writes the in-app inbox (announcement is inbox-only).
  {
    const notifPayload = {
      broadcastId: broadcastRef.id,
      category,
      route: "broadcast_detail",
      priority: isHigh ? "high" : "normal",
    };
    try {
      for (let i = 0; i < recipientDocs.length; i += BATCH_LIMIT) {
        const slice = recipientDocs.slice(i, i + BATCH_LIMIT);
        const batch = db.batch();
        for (const doc of slice) {
          const ref = db.collection(NOTIFICATIONS).doc();
          batch.set(ref, {
            id: ref.id,
            recipientUid: doc.id,
            senderUid: senderId,
            type: notifType,
            title,
            body,
            readAt: null,
            payload: notifPayload,
            pushedByFunction: true,
            createdAt: admin.firestore.FieldValue.serverTimestamp(),
          });
        }
        await batch.commit();
      }
    } catch (err) {
      logger.warn("failed to persist broadcast notifications", { error: String(err) });
    }
  }

  // ── Push the notification (chunked; prune dead tokens) — push channels only ──
  let deliveredCount = 0;
  let pushFailureCount = 0;
  // Diagnostics: how many times the SAME device token was found on two different
  // recipients in one send — an ownership-drift signal (defense-in-depth #3).
  let tokenDriftCount = 0;
  if (sendsPush) {
    // Gather FCM tokens (de-duplicated; remember each token's EXCLUSIVE owner).
    // If a token is already claimed by another recipient in this send, that's
    // drift: keep the first owner (no double-send) and log it. claimFcmToken is
    // the authoritative reconciliation; this just surfaces the race for ops.
    const tokens = [];
    const tokenOwner = new Map();
    const claimToken = (t, uid) => {
      if (!t) return;
      const existing = tokenOwner.get(t);
      if (existing === undefined) {
        tokenOwner.set(t, uid);
        tokens.push(t);
      } else if (existing !== uid) {
        tokenDriftCount++;
        logger.warn("token ownership drift during dispatch", {
          broadcastId: broadcastRef.id,
          tokenSuffix: String(t).slice(-8),
          owners: [existing, uid],
        });
      }
    };
    for (const doc of recipientDocs) {
      const u = doc.data() || {};
      const arr = Array.isArray(u.fcmTokens) ? u.fcmTokens : [];
      for (const t of arr) claimToken(t, doc.id);
      // Legacy single-token field (pre-Phase-2 docs).
      claimToken(u.fcmToken, doc.id);
    }

    // Data values must be strings — they ride along to the tap handler. Each
    // push is stamped per-token with its intended `recipientUid` below, so the
    // client can DROP any notification whose recipient != the signed-in user
    // (defense-in-depth #3 — the last guard against a drifted/stale token).
    const baseData = {
      type: notifType,
      category,
      priority: isHigh ? "high" : "normal",
      senderId,
      broadcastId: broadcastRef.id,
      route: "broadcast_detail",
      title,
      body,
    };
    const androidPriority = isHigh ? "high" : "normal";
    const apnsPriority = isHigh ? "10" : "5";

    if (tokens.length === 0) {
      // Recipients exist but none has a registered device token — they still get
      // the in-app inbox entry, just no push. Logged so a "didn't reach all"
      // report can be diagnosed (token persistence vs. the send itself).
      logger.info("broadcast push: recipients have no registered device tokens", {
        broadcastId: broadcastRef.id,
        recipientCount,
      });
    }
    // A push / messaging-API failure must NOT fail a send whose broadcast doc +
    // inbox notifications already succeeded (recipients still got the in-app
    // entry). Isolate it: log it and keep the partial delivered count.
    try {
    for (let i = 0; i < tokens.length; i += MULTICAST_CHUNK) {
      const batch = tokens.slice(i, i + MULTICAST_CHUNK);
      // One message per token so `data.recipientUid` can differ per recipient (a
      // multicast shares one data block). `sendEach` preserves response order, so
      // the dead-token pruning below still indexes `batch[idx]`.
      const messages = batch.map((token) => ({
        token,
        notification: { title, body },
        android: { priority: androidPriority },
        apns: { headers: { "apns-priority": apnsPriority } },
        data: { ...baseData, recipientUid: tokenOwner.get(token) || "" },
      }));
      let response;
      try {
        response = await messaging.sendEach(messages);
      } catch (err) {
        if (!isRetryableBroadcastPushError(err)) throw err;
        logger.warn("broadcast push failed; retrying once", {
          broadcastId: broadcastRef.id,
          tokenCount: batch.length,
          code: err && err.code,
          error: String(err),
        });
        response = await messaging.sendEach(messages);
      }
      deliveredCount += response.successCount;
      pushFailureCount += response.failureCount;

      // Remove tokens FCM reports as permanently invalid, per owner.
      const removals = new Map(); // uid -> [badToken]
      response.responses.forEach((r, idx) => {
        if (r.success) return;
        const code = r.error && r.error.code;
        // DIAGNOSTIC: surface the EXACT per-token failure reason (FCM discards it
        // otherwise) — e.g. `messaging/third-party-auth-error` = iOS APNs key not
        // configured; `messaging/registration-token-not-registered` = stale token.
        logger.warn("broadcast token send failed", {
          broadcastId: broadcastRef.id,
          owner: tokenOwner.get(batch[idx]),
          tokenSuffix: String(batch[idx]).slice(-10),
          code,
          message: r.error && r.error.message,
        });
        if (isDeadTokenError(code)) {
          const badToken = batch[idx];
          const owner = tokenOwner.get(badToken);
          if (owner) {
            if (!removals.has(owner)) removals.set(owner, []);
            removals.get(owner).push(badToken);
          }
        }
      });
      await Promise.all(
        Array.from(removals.entries()).map(([uid, bad]) =>
          db
            .collection(USERS)
            .doc(uid)
            .update({ fcmTokens: admin.firestore.FieldValue.arrayRemove(...bad) })
            .catch(() => {}),
        ),
      );
    }
    } catch (err) {
      logger.error("broadcast push failed (inbox delivery already succeeded)", {
        broadcastId: broadcastRef.id,
        tokenCount: tokens.length,
        deliveredCount,
        failureCount: pushFailureCount,
        error: String(err),
      });
    }
  }

  // Persist the delivery result on the doc so the Communications Center feed /
  // detail can show "delivered N / M" (best-effort; never fails the send).
  await broadcastRef.update({ deliveredCount }).catch(() => {});

  logger.info("broadcast dispatched", {
    broadcastId: broadcastRef.id,
    audience,
    recipientCount,
    deliveredCount,
    failureCount: pushFailureCount,
    tokenDriftCount,
  });

  return { broadcastId: broadcastRef.id, recipientCount, deliveredCount };
}

exports.sendBroadcast = onCall(async (request) => {
  const auth = request.auth;
  if (!auth) {
    throw new HttpsError("unauthenticated", "Please sign in to send a broadcast.");
  }

  const payload = request.data || {};
  const title = String(payload.title || "").trim();
  const body = String(payload.body || payload.message || "").trim();
  const category = String(payload.category || "general").trim() || "general";
  const audience = String(payload.audience || "").trim();
  const branchId = String(payload.branchId || "").trim();
  const targetUserId = String(payload.targetUserId || "").trim();
  const roleFilter = String(payload.roleFilter || "").trim();
  const sendsPush = typeof payload.sendsPush === "boolean" ? payload.sendsPush : undefined;
  const targetUserIds = Array.isArray(payload.targetUserIds)
    ? payload.targetUserIds.map((s) => String(s || "").trim()).filter(Boolean)
    : [];

  if (!title || !body) {
    throw new HttpsError("invalid-argument", "A broadcast needs a title and a message.");
  }

  // ── Load the sender (role + branch are the authority for permissions) ──
  const senderSnap = await db.collection(USERS).doc(auth.uid).get();
  if (!senderSnap.exists) {
    throw new HttpsError("permission-denied", "Your account profile was not found.");
  }
  const sender = senderSnap.data() || {};
  const senderRole = sender.role || "employee";
  const senderBranch = sender.branchId || "";

  if (senderRole !== "admin" && senderRole !== "manager") {
    throw new HttpsError("permission-denied", "Only managers and admins can send broadcasts.");
  }

  // ── Validate permissions per audience (recipient resolution is in dispatch) ──
  if (audience === "allBranches") {
    if (senderRole !== "admin") {
      throw new HttpsError("permission-denied", "Only admins can broadcast to all branches.");
    }
  } else if (audience === "branch") {
    if (!branchId) {
      throw new HttpsError("invalid-argument", "Pick a branch to broadcast to.");
    }
    if (senderRole === "manager" && branchId !== senderBranch) {
      throw new HttpsError("permission-denied", "Managers can only broadcast to their own branch.");
    }
  } else if (audience === "user") {
    if (!targetUserId) {
      throw new HttpsError("invalid-argument", "Pick a recipient.");
    }
    if (senderRole === "manager") {
      const targetSnap = await db.collection(USERS).doc(targetUserId).get();
      const target = targetSnap.exists ? targetSnap.data() || {} : {};
      if (!targetSnap.exists) {
        throw new HttpsError("not-found", "That recipient no longer exists.");
      }
      if ((target.branchId || "") !== senderBranch) {
        throw new HttpsError("permission-denied", "Managers can only message users inside their own branch.");
      }
    }
  } else if (audience === "custom") {
    if (targetUserIds.length === 0) {
      throw new HttpsError("invalid-argument", "Pick at least one recipient.");
    }
    // A manager's out-of-branch picks are filtered out inside dispatch.
  } else {
    throw new HttpsError("invalid-argument", "Unknown broadcast audience.");
  }

  const senderName = sender.fullName || sender.displayName || sender.email || "DROP";

  const result = await dispatchBroadcast({
    senderId: auth.uid,
    senderRole,
    senderBranch,
    senderName,
    title,
    body,
    category,
    audience,
    branchId,
    targetUserId,
    targetUserIds,
    roleFilter,
    sendsPush,
  });

  return { success: true, ...result };
});

// ─────────────────────────────────────────────────────────────────────────────
// createUserAccount — the secure account-provisioning path (admin-only).
//
// DROP no longer allows public registration: only an admin creates accounts.
// This callable creates the Firebase Auth user with the Admin SDK (which does
// NOT sign the calling admin out, unlike the client createUserWithEmailAndPassword)
// and seeds the `users/{uid}` document with the role/branch/shift/position plus
// the first-login flags (mustChangePassword + isProfileCompleted:false). Firestore
// rules deny ALL client creates of user docs, so this is the only creation path.
const VALID_ROLES = ["admin", "manager", "employee"];

exports.createUserAccount = onCall(async (request) => {
  const callerAuth = request.auth;
  if (!callerAuth) {
    throw new HttpsError("unauthenticated", "Please sign in.");
  }

  // ── Only an admin may provision accounts ──
  const callerSnap = await db.collection(USERS).doc(callerAuth.uid).get();
  const caller = callerSnap.exists ? callerSnap.data() || {} : {};
  if ((caller.role || "employee") !== "admin") {
    throw new HttpsError("permission-denied", "Only an admin can create accounts.");
  }

  const data = request.data || {};
  const name = String(data.name || "").trim();
  const email = String(data.email || "").trim().toLowerCase();
  const password = String(data.password || "");
  const role = String(data.role || "").trim();
  const branchId = String(data.branchId || "").trim();
  const assignedShift = String(data.assignedShift || "").trim();
  const position = String(data.position || "").trim();

  // ── Validation ──
  if (!name) throw new HttpsError("invalid-argument", "A full name is required.");
  if (!email || !email.includes("@")) {
    throw new HttpsError("invalid-argument", "A valid email is required.");
  }
  if (password.length < 6) {
    throw new HttpsError("invalid-argument", "The temporary password must be at least 6 characters.");
  }
  if (!VALID_ROLES.includes(role)) {
    throw new HttpsError("invalid-argument", "Pick a valid role.");
  }
  // A manager / employee must belong to a branch; an admin may be global.
  if ((role === "manager" || role === "employee") && !branchId) {
    throw new HttpsError("invalid-argument", "Pick a branch for this account.");
  }

  // ── Create the Auth user (does NOT affect the admin's own session) ──
  let userRecord;
  try {
    userRecord = await auth.createUser({
      email,
      password,
      displayName: name,
    });
  } catch (err) {
    if (err && err.code === "auth/email-already-exists") {
      throw new HttpsError("already-exists", "An account already exists with this email.");
    }
    if (err && err.code === "auth/invalid-email") {
      throw new HttpsError("invalid-argument", "The email address is not valid.");
    }
    if (err && err.code === "auth/invalid-password") {
      throw new HttpsError("invalid-argument", "The temporary password is too weak.");
    }
    logger.error("createUserAccount: auth.createUser failed", { error: String(err) });
    throw new HttpsError("internal", "Could not create the account. Please try again.");
  }

  // ── Seed the Firestore user document ──
  try {
    await db.collection(USERS).doc(userRecord.uid).set({
      uid: userRecord.uid,
      email,
      // `name` maps to displayName (canonical) mirrored to the profile fullName.
      displayName: name,
      fullName: name,
      authProvider: "admin-created",
      role,
      branchId: branchId || null,
      assignedShift: assignedShift || null,
      position: position || null,
      isActive: true,
      employmentStatus: "active",
      mustChangePassword: true,
      isProfileCompleted: false,
      isEmailVerified: false,
      // Empty profile-schema seeds (filled during Profile Completion).
      username: "",
      bio: "",
      profileImage: "",
      coverImage: "",
      createdBy: callerAuth.uid,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
  } catch (err) {
    // Roll back the orphaned Auth user so a retry with the same email works.
    await auth.deleteUser(userRecord.uid).catch(() => {});
    logger.error("createUserAccount: firestore seed failed", { error: String(err) });
    throw new HttpsError("internal", "Could not finish creating the account. Please try again.");
  }

  logger.info("account created", { uid: userRecord.uid, role, by: callerAuth.uid });
  return { success: true, uid: userRecord.uid };
});

// ─────────────────────────────────────────────────────────────────────────────
// adminResetPassword — admin-only account reset: set a new temporary password
// (Admin SDK) and re-force a password change on next login. Satisfies the spec's
// "reset employee accounts" without exposing Auth credentials to the client.
exports.adminResetPassword = onCall(async (request) => {
  const callerAuth = request.auth;
  if (!callerAuth) {
    throw new HttpsError("unauthenticated", "Please sign in.");
  }
  const callerSnap = await db.collection(USERS).doc(callerAuth.uid).get();
  const caller = callerSnap.exists ? callerSnap.data() || {} : {};
  if ((caller.role || "employee") !== "admin") {
    throw new HttpsError("permission-denied", "Only an admin can reset accounts.");
  }

  const data = request.data || {};
  const uid = String(data.uid || "").trim();
  const tempPassword = String(data.tempPassword || "");
  if (!uid) throw new HttpsError("invalid-argument", "Missing the account to reset.");
  if (tempPassword.length < 6) {
    throw new HttpsError("invalid-argument", "The temporary password must be at least 6 characters.");
  }

  try {
    await auth.updateUser(uid, { password: tempPassword });
  } catch (err) {
    if (err && err.code === "auth/user-not-found") {
      throw new HttpsError("not-found", "That account no longer exists.");
    }
    logger.error("adminResetPassword: updateUser failed", { error: String(err) });
    throw new HttpsError("internal", "Could not reset the account. Please try again.");
  }

  await db.collection(USERS).doc(uid).set(
    {
      mustChangePassword: true,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    },
    { merge: true },
  );

  logger.info("account reset", { uid, by: callerAuth.uid });
  return { success: true };
});

// ─────────────────────────────────────────────────────────────────────────────
// approveSwap — the server-authoritative shift-swap exchange (2026-06-25
// hardening). A coworker-approved swap is finalized HERE, never by a direct
// client write (firestore.rules deny a client setting status==managerApproved).
//
// The function re-validates against the FRESHEST schedule (TOCTOU backstop) and
// applies the exchange ATOMICALLY in a single transaction — the requester and the
// target trade shifts on the same day (only two shifts exist, so the target's
// slot is the opposite of the requester's). Either both move or nothing changes.
//
// Validation mirrors `SwapValidation` (lib/features/schedule/domain/
// swap_validation.dart) — keep the two in sync. Notifications stay client-side
// (`NotifySwapEvent` fires after this resolves), reusing the existing pipeline.
const SWAP_DAY_INDEX = {
  sunday: 0, monday: 1, tuesday: 2, wednesday: 3, thursday: 4, friday: 5, saturday: 6,
};
const SWAP_SHIFTS = ["morning", "night"];

function swapOppositeShift(s) {
  return s === "night" ? "morning" : "night";
}
// Minutes past the slot day's midnight, mirroring ShiftHours.standard /
// SwapEligibility / SwapValidation: morning 08:30–16:30; weekday night
// 15:00–23:00; weekend night (Thu/Fri/Sat) 16:00–00:00 (end 1440 = next-day
// midnight). Day-aware because weekday and weekend nights now differ.
function swapIsWeekendDay(day) {
  return day === "thursday" || day === "friday" || day === "saturday";
}
function swapShiftMinutes(s, day) {
  if (s !== "night") return { start: 8 * 60 + 30, end: 16 * 60 + 30 };
  return swapIsWeekendDay(day)
    ? { start: 16 * 60, end: 24 * 60 }
    : { start: 15 * 60, end: 23 * 60 };
}
function swapAssignedUids(assignments, day, shift) {
  const d = assignments && assignments[day];
  const arr = d && d[shift];
  return Array.isArray(arr) ? arr : [];
}
// Smallest gap (minutes) between any two of the employee's shifts in the week.
// < 2 shifts → unconstrained. Week-bounded (the adjacent week isn't loaded) —
// mirrors SwapValidation._minGapMinutes.
function swapMinGapMinutes(assignments, uid) {
  const intervals = [];
  for (const day of Object.keys(SWAP_DAY_INDEX)) {
    const di = SWAP_DAY_INDEX[day];
    for (const sh of SWAP_SHIFTS) {
      if (swapAssignedUids(assignments, day, sh).includes(uid)) {
        const m = swapShiftMinutes(sh, day);
        intervals.push([di * 1440 + m.start, di * 1440 + m.end]);
      }
    }
  }
  if (intervals.length < 2) return Number.MAX_SAFE_INTEGER;
  intervals.sort((a, b) => a[0] - b[0]);
  let minGap = Number.MAX_SAFE_INTEGER;
  for (let i = 1; i < intervals.length; i++) {
    const gap = intervals[i][0] - intervals[i - 1][1];
    if (gap < minGap) minGap = gap;
  }
  return minGap;
}

exports.approveSwap = onCall(async (request) => {
  const auth = request.auth;
  if (!auth) {
    throw new HttpsError("unauthenticated", "Please sign in to approve a swap.");
  }
  const data = request.data || {};
  const swapId = String(data.swapId || "").trim();
  // The client computes the schedule doc id from the LOCAL week start (the way it
  // was created); the function would mis-format it in UTC, so it's passed in and
  // re-validated against the swap's branch + slot contents below.
  const scheduleId = String(data.scheduleId || "").trim();
  if (!swapId || !scheduleId) {
    throw new HttpsError("invalid-argument", "Missing swap or schedule reference.");
  }

  // ── Load the swap (the source of truth for branch / day / shift / parties) ──
  const swapRef = db.collection(SHIFT_SWAPS).doc(swapId);
  const swapSnap = await swapRef.get();
  if (!swapSnap.exists) {
    throw new HttpsError("not-found", "This swap request no longer exists.");
  }
  const swap = swapSnap.data() || {};
  const branchId = String(swap.branchId || "");
  const day = String(swap.day || "");
  const shift = String(swap.shift || "");
  const opp = swapOppositeShift(shift);
  const requesterId = String(swap.requesterId || "");
  const targetId = String(swap.targetId || "");

  // ── Permission: admin, or the manager of THIS branch ──
  const callerSnap = await db.collection(USERS).doc(auth.uid).get();
  if (!callerSnap.exists) {
    throw new HttpsError("permission-denied", "Your account profile was not found.");
  }
  const caller = callerSnap.data() || {};
  const callerRole = caller.role || "employee";
  const callerBranch = caller.branchId || "";
  const approverName = String(caller.displayName || caller.fullName || caller.email || "Manager").trim();
  const canApprove =
    callerRole === "admin" ||
    (callerRole === "manager" && callerBranch === branchId);
  if (!canApprove) {
    throw new HttpsError(
      "permission-denied",
      "Only the branch manager or an admin can approve a swap.",
    );
  }

  // The passed scheduleId must belong to this swap's branch (forged-id defense).
  if (!scheduleId.startsWith(`${branchId}_`)) {
    throw new HttpsError("invalid-argument", "Schedule reference does not match this branch.");
  }

  if (swap.status !== "employeeApproved") {
    throw new HttpsError("failed-precondition", "This swap isn’t awaiting manager approval.");
  }

  // ── Slow-changing config (employees + branch policy), read outside the tx ──
  const [reqSnap, tgtSnap, branchSnap] = await Promise.all([
    db.collection(USERS).doc(requesterId).get(),
    db.collection(USERS).doc(targetId).get(),
    db.collection(BRANCHES).doc(branchId).get(),
  ]);
  const reqUser = reqSnap.exists ? reqSnap.data() || {} : null;
  const tgtUser = tgtSnap.exists ? tgtSnap.data() || {} : null;
  if (!reqUser || !tgtUser) {
    throw new HttpsError("failed-precondition", "One of the employees no longer exists.");
  }
  if (reqUser.isActive === false || tgtUser.isActive === false) {
    throw new HttpsError("failed-precondition", "One of the employees is no longer active.");
  }
  const policy = (branchSnap.exists && (branchSnap.data() || {}).swapPolicy) || {};
  const restrictSamePosition = policy.restrictToSamePosition === true;
  const minRestHours =
    Number(policy.minRestHours) > 0 ? Number(policy.minRestHours) : null;

  // Role compatibility (mirror SwapPolicy.positionsCompatible — unset = ok).
  if (restrictSamePosition) {
    const pa = String(reqUser.position || "").trim().toLowerCase();
    const pb = String(tgtUser.position || "").trim().toLowerCase();
    if (pa && pb && pa !== pb) {
      throw new HttpsError(
        "failed-precondition",
        "You can only swap with a coworker in a compatible role.",
      );
    }
  }

  // Future check (mirror swapSlotInFuture). weekStart is an absolute instant
  // (local-midnight Sunday); adding the day offset + shift start gives the slot's
  // start instant, compared against now — timezone-safe (both absolute).
  const weekStartMs =
    swap.weekStart && typeof swap.weekStart.toMillis === "function"
      ? swap.weekStart.toMillis()
      : null;
  if (weekStartMs == null) {
    throw new HttpsError("failed-precondition", "This swap is malformed.");
  }
  const slotStartMs =
    weekStartMs +
    (SWAP_DAY_INDEX[day] || 0) * 24 * 60 * 60 * 1000 +
    swapShiftMinutes(shift, day).start * 60 * 1000;
  if (slotStartMs <= Date.now()) {
    throw new HttpsError(
      "failed-precondition",
      "This shift has already started — it can no longer be swapped.",
    );
  }

  const schedRef = db.collection(WEEKLY_SCHEDULES).doc(scheduleId);

  // ── Atomic re-validate + exchange ──
  await db.runTransaction(async (tx) => {
    const sSnap = await tx.get(swapRef);
    const schSnap = await tx.get(schedRef);
    if (!sSnap.exists) {
      throw new HttpsError("not-found", "This swap request no longer exists.");
    }
    if ((sSnap.data() || {}).status !== "employeeApproved") {
      throw new HttpsError("failed-precondition", "This swap isn’t awaiting manager approval.");
    }
    if (!schSnap.exists) {
      throw new HttpsError("failed-precondition", "The schedule for this week no longer exists.");
    }
    const sched = schSnap.data() || {};
    if (String(sched.branchId || "") !== branchId) {
      throw new HttpsError("invalid-argument", "Schedule reference does not match this branch.");
    }
    const assignments = sched.assignments || {};
    const shiftArr = swapAssignedUids(assignments, day, shift);
    const oppArr = swapAssignedUids(assignments, day, opp);

    // Slot integrity (TOCTOU): both parties must still hold their slots.
    if (!shiftArr.includes(requesterId)) {
      throw new HttpsError(
        "failed-precondition",
        "The schedule changed — the requester is no longer on that shift.",
      );
    }
    if (!oppArr.includes(targetId)) {
      throw new HttpsError(
        "failed-precondition",
        "The schedule changed — your coworker is no longer on the opposite shift.",
      );
    }

    // Post-exchange arrays (deterministic — no array-transform collisions).
    const newShiftArr = shiftArr.filter((u) => u !== requesterId);
    if (!newShiftArr.includes(targetId)) newShiftArr.push(targetId);
    const newOppArr = oppArr.filter((u) => u !== targetId);
    if (!newOppArr.includes(requesterId)) newOppArr.push(requesterId);

    // Double-booking guard: neither party ends on both shifts that day.
    for (const uid of [requesterId, targetId]) {
      if (newShiftArr.includes(uid) && newOppArr.includes(uid)) {
        throw new HttpsError(
          "failed-precondition",
          "This swap would double-book someone on the same day.",
        );
      }
    }

    // Rest-hours guard (post-exchange, week-bounded) — only if the branch sets it.
    if (minRestHours != null) {
      const after = {};
      for (const d of Object.keys(SWAP_DAY_INDEX)) {
        const dd = assignments[d] || {};
        after[d] = {};
        for (const sh of SWAP_SHIFTS) {
          after[d][sh] = Array.isArray(dd[sh]) ? dd[sh].slice() : [];
        }
      }
      after[day][shift] = newShiftArr;
      after[day][opp] = newOppArr;
      for (const uid of [requesterId, targetId]) {
        if (swapMinGapMinutes(after, uid) < minRestHours * 60) {
          throw new HttpsError(
            "failed-precondition",
            `This swap would leave less than ${minRestHours} hours of rest between shifts.`,
          );
        }
      }
    }

    tx.update(swapRef, {
      status: "managerApproved",
      managerApprovedById: auth.uid,
      managerApprovedByName: approverName,
      managerApprovedAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    tx.update(schedRef, {
      [`assignments.${day}.${shift}`]: newShiftArr,
      [`assignments.${day}.${opp}`]: newOppArr,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
  });

  // The roster exchange is authoritative on the server, so its approval notice
  // is too. Delivery remains best-effort: an inbox write failure cannot undo a
  // committed exchange or turn this callable into a false failure.
  try {
    // Mirrors ScheduleDay.fromString(raw).label: unknown/missing values fall
    // back to Sunday rather than inventing a different inbox label.
    const dayLabels = {
      sunday: "Sunday",
      monday: "Monday",
      tuesday: "Tuesday",
      wednesday: "Wednesday",
      thursday: "Thursday",
      friday: "Friday",
      saturday: "Saturday",
    };
    const dayLabel = dayLabels[day] || "Sunday";
    const batch = db.batch();
    for (const recipientUid of new Set([requesterId, targetId])) {
      if (!recipientUid) continue;
      const ref = db.collection(NOTIFICATIONS).doc();
      batch.set(ref, {
        id: ref.id,
        recipientUid,
        senderUid: auth.uid,
        type: "swapApproved",
        title: "Swap Approved",
        body: `${approverName} approved your ${dayLabel} shift swap — the schedule is updated.`,
        readAt: null,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        payload: { swapId, route: "schedule" },
      });
    }
    await batch.commit();
  } catch (err) {
    logger.error("failed to write swap approval notifications", {
      swapId,
      error: String(err),
    });
  }

  return { success: true };
});

// ── Branch monthly sales ledger (server-authoritative decisions) ──────────
function salesActor(user, uid) {
  return { id: uid, name: String(user.displayName || user.fullName || user.email || "User").trim(), role: String(user.role || "employee") };
}
async function requireSalesManager(request, branchId) {
  if (!request.auth) throw new HttpsError("unauthenticated", "Please sign in.");
  const snap = await db.collection(USERS).doc(request.auth.uid).get();
  if (!snap.exists) throw new HttpsError("permission-denied", "Your account profile was not found.");
  const user = snap.data() || {};
  const role = String(user.role || "employee");
  if (user.isActive === false || !(role === "admin" || (role === "manager" && user.branchId === branchId))) {
    throw new HttpsError("permission-denied", "Only the branch manager or an admin can make this change.");
  }
  return salesActor(user, request.auth.uid);
}
function salesReason(value, required = true) {
  const reason = typeof value === "string" ? value.trim() : "";
  if (required && !reason) throw new HttpsError("invalid-argument", "A reason is required.");
  return reason;
}
async function writeSalesAudit({ eventType, entityType, entityId, actor, branchId, metadata }) {
  const ref = db.collection(AUDIT_LOGS).doc();
  await ref.set({ eventType, entityType, entityId, actorId: actor.id,
    actorName: actor.name, actorRole: actor.role, branchId, metadata, schemaVersion: 1,
    isDeleted: false, timestamp: admin.firestore.FieldValue.serverTimestamp() });
}
async function salesRecipients(branchId, { managersOnly = false, adminsFallback = false } = {}) {
  const snap = await db.collection(USERS).where("branchId", "==", branchId).where("isActive", "==", true).get();
  let ids = snap.docs.filter((d) => !managersOnly || d.data().role === "manager").map((d) => d.id);
  if (!ids.length && adminsFallback) {
    const admins = await db.collection(USERS).where("role", "==", "admin").where("isActive", "==", true).get();
    ids = admins.docs.map((d) => d.id);
  }
  return ids;
}
async function writeSalesNotifications(recipientUids, { title, body, submissionId = null, monthKey = null }) {
  const ids = [...new Set(recipientUids.filter(Boolean))];
  if (!ids.length) return;
  const batch = db.batch();
  for (const recipientUid of ids) {
    const ref = db.collection(NOTIFICATIONS).doc();
    batch.set(ref, { id: ref.id, recipientUid, senderUid: "", type: "salesSubmission",
      title: String(title).slice(0, 120), body: String(body).slice(0, 500), readAt: null,
      payload: { route: "sales_submission", ...(submissionId ? { salesSubmissionId: submissionId } : {}), ...(monthKey ? { monthKey } : {}) },
      createdAt: admin.firestore.FieldValue.serverTimestamp() });
  }
  await batch.commit();
}
async function approvedTotal(tx, branchId, monthKey) {
  const snap = await tx.get(db.collection(BRANCH_SALES_SUBMISSIONS)
    .where("branchId", "==", branchId).where("monthKey", "==", monthKey).where("status", "==", "approved"));
  return snap.docs.reduce((sum, doc) => sum + (Number(doc.data().amountPiastres) || 0), 0);
}

exports.setBranchSalesTarget = onCall(async (request) => {
  const data = request.data || {};
  const branchId = String(data.branchId || "").trim();
  const monthKey = String(data.monthKey || "").trim();
  if (!branchId || !isMonthKey(monthKey) || monthKey !== businessMonthKey(`${monthKey.slice(0, 4)}-${monthKey.slice(4, 6)}-15T12:00:00Z`) || !isValidMoney(data.targetPiastres)) {
    throw new HttpsError("invalid-argument", "Invalid branch, Cairo month, or target amount.");
  }
  const reason = salesReason(data.reason);
  const actor = await requireSalesManager(request, branchId);
  const ref = db.collection(BRANCH_SALES_MONTHS).doc(`${branchId}_${monthKey}`);
  let result;
  await db.runTransaction(async (tx) => {
    const snap = await tx.get(ref); const now = admin.firestore.FieldValue.serverTimestamp();
    if (!snap.exists) {
      result = { oldTarget: null, targetRevision: 1 };
      tx.create(ref, { id: ref.id, branchId, monthKey, timeZone: SALES_TIME_ZONE, targetPiastres: data.targetPiastres, targetRevision: 1,
        createdAt: now, updatedAt: now, createdById: actor.id, createdByName: actor.name, createdByRole: actor.role,
        updatedById: actor.id, updatedByName: actor.name, updatedByRole: actor.role, lastChangeReason: reason, schemaVersion: 1 });
    } else {
      const old = snap.data() || {}; const currentRevision = Number(old.targetRevision) || 1;
      if (data.expectedTargetRevision != null && data.expectedTargetRevision !== currentRevision) throw new HttpsError("failed-precondition", "Target revision is stale.");
      result = { oldTarget: old.targetPiastres, targetRevision: currentRevision + 1 };
      tx.update(ref, { targetPiastres: data.targetPiastres, targetRevision: currentRevision + 1, updatedAt: now,
        updatedById: actor.id, updatedByName: actor.name, updatedByRole: actor.role, lastChangeReason: reason });
    }
  });
  try { await writeSalesAudit({ eventType: "sales.target_changed", entityType: "sales_month", entityId: ref.id, actor, branchId, metadata: { branchId, monthKey, targetId: ref.id, oldTargetPiastres: result.oldTarget, newTargetPiastres: data.targetPiastres, targetRevision: result.targetRevision, reason, schemaVersion: 1 } });
    await writeSalesNotifications(await salesRecipients(branchId), { title: "Sales target updated", body: "Your branch monthly sales target was updated.", monthKey });
  } catch (err) { logger.warn("failed to write sales target side effects", { error: String(err), branchId, monthKey }); }
  return { success: true, targetRevision: result.targetRevision };
});

exports.decideDailySalesSubmission = onCall(async (request) => {
  const data = request.data || {}; const submissionId = String(data.submissionId || "").trim();
  const action = String(data.action || "");
  if (!submissionId || !["approve", "reject", "requestCorrection", "reopen"].includes(action)) throw new HttpsError("invalid-argument", "Invalid sales decision.");
  const ref = db.collection(BRANCH_SALES_SUBMISSIONS).doc(submissionId); const initial = await ref.get();
  if (!initial.exists) throw new HttpsError("not-found", "Sales submission no longer exists.");
  const branchId = String((initial.data() || {}).branchId || ""); const actor = await requireSalesManager(request, branchId);
  const reason = salesReason(data.reason, ["reject", "requestCorrection", "reopen"].includes(action)); let result;
  await db.runTransaction(async (tx) => {
    const snap = await tx.get(ref); if (!snap.exists) throw new HttpsError("not-found", "Sales submission no longer exists.");
    const sub = snap.data() || {}; if (String(sub.branchId || "") !== branchId) throw new HttpsError("failed-precondition", "Submission branch changed.");
    if (!canDecideSubmission(actor.id, sub.submittedById)) throw new HttpsError("failed-precondition", "You cannot approve your own sales submission.");
    const transition = nextStatus(String(sub.status || ""), action, actor.role);
    if (transition.error) throw new HttpsError("failed-precondition", "This sales submission cannot take that action now.");
    const revision = Number(sub.revision) || 1; const update = { status: transition.status, decisionById: actor.id, decisionByName: actor.name, decisionByRole: actor.role, decisionAt: admin.firestore.FieldValue.serverTimestamp(), decisionReason: reason || null, updatedAt: admin.firestore.FieldValue.serverTimestamp() };
    if (action === "approve") update.approvedRevision = revision;
    let crossing = false;
    if (action === "approve") { const month = await tx.get(db.collection(BRANCH_SALES_MONTHS).doc(`${branchId}_${sub.monthKey}`)); const total = await approvedTotal(tx, branchId, sub.monthKey); crossing = month.exists && targetAchievedCrossing(total, total + sub.amountPiastres, Number((month.data() || {}).targetPiastres)); }
    tx.update(ref, update); result = { sub, nextStatus: transition.status, revision, crossing };
  });
  const event = { approve: "sales.approved", reject: "sales.rejected", requestCorrection: "sales.correction_requested", reopen: "sales.reopened" }[action];
  try { await writeSalesAudit({ eventType: event, entityType: "daily_sales_submission", entityId: submissionId, actor, branchId, metadata: { branchId, monthKey: result.sub.monthKey, businessDateKey: result.sub.businessDateKey, submissionId, oldStatus: result.sub.status, newStatus: result.nextStatus, revision: result.revision, reason: reason || null, schemaVersion: 1 } });
    await writeSalesNotifications([result.sub.submittedById], { title: "Sales submission updated", body: `Your sales submission was ${result.nextStatus}.`, submissionId });
    if (result.crossing) await writeSalesNotifications(await salesRecipients(branchId), { title: "Sales target achieved", body: "Your branch has reached its monthly sales target.", submissionId, monthKey: result.sub.monthKey });
  } catch (err) { logger.warn("failed to write sales decision side effects", { error: String(err), submissionId }); }
  return { success: true, status: result.nextStatus };
});

exports.editApprovedDailySalesSubmission = onCall(async (request) => {
  const data = request.data || {}; const submissionId = String(data.submissionId || "").trim();
  if (!submissionId || !isValidMoney(data.amountPiastres) || !Number.isInteger(data.expectedRevision)) throw new HttpsError("invalid-argument", "Invalid sales edit.");
  const ref = db.collection(BRANCH_SALES_SUBMISSIONS).doc(submissionId); const initial = await ref.get();
  if (!initial.exists) throw new HttpsError("not-found", "Sales submission no longer exists.");
  const branchId = String((initial.data() || {}).branchId || ""); const actor = await requireSalesManager(request, branchId); const reason = salesReason(data.reason); let result;
  await db.runTransaction(async (tx) => {
    const snap = await tx.get(ref); if (!snap.exists) throw new HttpsError("not-found", "Sales submission no longer exists."); const sub = snap.data() || {};
    const revision = Number(sub.revision) || 1; if (sub.status !== "approved" || revision !== data.expectedRevision) throw new HttpsError("failed-precondition", "Sales submission revision is stale or not approved.");
    const month = await tx.get(db.collection(BRANCH_SALES_MONTHS).doc(`${branchId}_${sub.monthKey}`)); const totalAfter = await approvedTotal(tx, branchId, sub.monthKey); const before = totalAfter; const after = before - Number(sub.amountPiastres || 0) + data.amountPiastres;
    const crossing = month.exists && targetAchievedCrossing(before, after, Number((month.data() || {}).targetPiastres));
    tx.update(ref, { amountPiastres: data.amountPiastres, revision: revision + 1, lastEditedById: actor.id, lastEditedByName: actor.name, lastEditedAt: admin.firestore.FieldValue.serverTimestamp(), updatedAt: admin.firestore.FieldValue.serverTimestamp() });
    result = { sub, oldAmount: sub.amountPiastres, revision: revision + 1, crossing };
  });
  try { await writeSalesAudit({ eventType: "sales.approved_amount_edited", entityType: "daily_sales_submission", entityId: submissionId, actor, branchId, metadata: { branchId, monthKey: result.sub.monthKey, businessDateKey: result.sub.businessDateKey, submissionId, oldAmountPiastres: result.oldAmount, newAmountPiastres: data.amountPiastres, revision: result.revision, reason, schemaVersion: 1 } });
    if (result.crossing) await writeSalesNotifications(await salesRecipients(branchId), { title: "Sales target achieved", body: "Your branch has reached its monthly sales target.", submissionId, monthKey: result.sub.monthKey });
  } catch (err) { logger.warn("failed to write sales edit side effects", { error: String(err), submissionId }); }
  return { success: true, revision: result.revision };
});

exports.resubmitCorrectedSales = onCall(async (request) => {
  if (!request.auth) throw new HttpsError("unauthenticated", "Please sign in.");
  const data = request.data || {}; const submissionId = String(data.submissionId || "").trim();
  if (!submissionId || !isValidMoney(data.amountPiastres)) throw new HttpsError("invalid-argument", "Invalid corrected sales amount.");
  const ref = db.collection(BRANCH_SALES_SUBMISSIONS).doc(submissionId); const initial = await ref.get();
  if (!initial.exists) throw new HttpsError("not-found", "Sales submission no longer exists.");
  const initialSub = initial.data() || {};
  if (initialSub.status !== "correctionRequested") throw new HttpsError("failed-precondition", "This sales submission is not awaiting correction.");
  if (initialSub.submittedById !== request.auth.uid) throw new HttpsError("permission-denied", "You can only correct your own sales submission.");
  const userSnap = await db.collection(USERS).doc(request.auth.uid).get();
  const actor = salesActor(userSnap.exists ? (userSnap.data() || {}) : {}, request.auth.uid); let result;
  await db.runTransaction(async (tx) => {
    const snap = await tx.get(ref); if (!snap.exists) throw new HttpsError("not-found", "Sales submission no longer exists.");
    const sub = snap.data() || {};
    if (sub.status !== "correctionRequested") throw new HttpsError("failed-precondition", "This sales submission is no longer awaiting correction.");
    if (sub.submittedById !== request.auth.uid) throw new HttpsError("permission-denied", "You can only correct your own sales submission.");
    const transition = nextStatus(String(sub.status || ""), "resubmit", "employee");
    if (transition.error) throw new HttpsError("failed-precondition", "This sales submission cannot be resubmitted now.");
    const revision = Number(sub.revision) || 1;
    tx.update(ref, { status: transition.status, amountPiastres: data.amountPiastres, revision: revision + 1,
      submittedAt: admin.firestore.FieldValue.serverTimestamp(), updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      decisionById: admin.firestore.FieldValue.delete(), decisionByName: admin.firestore.FieldValue.delete(), decisionByRole: admin.firestore.FieldValue.delete(), decisionAt: admin.firestore.FieldValue.delete(), decisionReason: admin.firestore.FieldValue.delete() });
    result = { sub, revision: revision + 1 };
  });
  try { await writeSalesAudit({ eventType: "sales.resubmitted", entityType: "daily_sales_submission", entityId: submissionId, actor, branchId: result.sub.branchId, metadata: { branchId: result.sub.branchId, monthKey: result.sub.monthKey, businessDateKey: result.sub.businessDateKey, submissionId, oldAmountPiastres: result.sub.amountPiastres, newAmountPiastres: data.amountPiastres, oldStatus: result.sub.status, newStatus: "pending", revision: result.revision, schemaVersion: 1 } });
    await writeSalesNotifications(await salesRecipients(String(result.sub.branchId || ""), { managersOnly: true, adminsFallback: true }), { title: "Corrected sales submission", body: "A corrected daily sales submission is ready for review.", submissionId, monthKey: result.sub.monthKey });
  } catch (err) { logger.warn("failed to write sales resubmit side effects", { error: String(err), submissionId }); }
  return { success: true, status: "pending", revision: result.revision };
});

exports.onDailySalesSubmissionCreated = onDocumentCreated(`${BRANCH_SALES_SUBMISSIONS}/{submissionId}`, async (event) => {
  const sub = event.data && event.data.data(); if (!sub || sub.status !== "pending") return;
  try { await writeSalesNotifications(await salesRecipients(String(sub.branchId || ""), { managersOnly: true, adminsFallback: true }), { title: "New sales submission", body: "A daily sales submission is ready for review.", submissionId: event.params.submissionId, monthKey: sub.monthKey }); }
  catch (err) { logger.warn("failed to write new sales submission notification", { error: String(err), submissionId: event.params.submissionId }); }
});

/**
 * Firestore trigger: deliver the FCM push for a newly-created in-app
 * notification (Notification System Phase 1 — the task-event push path).
 *
 * Task notifications are written by the client (`NotifyTaskEvent`); this trigger
 * reads the recipient's `fcmTokens` and pushes. Broadcast notifications carry
 * `pushedByFunction:true` (already pushed by `sendBroadcast`), so they are
 * skipped here to avoid a double push.
 */
// ─────────────────────────────────────────────────────────────────────────────
// claimFcmToken — guarantees EXCLUSIVE token ownership (the FCM routing fix).
//
// Root problem: an FCM token is per-device, not per-user, and the client can
// only ADD it to the signed-in user's `fcmTokens` (clients can't write OTHER
// users' docs — firestore.rules). The only cross-user cleanup is the client's
// best-effort `forgetUser` on logout; if that fails (offline / force-kill /
// timing) the SAME token stays attached to multiple users, so a send to the old
// user reaches a device now used by someone else (cross-user notification leak).
//
// Fix: whenever a token is ADDED to a user, claim it exclusively here (admin
// privileges) — remove it from every OTHER user's `fcmTokens` and clear any
// matching legacy `fcmToken`. A token then belongs to AT MOST ONE user (the most
// recent to register it), independent of whether the client cleanup ran.
//
// Loop-safe: removing a token from another user SHRINKS their array (no token
// ADDED), so that update's `added` set is empty → early return, no cascade.
exports.claimFcmToken = onDocumentUpdated(`${USERS}/{uid}`, async (event) => {
  const before = event.data.before.data() || {};
  const after = event.data.after.data() || {};
  const beforeTokens = new Set(
    Array.isArray(before.fcmTokens) ? before.fcmTokens : []);
  const afterTokens = Array.isArray(after.fcmTokens) ? after.fcmTokens : [];
  const added = afterTokens.filter((t) => t && !beforeTokens.has(t));
  if (added.length === 0) return; // nothing claimed → loop-safe no-op

  const uid = event.params.uid;
  for (const token of added) {
    try {
      // Other users still holding this token in their array.
      const dupes = await db
        .collection(USERS)
        .where("fcmTokens", "array-contains", token)
        .get();
      // Other users holding it as the legacy single field.
      const legacy = await db
        .collection(USERS)
        .where("fcmToken", "==", token)
        .get();

      const batch = db.batch();
      let count = 0;
      dupes.forEach((d) => {
        if (d.id === uid) return; // keep it on the claimant
        batch.update(d.ref, {
          fcmTokens: admin.firestore.FieldValue.arrayRemove(token),
        });
        count++;
      });
      legacy.forEach((d) => {
        if (d.id === uid) return;
        batch.update(d.ref, {
          fcmToken: admin.firestore.FieldValue.delete(),
        });
        count++;
      });
      if (count > 0) {
        await batch.commit();
        logger.info("claimFcmToken: reclaimed a token", { uid, removedFrom: count });
      }
    } catch (err) {
      logger.warn("claimFcmToken failed", { uid, error: String(err) });
    }
  }
});

/**
 * The ONLY path a client has for creating in-app notifications (M2 fix,
 * 2026-07-03). Direct `notifications/{id}` creates are denied by rules —
 * every notification doc a client produces goes through this callable, which
 * validates before writing (the docs then flow to `onNotificationCreated`
 * for push, unchanged):
 *   - the caller must be signed in, exist, and be active;
 *   - `type` must be one of the CLIENT-legit types (task lifecycle + swap
 *     workflow — reminder/broadcast types are produced server-side only);
 *   - every recipient must exist and be REACHABLE by the caller: an admin
 *     reaches anyone; everyone else only their own branch (covers all real
 *     flows: coworker swaps, employee→manager review pings, manager→staff
 *     assignments);
 *   - title/body are length-capped; the payload is reduced to known keys;
 *   - `senderUid` is SERVER-STAMPED from auth — never forgeable.
 */
const CLIENT_NOTIFICATION_TYPES = new Set([
  "taskAssigned", "taskRework", "taskSubmitted", "taskApproved", "taskRejected",
  // A manager/admin cancels client-side, so the cancel notice is client-sent;
  // an employee files a report-incorrect the same way. `taskMissed` is
  // deliberately ABSENT — the sweep is its only writer (Admin SDK).
  "taskCancelled", "taskReportedIncorrect",
  "swapRequested", "swapAccepted", "swapApproved", "swapRejected",
]);
const NOTIFICATION_PAYLOAD_KEYS = ["taskId", "route", "revisionNumber", "swapId"];

exports.sendNotification = onCall(async (request) => {
  const auth = request.auth;
  if (!auth) {
    throw new HttpsError("unauthenticated", "Please sign in.");
  }
  const callerSnap = await db.collection(USERS).doc(auth.uid).get();
  if (!callerSnap.exists) {
    throw new HttpsError("permission-denied", "Your account profile was not found.");
  }
  const caller = callerSnap.data() || {};
  if (caller.isActive === false) {
    throw new HttpsError("permission-denied", "This account is disabled.");
  }
  const callerIsAdmin = (caller.role || "employee") === "admin";
  const callerBranch = String(caller.branchId || "");

  const items = Array.isArray(request.data && request.data.notifications)
    ? request.data.notifications
    : [];
  if (items.length === 0 || items.length > 50) {
    throw new HttpsError("invalid-argument", "Send between 1 and 50 notifications.");
  }

  const batch = db.batch();
  let queued = 0;
  for (const raw of items) {
    const recipientUid = String((raw && raw.recipientUid) || "").trim();
    const type = String((raw && raw.type) || "").trim();
    const title = String((raw && raw.title) || "").trim().slice(0, 120);
    const body = String((raw && raw.body) || "").trim().slice(0, 500);
    if (!recipientUid || (!title && !body)) {
      throw new HttpsError("invalid-argument", "Each notification needs a recipient and content.");
    }
    if (!CLIENT_NOTIFICATION_TYPES.has(type)) {
      throw new HttpsError("invalid-argument", `"${type}" is not a client notification type.`);
    }

    // Reachability: admin → anyone; others → own branch only.
    const recipientSnap = await db.collection(USERS).doc(recipientUid).get();
    if (!recipientSnap.exists) continue; // stale recipient — skip, not fatal
    const recipientBranch = String((recipientSnap.data() || {}).branchId || "");
    const reachable = callerIsAdmin
      || (callerBranch !== "" && recipientBranch === callerBranch);
    if (!reachable) {
      throw new HttpsError(
        "permission-denied",
        "You can only notify people in your own branch.",
      );
    }

    // Sanitized payload — only the keys the tap handler understands.
    const rawPayload = (raw && raw.payload) || {};
    const payload = {};
    for (const k of NOTIFICATION_PAYLOAD_KEYS) {
      if (rawPayload[k] !== undefined && rawPayload[k] !== null) {
        payload[k] = typeof rawPayload[k] === "number"
          ? rawPayload[k]
          : String(rawPayload[k]);
      }
    }

    const ref = db.collection(NOTIFICATIONS).doc();
    batch.set(ref, {
      id: ref.id,
      recipientUid,
      senderUid: auth.uid, // server-stamped — the client cannot forge this
      type,
      title,
      body,
      readAt: null,
      payload,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    queued++;
  }

  if (queued > 0) await batch.commit();
  return { created: queued };
});

exports.onNotificationCreated = onDocumentCreated(
  `${NOTIFICATIONS}/{id}`,
  async (event) => {
    const snap = event.data;
    if (!snap) return;
    const n = snap.data() || {};

    // Already pushed by the broadcast engine — don't double-send.
    if (n.pushedByFunction === true) return;

    const recipientUid = String(n.recipientUid || "").trim();
    if (!recipientUid) return;

    const title = String(n.title || "").trim();
    const body = String(n.body || "").trim();
    if (!title && !body) return;

    // Gather the recipient's device tokens (array + legacy single field).
    const userSnap = await db.collection(USERS).doc(recipientUid).get();
    if (!userSnap.exists) return;
    const user = userSnap.data() || {};
    const tokenSet = new Set();
    if (Array.isArray(user.fcmTokens)) {
      for (const t of user.fcmTokens) if (t) tokenSet.add(t);
    }
    if (user.fcmToken) tokenSet.add(user.fcmToken);
    const tokens = Array.from(tokenSet);
    if (tokens.length === 0) return;

    const payload = n.payload || {};
    // Data values must be strings — they ride along to the tap handler, which
    // feeds them to the shared deep-link resolver. EVERY target id the resolver
    // reads must be forwarded here or the deep link is lost on a background /
    // cold-start tap: taskId · caseId · requestId · broadcastId · swapId
    // (schedule route) · recordId (attendance route). `route` selects which id
    // the resolver uses.
    const message = {
      notification: { title, body },
      data: {
        type: String(n.type || ""),
        // Intended recipient — the client drops a push whose recipientUid != the
        // signed-in user (defense-in-depth #3). This path is already per-recipient.
        recipientUid: String(recipientUid),
        taskId: String(payload.taskId || ""),
        caseId: String(payload.caseId || ""),
        requestId: String(payload.requestId || ""),
        broadcastId: String(payload.broadcastId || ""),
        swapId: String(payload.swapId || ""),
        // Attendance corrections / auto-closed sessions. Without recordId a
        // background tap can only reach the ledger, not the exact record.
        recordId: String(payload.recordId || ""),
        correctionId: String(payload.correctionId || ""),
        category: String(payload.category || ""),
        revisionNumber:
          payload.revisionNumber == null ? "" : String(payload.revisionNumber),
        route: String(payload.route || ""),
      },
    };

    // Push (chunked) + prune dead tokens.
    const removals = [];
    let successCount = 0;
    let failureCount = 0;
    for (let i = 0; i < tokens.length; i += MULTICAST_CHUNK) {
      const batch = tokens.slice(i, i + MULTICAST_CHUNK);
      const response = await messaging.sendEachForMulticast({ ...message, tokens: batch });
      successCount += response.successCount;
      failureCount += response.failureCount;
      response.responses.forEach((r, idx) => {
        if (r.success) return;
        const code = r.error && r.error.code;
        // DIAGNOSTIC: the EXACT per-token failure reason (FCM discards it). See
        // the broadcast path for the common codes (APNs / stale-token).
        logger.warn("task notification token send failed", {
          recipientUid,
          tokenSuffix: String(batch[idx]).slice(-10),
          code,
          message: r.error && r.error.message,
        });
        if (isDeadTokenError(code)) removals.push(batch[idx]);
      });
    }
    if (removals.length > 0) {
      await db
        .collection(USERS)
        .doc(recipientUid)
        .update({ fcmTokens: admin.firestore.FieldValue.arrayRemove(...removals) })
        .catch(() => {});
    }

    // Log REAL delivery, not just the attempt count. `tokenCount` alone (the old
    // log) made a 0-delivered push look healthy.
    logger.info("notification pushed", {
      type: n.type,
      recipientUid,
      tokenCount: tokens.length,
      successCount,
      failureCount,
    });
  },
);

// ── Recurrence math (mirrors lib/.../recurrence_rule.dart) ──
function addDays(date, days) {
  const d = new Date(date.getTime());
  d.setDate(d.getDate() + days);
  return d;
}
function addMonths(date, months) {
  const d = new Date(date.getTime());
  const day = d.getDate();
  d.setDate(1);
  d.setMonth(d.getMonth() + months);
  const lastDay = new Date(d.getFullYear(), d.getMonth() + 1, 0).getDate();
  d.setDate(Math.min(day, lastDay));
  return d;
}

// The next run strictly after `from` (a JS Date) for a schedule doc, or null
// when the series has completed (one-time, or past endDate).
function computeScheduleNextRun(s, from) {
  const type = s.recurrenceType || "oneTime";
  if (type === "oneTime") return null;
  let next;
  if (type === "daily") next = addDays(from, 1);
  else if (type === "weekly") next = addDays(from, 7);
  else if (type === "monthly") next = addMonths(from, 1);
  else if (type === "custom") next = addDays(from, Math.max(1, Number(s.interval) || 1));
  else return null;
  const endDate = s.endDate && s.endDate.toDate ? s.endDate.toDate() : null;
  if (endDate && next > endDate) return null;
  return admin.firestore.Timestamp.fromDate(next);
}

/**
 * The scheduled-broadcast poller (Phase 2 Commit 4) — the chosen scheduler
 * architecture (a single onSchedule function, not per-schedule Cloud Scheduler
 * jobs): scales to any number of schedules with one cron job. Every 5 minutes it
 * fires every due, enabled schedule through the shared `dispatchBroadcast`
 * engine, then advances `nextRunAt` from the recurrence rule (or disables a
 * completed one-time / past-endDate schedule). Up to ~5-min firing granularity.
 *
 * Query is `nextRunAt <= now` only (a single-field inequality — automatic index);
 * the `enabled` flag is filtered in JS to avoid a composite index.
 */
exports.runBroadcastSchedules = onSchedule("every 5 minutes", async () => {
  const now = admin.firestore.Timestamp.now();
  const snap = await db
    .collection(BROADCAST_SCHEDULES)
    .where("nextRunAt", "<=", now)
    .get();

  let fired = 0;
  for (const doc of snap.docs) {
    const s = doc.data() || {};
    if (s.enabled === false) continue; // paused

    const expectedNextRunAt = s.nextRunAt;
    const expectedNextRunAtMs =
      expectedNextRunAt && typeof expectedNextRunAt.toMillis === "function"
        ? expectedNextRunAt.toMillis()
        : null;
    if (expectedNextRunAtMs == null) continue;

    // Claim before dispatch. A claim deliberately remains if finalization later
    // fails: at this scale, avoiding a duplicate org-wide broadcast wins over
    // retrying an uncertain send.
    const claimed = await db.runTransaction(async (tx) => {
      const current = await tx.get(doc.ref);
      const currentData = current.exists ? current.data() || {} : null;
      if (!canClaimScheduledBroadcast(currentData, expectedNextRunAtMs)) return false;
      tx.update(doc.ref, {
        dispatchClaimedFor: expectedNextRunAt,
        dispatchClaimedAt: now,
      });
      return true;
    });
    if (!claimed) continue;

    // The sender's current branch (for a manager's custom-recipient filter).
    let senderBranch = "";
    try {
      const u = await db.collection(USERS).doc(String(s.senderId || "")).get();
      senderBranch = u.exists ? u.data().branchId || "" : "";
    } catch (_) {
      // best-effort
    }

    try {
      await dispatchBroadcast({
        senderId: s.senderId,
        senderRole: s.senderRole,
        senderBranch,
        senderName: s.senderName,
        title: s.title,
        body: s.message,
        category: s.category,
        sendsPush: s.sendsPush,
        audience: s.audience,
        branchId: s.branchId || "",
        targetUserId: "",
        targetUserIds: Array.isArray(s.targetUserIds) ? s.targetUserIds : [],
        roleFilter: s.roleFilter || "",
      });
      fired += 1;
    } catch (err) {
      logger.error("schedule dispatch failed after claim; run consumed", {
        id: doc.id,
        error: String(err),
      });
    }

    const nextRunAt = computeScheduleNextRun(s, now.toDate());
    await doc.ref
      .update({
        lastRunAt: now,
        runCount: (Number(s.runCount) || 0) + 1,
        nextRunAt: nextRunAt, // null disables a completed schedule
        enabled: nextRunAt !== null,
        dispatchClaimedFor: admin.firestore.FieldValue.delete(),
        dispatchClaimedAt: admin.firestore.FieldValue.delete(),
      })
      .catch((err) =>
        logger.warn("schedule advance failed", { id: doc.id, error: String(err) }),
      );
  }

  logger.info("broadcast schedules run", { due: snap.size, fired });
});

/**
 * Daily housekeeping (retention / cleanup): hard-deletes long-dead docs so the
 * collections stay lean — archived notifications older than 60 days.
 */
exports.broadcastHousekeeping = onSchedule("every 24 hours", async () => {
  const now = Date.now();
  const cutoff = (days) =>
    admin.firestore.Timestamp.fromMillis(now - days * 24 * 60 * 60 * 1000);

  const deleteQuery = async (query, label) => {
    let removed = 0;
    // Page in chunks to respect the 500-write batch limit.
    // eslint-disable-next-line no-constant-condition
    while (true) {
      const snap = await query.limit(BATCH_LIMIT).get();
      if (snap.empty) break;
      const batch = db.batch();
      snap.docs.forEach((d) => batch.delete(d.ref));
      await batch.commit();
      removed += snap.size;
      if (snap.size < BATCH_LIMIT) break;
    }
    if (removed > 0) logger.info(`housekeeping removed ${removed} ${label}`);
  };

  try {
    await deleteQuery(
      db.collection(NOTIFICATIONS).where("archivedAt", "<=", cutoff(60)),
      "old archived notifications",
    );
  } catch (err) {
    logger.warn("housekeeping failed", { error: String(err) });
  }
});

// ── Task reminder rules (mirrors lib/features/task/domain/reminder_rules.dart) ──
const REMINDER_ORDER = ["due24h", "due1h", "overdue"];

function reminderInQuietHours(hour, startHour, endHour) {
  if (startHour === endHour) return false;
  if (startHour < endHour) return hour >= startHour && hour < endHour;
  return hour >= startHour || hour < endHour; // wraps midnight
}

function reminderDueKind(deadline, now, lastKind, count, cfg) {
  if (!cfg.enabled) return null;
  if (count >= cfg.maxReminders) return null;
  if (reminderInQuietHours(now.getUTCHours(), cfg.quietStartHour, cfg.quietEndHour)) {
    return null;
  }
  const diffMs = deadline.getTime() - now.getTime();
  let kind;
  if (diffMs < 0) kind = "overdue";
  else if (diffMs <= 60 * 60 * 1000) kind = "due1h";
  else if (diffMs <= 24 * 60 * 60 * 1000) kind = "due24h";
  else return null;
  // Only escalate forward.
  if (lastKind && REMINDER_ORDER.indexOf(kind) <= REMINDER_ORDER.indexOf(lastKind)) {
    return null;
  }
  return kind;
}

/**
 * Automated task reminders (Phase 2 Commit 5). Every 30 minutes it scans tasks
 * due within 24h (or overdue) and sends an in-app + push reminder to the
 * assignees, escalating due24h → due1h → overdue with a per-task ledger
 * (`taskReminders/{taskId}`) + quiet hours + a max-reminders cap to avoid spam.
 * Config lives in `reminderConfig/global` (defaults applied when absent). Quiet
 * hours are evaluated in UTC (the function's timezone).
 *
 * Which statuses still get reminded lives in `task_reminders.js` — read the
 * comment there before changing it; the set deliberately differs from the
 * canonical `isTerminalTaskStatus`.
 */
exports.runTaskReminders = onSchedule({ schedule: "every 30 minutes", maxInstances: 1, retryCount: 0, timeoutSeconds: 300 }, async () => {
  const now = new Date();

  // Config (defaults when the doc is absent).
  let cfg = { enabled: true, quietStartHour: 22, quietEndHour: 7, maxReminders: 3 };
  try {
    const cSnap = await db.collection(REMINDER_CONFIG).doc("global").get();
    if (cSnap.exists) {
      const c = cSnap.data() || {};
      cfg = {
        enabled: c.enabled !== false,
        quietStartHour: Number.isFinite(c.quietStartHour) ? c.quietStartHour : 22,
        quietEndHour: Number.isFinite(c.quietEndHour) ? c.quietEndHour : 7,
        maxReminders: Number.isFinite(c.maxReminders) ? c.maxReminders : 3,
      };
    }
  } catch (_) {
    // best-effort; use defaults
  }
  if (!cfg.enabled) {
    logger.info("task reminders disabled");
    return;
  }

  // Tasks due within 24h or already overdue (single-field inequality).
  const soon = admin.firestore.Timestamp.fromMillis(now.getTime() + 24 * 60 * 60 * 1000);
  const snap = await db.collection(TASKS).where("deadline", "<=", soon).get();

  let sent = 0;
  for (const doc of snap.docs) {
    const t = doc.data() || {};
    if (!isReminderEligibleStatus(t.status)) continue;
    const deadline = t.deadline && t.deadline.toDate ? t.deadline.toDate() : null;
    if (!deadline) continue;
    const assignees = Array.isArray(t.assigneeIds) ? t.assigneeIds.filter(Boolean) : [];
    if (assignees.length === 0) continue;

    // Per-task reminder ledger.
    const ledgerRef = db.collection(TASK_REMINDERS).doc(doc.id);
    let lastKind = null;
    let count = 0;
    try {
      const lSnap = await ledgerRef.get();
      if (lSnap.exists) {
        const l = lSnap.data() || {};
        lastKind = l.lastKind || null;
        count = Number(l.count) || 0;
      }
    } catch (_) {
      // best-effort
    }

    const kind = reminderDueKind(deadline, now, lastKind, count, cfg);
    if (!kind) continue;

    const type = kind === "overdue" ? "taskOverdue" : "taskReminder";
    const title = kind === "overdue" ? "Task Late" : "Task Reminder";
    const dueLabel = kind === "overdue" ? "is late" : "is due soon";
    const body = `${t.title || "A task"} ${dueLabel}`;
    const payload = { taskId: doc.id, route: "task_details", kind };

    try {
      const batch = db.batch();
      for (const uid of assignees) {
        const ref = db.collection(NOTIFICATIONS).doc();
        batch.set(ref, {
          id: ref.id,
          recipientUid: uid,
          senderUid: "system",
          type,
          title,
          body,
          readAt: null,
          payload,
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
        });
      }
      await batch.commit();
      await ledgerRef.set(
        {
          taskId: doc.id,
          lastKind: kind,
          count: count + 1,
          lastSentAt: admin.firestore.FieldValue.serverTimestamp(),
        },
        { merge: true },
      );
      sent += 1;
    } catch (err) {
      logger.warn("task reminder failed", { taskId: doc.id, error: String(err) });
    }
  }

  logger.info("task reminders run", { scanned: snap.size, sent });
});

// ── Recurring shift-task instance generation (Shift Assignment feature) ──

// Automation date helpers. "Today" is the business civil day in Africa/Cairo
// (Automated Tasks spec §12.2), not the Cloud Function host's UTC calendar.
function isoDate(d) {
  return businessDayParts(d).dateKey;
}

// 1 = Monday … 7 = Sunday (matches RecurringTaskTemplateEntity.weekday /
// Dart's DateTime.weekday convention).
function isoWeekday(d) {
  return businessDayParts(d).isoWeekday;
}

// weekly_schedules.assignments.<day> key spelling — matches SWAP_DAY_INDEX.
function scheduleDayName(d) {
  return businessDayParts(d).dayName;
}

// The Sunday that starts the business week containing d, as a
// yyyy-MM-dd key — mirrors ScheduleWeek.startOf/docId (`<branchId>_<key>`).
function weekStartKey(d) {
  return businessWeekStartKey(d);
}

function legacyUtcDateKey(d) {
  const y = d.getUTCFullYear();
  const m = String(d.getUTCMonth() + 1).padStart(2, "0");
  const day = String(d.getUTCDate()).padStart(2, "0");
  return `${y}-${m}-${day}`;
}

function addCivilDays(year, month, day, days) {
  const date = new Date(Date.UTC(year, month - 1, day + days));
  return {
    year: date.getUTCFullYear(),
    month: date.getUTCMonth() + 1,
    day: date.getUTCDate(),
  };
}

// True when a Firestore write failed because the document already exists — the
// signal that `ref.create()` lost the idempotency race (a concurrent run / retry
// already generated this instance). gRPC code 6 = ALREADY_EXISTS.
function isAlreadyExists(err) {
  return !!err && (err.code === 6 || err.code === "already-exists" ||
    /already exists/i.test(String(err && err.message)));
}

// Resolves the employees who should be NOTIFIED of a generated shift task:
// rostered on (dayName, shift) MINUS anyone on leave that day MINUS deactivated
// accounts. Returns `{ uid, name }` for each eligible recipient (name for the
// run record's target block). An empty result is valid (nobody eligible) — the
// task is still created; it just notifies no one and the run records
// `noEligibleEmployees`.
async function eligibleRecipients(scheduleData, dayName, shift) {
  const rostered = swapAssignedUids(scheduleData.assignments || {}, dayName, shift);
  if (!rostered.length) return [];
  const onLeave = new Set(Object.keys((scheduleData.leave || {})[dayName] || {}));
  const candidates = rostered.filter((uid) => !onLeave.has(uid));
  if (!candidates.length) return [];
  const snaps = await Promise.all(
    candidates.map((uid) => db.collection(USERS).doc(uid).get()),
  );
  return snaps
    .filter((s) => s.exists && (s.data() || {}).isActive !== false)
    .map((s) => {
      const d = s.data() || {};
      return {
        uid: s.id,
        name: String(d.fullName || d.displayName || d.email || s.id),
        role: d.role != null ? String(d.role) : null,
      };
    });
}

// Advisory next-run timestamp for a template's rollup (the Automation Center
// shows it). Daily → tomorrow; weekly → the next matching business weekday.
function computeNextRun(repeat, weekday, now) {
  const today = businessDayParts(now);
  if (!today) return admin.firestore.Timestamp.fromDate(now);
  let next = today;
  if (repeat === "weekly") {
    for (let i = 0; i < 7; i++) {
      const civil = addCivilDays(next.year, next.month, next.day, 1);
      const midnightMs = businessCivilMidnightMs(civil.year, civil.month, civil.day);
      if (midnightMs == null) return admin.firestore.Timestamp.fromDate(now);
      next = businessDayParts(midnightMs);
      if (next && next.isoWeekday === Number(weekday)) break;
    }
  } else {
    const civil = addCivilDays(today.year, today.month, today.day, 1);
    const midnightMs = businessCivilMidnightMs(civil.year, civil.month, civil.day);
    if (midnightMs == null) return admin.firestore.Timestamp.fromDate(now);
    next = businessDayParts(midnightMs);
  }
  const nextMidnightMs = next
    ? businessCivilMidnightMs(next.year, next.month, next.day)
    : null;
  const runAtMs = nextMidnightMs != null
    ? nextMidnightMs + 60 * 60 * 1000
    : now.getTime();
  return admin.firestore.Timestamp.fromMillis(runAtMs);
}

// Writes ONE business audit event to `audit_logs` as the "system" actor,
// matching the app's `AuditLogModel` shape so automation events render in the
// audit feed. Best-effort (audit is observability, never blocks the run).
async function writeAutomationAudit(eventType, entityType, entityId, branchId, metadata) {
  try {
    await db.collection(AUDIT_LOGS).add({
      eventType,
      entityType,
      entityId,
      actorId: "system",
      actorName: "Automation",
      actorRole: "admin",
      branchId: branchId || null,
      metadata: metadata || {},
      schemaVersion: 1,
      isDeleted: false,
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
    });
  } catch (e) {
    logger.warn("automation audit write failed", { eventType, entityId, error: String(e) });
  }
}

/**
 * Daily instance generation for recurring shift-task templates (Shift
 * Assignment feature). Scans active `recurringTaskTemplates` and, for each one
 * due today (daily, or weekly matching today's ISO weekday), creates *one* real
 * `tasks/{id}` document at a **deterministic business-date id**
 * (`rt_{templateId}_{yyyy-MM-dd}`, Africa/Cairo). It is pinned to 01:00
 * Africa/Cairo so generation runs before the earliest shift starts. Duplicate
 * prevention is an **atomic `ref.create()`** (throws
 * ALREADY_EXISTS → skip), so overlapping runs / scheduler retries can never
 * double-create or double-notify; `maxInstances:1` additionally prevents
 * overlap. Roster notifications go only to ELIGIBLE employees (rostered, not on
 * leave, active) with **deterministic notification ids**. Every attempt records
 * operational telemetry to `automationRuns/{templateId}_{dateKey}` (deterministic
 * id → idempotent history), rolls its outcome up onto the template
 * (lastRunAt/nextRunAt/lastStatus/lastGeneratedTaskId/failureCount for the
 * Automation Center), and emits business audit events to `audit_logs`. See
 * docs/design/AUTOMATION_ENGINE.md.
 */
exports.generateShiftTaskInstances = onSchedule(
  {
    schedule: "0 1 * * *",
    timeZone: BUSINESS_TIME_ZONE,
    maxInstances: 1,
    retryCount: 0,
    timeoutSeconds: 300,
  },
  async (event) => {
    const now = new Date();
    const todayKey = isoDate(now);
    const todayDow = isoWeekday(now);
    const dayName = scheduleDayName(now);
    const executionId = require("crypto").randomUUID();
    // The tick this invocation was scheduled for (for the run's schedule block +
    // execution-delay metric); falls back to `now` if the platform omits it.
    const scheduledAt =
      event && event.scheduleTime ? new Date(event.scheduleTime) : now;
    const scheduledAtMs = scheduledAt.getTime();

    const snap = await db
      .collection(RECURRING_TASK_TEMPLATES)
      .where("active", "==", true)
      .get();

    let created = 0;
    for (const doc of snap.docs) {
      const t = doc.data() || {};
      const repeat = t.repeat || "daily";
      // "once" is defensive only — the client never persists a template row
      // with repeat:"once" (a single shift task is created directly instead).
      if (repeat === "once") continue;
      if (repeat === "weekly" && Number(t.weekday) !== todayDow) continue;

      const branchId = String(t.branchId || "");
      if (!branchId) continue;
      const shift = t.shift === "night" ? "night" : "morning";
      const instanceId = `rt_${doc.id}_${todayKey}`;
      const legacyTodayKey = legacyUtcDateKey(now);
      const legacyInstanceId = `rt_${doc.id}_${legacyTodayKey}`;
      const runId = `${doc.id}_${todayKey}`;
      // Deterministic correlation id for this execution (§Correlation ID) —
      // stamped on the run, the generated task, its notifications and its audit
      // events so any one traces back to the whole run. Derived from (templateId,
      // dateKey), so a retry re-computes the identical id (idempotent).
      const runCorrelationId = correlationId(doc.id, todayKey);
      const ref = db.collection(TASKS).doc(instanceId);
      const startedMs = Date.now();
      const version = Number(t.configVersion) || 1;

      // Per-template outcome — always recorded to `automationRuns` and rolled up
      // onto the template, whatever happens.
      let status = "completed"; // completed | skipped | failed
      let outcome = "created"; // created | alreadyExists | noEligibleEmployees | error
      let generatedTaskId = null;
      let recipientCount = 0;
      let failureReason = null;

      // ── Observability accumulators (ADR-011). None of this changes what tasks
      // or notifications are created — it only records what happened, why, and
      // when, so an admin can answer every question about a run without logs. ──
      const logs = []; // chronological execution timeline
      const step = (severity, message, meta) =>
        logs.push(logStep(Date.now(), _stageForNow(), severity, message, meta));
      let currentStage = "start";
      function _stageForNow() { return currentStage; }
      const stage = (s) => { currentStage = s; };

      let snapshot = null; // immutable execution snapshot (written on `created`)
      let scheduleExists = null; // null = not reached
      let scheduleData = null;
      let taskWindow = null;
      let employeesFound = null;
      const recipients = []; // { uid, name }
      const notificationIds = [];
      let notifySent = 0;
      let notifyFailed = 0;
      let errorBlock = null;
      let checklistCount = 0;

      stage("start");
      step(SEVERITY.info, "Execution started", { executionId });

      try {
        const checklist = Array.isArray(t.checklistItems)
          ? t.checklistItems.map((c) => ({
              id: String((c && c.id) || ""),
              title: String((c && c.title) || ""),
              isRequired: !c || c.isRequired !== false,
              completed: false,
              completedAt: null,
            }))
          : [];
        checklistCount = checklist.length;

        // Resolve the same frozen-week hours that attendance/scheduling use.
        // A missing/unreadable weekly document is deliberately non-fatal: the
        // standing shift hours are the durable fallback, just as they are in
        // the client. Reading once here also lets notification resolution reuse
        // the exact schedule snapshot that set this task's deadline.
        const scheduleId = `${branchId}_${weekStartKey(now)}`;
        try {
          const schedSnap = await db.collection(WEEKLY_SCHEDULES).doc(scheduleId).get();
          scheduleExists = schedSnap.exists;
          scheduleData = schedSnap.exists ? (schedSnap.data() || {}) : null;
        } catch (scheduleErr) {
          scheduleExists = null;
          step(SEVERITY.warning, "Weekly schedule unavailable; using standard shift hours", {
            scheduleId,
            error: String(scheduleErr),
          });
          logger.warn("recurring task schedule lookup failed", {
            templateId: doc.id,
            scheduleId,
            error: String(scheduleErr),
          });
        }
        taskWindow = resolveRecurringTaskWindow({
          schedule: scheduleData,
          occurrenceAt: now,
          day: dayName,
          shift,
        });
        if (!taskWindow) {
          throw new Error("Could not resolve recurring task shift window.");
        }

        stage("validate");
        step(SEVERITY.info, `Schedule window resolved for ${dayName} ${shift}`, {
          day: dayName,
          shift,
          branchId,
          source: taskWindow.source,
          startsAtMs: taskWindow.startsAtMs,
          deadlineMs: taskWindow.deadlineMs,
        });

        stage("generate");
        // Temporary transition guard for the UTC-key → business-date-key
        // convention change. If today's occurrence already exists under the
        // legacy UTC-derived id, this business occurrence is already spent; skip
        // exactly like an ALREADY_EXISTS on the new id. Delete once no live
        // UTC-keyed generated instance can remain.
        if (legacyTodayKey !== todayKey) {
          const legacySnap = await db.collection(TASKS).doc(legacyInstanceId).get();
          if (legacySnap.exists) {
            status = "skipped";
            outcome = "alreadyExists";
            step(SEVERITY.info, "Skipped — task already generated for today", {
              taskId: legacyInstanceId,
              legacyUtcDateKey: legacyTodayKey,
              businessDateKey: todayKey,
              windowBackfilled: false,
            });
          }
        }
        // Atomic create — the ENTIRE duplicate guarantee. `create()` rejects with
        // ALREADY_EXISTS if the deterministic id is already present (an overlapping
        // run / retry / the client materializer beat us), so we never double-create
        // and never double-notify.
        if (outcome !== "alreadyExists") {
          try {
            await ref.create({
              id: instanceId,
              title: t.title || "",
              description: t.description || null,
              type: "daily",
              status: "pending",
              priority: t.priority || "normal",
              branchId,
              assigneeIds: [],
              assignedEmployeeId: null,
              checklist,
              referenceAttachments: [],
              createdBy: t.createdBy || null,
              assignedShiftId: null,
              shift,
              assignmentType: "shift",
              instanceDate: admin.firestore.Timestamp.fromMillis(taskWindow.instanceDateMs),
              sourceTemplateId: doc.id,
              correlationId: runCorrelationId,
              startsAt: admin.firestore.Timestamp.fromMillis(taskWindow.startsAtMs),
              deadline: admin.firestore.Timestamp.fromMillis(taskWindow.deadlineMs),
              missedAt: null,
              notes: null,
              proofImageUrl: null,
              startedAt: null,
              submittedAt: null,
              approvedBy: null,
              approvedAt: null,
              rejectedBy: null,
              rejectedAt: null,
              reviewNotes: null,
              revisionNumber: 0,
              requiresRework: false,
              rejectionReason: null,
              recurrence: null,
              activityLog: [
                {
                  status: "pending",
                  actorId: "system",
                  actorName: null,
                  at: admin.firestore.Timestamp.fromDate(now),
                  note: "Auto-generated (recurring shift task)",
                  attachments: [],
                },
              ],
              createdAt: admin.firestore.FieldValue.serverTimestamp(),
              updatedAt: admin.firestore.FieldValue.serverTimestamp(),
            });
            generatedTaskId = instanceId;
            created++;
            step(SEVERITY.info, "Task generated", { taskId: instanceId });
          } catch (createErr) {
            if (isAlreadyExists(createErr)) {
              status = "skipped";
              outcome = "alreadyExists";
              // A pre-deployment app may have materialized this deterministic
              // instance without a deadline before the server run reached it.
              // Repair only missing window fields, transactionally, and never
              // overwrite a window already persisted for the occurrence.
              //
              // A TERMINAL instance is never touched — "no retry, regeneration or
              // repair may recreate, reopen, or overwrite it" (spec §4.4). Giving
              // an already-cancelled (or approved / missed) task a fresh deadline
              // would put a closed record back on the auto-end sweep's radar and
              // rewrite history nobody asked to change.
              let windowBackfilled = false;
              await db.runTransaction(async (tx) => {
                const existing = await tx.get(ref);
                if (!existing.exists) return;
                const existingTask = existing.data() || {};
                if (
                  existingTask.sourceTemplateId !== doc.id ||
                  existingTask.assignmentType !== "shift" ||
                  existingTask.deadline != null ||
                  isTerminalTaskStatus(existingTask.status)
                ) {
                  return;
                }
                tx.update(ref, {
                  instanceDate: admin.firestore.Timestamp.fromMillis(taskWindow.instanceDateMs),
                  startsAt: admin.firestore.Timestamp.fromMillis(taskWindow.startsAtMs),
                  deadline: admin.firestore.Timestamp.fromMillis(taskWindow.deadlineMs),
                  updatedAt: admin.firestore.FieldValue.serverTimestamp(),
                });
                windowBackfilled = true;
              });
              step(SEVERITY.info, "Skipped — task already generated for today", {
                taskId: instanceId,
                windowBackfilled,
              });
            } else {
              throw createErr;
            }
          }
        }

        // Notify eligible rostered employees — ONLY when we actually created the
        // instance this run (so a skipped duplicate never re-notifies).
        if (outcome === "created") {
          stage("notify");
          try {
            const resolved = scheduleExists
              ? await eligibleRecipients(scheduleData, dayName, shift)
              : [];
            recipients.push(...resolved);
            recipientCount = recipients.length;
            employeesFound = recipientCount > 0;
            step(SEVERITY.info, `Resolved ${recipientCount} eligible employee(s)`, {
              count: recipientCount,
            });

            // Capture the immutable execution snapshot (§Execution Snapshot):
            // exactly what existed now, so this run renders correctly forever
            // even after the definition/branch/employees/schedule change. One
            // branch read (for the name); everything else is already in hand.
            let branchName = null;
            try {
              const bSnap = await db.collection(BRANCHES).doc(branchId).get();
              branchName = bSnap.exists
                ? String((bSnap.data() || {}).name || "")
                : null;
            } catch (_) {
              // A missing branch name never fails the run — snapshot keeps null.
            }
            snapshot = buildExecutionSnapshot({
              templateId: doc.id,
              name: t.title || "",
              version,
              checklistCount,
              priority: t.priority || "normal",
              proofRequired: false,
              scheduleType: repeat,
              days: repeat === "weekly" ? [dayName] : [],
              shift,
              branchId,
              branchName,
              timezone: BUSINESS_TIME_ZONE,
              recipients,
            });

            if (recipients.length) {
              const batch = db.batch();
              for (const r of recipients) {
                // Deterministic id → even a re-entry can't create a second notice.
                const nref = db
                  .collection(NOTIFICATIONS)
                  .doc(`autoassign_${instanceId}_${r.uid}`);
                notificationIds.push(nref.id);
                batch.set(nref, {
                  id: nref.id,
                  recipientUid: r.uid,
                  senderUid: "system",
                  type: "taskAssigned",
                  title: "New Task Assigned",
                  body: t.title || "A new shift task was assigned",
                  readAt: null,
                  correlationId: runCorrelationId,
                  payload: {
                    taskId: instanceId,
                    route: "task_details",
                    correlationId: runCorrelationId,
                  },
                  createdAt: admin.firestore.FieldValue.serverTimestamp(),
                });
              }
              await batch.commit();
              notifySent = recipients.length;
              step(SEVERITY.info, `Sent ${notifySent} notification(s)`, {
                count: notifySent,
              });
            } else {
              outcome = "noEligibleEmployees";
              step(SEVERITY.warning, "No eligible employees to notify", {
                scheduleExists,
              });
            }
          } catch (notifyErr) {
            // A notify failure does NOT fail the run — the task exists regardless.
            notifyFailed = recipients.length;
            errorBlock = classifyError(notifyErr, "notify", { recovered: true });
            step(SEVERITY.warning, "Notification delivery failed (task kept)", {
              error: String(notifyErr),
            });
            logger.warn("shift task notify failed", {
              taskId: instanceId,
              error: String(notifyErr),
            });
          }
        }
      } catch (err) {
        status = "failed";
        outcome = "error";
        failureReason = String((err && err.message) || err);
        errorBlock = classifyError(err, currentStage);
        step(SEVERITY.error, `Execution failed at ${currentStage}`, {
          error: failureReason,
        });
        logger.warn("shift task instance generation failed", {
          templateId: doc.id,
          error: failureReason,
        });
      }

      stage("complete");
      step(
        status === "failed" ? SEVERITY.error : SEVERITY.info,
        status === "failed" ? "Execution failed" : "Execution completed",
        { status, outcome },
      );

      // ── Run telemetry (deterministic id → idempotent history) ──
      const finishedMs = Date.now();
      try {
        await db.collection(AUTOMATION_RUNS).doc(runId).set(
          {
            // ── Identity ──
            templateId: doc.id,
            automationName: t.title || "",
            version,
            branchId,
            dateKey: todayKey,
            executionId,
            correlationId: runCorrelationId,
            // ── Execution ──
            startedAt: admin.firestore.Timestamp.fromDate(new Date(startedMs)),
            finishedAt: admin.firestore.Timestamp.fromDate(new Date(finishedMs)),
            durationMs: finishedMs - startedMs,
            trigger: "schedule",
            retryCount: 0,
            status,
            outcome,
            // ── Schedule ──
            schedule: {
              scheduledAt: admin.firestore.Timestamp.fromDate(scheduledAt),
              actualAt: admin.firestore.Timestamp.fromDate(new Date(startedMs)),
              delayMs: executionDelayMs(scheduledAtMs, startedMs),
              shift,
              day: dayName,
              branchId,
            },
            // ── Validation ──
            validations: buildValidations({
              templatePresent: true,
              branchPresent: !!branchId,
              scheduleExists,
              employeesFound,
            }),
            // ── Target resolution (explicit even when nobody matched) ──
            target: {
              uids: recipients.map((r) => r.uid),
              names: recipients.map((r) => r.name),
              count: recipientCount,
              matched: recipientCount > 0,
              shift,
              branchId,
            },
            // ── Generation ──
            generation: {
              templateVersion: version,
              checklistCount,
              priority: t.priority || "normal",
              proofRequired: false,
            },
            generated: {
              taskIds: generatedTaskId ? [generatedTaskId] : [],
              titles: generatedTaskId ? [t.title || ""] : [],
              count: generatedTaskId ? 1 : 0,
              skippedCount: outcome === "alreadyExists" ? 1 : 0,
            },
            // ── Notification ──
            notification: {
              sent: notifySent,
              failed: notifyFailed,
              notificationIds,
            },
            // ── Error (null unless the run failed or a step recovered) ──
            error: errorBlock,
            // ── Chronological logs (embedded, bounded) ──
            logs: logs.map((l) => ({
              at: admin.firestore.Timestamp.fromMillis(l.at),
              stage: l.stage,
              severity: l.severity,
              message: l.message,
              meta: l.meta,
            })),
            // ── Immutable execution snapshot (written on `created` only, so a
            // later skip/failure never overwrites it — creation happens at most
            // once per deterministic run id) ──
            ...(snapshot ? { snapshot } : {}),
            // ── Back-compat flat fields (pre-ADR-011 readers / retention) ──
            generatedTaskId,
            recipientCount,
            failureReason,
          },
          { merge: true },
        );
      } catch (runErr) {
        logger.warn("automation run write failed", { runId, error: String(runErr) });
      }

      // ── Template rollup + cumulative health counters (Automation Center) ──
      try {
        const h = healthDeltas(status, finishedMs - startedMs);
        const rollup = {
          lastRunAt: admin.firestore.FieldValue.serverTimestamp(),
          nextRunAt: computeNextRun(repeat, t.weekday, now),
          lastStatus: status,
          // Cumulative counters — O(1) increments so the health panel is one
          // read; success rate / avg duration are DERIVED on the client (nothing
          // derived is stored — the ADR-011 line vs. an analytics pipeline).
          runCount: admin.firestore.FieldValue.increment(h.runCountDelta),
          successCount: admin.firestore.FieldValue.increment(h.successCountDelta),
          failedCount: admin.firestore.FieldValue.increment(h.failedCountDelta),
          skippedCount: admin.firestore.FieldValue.increment(h.skippedCountDelta),
          totalDurationMs: admin.firestore.FieldValue.increment(
            h.totalDurationMsDelta,
          ),
        };
        rollup.failureCount = h.resetConsecutiveFailures
          ? 0
          : admin.firestore.FieldValue.increment(1);
        if (h.markLastSuccess) {
          rollup.lastSuccessAt = admin.firestore.FieldValue.serverTimestamp();
        }
        if (h.markLastFailure) {
          rollup.lastFailureAt = admin.firestore.FieldValue.serverTimestamp();
        }
        if (status !== "failed" && generatedTaskId) {
          rollup.lastGeneratedTaskId = generatedTaskId;
        }
        await doc.ref.set(rollup, { merge: true });
      } catch (rollupErr) {
        logger.warn("automation rollup write failed", {
          templateId: doc.id,
          error: String(rollupErr),
        });
      }

      // ── Business audit events (best-effort, reuse the audit trail) ──
      // Each carries the correlationId so an audit entry traces to its run.
      if (outcome === "created" || outcome === "noEligibleEmployees") {
        await writeAutomationAudit("task.auto_generated", "task", instanceId, branchId, {
          templateId: doc.id,
          title: t.title || "",
          shift,
          correlationId: runCorrelationId,
        });
        if (recipientCount > 0) {
          await writeAutomationAudit("automation.assigned", "automation", doc.id, branchId, {
            taskId: instanceId,
            recipientCount,
            correlationId: runCorrelationId,
          });
        }
      } else if (status === "failed") {
        await writeAutomationAudit("automation.failed", "automation", doc.id, branchId, {
          reason: failureReason,
          correlationId: runCorrelationId,
        });
      }
    }

    logger.info("shift task instances generated", {
      templates: snap.size,
      created,
      executionId,
    });
  },
);

/**
 * Ends generated recurring shift tasks once their persisted shift deadline has
 * passed. This is deliberately server-authoritative: client clocks and app
 * foreground state cannot decide a terminal outcome. Only source-template
 * instances still in `pending`/`started` can become `missed`; completed and
 * review states are never rewritten. The query is index-backed and bounded to
 * one batch per 15-minute tick, while each candidate is revalidated in a
 * transaction so a simultaneous employee submission always wins safely.
 */
/**
 * Tells a human that a generated shift task was auto-closed as **Missed**
 * (Automated Tasks spec §9.1).
 *
 * Routed to the branch's active managers, or to admins when the branch has none
 * (see `selectMissedNotifyTargets` for why that is a fallback, not an addition).
 * Ids are **deterministic** (`taskmissed_{taskId}_{uid}`), so a retried sweep or
 * an overlapping run can never produce a second notice for the same miss.
 *
 * Best-effort: a notification failure must never undo the transition that has
 * already committed — the task is genuinely missed either way.
 */
async function notifyTaskMissed(taskId, ended) {
  const branchId = String(ended.branchId || "");
  try {
    const [managerSnap, adminSnap] = await Promise.all([
      branchId
        ? db.collection(USERS)
            .where("branchId", "==", branchId)
            .where("role", "==", "manager")
            .get()
        : Promise.resolve({ docs: [] }),
      db.collection(USERS).where("role", "==", "admin").get(),
    ]);
    const active = (snap) => snap.docs
      .filter((d) => (d.data() || {}).isActive !== false)
      .map((d) => d.id);

    const targets = selectMissedNotifyTargets({
      managers: active(managerSnap),
      admins: active(adminSnap),
    });
    if (targets.length === 0) return;

    const batch = db.batch();
    for (const uid of targets) {
      const ref = db.collection(NOTIFICATIONS).doc(`taskmissed_${taskId}_${uid}`);
      batch.set(ref, {
        id: ref.id,
        recipientUid: uid,
        senderUid: "system",
        type: "taskMissed",
        title: "Task Missed",
        body: ended.title
          ? `${ended.title} — the shift ended before it was done`
          : "A shift task ended before it was done",
        readAt: null,
        payload: { taskId, route: "task_details" },
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    }
    await batch.commit();
  } catch (err) {
    logger.warn("missed-task notification failed", {
      taskId,
      error: String(err),
    });
  }
}

exports.autoEndRecurringShiftTasks = onSchedule(
  { schedule: "every 15 minutes", maxInstances: 1, retryCount: 0, timeoutSeconds: 300 },
  async () => {
    const now = new Date();
    const nowTs = admin.firestore.Timestamp.fromDate(now);
    // The grace cutoff (ADR-013): a task is a candidate only once its deadline
    // is at least the grace period in the past. Narrowing the QUERY by the same
    // rule the transaction re-checks keeps one definition of "due" — a query
    // that fetched everything past the raw deadline would churn through tasks
    // still inside their tolerance on every 15-minute run.
    const graceCutoffTs = admin.firestore.Timestamp.fromMillis(
      now.getTime() - TASK_GRACE_MS,
    );
    let due;
    try {
      due = await db
        .collection(TASKS)
        .where("assignmentType", "==", "shift")
        .where("status", "in", ["pending", "started"])
        .where("deadline", "<=", graceCutoffTs)
        .orderBy("deadline", "asc")
        .limit(BATCH_LIMIT)
        .get();
    } catch (queryErr) {
      logger.error("recurring task auto-end query failed", {
        error: String(queryErr),
      });
      return;
    }

    let missed = 0;
    let skipped = 0;
    let failures = 0;
    for (const doc of due.docs) {
      let ended = null;
      try {
        await db.runTransaction(async (tx) => {
          const live = await tx.get(doc.ref);
          if (!live.exists) return;
          const task = live.data() || {};
          if (!shouldAutoEndRecurringTask({
            sourceTemplateId: String(task.sourceTemplateId || ""),
            status: task.status,
            archivedAt: task.archivedAt,
            deadline: task.deadline,
            nowMs: now.getTime(),
          })) {
            return;
          }

          const currentVersion = Number(task.version);
          const activityLog = Array.isArray(task.activityLog) ? task.activityLog : [];
          tx.update(doc.ref, {
            status: "missed",
            missedAt: nowTs,
            activityLog: [
              ...activityLog,
              {
                status: "missed",
                actorId: "system",
                actorName: "Automation",
                at: nowTs,
                note: "Automatically marked missed — the shift ended and the grace period passed.",
                attachments: [],
              },
            ],
            version: Number.isFinite(currentVersion) ? currentVersion + 1 : 1,
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          });
          ended = {
            branchId: String(task.branchId || ""),
            deadline: task.deadline || null,
            templateId: String(task.sourceTemplateId || ""),
            title: String(task.title || ""),
          };
        });
      } catch (transitionErr) {
        failures++;
        logger.warn("recurring task auto-end transition failed", {
          taskId: doc.id,
          error: String(transitionErr),
        });
        continue;
      }

      if (ended == null) {
        skipped++;
        continue;
      }

      missed++;
      await writeAutomationAudit("task.auto_missed", "task", doc.id, ended.branchId, {
        deadline: ended.deadline,
        templateId: ended.templateId,
      });
      // A task that fails automatically must be visible to a HUMAN (spec §9.1).
      // Before this, the sweep closed work silently and the only trace was the
      // audit log — which nobody watches.
      await notifyTaskMissed(doc.id, ended);
    }

    logger.info("recurring task auto-end complete", {
      candidates: due.size,
      failures,
      missed,
      skipped,
    });
  },
);

// The definition fields whose change is a lifecycle event worth auditing (vs. the
// CF-owned rollup/health fields, whose churn on every generation run must NOT
// produce audit noise or bump the config version).
const TEMPLATE_CONFIG_FIELDS = [
  "title",
  "description",
  "priority",
  "shift",
  "repeat",
  "weekday",
  "active",
  "checklistItems",
];

// A stable, comparable snapshot of only the audited config fields.
function templateConfigSnapshot(data) {
  const d = data || {};
  return {
    title: d.title ?? null,
    description: d.description ?? null,
    priority: d.priority ?? null,
    shift: d.shift ?? null,
    repeat: d.repeat ?? null,
    weekday: d.weekday ?? null,
    active: d.active ?? null,
    checklistItems: Array.isArray(d.checklistItems)
      ? d.checklistItems.map((c) => ({
          id: (c && c.id) || "",
          title: (c && c.title) || "",
          isRequired: !c || c.isRequired !== false,
        }))
      : [],
  };
}

// Field-by-field diff of two config snapshots → [{ field, old, new }].
function diffTemplateConfig(before, after) {
  const changes = [];
  for (const f of TEMPLATE_CONFIG_FIELDS) {
    const a = before ? before[f] : undefined;
    const b = after ? after[f] : undefined;
    if (JSON.stringify(a) !== JSON.stringify(b)) {
      changes.push({ field: f, old: a ?? null, new: b ?? null });
    }
  }
  return changes;
}

/**
 * Server-authoritative lifecycle audit for automation DEFINITIONS (ADR-005 +
 * ADR-011). Clients mutate `recurringTaskTemplates/{id}` directly (create /
 * pause-resume / edit / delete via `TaskCubit`) and never write their own audit
 * trail; this trigger derives the audit event from the before/after diff and
 * appends it to `audit_logs` as the acting user — so "who paused this, when, and
 * what changed" is answerable and tamper-evident.
 *
 * Idempotent: the audit doc id is derived from the CloudEvent id, so an
 * at-least-once redelivery overwrites rather than duplicates. The CF-owned
 * rollup/health fields are excluded from the diff, so a generation run's rollup
 * write produces NO audit and NO version bump (the loop terminates: this trigger
 * only writes `configVersion`, which is itself excluded from the diff).
 */
exports.onRecurringTemplateWritten = onDocumentWritten(
  `${RECURRING_TASK_TEMPLATES}/{templateId}`,
  async (event) => {
    const templateId = event.params.templateId;
    const beforeExists = event.data && event.data.before && event.data.before.exists;
    const afterExists = event.data && event.data.after && event.data.after.exists;
    const beforeData = beforeExists ? event.data.before.data() : null;
    const afterData = afterExists ? event.data.after.data() : null;

    // Resolve the actor: the app writes `updatedBy` (edits/pause) / `createdBy`
    // (create) on the definition; deletes carry the last known editor.
    const actorSource = afterData || beforeData || {};
    const actorId = String(
      actorSource.updatedBy || actorSource.createdBy || "system",
    );
    const branchId = String((afterData || beforeData || {}).branchId || "") || null;

    let eventType;
    let metadata = {};

    if (!beforeExists && afterExists) {
      eventType = "automation.created";
      metadata = {
        title: afterData.title || "",
        shift: afterData.shift || null,
        repeat: afterData.repeat || null,
      };
    } else if (beforeExists && !afterExists) {
      eventType = "automation.deleted";
      metadata = { title: (beforeData || {}).title || "" };
    } else {
      const changes = diffTemplateConfig(
        templateConfigSnapshot(beforeData),
        templateConfigSnapshot(afterData),
      );
      if (!changes.length) return; // rollup-only / version-only write → no audit
      const activeChange = changes.find((c) => c.field === "active");
      if (activeChange && changes.length === 1) {
        eventType = activeChange.new ? "automation.resumed" : "automation.paused";
      } else {
        eventType = "automation.config_changed";
      }
      metadata = { changes };

      // Bump the definition's config version (idempotent per event: computed
      // from the frozen `after` snapshot, written with `set`, and excluded from
      // the diff above so it can't re-trigger an audit).
      try {
        await event.data.after.ref.set(
          { configVersion: (Number(afterData.configVersion) || 0) + 1 },
          { merge: true },
        );
      } catch (e) {
        logger.warn("configVersion bump failed", { templateId, error: String(e) });
      }
    }

    try {
      await db.collection(AUDIT_LOGS).doc(`autotpl_${event.id}`).set({
        eventType,
        entityType: "automation",
        entityId: templateId,
        actorId,
        actorName: actorId === "system" ? "Automation" : null,
        actorRole: null,
        branchId,
        metadata,
        schemaVersion: 1,
        isDeleted: false,
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
      });
    } catch (e) {
      logger.warn("automation lifecycle audit write failed", {
        templateId,
        eventType,
        error: String(e),
      });
    }
  },
);

/**
 * Task retention sweep (Home Dashboard redesign, P3). Runs daily:
 *
 *  1. ARCHIVE — every APPROVED task older than `archiveAfterDays` (default 30)
 *     is soft-archived: `archivedAt` is stamped so the client filters it out of
 *     active lists/feeds. The doc STAYS in `tasks` (never moved to another
 *     collection), so statistics' lifetime "completed" counts, audit history,
 *     and `/task/:id` deep-links keep working. When `coldTierImages` is true its
 *     Storage evidence under `tasks/{id}/` is re-classed to COLDLINE (~85%
 *     cheaper storage; archived proof is rarely read again).
 *  2. DELETE (opt-in) — only when `deleteAfterDays` is a positive number: an
 *     archived task older than that is hard-deleted, its `tasks/{id}/` Storage
 *     prefix FIRST (so evidence never orphans), then the doc. Off by default —
 *     soft archive is forever unless an org explicitly opts into purging.
 *
 * Config in `config/taskRetention` (defaults applied when the doc is absent).
 * All queries are single-field inequalities on an auto-indexed field (no
 * composite index to deploy). Idempotent + outage-tolerant: the archive pass
 * pages by `approvedAt` with a cursor and skips already-archived docs, so it
 * never starves; the Storage ops are safe to repeat.
 */
// Extracts the Storage object name from a Firebase download URL, e.g.
// `https://…/o/tasks%2F{id}%2Fattachments%2F{stem}.jpg?alt=…` → `tasks/{id}/attachments/{stem}.jpg`.
// Returns null when the URL isn't a parseable Storage download URL — the orphan
// GC treats a null as "can't confirm the reference set" and skips the task.
function objectNameFromUrl(url) {
  try {
    const m = String(url).match(/\/o\/([^?]+)/);
    return m ? decodeURIComponent(m[1]) : null;
  } catch (_) {
    return null;
  }
}

// Reconciles ONE task's `attachments/` folder against the object names its doc
// actually references, deleting unreferenced objects older than [graceCutoffMs].
// SAFETY: if any referenced URL can't be parsed, the whole task is skipped (never
// risk deleting evidence on incomplete information); objects newer than the grace
// window are kept (an in-flight / retryable submission is never touched). Returns
// the count deleted. The Admin SDK bypasses the create-only Storage rules.
async function gcTaskOrphans(bucket, doc, graceCutoffMs) {
  const t = doc.data() || {};
  const referenced = new Set();
  let parseFailed = false;
  const addUrl = (url) => {
    if (!url) return;
    const name = objectNameFromUrl(url);
    if (name) referenced.add(name);
    else parseFailed = true;
  };
  for (const e of t.activityLog || []) {
    for (const a of e.attachments || []) addUrl(a.url);
  }
  for (const a of t.referenceAttachments || []) addUrl(a.url);
  if (t.proofImageUrl) addUrl(t.proofImageUrl);
  if (parseFailed) {
    logger.warn("orphan gc: unparseable reference, skipping task", { taskId: doc.id });
    return 0;
  }

  let deleted = 0;
  try {
    const [files] = await bucket.getFiles({ prefix: `${TASKS}/${doc.id}/attachments/` });
    for (const f of files) {
      if (referenced.has(f.name)) continue; // still referenced → keep
      try {
        const [meta] = await f.getMetadata();
        const created = Date.parse(meta.timeCreated || "");
        if (!Number.isFinite(created) || created > graceCutoffMs) continue; // too new → keep
        await f.delete();
        deleted++;
        logger.info("orphan gc: deleted", { taskId: doc.id, file: f.name });
      } catch (e) {
        logger.warn("orphan gc: object check/delete failed", { taskId: doc.id, file: f.name, error: String(e) });
      }
    }
  } catch (e) {
    logger.warn("orphan gc: list failed", { taskId: doc.id, error: String(e) });
  }
  return deleted;
}

exports.taskHousekeeping = onSchedule("every 24 hours", async () => {
  const now = Date.now();
  const nowTs = admin.firestore.Timestamp.fromMillis(now);
  const cutoff = (days) =>
    admin.firestore.Timestamp.fromMillis(now - days * 24 * 60 * 60 * 1000);

  // Config (defaults when the doc is absent). `deleteAfterDays` is opt-in: any
  // non-positive / missing value keeps soft archive forever.
  let cfg = {
    archiveAfterDays: 30,
    coldTierImages: true,
    deleteAfterDays: null,
    gcOrphanAttachments: false,
    gcGraceHours: 48,
    automationRunRetentionDays: 90,
  };
  try {
    const cSnap = await db.collection(CONFIG).doc("taskRetention").get();
    if (cSnap.exists) {
      const c = cSnap.data() || {};
      cfg = {
        archiveAfterDays: Number.isFinite(c.archiveAfterDays) && c.archiveAfterDays > 0
          ? c.archiveAfterDays : 30,
        coldTierImages: c.coldTierImages !== false,
        deleteAfterDays: Number.isFinite(c.deleteAfterDays) && c.deleteAfterDays > 0
          ? c.deleteAfterDays : null,
        // Orphan attachment GC — OFF unless explicitly enabled (a delete sweep is
        // risky; the owner enables it after reviewing this function).
        gcOrphanAttachments: c.gcOrphanAttachments === true,
        gcGraceHours: Number.isFinite(c.gcGraceHours) && c.gcGraceHours > 0
          ? c.gcGraceHours : 48,
        automationRunRetentionDays:
          Number.isFinite(c.automationRunRetentionDays) && c.automationRunRetentionDays > 0
            ? c.automationRunRetentionDays : 90,
      };
    }
  } catch (_) {
    // best-effort; use defaults
  }

  const bucket = admin.storage().bucket();
  let archived = 0;
  let coldTiered = 0;
  let deleted = 0;

  // Best-effort: re-class every object under tasks/{id}/ to a colder class.
  const coldTier = async (taskId) => {
    try {
      const [files] = await bucket.getFiles({ prefix: `${TASKS}/${taskId}/` });
      for (const f of files) {
        try {
          const [meta] = await f.getMetadata();
          if (String(meta.storageClass || "STANDARD").toUpperCase() === "COLDLINE") continue;
          await f.setStorageClass("COLDLINE");
          coldTiered++;
        } catch (e) {
          logger.warn("cold-tier object failed", { taskId, file: f.name, error: String(e) });
        }
      }
    } catch (e) {
      logger.warn("cold-tier list failed", { taskId, error: String(e) });
    }
  };

  // ── 1. ARCHIVE terminal tasks past the window ──
  // `approvedAt` is cleared on an admin reopen, and `missedAt` is only written
  // by the recurring shift expiry sweep. Each timestamp therefore selects the
  // current terminal outcome precisely. We page by its timestamp and skip any
  // already-archived doc, so re-runs / long outages cannot starve the backlog.
  const RUN_CAP = 5000; // bound per-run scan; daily cadence drains any backlog
  const archiveTerminalTasks = async (status, timestampField) => {
    let scanned = 0;
    let last = null;
    try {
      // eslint-disable-next-line no-constant-condition
      while (scanned < RUN_CAP) {
        let q = db
          .collection(TASKS)
          .where(timestampField, "<=", cutoff(cfg.archiveAfterDays))
          .orderBy(timestampField, "asc")
          .limit(BATCH_LIMIT);
        if (last) q = q.startAfter(last);
        const snap = await q.get();
        if (snap.empty) break;

        const batch = db.batch();
        const toColdTier = [];
        let n = 0;
        for (const doc of snap.docs) {
          last = doc;
          const task = doc.data() || {};
          if ((task.status || "") !== status) continue;
          if (task.archivedAt) continue;
          batch.update(doc.ref, { archivedAt: nowTs });
          if (cfg.coldTierImages) toColdTier.push(doc.id);
          n++;
        }
        if (n > 0) await batch.commit();
        archived += n;
        for (const id of toColdTier) await coldTier(id);

        scanned += snap.size;
        if (snap.size < BATCH_LIMIT) break;
      }
    } catch (err) {
      logger.warn("task archive sweep failed", {
        error: String(err),
        status,
        timestampField,
      });
    }
  };
  await archiveTerminalTasks("approved", "approvedAt");
  await archiveTerminalTasks("missed", "missedAt");

  // ── 2. DELETE archived tasks past the (opt-in) purge window ──
  if (cfg.deleteAfterDays) {
    try {
      const snap = await db
        .collection(TASKS)
        .where("archivedAt", "<=", cutoff(cfg.deleteAfterDays))
        .limit(BATCH_LIMIT)
        .get();
      for (const doc of snap.docs) {
        // Evidence first, so a crash between the two never orphans Storage.
        try {
          await bucket.deleteFiles({ prefix: `${TASKS}/${doc.id}/`, force: true });
        } catch (e) {
          logger.warn("delete task storage failed", { taskId: doc.id, error: String(e) });
        }
        await doc.ref.delete();
        deleted++;
      }
    } catch (err) {
      logger.warn("task delete sweep failed", { error: String(err) });
    }
  }

  // ── 3. GC ORPHANED ATTACHMENTS (opt-in) ──
  // A cancelled / failed / interrupted submission (or a Firestore failure after a
  // Storage success) can upload attachment objects whose URL never lands on the
  // task doc; the client can't delete them (create-only Storage rules). This
  // reconciles each task's `attachments/` folder against the URLs the doc
  // references and deletes the unreferenced, past-grace objects. OFF by default —
  // enable via `config/taskRetention.gcOrphanAttachments: true` (+ optional
  // `gcGraceHours`, default 48). Newest-first + RUN_CAP bounds the scan.
  let orphansDeleted = 0;
  if (cfg.gcOrphanAttachments) {
    const graceCutoff = now - cfg.gcGraceHours * 60 * 60 * 1000;
    try {
      let scanned = 0;
      let last = null;
      while (scanned < RUN_CAP) {
        let q = db.collection(TASKS).orderBy("updatedAt", "desc").limit(BATCH_LIMIT);
        if (last) q = q.startAfter(last);
        const snap = await q.get();
        if (snap.empty) break;
        for (const doc of snap.docs) {
          last = doc;
          orphansDeleted += await gcTaskOrphans(bucket, doc, graceCutoff);
        }
        scanned += snap.size;
        if (snap.size < BATCH_LIMIT) break;
      }
    } catch (err) {
      logger.warn("orphan gc sweep failed", { error: String(err) });
    }
  }

  // Automation run-history retention — `automationRuns` gains one doc per template
  // per day, so prune runs older than `automationRunRetentionDays` (default 90) to
  // keep it bounded. Single-field inequality on `startedAt` (auto-indexed); bounded
  // by RUN_CAP like the sweeps above. Idempotent (already-deleted docs just aren't
  // re-found).
  let automationRunsDeleted = 0;
  try {
    let scanned = 0;
    while (scanned < RUN_CAP) {
      const snap = await db
        .collection(AUTOMATION_RUNS)
        .where("startedAt", "<=", cutoff(cfg.automationRunRetentionDays))
        .limit(BATCH_LIMIT)
        .get();
      if (snap.empty) break;
      const batch = db.batch();
      for (const doc of snap.docs) batch.delete(doc.ref);
      await batch.commit();
      automationRunsDeleted += snap.size;
      scanned += snap.size;
      if (snap.size < BATCH_LIMIT) break;
    }
  } catch (err) {
    logger.warn("automation run prune failed", { error: String(err) });
  }

  logger.info("task housekeeping done", {
    archived,
    coldTiered,
    deleted,
    orphansDeleted,
    automationRunsDeleted,
  });
});

/**
 * ── Case Management notification fan-out ─────────────────────────────────────
 *
 * Case notifications are produced SERVER-SIDE (not by the client) because a
 * case's reporter identity lives in the private `cases/{id}/reporter/identity`
 * subdoc — a manager can't read it, so they can't notify a confidential reporter
 * from their own client. The Admin SDK also owns the `opening` + `system`
 * messages (clients can't forge them — see firestore.rules). These triggers
 * write per-recipient `notifications/{id}` docs with the Admin SDK (bypassing
 * the `create: if false` rule); `onNotificationCreated` then delivers the FCM
 * push (they intentionally do NOT set `pushedByFunction`). `senderUid` is left
 * empty (system) so a recipient reading their own notification can never resolve
 * a confidential reporter from it.
 */

// Reads the reporter uid from a case's private identity subdoc (best-effort).
async function caseReporterUid(caseId) {
  try {
    const idSnap = await db
      .collection(CASES)
      .doc(caseId)
      .collection("reporter")
      .doc("identity")
      .get();
    if (idSnap.exists) return String((idSnap.data() || {}).createdByUserId || "");
  } catch (e) {
    logger.warn("case identity read failed", { caseId, error: String(e) });
  }
  return "";
}

// The routed recipients for a case (branch managers and/or admins), minus the
// reporter. Mirrors the client `CaseRecipient` routing.
async function resolveCaseRecipients(caseData, excludeUid) {
  const recipient = String(caseData.recipient || "manager");
  const branchId = String(caseData.branchId || "");
  const out = new Set();
  if (recipient === "manager" || recipient === "both") {
    try {
      const snap = await db
        .collection(USERS)
        .where("branchId", "==", branchId)
        .where("role", "==", "manager")
        .get();
      snap.docs.forEach((d) => {
        if ((d.data() || {}).isActive !== false) out.add(d.id);
      });
    } catch (e) {
      logger.warn("case manager lookup failed", { error: String(e) });
    }
  }
  if (recipient === "admin" || recipient === "both") {
    try {
      const snap = await db.collection(USERS).where("role", "==", "admin").get();
      snap.docs.forEach((d) => {
        if ((d.data() || {}).isActive !== false) out.add(d.id);
      });
    } catch (e) {
      logger.warn("case admin lookup failed", { error: String(e) });
    }
  }
  out.delete(excludeUid);
  out.delete("");
  return [...out];
}

// Writes one in-app notification doc per recipient (Admin SDK). onNotificationCreated
// handles the push. senderUid is intentionally empty (privacy). Best-effort.
async function writeCaseNotifications(recipientUids, { type, title, body, caseId }) {
  const uids = [...new Set(recipientUids.filter(Boolean))];
  if (uids.length === 0) return;
  const payload = { caseId, route: "case_details" };
  try {
    for (let i = 0; i < uids.length; i += BATCH_LIMIT) {
      const slice = uids.slice(i, i + BATCH_LIMIT);
      const batch = db.batch();
      for (const uid of slice) {
        const ref = db.collection(NOTIFICATIONS).doc();
        batch.set(ref, {
          id: ref.id,
          recipientUid: uid,
          senderUid: "", // system — never leak a confidential reporter
          type,
          title: String(title || "").slice(0, 120),
          body: String(body || "").slice(0, 500),
          readAt: null,
          payload,
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
        });
      }
      await batch.commit();
    }
  } catch (err) {
    logger.warn("failed to persist case notifications", { error: String(err) });
  }
}

// A one-line preview of a message for the inbox row.
function caseMessagePreview(text, attachments) {
  const t = String(text || "").trim();
  if (t) return t.slice(0, 140);
  if (Array.isArray(attachments) && attachments.length > 0) return "📎 Attachment";
  return "";
}

// Human label for a status-change system message.
function caseStatusSystemLabel(status) {
  switch (status) {
    case "inDiscussion": return "Marked In Discussion";
    case "waitingResponse": return "Waiting for a response";
    case "closed": return "Case closed";
    case "open": return "Case reopened";
    default: return "Status updated";
  }
}

// Appends a server-authored message (opening / system) + bumps the parent case.
// Clients cannot write these kinds (firestore.rules), so they are trusted.
async function appendServerCaseMessage(caseId, message, preview) {
  try {
    const msgRef = db.collection(CASES).doc(caseId).collection("messages").doc();
    const batch = db.batch();
    batch.set(msgRef, {
      ...message,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    batch.update(db.collection(CASES).doc(caseId), {
      lastMessagePreview: preview,
      messageCount: admin.firestore.FieldValue.increment(1),
      lastMessageAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    await batch.commit();
  } catch (e) {
    logger.warn("failed to append server case message", { caseId, error: String(e) });
  }
}

// A new case → write the opening message (de-identified per privacy) + notify
// the routed recipients (branch managers / admins).
exports.onCaseCreated = onDocumentCreated(`${CASES}/{caseId}`, async (event) => {
  const snap = event.data;
  if (!snap) return;
  const caseData = snap.data() || {};
  const caseId = event.params.caseId;

  const reporterUid = await caseReporterUid(caseId);
  const confidential = String(caseData.privacy || "normal") !== "normal";
  const description = String(caseData.description || "");
  const attachments = Array.isArray(caseData.attachments) ? caseData.attachments : [];

  await appendServerCaseMessage(
    caseId,
    {
      authorId: confidential ? "" : reporterUid,
      authorName: confidential
        ? "Confidential Sender"
        : String(caseData.reporterDisplayName || "Reporter"),
      authorRole: "reporter",
      kind: "opening",
      text: description || null,
      attachments,
      systemEvent: null,
    },
    caseMessagePreview(description, attachments),
  );

  const recipients = await resolveCaseRecipients(caseData, reporterUid);
  if (recipients.length === 0) return;
  const urgent = caseData.urgent === true;
  await writeCaseNotifications(recipients, {
    type: "caseOpened",
    title: urgent ? "New Case • Urgent" : "New Case",
    body: String(caseData.subject || "A new case was opened"),
    caseId,
  });
});

// A case status changed → append a system message + notify the affected party.
// Only reacts to a real status transition (its own lastMessage* bumps do not
// change status, so there is no re-fire loop).
exports.onCaseUpdated = onDocumentUpdated(`${CASES}/{caseId}`, async (event) => {
  const before = (event.data && event.data.before && event.data.before.data()) || {};
  const after = (event.data && event.data.after && event.data.after.data()) || {};
  const caseId = event.params.caseId;

  const beforeStatus = String(before.status || "open");
  const afterStatus = String(after.status || "open");
  if (beforeStatus === afterStatus) return;

  const label = caseStatusSystemLabel(afterStatus);
  await appendServerCaseMessage(
    caseId,
    {
      authorId: "",
      authorName: "System",
      authorRole: "system",
      kind: "system",
      text: label,
      attachments: [],
      systemEvent: afterStatus,
    },
    label,
  );

  const reporterUid = await caseReporterUid(caseId);
  const reopened = beforeStatus === "closed" && afterStatus !== "closed";
  if (reopened) {
    const actorUid = String(after.statusChangedBy || "");
    const recipients = (await resolveCaseRecipients(after, reporterUid)).filter(
      (uid) => uid !== actorUid,
    );
    await writeCaseNotifications(recipients, {
      type: "caseUpdated",
      title: "Case Reopened",
      body: String(after.subject || "A case was reopened"),
      caseId,
    });
  } else if (reporterUid) {
    const closed = afterStatus === "closed";
    const bodyByStatus = {
      inDiscussion: "Your case is now in discussion",
      waitingResponse: "A response is needed on your case",
      closed: "Your case was closed",
    };
    const subject = String(after.subject || "Case").trim();
    await writeCaseNotifications([reporterUid], {
      type: closed ? "caseClosed" : "caseUpdated",
      title: closed ? "Case Closed" : "Case Update",
      body: bodyByStatus[afterStatus]
        ? `${subject} • ${bodyByStatus[afterStatus]}`
        : subject,
      caseId,
    });
  }
});

// A new conversation message → bump the parent case + notify the OTHER party.
// opening/system messages are handled by their own creators (skipped here).
exports.onCaseMessageCreated = onDocumentCreated(
  `${CASES}/{caseId}/messages/{messageId}`,
  async (event) => {
    const snap = event.data;
    if (!snap) return;
    const message = snap.data() || {};
    const caseId = event.params.caseId;
    if (String(message.kind || "message") !== "message") return;

    const preview = caseMessagePreview(
      message.text,
      Array.isArray(message.attachments) ? message.attachments : [],
    );
    try {
      await db.collection(CASES).doc(caseId).update({
        lastMessagePreview: preview,
        messageCount: admin.firestore.FieldValue.increment(1),
        lastMessageAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    } catch (e) {
      logger.warn("failed to bump case on message", { caseId, error: String(e) });
    }

    const caseSnap = await db.collection(CASES).doc(caseId).get();
    const caseData = caseSnap.exists ? (caseSnap.data() || {}) : {};
    const reporterUid = await caseReporterUid(caseId);
    const authorId = String(message.authorId || "");
    const byReporter = authorId === "" || authorId === reporterUid;
    if (byReporter) {
      const recipients = await resolveCaseRecipients(caseData, reporterUid);
      await writeCaseNotifications(recipients, {
        type: "caseReplied",
        title: "New Case Reply",
        body: String(caseData.subject || "New reply on a case"),
        caseId,
      });
    } else if (reporterUid && authorId !== reporterUid) {
      await writeCaseNotifications([reporterUid], {
        type: "caseReplied",
        title: "New Case Reply",
        body: String(caseData.subject || "New reply on your case"),
        caseId,
      });
    }
  },
);


// ═══════════════════════════════════════════════════════════════════════════
//  Operations Requests (in-the-moment approvals) — server-side timeline +
//  notifications + the human-friendly REQ-###### sequence.
//
//  The client writes the request doc + its comment/attachment events; the Admin
//  SDK owns everything a client can't be trusted with:
//    • the opening `submitted` timeline event + the REQ-###### refCode,
//    • the decision events (approved/rejected),
//    • the `lastEvent*` inbox bumps,
//    • every notification (routing depends on branch/role/policy lookups).
//  No re-fire loop: the lastEvent*/refCode bumps never change `status`, and the
//  server-written events are `submitted`/lifecycle kinds the event trigger skips.
// ═══════════════════════════════════════════════════════════════════════════

// A one-line preview of a request event for the inbox row.
function requestEventPreview(text, attachments) {
  const t = String(text || "").trim();
  if (t) return t.slice(0, 140);
  if (Array.isArray(attachments) && attachments.length > 0) return "📎 Attachment";
  return "";
}

// Requests have no dedicated subject field, so the inbox subject is the
// requester's own free-text reason — `details.message` (see RequestModel: "the
// free-text reason lives in `details`").
//
// It is deliberately NOT `lastEventPreview`: that field is a ROLLING preview of
// the most recent timeline event, so by the time a request is approved it may
// hold the latest comment rather than what the request is about — producing a
// row like "sounds fine to me • Approved". `details.message` is written once and
// stays the same string the opening notification used, so every row for one
// request names the same thing.
//
// `lastEventPreview` remains the first fallback (it equals the reason at
// creation time, which covers docs written before this field was relied on), and
// the durable REQ-###### code is the last resort that still identifies which
// request this is.
function requestNotificationSubject(requestData) {
  const details = (requestData && requestData.details) || {};
  const message = String(details.message || "").trim();
  if (message) return message.slice(0, 140);
  const preview = String(requestData.lastEventPreview || "").trim();
  if (preview) return preview.slice(0, 140);
  const refCode = String(requestData.refCode || "").trim();
  return refCode || "Request";
}

// The routed approvers for a request — the request's own-branch managers and all
// admins — minus [excludeUid]. A request is a simple approval, so the decider is
// always "the branch manager or an admin"; there is no per-type policy.
async function resolveRequestApprovers(requestData, excludeUid) {
  const branchId = String(requestData.branchId || "");
  const out = new Set();
  if (branchId) {
    try {
      const snap = await db.collection(USERS)
        .where("branchId", "==", branchId)
        .where("role", "==", "manager").get();
      snap.docs.forEach((d) => {
        if ((d.data() || {}).isActive !== false) out.add(d.id);
      });
    } catch (e) { logger.warn("request manager lookup failed", { error: String(e) }); }
  }
  try {
    const snap = await db.collection(USERS).where("role", "==", "admin").get();
    snap.docs.forEach((d) => {
      if ((d.data() || {}).isActive !== false) out.add(d.id);
    });
  } catch (e) { logger.warn("request admin lookup failed", { error: String(e) }); }
  out.delete(excludeUid);
  out.delete("");
  return [...out];
}

// Writes one in-app notification doc per recipient (Admin SDK). onNotificationCreated
// handles the matching push. Best-effort.
async function writeRequestNotifications(recipientUids, { type, title, body, requestId, senderUid }) {
  const uids = [...new Set(recipientUids.filter(Boolean))];
  if (uids.length === 0) return;
  const payload = { requestId, route: "request_details" };
  try {
    for (let i = 0; i < uids.length; i += BATCH_LIMIT) {
      const slice = uids.slice(i, i + BATCH_LIMIT);
      const batch = db.batch();
      for (const uid of slice) {
        const ref = db.collection(NOTIFICATIONS).doc();
        batch.set(ref, {
          id: ref.id,
          recipientUid: uid,
          senderUid: String(senderUid || ""),
          type,
          title: String(title || "").slice(0, 120),
          body: String(body || "").slice(0, 500),
          readAt: null,
          payload,
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
        });
      }
      await batch.commit();
    }
  } catch (err) {
    logger.warn("failed to persist request notifications", { error: String(err) });
  }
}

// Appends a server-authored timeline event (submitted / lifecycle) + bumps the
// parent request. Clients cannot write these kinds (firestore.rules).
async function appendServerRequestEvent(requestId, ev, preview) {
  try {
    const evRef = db.collection(REQUESTS).doc(requestId).collection("events").doc();
    const batch = db.batch();
    batch.set(evRef, { ...ev, createdAt: admin.firestore.FieldValue.serverTimestamp() });
    batch.update(db.collection(REQUESTS).doc(requestId), {
      lastEventPreview: preview,
      eventCount: admin.firestore.FieldValue.increment(1),
      lastEventAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    await batch.commit();
  } catch (e) {
    logger.warn("failed to append server request event", { requestId, error: String(e) });
  }
}

// Allocates the next human-friendly REQ-###### code via a counter transaction.
async function nextRequestRefCode() {
  const ref = db.collection(COUNTERS).doc("requests");
  try {
    const seq = await db.runTransaction(async (tx) => {
      const snap = await tx.get(ref);
      const current = snap.exists ? Number((snap.data() || {}).seq || 0) : 0;
      const next = current + 1;
      tx.set(ref, {
        seq: next,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      }, { merge: true });
      return next;
    });
    return { seq, refCode: `REQ-${String(seq).padStart(6, "0")}` };
  } catch (e) {
    logger.warn("failed to allocate request ref", { error: String(e) });
    return { seq: null, refCode: null };
  }
}

// A new request → assign REQ-######, write the opening `submitted` event, and
// notify the routed approvers.
exports.onRequestCreated = onDocumentCreated(`${REQUESTS}/{requestId}`, async (event) => {
  const snap = event.data;
  if (!snap) return;
  const data = snap.data() || {};
  const requestId = event.params.requestId;

  // 1) Ref code (idempotent — skip if a retriggered create already assigned one).
  if (!data.refCode) {
    const { seq, refCode } = await nextRequestRefCode();
    if (refCode) {
      try {
        await db.collection(REQUESTS).doc(requestId).update({ refCode, seq });
      } catch (e) {
        logger.warn("failed to write request refCode", { requestId, error: String(e) });
      }
    }
  }

  // 2) Opening timeline event (from the requester's summary + opening media).
  const summary = String(data.lastEventPreview || "").trim();
  const attachments = Array.isArray(data.attachments) ? data.attachments : [];
  await appendServerRequestEvent(
    requestId,
    {
      authorId: String(data.requesterId || ""),
      authorName: String(data.requesterName || "Requester"),
      actor: "requester",
      kind: "submitted",
      text: summary || null,
      attachments,
    },
    requestEventPreview(summary, attachments),
  );

  // 3) Notify the routed approvers.
  const requesterUid = String(data.requesterId || "");
  const approvers = await resolveRequestApprovers(data, requesterUid);
  await writeRequestNotifications(approvers, {
    type: "requestSubmitted",
    title: "New approval request",
    body: summary ||
      `${String(data.requesterName || "An employee")} asked for your approval`,
    requestId,
    senderUid: requesterUid,
  });
});

// A request's status changed → append the lifecycle event + notify the affected
// party. Ignores its own lastEvent*/refCode bumps (status unchanged → no re-fire).
exports.onRequestUpdated = onDocumentUpdated(`${REQUESTS}/{requestId}`, async (event) => {
  const before = (event.data && event.data.before && event.data.before.data()) || {};
  const after = (event.data && event.data.after && event.data.after.data()) || {};
  const requestId = event.params.requestId;

  const beforeStatus = String(before.status || "pending");
  const afterStatus = String(after.status || "pending");
  if (beforeStatus === afterStatus) return;

  // approved / rejected = a decision; pending (from a decided state) = an
  // admin REOPEN — the client cleared `decided*` and stamped `reopened*`.
  const kinds = { approved: "approved", rejected: "rejected", pending: "reopened" };
  const kind = kinds[afterStatus];
  if (!kind) return;

  const deciderName = String(after.decidedByName || "").trim();
  const reopenerName = String(after.reopenedByName || "").trim();
  const label = {
    approved: deciderName ? `Approved by ${deciderName}` : "Approved",
    rejected: deciderName ? `Rejected by ${deciderName}` : "Rejected",
    pending: reopenerName ? `Reopened by ${reopenerName}` : "Reopened",
  }[afterStatus];
  const actorUid = afterStatus === "pending"
    ? String(after.reopenedBy || "")
    : String(after.decidedBy || "");

  await appendServerRequestEvent(
    requestId,
    {
      authorId: actorUid,
      authorName: (afterStatus === "pending" ? reopenerName : deciderName) || "System",
      actor: "system",
      kind,
      text: label,
      attachments: [],
    },
    label,
  );

  const requesterUid = String(after.requesterId || "");
  const subject = requestNotificationSubject(after);
  if (afterStatus === "pending") {
    // Reopened → it needs a decision again: tell the branch approvers (minus
    // the admin who reopened) and the requester.
    const approvers = await resolveRequestApprovers(after, actorUid);
    const body = reopenerName
      ? `${subject} • ${reopenerName} reopened it — it needs a decision again`
      : `${subject} • Reopened and needs a decision again`;
    await writeRequestNotifications(approvers, {
      type: "requestSubmitted",
      title: "Request reopened",
      body,
      requestId,
      senderUid: actorUid,
    });
    if (requesterUid && requesterUid !== actorUid) {
      await writeRequestNotifications([requesterUid], {
        type: "requestSubmitted",
        title: "Request reopened",
        body: `${subject} • Your request is being reviewed again`,
        requestId,
        senderUid: actorUid,
      });
    }
    return;
  }

  // Notify the requester of the decision.
  if (requesterUid) {
    const byStatus = {
      approved: { type: "requestApproved", title: "Request Approved", body: `${subject} • Approved` },
      rejected: { type: "requestRejected", title: "Request Rejected", body: `${subject} • Rejected` },
    }[afterStatus];
    await writeRequestNotifications([requesterUid], {
      ...byStatus,
      requestId,
      senderUid: String(after.decidedBy || ""),
    });
  }
});

// A new comment/attachment event → bump the parent + notify the OTHER party.
// submitted/lifecycle events are written by the functions above (skipped here).
exports.onRequestEventCreated = onDocumentCreated(
  `${REQUESTS}/{requestId}/events/{eventId}`,
  async (event) => {
    const snap = event.data;
    if (!snap) return;
    const ev = snap.data() || {};
    const requestId = event.params.requestId;
    const kind = String(ev.kind || "comment");
    if (kind !== "comment" && kind !== "attachmentAdded") return;

    const preview = requestEventPreview(ev.text, Array.isArray(ev.attachments) ? ev.attachments : []);
    try {
      await db.collection(REQUESTS).doc(requestId).update({
        lastEventPreview: preview,
        eventCount: admin.firestore.FieldValue.increment(1),
        lastEventAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    } catch (e) {
      logger.warn("failed to bump request on event", { requestId, error: String(e) });
    }

    const reqSnap = await db.collection(REQUESTS).doc(requestId).get();
    const data = reqSnap.exists ? (reqSnap.data() || {}) : {};
    const subject = requestNotificationSubject(data);
    const requesterUid = String(data.requesterId || "");
    const authorId = String(ev.authorId || "");
    const byRequester = authorId !== "" && authorId === requesterUid;
    if (byRequester) {
      const approvers = await resolveRequestApprovers(data, requesterUid);
      await writeRequestNotifications(approvers, {
        type: "requestCommented",
        title: "New Request Comment",
        body: `${subject} • ${preview || "New comment on a request"}`,
        requestId,
        senderUid: authorId,
      });
    } else if (requesterUid && authorId !== requesterUid) {
      await writeRequestNotifications([requesterUid], {
        type: "requestCommented",
        title: "New Request Comment",
        body: `${subject} • ${preview || "New comment on your request"}`,
        requestId,
        senderUid: authorId,
      });
    }
  },
);

// ═══════════════════════════════════════════════════════════════════════════
//  Attendance — server-authoritative audit trail + correction apply + auto-close.
//
//  Clients write ONLY the attendance record (clock in/out/breaks) and the
//  correction doc (file / decide). Everything a client can't be trusted with is
//  derived here by the Admin SDK:
//    • the immutable, append-only audit trail (`attendance/{id}/events`),
//    • applying an APPROVED correction's resolution onto the parent record,
//    • auto-closing sessions the employee never clocked out of,
//    • every notification (routing needs branch/role lookups).
//  Mirrors the `onRequest*` pattern. No re-fire: the audit append writes a
//  subcollection doc (never the parent record), and the correction-apply write
//  carries `source: 'correction'` — which `onAttendanceWritten` ignores for the
//  self-clock events, so it never double-audits.
// ═══════════════════════════════════════════════════════════════════════════

// Appends one server-authored, immutable audit event to attendance/{id}/events.
// Clients cannot write these (firestore.rules), so the trail can't be forged.
async function appendAttendanceEvent(recordId, ev) {
  if (!recordId) return;
  try {
    const ref = db.collection(ATTENDANCE).doc(recordId).collection("events").doc();
    await ref.set({
      kind: String(ev.kind || ""),
      actorId: String(ev.actorId || ""),
      actorName: ev.actorName != null ? String(ev.actorName) : null,
      note: ev.note != null ? String(ev.note) : null,
      data: ev.data && typeof ev.data === "object" ? ev.data : {},
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });
  } catch (e) {
    logger.warn("failed to append attendance event", { recordId, error: String(e) });
  }
}

// The reviewers for an attendance correction — the branch's managers + all
// admins (active), minus [excludeUid]. Mirrors resolveRequestApprovers.
async function resolveAttendanceReviewers(branchId, excludeUid) {
  const out = new Set();
  const bid = String(branchId || "");
  if (bid) {
    try {
      const snap = await db.collection(USERS)
        .where("branchId", "==", bid)
        .where("role", "==", "manager").get();
      snap.docs.forEach((d) => { if ((d.data() || {}).isActive !== false) out.add(d.id); });
    } catch (e) { logger.warn("attendance manager lookup failed", { error: String(e) }); }
  }
  try {
    const snap = await db.collection(USERS).where("role", "==", "admin").get();
    snap.docs.forEach((d) => { if ((d.data() || {}).isActive !== false) out.add(d.id); });
  } catch (e) { logger.warn("attendance admin lookup failed", { error: String(e) }); }
  out.delete(excludeUid);
  out.delete("");
  return [...out];
}

// Writes one in-app notification doc per recipient (Admin SDK). onNotificationCreated
// handles the matching push. Best-effort.
async function writeAttendanceNotifications(
  recipientUids,
  { type, title, body, recordId, correctionId, senderUid },
) {
  const uids = [...new Set((recipientUids || []).filter(Boolean))];
  if (uids.length === 0) return;
  const payload = { route: "attendance" };
  if (recordId) payload.recordId = recordId;
  if (correctionId) payload.correctionId = correctionId;
  try {
    for (let i = 0; i < uids.length; i += BATCH_LIMIT) {
      const slice = uids.slice(i, i + BATCH_LIMIT);
      const batch = db.batch();
      for (const uid of slice) {
        const ref = db.collection(NOTIFICATIONS).doc();
        batch.set(ref, {
          id: ref.id,
          recipientUid: uid,
          senderUid: String(senderUid || ""),
          type,
          title: String(title || "").slice(0, 120),
          body: String(body || "").slice(0, 500),
          readAt: null,
          payload,
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
        });
      }
      await batch.commit();
    }
  } catch (err) {
    logger.warn("failed to persist attendance notifications", { error: String(err) });
  }
}

// A readable label for a correction kind (mirrors AttendanceCorrectionKind.label).
function attendanceCorrectionKindLabel(kind) {
  switch (String(kind || "")) {
    case "missingClockOut": return "missing clock-out";
    case "wrongTime": return "wrong time";
    case "absenceDispute": return "absence dispute";
    default: return "correction";
  }
}

// Any write to an attendance record → derive the append-only audit events by
// diffing before/after. Self-clock events are gated on `source: 'clock'` so the
// auto-close and correction-apply paths (which own their own events) never
// double-audit.
exports.onAttendanceWritten = onDocumentWritten(`${ATTENDANCE}/{recordId}`, async (event) => {
  const recordId = event.params.recordId;
  const beforeSnap = event.data && event.data.before;
  const afterSnap = event.data && event.data.after;
  const before = (beforeSnap && beforeSnap.exists) ? (beforeSnap.data() || {}) : null;
  const after = (afterSnap && afterSnap.exists) ? (afterSnap.data() || {}) : null;
  if (!after) return; // deleted — records are soft-deleted, so this is defensive.

  const source = String(after.source || "clock");
  const actorId = String(after.userId || "");
  const actorName = after.userName != null ? String(after.userName) : null;
  const events = [];

  // Clock-in — first appearance of clockIn on a self-clocked record.
  if (source === "clock" && !(before && before.clockIn) && after.clockIn) {
    events.push({ kind: "clockedIn", actorId, actorName });
  }
  // Clock-out — clockOut newly set, self-clocked.
  if (source === "clock" && !(before && before.clockOut) && after.clockOut) {
    events.push({ kind: "clockedOut", actorId, actorName });
  }
  // (Breaks are not part of the MVP — no break audit is derived. The record's
  // `breaks` array stays a dormant extension point.)

  const beforeStatus = before ? String(before.status || "") : "";
  const afterStatus = String(after.status || "");
  // Auto-closed — the scheduled sweep flips an open session to pendingReview.
  if (beforeStatus !== "pendingReview" && afterStatus === "pendingReview" && source === "autoClose") {
    events.push({ kind: "autoClosed", actorId: "", actorName: null, note: "Session auto-closed — never clocked out" });
  }
  // Marked absent — a manager recorded a no-show.
  if (beforeStatus !== "absent" && afterStatus === "absent") {
    events.push({
      kind: "markedAbsent",
      actorId: String(after.resolvedBy || ""),
      actorName: after.resolvedByName != null ? String(after.resolvedByName) : null,
    });
  }

  for (const ev of events) {
    await appendAttendanceEvent(recordId, ev);
  }
});

// Apply an approved correction's resolution onto its parent attendance record —
// the ONE server-authoritative apply path, shared by a reviewer's approval and a
// manager's direct action (Add record / Resolve). Upserts: an existing record is
// updated; a MISSING record is materialized (a missed-punch / manager-added shift
// that never had a document). A concurrently soft-deleted record is left alone.
// The dayKey is lifted from the deterministic id (`{uid}_{yyyyMMdd}_{shift}`) so it
// matches the client's calendar day without a timezone round-trip.
async function applyCorrectionResolution(recordId, after) {
  if (!recordId) return false;
  const res = (after.resolution && typeof after.resolution === "object") ? after.resolution : {};
  const fields = {
    clockIn: res.clockIn || null,
    clockOut: res.clockOut || null,
    status: String(res.status || "completed"),
    workedMinutes: Number(res.workedMinutes || 0),
    lateMinutes: Number(res.lateMinutes || 0),
    earlyLeaveMinutes: Number(res.earlyLeaveMinutes || 0),
    overtimeMinutes: Number(res.overtimeMinutes || 0),
    breakMinutes: Number(res.breakMinutes || 0),
    source: "correction",
    resolvedBy: String(after.decidedBy || ""),
    resolvedByName: after.decidedByName != null ? String(after.decidedByName) : null,
    resolvedAt: admin.firestore.FieldValue.serverTimestamp(),
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  };
  const ref = db.collection(ATTENDANCE).doc(recordId);
  const snap = await ref.get();
  if (snap.exists) {
    // Guard a concurrent soft-delete — never resurrect a deleted record.
    const record = snap.data() || {};
    if (record.deletedAt) return false;
    if (!correctionMatchesExistingRecordOwner(record, after.userId)) {
      logger.error("refusing attendance correction for another employee's record", {
        recordId,
        recordUserId: record.userId,
        correctionUserId: String(after.userId || ""),
      });
      return false;
    }
    await ref.update(fields);
    return true;
  }
  if (!correctionTargetsOwnRecord(recordId, after.userId)) {
    logger.error("refusing attendance correction for another employee's record", {
      recordId,
      recordUserId: String(recordId || "").split("_")[0] || "",
      correctionUserId: String(after.userId || ""),
    });
    return false;
  }
  // Materialize a missing record from the correction's identity + schedule.
  const dayKey = String(recordId).split("_").find((p) => /^\d{8}$/.test(p)) || "";
  await ref.set({
    ...fields,
    userId: String(after.userId || ""),
    userName: after.userName != null ? String(after.userName) : null,
    branchId: after.branchId != null ? String(after.branchId) : null,
    shift: String(after.shift || ""),
    date: after.date || null,
    dayKey,
    scheduledStart: after.scheduledStart || null,
    scheduledEnd: after.scheduledEnd || null,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  });
  return true;
}

// Any write to a correction → own its lifecycle events + notifications, and (on
// approval) apply the resolution onto the parent record. Clients never touch the
// record's corrected fields or the audit trail directly.
exports.onAttendanceCorrectionWritten = onDocumentWritten(
  `${ATTENDANCE_CORRECTIONS}/{correctionId}`,
  async (event) => {
    const beforeSnap = event.data && event.data.before;
    const afterSnap = event.data && event.data.after;
    const before = (beforeSnap && beforeSnap.exists) ? (beforeSnap.data() || {}) : null;
    const after = (afterSnap && afterSnap.exists) ? (afterSnap.data() || {}) : null;
    if (!after) return; // soft-deleted only — nothing to do.

    const correctionId = event.params.correctionId;
    const recordId = String(after.attendanceId || "");
    const employeeUid = String(after.userId || "");
    const data = { correctionKind: String(after.kind || "other") };
    const subject = attendanceNotificationSubject(after);

    // 1) Newly created correction.
    if (!before) {
      const createStatus = String(after.status || "pending");

      // 1a) A manager's DIRECT action — born `approved` (Add record / Resolve).
      // Apply immediately (materializing a missing record), audit, and notify the
      // employee. No reviewer step, so no reviewer notification.
      if (createStatus === "approved") {
        const applied = await applyCorrectionResolution(recordId, after);
        await appendAttendanceEvent(recordId, {
          kind: "correctionApproved",
          actorId: String(after.decidedBy || ""),
          actorName: after.decidedByName != null ? String(after.decidedByName) : null,
          note: after.decisionNote != null ? String(after.decisionNote) : (after.reason != null ? String(after.reason) : null),
          data,
        });
        if (applied && employeeUid) {
          const deciderName = String(after.decidedByName || "").trim();
          await writeAttendanceNotifications([employeeUid], {
            type: "attendanceCorrectionApproved",
            title: "Attendance updated",
            body: deciderName
              ? `${subject} • Updated by ${deciderName}`
              : `${subject} • Attendance updated`,
            recordId,
            correctionId,
            senderUid: String(after.decidedBy || ""),
          });
        }
        return;
      }

      // 1b) An employee FILING (pending) → opening audit event + notify reviewers.
      await appendAttendanceEvent(recordId, {
        kind: "correctionRequested",
        actorId: String(after.requestedBy || ""),
        actorName: after.requestedByName != null ? String(after.requestedByName) : null,
        note: after.reason != null ? String(after.reason) : null,
        data,
      });
      const reviewers = await resolveAttendanceReviewers(after.branchId, String(after.requestedBy || ""));
      await writeAttendanceNotifications(reviewers, {
        type: "attendanceCorrectionFiled",
        title: "Attendance correction",
        body: `${subject} • ${String(after.userName || "An employee")} filed a ${attendanceCorrectionKindLabel(after.kind)} correction`,
        recordId,
        correctionId,
        senderUid: String(after.requestedBy || ""),
      });
      return;
    }

    // 2) Decision — pending → approved / rejected (ignore other field bumps).
    const beforeStatus = String(before.status || "pending");
    const afterStatus = String(after.status || "pending");
    if (beforeStatus === afterStatus) return;
    if (afterStatus !== "approved" && afterStatus !== "rejected") return;

    const deciderName = String(after.decidedByName || "").trim();
    const decidedBy = String(after.decidedBy || "");

    if (afterStatus === "approved") {
      // Apply the client-computed resolution (single source of the minute math:
      // AttendanceCalculator) onto the parent record — server-authoritative,
      // upserting a missing record (a missed-punch materializes on approval).
      if (recordId) {
        let applied = false;
        try {
          applied = await applyCorrectionResolution(recordId, after);
        } catch (e) {
          logger.warn("failed to apply approved correction", { recordId, error: String(e) });
        }
        await appendAttendanceEvent(recordId, {
          kind: "correctionApproved",
          actorId: decidedBy,
          actorName: after.decidedByName != null ? String(after.decidedByName) : null,
          note: after.decisionNote != null ? String(after.decisionNote) : null,
          data,
        });
        if (applied && employeeUid) {
          await writeAttendanceNotifications([employeeUid], {
            type: "attendanceCorrectionApproved",
            title: "Correction approved",
            body: deciderName
              ? `${subject} • Approved by ${deciderName}`
              : `${subject} • Approved`,
            recordId,
            correctionId,
            senderUid: decidedBy,
          });
        }
      }
      return;
    }

    // rejected — record untouched; audit the decision + notify the employee.
    await appendAttendanceEvent(recordId, {
      kind: "correctionRejected",
      actorId: decidedBy,
      actorName: after.decidedByName != null ? String(after.decidedByName) : null,
      note: after.decisionNote != null ? String(after.decisionNote) : null,
      data,
    });
    if (employeeUid) {
      await writeAttendanceNotifications([employeeUid], {
        type: "attendanceCorrectionRejected",
        title: "Correction rejected",
        body: deciderName
          ? `${subject} • Rejected by ${deciderName}`
          : `${subject} • Rejected`,
        recordId,
        correctionId,
        senderUid: decidedBy,
      });
    }
  },
);

// Millis of a Firestore Timestamp, or null when absent/unresolved.
function tsMillis(v) {
  return v && typeof v.toMillis === "function" ? v.toMillis() : null;
}

function chunked(list, size) {
  const out = [];
  for (let i = 0; i < list.length; i += size) out.push(list.slice(i, i + size));
  return out;
}

async function getAllRefs(refs) {
  if (!refs.length) return [];
  const out = [];
  for (const slice of chunked(refs, 450)) {
    out.push(...await db.getAll(...slice));
  }
  return out;
}

async function readSchedulesForBusinessDays(days) {
  const weeks = new Map();
  for (const day of days) {
    const info = weekStartInfoForBusinessDay(day);
    if (info) weeks.set(info.key, info);
  }

  const byWeek = new Map();
  for (const info of weeks.values()) {
    const snap = await db
      .collection(WEEKLY_SCHEDULES)
      .where("weekStart", "==", admin.firestore.Timestamp.fromMillis(info.weekStartMs))
      .get();
    byWeek.set(
      info.key,
      snap.docs.map((doc) => ({ id: doc.id, data: doc.data() || {} })),
    );
  }
  return byWeek;
}

function candidateRowsForSchedules(days, schedulesByWeek, nowMs) {
  const rows = [];
  for (const day of days) {
    const info = weekStartInfoForBusinessDay(day);
    const schedules = info ? schedulesByWeek.get(info.key) || [] : [];
    for (const sched of schedules) {
      rows.push(...buildExpectedShiftRows({
        schedule: { ...sched.data, id: sched.id },
        businessDay: day,
        nowMs,
      }));
    }
  }
  return rows;
}

async function readAttendanceRecordsById(rowIds) {
  const refs = rowIds.map((id) => db.collection(ATTENDANCE).doc(id));
  const snaps = await getAllRefs(refs);
  const records = new Map();
  for (const snap of snaps) {
    if (!snap.exists) continue;
    const data = snap.data() || {};
    if (data.deletedAt) continue;
    records.set(snap.id, { ...data, id: snap.id });
  }
  return records;
}

async function readOpenAttendanceCorrectionIds(rowIds) {
  if (!rowIds.length) return new Set();
  const open = new Set();
  for (const ids of chunked(rowIds, 30)) {
    const snap = await db
      .collection(ATTENDANCE_CORRECTIONS)
      .where("attendanceId", "in", ids)
      .get();
    for (const doc of snap.docs) {
      const data = doc.data() || {};
      if (data.deletedAt) continue;
      if (String(data.status || "pending") === "pending") {
        const attendanceId = String(data.attendanceId || "");
        if (attendanceId) open.add(attendanceId);
      }
    }
  }
  return open;
}

function groupRowsByClose(rows) {
  const groups = new Map();
  for (const row of rows) {
    const key = `${row.branchId}_${row.dayKey}_${row.shift}`;
    const group = groups.get(key) || {
      branchId: row.branchId,
      dayKey: row.dayKey,
      businessDate: row.businessDate,
      shift: row.shift,
      rows: [],
    };
    group.rows.push(row);
    groups.set(key, group);
  }
  return groups;
}

function expectationAuditId(group) {
  return `attendance_expectations_${group.branchId}_${group.dayKey}_${group.shift}`;
}

function expectationPayload(row, existing, serverTimestamp) {
  const exists = !!existing;
  const existingVersion = Number(existing && existing.version);
  const changed = exists && expectationInputsChanged(row, existing);
  const closedAt = existing && existing.closedAt ? existing.closedAt : serverTimestamp;
  const version = exists
    ? (changed ? (Number.isFinite(existingVersion) ? existingVersion + 1 : 2) :
      (Number.isFinite(existingVersion) ? existingVersion : 1))
    : 1;

  return {
    rowId: row.rowId,
    userId: row.userId,
    userName: row.userName,
    branchId: row.branchId,
    dayKey: row.dayKey,
    businessDate: row.businessDate,
    shift: row.shift,
    scheduledStartAt: admin.firestore.Timestamp.fromMillis(row.scheduledStartAtMs),
    scheduledEndAt: admin.firestore.Timestamp.fromMillis(row.scheduledEndAtMs),
    outcome: row.outcome,
    expected: row.expected,
    recordId: row.recordId,
    leaveType: row.leaveType,
    workedMinutes: row.workedMinutes,
    lateMinutes: row.lateMinutes,
    earlyLeaveMinutes: row.earlyLeaveMinutes,
    overtimeMinutes: row.overtimeMinutes,
    exceptionCodes: row.exceptionCodes,
    ...(exists ? {} : { locked: false }),
    version,
    closedAt,
    restatedAt: changed ? serverTimestamp : ((existing && existing.restatedAt) || null),
    source: "system",
    schemaVersion: row.schemaVersion,
  };
}

async function commitAttendanceExpectationGroups(rows) {
  const serverTimestamp = admin.firestore.FieldValue.serverTimestamp();
  let created = 0;
  let restated = 0;
  let skipped = 0;
  let locked = 0;
  let audits = 0;

  for (const group of groupRowsByClose(rows).values()) {
    const rowRefs = group.rows.map((row) => db.collection(ATTENDANCE_EXPECTATIONS).doc(row.rowId));
    const auditRef = db.collection(AUDIT_LOGS).doc(expectationAuditId(group));
    const snaps = await getAllRefs([...rowRefs, auditRef]);
    const auditSnap = snaps[snaps.length - 1];
    const rowSnaps = snaps.slice(0, -1);

    const writes = [];
    for (let i = 0; i < group.rows.length; i++) {
      const row = group.rows[i];
      const snap = rowSnaps[i];
      const existing = snap && snap.exists ? (snap.data() || {}) : null;
      if (existing && existing.locked === true) {
        locked++;
        continue;
      }
      if (existing && existing.closedAt && !expectationInputsChanged(row, existing)) {
        skipped++;
        continue;
      }
      if (existing) restated++;
      else created++;
      writes.push({ ref: rowRefs[i], data: expectationPayload(row, existing, serverTimestamp) });
    }

    if (writes.length === 0) continue;

    const batches = chunked(writes, 449);
    for (let i = 0; i < batches.length; i++) {
      const batch = db.batch();
      for (const write of batches[i]) {
        batch.set(write.ref, write.data, { merge: true });
      }
      if (i === 0 && !(auditSnap && auditSnap.exists)) {
        const counts = summarizeRows(group.rows);
        batch.set(auditRef, {
          eventType: "attendance.expectations_closed",
          entityType: "attendance_expectations",
          entityId: `${group.branchId}_${group.dayKey}_${group.shift}`,
          actorId: "system",
          actorName: "Attendance Close",
          actorRole: "admin",
          branchId: group.branchId,
          metadata: {
            businessDate: group.businessDate,
            dayKey: group.dayKey,
            shift: group.shift,
            counts,
          },
          schemaVersion: 1,
          isDeleted: false,
          timestamp: serverTimestamp,
        });
        audits++;
      }
      await batch.commit();
    }
  }

  return { created, restated, skipped, locked, audits };
}

async function buildClosableAttendanceExpectationRows(nowMs) {
  const days = businessDaysToSweep(nowMs);
  if (!days.length) return [];
  const schedulesByWeek = await readSchedulesForBusinessDays(days);
  const candidates = candidateRowsForSchedules(days, schedulesByWeek, nowMs);
  const closableCandidates = candidates.filter((row) =>
    isSlotClosable(row, nowMs, AUTO_CLOSE_GRACE_MINUTES));
  const rowIds = [...new Set(closableCandidates.map((row) => row.rowId))];
  const closableUids = [...new Set(closableCandidates.map((row) => row.userId))];
  const [recordsById, openCorrectionIds, namesByUid] = await Promise.all([
    readAttendanceRecordsById(rowIds),
    readOpenAttendanceCorrectionIds(rowIds),
    readUserNamesByUid(closableUids),
  ]);

  const rows = [];
  for (const day of days) {
    const info = weekStartInfoForBusinessDay(day);
    const schedules = info ? schedulesByWeek.get(info.key) || [] : [];
    for (const sched of schedules) {
      rows.push(...buildExpectedShiftRows({
        schedule: { ...sched.data, id: sched.id },
        businessDay: day,
        recordsById,
        openCorrectionIds,
        namesByUid,
        nowMs,
      }).filter((row) => isSlotClosable(row, nowMs, AUTO_CLOSE_GRACE_MINUTES)));
    }
  }
  return rows;
}

// Resolve display names for the uids a sweep is about to close. The roster
// stores uids only and a phantom no-show has no attendance record, so without
// this every absence row lands with a null `userName` and the report renders a
// raw Firebase uid. Bounded by the closable slots in the swept week, batched
// through the same `getAll` path as the record read.
async function readUserNamesByUid(uids) {
  if (!uids.length) return {};
  const refs = uids.map((uid) => db.collection(USERS).doc(uid));
  const snaps = await getAllRefs(refs);
  const names = {};
  for (const snap of snaps) {
    if (!snap.exists) continue;
    const data = snap.data() || {};
    // Same precedence the client model uses: `displayName`, then the profile
    // `fullName` key the same doc carries.
    const name = String(data.displayName || data.fullName || "").trim();
    if (name) names[snap.id] = name;
  }
  return names;
}

// Auto-close sessions the employee never clocked out of. A still-open session
// (status inProgress, no clockOut) is flipped to `pendingReview` with source
// `autoClose` — which onAttendanceWritten audits as `autoClosed` — when it is due
// per `isAutoCloseDue`: scheduled end + grace has passed, OR (the R7 safety net)
// it has been open past the max-session cap from clock-in, which catches an
// UNSCHEDULED session that has no scheduled end. The employee is nudged to file a
// correction. Idempotent: the query is `status == inProgress` and a close flips
// that status, so a session is never closed twice and a manual close (which is not
// inProgress) is never overwritten.
exports.autoCloseAttendance = onSchedule("every 30 minutes", async () => {
  const nowMs = Date.now();
  const graceMs = ATTENDANCE_AUTO_CLOSE_GRACE_MINUTES * 60 * 1000;
  const maxSessionMs = ATTENDANCE_MAX_SESSION_MINUTES * 60 * 1000;
  let snap;
  try {
    // Open sessions are naturally bounded (only people currently clocked in);
    // status equality needs only the automatic single-field index.
    snap = await db.collection(ATTENDANCE).where("status", "==", "inProgress").get();
  } catch (e) {
    logger.warn("autoCloseAttendance query failed", { error: String(e) });
    return;
  }
  let closed = 0;
  for (const doc of snap.docs) {
    const d = doc.data() || {};
    const due = isAutoCloseDue({
      clockOutMs: tsMillis(d.clockOut),
      deleted: !!d.deletedAt,
      scheduledEndMs: tsMillis(d.scheduledEnd),
      clockInMs: tsMillis(d.clockIn),
      nowMs,
      graceMs,
      maxSessionMs,
    });
    if (!due) continue;
    try {
      await doc.ref.update({
        status: "pendingReview",
        source: "autoClose",
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      closed++;
      const uid = String(d.userId || "");
      if (uid) {
        await writeAttendanceNotifications([uid], {
          type: "attendanceAutoClosed",
          title: "Shift needs review",
          body: `${attendanceNotificationSubject(d)} • You didn't clock out — file a correction with your real clock-out time.`,
          recordId: doc.id,
          senderUid: "",
        });
      }
    } catch (e) {
      logger.warn("autoCloseAttendance update failed", { recordId: doc.id, error: String(e) });
    }
  }
  if (closed > 0) logger.info("autoCloseAttendance closed sessions", { closed });
});

/**
 * Materializes the durable attendance-reporting denominator at slot close
 * ([ADR-017](../docs/decisions/ADR-017-attendance-reporting-ledger.md)).
 *
 * WHY THIS EXISTS. A rostered no-show writes no `attendance` document (lazy
 * Absent, deliberate — the live board derives it in memory). Reporting therefore
 * had no durable denominator: aggregating only materialized records means
 * absence can never grow and a show-up rate pins at ~100%. This sweep turns each
 * expected roster slot into a persisted fact, including the **phantom** rows for
 * slots nobody ever clocked.
 *
 * THE SWEEP. Every 30 minutes it resolves every `Africa/Cairo` business day from
 * the current business week's Sunday through today, plus the previous business
 * day for the Sunday boundary, then reads those business weeks'
 * `weekly_schedules`, expands rostered slots, and keeps only slots already past
 * `scheduledEnd + grace`. The window is intentionally capped at 8 days: wide
 * enough to self-heal after a missed run or deploy delay so a rostered day never
 * falls out of reach during its active week, but still bounded. Attendance
 * documents are fetched with one `getAll` on deterministic ids — not a query per
 * row — and pending corrections in chunked `attendanceId in (...)` reads, so
 * cost is `O(branches × ≤8 days × shifts × staff)` with no unbounded scan.
 *
 * IDEMPOTENCY + RESTATEMENT. Each row id equals the attendance record's own
 * deterministic id (`{uid}_{yyyyMMdd}_{shift}`), so a retry overwrites rather
 * than duplicating, and joining to `attendance/{id}` needs no lookup. A row
 * marked `locked` is never overwritten. A row whose inputs changed — typically
 * an approved correction landing after close — is **restated**: same id, `version`
 * incremented, `restatedAt` stamped. Values are never silently mutated, because a
 * period may already have been exported to payroll.
 *
 * MINUTES ARE NOT RECOMPUTED HERE. Worked/late/early/overtime are copied from the
 * record's persisted snapshot, which the single Flutter `AttendanceCalculator`
 * produced. Two implementations in two languages would drift, and these minutes
 * feed pay. An open session at close time therefore carries stale minutes plus a
 * `missingPunch` code that blocks the close; the authoritative figures arrive when
 * `autoCloseAttendance` or a correction closes the session, which restates the row.
 *
 * Time math is delegated entirely to `recurring_task_deadline.js`
 * (`businessDayParts` / `businessCivilMidnightMs` / `resolveShiftHours`) — no Cairo
 * offset or DST arithmetic is written here. Egypt observes DST, so a hand-rolled
 * offset would be a silent one-hour payroll error twice a year. Overnight shifts
 * (`endMinutes > 1440`) end on the next calendar day but belong to their
 * scheduled-start business day.
 *
 * Writes are batched ≤450 ops and emit one deterministic `audit_logs` entry per
 * (branch, businessDate, shift) close with the materialized counts, per
 * [ADR-005](../docs/decisions/ADR-005-server-authoritative-writes.md). Clients may
 * only ever read `attendance_expectations`; every client write is denied in
 * `firestore.rules`.
 *
 * Requires the `(branchId, dayKey)` and `(userId, dayKey)` composites in
 * `firestore.indexes.json` for the client read layer to query these rows.
 */
exports.closeAttendanceExpectations = onSchedule(
  {
    schedule: "every 30 minutes",
    timeZone: BUSINESS_TIME_ZONE,
    maxInstances: 1,
    retryCount: 0,
    timeoutSeconds: 540,
  },
  async () => {
    const nowMs = Date.now();
    let rows;
    try {
      rows = await buildClosableAttendanceExpectationRows(nowMs);
    } catch (err) {
      logger.error("attendance expectation close read failed", { error: String(err) });
      return;
    }

    if (rows.length === 0) {
      logger.info("attendance expectation close complete", {
        rows: 0,
        created: 0,
        restated: 0,
        skipped: 0,
        locked: 0,
        audits: 0,
      });
      return;
    }

    try {
      const result = await commitAttendanceExpectationGroups(rows);
      logger.info("attendance expectation close complete", {
        rows: rows.length,
        ...result,
      });
    } catch (err) {
      logger.error("attendance expectation close write failed", { error: String(err) });
    }
  },
);
