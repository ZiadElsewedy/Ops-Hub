"use strict";

// Pure policy for the branch-sales ledger.  Keep this Firebase-free so both the
// callable boundary and node:test exercise the identical Cairo calendar logic.
const BUSINESS_TIME_ZONE = "Africa/Cairo";
const MAX_MONEY_PIASTRES = 9_000_000_000_000;
const DATE_FORMATTER = new Intl.DateTimeFormat("en-CA", {
  timeZone: BUSINESS_TIME_ZONE, year: "numeric", month: "2-digit", day: "2-digit",
});

function dateParts(value) {
  const date = value instanceof Date ? value : new Date(value);
  if (!Number.isFinite(date.getTime())) return null;
  const parts = Object.fromEntries(DATE_FORMATTER.formatToParts(date)
    .filter((part) => part.type !== "literal").map((part) => [part.type, part.value]));
  return { year: parts.year, month: parts.month, day: parts.day };
}
function businessDateKey(value) {
  const p = dateParts(value); return p ? `${p.year}${p.month}${p.day}` : null;
}
function businessMonthKey(value) {
  const p = dateParts(value); return p ? `${p.year}${p.month}` : null;
}
function isDateKey(value) { return typeof value === "string" && /^\d{8}$/.test(value); }
function isMonthKey(value) { return typeof value === "string" && /^\d{6}$/.test(value); }
function isWithinLastBusinessDays(dateKey, days, now = new Date()) {
  if (!isDateKey(dateKey) || !Number.isInteger(days) || days < 0) return false;
  const today = businessDateKey(now);
  // YYYYMMDD sorts chronologically, but calendar subtraction must be performed
  // in Cairo civil days.  UTC noon safely represents each date without DST drift.
  const target = Date.UTC(+dateKey.slice(0, 4), +dateKey.slice(4, 6) - 1, +dateKey.slice(6, 8));
  const todayUtc = Date.UTC(+today.slice(0, 4), +today.slice(4, 6) - 1, +today.slice(6, 8));
  const delta = (todayUtc - target) / 86_400_000;
  return Number.isInteger(delta) && delta >= 0 && delta <= days;
}
// A manager/admin may record a close for today or ANY past Cairo business day
// (they enter days an employee missed), but never a future day. Unlike the
// employee `isWithinLastBusinessDays` window there is no lower bound — a
// back-filled record still lands in its own month by its own `businessDateKey`.
function isRecordableSalesDate(dateKey, now = new Date()) {
  if (!isDateKey(dateKey)) return false;
  const today = businessDateKey(now);
  const target = Date.UTC(+dateKey.slice(0, 4), +dateKey.slice(4, 6) - 1, +dateKey.slice(6, 8));
  const todayUtc = Date.UTC(+today.slice(0, 4), +today.slice(4, 6) - 1, +today.slice(6, 8));
  const delta = (todayUtc - target) / 86_400_000;
  return Number.isInteger(delta) && delta >= 0;
}
function salesSubmissionId(branchId, dateKey) { return `${branchId}_${dateKey}`; }
function salesMonthId(branchId, monthKey) { return `${branchId}_${monthKey}`; }
function validSubmissionId(id, branchId, dateKey) {
  return typeof branchId === "string" && branchId.length > 0 && isDateKey(dateKey)
    && id === salesSubmissionId(branchId, dateKey);
}
function validMonthId(id, branchId, monthKey) {
  return typeof branchId === "string" && branchId.length > 0 && isMonthKey(monthKey)
    && id === salesMonthId(branchId, monthKey);
}
function isValidMoney(value) {
  return typeof value === "number" && Number.isFinite(value) && Number.isInteger(value)
    && value >= 0 && value <= MAX_MONEY_PIASTRES;
}
function nextStatus(current, action, actorRole) {
  // Resubmission is intentionally employee-facing. Ownership is enforced by
  // the callable; this pure transition policy only answers role + state.
  if (action === "resubmit") {
    // A day the manager sent back (correctionRequested) OR outright rejected can
    // be fixed and resent by its submitter — a rejection is not a dead end; the
    // amount/details were wrong, so the employee corrects and it re-enters the
    // normal approval flow at `pending`. Ownership is enforced by the callable.
    const resumable = current === "correctionRequested" || current === "rejected";
    if (!resumable) return { error: "illegal_transition" };
    if (actorRole !== "employee") return { error: "unauthorized_role" };
    return { status: "pending" };
  }
  if (!["manager", "admin"].includes(actorRole)) return { error: "unauthorized_role" };
  if (action === "reopen" && actorRole !== "admin") return { error: "unauthorized_role" };
  const map = {
    pending: { approve: "approved", reject: "rejected", requestCorrection: "correctionRequested" },
    approved: { reopen: "pending", editApproved: "approved" },
    rejected: { reopen: "pending" },
  };
  const status = map[current] && map[current][action];
  return status ? { status } : { error: "illegal_transition" };
}
function targetAchievedCrossing(beforeApproved, afterApproved, target) {
  return isValidMoney(beforeApproved) && isValidMoney(afterApproved) && isValidMoney(target)
    && beforeApproved < target && afterApproved >= target;
}
function canDecideSubmission(actorId, submittedById) {
  return typeof actorId === "string" && actorId.length > 0 && actorId !== submittedById;
}

/**
 * Who is told about a branch sales event.
 *
 * **An admin has no `branchId`** (the role is global — see PROJECT_CONTEXT §8),
 * so no `where("branchId", ...)` query can ever return one. Every other
 * reviewer set in OpsHub therefore resolves as *the branch's managers **plus**
 * every active admin* (`resolveRequestApprovers`, `resolveAttendanceReviewers`).
 * Sales was the one that treated admins as a **fallback** — consulted only when
 * the branch query came back empty — which meant an admin received nothing at
 * all from the entire feature: not a new submission to review, not a corrected
 * one, not a target change, not an achieved target. Admins are an **addition**
 * here, exactly like the other two.
 *
 * `managersOnly` narrows the *branch* side to its managers — the difference
 * between a review ping and a branch-wide announcement. It never narrows the
 * admin side: an admin can decide any submission, so an admin is a reviewer in
 * both shapes.
 *
 * `excludeUid` is the actor. Nobody is notified of their own action — the same
 * rule `dispatchBroadcast` applies to an implicit audience. Without it, adding
 * admins would page the admin who just edited the target about their own edit.
 *
 * @param {object} p
 * @param {Array<{id: string, role?: string}>} p.branchUsers active users of the branch
 * @param {Array<{id: string}>} p.admins active admins, org-wide
 * @param {boolean} p.managersOnly restrict the branch side to its managers
 * @param {string} p.excludeUid the acting uid, never a recipient
 * @returns {string[]} de-duplicated recipient uids (possibly empty — valid)
 */
function selectSalesRecipients({ branchUsers = [], admins = [], managersOnly = false, excludeUid = "" } = {}) {
  const uid = (u) => String((u && u.id) || "").trim();
  const out = new Set();
  for (const u of Array.isArray(branchUsers) ? branchUsers : []) {
    if (managersOnly && String((u && u.role) || "employee") !== "manager") continue;
    if (uid(u)) out.add(uid(u));
  }
  for (const a of Array.isArray(admins) ? admins : []) {
    if (uid(a)) out.add(uid(a));
  }
  out.delete(String(excludeUid || "").trim());
  out.delete("");
  return [...out];
}

module.exports = {
  BUSINESS_TIME_ZONE, MAX_MONEY_PIASTRES, businessDateKey, businessMonthKey,
  isWithinLastBusinessDays, isRecordableSalesDate, isDateKey, isMonthKey, salesSubmissionId, salesMonthId,
  validSubmissionId, validMonthId, isValidMoney, nextStatus, targetAchievedCrossing, canDecideSubmission,
  selectSalesRecipients,
};
