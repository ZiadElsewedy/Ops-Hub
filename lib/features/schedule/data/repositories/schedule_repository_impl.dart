import 'package:drop/core/enums/leave_type.dart';
import 'package:drop/core/enums/schedule_day.dart';
import 'package:drop/core/enums/schedule_shift.dart';
import 'package:drop/features/schedule/domain/shift_hours.dart';
import 'package:drop/core/enums/swap_status.dart';
import 'package:drop/core/errors/exceptions.dart';
import 'package:drop/core/errors/failures.dart';
import 'package:drop/features/schedule/data/datasources/schedule_remote_datasource.dart';
import 'package:drop/features/schedule/data/models/shift_swap_model.dart';
import 'package:drop/features/schedule/data/models/weekly_schedule_model.dart';
import 'package:drop/features/schedule/domain/entities/shift_swap_entity.dart';
import 'package:drop/features/schedule/domain/entities/weekly_schedule_entity.dart';
import 'package:drop/features/schedule/domain/repositories/schedule_repository.dart';
import 'package:drop/features/schedule/domain/schedule_week.dart';
import 'package:drop/features/schedule/domain/shift_plan.dart';

class ScheduleRepositoryImpl implements ScheduleRepository {
  final ScheduleRemoteDataSource _remote;

  ScheduleRepositoryImpl(this._remote);

  @override
  Future<WeeklyScheduleEntity?> getSchedule(
      String branchId, DateTime weekStart) async {
    try {
      final model = await _remote.getSchedule(branchId, weekStart);
      return model?.toEntity();
    } on ServerException catch (e) {
      throw ServerFailure(e.message);
    }
  }

  @override
  Future<WeeklyScheduleEntity?> getScheduleCacheFirst(
      String branchId, DateTime weekStart) async {
    try {
      final model = await _remote.getScheduleCacheFirst(branchId, weekStart);
      return model?.toEntity();
    } on ServerException catch (e) {
      throw ServerFailure(e.message);
    }
  }

  @override
  Future<List<WeeklyScheduleEntity>> getBranchSchedules(String branchId) async {
    try {
      final models = await _remote.getBranchSchedules(branchId);
      return models.map((m) => m.toEntity()).toList();
    } on ServerException catch (e) {
      throw ServerFailure(e.message);
    }
  }

  @override
  Future<List<WeeklyScheduleEntity>> getAllSchedules() async {
    try {
      final models = await _remote.getAllSchedules();
      return models.map((m) => m.toEntity()).toList();
    } on ServerException catch (e) {
      throw ServerFailure(e.message);
    }
  }

  @override
  Future<WeeklyScheduleEntity> createSchedule({
    required String branchId,
    required DateTime weekStart,
    String? createdBy,
    ShiftPlan? shiftPlan,
  }) async {
    try {
      final start = ScheduleWeek.startOf(weekStart);
      final created = await _remote.createSchedule(
        WeeklyScheduleModel.empty(
          id: ScheduleWeek.docId(branchId, start),
          branchId: branchId,
          weekStart: start,
          createdBy: createdBy,
          shiftPlan: shiftPlan,
        ),
      );
      return created.toEntity();
    } on ServerException catch (e) {
      throw ServerFailure(e.message);
    }
  }

  @override
  Future<void> restampShiftPlan({
    required String branchId,
    required DateTime fromWeek,
    required ShiftPlan plan,
  }) async {
    try {
      await _remote.restampShiftPlan(
        branchId: branchId,
        fromWeek: ScheduleWeek.startOf(fromWeek),
        plan: plan,
      );
    } on ServerException catch (e) {
      throw ServerFailure(e.message);
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
      await _remote.assignEmployee(
        scheduleId: scheduleId,
        day: day,
        shift: shift,
        employeeId: employeeId,
      );
    } on ServerException catch (e) {
      throw ServerFailure(e.message);
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
      await _remote.removeEmployee(
        scheduleId: scheduleId,
        day: day,
        shift: shift,
        employeeId: employeeId,
      );
    } on ServerException catch (e) {
      throw ServerFailure(e.message);
    }
  }

  @override
  Future<void> setDayNote({
    required String scheduleId,
    required ScheduleDay day,
    required String note,
  }) async {
    try {
      await _remote.setDayNote(scheduleId: scheduleId, day: day, note: note);
    } on ServerException catch (e) {
      throw ServerFailure(e.message);
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
      await _remote.setLeave(
        scheduleId: scheduleId,
        day: day,
        employeeId: employeeId,
        type: type,
      );
    } on ServerException catch (e) {
      throw ServerFailure(e.message);
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
      await _remote.setShiftHours(
        scheduleId: scheduleId,
        day: day,
        shift: shift,
        hours: hours,
      );
    } on ServerException catch (e) {
      throw ServerFailure(e.message);
    }
  }

  // ── Shift swaps ────────────────────────────────────────────────
  @override
  Future<List<ShiftSwapEntity>> getBranchSwaps(String branchId) async {
    try {
      final models = await _remote.getBranchSwaps(branchId);
      return models.map((m) => m.toEntity()).toList();
    } on ServerException catch (e) {
      throw ServerFailure(e.message);
    }
  }

  @override
  Future<List<ShiftSwapEntity>> getEmployeeSwaps(String uid) async {
    try {
      final models = await _remote.getEmployeeSwaps(uid);
      return models.map((m) => m.toEntity()).toList();
    } on ServerException catch (e) {
      throw ServerFailure(e.message);
    }
  }

  @override
  Future<List<ShiftSwapEntity>> getAllSwaps() async {
    try {
      final models = await _remote.getAllSwaps();
      return models.map((m) => m.toEntity()).toList();
    } on ServerException catch (e) {
      throw ServerFailure(e.message);
    }
  }

  @override
  Stream<List<ShiftSwapEntity>> watchEmployeeSwaps(String uid) =>
      _remote.watchEmployeeSwaps(uid).map(_toEntities).handleError(_streamError);

  @override
  Stream<List<ShiftSwapEntity>> watchBranchSwaps(String branchId) =>
      _remote.watchBranchSwaps(branchId).map(_toEntities).handleError(_streamError);

  @override
  Stream<List<ShiftSwapEntity>> watchAllSwaps() =>
      _remote.watchAllSwaps().map(_toEntities).handleError(_streamError);

  List<ShiftSwapEntity> _toEntities(List<ShiftSwapModel> models) =>
      models.map((m) => m.toEntity()).toList();

  Never _streamError(Object e, StackTrace st) =>
      throw ServerFailure(e is Failure ? e.message : 'Failed to load swap requests.');

  @override
  Future<ShiftSwapEntity> createSwap(ShiftSwapEntity swap) async {
    try {
      final created = await _remote.createSwap(ShiftSwapModel.fromEntity(swap));
      return created.toEntity();
    } on ServerException catch (e) {
      throw ServerFailure(e.message);
    }
  }

  @override
  Future<void> updateSwapStatus({
    required String swapId,
    required SwapStatus status,
  }) async {
    try {
      await _remote.updateSwapStatus(swapId: swapId, status: status);
    } on ServerException catch (e) {
      throw ServerFailure(e.message);
    }
  }

  @override
  Future<void> managerApproveSwap(ShiftSwapEntity swap) async {
    try {
      // The validated, ATOMIC exchange is owned by the `approveSwap` Cloud
      // Function: it re-checks against the freshest schedule (TOCTOU backstop),
      // enforces the branch's swap policy (role compatibility / rest hours / no
      // double-booking), and applies the requester ⇄ target trade in a single
      // transaction (either both move or nothing changes). The replaced client
      // path was four sequential, non-atomic writes — a partial failure could
      // corrupt the roster. The schedule doc id is computed here from the LOCAL
      // week start (the UTC function can't reproduce it) and re-validated
      // server-side against the swap's branch.
      await _remote.approveSwap(
        swapId: swap.id,
        scheduleId: ScheduleWeek.docId(swap.branchId, swap.weekStart),
      );
    } on ServerException catch (e) {
      throw ServerFailure(e.message);
    }
  }
}
