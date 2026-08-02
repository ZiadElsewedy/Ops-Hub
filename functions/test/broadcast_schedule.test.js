"use strict";

const test = require("node:test");
const assert = require("node:assert/strict");
const { canClaimScheduledBroadcast } = require("../broadcast_schedule");

const timestamp = (ms) => ({ toMillis: () => ms });

test("a due enabled schedule can be claimed exactly once for its due instant", () => {
  assert.equal(canClaimScheduledBroadcast({ enabled: true, nextRunAt: timestamp(10) }, 10), true);
  assert.equal(
    canClaimScheduledBroadcast(
      { enabled: true, nextRunAt: timestamp(10), dispatchClaimedFor: timestamp(10) },
      10,
    ),
    false,
  );
});

test("a changed, missing, or paused schedule cannot be claimed from a stale query", () => {
  assert.equal(canClaimScheduledBroadcast({ enabled: true, nextRunAt: timestamp(11) }, 10), false);
  assert.equal(canClaimScheduledBroadcast({ enabled: false, nextRunAt: timestamp(10) }, 10), false);
  assert.equal(canClaimScheduledBroadcast({ enabled: true }, 10), false);
});
