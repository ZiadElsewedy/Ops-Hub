"use strict";

const test = require("node:test");
const assert = require("node:assert");

const {
  PERIOD_STATUS,
  EXPORT_KIND,
  DENY,
  PAYROLL_CSV_COLUMNS,
  exportGate,
  csvEscape,
  payrollCsvRow,
  buildPayrollCsv,
  exportWarnings,
} = require("../attendance_export");

const DAY = "2026-07-29";
const START = Date.UTC(2026, 6, 29, 5, 30); // 08:30 Cairo
const END = Date.UTC(2026, 6, 29, 13, 30); // 16:30 Cairo

function row(overrides = {}) {
  return Object.assign(
    {
      rowId: "u1_20260729_morning",
      userId: "u1",
      userName: "Amal",
      branchId: "b1",
      dayKey: "20260729",
      businessDate: DAY,
      shift: "morning",
      scheduledStartAtMs: START,
      scheduledEndAtMs: END,
      outcome: "worked",
      expected: true,
      recordId: "u1_20260729_morning",
      leaveType: null,
      workedMinutes: 480,
      lateMinutes: 0,
      earlyLeaveMinutes: 0,
      overtimeMinutes: 0,
      breakMinutes: 0,
      exceptionCodes: [],
      version: 1,
      source: "clock",
    },
    overrides,
  );
}

/** A real RFC4180 line parser, so an escaped comma cannot fake a passing test. */
function cells(line) {
  const out = [];
  let field = "";
  let quoted = false;
  for (let i = 0; i < line.length; i++) {
    const c = line[i];
    if (quoted) {
      if (c === '"') {
        if (line[i + 1] === '"') {
          field += '"';
          i++;
        } else {
          quoted = false;
        }
      } else {
        field += c;
      }
    } else if (c === '"') {
      quoted = true;
    } else if (c === ",") {
      out.push(field);
      field = "";
    } else {
      field += c;
    }
  }
  out.push(field);
  return out;
}

function valueOf(line, column) {
  return cells(line)[PAYROLL_CSV_COLUMNS.indexOf(column)];
}

test("payroll requires a locked period", () => {
  const base = { kind: EXPORT_KIND.payrollCsv, role: "admin", hasRows: true };

  for (const status of [PERIOD_STATUS.open, PERIOD_STATUS.ready]) {
    const gate = exportGate(Object.assign({}, base, { status }));
    assert.strictEqual(gate.allowed, false, `${status} must not export payroll`);
    assert.strictEqual(gate.reason, DENY.notLocked);
  }
  for (const status of [
    PERIOD_STATUS.locked,
    PERIOD_STATUS.exported,
    PERIOD_STATUS.restated,
  ]) {
    assert.strictEqual(
      exportGate(Object.assign({}, base, { status })).allowed,
      true,
      `${status} may export payroll`,
    );
  }
});

test("a manager can never request payroll, however settled the period", () => {
  const gate = exportGate({
    kind: EXPORT_KIND.payrollCsv,
    role: "manager",
    status: PERIOD_STATUS.locked,
    hasRows: true,
  });
  assert.strictEqual(gate.allowed, false);
  assert.strictEqual(gate.reason, DENY.forbidden);
});

test("manager artifacts do not require a lock, only a settled period", () => {
  // Managers need to share a week before payroll finalises it; neither artifact
  // carries financial authority.
  for (const kind of [EXPORT_KIND.summaryPdf, EXPORT_KIND.timesheetCsv]) {
    assert.strictEqual(
      exportGate({
        kind,
        role: "manager",
        status: PERIOD_STATUS.ready,
        hasRows: true,
        blockingRows: 0,
      }).allowed,
      true,
    );
    assert.strictEqual(
      exportGate({
        kind,
        role: "manager",
        status: PERIOD_STATUS.ready,
        hasRows: true,
        blockingRows: 2,
      }).reason,
      DENY.notSettled,
      "an unsettled week must not be shared as though it were final",
    );
  }
});

test("an empty period exports nothing at all", () => {
  for (const kind of Object.values(EXPORT_KIND)) {
    assert.strictEqual(
      exportGate({
        kind,
        role: "admin",
        status: PERIOD_STATUS.locked,
        hasRows: false,
      }).reason,
      DENY.noRows,
    );
  }
});

test("an employee may request nothing", () => {
  for (const kind of Object.values(EXPORT_KIND)) {
    assert.strictEqual(
      exportGate({
        kind,
        role: "employee",
        status: PERIOD_STATUS.locked,
        hasRows: true,
      }).reason,
      DENY.forbidden,
    );
  }
});

test("csvEscape protects the column boundary", () => {
  // A name with a comma silently shifts every later column by one, and a
  // payroll system imports the shifted values without complaining.
  assert.strictEqual(csvEscape("Amal, A"), '"Amal, A"');
  assert.strictEqual(csvEscape('He said "hi"'), '"He said ""hi"""');
  assert.strictEqual(csvEscape("line\nbreak"), '"line\nbreak"');
  assert.strictEqual(csvEscape(null), "");
  assert.strictEqual(csvEscape(undefined), "");
  assert.strictEqual(csvEscape(0), "0");
  assert.strictEqual(csvEscape(false), "false");
});

test("a row with an awkward name still parses to the right column count", () => {
  const line = payrollCsvRow(row({ userName: 'Amal, "A"' }));
  const parsed = cells(line);
  assert.strictEqual(parsed.length, PAYROLL_CSV_COLUMNS.length);
  // And the awkward value survives the round trip intact.
  assert.strictEqual(
    parsed[PAYROLL_CSV_COLUMNS.indexOf("employee_name")],
    'Amal, "A"',
  );
});

test("header is the documented column order", () => {
  const csv = buildPayrollCsv([]);
  assert.strictEqual(csv.trimEnd(), PAYROLL_CSV_COLUMNS.join(","));
  assert.strictEqual(PAYROLL_CSV_COLUMNS[0], "period_id");
  assert.strictEqual(
    PAYROLL_CSV_COLUMNS[PAYROLL_CSV_COLUMNS.length - 1],
    "restatement_of",
  );
});

test("minutes are exported whole and unrounded", () => {
  // Payroll owns 5/10/15-minute rounding. Rounding twice is how two systems
  // disagree about a person's pay.
  const line = payrollCsvRow(
    row({ workedMinutes: 487, lateMinutes: 7, overtimeMinutes: 13 }),
  );
  assert.strictEqual(valueOf(line, "worked_minutes"), "487");
  assert.strictEqual(valueOf(line, "late_minutes"), "7");
  assert.strictEqual(valueOf(line, "overtime_minutes"), "13");
});

test("leave and excused are excluded from the show-up denominator", () => {
  const leave = payrollCsvRow(row({ outcome: "onLeave", leaveType: "sick" }));
  assert.strictEqual(valueOf(leave, "excluded_from_show_up_rate"), "true");
  assert.strictEqual(valueOf(leave, "excluded_reason"), "sick");

  const excused = payrollCsvRow(row({ outcome: "excused", leaveType: null }));
  assert.strictEqual(valueOf(excused, "excluded_from_show_up_rate"), "true");

  const worked = payrollCsvRow(row());
  assert.strictEqual(valueOf(worked, "excluded_from_show_up_rate"), "false");
  assert.strictEqual(valueOf(worked, "excluded_reason"), "");
});

test("a no-show carries no clock times and no record id", () => {
  const line = payrollCsvRow(
    row({
      outcome: "absent",
      recordId: null,
      clockInAtMs: null,
      clockOutAtMs: null,
      workedMinutes: 0,
    }),
  );
  assert.strictEqual(valueOf(line, "clock_in_at"), "");
  assert.strictEqual(valueOf(line, "clock_out_at"), "");
  assert.strictEqual(valueOf(line, "attendance_record_id"), "");
  assert.strictEqual(valueOf(line, "worked_minutes"), "0");
  // Still a real expected shift — that is the whole point of the ledger row.
  assert.strictEqual(valueOf(line, "expected_shift"), "true");
});

test("pending review is flagged so payroll can refuse the row", () => {
  for (const outcome of ["needsReview", "openSession"]) {
    assert.strictEqual(
      valueOf(payrollCsvRow(row({ outcome })), "pending_review"),
      "true",
    );
  }
  assert.strictEqual(valueOf(payrollCsvRow(row()), "pending_review"), "false");
});

test("overnight is derived from the scheduled window crossing a date", () => {
  const sameDay = payrollCsvRow(row());
  assert.strictEqual(valueOf(sameDay, "overnight"), "false");

  const overnight = payrollCsvRow(
    row({
      scheduledStartAtMs: Date.UTC(2026, 6, 29, 20, 0),
      scheduledEndAtMs: Date.UTC(2026, 6, 30, 4, 0),
    }),
  );
  assert.strictEqual(valueOf(overnight, "overnight"), "true");
});

test("GPS is optional and never fabricated", () => {
  const without = payrollCsvRow(row());
  assert.strictEqual(valueOf(without, "gps_in_verified"), "");
  assert.strictEqual(valueOf(without, "gps_in_distance_m"), "");

  const with_ = payrollCsvRow(
    row({
      clockInVerification: { verified: true, distanceMeters: 12.4 },
      clockOutVerification: { verified: false, distanceMeters: 310.6 },
    }),
  );
  assert.strictEqual(valueOf(with_, "gps_in_verified"), "true");
  assert.strictEqual(valueOf(with_, "gps_in_distance_m"), "12");
  assert.strictEqual(valueOf(with_, "gps_out_verified"), "false");
  assert.strictEqual(valueOf(with_, "gps_out_distance_m"), "311");
});

test("exception codes and correction ids are pipe-delimited", () => {
  const line = payrollCsvRow(
    row({
      exceptionCodes: ["late", "overtime"],
      correctionIds: ["c1", "c2"],
    }),
  );
  assert.strictEqual(valueOf(line, "exception_codes"), "late|overtime");
  assert.strictEqual(valueOf(line, "correction_ids"), "c1|c2");
});

test("meta travels onto every row so a file explains itself", () => {
  const csv = buildPayrollCsv([row(), row({ userId: "u2" })], {
    periodId: "b1_weekly_20260726_20260801_v1",
    periodVersion: 2,
    exportId: "exp_9",
    scopeKind: "branch",
    branchNames: { b1: "Arkan" },
    restatementOf: "exp_8",
  });
  const lines = csv.trimEnd().split("\r\n");
  assert.strictEqual(lines.length, 3, "header + two rows");
  for (const line of lines.slice(1)) {
    assert.strictEqual(valueOf(line, "period_id"), "b1_weekly_20260726_20260801_v1");
    assert.strictEqual(valueOf(line, "period_version"), "2");
    assert.strictEqual(valueOf(line, "export_id"), "exp_9");
    assert.strictEqual(valueOf(line, "branch_name"), "Arkan");
    assert.strictEqual(valueOf(line, "timezone"), "Africa/Cairo");
    assert.strictEqual(valueOf(line, "restatement_of"), "exp_8");
  }
});

test("the file is CRLF-terminated per RFC4180", () => {
  const csv = buildPayrollCsv([row()]);
  assert.ok(csv.endsWith("\r\n"));
  assert.strictEqual(csv.split("\r\n").filter(Boolean).length, 2);
});

test("warnings say what the file could not know", () => {
  // Breaks are dormant, so paid candidate minutes equal worked minutes. The
  // export says so rather than inventing a deduction nobody configured.
  const warnings = exportWarnings([row(), row({ outcome: "needsReview" })]);
  assert.ok(warnings.some((w) => w.startsWith("no-break-policy")));
  assert.ok(warnings.some((w) => w === "pending-review-rows: 1"));

  const clean = exportWarnings([row({ breakMinutes: 30 })]);
  assert.ok(!clean.some((w) => w.startsWith("no-break-policy")));
  assert.ok(!clean.some((w) => w.startsWith("pending-review-rows")));
});
