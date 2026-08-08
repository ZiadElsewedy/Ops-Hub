import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:drop/core/errors/failures.dart';
import 'package:drop/features/auth/domain/entities/user_entity.dart';
import 'package:drop/features/branch/domain/repositories/branch_repository.dart';
import 'package:drop/features/sales/domain/entities/branch_sales_month_entity.dart';
import 'package:drop/features/sales/domain/entities/daily_sales_submission_entity.dart';
import 'package:drop/features/sales/domain/entities/sales_month_snapshot.dart';
import 'package:drop/features/sales/domain/repositories/sales_repository.dart';
import 'package:drop/features/sales/domain/sales_business_time.dart';
import 'package:drop/features/sales/domain/usecases/resubmit_corrected_sales.dart';
import 'package:drop/features/sales/domain/usecases/submit_daily_sales.dart';
import 'sales_month_state.dart';

/// The branch's sales month as a **Home-surface** read: the target and the
/// approved total, plus — for an employee — their own daily records and the
/// actions they may take.
///
/// Two entry points, one subscription set:
///
/// * [loadForEmployee] adds the employee's own records (every status), because
///   an employee's Home has to know whether *they* still owe today's close.
/// * [loadForBranch] omits that stream. A manager never closes a day, so
///   subscribing to their own submissions would open a third listener that can
///   only ever be empty. Everything a manager acts on — the review queue, the
///   filtered ledgers, target editing — lives on `SalesManagerDashboardCubit`
///   behind `/sales`; this is the figure on Home, nothing more.
class SalesMonthCubit extends Cubit<SalesMonthState> {
  SalesMonthCubit({
    required this._repository,
    required this._branchRepository,
    required this._submitDailySales,
    required this._resubmitCorrectedSales,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now,
       super(const SalesMonthState.initial());

  final SalesRepository _repository;
  final BranchRepository _branchRepository;
  final SubmitDailySales _submitDailySales;
  final ResubmitCorrectedSales _resubmitCorrectedSales;
  final DateTime Function() _now;

  StreamSubscription<BranchSalesMonthEntity?>? _monthSub;
  StreamSubscription<List<DailySalesSubmissionEntity>>? _approvedSub;
  StreamSubscription<List<DailySalesSubmissionEntity>>? _ownSub;

  BranchSalesMonthEntity? _target;
  List<DailySalesSubmissionEntity> _approved = const [];
  List<DailySalesSubmissionEntity> _own = const [];
  String? _branchId;
  String? _uid;
  String? _monthKey;
  String _todayDateKey = '';
  bool _busy = false;

  /// Subscribes to this employee's branch-month. Re-subscribes whenever the
  /// branch, the employee, or the Cairo **month** changed — the last one matters
  /// because an app left open across midnight on the 1st would otherwise keep
  /// streaming last month's ledger.
  ///
  /// [force] re-subscribes unconditionally; it is what a Retry control calls.
  /// Without it, a failed load left `_monthSub` non-null and every retry
  /// early-returned, so the error state could never clear.
  Future<void> loadForEmployee({
    required String branchId,
    required String uid,
    DateTime? now,
    bool force = false,
  }) => _subscribe(branchId: branchId, uid: uid, now: now, force: force);

  /// The manager/branch view: target + approved total, **no own-submissions
  /// stream**. Same guards, same opt-in resolution, same month rollover as
  /// [loadForEmployee] — the only difference is the third listener.
  ///
  /// ⚠️ `ownSubmissions` stays empty, so the submission-flow getters on
  /// `SalesMonthLoaded` are **not meaningful in this mode** — `canSubmitToday`
  /// in particular reads `true` whenever a target exists, because it is asking
  /// "does this employee still owe today?" of a cubit holding no employee. The
  /// manager card renders `snapshot` only. Never drive a submit CTA off a
  /// branch-mode state; the manager's actions live on
  /// `SalesManagerDashboardCubit`.
  Future<void> loadForBranch({
    required String branchId,
    DateTime? now,
    bool force = false,
  }) => _subscribe(branchId: branchId, uid: null, now: now, force: force);

  /// The one subscription path both entry points share. A null [uid] is branch
  /// mode. It participates in the `unchanged` guard, so a role that somehow
  /// switched modes on the same branch and month still re-subscribes rather
  /// than keeping the wrong stream set.
  Future<void> _subscribe({
    required String branchId,
    required String? uid,
    DateTime? now,
    bool force = false,
  }) async {
    final instant = now ?? _now();
    final monthKey = businessMonthKey(instant);
    final unchanged =
        _branchId == branchId &&
        _uid == uid &&
        _monthKey == monthKey &&
        _monthSub != null;
    if (unchanged && !force) {
      // Still refresh the business day so a card left open overnight stops
      // offering to submit a day that is already closed.
      _todayDateKey = businessDateKey(instant);
      if (state is SalesMonthLoaded) _emitLoaded();
      return;
    }

    _branchId = branchId;
    _uid = uid;
    _monthKey = monthKey;
    _todayDateKey = businessDateKey(instant);
    if (state is! SalesMonthLoaded) emit(const SalesMonthState.loading());

    await _cancelSubscriptions();

    // A branch that does not run targets must behave as if the feature does not
    // exist — so resolve the flag BEFORE subscribing and never read the ledger.
    final bool enabled;
    try {
      final branch = await _branchRepository.getBranch(branchId);
      enabled = branch?.salesTargetEnabled ?? false;
    } on Failure catch (e) {
      emit(SalesMonthState.error(e.message));
      return;
    } catch (_) {
      emit(const SalesMonthState.error('Failed to load sales.'));
      return;
    }
    if (!enabled) {
      _target = null;
      _approved = const [];
      _own = const [];
      emit(const SalesMonthState.disabled());
      return;
    }

    _target = null;
    _approved = const [];
    _own = const [];

    _monthSub = _repository.watchMonth(branchId, monthKey).listen((value) {
      _target = value;
      _emitLoaded();
    }, onError: _onError);
    _approvedSub = _repository
        .watchApprovedSubmissions(branchId, monthKey)
        .listen((value) {
          _approved = value;
          _emitLoaded();
        }, onError: _onError);
    // Branch mode (a manager) has no own-submissions stream — see the class doc.
    if (uid != null) {
      _ownSub = _repository
          .watchOwnSubmissions(branchId, monthKey, uid)
          .listen((value) {
            _own = value;
            _emitLoaded();
          }, onError: _onError);
    }
  }

  void _emitLoaded([String? message]) => emit(
    SalesMonthState.loaded(
      snapshot: SalesMonthSnapshot(target: _target, submissions: _approved),
      todayDateKey: _todayDateKey,
      ownSubmissions: _own,
      submitting: _busy,
      message: message,
    ),
  );

  void _onError(Object error, [StackTrace? _]) => emit(
    SalesMonthState.error(
      error is Failure ? error.message : 'Failed to load sales.',
    ),
  );

  Future<void> submitToday({
    required int amountPiastres,
    required UserEntity user,
  }) async {
    if (_busy) return;
    final branchId = user.branchId;
    if (branchId == null || branchId.isEmpty) {
      _emitLoaded('Your branch is not available.');
      return;
    }
    if (amountPiastres < 0) {
      _emitLoaded('Enter a valid non-negative EGP amount.');
      return;
    }
    final now = _now();
    final dateKey = businessDateKey(now);
    _todayDateKey = dateKey;
    if (_target == null) {
      _emitLoaded('A monthly target must be set before submitting sales.');
      return;
    }
    if (!isWithinSalesSubmissionWindow(dateKey, now: now)) {
      _emitLoaded('Today is outside the submission window.');
      return;
    }
    if (_own.any((s) => s.businessDateKey == dateKey) ||
        _approved.any((s) => s.businessDateKey == dateKey)) {
      _emitLoaded('Today’s sales have already been submitted.');
      return;
    }
    await _run(
      () => _submitDailySales(
        branchId: branchId,
        monthKey: businessMonthKey(now),
        businessDateKey: dateKey,
        amountPiastres: amountPiastres,
        submittedById: user.uid,
        submittedByName: user.displayName ?? 'Employee',
      ),
      salesSubmittedMessage,
    );
  }

  /// Resends a day the manager asked to be corrected. This is the employee half
  /// of the correction loop — without it a `correctionRequested` record was a
  /// dead end with no way back to `pending`.
  Future<void> resubmitCorrection({
    required String submissionId,
    required int amountPiastres,
  }) async {
    if (_busy) return;
    if (amountPiastres < 0) {
      _emitLoaded('Enter a valid non-negative EGP amount.');
      return;
    }
    await _run(
      () => _resubmitCorrectedSales(
        submissionId: submissionId,
        amountPiastres: amountPiastres,
      ),
      salesResubmittedMessage,
    );
  }

  Future<void> _run(Future<void> Function() action, String success) async {
    _busy = true;
    _emitLoaded();
    try {
      await action();
      _busy = false;
      _emitLoaded(success);
    } on Failure catch (e) {
      _busy = false;
      _emitLoaded(e.message);
    } catch (_) {
      _busy = false;
      _emitLoaded('Couldn’t submit sales right now. Please try again.');
    }
  }

  Future<void> _cancelSubscriptions() async {
    await _monthSub?.cancel();
    await _approvedSub?.cancel();
    await _ownSub?.cancel();
    _monthSub = null;
    _approvedSub = null;
    _ownSub = null;
  }

  /// Drops all three user-scoped streams and the cached month, returning the
  /// cubit to [SalesMonthState.initial]. Called on sign-out and on
  /// single-active-session eviction. Clearing `_branchId`/`_uid`/`_monthKey`
  /// also disarms the same-scope freshness short-circuit in `loadForEmployee`,
  /// so the next user's first load actually re-subscribes instead of being
  /// treated as a repeat of the previous user's.
  Future<void> reset() async {
    await _cancelSubscriptions();
    _target = null;
    _approved = const [];
    _own = const [];
    _branchId = null;
    _uid = null;
    _monthKey = null;
    _todayDateKey = '';
    _busy = false;
    if (!isClosed) emit(const SalesMonthState.initial());
  }

  @override
  Future<void> close() async {
    await _cancelSubscriptions();
    return super.close();
  }
}

/// Success messages the submit surfaces match on to decide whether to pop.
/// Shared constants rather than repeated literals — comparing against a typed
/// string in two files is how the old screen silently stopped closing itself.
const salesSubmittedMessage = 'Sales submitted for approval.';
const salesResubmittedMessage = 'Corrected sales sent for approval.';
