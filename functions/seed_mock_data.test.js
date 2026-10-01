'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');
const { buildData, users, PASSWORD } = require('./scripts/seed_mock_data');

test('mock dataset has unique document paths and complete login users', () => {
  const docs = buildData();
  const paths = docs.map((item) => item.path);
  assert.equal(new Set(paths).size, paths.length);
  assert.equal(users.length, 10);
  assert.ok(PASSWORD.length >= 12);

  const userDocs = new Set(
    docs.filter((item) => item.path.startsWith('users/') && item.path.split('/').length === 2)
      .map((item) => item.path.split('/')[1]),
  );
  for (const [uid] of users) assert.ok(userDocs.has(uid));
});

test('mock dataset keeps core cross-document references valid', () => {
  const docs = buildData();
  const byPath = new Map(docs.map((item) => [item.path, item.data]));

  for (const { path, data } of docs.filter((item) => item.path.startsWith('tasks/'))) {
    assert.ok(byPath.has(`branches/${data.branchId}`), `${path} branch`);
    for (const uid of data.assigneeIds) assert.ok(byPath.has(`users/${uid}`), `${path} assignee`);
  }

  for (const { path, data } of docs.filter((item) =>
    item.path.startsWith('attendance/') && item.path.split('/').length === 2)) {
    assert.ok(byPath.has(`users/${data.userId}`), `${path} user`);
    assert.ok(byPath.has(`branches/${data.branchId}`), `${path} branch`);
  }

  for (const { path, data } of docs.filter((item) => item.path.startsWith('branch_sales_submissions/'))) {
    assert.ok(byPath.has(`branch_sales_months/${data.branchId}_${data.monthKey}`), `${path} month`);
  }
});

test('mock dataset covers active and historical workflow states', () => {
  const docs = buildData();
  const values = (prefix, field) => new Set(
    docs.filter((item) => item.path.startsWith(prefix)).map((item) => item.data[field]),
  );

  assert.deepEqual(
    [...values('tasks/', 'status')].sort(),
    ['approved', 'cancelled', 'completed', 'missed', 'pending', 'rejected', 'started', 'waitingReview'],
  );
  assert.ok(values('requests/', 'status').has('pending'));
  assert.ok(values('requests/', 'status').has('approved'));
  assert.ok(values('cases/', 'privacy').has('confidential'));
});
