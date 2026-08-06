import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:drop/core/constants/app_constants.dart';
import 'package:drop/core/utils/app_logger.dart';
import 'package:drop/core/enums/leave_type.dart';
import 'package:drop/core/enums/schedule_day.dart';
import 'package:drop/core/enums/schedule_shift.dart';
import 'package:drop/core/enums/swap_status.dart';
import 'package:drop/core/errors/exceptions.dart';
import 'package:drop/features/schedule/data/models/shift_swap_model.dart';
import 'package:drop/features/schedule/data/models/weekly_schedule_model.dart';
import 'package:drop/features/schedule/domain/schedule_week.dart';
import 'package:drop/features/schedule/domain/shift_hours.dart';
import 'package:drop/features/schedule/domain/shift_plan.dart';

/// Firestore access for the weekly schedule + shift swaps (Phase 7). Schedules
/// live at `weekly_schedules/{branchId_yyyy-MM-dd}` (deterministic id → one doc
/// per branch+week, addressed without a query). Swaps live at `shift_swaps/{id}`.
/// Branch/role access is enforced server-side in `firestore.rules`.
abstract class ScheduleRemoteDataSource {
  // ── Weekly schedules ──
  Future<WeeklyScheduleModel?> getSchedule(String branchId, DateTime weekStart);

  /// [getSchedule], but answered from the on-device Firestore cache when the
  /// week's document is already there, falling back to the server on a miss.
  ///
  /// For callers that need the roster *now* and can tolerate it being one read
  /// stale — today only `TaskCubit`, which uses it to bind shift task streams
  /// without waiting on a network round trip, then reconciles against the
  /// server. **Not a general replacement for [getSchedule]:** anything that
  /// displays or edits the roster must keep reading server-first.
  Future<WeeklyScheduleModel?> getScheduleCacheFirst(
    String branchId,
    DateTime weekStart,
  );
  Future<List<WeeklyScheduleModel>> getBranchSchedules(String branchId);
  Future<List<WeeklyScheduleModel>> getAllSchedules();
  Future<WeeklyScheduleModel> createSchedule(WeeklyScheduleModel schedule);
  Future<void> assignEmployee({
    required String scheduleId,
    required ScheduleDay day,
    required ScheduleShift shift,
    required String employeeId,
  });
  Future<void> removeEmployee({
    required String scheduleId,
    required ScheduleDay day,
    required ScheduleShift shift,
    required String employeeId,
  });

  /// Sets (or clears, when [note] is empty) the manager note pinned to [day].
  Future<void> setDayNote({
    required String scheduleId,
    required ScheduleDay day,
    required String note,
  });

  /// Marks [employeeId] on [type] leave for [day]; a null [type] clears it.
  Future<void> setLeave({
    required String scheduleId,
    required ScheduleDay day,
    required String employeeId,
    required LeaveType? type,
  });

  /// Overrides the [hours] for [day] + [shift] this week; a null [hours] clears
  /// the override (the slot falls back to [ShiftHours.standard]).
  Future<void> setShiftHours({
    required String scheduleId,
    required ScheduleDay day,
    required ScheduleShift shift,
    required ShiftHours? hours,
  });

  /// Re-stamps [plan] onto every `weekly_schedules` doc for [branchId] with
  /// `weekStart >= fromWeek` (the "update template globally" scope). Past weeks
  /// are skipped so history stays frozen.
  Future<void> restampShiftPlan({
    required String branchId,
    required DateTime fromWeek,
    required ShiftPlan plan,
  });

  // ── Shift swaps ──
  Future<List<ShiftSwapModel>> getBranchSwaps(String branchId);
  Future<List<ShiftSwapModel>> getEmployeeSwaps(String uid);
  Future<List<ShiftSwapModel>> getAllSwaps();

  /// Realtime swap streams (newest first). [watchEmployeeSwaps] merges the
  /// requester + target queries (Firestore has no cross-field OR); the branch /
  /// all streams are a single snapshot query.
  Stream<List<ShiftSwapModel>> watchEmployeeSwaps(String uid);
  Stream<List<ShiftSwapModel>> watchBranchSwaps(String branchId);
  Stream<List<ShiftSwapModel>> watchAllSwaps();

  Future<ShiftSwapModel> createSwap(ShiftSwapModel swap);
  Future<void> updateSwapStatus({
    required String swapId,
    required SwapStatus status,
  });

  /// Finalizes a coworker-approved swap through the **callable `approveSwap`
  /// Cloud Function** (the authority): it re-validates against the freshest
  /// schedule and applies the exchange atomically. [scheduleId] is computed
  /// client-side from the local week start (the function can't reproduce that id
  /// in UTC) and is re-checked server-side against the swap's branch.
  Future<void> approveSwap({
    required String swapId,
    required String scheduleId,
  });
}

class ScheduleRemoteDataSourceImpl implements ScheduleRemoteDataSource {
  final FirebaseFirestore _firestore;
  final FirebaseFunctions _functions;

  ScheduleRemoteDataSourceImpl(this._firestore, this._functions);

  CollectionReference<Map<String, dynamic>> get _schedules =>
      _firestore.collection(AppConstants.weeklySchedulesCollection);
  CollectionReference<Map<String, dynamic>> get _swaps =>
      _firestore.collection(AppConstants.shiftSwapsCollection);

  // ── Weekly schedules ───────────────────────────────────────────
  @override
  Future<WeeklyScheduleModel?> getSchedule(
    String branchId,
    DateTime weekStart,
  ) async {
    try {
      final doc = await _schedules
          .doc(ScheduleWeek.docId(branchId, weekStart))
          .get();
      if (!doc.exists || doc.data() == null) return null;
      return WeeklyScheduleModel.fromMap(doc.data()!, id: doc.id);
    } on FirebaseException catch (e) {
      throw ServerException(e.message ?? 'Failed to load the schedule.');
    }
  }

  @override
  Future<WeeklyScheduleModel?> getScheduleCacheFirst(
    String branchId,
    DateTime weekStart,
  ) async {
    try {
      final doc = await _schedules
          .doc(ScheduleWeek.docId(branchId, weekStart))
          .get(const GetOptions(source: Source.cache));
      if (doc.exists && doc.data() != null) {
        return WeeklyScheduleModel.fromMap(doc.data()!, id: doc.id);
      }
    } on FirebaseException {
      // A cache miss throws `unavailable` rather than returning an empty
      // snapshot. Either shape means "not on disk" — fall through to the
      // server, which is the normal path on a first run.
    }
    return getSchedule(branchId, weekStart);
  }

  @override
  Future<List<WeeklyScheduleModel>> getBranchSchedules(String branchId) async {
    try {
      // Single-field query (no composite index); sorted client-side, newest week
      // first — same pattern as the statistics datasource.
      final snap = await _schedules
          .where('branchId', isEqualTo: branchId)
          .get();
      return _sortByWeek(snap.docs);
    } on FirebaseException catch (e) {
      throw ServerException(e.message ?? 'Failed to load branch schedules.');
    }
  }

  @override
  Future<List<WeeklyScheduleModel>> getAllSchedules() async {
    try {
      final snap = await _schedules.get();
      return _sortByWeek(snap.docs);
    } on FirebaseException catch (e) {
      throw ServerException(e.message ?? 'Failed to load schedules.');
    }
  }

  @override
  Future<WeeklyScheduleModel> createSchedule(
    WeeklyScheduleModel schedule,
  ) async {
    try {
      final docRef = _schedules.doc(
        ScheduleWeek.docId(schedule.branchId, schedule.weekStart),
      );
      await docRef.set({
        ...schedule.toMap(),
        'id': docRef.id,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return WeeklyScheduleModel.fromMap(schedule.toMap(), id: docRef.id);
    } on FirebaseException catch (e) {
      throw ServerException(e.message ?? 'Failed to create the schedule.');
    }
  }

  @override
  Future<void> assignEmployee({
    required String scheduleId,
    required ScheduleDay day,
    required ScheduleShift shift,
    required String employeeId,
  }) async {
    try {
      // Targeted nested-array update — no read/modify/write race. The dotted
      // path creates intermediate maps/arrays if they don't exist yet.
      await _schedules.doc(scheduleId).update({
        'assignments.${day.value}.${shift.value}': FieldValue.arrayUnion([
          employeeId,
        ]),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } on FirebaseException catch (e) {
      throw ServerException(e.message ?? 'Failed to assign the employee.');
    }
  }

  @override
  Future<void> removeEmployee({
    required String scheduleId,
    required ScheduleDay day,
    required ScheduleShift shift,
    required String employeeId,
  }) async {
    try {
      await _schedules.doc(scheduleId).update({
        'assignments.${day.value}.${shift.value}': FieldValue.arrayRemove([
          employeeId,
        ]),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } on FirebaseException catch (e) {
      throw ServerException(e.message ?? 'Failed to remove the employee.');
    }
  }

  @override
  Future<void> setDayNote({
    required String scheduleId,
    required ScheduleDay day,
    required String note,
  }) async {
    try {
      // Same targeted dotted-path pattern as assignEmployee — an empty note
      // deletes the field so absent days stay absent in the doc.
      await _schedules.doc(scheduleId).update({
        'dayNotes.${day.value}': note.trim().isEmpty
            ? FieldValue.delete()
            : note.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } on FirebaseException catch (e) {
      throw ServerException(e.message ?? 'Failed to save the day note.');
    }
  }

  @override
  Future<void> setLeave({
    required String scheduleId,
    required ScheduleDay day,
    required String employeeId,
    required LeaveType? type,
  }) async {
    try {
      await _schedules.doc(scheduleId).update({
        'leave.${day.value}.$employeeId': type == null
            ? FieldValue.delete()
            : type.value,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } on FirebaseException catch (e) {
      throw ServerException(e.message ?? 'Failed to update the leave entry.');
    }
  }

  @override
  Future<void> setShiftHours({
    required String scheduleId,
    required ScheduleDay day,
    required ScheduleShift shift,
    required ShiftHours? hours,
  }) async {
    try {
      await _schedules.doc(scheduleId).update({
        'shiftHours.${day.value}.${shift.value}': hours == null
            ? FieldValue.delete()
            : hours.toMap(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } on FirebaseException catch (e) {
      throw ServerException(e.message ?? 'Failed to update the shift hours.');
    }
  }

  @override
  Future<void> restampShiftPlan({
    required String branchId,
    required DateTime fromWeek,
    required ShiftPlan plan,
  }) async {
    try {
      final snap = await _schedules
          .where('branchId', isEqualTo: branchId)
          .get();
      final planMap = plan.toMap();
      final batch = _firestore.batch();
      var touched = 0;
      for (final doc in snap.docs) {
        final ws = (doc.data()['weekStart'] as Timestamp?)?.toDate();
        // Only current + future already-created weeks; the past stays frozen.
        if (ws == null || ws.isBefore(fromWeek)) continue;
        batch.update(doc.reference, {
          'shiftPlan': planMap,
          'updatedAt': FieldValue.serverTimestamp(),
        });
        touched++;
      }
      if (touched > 0) await batch.commit();
    } on FirebaseException catch (e) {
      throw ServerException(e.message ?? 'Failed to update future schedules.');
    }
  }

  // ── Shift swaps ────────────────────────────────────────────────
  @override
  Future<List<ShiftSwapModel>> getBranchSwaps(String branchId) async {
    try {
      final snap = await _swaps.where('branchId', isEqualTo: branchId).get();
      return _sortSwaps(
        snap.docs.map((d) => ShiftSwapModel.fromMap(d.data(), id: d.id)),
      );
    } on FirebaseException catch (e) {
      throw ServerException(e.message ?? 'Failed to load swap requests.');
    }
  }

  @override
  Future<List<ShiftSwapModel>> getEmployeeSwaps(String uid) async {
    try {
      // Firestore has no OR across fields; query each side and merge by id.
      final asRequester = await _swaps
          .where('requesterId', isEqualTo: uid)
          .get();
      final asTarget = await _swaps.where('targetId', isEqualTo: uid).get();
      final byId = <String, ShiftSwapModel>{};
      for (final d in [...asRequester.docs, ...asTarget.docs]) {
        byId[d.id] = ShiftSwapModel.fromMap(d.data(), id: d.id);
      }
      return _sortSwaps(byId.values);
    } on FirebaseException catch (e) {
      throw ServerException(e.message ?? 'Failed to load your swap requests.');
    }
  }

  @override
  Future<List<ShiftSwapModel>> getAllSwaps() async {
    try {
      final snap = await _swaps.get();
      return _sortSwaps(
        snap.docs.map((d) => ShiftSwapModel.fromMap(d.data(), id: d.id)),
      );
    } on FirebaseException catch (e) {
      throw ServerException(e.message ?? 'Failed to load swap requests.');
    }
  }

  @override
  Stream<List<ShiftSwapModel>> watchBranchSwaps(String branchId) {
    return _swaps
        .where('branchId', isEqualTo: branchId)
        .snapshots()
        .map(
          (snap) => _sortSwaps(
            snap.docs.map((d) => ShiftSwapModel.fromMap(d.data(), id: d.id)),
          ),
        );
  }

  @override
  Stream<List<ShiftSwapModel>> watchAllSwaps() {
    return _swaps.snapshots().map(
      (snap) => _sortSwaps(
        snap.docs.map((d) => ShiftSwapModel.fromMap(d.data(), id: d.id)),
      ),
    );
  }

  @override
  Stream<List<ShiftSwapModel>> watchEmployeeSwaps(String uid) {
    // Firestore has no cross-field OR on snapshots, so we run the requester +
    // target queries and merge their latest results by id. A single broadcast
    // controller fans the union out; both inner subscriptions are cancelled when
    // the consumer cancels (the cubit, on close / re-subscribe).
    final reqStream = _swaps.where('requesterId', isEqualTo: uid).snapshots();
    final tgtStream = _swaps.where('targetId', isEqualTo: uid).snapshots();

    late final StreamController<List<ShiftSwapModel>> controller;
    StreamSubscription? reqSub;
    StreamSubscription? tgtSub;
    var reqMap = <String, ShiftSwapModel>{};
    var tgtMap = <String, ShiftSwapModel>{};
    var reqReady = false;
    var tgtReady = false;

    void emitUnion() {
      if (!reqReady && !tgtReady) return;
      final byId = <String, ShiftSwapModel>{...reqMap, ...tgtMap};
      controller.add(_sortSwaps(byId.values));
    }

    Map<String, ShiftSwapModel> toMap(
      QuerySnapshot<Map<String, dynamic>> s,
    ) => {
      for (final d in s.docs) d.id: ShiftSwapModel.fromMap(d.data(), id: d.id),
    };

    controller = StreamController<List<ShiftSwapModel>>(
      onListen: () {
        reqSub = reqStream.listen((s) {
          reqMap = toMap(s);
          reqReady = true;
          emitUnion();
        }, onError: controller.addError);
        tgtSub = tgtStream.listen((s) {
          tgtMap = toMap(s);
          tgtReady = true;
          emitUnion();
        }, onError: controller.addError);
      },
      onCancel: () async {
        await reqSub?.cancel();
        await tgtSub?.cancel();
      },
    );
    return controller.stream;
  }

  @override
  Future<ShiftSwapModel> createSwap(ShiftSwapModel swap) async {
    try {
      final docRef = _swaps.doc();
      final created = swap.copyWithId(docRef.id);
      await docRef.set({
        ...created.toMap(),
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return created;
    } on FirebaseException catch (e) {
      throw ServerException(e.message ?? 'Failed to send the swap request.');
    }
  }

  @override
  Future<void> updateSwapStatus({
    required String swapId,
    required SwapStatus status,
  }) async {
    try {
      await _swaps.doc(swapId).set({
        'status': status.value,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } on FirebaseException catch (e) {
      throw ServerException(e.message ?? 'Failed to update the swap request.');
    }
  }

  @override
  Future<void> approveSwap({
    required String swapId,
    required String scheduleId,
  }) async {
    try {
      final callable = _functions.httpsCallable('approveSwap');
      await callable.call<Map<String, dynamic>>({
        'swapId': swapId,
        'scheduleId': scheduleId,
      });
    } on FirebaseFunctionsException catch (e, st) {
      AppLog.error(
        'schedule',
        'approveSwap callable failed: code=${e.code} message=${e.message}',
        e,
        st,
      );
      throw ServerException(_friendlyFunctionsError(e));
    } on FirebaseException catch (e) {
      throw ServerException(e.message ?? 'Failed to approve the swap.');
    }
  }

  /// Maps a callable failure to a user-facing message. The function raises
  /// full-sentence `HttpsError` messages for validation problems (surfaced
  /// verbatim); transport-level failures raise bare upper-case codes, replaced
  /// with guidance (mirrors `BroadcastRemoteDataSourceImpl`).
  String _friendlyFunctionsError(FirebaseFunctionsException e) {
    final msg = (e.message ?? '').trim();
    if (msg.contains(' ')) return msg; // a real sentence vs. a raw code token
    switch (e.code) {
      case 'unauthenticated':
      case 'permission-denied':
        return 'Couldn’t reach the swap service. Please try again in a moment.';
      case 'unavailable':
        return 'Network problem — check your connection and try again.';
      case 'not-found':
        return 'The swap service isn’t available yet. Please try again later.';
      default:
        return 'Couldn’t approve the swap right now. Please try again.';
    }
  }

  List<WeeklyScheduleModel> _sortByWeek(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    final models = docs
        .map((d) => WeeklyScheduleModel.fromMap(d.data(), id: d.id))
        .toList();
    models.sort((a, b) => b.weekStart.compareTo(a.weekStart));
    return models;
  }

  List<ShiftSwapModel> _sortSwaps(Iterable<ShiftSwapModel> swaps) {
    final list = swaps.toList();
    // Newest activity first: this puts decisions made today ahead of requests
    // created earlier in the week, making resolved swaps a useful history.
    DateTime activityAt(ShiftSwapModel swap) =>
        swap.managerApprovedAt ??
        swap.updatedAt ??
        swap.createdAt ??
        DateTime.now();
    list.sort((a, b) => activityAt(b).compareTo(activityAt(a)));
    return list;
  }
}
