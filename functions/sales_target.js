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
  if (!["manager", "admin"].includes(actorRole)) return { error: "unauthorized_role" };
  if (action === "reopen" && actorRole !== "admin") return { error: "unauthorized_role" };
  const map = {
    pending: { approve: "approved", reject: "rejected", requestCorrection: "correctionRequested" },
    approved: { reopen: "pending", editApproved: "approved" },
    rejected: { reopen: "pending" },
    correctionRequested: { resubmit: "pending" },
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

module.exports = {
  BUSINESS_TIME_ZONE, MAX_MONEY_PIASTRES, businessDateKey, businessMonthKey,
  isWithinLastBusinessDays, isDateKey, isMonthKey, salesSubmissionId, salesMonthId,
  validSubmissionId, validMonthId, isValidMoney, nextStatus, targetAchievedCrossing, canDecideSubmission,
};
