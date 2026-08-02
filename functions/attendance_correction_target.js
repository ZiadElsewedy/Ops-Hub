"use strict";

// Attendance ids are deterministic: `{uid}_{yyyyMMdd}_{shift}`. Firebase UIDs
// cannot contain underscores, so the first segment binds the record to its owner.
function correctionTargetsOwnRecord(recordId, userId) {
  const id = String(recordId || "");
  const uid = String(userId || "");
  const parts = id.split("_");
  return uid.length > 0 && parts.length > 1 && parts[0] === uid;
}

// Legacy attendance rows may not carry userId. Preserve their existing apply
// behavior, but never overwrite a row that declares a different owner.
function correctionMatchesExistingRecordOwner(record, userId) {
  return !Object.prototype.hasOwnProperty.call(record || {}, "userId")
    || String(record.userId) === String(userId || "");
}

module.exports = {
  correctionTargetsOwnRecord,
  correctionMatchesExistingRecordOwner,
};
