"use strict";

const assert = require("node:assert/strict");
const test = require("node:test");
const { attendanceNotificationSubject } = require("../attendance_notification_subject");

test("attendanceNotificationSubject joins a readable shift and Cairo business date", () => {
  assert.equal(
    attendanceNotificationSubject({
      shift: "morning",
      date: { toMillis: () => Date.parse("2026-08-01T21:00:00Z") },
    }),
    "Morning shift, 2 Aug",
  );
});

test("attendanceNotificationSubject keeps the shift when a date is unavailable", () => {
  assert.equal(attendanceNotificationSubject({ shift: "night" }), "Night shift");
});
