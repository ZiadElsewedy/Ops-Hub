import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:drop/core/errors/failures.dart';
import 'package:drop/features/sales/domain/entities/branch_sales_month_entity.dart';
import 'package:drop/features/sales/domain/entities/daily_sales_submission_entity.dart';
import 'package:drop/features/sales/domain/entities/sales_month_snapshot.dart';
import 'package:drop/features/sales/domain/repositories/sales_repository.dart';
import 'package:drop/features/sales/domain/sales_business_time.dart';
import 'package:drop/features/sales/domain/usecases/approve_sales_submission.dart';
import 'package:drop/features/sales/domain/usecases/edit_approved_sales_submission.dart';
import 'package:drop/features/sales/domain/usecases/reject_sales_submission.dart';
import 'package:drop/features/sales/domain/usecases/request_sales_correction.dart';
import 'package:drop/features/sales/domain/usecases/set_branch_monthly_target.dart';

sealed class SalesManagerDashboardState {
  const SalesManagerDashboardState();
}

class SalesManagerDashboardLoading extends SalesManagerDashboardState {
  const SalesManagerDashboardLoading();
}

class SalesManagerDashboardError extends SalesManagerDashboardState {
  const SalesManagerDashboardError(this.message);
  final String message;
}

class SalesManagerDashboardLoaded extends SalesManagerDashboardState {
  const SalesManagerDashboardLoaded({
    required this.snapshot,
    this.busyId,
    this.message,
  });
  final SalesMonthSnapshot snapshot;
  final String? busyId;
  final String? message;
  bool isBusy(String id) => busyId == id;
}

class SalesManagerDashboardCubit extends Cubit<SalesManagerDashboardState> {
  SalesManagerDashboardCubit({
    required this._repository,
    required this._approve,
    required this._reject,
    required this._requestCorrection,
    required this._editApproved,
    required this._setTarget,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now,
       super(const SalesManagerDashboardLoading());
  final SalesRepository _repository;
  final ApproveSalesSubmission _approve;
  final RejectSalesSubmission _reject;
  final RequestSalesCorrection _requestCorrection;
  final EditApprovedSalesSubmission _editApproved;
  final SetBranchMonthlyTarget _setTarget;
  final DateTime Function() _now;
  StreamSubscription<BranchSalesMonthEntity?>? _monthSub;
  StreamSubscription<List<DailySalesSubmissionEntity>>? _submissionsSub;
  BranchSalesMonthEntity? _target;
  List<DailySalesSubmissionEntity> _submissions = const [];
  String? _branchId;
  String? _monthKey;
  String? _busyId;
  Future<void> loadForBranch({
    required String branchId,
    String? monthKey,
    DateTime? now,
  }) async {
    final key = monthKey ?? businessMonthKey(now ?? _now());
    if (_branchId == branchId && _monthKey == key && _monthSub != null) return;
    _branchId = branchId;
    _monthKey = key;
    if (state is! SalesManagerDashboardLoaded) {
      emit(const SalesManagerDashboardLoading());
    }
    await _monthSub?.cancel();
    await _submissionsSub?.cancel();
    _monthSub = _repository.watchMonth(branchId, key).listen((v) {
      _target = v;
      _emit();
    }, onError: _onError);
    _submissionsSub = _repository.watchSubmissions(branchId, key).listen((v) {
      _submissions = v;
      _emit();
    }, onError: _onError);
  }

  void _emit([String? message]) => emit(
    SalesManagerDashboardLoaded(
      snapshot: SalesMonthSnapshot(target: _target, submissions: _submissions),
      busyId: _busyId,
      message: message,
    ),
  );
  void _onError(Object e, [StackTrace? _]) => emit(
    SalesManagerDashboardError(
      e is Failure ? e.message : 'Failed to load sales.',
    ),
  );
  Future<void> _run(
    String id,
    Future<void> Function() action,
    String success,
  ) async {
    if (_busyId != null) return;
    _busyId = id;
    _emit();
    try {
      await action();
      _busyId = null;
      _emit(success);
    } on Failure catch (e) {
      _busyId = null;
      _emit(e.message);
    } catch (_) {
      _busyId = null;
      _emit('Couldn’t update sales right now. Please try again.');
    }
  }

  Future<void> approve(String id) =>
      _run(id, () => _approve(id), 'Sales approved.');
  Future<void> reject(String id, String reason) => _run(
    id,
    () => _reject(submissionId: id, reason: reason),
    'Sales rejected.',
  );
  Future<void> requestCorrection(String id, String reason) => _run(
    id,
    () => _requestCorrection(submissionId: id, reason: reason),
    'Correction requested.',
  );
  Future<void> editApproved(
    String id,
    int amountPiastres,
    String reason,
    int expectedRevision,
  ) => _run(
    id,
    () => _editApproved(
      submissionId: id,
      amountPiastres: amountPiastres,
      reason: reason,
      expectedRevision: expectedRevision,
    ),
    'Approved amount updated.',
  );
  Future<void> setTarget(
    int targetPiastres,
    String reason, {
    int? expectedTargetRevision,
  }) => _run(
    'target',
    () => _setTarget(
      branchId: _branchId!,
      monthKey: _monthKey!,
      targetPiastres: targetPiastres,
      reason: reason,
      expectedTargetRevision: expectedTargetRevision,
    ),
    'Monthly target updated.',
  );
  @override
  Future<void> close() async {
    await _monthSub?.cancel();
    await _submissionsSub?.cancel();
    return super.close();
  }
}
