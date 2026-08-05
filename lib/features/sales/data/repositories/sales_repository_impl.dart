import 'dart:async';

import 'package:drop/core/errors/exceptions.dart';
import 'package:drop/core/errors/failures.dart';
import 'package:drop/core/network/network_guard.dart';
import 'package:drop/features/sales/data/datasources/sales_remote_datasource.dart';
import 'package:drop/features/sales/domain/entities/sales_month_snapshot.dart';
import 'package:drop/features/sales/domain/entities/branch_sales_month_entity.dart';
import 'package:drop/features/sales/domain/entities/daily_sales_submission_entity.dart';
import 'package:drop/features/sales/domain/repositories/sales_repository.dart';

class SalesRepositoryImpl implements SalesRepository {
  SalesRepositoryImpl(this._remote);
  final SalesRemoteDataSource _remote;

  @override
  Future<void> submitDailySales({required String branchId, required String monthKey, required String businessDateKey, required int amountPiastres, required String submittedById, required String submittedByName}) => _write(() => _remote.submitDailySales(branchId: branchId, monthKey: monthKey, businessDateKey: businessDateKey, amountPiastres: amountPiastres, submittedById: submittedById, submittedByName: submittedByName));
  @override
  Future<void> setBranchTarget({required String branchId, required String monthKey, required int targetPiastres, required String reason, int? expectedTargetRevision}) => _write(() => _remote.setBranchTarget(branchId: branchId, monthKey: monthKey, targetPiastres: targetPiastres, reason: reason, expectedTargetRevision: expectedTargetRevision));
  @override
  Future<void> decideSubmission({required String submissionId, required String action, String? reason}) => _write(() => _remote.decideSubmission(submissionId: submissionId, action: action, reason: reason));
  @override
  Future<void> editApprovedSubmission({required String submissionId, required int amountPiastres, required String reason, required int expectedRevision}) => _write(() => _remote.editApprovedSubmission(submissionId: submissionId, amountPiastres: amountPiastres, reason: reason, expectedRevision: expectedRevision));
  @override
  Future<void> resubmitCorrectedSales({required String submissionId, required int amountPiastres}) => _write(() => _remote.resubmitCorrectedSales(submissionId: submissionId, amountPiastres: amountPiastres));

  Future<void> _write(Future<void> Function() operation) async {
    NetworkGuard.ensureWritable();
    try { await operation(); } on ServerException catch (e) { throw ServerFailure(e.message); }
  }

  @override
  Stream<BranchSalesMonthEntity?> watchMonth(
    String branchId,
    String monthKey,
  ) => _failureStream(
    _remote.watchMonth(branchId, monthKey).map((model) => model?.toEntity()),
  );

  @override
  Stream<List<DailySalesSubmissionEntity>> watchSubmissions(
    String branchId,
    String monthKey,
  ) => _failureStream(
    _remote
        .watchSubmissions(branchId, monthKey)
        .map((models) => models.map((model) => model.toEntity()).toList()),
  );

  @override
  Stream<List<DailySalesSubmissionEntity>> watchApprovedSubmissions(
    String branchId,
    String monthKey,
  ) => _failureStream(
    _remote
        .watchApprovedSubmissions(branchId, monthKey)
        .map((models) => models.map((model) => model.toEntity()).toList()),
  );

  @override
  Stream<List<DailySalesSubmissionEntity>> watchOwnSubmissions(
    String branchId,
    String monthKey,
    String submittedById,
  ) => _failureStream(
    _remote
        .watchOwnSubmissions(branchId, monthKey, submittedById)
        .map((models) => models.map((model) => model.toEntity()).toList()),
  );

  @override
  Stream<DailySalesSubmissionEntity?> watchSubmission(String id) =>
      _failureStream(
        _remote.watchSubmission(id).map((model) => model?.toEntity()),
      );

  @override
  Stream<List<SalesMonthSnapshot>> watchBranchMonthSummaries(String monthKey) {
    final months = _failureStream(_remote.watchMonths(monthKey));
    final submissions = _failureStream(_remote.watchMonthSubmissions(monthKey));
    return _combineLatest(months, submissions, (monthModels, submissionModels) {
      final byBranch = <String, List<DailySalesSubmissionEntity>>{};
      for (final submission in submissionModels) {
        byBranch
            .putIfAbsent(submission.branchId, () => [])
            .add(submission.toEntity());
      }
      return monthModels
          .map(
            (month) => SalesMonthSnapshot(
              target: month.toEntity(),
              submissions: List.from(byBranch[month.branchId] ?? const []),
            ),
          )
          .toList();
    });
  }

  Stream<T> _failureStream<T>(Stream<T> stream) => stream.handleError((error) {
    if (error is ServerException) throw ServerFailure(error.message);
    throw error;
  });

  Stream<R> _combineLatest<A, B, R>(
    Stream<A> first,
    Stream<B> second,
    R Function(A first, B second) combine,
  ) {
    late final StreamController<R> controller;
    StreamSubscription<A>? firstSubscription;
    StreamSubscription<B>? secondSubscription;
    A? firstValue;
    B? secondValue;
    var hasFirst = false;
    var hasSecond = false;
    void emit() {
      if (hasFirst && hasSecond) {
        controller.add(combine(firstValue as A, secondValue as B));
      }
    }

    controller = StreamController<R>(
      onListen: () {
        firstSubscription = first.listen((value) {
          firstValue = value;
          hasFirst = true;
          emit();
        }, onError: controller.addError);
        secondSubscription = second.listen((value) {
          secondValue = value;
          hasSecond = true;
          emit();
        }, onError: controller.addError);
      },
      onCancel: () async {
        await firstSubscription?.cancel();
        await secondSubscription?.cancel();
      },
    );
    return controller.stream;
  }
}
