"use strict";

// Whether the due row read by the poller can still be claimed. Keeping this
// comparison pure makes the no-duplicate schedule decision testable.
function canClaimScheduledBroadcast(schedule, expectedNextRunAtMs) {
  if (!schedule || schedule.enabled === false) return false;
  const next = schedule.nextRunAt;
  const nextMs = next && typeof next.toMillis === "function" ? next.toMillis() : null;
  if (nextMs == null || nextMs !== expectedNextRunAtMs) return false;
  const claimed = schedule.dispatchClaimedFor;
  const claimedMs =
    claimed && typeof claimed.toMillis === "function" ? claimed.toMillis() : null;
  return claimedMs !== expectedNextRunAtMs;
}

module.exports = { canClaimScheduledBroadcast };
