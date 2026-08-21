import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:opshub/core/enums/sales_submission_status.dart';
import 'package:opshub/features/sales/data/models/daily_sales_submission_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('round trips timestamps and defaults unknown status to pending', () {
    final date = DateTime.utc(2026, 8, 5, 10);
    final model = DailySalesSubmissionModel.fromMap({
      'branchId': 'b1',
      'monthKey': '202608',
      'businessDateKey': '20260805',
      'amountPiastres': 0,
      'status': 'future',
      'submittedAt': Timestamp.fromDate(date),
    }, id: 'b1_20260805');
    expect(model.status, SalesSubmissionStatus.pending);
    expect(model.toEntity().amountPiastres, 0);
    expect((model.toMap()['submittedAt'] as Timestamp).toDate().toUtc(), date);
    expect(DailySalesSubmissionModel.fromMap({}).revision, 1);
  });
}
