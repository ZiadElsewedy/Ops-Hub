"use strict";

// Pure decision + transform helpers for `deleteUserAccount` (see functions/
// index.js). Kept Firebase-free so the risky cascade logic — which records to
// keep vs. purge, and how a schedule/task is rewritten — is unit-testable
// without an emulator, mirroring recurring_task_deadline.js / task_reminders.js.
//
// Policy: clean active/forward-looking data, keep finished history.

// A task/swap/submission in one of these statuses is finished history and is
// left untouched by a delete.
const TERMINAL_TASK_STATUSES = ["approved", "missed", "cancelled"];
const TERMINAL_SWAP_STATUSES = ["managerApproved", "rejected", "cancelled"];
// A sales submission the deleted employee left mid-flight (no terminal decision).
const OPEN_SALES_STATUSES = ["pending", "correctionRequested"];

// Last-admin guard: given every admin user doc as `{ id, isActive }` and the
// target uid, may the target admin be deleted? True only when at least one OTHER
// admin remains usable (not explicitly deactivated) — so the org is never left
// without an administrator who can actually sign in.
function canDeleteAdmin(adminDocs, targetUid) {
  return (adminDocs || []).some(
    (d) => d && d.id !== targetUid && d.isActive !== false,
  );
}

// A weekly-schedule doc id is `${branchId}_${yyyy-MM-dd}`; the trailing 10 chars
// are the week-start key. Past weeks are history and are left alone.
function weekIsCurrentOrFuture(docId, currentWeekKey) {
  return String(docId || "").slice(-10) >= String(currentWeekKey || "");
}

// Remove `uid` from a weekly schedule's `assignments` (nested `{day:{shift:[uid]}}`
// arrays) and `leave` (`{day:{uid:type}}` map keys). Returns the rewritten maps
// plus whether anything changed. Operates on shallow-cloned structures so the
// caller's snapshot is never mutated.
function cleanScheduleForUser(data, uid) {
  const srcAssignments = (data && data.assignments) || {};
  const srcLeave = (data && data.leave) || {};
  const assignments = {};
  const leave = {};
  let changed = false;

  for (const day of Object.keys(srcAssignments)) {
    const shifts = srcAssignments[day] || {};
    assignments[day] = {};
    for (const shift of Object.keys(shifts)) {
      const arr = Array.isArray(shifts[shift]) ? shifts[shift] : [];
      const filtered = arr.filter((u) => u !== uid);
      if (filtered.length !== arr.length) changed = true;
      assignments[day][shift] = filtered;
    }
  }

  for (const day of Object.keys(srcLeave)) {
    const dayLeave = srcLeave[day] || {};
    const next = {};
    for (const key of Object.keys(dayLeave)) {
      if (key === uid) {
        changed = true;
        continue;
      }
      next[key] = dayLeave[key];
    }
    leave[day] = next;
  }

  return { assignments, leave, changed };
}

// Whether a task in this status is still active (eligible for unassign/cancel).
function isActiveTaskStatus(status) {
  return !TERMINAL_TASK_STATUSES.includes(String(status || "pending"));
}

// The assignees left after removing `uid`.
function remainingAssignees(assigneeIds, uid) {
  return (Array.isArray(assigneeIds) ? assigneeIds : []).filter((u) => u !== uid);
}

// An active task loses its only assignee when the deleted user is removed → it is
// cancelled (leaves the active board, stays as a record).
function shouldCancelTask(assigneeIds, uid) {
  return remainingAssignees(assigneeIds, uid).length === 0;
}

function shouldDeleteSwap(status) {
  return !TERMINAL_SWAP_STATUSES.includes(String(status || "pending"));
}

function shouldDeleteRequest(status) {
  return String(status || "pending") === "pending";
}

function shouldDeleteSubmission(status) {
  return OPEN_SALES_STATUSES.includes(String(status || "pending"));
}

// An attendance expectation is forward-looking (delete) when its business date is
// today or later; past expectations pair with actuals and are kept.
function isFutureExpectation(businessDate, todayKey) {
  return String(businessDate || "") >= String(todayKey || "");
}

module.exports = {
  TERMINAL_TASK_STATUSES,
  TERMINAL_SWAP_STATUSES,
  OPEN_SALES_STATUSES,
  canDeleteAdmin,
  weekIsCurrentOrFuture,
  cleanScheduleForUser,
  isActiveTaskStatus,
  remainingAssignees,
  shouldCancelTask,
  shouldDeleteSwap,
  shouldDeleteRequest,
  shouldDeleteSubmission,
  isFutureExpectation,
};
