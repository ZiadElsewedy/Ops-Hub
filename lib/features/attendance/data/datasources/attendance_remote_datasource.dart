import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:drop/core/constants/app_constants.dart';
import 'package:drop/core/enums/attendance_status.dart';
import 'package:drop/core/enums/request_status.dart';
import 'package:drop/core/errors/exceptions.dart';
import 'package:drop/features/attendance/data/models/attendance_correction_model.dart';
import 'package:drop/features/attendance/data/models/attendance_model.dart';
import 'package:drop/features/attendance/domain/attendance_calculator.dart';
import 'package:drop/features/attendance/domain/attendance_gps.dart';
import 'package:drop/features/attendance/domain/attendance_resolution.dart';
import 'package:drop/features/attendance/domain/entities/attendance_event.dart';

/// A history snapshot as it leaves the datasource — the models plus the raw
/// Firestore sync metadata (mapped to `AttendanceFeed` by the repository).
typedef AttendanceModelFeed = ({
  List<AttendanceModel> records,
  bool isOffline,
  bool hasPendingWrites,
});

/// The fields written at clock-out. [totals] is carried for the caller's UI
/// feedback but is **not** persisted by the datasource — payroll minutes are
/// computed server-side (`onAttendanceWritten`) and the client is forbidden by
/// rules from writing them (ADR-024).
class ClockOutWrite {
  final DateTime clockOut;
  final AttendanceStatus status;
  final AttendanceTotals totals;

  /// The GPS verification captured at clock-out (persisted on
  /// `clockOutVerification`).
  final AttendanceVerification? verification;

  const ClockOutWrite({
    required this.clockOut,
    required this.status,
    required this.totals,
    this.verification,
  });
}

/// Client data access for `attendance/{id}`.
///
/// **Audit is server-side.** Clock actions here are plain **record writes**; the
/// immutable audit trail in `attendance/{id}/events` is derived by an Admin-SDK
/// Cloud Function (mirroring `onRequestCreated`/`onRequestUpdated`), so clients
/// can't forge or mutate audit events — exactly the "reuse the existing audit
/// pattern, not a parallel system" contract. The client only *reads* the trail
/// ([watchEvents]).
abstract class AttendanceRemoteDataSource {
  /// A direct one-shot read of the deterministic-id record ("today"). No query.
  Future<AttendanceModel?> getRecord(String id);

  /// Realtime stream of one record doc (the live session).
  Stream<AttendanceModel?> watchRecord(String id);

  /// A user's own history, newest day first ([limit] most recent), carrying the
  /// snapshot's offline / pending-write metadata.
  Stream<AttendanceModelFeed> watchUserHistory(String uid, {int limit});

  /// Every record in [branchId] on the single [dayKey] — the manager live board
  /// (bounded to one day; served by the `branchId + dayKey` index).
  Stream<List<AttendanceModel>> watchBranchDay(String branchId, String dayKey);

  /// Every record in [branchId] over the inclusive `dayKey` range
  /// `[startKey, endKey]` — the bounded window the admin analytics reads.
  Stream<List<AttendanceModel>> watchBranchRange(
      String branchId, String startKey, String endKey);

  /// The record's server-written, append-only audit trail, oldest first.
  Stream<List<AttendanceEvent>> watchEvents(String id);

  /// Clock in — idempotent `set(merge)` of the record on its deterministic id
  /// (a double-tap / offline replay overwrites the same doc, never duplicates).
  Future<void> clockIn(AttendanceModel record);

  /// Clock out — writes the finalized fields + the minute snapshot.
  Future<void> clockOut(String id, ClockOutWrite write);

  /// Soft-delete a record (admin) — stamps `deletedAt`; the doc stays as history.
  Future<void> softDelete(String id);

  /// Upload a clock-in selfie to `attendance/{recordId}/selfie/{id}.<ext>` and
  /// return its download URL. Optional (only when the branch requires a photo).
  Future<String> uploadSelfie({
    required String recordId,
    required File file,
    required String uploadedBy,
  });

  // ── Attendance corrections (`attendance_corrections/{id}`) ──────────────
  Future<AttendanceCorrectionModel?> getCorrection(String id);

  /// File a correction (auto id, status `pending`, server timestamps).
  Future<void> requestCorrection(AttendanceCorrectionModel correction);

  /// Create a correction **already `approved`** (a manager's direct *Add record*
  /// / *Resolve*) — auto id, carries the resolution + decision stamps + server
  /// timestamps. The Cloud Function's create branch applies it to the record
  /// immediately (materializing it if absent), with no reviewer step.
  Future<void> createResolvedCorrection(AttendanceCorrectionModel correction);

  /// Persist a reviewer's decision (status + stamps + the applied [resolution]).
  Future<void> decideCorrection(String id, CorrectionDecisionWrite write);

  Stream<List<AttendanceCorrectionModel>> watchUserCorrections(String uid,
      {int limit});

  Stream<List<AttendanceCorrectionModel>> watchBranchPendingCorrections(
      String branchId);

  Stream<List<AttendanceCorrectionModel>> watchRecordCorrections(
      String attendanceId);
}

/// The decision fields written when a reviewer approves/rejects a correction.
class CorrectionDecisionWrite {
  final RequestStatus status;
  final String decidedBy;
  final String? decidedByName;
  final String? decisionNote;

  /// The applied snapshot (approve only) the Cloud Function copies onto the
  /// record; null on a reject.
  final AttendanceResolution? resolution;

  const CorrectionDecisionWrite({
    required this.status,
    required this.decidedBy,
    this.decidedByName,
    this.decisionNote,
    this.resolution,
  });
}

class AttendanceRemoteDataSourceImpl implements AttendanceRemoteDataSource {
  final FirebaseFirestore _firestore;
  final FirebaseStorage _storage;

  AttendanceRemoteDataSourceImpl(this._firestore, this._storage);

  static const String _eventsSub = 'events';

  CollectionReference<Map<String, dynamic>> get _records =>
      _firestore.collection(AppConstants.attendanceCollection);

  CollectionReference<Map<String, dynamic>> get _corrections =>
      _firestore.collection(AppConstants.attendanceCorrectionsCollection);

  DocumentReference<Map<String, dynamic>> _record(String id) => _records.doc(id);

  CollectionReference<Map<String, dynamic>> _events(String id) =>
      _record(id).collection(_eventsSub);

  List<AttendanceModel> _mapSnap(QuerySnapshot<Map<String, dynamic>> snap) =>
      snap.docs.map((d) => AttendanceModel.fromMap(d.data(), id: d.id)).toList();

  List<AttendanceCorrectionModel> _mapCorrections(
          QuerySnapshot<Map<String, dynamic>> snap) =>
      snap.docs
          .map((d) => AttendanceCorrectionModel.fromMap(d.data(), id: d.id))
          .toList();

  @override
  Future<AttendanceModel?> getRecord(String id) async {
    try {
      final doc = await _record(id).get();
      if (!doc.exists || doc.data() == null) return null;
      return AttendanceModel.fromMap(doc.data()!, id: doc.id);
    } on FirebaseException catch (e) {
      throw ServerException(e.message ?? 'Failed to load attendance.');
    }
  }

  @override
  Stream<AttendanceModel?> watchRecord(String id) =>
      _record(id).snapshots().map((doc) => (!doc.exists || doc.data() == null)
          ? null
          : AttendanceModel.fromMap(doc.data()!, id: doc.id));

  @override
  Stream<AttendanceModelFeed> watchUserHistory(String uid, {int limit = 30}) =>
      _records
          .where('userId', isEqualTo: uid)
          .orderBy('date', descending: true)
          .limit(limit)
          // Metadata changes so the cubit can surface offline / syncing honestly
          // (the local write lands first, then the server ack clears pending).
          .snapshots(includeMetadataChanges: true)
          .map((snap) => (
                records: _mapSnap(snap),
                isOffline: snap.metadata.isFromCache,
                hasPendingWrites: snap.metadata.hasPendingWrites,
              ));

  @override
  Stream<List<AttendanceModel>> watchBranchDay(String branchId, String dayKey) =>
      _records
          .where('branchId', isEqualTo: branchId)
          .where('dayKey', isEqualTo: dayKey)
          .snapshots()
          .map(_mapSnap);

  @override
  Stream<List<AttendanceModel>> watchBranchRange(
          String branchId, String startKey, String endKey) =>
      _records
          .where('branchId', isEqualTo: branchId)
          .where('dayKey', isGreaterThanOrEqualTo: startKey)
          .where('dayKey', isLessThanOrEqualTo: endKey)
          .snapshots()
          .map(_mapSnap);

  @override
  Stream<List<AttendanceEvent>> watchEvents(String id) => _events(id)
      .orderBy('createdAt', descending: false)
      .snapshots()
      .map((snap) => snap.docs
          .map((d) => AttendanceModel.eventFromMap(d.data(), id: d.id))
          .toList());

  @override
  Future<void> clockIn(AttendanceModel record) async {
    try {
      await _record(record.id).set(
        {
          ...record.toCreateMap(),
          // Server-authoritative clock time (overrides the client value in the
          // create payload) — the honest record of when the backend saw it.
          'clockIn': FieldValue.serverTimestamp(),
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    } on FirebaseException catch (e) {
      throw ServerException(e.message ?? 'Failed to clock in.');
    }
  }

  @override
  Future<void> clockOut(String id, ClockOutWrite write) async {
    try {
      await _record(id).update({
        // Server-authoritative clock-out time.
        'clockOut': FieldValue.serverTimestamp(),
        'status': write.status.value,
        // Worked / late / early / overtime minutes are intentionally NOT written
        // here. They feed payroll, so they are computed by the Admin SDK in
        // `onAttendanceWritten` and firestore.rules forbid a client from writing
        // any minute field — the client must not be able to choose its own pay
        // (ADR-024). The UI shows live minutes via `AttendanceCalculator` until
        // the server snapshot lands (usually within a second; on the next sync
        // when offline), so nothing on screen waits for this.
        'clockOutVerification':
            AttendanceModel.verificationToMap(write.verification),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } on FirebaseException catch (e) {
      throw ServerException(e.message ?? 'Failed to clock out.');
    }
  }

  @override
  Future<void> softDelete(String id) async {
    try {
      await _record(id).update({
        'deletedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } on FirebaseException catch (e) {
      throw ServerException(e.message ?? 'Failed to delete the record.');
    }
  }

  // ── Attendance corrections ──────────────────────────────────────────────
  @override
  Future<AttendanceCorrectionModel?> getCorrection(String id) async {
    try {
      final doc = await _corrections.doc(id).get();
      if (!doc.exists || doc.data() == null) return null;
      return AttendanceCorrectionModel.fromMap(doc.data()!, id: doc.id);
    } on FirebaseException catch (e) {
      throw ServerException(e.message ?? 'Failed to load the correction.');
    }
  }

  @override
  Future<void> requestCorrection(AttendanceCorrectionModel correction) async {
    try {
      // Auto id (a correction isn't idempotent on a natural key — an employee may
      // file more than one against the same record over time).
      final ref = correction.id.isEmpty
          ? _corrections.doc()
          : _corrections.doc(correction.id);
      final payload = AttendanceCorrectionModel.fromEntity(
        correction.toEntity(),
      ).toCreateMap();
      await ref.set({
        ...payload,
        'id': ref.id,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } on FirebaseException catch (e) {
      throw ServerException(e.message ?? 'Failed to file the correction.');
    }
  }

  @override
  Future<void> createResolvedCorrection(
      AttendanceCorrectionModel correction) async {
    try {
      final ref = correction.id.isEmpty
          ? _corrections.doc()
          : _corrections.doc(correction.id);
      final payload = AttendanceCorrectionModel.fromEntity(
        correction.toEntity(),
      ).toResolvedCreateMap();
      await ref.set({
        ...payload,
        'id': ref.id,
        'decidedAt': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } on FirebaseException catch (e) {
      throw ServerException(e.message ?? 'Failed to save the record.');
    }
  }

  @override
  Future<void> decideCorrection(String id, CorrectionDecisionWrite write) async {
    try {
      await _corrections.doc(id).update({
        'status': write.status.value,
        'decidedBy': write.decidedBy,
        'decidedByName': write.decidedByName,
        'decisionNote': write.decisionNote,
        'decidedAt': FieldValue.serverTimestamp(),
        'resolution':
            AttendanceCorrectionModel.resolutionToMap(write.resolution),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } on FirebaseException catch (e) {
      throw ServerException(e.message ?? 'Failed to save the decision.');
    }
  }

  @override
  Stream<List<AttendanceCorrectionModel>> watchUserCorrections(String uid,
          {int limit = 30}) =>
      _corrections
          .where('userId', isEqualTo: uid)
          .orderBy('createdAt', descending: true)
          .limit(limit)
          .snapshots()
          .map(_mapCorrections);

  @override
  Stream<List<AttendanceCorrectionModel>> watchBranchPendingCorrections(
          String branchId) =>
      _corrections
          .where('branchId', isEqualTo: branchId)
          .where('status', isEqualTo: RequestStatus.pending.value)
          .orderBy('createdAt', descending: true)
          .snapshots()
          .map(_mapCorrections);

  @override
  Stream<List<AttendanceCorrectionModel>> watchRecordCorrections(
          String attendanceId) =>
      _corrections
          .where('attendanceId', isEqualTo: attendanceId)
          .orderBy('createdAt', descending: false)
          .snapshots()
          .map(_mapCorrections);

  static const _uploadTimeout = Duration(seconds: 120);

  @override
  Future<String> uploadSelfie({
    required String recordId,
    required File file,
    required String uploadedBy,
  }) async {
    final attId = _records.doc().id; // guaranteed-unique id
    final ext = _extensionFor(file.path);
    final upload = _storage
        .ref('${AppConstants.attendanceCollection}/$recordId/selfie/$attId.$ext')
        .putFile(file, SettableMetadata(contentType: _contentType(ext)));
    try {
      final snapshot = await upload.timeout(
        _uploadTimeout,
        onTimeout: () {
          upload.cancel();
          throw const ServerException(
              'Selfie upload timed out. Check your connection and try again.');
        },
      );
      return await snapshot.ref.getDownloadURL().timeout(const Duration(seconds: 30));
    } on TimeoutException {
      throw const ServerException(
          'Selfie upload timed out. Check your connection and try again.');
    } on FirebaseException catch (e) {
      throw ServerException(_storageError(e));
    }
  }

  static String _extensionFor(String path) {
    final dot = path.lastIndexOf('.');
    if (dot != -1 && dot < path.length - 1) {
      final ext = path.substring(dot + 1).toLowerCase();
      if (ext.isNotEmpty && ext.length <= 5) return ext;
    }
    return 'jpg';
  }

  static String _contentType(String ext) {
    switch (ext) {
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      case 'heic':
        return 'image/heic';
      default:
        return 'image/jpeg';
    }
  }

  static String _storageError(FirebaseException e) {
    switch (e.code) {
      case 'unauthorized':
      case 'unauthenticated':
        return 'Selfie upload was blocked by Storage permissions (${e.code}). '
            'Storage rules likely need to be deployed.';
      case 'object-not-found':
      case 'bucket-not-found':
      case 'project-not-found':
        return 'Firebase Storage isn\'t set up for this project (${e.code}).';
      default:
        return e.message ?? 'Selfie upload failed (${e.code}).';
    }
  }
}
