"use strict";

const BUSINESS_TIME_ZONE = "Africa/Cairo";

/** A compact, subject-led label for an attendance shift notification. */
function attendanceNotificationSubject({ shift, date }) {
  const shiftName = String(shift || "").trim();
  const readableShift = shiftName
    ? `${shiftName.charAt(0).toUpperCase()}${shiftName.slice(1)} shift`
    : "Shift";
  const millis = date instanceof Date
    ? date.getTime()
    : date && typeof date.toMillis === "function"
      ? date.toMillis()
      : null;
  if (!Number.isFinite(millis)) return readableShift;

  const day = new Intl.DateTimeFormat("en-GB", {
    day: "numeric",
    month: "short",
    timeZone: BUSINESS_TIME_ZONE,
  }).format(new Date(millis));
  return `${readableShift}, ${day}`;
}

module.exports = { attendanceNotificationSubject };
