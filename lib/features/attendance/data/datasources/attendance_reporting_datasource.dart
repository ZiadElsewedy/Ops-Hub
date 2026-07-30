import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:drop/core/constants/app_constants.dart';
import 'package:drop/core/errors/exceptions.dart';
import 'package:drop/features/attendance/data/models/attendance_ledger_model.dart';

abstract class AttendanceReportingDataSource {
  Stream<List<AttendanceLedgerModel>> watchBranchLedgerRange({
    required String branchId,
    required String startDayKey,
    required String endDayKey,
  });

  Stream<List<AttendanceLedgerModel>> watchUserLedgerRange({
    required String userId,
    required String startDayKey,
    required String endDayKey,
  });
}

class AttendanceReportingDataSourceImpl
    implements AttendanceReportingDataSource {
  AttendanceReportingDataSourceImpl(this._firestore);

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _rows =>
      _firestore.collection(AppConstants.attendanceExpectationsCollection);

  List<AttendanceLedgerModel> _mapSnap(
    QuerySnapshot<Map<String, dynamic>> snap,
  ) => snap.docs
      .map((doc) => AttendanceLedgerModel.fromMap(doc.data(), id: doc.id))
      .toList();

  @override
  Stream<List<AttendanceLedgerModel>> watchBranchLedgerRange({
    required String branchId,
    required String startDayKey,
    required String endDayKey,
  }) {
    try {
      return _rows
          .where('branchId', isEqualTo: branchId)
          .where('dayKey', isGreaterThanOrEqualTo: startDayKey)
          .where('dayKey', isLessThanOrEqualTo: endDayKey)
          .orderBy('dayKey')
          .snapshots()
          .map(_mapSnap);
    } on FirebaseException catch (e) {
      throw ServerException(e.message ?? 'Failed to load attendance report.');
    }
  }

  @override
  Stream<List<AttendanceLedgerModel>> watchUserLedgerRange({
    required String userId,
    required String startDayKey,
    required String endDayKey,
  }) {
    try {
      return _rows
          .where('userId', isEqualTo: userId)
          .where('dayKey', isGreaterThanOrEqualTo: startDayKey)
          .where('dayKey', isLessThanOrEqualTo: endDayKey)
          .orderBy('dayKey')
          .snapshots()
          .map(_mapSnap);
    } on FirebaseException catch (e) {
      throw ServerException(e.message ?? 'Failed to load attendance report.');
    }
  }
}
