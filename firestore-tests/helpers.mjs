import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import {
  initializeTestEnvironment,
  assertFails,
  assertSucceeds,
} from "@firebase/rules-unit-testing";
import { doc, setDoc } from "firebase/firestore";

const HERE = path.dirname(fileURLToPath(import.meta.url));

export const RULES = fs.readFileSync(
  path.join(HERE, "..", "firestore.rules"),
  "utf8",
);

/// Boots the emulator-backed environment with the REAL rules file and seeds the
/// three roles the rules resolve via `selfDoc()`.
export async function makeEnv(projectId) {
  const env = await initializeTestEnvironment({
    projectId,
    firestore: { rules: RULES, host: "127.0.0.1", port: 8080 },
  });
  await env.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    await setDoc(doc(db, "users/mgr1"), {
      role: "manager",
      branchId: "branch1",
      isActive: true,
    });
    await setDoc(doc(db, "users/mgr2"), {
      role: "manager",
      branchId: "branch2",
      isActive: true,
    });
    await setDoc(doc(db, "users/admin1"), { role: "admin", isActive: true });
    await setDoc(doc(db, "users/emp1"), {
      role: "employee",
      branchId: "branch1",
      isActive: true,
    });
    await setDoc(doc(db, "users/emp2"), {
      role: "employee",
      branchId: "branch1",
      isActive: true,
    });
  });
  return env;
}

/// A task document **exactly as `TaskModel.toMap()` writes it**: every optional
/// key present, holding an explicit `null`. This shape is the whole point — the
/// 2026-07-28 regression was invisible to any fixture that omitted these keys.
export function currentTask(over = {}) {
  return {
    id: "x",
    title: "Restock the cold case",
    description: null,
    type: "daily",
    workType: "general",
    status: "pending",
    priority: "normal",
    branchId: "branch1",
    assigneeIds: ["emp1"],
    assignedEmployeeId: "emp1",
    checklist: [],
    referenceAttachments: [],
    data: {},
    createdBy: "mgr1",
    assignedShiftId: null,
    shift: null,
    assignmentType: "individual",
    instanceDate: null,
    sourceTemplateId: null,
    recurrenceRootId: null,
    occurrenceKey: null,
    correlationId: null,
    startsAt: null,
    deadline: null,
    missedAt: null,
    cancelledAt: null,
    cancelledBy: null,
    cancelReason: null,
    cancelNote: null,
    reportedIncorrectBy: null,
    reportedIncorrectAt: null,
    reportedIncorrectNote: null,
    notes: null,
    proofImageUrl: null,
    startedAt: null,
    submittedAt: null,
    approvedBy: null,
    approvedAt: null,
    rejectedBy: null,
    rejectedAt: null,
    reviewNotes: null,
    revisionNumber: 0,
    requiresRework: false,
    rejectionReason: null,
    recurrence: null,
    activityLog: [],
    archivedAt: null,
    version: 0,
    ...over,
  };
}

/// A task written **before** the Phase 1–3 fields existed — those keys are
/// absent, not null. Every rule must treat this identically to [currentTask],
/// which is the backwards-compatibility guarantee.
export function legacyTask(over = {}) {
  const t = currentTask(over);
  for (const k of [
    "cancelledAt",
    "cancelledBy",
    "cancelReason",
    "cancelNote",
    "reportedIncorrectBy",
    "reportedIncorrectAt",
    "reportedIncorrectNote",
  ]) {
    if (!(k in over)) delete t[k];
  }
  return t;
}

/// Writes a task straight to the emulator with rules bypassed (fixture setup).
export const seed = (env, id, data) =>
  env.withSecurityRulesDisabled((ctx) =>
    setDoc(doc(ctx.firestore(), `tasks/${id}`), { ...data, id }),
  );

export { assertFails, assertSucceeds };
