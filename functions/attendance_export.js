"use strict";

/**
 * Attendance export — the payroll CSV, and the gate that decides who may ask
 * for it.
 *
 * **Server-side by contract.** ADR-005 makes payroll-relevant artifacts
 * server-authored, and ADR-017 refuses client-authored payroll totals outright:
 * a file the client assembled cannot be audited, because nothing outside the
 * client saw the inputs. So the row mapping lives here, next to the ledger that
 * produced the rows.
 *
 * **Firebase-free on purpose.** Like `attendance_auto_close.js`, every decision
 * in this module is a pure function over plain objects, so it is unit-tested by
 * `node --test` without an emulator, a deploy, or a network. The thin Cloud
 * Function wrapper that writes to Storage and records the export is the only
 * part that needs either.
 *
 * Rounding is deliberately absent: whole minutes go out, and the payroll system
 * owns 5/10/15-minute rounding (`ATTENDANCE_REPORTS_IA` §12.6). Rounding twice
 * is how two systems disagree about a person's pay.
 */

/** Period lifecycle, in the order it advances (ADR-017). */
const PERIOD_STATUS = Object.freeze({
  open: "open",
  ready: "ready",
  locked: "locked",
  exported: "exported",
  restated: "restated",
});

/** What a caller may ask for, and why not. */
const EXPORT_KIND = Object.freeze({
  summaryPdf: "summaryPdf",
  timesheetCsv: "timesheetCsv",
  payrollCsv: "payrollCsv",
});

const DENY = Object.freeze({
  noRows: "noRows",
  notSettled: "notSettled",
  notLocked: "notLocked",
  forbidden: "forbidden",
});

/**
 * May [kind] be produced for this period, by this role?
 *
 * The rule that matters: **payroll requires a locked period, and only an
 * admin may ask.** A pay figure that can still move is not a pay figure, and an
 * export that sits one tap from a manager's PDF button will eventually be
 * pressed by someone who meant to print a summary.
 *
 * The manager artifacts deliberately do *not* require a lock. Managers need to
 * share a week before payroll finalises it, and neither a summary nor a
 * timesheet carries financial authority — gating them on lock would only push
 * people back to screenshots.
 */
function exportGate({ kind, role, status, hasRows, blockingRows = 0 }) {
  const isAdmin = role === "admin";
  const isManagerOrAdmin = isAdmin || role === "manager";

  if (kind === EXPORT_KIND.payrollCsv && !isAdmin) {
    return { allowed: false, reason: DENY.forbidden };
  }
  if (kind !== EXPORT_KIND.payrollCsv && !isManagerOrAdmin) {
    return { allowed: false, reason: DENY.forbidden };
  }
  if (!hasRows) return { allowed: false, reason: DENY.noRows };

  if (kind === EXPORT_KIND.payrollCsv) {
    const locked = status === PERIOD_STATUS.locked ||
      status === PERIOD_STATUS.exported ||
      status === PERIOD_STATUS.restated;
    return locked
      ? { allowed: true, reason: null }
      : { allowed: false, reason: DENY.notLocked };
  }

  // A period still carrying blockers is not settled, and a summary of an
  // unsettled week would be shared as though it were final.
  if (blockingRows > 0) return { allowed: false, reason: DENY.notSettled };
  return { allowed: true, reason: null };
}

/** `ATTENDANCE_REPORTS_IA` §12.6, in order. The order is part of the contract. */
const PAYROLL_CSV_COLUMNS = Object.freeze([
  "period_id",
  "period_version",
  "export_id",
  "scope_kind",
  "branch_id",
  "branch_name",
  "employee_uid",
  "employee_name",
  "business_date",
  "shift",
  "overnight",
  "scheduled_start_at",
  "scheduled_end_at",
  "clock_in_at",
  "clock_out_at",
  "timezone",
  "status",
  "expected_shift",
  "excluded_from_show_up_rate",
  "excluded_reason",
  "source",
  "worked_minutes",
  "break_minutes",
  "paid_candidate_minutes",
  "late_minutes",
  "early_leave_minutes",
  "overtime_minutes",
  "exception_codes",
  "pending_review",
  "correction_ids",
  "gps_in_verified",
  "gps_in_distance_m",
  "gps_out_verified",
  "gps_out_distance_m",
  "attendance_record_id",
  "report_row_id",
  "restatement_of",
]);

/**
 * RFC4180 escaping.
 *
 * Not cosmetic: an employee name containing a comma silently shifts every
 * later column by one, and a payroll system would import the shifted values
 * without complaining.
 */
function csvEscape(value) {
  if (value === null || value === undefined) return "";
  const s = String(value);
  if (/[",\r\n]/.test(s)) return `"${s.replace(/"/g, '""')}"`;
  return s;
}

function isoOrNull(ms) {
  const n = Number(ms);
  if (!Number.isFinite(n) || n <= 0) return null;
  return new Date(n).toISOString();
}

function boolOrNull(v) {
  if (v === null || v === undefined) return null;
  return v ? "true" : "false";
}

function metresOrNull(v) {
  const n = Number(v);
  if (!Number.isFinite(n)) return null;
  return String(Math.round(n));
}

/**
 * Outcomes that are excluded from the show-up denominator. Leave and excused
 * are not failures to attend — counting them as such is the misreading this
 * whole redesign started from.
 */
function excludedFromShowUpRate(row) {
  return row.outcome === "onLeave" || row.outcome === "excused";
}

/** One CSV record for one materialized ledger row. */
function payrollCsvRow(row, meta = {}) {
  const gpsIn = row.clockInVerification || {};
  const gpsOut = row.clockOutVerification || {};
  const excluded = excludedFromShowUpRate(row);
  const codes = Array.isArray(row.exceptionCodes) ? row.exceptionCodes : [];
  const corrections = Array.isArray(row.correctionIds) ? row.correctionIds : [];

  const values = {
    period_id: meta.periodId ?? "",
    period_version: meta.periodVersion ?? row.version ?? 1,
    export_id: meta.exportId ?? "",
    scope_kind: meta.scopeKind ?? "branch",
    branch_id: row.branchId ?? "",
    branch_name: (meta.branchNames || {})[row.branchId] ?? "",
    employee_uid: row.userId ?? "",
    employee_name: row.userName ?? "",
    business_date: row.businessDate ?? "",
    shift: row.shift ?? "",
    // An overnight shift is one whose scheduled end lands past its start's
    // midnight — the payroll system needs to know before it buckets the hours.
    overnight: boolOrNull(isOvernight(row)),
    scheduled_start_at: isoOrNull(row.scheduledStartAtMs),
    scheduled_end_at: isoOrNull(row.scheduledEndAtMs),
    clock_in_at: isoOrNull(row.clockInAtMs),
    clock_out_at: isoOrNull(row.clockOutAtMs),
    timezone: meta.timezone ?? "Africa/Cairo",
    status: row.outcome ?? "",
    expected_shift: boolOrNull(!!row.expected),
    excluded_from_show_up_rate: boolOrNull(excluded),
    excluded_reason: excluded ? (row.leaveType ?? row.outcome ?? "") : "",
    source: row.source ?? "",
    worked_minutes: intOr0(row.workedMinutes),
    break_minutes: intOr0(row.breakMinutes),
    // Breaks are dormant, so there is no unpaid-break policy to subtract. This
    // equals worked minutes and the export carries a warning saying so, rather
    // than inventing a deduction nobody configured.
    paid_candidate_minutes: intOr0(row.workedMinutes) - intOr0(row.breakMinutes) > 0
      ? intOr0(row.workedMinutes) - intOr0(row.breakMinutes)
      : intOr0(row.workedMinutes),
    late_minutes: intOr0(row.lateMinutes),
    early_leave_minutes: intOr0(row.earlyLeaveMinutes),
    overtime_minutes: intOr0(row.overtimeMinutes),
    exception_codes: codes.join("|"),
    pending_review: boolOrNull(
      row.outcome === "needsReview" || row.outcome === "openSession",
    ),
    correction_ids: corrections.join("|"),
    gps_in_verified: boolOrNull(
      gpsIn.verified === undefined ? null : gpsIn.verified,
    ),
    gps_in_distance_m: metresOrNull(gpsIn.distanceMeters),
    gps_out_verified: boolOrNull(
      gpsOut.verified === undefined ? null : gpsOut.verified,
    ),
    gps_out_distance_m: metresOrNull(gpsOut.distanceMeters),
    attendance_record_id: row.recordId ?? "",
    report_row_id: row.rowId ?? "",
    restatement_of: meta.restatementOf ?? "",
  };

  return PAYROLL_CSV_COLUMNS.map((c) => csvEscape(values[c])).join(",");
}

function isOvernight(row) {
  const start = Number(row.scheduledStartAtMs);
  const end = Number(row.scheduledEndAtMs);
  if (!Number.isFinite(start) || !Number.isFinite(end)) return null;
  const startDay = new Date(start).toISOString().slice(0, 10);
  const endDay = new Date(end).toISOString().slice(0, 10);
  return startDay !== endDay;
}

function intOr0(v) {
  const n = Number(v);
  return Number.isFinite(n) ? Math.trunc(n) : 0;
}

/**
 * The whole file: header plus one record per row, CRLF-terminated per RFC4180.
 *
 * Rows are emitted in the order given. The caller sorts, because the ledger's
 * own ordering (date, shift, employee) is already the one payroll expects.
 */
function buildPayrollCsv(rows, meta = {}) {
  const out = [PAYROLL_CSV_COLUMNS.join(",")];
  for (const row of rows || []) {
    out.push(payrollCsvRow(row, meta));
  }
  return out.join("\r\n") + "\r\n";
}

/** Metadata recorded beside the file, so an export can be explained later. */
function exportWarnings(rows) {
  const warnings = [];
  const anyBreaks = (rows || []).some((r) => intOr0(r.breakMinutes) > 0);
  if (!anyBreaks) {
    warnings.push(
      "no-break-policy: paid_candidate_minutes equals worked_minutes",
    );
  }
  const pending = (rows || []).filter(
    (r) => r.outcome === "needsReview" || r.outcome === "openSession",
  ).length;
  if (pending > 0) {
    warnings.push(`pending-review-rows: ${pending}`);
  }
  return warnings;
}

module.exports = {
  PERIOD_STATUS,
  EXPORT_KIND,
  DENY,
  PAYROLL_CSV_COLUMNS,
  exportGate,
  csvEscape,
  payrollCsvRow,
  buildPayrollCsv,
  exportWarnings,
};
