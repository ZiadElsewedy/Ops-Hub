import 'package:opshub/features/sales/domain/sales_submission_id.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('builds deterministic branch sales ids', () {
    expect(salesSubmissionId('branch-a', '20260805'), 'branch-a_20260805');
    expect(salesMonthId('branch-a', '202608'), 'branch-a_202608');
  });
}
