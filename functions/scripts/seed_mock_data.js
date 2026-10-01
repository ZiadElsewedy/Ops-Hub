#!/usr/bin/env node
'use strict';

/**
 * Realistic, relational OpsHub demo data for the Firebase Emulator Suite.
 *
 * The generator is intentionally date-relative so dashboards, schedules and
 * deadlines remain useful whenever it is run. It is idempotent: stable IDs are
 * merged on every run, and it never deletes unrelated emulator data.
 */

const { initializeApp } = require('firebase-admin/app');
const { getAuth } = require('firebase-admin/auth');
const { getFirestore, Timestamp } = require('firebase-admin/firestore');

const dryRun = process.argv.includes('--dry-run');
// Must match firebase_options.dart so the Flutter client and Admin SDK address
// the same emulator namespace. The host guards below still make remote writes
// impossible.
const projectId = process.env.GCLOUD_PROJECT || process.env.GOOGLE_CLOUD_PROJECT || 'bazic-d9ad7';
const PASSWORD = 'MockPass123!';

const users = [
  ['mock-admin', 'admin@opshub.test', 'Nour El-Sayed', 'admin', null, null, 'Operations Director'],
  ['mock-manager-downtown', 'manager.downtown@opshub.test', 'Omar Hassan', 'manager', 'branch-downtown', 'morning', 'Branch Manager'],
  ['mock-manager-maadi', 'manager.maadi@opshub.test', 'Mariam Adel', 'manager', 'branch-maadi', 'morning', 'Branch Manager'],
  ['mock-salma', 'salma@opshub.test', 'Salma Ahmed', 'employee', 'branch-downtown', 'morning', 'Sales Associate'],
  ['mock-youssef', 'youssef@opshub.test', 'Youssef Ali', 'employee', 'branch-downtown', 'night', 'Sales Associate'],
  ['mock-layla', 'layla@opshub.test', 'Layla Mostafa', 'employee', 'branch-downtown', 'morning', 'Cashier'],
  ['mock-karim', 'karim@opshub.test', 'Karim Tarek', 'employee', 'branch-downtown', 'night', 'Cashier'],
  ['mock-dina', 'dina@opshub.test', 'Dina Samir', 'employee', 'branch-maadi', 'morning', 'Sales Associate'],
  ['mock-ahmed', 'ahmed@opshub.test', 'Ahmed Fathy', 'employee', 'branch-maadi', 'night', 'Sales Associate'],
  ['mock-hana', 'hana@opshub.test', 'Hana Nabil', 'employee', 'branch-maadi', 'morning', 'Cashier'],
];

const pad = (n) => String(n).padStart(2, '0');
const ts = (date) => Timestamp.fromDate(date);
const at = (dayOffset, hour = 9, minute = 0) => {
  const d = new Date();
  d.setHours(hour, minute, 0, 0);
  d.setDate(d.getDate() + dayOffset);
  return d;
};
const dayKey = (date) => {
  const parts = new Intl.DateTimeFormat('en-CA', {
    timeZone: 'Africa/Cairo', year: 'numeric', month: '2-digit', day: '2-digit',
  }).formatToParts(date);
  const value = Object.fromEntries(parts.map((p) => [p.type, p.value]));
  return `${value.year}-${value.month}-${value.day}`;
};
const compactDayKey = (date) => dayKey(date).replaceAll('-', '');
const monthKey = (date) => dayKey(date).slice(0, 7).replace('-', '');
const sundayOf = (date) => {
  const d = new Date(date);
  d.setHours(0, 0, 0, 0);
  d.setDate(d.getDate() - d.getDay());
  return d;
};

const created = ts(at(-45));
const updated = ts(at(0));
const docs = [];
const put = (path, data) => docs.push({ path, data });

function baseTask(id, title, assignees, status, deadlineOffset, overrides = {}) {
  const now = at(0);
  const started = ['started', 'completed', 'waitingReview', 'approved', 'rejected'].includes(status);
  const submitted = ['completed', 'waitingReview', 'approved', 'rejected'].includes(status);
  const checklist = ['Prepare the work area', 'Complete the operation', 'Confirm and document']
    .map((title, i) => ({
      id: `${id}-check-${i + 1}`, title, isRequired: i < 2,
      completed: submitted || (started && i === 0), completedAt: submitted ? ts(at(-1, 16 + i)) : null,
    }));
  return {
    id, title, description: `${title}. Follow the branch standard and add a clear note if anything is blocked.`,
    type: overrides.type || 'daily', workType: overrides.workType || null,
    status, priority: overrides.priority || 'normal', branchId: overrides.branchId || 'branch-downtown',
    assigneeIds: assignees, assignedEmployeeId: assignees[0] || null,
    checklist, referenceAttachments: [], data: overrides.data || {}, createdBy: 'mock-manager-downtown',
    assignedShiftId: null, shift: overrides.shift || null,
    assignmentType: overrides.assignmentType || 'individual', instanceDate: null,
    sourceTemplateId: overrides.sourceTemplateId || null, recurrenceRootId: null,
    occurrenceKey: null, correlationId: null, startsAt: ts(at(deadlineOffset - 1, 9)),
    deadline: ts(at(deadlineOffset, 18)), missedAt: status === 'missed' ? ts(at(-2, 18)) : null,
    cancelledAt: status === 'cancelled' ? ts(at(-1, 13)) : null,
    cancelledBy: status === 'cancelled' ? 'mock-manager-downtown' : null,
    cancelReason: status === 'cancelled' ? 'management_decision' : null,
    cancelNote: status === 'cancelled' ? 'Superseded by the branch maintenance visit.' : null,
    reportedIncorrectBy: null, reportedIncorrectAt: null, reportedIncorrectNote: null,
    notes: submitted ? 'Completed and ready for verification.' : null, proofImageUrl: null,
    startedAt: started ? ts(at(-1, 10)) : null, submittedAt: submitted ? ts(at(-1, 17)) : null,
    approvedBy: status === 'approved' ? 'mock-manager-downtown' : null,
    approvedAt: status === 'approved' ? ts(at(-1, 18)) : null,
    rejectedBy: status === 'rejected' ? 'mock-manager-downtown' : null,
    rejectedAt: status === 'rejected' ? ts(at(-1, 18)) : null,
    reviewNotes: status === 'rejected' ? 'Please recount aisle three and attach the discrepancy note.' : null,
    revisionNumber: status === 'rejected' ? 1 : 0, requiresRework: status === 'rejected',
    rejectionReason: status === 'rejected' ? 'incomplete' : null, recurrence: null,
    activityLog: [
      { status: 'pending', actorId: 'mock-manager-downtown', actorName: 'Omar Hassan', at: ts(at(-2, 9)), note: 'Task assigned', attachments: [] },
      ...(started ? [{ status: 'started', actorId: assignees[0] || 'mock-salma', actorName: 'Team member', at: ts(at(-1, 10)), note: null, attachments: [] }] : []),
      ...(submitted ? [{ status: 'waitingReview', actorId: assignees[0] || 'mock-salma', actorName: 'Team member', at: ts(at(-1, 17)), note: 'Submitted for review', attachments: [] }] : []),
    ],
    createdAt: ts(new Date(now.getTime() - 2 * 86400000)), updatedAt: updated, archivedAt: null, version: 1,
  };
}

function buildData() {
  const branches = [
    ['branch-downtown', 'Downtown Flagship', '26 Talaat Harb Street, Cairo', 30.0444, 31.2357, true],
    ['branch-maadi', 'Maadi', 'Road 9, Maadi, Cairo', 29.9602, 31.2569, true],
    ['branch-new-cairo', 'New Cairo', 'Fifth Settlement, Cairo', 30.0131, 31.4913, false],
  ];
  for (const [id, name, location, latitude, longitude, activeSales] of branches) {
    put(`branches/${id}`, {
      id, name, location, isActive: true, logoUrl: null, coverUrl: null,
      swapPolicy: { restrictToSamePosition: true, minRestHours: 10 }, managersCanClock: true,
      geofence: { latitude, longitude, radiusMeters: 175, minAccuracyMeters: 50 },
      salesTargetEnabled: activeSales, createdAt: created, updatedAt: updated, deletedAt: null,
    });
  }

  for (const [uid, email, displayName, role, branchId, assignedShift, position] of users) {
    put(`users/${uid}`, {
      uid, email, displayName, fullName: displayName, photoUrl: null,
      phoneNumber: `+2010${String(10000000 + users.findIndex((u) => u[0] === uid)).padStart(8, '0')}`,
      address: 'Cairo, Egypt', emergencyContact: '+201000000000', authProvider: 'password',
      isEmailVerified: true, role, branchId, isActive: true, assignedShift, position,
      mustChangePassword: false, isProfileCompleted: true, hasCompletedOnboarding: true,
      employmentStatus: 'active', createdBy: uid === 'mock-admin' ? 'system' : 'mock-admin',
      activeSessionId: null, createdAt: created, updatedAt: updated,
    });
    put(`users/${uid}/private/compensation`, {
      salaryAmount: role === 'admin' ? 3500000 : role === 'manager' ? 2400000 : 1250000,
      salaryType: 'monthly', paymentMethod: 'bankTransfer', paymentNumber: `EG-MOCK-${uid.slice(-6).toUpperCase()}`,
      updatedAt: updated, updatedBy: 'mock-admin',
    });
  }

  const taskRows = [
    ['mock-task-open', 'Opening floor readiness', ['mock-salma'], 'pending', 0, { priority: 'high' }],
    ['mock-task-display', 'Refresh the front display', ['mock-youssef'], 'started', 1, {}],
    ['mock-task-cash', 'Verify closing cash count', ['mock-layla'], 'waitingReview', 0, { priority: 'high' }],
    ['mock-task-completed', 'Customer follow-up log', ['mock-salma'], 'completed', 0, {}],
    ['mock-task-stock', 'Weekly stockroom count', ['mock-karim'], 'rejected', 1, { type: 'special' }],
    ['mock-task-approved', 'Safety walkthrough', ['mock-salma', 'mock-layla'], 'approved', -1, {}],
    ['mock-task-overdue', 'Update shelf price labels', ['mock-youssef'], 'pending', -2, { priority: 'high' }],
    ['mock-task-missed', 'Night refrigeration log', [], 'missed', -2, { assignmentType: 'shift', shift: 'night', sourceTemplateId: 'mock-recurring-close' }],
    ['mock-task-cancelled', 'Contractor access preparation', ['mock-karim'], 'cancelled', 2, { type: 'special' }],
    ['mock-task-maadi-open', 'Morning merchandising check', ['mock-dina'], 'started', 0, { branchId: 'branch-maadi' }],
    ['mock-task-maadi-review', 'POS consumables inventory', ['mock-hana'], 'waitingReview', 0, { branchId: 'branch-maadi' }],
  ];
  for (const row of taskRows) put(`tasks/${row[0]}`, baseTask(...row));

  put('task_templates/mock-template-opening', {
    id: 'mock-template-opening', title: 'Store opening checklist', description: 'Reusable opening standard',
    type: 'daily', priority: 'high', branchId: 'branch-downtown', createdBy: 'mock-manager-downtown',
    checklistItems: [
      { id: 'doors', title: 'Inspect entrance and doors', isRequired: true },
      { id: 'pos', title: 'Start and test POS terminals', isRequired: true },
      { id: 'floor', title: 'Confirm floor presentation', isRequired: true },
    ], createdAt: created, updatedAt: updated,
  });
  put('recurringTaskTemplates/mock-recurring-close', {
    id: 'mock-recurring-close', title: 'Evening close', description: 'Daily automated close duties',
    priority: 'high', checklistItems: [{ id: 'secure', title: 'Secure cash and doors', isRequired: true }],
    branchId: 'branch-downtown', shift: 'night', repeat: 'daily', weekday: 1, active: true,
    createdBy: 'mock-manager-downtown', updatedBy: 'mock-manager-downtown', createdAt: created, updatedAt: updated,
    lastRunAt: ts(at(-1, 16)), nextRunAt: ts(at(0, 16)), lastStatus: 'success',
    lastGeneratedTaskId: 'mock-task-missed', failureCount: 0, configVersion: 1,
    runCount: 28, successCount: 27, failedCount: 1, skippedCount: 0, totalDurationMs: 18420,
    lastSuccessAt: ts(at(-1, 16)), lastFailureAt: ts(at(-12, 16)),
  });

  const weekStart = sundayOf(new Date());
  const weekKey = dayKey(weekStart);
  const emptyDay = () => ({ morning: [], night: [] });
  const downtownAssignments = Object.fromEntries(['sunday','monday','tuesday','wednesday','thursday','friday','saturday'].map((d) => [d, emptyDay()]));
  for (const day of Object.keys(downtownAssignments)) {
    downtownAssignments[day].morning = ['mock-salma', 'mock-layla'];
    downtownAssignments[day].night = ['mock-youssef', 'mock-karim'];
  }
  downtownAssignments.friday = { morning: ['mock-layla'], night: ['mock-youssef'] };
  const maadiAssignments = Object.fromEntries(['sunday','monday','tuesday','wednesday','thursday','friday','saturday'].map((d) => [d, { morning: ['mock-dina','mock-hana'], night: ['mock-ahmed'] }]));
  for (const [branchId, assignments] of [['branch-downtown', downtownAssignments], ['branch-maadi', maadiAssignments]]) {
    put(`weekly_schedules/${branchId}_${weekKey}`, {
      id: `${branchId}_${weekKey}`, branchId, weekStart: ts(weekStart), assignments,
      dayNotes: { friday: 'Reduced Friday coverage' }, leave: { friday: { 'mock-salma': 'annual' } },
      createdBy: branchId === 'branch-downtown' ? 'mock-manager-downtown' : 'mock-manager-maadi',
      createdAt: created, updatedAt: updated,
    });
    for (const [role, name, startMinutes, endMinutes] of [['morning','Morning',510,990], ['weekdayNight','Weekday night',900,1380], ['weekendNight','Weekend night',960,1440]]) {
      put(`shift_templates/${branchId}__${role}`, { id: `${branchId}__${role}`, branchId, name, role, startMinutes, endMinutes });
    }
  }
  put('shift_swaps/mock-swap-pending', {
    id: 'mock-swap-pending', branchId: 'branch-downtown', weekStart: ts(weekStart), day: 'wednesday', shift: 'morning',
    requesterId: 'mock-salma', requesterName: 'Salma Ahmed', targetId: 'mock-layla', targetName: 'Layla Mostafa',
    status: 'employeeApproved', note: 'University appointment in the morning.', createdAt: ts(at(-1, 12)), updatedAt: updated,
    managerApprovedById: null, managerApprovedByName: null, managerApprovedAt: null,
  });
  put('shift_swaps/mock-swap-coworker', {
    id: 'mock-swap-coworker', branchId: 'branch-downtown', weekStart: ts(weekStart), day: 'thursday', shift: 'night',
    requesterId: 'mock-karim', requesterName: 'Karim Tarek', targetId: 'mock-youssef', targetName: 'Youssef Ali',
    status: 'pending', note: 'Could you cover the night slot?', createdAt: ts(at(-1, 9)), updatedAt: ts(at(-1, 9)),
    managerApprovedById: null, managerApprovedByName: null, managerApprovedAt: null,
  });
  put('shift_swaps/mock-swap-approved', {
    id: 'mock-swap-approved', branchId: 'branch-downtown', weekStart: ts(weekStart), day: 'monday', shift: 'night',
    requesterId: 'mock-youssef', requesterName: 'Youssef Ali', targetId: 'mock-karim', targetName: 'Karim Tarek',
    status: 'managerApproved', note: 'Family commitment.', createdAt: ts(at(-5, 11)), updatedAt: ts(at(-4, 14)),
    managerApprovedById: 'mock-manager-downtown', managerApprovedByName: 'Omar Hassan', managerApprovedAt: ts(at(-4, 14)),
  });
  put('shift_swaps/mock-swap-rejected', {
    id: 'mock-swap-rejected', branchId: 'branch-maadi', weekStart: ts(weekStart), day: 'tuesday', shift: 'morning',
    requesterId: 'mock-dina', requesterName: 'Dina Samir', targetId: 'mock-hana', targetName: 'Hana Nabil',
    status: 'rejected', note: 'Personal appointment.', createdAt: ts(at(-6, 11)), updatedAt: ts(at(-5, 10)),
    managerApprovedById: null, managerApprovedByName: null, managerApprovedAt: null,
  });

  const attendanceUsers = users.filter((u) => u[3] === 'employee');
  for (let offset = -6; offset <= 0; offset += 1) {
    for (let i = 0; i < attendanceUsers.length; i += 1) {
      const [uid,, name,, branchId, shift] = attendanceUsers[i];
      const date = at(offset, 0);
      const compact = compactDayKey(date);
      const id = `${uid}_${compact}_${shift}`;
      const absent = offset === -2 && i === 1;
      const inProgress = offset === 0 && i < 2;
      const pendingReview = offset === -1 && i === 3;
      const clockIn = absent ? null : at(offset, shift === 'morning' ? 8 : 15, shift === 'morning' ? 30 + (i % 3 === 0 ? 8 : 0) : i % 3 === 0 ? 8 : 0);
      const clockOut = absent || inProgress || pendingReview ? null : at(offset, shift === 'morning' ? 16 : 23, shift === 'morning' ? 35 : 5);
      const outcome = absent ? 'absent' : inProgress ? 'inProgress' : pendingReview ? 'pendingReview' : 'completed';
      const lateMinutes = absent || i % 3 !== 0 ? 0 : 8;
      put(`attendance/${id}`, {
        id, userId: uid, userName: name, branchId, shift, date: ts(date), dayKey: dayKey(date),
        scheduledStart: ts(at(offset, shift === 'morning' ? 8 : 15, shift === 'morning' ? 30 : 0)), scheduledEnd: ts(at(offset, shift === 'morning' ? 16 : 23, shift === 'morning' ? 30 : 0)),
        presenceOnly: false, clockIn: clockIn ? ts(clockIn) : null, clockOut: clockOut ? ts(clockOut) : null,
        breaks: clockOut ? [{ start: ts(at(offset, shift === 'morning' ? 13 : 19)), end: ts(at(offset, shift === 'morning' ? 13 : 19, 30)) }] : [],
        status: outcome, workedMinutes: clockOut ? 455 : 0, lateMinutes, earlyLeaveMinutes: 0,
        overtimeMinutes: 5, breakMinutes: clockOut ? 30 : 0,
        clockInVerification: clockIn ? { location: { latitude: branchId === 'branch-downtown' ? 30.0444 : 29.9602, longitude: branchId === 'branch-downtown' ? 31.2357 : 31.2569, accuracyMeters: 12, capturedAt: ts(clockIn) }, distanceMeters: 18, radiusMeters: 175, minAccuracyMeters: 50, withinRadius: true, accuracyOk: true, verified: true } : null,
        clockOutVerification: null, photoUrl: null, deviceId: `mock-device-${uid}`, notes: null,
        source: 'clock', schemaVersion: 1, createdAt: ts(at(offset, 9)), updatedAt: ts(at(offset, 17)),
      });
      if (offset < 0) put(`attendance_expectations/${id}`, {
        rowId: id, userId: uid, userName: name, branchId, dayKey: dayKey(date), businessDate: dayKey(date), shift,
        scheduledStartAt: ts(at(offset, shift === 'morning' ? 8 : 15, shift === 'morning' ? 30 : 0)), scheduledEndAt: ts(at(offset, shift === 'morning' ? 16 : 23, shift === 'morning' ? 30 : 0)),
        outcome: absent ? 'absent' : pendingReview ? 'needsReview' : lateMinutes ? 'workedLate' : 'worked', expected: true, recordId: id, leaveType: null,
        workedMinutes: clockOut ? 455 : 0, lateMinutes, earlyLeaveMinutes: 0, overtimeMinutes: 5,
        breakMinutes: clockOut ? 30 : 0, exceptionCodes: absent ? ['noShow'] : lateMinutes ? ['late'] : [],
        locked: true, version: 1, closedAt: ts(at(offset, 23, 30)), restatedAt: null,
        source: 'scheduleClose', schemaVersion: 1,
      });
    }
  }
  const salmaTodayId = `mock-salma_${compactDayKey(at(0))}_morning`;
  put(`attendance/${salmaTodayId}/events/clock-in`, {
    kind: 'clockIn', actorId: 'mock-salma', actorName: 'Salma Ahmed',
    note: null, data: { source: 'clock', verified: true }, createdAt: ts(at(0, 8, 38)),
  });
  const laylaYesterdayId = `mock-layla_${compactDayKey(at(-1))}_morning`;
  put(`attendance/${laylaYesterdayId}/events/clock-in`, {
    kind: 'clockIn', actorId: 'mock-layla', actorName: 'Layla Mostafa',
    note: null, data: { source: 'clock', verified: true }, createdAt: ts(at(-1, 8, 30)),
  });
  put(`attendance/${laylaYesterdayId}/events/clock-out`, {
    kind: 'clockOut', actorId: 'mock-layla', actorName: 'Layla Mostafa',
    note: 'Shift completed', data: { workedMinutes: 455 }, createdAt: ts(at(-1, 16, 35)),
  });
  const reviewWeekKey = compactDayKey(weekStart);
  put(`attendance_week_reviews/branch-downtown_${reviewWeekKey}`, {
    branchId: 'branch-downtown', weekStartKey: reviewWeekKey,
    reviewedBy: 'mock-manager-downtown', reviewedByName: 'Omar Hassan',
    reviewedAt: ts(at(-1, 19)), note: 'Daily records and exceptions reviewed.',
  });
  const correctionAttendanceId = `mock-youssef_${compactDayKey(at(-3))}_night`;
  put('attendance_corrections/mock-correction-pending', {
    id: 'mock-correction-pending', attendanceId: correctionAttendanceId, userId: 'mock-youssef', userName: 'Youssef Ali',
    branchId: 'branch-downtown', shift: 'night', date: ts(at(-3, 0)), requestedBy: 'mock-youssef', requestedByName: 'Youssef Ali',
    kind: 'missingClockOut', status: 'pending', reason: 'The app closed before my clock-out was saved.',
    scheduledStart: ts(at(-3, 15)), scheduledEnd: ts(at(-3, 23)), proposedClockIn: null, proposedClockOut: ts(at(-3, 23, 7)),
    proposedStatus: 'completed', resolution: null, decidedBy: null, decidedByName: null, decidedAt: null,
    decisionNote: null, createdAt: ts(at(-2, 10)), updatedAt: ts(at(-2, 10)), deletedAt: null,
  });

  const requests = [
    ['mock-request-stock', 1042, 'REQ-001042', 'stockRequest', 'pending', 'mock-salma', 'Salma Ahmed', 'Need 12 units of the new display item from Maadi.', null],
    ['mock-request-maintenance', 1041, 'REQ-001041', 'maintenance', 'approved', 'mock-karim', 'Karim Tarek', 'The stockroom light is flickering.', 'Approved; electrician booked for tomorrow.'],
    ['mock-request-leave', 1040, 'REQ-001040', 'leaveStore', 'rejected', 'mock-youssef', 'Youssef Ali', 'Requesting 45 minutes away during the night shift.', 'Coverage is too limited today.'],
  ];
  for (const [id, seq, refCode, type, status, requesterId, requesterName, message, decision] of requests) {
    const decided = status !== 'pending';
    put(`requests/${id}`, {
      id, seq, refCode, branchId: 'branch-downtown', type, status, requesterId, requesterName, requesterRole: 'employee',
      details: { message }, attachments: [], lastEventPreview: decision || message, lastEventAt: ts(at(-1, 11)),
      eventCount: decided ? 2 : 1, decidedBy: decided ? 'mock-manager-downtown' : null,
      decidedByName: decided ? 'Omar Hassan' : null, decidedAt: decided ? ts(at(-1, 11)) : null,
      deletedAt: null, createdAt: ts(at(-2, 13)), updatedAt: ts(at(-1, 11)),
    });
    put(`requests/${id}/events/opened`, { authorId: requesterId, authorName: requesterName, actor: 'requester', kind: 'submitted', text: message, attachments: [], createdAt: ts(at(-2, 13)) });
    if (decided) put(`requests/${id}/events/decision`, { authorId: 'mock-manager-downtown', authorName: 'Omar Hassan', actor: 'approver', kind: status, text: decision, attachments: [], createdAt: ts(at(-1, 11)) });
  }
  put('counters/requests', { value: 1042, updatedAt: updated });

  const cases = [
    ['mock-case-inventory', 'Damaged delivery cartons', 'inventory', 'manager', 'normal', 'inDiscussion', 'mock-salma', 'Salma Ahmed', false],
    ['mock-case-personal', 'Private scheduling concern', 'personal', 'admin', 'confidential', 'open', 'mock-layla', 'Layla Mostafa', true],
    ['mock-case-security', 'Rear entrance camera blind spot', 'security', 'both', 'normal', 'closed', 'mock-karim', 'Karim Tarek', true],
    ['mock-case-response', 'Shift handover process', 'operations', 'manager', 'normal', 'waitingResponse', 'mock-youssef', 'Youssef Ali', false],
  ];
  for (const [id, subject, category, recipient, privacy, status, reporterId, reporterName, urgent] of cases) {
    const description = `${subject}. Please review the details and advise on the next operational step.`;
    put(`cases/${id}`, {
      id, branchId: 'branch-downtown', subject, description, category, recipient, privacy, urgent, status,
      visibleToManager: recipient !== 'admin', reporterDisplayName: privacy === 'normal' ? reporterName : null,
      attachments: [], lastMessagePreview: status === 'closed' ? 'Resolved and documented.' : 'I have added the relevant details.',
      lastMessageAt: ts(at(-1, 14)), messageCount: 2, createdAt: ts(at(-3, 10)), updatedAt: ts(at(-1, 14)),
      closedAt: status === 'closed' ? ts(at(-1, 14)) : null,
    });
    put(`cases/${id}/reporter/identity`, { caseId: id, createdByUserId: reporterId, createdByName: reporterName, privacy, branchId: 'branch-downtown', createdAt: ts(at(-3, 10)) });
    put(`cases/${id}/messages/opening`, { authorId: privacy === 'normal' ? reporterId : '', authorName: privacy === 'normal' ? reporterName : 'Confidential Sender', authorRole: 'reporter', kind: 'opening', text: description, attachments: [], systemEvent: null, createdAt: ts(at(-3, 10)) });
    put(`cases/${id}/messages/reply`, { authorId: recipient === 'admin' ? 'mock-admin' : 'mock-manager-downtown', authorName: recipient === 'admin' ? 'Nour El-Sayed' : 'Omar Hassan', authorRole: 'recipient', kind: 'message', text: status === 'closed' ? 'Resolved and documented.' : 'Thanks. I am reviewing this now.', attachments: [], systemEvent: null, createdAt: ts(at(-1, 14)) });
  }

  const nowMonth = monthKey(new Date());
  for (const [branchId, target] of [['branch-downtown', 48000000], ['branch-maadi', 36000000]]) {
    put(`branch_sales_months/${branchId}_${nowMonth}`, {
      id: `${branchId}_${nowMonth}`, branchId, monthKey: nowMonth, timeZone: 'Africa/Cairo', targetPiastres: target,
      targetRevision: 2, createdAt: ts(at(-25)), updatedAt: ts(at(-7)), createdById: 'mock-admin', createdByName: 'Nour El-Sayed',
      createdByRole: 'admin', updatedById: 'mock-admin', updatedByName: 'Nour El-Sayed', updatedByRole: 'admin',
      lastChangeReason: 'Adjusted to the current monthly forecast.', schemaVersion: 1,
    });
    for (let offset = -12; offset <= -1; offset += 1) {
      const date = at(offset);
      const key = compactDayKey(date);
      const approved = offset !== -2 && offset !== -3;
      const status = offset === -2 ? 'pending' : offset === -3 ? 'rejected' : 'approved';
      put(`branch_sales_submissions/${branchId}_${key}`, {
        id: `${branchId}_${key}`, branchId, monthKey: nowMonth, businessDateKey: dayKey(date), businessTimeZone: 'Africa/Cairo',
        amountPiastres: (branchId === 'branch-downtown' ? 1550000 : 1120000) + (Math.abs(offset) % 4) * 85000,
        status, revision: 1, approvedRevision: approved ? 1 : null,
        submittedById: branchId === 'branch-downtown' ? 'mock-manager-downtown' : 'mock-manager-maadi',
        submittedByName: branchId === 'branch-downtown' ? 'Omar Hassan' : 'Mariam Adel', submittedAt: ts(at(offset, 21)),
        lastEditedById: null, lastEditedByName: null, lastEditedAt: null,
        decisionById: status === 'pending' ? null : 'mock-admin', decisionByName: status === 'pending' ? null : 'Nour El-Sayed',
        decisionByRole: status === 'pending' ? null : 'admin', decisionAt: status === 'pending' ? null : ts(at(offset + 1, 9)),
        decisionReason: status === 'approved' ? 'Daily close verified.' : status === 'rejected' ? 'Receipt total does not match the close.' : null,
        createdAt: ts(at(offset, 21)), updatedAt: ts(at(offset + 1, 9)), schemaVersion: 1,
      });
    }
  }

  put('broadcastTemplates/mock-template-opening-hours', { id: 'mock-template-opening-hours', title: 'Opening hours update', message: 'Tomorrow’s operating hours are {{hours}}. Please acknowledge before your shift.', category: 'announcement', ownerId: 'mock-admin', branchId: '', isFavorite: true, usageCount: 5, createdAt: created, updatedAt: updated });
  put('broadcasts/mock-broadcast-all', { id: 'mock-broadcast-all', title: 'Monthly operations focus', message: 'This week we are focusing on customer handoff quality and accurate closing notes.', senderId: 'mock-admin', senderName: 'Nour El-Sayed', senderRole: 'admin', audience: 'allBranches', branchId: '', targetUserId: '', category: 'announcement', sendsPush: false, recipientCount: 9, deliveredCount: 9, archivedAt: null, createdAt: ts(at(-2, 8)) });
  put('broadcasts/mock-broadcast-branch', { id: 'mock-broadcast-branch', title: 'Downtown stock delivery', message: 'The delivery arrives at 14:00. Keep the rear access clear.', senderId: 'mock-manager-downtown', senderName: 'Omar Hassan', senderRole: 'manager', audience: 'branch', branchId: 'branch-downtown', targetUserId: '', category: 'reminder', sendsPush: true, recipientCount: 4, deliveredCount: 4, archivedAt: null, createdAt: ts(at(-1, 10)) });
  put('broadcastSchedules/mock-schedule-weekly', { id: 'mock-schedule-weekly', title: 'Weekly standards reminder', message: 'Review your schedule and active tasks before Sunday opening.', category: 'reminder', sendsPush: true, audience: 'branch', branchId: 'branch-downtown', roleFilter: 'all', targetUserIds: [], senderId: 'mock-manager-downtown', senderName: 'Omar Hassan', senderRole: 'manager', recurrenceType: 'weekly', interval: 1, startDate: ts(at(-30)), endDate: ts(at(60)), nextRunAt: ts(at(4, 8)), enabled: true, lastRunAt: ts(at(-3, 8)), runCount: 4, createdAt: created });

  const notifications = [
    ['mock-note-task', 'mock-salma', 'taskAssigned', 'New task assigned', 'Opening floor readiness', { route: '/tasks/mock-task-open', taskId: 'mock-task-open' }, null],
    ['mock-note-overdue', 'mock-youssef', 'taskOverdue', 'Task overdue', 'Update shelf price labels is past its deadline.', { route: '/tasks/mock-task-overdue', taskId: 'mock-task-overdue' }, null],
    ['mock-note-request', 'mock-karim', 'requestApproved', 'Request approved', 'Your maintenance request was approved.', { route: '/requests/mock-request-maintenance', requestId: 'mock-request-maintenance' }, ts(at(-1, 12))],
    ['mock-note-broadcast', 'mock-salma', 'broadcastReminder', 'Downtown stock delivery', 'The delivery arrives at 14:00.', { route: '/communications/mock-broadcast-branch', broadcastId: 'mock-broadcast-branch' }, null],
    ['mock-note-manager-review', 'mock-manager-downtown', 'taskSubmitted', 'Task ready for review', 'Layla submitted Verify closing cash count.', { route: '/tasks/mock-task-cash', taskId: 'mock-task-cash' }, null],
  ];
  for (const [id, recipientUid, type, title, body, payload, readAt] of notifications) {
    put(`notifications/${id}`, { id, recipientUid, senderUid: 'mock-manager-downtown', type, title, body, payload, readAt, archivedAt: null, pinnedAt: type === 'taskOverdue' ? updated : null, createdAt: ts(at(-1, 12)) });
  }

  put('reminderConfig/global', {
    enabled: true, quietStartHour: 22, quietEndHour: 7, maxReminders: 3,
    updatedAt: updated, updatedBy: 'mock-admin',
  });
  put('taskReminders/mock-task-overdue', {
    taskId: 'mock-task-overdue', lastKind: 'overdue', count: 3,
    lastSentAt: ts(at(-1, 9)),
  });
  put('taskReminders/mock-task-open', {
    taskId: 'mock-task-open', lastKind: 'due1h', count: 1,
    lastSentAt: ts(at(0, 17)),
  });
  put('usageStats/feed', {
    preset_overdue: 18, sort_smart: 43, expansion_open: 71,
    quick_approve: 12, note_create: 9, updatedAt: updated,
  });

  put('audit_logs/mock-audit-task-approved', { eventType: 'task.approved', actorId: 'mock-manager-downtown', actorName: 'Omar Hassan', actorRole: 'manager', branchId: 'branch-downtown', entityType: 'task', entityId: 'mock-task-approved', metadata: { source: 'mock-seed', summary: 'Approved Safety walkthrough' }, schemaVersion: 1, isDeleted: false, timestamp: ts(at(-1, 18)) });
  put('automationRuns/mock-recurring-close_latest', { id: 'mock-recurring-close_latest', templateId: 'mock-recurring-close', automationName: 'Night close', version: 1, dateKey: dayKey(at(-1)), executionId: 'mock-execution-close', correlationId: 'mock-run-close', status: 'completed', outcome: 'created', branchId: 'branch-downtown', startedAt: ts(at(-1, 16)), finishedAt: ts(at(-1, 16, 1)), durationMs: 1120, trigger: 'schedule', retryCount: 0, schedule: { scheduledAt: ts(at(-1, 16)), actualAt: ts(at(-1, 16)), delayMs: 0, shift: 'night', day: dayKey(at(-1)) }, validations: [{ name: 'branchFound', result: 'pass' }, { name: 'employeesFound', result: 'pass' }], target: { uids: ['mock-youssef', 'mock-karim'], names: ['Youssef Ali', 'Karim Tarek'], count: 2, matched: true }, generation: { templateVersion: 1, checklistCount: 1, priority: 'high' }, generated: { taskIds: ['mock-task-missed'], titles: ['Night refrigeration log'], skippedCount: 0 }, notification: { sent: 2, failed: 0, notificationIds: [] }, logs: [{ at: ts(at(-1, 16)), stage: 'complete', severity: 'info', message: 'Task generated', meta: null }], createdAt: ts(at(-1, 16)) });
  return docs;
}

async function seedAuth(auth) {
  for (const [uid, email, displayName] of users) {
    try {
      await auth.updateUser(uid, { email, password: PASSWORD, displayName, emailVerified: true, disabled: false });
    } catch (error) {
      if (error.code !== 'auth/user-not-found') throw error;
      await auth.createUser({ uid, email, password: PASSWORD, displayName, emailVerified: true });
    }
  }
}

async function seedFirestore(db, generated) {
  for (let start = 0; start < generated.length; start += 400) {
    const batch = db.batch();
    for (const item of generated.slice(start, start + 400)) {
      batch.set(db.doc(item.path), item.data, { merge: true });
    }
    await batch.commit();
  }
}

async function main() {
  const generated = buildData();
  const counts = generated.reduce((out, item) => {
    const collection = item.path.split('/').filter((_, i) => i % 2 === 0).join('/*/');
    out[collection] = (out[collection] || 0) + 1;
    return out;
  }, {});
  if (dryRun) {
    console.log(JSON.stringify({ projectId, users: users.length, documents: generated.length, collections: counts }, null, 2));
    return;
  }
  if (!process.env.FIRESTORE_EMULATOR_HOST || !process.env.FIREBASE_AUTH_EMULATOR_HOST) {
    throw new Error('Refusing to seed without FIRESTORE_EMULATOR_HOST and FIREBASE_AUTH_EMULATOR_HOST. Start the Firebase Emulator Suite first.');
  }
  initializeApp({ projectId });
  const db = getFirestore();
  db.settings({ ignoreUndefinedProperties: true });
  await seedAuth(getAuth());
  await seedFirestore(db, generated);
  console.log(`Seeded ${users.length} accounts and ${generated.length} documents into Firebase emulators (${projectId}).`);
  console.log(`Login: admin@opshub.test / ${PASSWORD}`);
}

if (require.main === module) {
  main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
  });
}

module.exports = { buildData, users, PASSWORD };
