import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:drop/core/errors/failures.dart';
import 'package:drop/features/auth/domain/entities/user_entity.dart';
import 'package:drop/features/sales/domain/entities/branch_sales_month_entity.dart';
import 'package:drop/features/sales/domain/entities/daily_sales_submission_entity.dart';
import 'package:drop/features/sales/domain/entities/sales_month_snapshot.dart';
import 'package:drop/features/sales/domain/repositories/sales_repository.dart';
import 'package:drop/features/sales/domain/sales_business_time.dart';
import 'package:drop/features/sales/domain/usecases/submit_daily_sales.dart';
import 'sales_month_state.dart';

class SalesMonthCubit extends Cubit<SalesMonthState> {
  SalesMonthCubit({
    required this._repository,
    required this._submitDailySales,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now,
       super(const SalesMonthState.initial());
  final SalesRepository _repository;
  final SubmitDailySales _submitDailySales;
  final DateTime Function() _now;
  StreamSubscription<BranchSalesMonthEntity?>? _monthSub;
  StreamSubscription<List<DailySalesSubmissionEntity>>? _approvedSub;
  StreamSubscription<List<DailySalesSubmissionEntity>>? _ownSub;
  BranchSalesMonthEntity? _target;
  List<DailySalesSubmissionEntity> _approved = const [];
  List<DailySalesSubmissionEntity> _own = const [];
  String? _branchId;
  String? _uid;
  bool _busy = false;
  Future<void> loadForEmployee({
    required String branchId,
    required String uid,
    DateTime? now,
  }) async {
    if (_branchId == branchId && _uid == uid && _monthSub != null) return;
    _branchId = branchId;
    _uid = uid;
    if (state is! SalesMonthLoaded) emit(const SalesMonthState.loading());
    await _monthSub?.cancel();
    await _approvedSub?.cancel();
    await _ownSub?.cancel();
    final monthKey = businessMonthKey(now ?? _now());
    _monthSub = _repository.watchMonth(branchId, monthKey).listen((v) {
      _target = v;
      _emitLoaded();
    }, onError: _onError);
    _approvedSub = _repository
        .watchApprovedSubmissions(branchId, monthKey)
        .listen((v) {
          _approved = v;
          _emitLoaded();
        }, onError: _onError);
    _ownSub = _repository.watchOwnSubmissions(branchId, monthKey, uid).listen((
      v,
    ) {
      _own = v;
      _emitLoaded();
    }, onError: _onError);
  }

  void _emitLoaded([String? message]) => emit(
    SalesMonthState.loaded(
      snapshot: SalesMonthSnapshot(target: _target, submissions: _approved),
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
    final now = _now();
    final dateKey = businessDateKey(now);
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
    _busy = true;
    _emitLoaded();
    try {
      await _submitDailySales(
        branchId: branchId,
        monthKey: businessMonthKey(now),
        businessDateKey: dateKey,
        amountPiastres: amountPiastres,
        submittedById: user.uid,
        submittedByName: user.displayName ?? 'Employee',
      );
      _busy = false;
      _emitLoaded('Sales submitted for approval.');
    } on Failure catch (e) {
      _busy = false;
      _emitLoaded(e.message);
    } catch (_) {
      _busy = false;
      _emitLoaded('Couldn’t submit sales right now. Please try again.');
    }
  }

  @override
  Future<void> close() async {
    await _monthSub?.cancel();
    await _approvedSub?.cancel();
    await _ownSub?.cancel();
    return super.close();
  }
}
