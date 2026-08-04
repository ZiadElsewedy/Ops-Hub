"use strict";

const test = require("node:test");
const assert = require("node:assert/strict");
const { isRetryableBroadcastPushError, resolveSendsPush } = require("../broadcast_delivery");

test("explicit broadcast delivery wins, with category fallback for legacy schedules", () => {
  assert.equal(resolveSendsPush(true, false), true);
  assert.equal(resolveSendsPush(false, true), false);
  assert.equal(resolveSendsPush(undefined, false), false);
  assert.equal(resolveSendsPush(undefined, true), true);
});

test("broadcast push retries only transient FCM failures or thrown API calls", () => {
  for (const code of [
    "messaging/internal-error",
    "messaging/server-unavailable",
    "messaging/unavailable",
    "messaging/unknown-error",
  ]) {
    assert.equal(isRetryableBroadcastPushError({ code }), true);
  }
  assert.equal(isRetryableBroadcastPushError(new Error("transport broke")), true);
});

test("broadcast push never retries dead or invalid tokens", () => {
  for (const code of [
    "messaging/registration-token-not-registered",
    "messaging/invalid-registration-token",
    "messaging/invalid-argument",
  ]) {
    assert.equal(isRetryableBroadcastPushError({ code }), false);
  }
});
