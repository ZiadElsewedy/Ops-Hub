import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:opshub/features/sales/domain/entities/branch_sales_month_entity.dart';
import 'package:opshub/features/sales/domain/entities/sales_month_snapshot.dart';
import 'package:opshub/features/sales/domain/repositories/sales_repository.dart';
import 'package:opshub/features/sales/presentation/cubit/sales_admin_overview_cubit.dart';

class _FakeSalesRepository implements SalesRepository {
  final summaries = StreamController<List<SalesMonthSnapshot>>.broadcast();

  @override
  Stream<List<SalesMonthSnapshot>> watchBranchMonthSummaries(String monthKey) =>
      summaries.stream;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

SalesMonthSnapshot _snapshot(String branchId) => SalesMonthSnapshot(
  target: BranchSalesMonthEntity(
    id: '${branchId}_202608',
    branchId: branchId,
    monthKey: '202608',
    targetPiastres: 100000,
  ),
);

void main() {
  test('maps every branch summary and cancels the stream when closed', () async {
    final repository = _FakeSalesRepository();
    final cubit = SalesAdminOverviewCubit(
      repository: repository,
      now: () => DateTime.utc(2026, 8, 5),
    );

    await cubit.load();
    repository.summaries.add([_snapshot('b1'), _snapshot('b2')]);
    await Future<void>.delayed(Duration.zero);

    final state = cubit.state as SalesAdminOverviewLoaded;
    expect(state.snapshotsByBranchId.keys, containsAll(['b1', 'b2']));
    expect(repository.summaries.hasListener, isTrue);

    await cubit.close();
    expect(repository.summaries.hasListener, isFalse);
    await repository.summaries.close();
  });
}
