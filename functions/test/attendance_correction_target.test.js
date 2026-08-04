"use strict";

const test = require("node:test");
const assert = require("node:assert");
const {
  correctionTargetsOwnRecord,
  correctionMatchesExistingRecordOwner,
} = require("../attendance_correction_target");

test("correction target accepts a deterministic record id owned by its user", () => {
  assert.strictEqual(
    correctionTargetsOwnRecord("emp1_20260802_morning", "emp1"),
    true,
  );
});

test("correction target refuses another employee's deterministic record id", () => {
  assert.strictEqual(
    correctionTargetsOwnRecord("emp2_20260802_morning", "emp1"),
    false,
  );
});

test("correction target refuses missing or malformed ids", () => {
  assert.strictEqual(correctionTargetsOwnRecord("", "emp1"), false);
  assert.strictEqual(correctionTargetsOwnRecord("emp1", "emp1"), false);
  assert.strictEqual(correctionTargetsOwnRecord("_20260802_morning", ""), false);
});

test("existing attendance owner must match, while legacy rows without owner remain compatible", () => {
  assert.strictEqual(correctionMatchesExistingRecordOwner({ userId: "emp1" }, "emp1"), true);
  assert.strictEqual(correctionMatchesExistingRecordOwner({ userId: "emp2" }, "emp1"), false);
  assert.strictEqual(correctionMatchesExistingRecordOwner({}, "emp1"), true);
});
