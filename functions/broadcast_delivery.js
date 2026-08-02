"use strict";

// A thrown Admin Messaging call has no per-token result to classify, so retry it
// once. Otherwise only retry FCM's transient service failures; invalid/dead
// tokens are handled per response and must not be retried.
function isRetryableBroadcastPushError(err) {
  if (!err || !err.code) return true;
  return new Set([
    "messaging/internal-error",
    "messaging/server-unavailable",
    "messaging/unavailable",
    "messaging/unknown-error",
  ]).has(String(err.code));
}

module.exports = { isRetryableBroadcastPushError };
