import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:drop/core/errors/failures.dart';
import 'package:drop/features/branch/domain/repositories/branch_repository.dart';
import 'package:drop/features/sales/domain/entities/branch_sales_month_entity.dart';
import 'package:drop/features/sales/domain/entities/daily_sales_submission_entity.dart';
import 'package:drop/features/sales/domain/entities/sales_month_snapshot.dart';
import 'package:drop/features/sales/domain/entities/sales_record_result.dart';
import 'package:drop/features/sales/domain/repositories/sales_repository.dart';
import 'package:drop/features/sales/domain/sales_business_time.dart';
import 'package:drop/features/sales/domain/usecases/approve_sales_submission.dart';
import 'package:drop/features/sales/domain/usecases/edit_approved_sales_submission.dart';
import 'package:drop/features/sales/domain/usecases/record_daily_sales.dart';
import 'package:drop/features/sales/domain/usecases/reject_sales_submission.dart';
import 'package:drop/features/sales/domain/usecases/request_sales_correction.dart';
import 'package:drop/features/sales/domain/usecases/set_branch_monthly_target.dart';

sealed class SalesManagerDashboardState {
  const SalesManagerDashboardState();
}

class SalesManagerDashboardLoading extends SalesManagerDashboardState {
  const SalesManagerDashboardLoading();
}

/// The branch does not run the monthly sales target workflow.
class SalesManagerDashboardDisabled extends SalesManagerDashboardState {
  const SalesManagerDashboardDisabled({this.branchName});
  final String? branchName;
}

class SalesManagerDashboardError extends SalesManagerDashboardState {
  const SalesManagerDashboardError(this.message);
  final String message;
}

class SalesManagerDashboardLoaded extends SalesManagerDashboardState {
  const SalesManagerDashboardLoaded({
    required this.snapshot,
    required this.monthKey,
    required this.todayDateKey,
    this.branchName,
    this.busyId,
    this.message,
    this.justRecorded,
  });
  final SalesMonthSnapshot snapshot;

  /// The Cairo month this view is showing — the history screen drives it.
  final String monthKey;

  /// Today's Cairo business day. Resolved by the cubit, never by the widget:
  /// the device's local date is a different day near midnight and across DST.
  final String todayDateKey;

  /// The branch's close for today, whatever its status — the figure the
  /// needed-per-day tone is judged against. Null until the day is submitted.
  int? get todayPiastres => snapshot.submissionFor(todayDateKey)?.amountPiastres;
  final String? branchName;
  final String? busyId;
  final String? message;

  /// Set for exactly one emission after a manager/admin records a day directly,
  /// so the screen can play the "+amount added" confirmation once. It rides a
  /// separate channel from [message] so the celebration is not also a snackbar.
  final SalesRecordResult? justRecorded;
  bool isBusy(String id) => busyId == id;

  /// True while a direct record is being written — the "Add record" control
  /// shows its own progress and every sibling control disables.
  bool get isRecording => busyId == 'record';

  /// True while any action is running: sibling controls disable so a second
  /// decision cannot race the first.
  bool get isBusyAnywhere => busyId != null;
}

class SalesManagerDashboardCubit extends Cubit<SalesManagerDashboardState> {
  SalesManagerDashboardCubit({
    required this._repository,
    required this._branchRepository,
    required this._approve,
    required this._reject,
    required this._requestCorrection,
    required this._editApproved,
    required this._setTarget,
    required this._record,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now,
       super(const SalesManagerDashboardLoading());

  final SalesRepository _repository;
  final BranchRepository _branchRepository;
  final ApproveSalesSubmission _approve;
  final RejectSalesSubmission _reject;
  final RequestSalesCorrection _requestCorrection;
  final EditApprovedSalesSubmission _editApproved;
  final SetBranchMonthlyTarget _setTarget;
  final RecordDailySales _record;
  final DateTime Function() _now;

  StreamSubscription<BranchSalesMonthEntity?>? _monthSub;
  StreamSubscription<List<DailySalesSubmissionEntity>>? _submissionsSub;
  BranchSalesMonthEntity? _target;
  List<DailySalesSubmissionEntity> _submissions = const [];
  String? _branchId;
  String? _monthKey;
  String? _branchName;
  String? _busyId;
  bool _hasLoaded = false;

  /// Whether a target already exists for the month in view — the difference
  /// between "Set monthly target" and "Edit monthly target".
  bool get hasTarget => _target != null;

  /// [force] re-subscribes even when nothing changed; a Retry control needs it,
  /// because a failed load otherwise left the guard satisfied forever.
  Future<void> loadForBranch({
    required String branchId,
    String? monthKey,
    DateTime? now,
    bool force = false,
  }) async {
    final key = monthKey ?? businessMonthKey(now ?? _now());
    if (_branchId == branchId &&
        _monthKey == key &&
        _monthSub != null &&
        !force) {
      return;
    }
    _branchId = branchId;
    _monthKey = key;
    if (state is! SalesManagerDashboardLoaded) {
      emit(const SalesManagerDashboardLoading());
    }
    await _cancelSubscriptions();

    if (branchId.isEmpty) {
      emit(
        const SalesManagerDashboardError(
          'No branch is assigned to your account.',
        ),
      );
      return;
    }

    // Resolve the branch's opt-in before touching the ledger, so a branch that
    // does not run targets shows nothing to manage rather than an empty month.
    try {
      final branch = await _branchRepository.getBranch(branchId);
      _branchName = branch?.name;
      if (branch == null || !branch.salesTargetEnabled) {
        _hasLoaded = false;
        emit(SalesManagerDashboardDisabled(branchName: _branchName));
        return;
      }
    } on Failure catch (e) {
      emit(SalesManagerDashboardError(e.message));
      return;
    } catch (_) {
      emit(const SalesManagerDashboardError('Failed to load sales.'));
      return;
    }

    _target = null;
    _submissions = const [];
    _hasLoaded = false;

    _monthSub = _repository.watchMonth(branchId, key).listen((value) {
      _target = value;
      _hasLoaded = true;
      _emit();
    }, onError: _onError);
    _submissionsSub = _repository.watchSubmissions(branchId, key).listen((
      value,
    ) {
      _submissions = value;
      _hasLoaded = true;
      _emit();
    }, onError: _onError);
  }

  void _emit([String? message, SalesRecordResult? justRecorded]) => emit(
    SalesManagerDashboardLoaded(
      snapshot: SalesMonthSnapshot(target: _target, submissions: _submissions),
      monthKey: _monthKey ?? businessMonthKey(_now()),
      todayDateKey: businessDateKey(_now()),
      branchName: _branchName,
      busyId: _busyId,
      message: message,
      justRecorded: justRecorded,
    ),
  );

  /// One of two streams failing must not discard content the other already
  /// delivered — surface the problem as a message and keep the page usable.
  void _onError(Object e, [StackTrace? _]) {
    final message = e is Failure ? e.message : 'Failed to load sales.';
    if (_hasLoaded) {
      _emit(message);
    } else {
      emit(SalesManagerDashboardError(message));
    }
  }

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
  Future<void> reject(String id, String reason) =>
      _run(id, () => _reject(submissionId: id, reason: reason), 'Sales rejected.');
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

  /// Creating and changing the target are the same server action; only the
  /// wording differs, so the caller passes what it showed the user.
  Future<void> setTarget(
    int targetPiastres,
    String reason, {
    int? expectedTargetRevision,
  }) {
    final creating = _target == null;
    return _run(
      'target',
      () => _setTarget(
        branchId: _branchId!,
        monthKey: _monthKey!,
        targetPiastres: targetPiastres,
        reason: reason,
        expectedTargetRevision: expectedTargetRevision,
      ),
      creating ? 'Monthly target set.' : 'Monthly target updated.',
    );
  }

  /// Record a day's sales directly (manager/admin). On success the record lands
  /// already approved; the result rides [SalesManagerDashboardLoaded.justRecorded]
  /// so the screen plays the "+amount added" confirmation exactly once. A null
  /// [businessDateKey] means today (the server resolves the Cairo day).
  Future<void> recordSales({
    required int amountPiastres,
    String? businessDateKey,
    String? reason,
  }) async {
    if (_busyId != null) return;
    final branchId = _branchId;
    if (branchId == null || branchId.isEmpty) {
      _emit('No branch is assigned to your account.');
      return;
    }
    _busyId = 'record';
    _emit();
    try {
      final result = await _record(
        branchId: branchId,
        amountPiastres: amountPiastres,
        businessDateKey: businessDateKey,
        reason: reason,
      );
      _busyId = null;
      _emit(null, result);
    } on Failure catch (e) {
      _busyId = null;
      _emit(e.message);
    } catch (_) {
      _busyId = null;
      _emit('Couldn’t record sales right now. Please try again.');
    }
  }

  Future<void> _cancelSubscriptions() async {
    await _monthSub?.cancel();
    await _submissionsSub?.cancel();
    _monthSub = null;
    _submissionsSub = null;
  }

  @override
  Future<void> close() async {
    await _cancelSubscriptions();
    return super.close();
  }
}
