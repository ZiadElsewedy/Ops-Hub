import 'dart:io';

import 'package:drop/core/enums/attendance_status.dart';
import 'package:drop/core/enums/request_status.dart';
import 'package:drop/core/errors/exceptions.dart';
import 'package:drop/core/errors/failures.dart';
import 'package:drop/core/network/network_guard.dart';
import 'package:drop/features/attendance/data/datasources/attendance_remote_datasource.dart';
import 'package:drop/features/attendance/data/models/attendance_correction_model.dart';
import 'package:drop/features/attendance/data/models/attendance_model.dart';
import 'package:drop/features/attendance/domain/attendance_calculator.dart';
import 'package:drop/features/attendance/domain/attendance_feed.dart';
import 'package:drop/features/attendance/domain/attendance_gps.dart';
import 'package:drop/features/attendance/domain/attendance_resolution.dart';
import 'package:drop/features/attendance/domain/entities/attendance_correction.dart';
import 'package:drop/features/attendance/domain/entities/attendance_entity.dart';
import 'package:drop/features/attendance/domain/entities/attendance_event.dart';
import 'package:drop/features/attendance/domain/repositories/attendance_repository.dart';

class AttendanceRepositoryImpl implements AttendanceRepository {
  final AttendanceRemoteDataSource _remote;

  AttendanceRepositoryImpl(this._remote);

  /// Models → entities, dropping soft-deleted records (client-side, like the
  /// Requests inbox: a `where(deletedAt, isNull)` query would exclude every doc
  /// missing the field, and per-scope volume is small).
  List<AttendanceEntity> _live(List<AttendanceModel> models) => [
        for (final m in models)
          if (m.deletedAt == null) m.toEntity(),
      ];

  @override
  Future<AttendanceEntity?> getRecord(String id) async {
    try {
      final m = await _remote.getRecord(id);
      if (m == null || m.deletedAt != null) return null;
      return m.toEntity();
    } on ServerException catch (e) {
      throw ServerFailure(e.message);
    }
  }

  @override
  Stream<AttendanceEntity?> watchRecord(String id) => _remote
      .watchRecord(id)
      .map((m) => (m == null || m.deletedAt != null) ? null : m.toEntity());

  @override
  Stream<AttendanceFeed> watchUserHistory(String uid, {int limit = 30}) =>
      _remote.watchUserHistory(uid, limit: limit).map((feed) => AttendanceFeed(
            records: _live(feed.records),
            isOffline: feed.isOffline,
            hasPendingWrites: feed.hasPendingWrites,
          ));

  @override
  Stream<List<AttendanceEntity>> watchBranchDay(String branchId, String dayKey) =>
      _remote.watchBranchDay(branchId, dayKey).map(_live);

  @override
  Stream<List<AttendanceEntity>> watchBranchRange(
          String branchId, String startKey, String endKey) =>
      _remote.watchBranchRange(branchId, startKey, endKey).map(_live);

  @override
  Stream<List<AttendanceEvent>> watchEvents(String id) => _remote.watchEvents(id);

  @override
  Future<void> clockIn(AttendanceEntity record) async {
    // Clock-in is the MOST offline-sensitive write in the app: a Firestore
    // `set` issued with no connection is cached, reported as success, and
    // replayed whenever the network returns — at which point the
    // server-timestamped `clockIn` resolves to the RECONNECT time, not when the
    // person actually clocked in. That silently corrupts pay data while the UI
    // says "clocked in". Fail fast instead so the user knows to reconnect.
    // (The rest of the attendance writes below already guard the same way; these
    // two were the gap.)
    NetworkGuard.ensureWritable();
    try {
      await _remote.clockIn(AttendanceModel.fromEntity(record));
    } on ServerException catch (e) {
      throw ServerFailure(e.message);
    }
  }

  @override
  Future<void> clockOut(
    String id, {
    required DateTime clockOut,
    required AttendanceStatus status,
    required AttendanceTotals totals,
    AttendanceVerification? verification,
  }) async {
    // Same offline hazard as [clockIn] — an offline clock-out would replay with
    // a reconnect-time server timestamp and mis-state worked minutes.
    NetworkGuard.ensureWritable();
    try {
      await _remote.clockOut(
        id,
        ClockOutWrite(
          clockOut: clockOut,
          status: status,
          totals: totals,
          verification: verification,
        ),
      );
    } on ServerException catch (e) {
      throw ServerFailure(e.message);
    }
  }

  @override
  Future<void> softDelete(String id) async {
    try {
      await _remote.softDelete(id);
    } on ServerException catch (e) {
      throw ServerFailure(e.message);
    }
  }

  @override
  Future<String> uploadSelfie({
    required String recordId,
    required File file,
    required String uploadedBy,
  }) async {
    try {
      return await _remote.uploadSelfie(
        recordId: recordId,
        file: file,
        uploadedBy: uploadedBy,
      );
    } on ServerException catch (e) {
      throw ServerFailure(e.message);
    }
  }

  // ── Attendance corrections ──────────────────────────────────────────────
  List<AttendanceCorrectionEntity> _liveCorrections(
          List<AttendanceCorrectionModel> models) =>
      [
        for (final m in models)
          if (m.deletedAt == null) m.toEntity(),
      ];

  @override
  Future<AttendanceCorrectionEntity?> getCorrection(String id) async {
    try {
      final m = await _remote.getCorrection(id);
      if (m == null || m.deletedAt != null) return null;
      return m.toEntity();
    } on ServerException catch (e) {
      throw ServerFailure(e.message);
    }
  }

  @override
  Future<void> requestCorrection(AttendanceCorrectionEntity correction) async {
    NetworkGuard.ensureWritable();
    try {
      await _remote
          .requestCorrection(AttendanceCorrectionModel.fromEntity(correction));
    } on ServerException catch (e) {
      throw ServerFailure(e.message);
    }
  }

  @override
  Future<void> createResolvedCorrection(
      AttendanceCorrectionEntity correction) async {
    NetworkGuard.ensureWritable();
    try {
      await _remote.createResolvedCorrection(
          AttendanceCorrectionModel.fromEntity(correction));
    } on ServerException catch (e) {
      throw ServerFailure(e.message);
    }
  }

  @override
  Future<void> decideCorrection(
    String id, {
    required RequestStatus status,
    required String decidedBy,
    String? decidedByName,
    String? decisionNote,
    AttendanceResolution? resolution,
  }) async {
    NetworkGuard.ensureWritable();
    try {
      await _remote.decideCorrection(
        id,
        CorrectionDecisionWrite(
          status: status,
          decidedBy: decidedBy,
          decidedByName: decidedByName,
          decisionNote: decisionNote,
          resolution: resolution,
        ),
      );
    } on ServerException catch (e) {
      throw ServerFailure(e.message);
    }
  }

  @override
  Stream<List<AttendanceCorrectionEntity>> watchUserCorrections(String uid,
          {int limit = 30}) =>
      _remote.watchUserCorrections(uid, limit: limit).map(_liveCorrections);

  @override
  Stream<List<AttendanceCorrectionEntity>> watchBranchPendingCorrections(
          String branchId) =>
      _remote.watchBranchPendingCorrections(branchId).map(_liveCorrections);

  @override
  Stream<List<AttendanceCorrectionEntity>> watchRecordCorrections(
          String attendanceId) =>
      _remote.watchRecordCorrections(attendanceId).map(_liveCorrections);
}
