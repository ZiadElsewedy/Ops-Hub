import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:drop/core/enums/sales_submission_status.dart';
import 'package:drop/core/errors/failures.dart';
import 'package:drop/features/branch/domain/entities/branch_entity.dart';
import 'package:drop/features/branch/domain/repositories/branch_repository.dart';
import 'package:drop/features/sales/domain/entities/branch_sales_month_entity.dart';
import 'package:drop/features/sales/domain/entities/daily_sales_submission_entity.dart';
import 'package:drop/features/sales/domain/repositories/sales_repository.dart';
import 'package:drop/features/sales/domain/usecases/resubmit_corrected_sales.dart';
import 'package:drop/features/sales/domain/usecases/submit_daily_sales.dart';
import 'package:drop/features/sales/presentation/cubit/sales_month_cubit.dart';
import 'package:drop/features/sales/presentation/cubit/sales_month_state.dart';

class _FakeSalesRepo implements SalesRepository {
  final month = StreamController<BranchSalesMonthEntity?>.broadcast();
  final approved = StreamController<List<DailySalesSubmissionEntity>>.broadcast();
  final own = StreamController<List<DailySalesSubmissionEntity>>.broadcast();
  final calls = <String>[];
  var monthListens = 0;

  @override
  Stream<BranchSalesMonthEntity?> watchMonth(String b, String m) {
    monthListens++;
    return month.stream;
  }

  @override
  Stream<List<DailySalesSubmissionEntity>> watchApprovedSubmissions(
    String b,
    String m,
  ) => approved.stream;

  @override
  Stream<List<DailySalesSubmissionEntity>> watchOwnSubmissions(
    String b,
    String m,
    String uid,
  ) => own.stream;

  @override
  Future<void> submitDailySales({
    required String branchId,
    required String monthKey,
    required String businessDateKey,
    required int amountPiastres,
    required String submittedById,
    required String submittedByName,
  }) async => calls.add('submit:$businessDateKey:$amountPiastres');

  @override
  Future<void> resubmitCorrectedSales({
    required String submissionId,
    required int amountPiastres,
  }) async => calls.add('resubmit:$submissionId:$amountPiastres');

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeBranchRepo implements BranchRepository {
  _FakeBranchRepo({this.enabled = true, this.failure});
  final bool enabled;
  final Failure? failure;

  @override
  Future<BranchEntity?> getBranch(
    String branchId, {
    bool forceRefresh = false,
  }) async {
    if (failure != null) throw failure!;
    return BranchEntity(
      id: branchId,
      name: 'Branch',
      salesTargetEnabled: enabled,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

const _target = BranchSalesMonthEntity(
  id: 'b1_202608',
  branchId: 'b1',
  monthKey: '202608',
  targetPiastres: 100000,
);

DailySalesSubmissionEntity _sub(
  String day,
  SalesSubmissionStatus status, {
  int amount = 5000,
}) => DailySalesSubmissionEntity(
  id: 'b1_$day',
  branchId: 'b1',
  monthKey: '202608',
  businessDateKey: day,
  amountPiastres: amount,
  status: status,
);

SalesMonthCubit _build(
  _FakeSalesRepo repo, {
  _FakeBranchRepo? branches,
  DateTime? now,
}) => SalesMonthCubit(
  repository: repo,
  branchRepository: branches ?? _FakeBranchRepo(),
  submitDailySales: SubmitDailySales(repo),
  resubmitCorrectedSales: ResubmitCorrectedSales(repo),
  now: () => now ?? DateTime.utc(2026, 8, 15, 9),
);

void main() {
  test('a branch that has targets off never reads the ledger', () async {
    final repo = _FakeSalesRepo();
    final cubit = _build(repo, branches: _FakeBranchRepo(enabled: false));

    await cubit.loadForEmployee(branchId: 'b1', uid: 'u1');

    expect(cubit.state, isA<SalesMonthDisabled>());
    // The whole point of the flag: no subscription, no reads, no card.
    expect(repo.monthListens, 0);
    await cubit.close();
  });

  test('an opted-in branch loads the month and this employee’s own days', () async {
    final repo = _FakeSalesRepo();
    final cubit = _build(repo);
    await cubit.loadForEmployee(branchId: 'b1', uid: 'u1');

    repo.month.add(_target);
    repo.approved.add([_sub('20260814', SalesSubmissionStatus.approved)]);
    repo.own.add([
      _sub('20260814', SalesSubmissionStatus.approved),
      _sub('20260815', SalesSubmissionStatus.pending, amount: 2500),
    ]);
    await Future<void>.delayed(Duration.zero);

    final state = cubit.state as SalesMonthLoaded;
    expect(state.todayDateKey, '20260815');
    expect(state.snapshot.approvedTotalPiastres, 5000);
    expect(state.todaySubmission?.amountPiastres, 2500);
    expect(state.canSubmitToday, isFalse);
    await cubit.close();
  });

  test('today is resolved in Cairo, not from the device clock', () async {
    final repo = _FakeSalesRepo();
    // 21:30 UTC on 31 July is already 1 August in Cairo (UTC+3 in summer).
    final cubit = _build(repo, now: DateTime.utc(2026, 7, 31, 21, 30));
    await cubit.loadForEmployee(branchId: 'b1', uid: 'u1');
    repo.month.add(_target);
    repo.approved.add(const []);
    repo.own.add(const []);
    await Future<void>.delayed(Duration.zero);

    expect((cubit.state as SalesMonthLoaded).todayDateKey, '20260801');
    await cubit.close();
  });

  test('a teammate’s approved close blocks a second submission for the day', () async {
    final repo = _FakeSalesRepo();
    final cubit = _build(repo);
    await cubit.loadForEmployee(branchId: 'b1', uid: 'u1');
    repo.month.add(_target);
    repo.approved.add([_sub('20260815', SalesSubmissionStatus.approved)]);
    repo.own.add(const []);
    await Future<void>.delayed(Duration.zero);

    final state = cubit.state as SalesMonthLoaded;
    expect(state.todayClosedByTeammate, isTrue);
    expect(state.canSubmitToday, isFalse);
    await cubit.close();
  });

  test('without a target the employee cannot submit', () async {
    final repo = _FakeSalesRepo();
    final cubit = _build(repo);
    await cubit.loadForEmployee(branchId: 'b1', uid: 'u1');
    repo.month.add(null);
    repo.approved.add(const []);
    repo.own.add(const []);
    await Future<void>.delayed(Duration.zero);

    expect((cubit.state as SalesMonthLoaded).canSubmitToday, isFalse);
    await cubit.close();
  });

  test('a correction is resubmitted through the callable', () async {
    final repo = _FakeSalesRepo();
    final cubit = _build(repo);
    await cubit.loadForEmployee(branchId: 'b1', uid: 'u1');
    repo.month.add(_target);
    repo.approved.add(const []);
    repo.own.add([_sub('20260814', SalesSubmissionStatus.correctionRequested)]);
    await Future<void>.delayed(Duration.zero);

    expect((cubit.state as SalesMonthLoaded).needsCorrection, hasLength(1));
    await cubit.resubmitCorrection(
      submissionId: 'b1_20260814',
      amountPiastres: 7777,
    );
    expect(repo.calls, contains('resubmit:b1_20260814:7777'));
    await cubit.close();
  });

  test('a forced reload re-subscribes so Retry can clear an error', () async {
    final repo = _FakeSalesRepo();
    final cubit = _build(repo);
    await cubit.loadForEmployee(branchId: 'b1', uid: 'u1');
    expect(repo.monthListens, 1);

    // Same branch, same month: the guard skips the work…
    await cubit.loadForEmployee(branchId: 'b1', uid: 'u1');
    expect(repo.monthListens, 1);

    // …unless the caller is a Retry, which must always re-subscribe. Without
    // this the error state was permanent for the life of the cubit.
    await cubit.loadForEmployee(branchId: 'b1', uid: 'u1', force: true);
    expect(repo.monthListens, 2);
    await cubit.close();
  });

  test('a new Cairo month re-subscribes without being forced', () async {
    final repo = _FakeSalesRepo();
    var now = DateTime.utc(2026, 8, 31, 12);
    final cubit = SalesMonthCubit(
      repository: repo,
      branchRepository: _FakeBranchRepo(),
      submitDailySales: SubmitDailySales(repo),
      resubmitCorrectedSales: ResubmitCorrectedSales(repo),
      now: () => now,
    );
    await cubit.loadForEmployee(branchId: 'b1', uid: 'u1');
    expect(repo.monthListens, 1);

    now = DateTime.utc(2026, 9, 1, 12);
    await cubit.loadForEmployee(branchId: 'b1', uid: 'u1');
    expect(repo.monthListens, 2);
    await cubit.close();
  });
}
