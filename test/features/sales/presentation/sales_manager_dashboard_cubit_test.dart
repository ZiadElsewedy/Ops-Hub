import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:opshub/core/enums/sales_submission_status.dart';
import 'package:opshub/features/branch/domain/entities/branch_entity.dart';
import 'package:opshub/features/branch/domain/repositories/branch_repository.dart';
import 'package:opshub/features/sales/domain/entities/branch_sales_month_entity.dart';
import 'package:opshub/features/sales/domain/entities/daily_sales_submission_entity.dart';
import 'package:opshub/features/sales/domain/entities/sales_record_result.dart';
import 'package:opshub/features/sales/domain/repositories/sales_repository.dart';
import 'package:opshub/features/sales/domain/usecases/approve_sales_submission.dart';
import 'package:opshub/features/sales/domain/usecases/edit_approved_sales_submission.dart';
import 'package:opshub/features/sales/domain/usecases/record_daily_sales.dart';
import 'package:opshub/features/sales/domain/usecases/reject_sales_submission.dart';
import 'package:opshub/features/sales/domain/usecases/request_sales_correction.dart';
import 'package:opshub/features/sales/domain/usecases/set_branch_monthly_target.dart';
import 'package:opshub/features/sales/presentation/cubit/sales_manager_dashboard_cubit.dart';

/// A minimal [SalesRepository] fake: controllable read streams + call recording
/// on the write path. The dashboard cubit only touches these members.
class _FakeSalesRepo implements SalesRepository {
  final month = StreamController<BranchSalesMonthEntity?>.broadcast();
  final subs = StreamController<List<DailySalesSubmissionEntity>>.broadcast();
  final calls = <String>[];
  Completer<void>? hold;

  @override
  Stream<BranchSalesMonthEntity?> watchMonth(String b, String m) => month.stream;
  @override
  Stream<List<DailySalesSubmissionEntity>> watchSubmissions(String b, String m) =>
      subs.stream;
  @override
  Future<void> decideSubmission({
    required String submissionId,
    required String action,
    String? reason,
  }) async {
    calls.add('$action:$submissionId');
    if (hold != null) await hold!.future;
  }

  @override
  Future<void> setBranchTarget({
    required String branchId,
    required String monthKey,
    required int targetPiastres,
    required String reason,
    int? expectedTargetRevision,
  }) async => calls.add('setTarget:$targetPiastres');

  @override
  Future<void> editApprovedSubmission({
    required String submissionId,
    required int amountPiastres,
    required String reason,
    required int expectedRevision,
  }) async => calls.add('edit:$submissionId');

  SalesRecordResult recordResult = const SalesRecordResult(
    amountPiastres: 5900000,
    achievedPiastres: 35900000,
    targetPiastres: 100000000,
    crossedTarget: false,
  );
  Object? recordError;

  @override
  Future<SalesRecordResult> recordDailySales({
    required String branchId,
    required int amountPiastres,
    String? businessDateKey,
    String? reason,
  }) async {
    calls.add('record:$amountPiastres:${businessDateKey ?? 'today'}');
    if (hold != null) await hold!.future;
    if (recordError != null) throw recordError!;
    return recordResult;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// The branch's opt-in is resolved before the ledger is read, so every
/// dashboard test needs a branch that runs targets.
class _FakeBranchRepo implements BranchRepository {
  _FakeBranchRepo({this.salesTargetEnabled = true});
  final bool salesTargetEnabled;

  @override
  Future<BranchEntity?> getBranch(String branchId, {bool forceRefresh = false}) async =>
      BranchEntity(
        id: branchId,
        name: 'Branch $branchId',
        salesTargetEnabled: salesTargetEnabled,
      );

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

DailySalesSubmissionEntity _sub(String id, SalesSubmissionStatus status, int amount) =>
    DailySalesSubmissionEntity(
      id: id,
      branchId: 'b1',
      monthKey: '202608',
      businessDateKey: '2026080$id',
      status: status,
      amountPiastres: amount,
    );

SalesManagerDashboardCubit _build(
  _FakeSalesRepo repo, {
  bool salesTargetEnabled = true,
}) => SalesManagerDashboardCubit(
  repository: repo,
  branchRepository: _FakeBranchRepo(salesTargetEnabled: salesTargetEnabled),
  approve: ApproveSalesSubmission(repo),
  reject: RejectSalesSubmission(repo),
  requestCorrection: RequestSalesCorrection(repo),
  editApproved: EditApprovedSalesSubmission(repo),
  setTarget: SetBranchMonthlyTarget(repo),
  record: RecordDailySales(repo),
  now: () => DateTime.utc(2026, 8, 15),
);

const _target = BranchSalesMonthEntity(
  id: 'b1_202608',
  branchId: 'b1',
  monthKey: '202608',
  targetPiastres: 100000000, // 1,000,000 EGP
);

void main() {
  test('loads, categorizes pending vs approved, and sums only approved', () async {
    final repo = _FakeSalesRepo();
    final cubit = _build(repo);
    await cubit.loadForBranch(branchId: 'b1');
    repo.month.add(_target);
    repo.subs.add([
      _sub('1', SalesSubmissionStatus.pending, 50000),
      _sub('2', SalesSubmissionStatus.approved, 30000000),
    ]);
    await Future<void>.delayed(Duration.zero);

    expect(cubit.state, isA<SalesManagerDashboardLoaded>());
    final s = (cubit.state as SalesManagerDashboardLoaded).snapshot;
    expect(s.pending.length, 1);
    expect(s.approved.length, 1);
    expect(s.approvedTotalPiastres, 30000000);
    expect(s.remainingPiastres, 70000000);
    await cubit.close();
  });

  test('approve delegates once; the busy guard blocks a concurrent action', () async {
    final repo = _FakeSalesRepo();
    final cubit = _build(repo);
    await cubit.loadForBranch(branchId: 'b1');
    repo.month.add(_target);
    repo.subs.add([_sub('1', SalesSubmissionStatus.pending, 50000)]);
    await Future<void>.delayed(Duration.zero);

    repo.hold = Completer<void>();
    final first = cubit.approve('d1'); // still in flight (awaiting hold)
    await cubit.reject('other', 'nope'); // blocked by the busy guard
    expect(repo.calls, ['approve:d1']); // the reject never reached the use case

    repo.hold!.complete();
    await first;
    await cubit.close();
  });

  test('recordSales delegates and surfaces the result once via justRecorded', () async {
    final repo = _FakeSalesRepo();
    final cubit = _build(repo);
    await cubit.loadForBranch(branchId: 'b1');
    repo.month.add(_target);
    repo.subs.add(const []);
    await Future<void>.delayed(Duration.zero);

    await cubit.recordSales(amountPiastres: 5900000, businessDateKey: null);
    expect(repo.calls, ['record:5900000:today']);
    final loaded = cubit.state as SalesManagerDashboardLoaded;
    expect(loaded.justRecorded, isNotNull);
    expect(loaded.justRecorded!.amountPiastres, 5900000);
    expect(loaded.busyId, isNull); // busy cleared after success

    // A later ordinary emission must NOT keep replaying the celebration.
    repo.subs.add([_sub('1', SalesSubmissionStatus.approved, 5900000)]);
    await Future<void>.delayed(Duration.zero);
    expect((cubit.state as SalesManagerDashboardLoaded).justRecorded, isNull);
    await cubit.close();
  });

  test('recordSales is blocked while another action is in flight', () async {
    final repo = _FakeSalesRepo();
    final cubit = _build(repo);
    await cubit.loadForBranch(branchId: 'b1');
    repo.month.add(_target);
    repo.subs.add([_sub('1', SalesSubmissionStatus.pending, 50000)]);
    await Future<void>.delayed(Duration.zero);

    repo.hold = Completer<void>();
    final first = cubit.approve('d1'); // in flight
    await cubit.recordSales(amountPiastres: 100); // blocked by the busy guard
    expect(repo.calls, ['approve:d1']);

    repo.hold!.complete();
    await first;
    await cubit.close();
  });
}
