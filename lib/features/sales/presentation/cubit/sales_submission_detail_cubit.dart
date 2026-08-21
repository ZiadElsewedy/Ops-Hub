import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:opshub/core/errors/failures.dart';
import 'package:opshub/features/sales/domain/entities/daily_sales_submission_entity.dart';
import 'package:opshub/features/sales/domain/repositories/sales_repository.dart';
import 'package:opshub/features/sales/domain/usecases/approve_sales_submission.dart';
import 'package:opshub/features/sales/domain/usecases/edit_approved_sales_submission.dart';
import 'package:opshub/features/sales/domain/usecases/reject_sales_submission.dart';
import 'package:opshub/features/sales/domain/usecases/request_sales_correction.dart';
import 'package:opshub/features/sales/domain/usecases/reopen_sales_submission.dart';

sealed class SalesSubmissionDetailState {
  const SalesSubmissionDetailState();
}

class SalesSubmissionDetailLoading extends SalesSubmissionDetailState {
  const SalesSubmissionDetailLoading();
}

class SalesSubmissionDetailUnavailable extends SalesSubmissionDetailState {
  const SalesSubmissionDetailUnavailable();
}

class SalesSubmissionDetailError extends SalesSubmissionDetailState {
  const SalesSubmissionDetailError(this.message);
  final String message;
}

class SalesSubmissionDetailLoaded extends SalesSubmissionDetailState {
  const SalesSubmissionDetailLoaded(
    this.submission, {
    this.busy = false,
    this.message,
  });
  final DailySalesSubmissionEntity submission;
  final bool busy;
  final String? message;
}

class SalesSubmissionDetailCubit extends Cubit<SalesSubmissionDetailState> {
  SalesSubmissionDetailCubit({
    required String submissionId,
    required this._repository,
    required this._approve,
    required this._reject,
    required this._requestCorrection,
    required this._editApproved,
    required this._reopen,
    DailySalesSubmissionEntity? seed,
  }) : _id = submissionId,
       super(
         seed == null
             ? const SalesSubmissionDetailLoading()
             : SalesSubmissionDetailLoaded(seed),
       ) {
    _sub = _repository
        .watchSubmission(_id)
        .listen(
          (v) => v == null
              ? emit(const SalesSubmissionDetailUnavailable())
              : emit(SalesSubmissionDetailLoaded(v, busy: _busy)),
          onError: (Object e, StackTrace _) => emit(
            SalesSubmissionDetailError(
              e is Failure ? e.message : 'Failed to load sales submission.',
            ),
          ),
        );
  }
  final String _id;
  final SalesRepository _repository;
  final ApproveSalesSubmission _approve;
  final RejectSalesSubmission _reject;
  final RequestSalesCorrection _requestCorrection;
  final EditApprovedSalesSubmission _editApproved;
  final ReopenSalesSubmission _reopen;
  StreamSubscription<DailySalesSubmissionEntity?>? _sub;
  bool _busy = false;
  Future<void> _run(Future<void> Function() work, String success) async {
    if (_busy) return;
    _busy = true;
    final current = state;
    if (current is SalesSubmissionDetailLoaded) {
      emit(SalesSubmissionDetailLoaded(current.submission, busy: true));
    }
    try {
      await work();
      _busy = false;
      if (state is SalesSubmissionDetailLoaded) {
        emit(
          SalesSubmissionDetailLoaded(
            (state as SalesSubmissionDetailLoaded).submission,
            message: success,
          ),
        );
      }
    } on Failure catch (e) {
      _busy = false;
      _message(e.message);
    } catch (_) {
      _busy = false;
      _message('Couldn’t update this submission right now.');
    }
  }

  void _message(String text) {
    final current = state;
    if (current is SalesSubmissionDetailLoaded) {
      emit(SalesSubmissionDetailLoaded(current.submission, message: text));
    } else {
      emit(SalesSubmissionDetailError(text));
    }
  }

  Future<void> approve() => _run(() => _approve(_id), 'Sales approved.');
  Future<void> reject(String reason) =>
      _run(() => _reject(submissionId: _id, reason: reason), 'Sales rejected.');
  Future<void> requestCorrection(String reason) => _run(
    () => _requestCorrection(submissionId: _id, reason: reason),
    'Correction requested.',
  );
  Future<void> editApproved(int amount, String reason, int revision) => _run(
    () => _editApproved(
      submissionId: _id,
      amountPiastres: amount,
      reason: reason,
      expectedRevision: revision,
    ),
    'Approved amount updated.',
  );
  Future<void> reopen(String reason) => _run(
    () => _reopen(submissionId: _id, reason: reason),
    'Sales submission reopened.',
  );
  @override
  Future<void> close() async {
    await _sub?.cancel();
    return super.close();
  }
}
