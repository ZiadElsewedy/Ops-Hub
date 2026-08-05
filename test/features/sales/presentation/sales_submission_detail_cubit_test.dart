import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:drop/features/sales/domain/entities/daily_sales_submission_entity.dart';
import 'package:drop/features/sales/domain/repositories/sales_repository.dart';
import 'package:drop/features/sales/domain/usecases/approve_sales_submission.dart';
import 'package:drop/features/sales/domain/usecases/edit_approved_sales_submission.dart';
import 'package:drop/features/sales/domain/usecases/reject_sales_submission.dart';
import 'package:drop/features/sales/domain/usecases/reopen_sales_submission.dart';
import 'package:drop/features/sales/domain/usecases/request_sales_correction.dart';
import 'package:drop/features/sales/presentation/cubit/sales_submission_detail_cubit.dart';

class _FakeSalesRepository implements SalesRepository {
  final submission = StreamController<DailySalesSubmissionEntity?>.broadcast();
  String? action;
  String? reason;

  @override
  Stream<DailySalesSubmissionEntity?> watchSubmission(String id) =>
      submission.stream;

  @override
  Future<void> decideSubmission({
    required String submissionId,
    required String action,
    String? reason,
  }) async {
    this.action = action;
    this.reason = reason;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  test('reopen delegates to the use case with its mandatory reason', () async {
    final repository = _FakeSalesRepository();
    final cubit = SalesSubmissionDetailCubit(
      submissionId: 'b1_20260805',
      repository: repository,
      approve: ApproveSalesSubmission(repository),
      reject: RejectSalesSubmission(repository),
      requestCorrection: RequestSalesCorrection(repository),
      editApproved: EditApprovedSalesSubmission(repository),
      reopen: ReopenSalesSubmission(repository),
    );

    await cubit.reopen('Incorrect close');

    expect(repository.action, 'reopen');
    expect(repository.reason, 'Incorrect close');
    await cubit.close();
    await repository.submission.close();
  });
}
