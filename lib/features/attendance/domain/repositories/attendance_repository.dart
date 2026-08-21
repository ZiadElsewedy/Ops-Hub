import 'dart:io';

import 'package:opshub/core/enums/attendance_status.dart';
import 'package:opshub/core/enums/request_status.dart';
import 'package:opshub/features/attendance/domain/attendance_calculator.dart';
import 'package:opshub/features/attendance/domain/attendance_gps.dart';
import 'package:opshub/features/attendance/domain/attendance_feed.dart';
import 'package:opshub/features/attendance/domain/attendance_resolution.dart';
import 'package:opshub/features/attendance/domain/entities/attendance_correction.dart';
import 'package:opshub/features/attendance/domain/entities/attendance_entity.dart';
import 'package:opshub/features/attendance/domain/entities/attendance_event.dart';

/// Contract for attendance data access. Branch/role access is enforced
/// server-side by `firestore.rules` (`attendance/{id}`): an employee reads +
/// clocks their own records; a manager reads/reviews their branch; an admin sees
/// all. Reads are deliberately cheap — "today" is a direct doc read (deterministic
/// id), history and the branch board are single bounded queries.
abstract class AttendanceRepository {
  /// One-shot read of a record by its deterministic id ("today").
  Future<AttendanceEntity?> getRecord(String id);

  /// Realtime stream of one record (the live session). Emits null when the record
  /// is absent or soft-deleted.
  Stream<AttendanceEntity?> watchRecord(String id);

  /// A user's own history, newest first ([limit] most recent), soft-deletes
  /// filtered out — plus the snapshot's offline / pending-write sync state (the
  /// single stream that drives the whole employee clock surface).
  Stream<AttendanceFeed> watchUserHistory(String uid, {int limit});

  /// A branch's records for a single [dayKey] (`yyyyMMdd`) — the manager live
  /// board.
  Stream<List<AttendanceEntity>> watchBranchDay(String branchId, String dayKey);

  /// A branch's records over an inclusive `dayKey` range — the admin analytics
  /// window.
  Stream<List<AttendanceEntity>> watchBranchRange(
      String branchId, String startKey, String endKey);

  /// A record's server-written, append-only audit trail, oldest first.
  Stream<List<AttendanceEvent>> watchEvents(String id);

  /// Clock in: writes the record (idempotent on its deterministic id). The
  /// `clockedIn` audit event is derived server-side.
  Future<void> clockIn(AttendanceEntity record);

  /// Clock out: writes the finalized fields + minute [totals] snapshot. [totals]
  /// come from [AttendanceCalculator] — the single source of that math; this is
  /// the one place they're persisted.
  Future<void> clockOut(
    String id, {
    required DateTime clockOut,
    required AttendanceStatus status,
    required AttendanceTotals totals,
    AttendanceVerification? verification,
  });

  /// Soft-delete a record (admin) — stamps `deletedAt`; the record stays as
  /// history.
  Future<void> softDelete(String id);

  /// Upload a clock-in selfie and return its download URL.
  Future<String> uploadSelfie({
    required String recordId,
    required File file,
    required String uploadedBy,
  });

  // ── Attendance corrections (`attendance_corrections/{id}`) ──────────────
  // The client only writes the correction doc; on approval the
  // `onAttendanceCorrectionWritten` Cloud Function applies [decideCorrection]'s
  // [AttendanceResolution] onto the parent record and writes the audit event.

  /// One-shot read of a correction by id.
  Future<AttendanceCorrectionEntity?> getCorrection(String id);

  /// File a correction (the employee, for their own record — status `pending`).
  Future<void> requestCorrection(AttendanceCorrectionEntity correction);

  /// A manager's **direct action** — *Add record* (materialize a missing/absent
  /// shift) or *Resolve* a `pendingReview` record — as a correction born
  /// `approved` with its [AttendanceCorrectionEntity.resolution] already computed
  /// (through `AttendanceResolution.fromRecord`, the single minute-math source).
  /// The Cloud Function applies it to the record immediately; no reviewer step.
  Future<void> createResolvedCorrection(AttendanceCorrectionEntity correction);

  /// Record a reviewer's decision. On approve, [resolution] carries the settled
  /// clock times + minute snapshot (computed by `DecideCorrection` through
  /// `AttendanceCalculator`); the Cloud Function copies it onto the record.
  Future<void> decideCorrection(
    String id, {
    required RequestStatus status,
    required String decidedBy,
    String? decidedByName,
    String? decisionNote,
    AttendanceResolution? resolution,
  });

  /// A user's own corrections, newest first (soft-deletes filtered out).
  Stream<List<AttendanceCorrectionEntity>> watchUserCorrections(String uid,
      {int limit});

  /// A branch's still-**pending** corrections — the reviewer's queue.
  Stream<List<AttendanceCorrectionEntity>> watchBranchPendingCorrections(
      String branchId);

  /// Every correction filed against one attendance record, oldest first.
  Stream<List<AttendanceCorrectionEntity>> watchRecordCorrections(
      String attendanceId);
}
