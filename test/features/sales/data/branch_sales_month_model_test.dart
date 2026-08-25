import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:opshub/features/sales/data/models/branch_sales_month_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('round trips a target model through map and entity', () {
    final date = DateTime.utc(2026, 8, 1);
    final model = BranchSalesMonthModel.fromMap({
      'branchId': 'b1',
      'monthKey': '202608',
      'targetPiastres': 1000,
      'createdAt': Timestamp.fromDate(date),
    }, id: 'b1_202608');
    expect(model.toEntity().targetPiastres, 1000);
    expect((model.toMap()['createdAt'] as Timestamp).toDate().toUtc(), date);
    expect(BranchSalesMonthModel.fromMap({}).targetRevision, 1);
  });
}
