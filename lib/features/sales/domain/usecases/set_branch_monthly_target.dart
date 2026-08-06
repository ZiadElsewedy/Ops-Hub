import 'package:drop/features/sales/domain/repositories/sales_repository.dart';
class SetBranchMonthlyTarget { const SetBranchMonthlyTarget(this._repository); final SalesRepository _repository;
  Future<void> call({required String branchId, required String monthKey, required int targetPiastres, required String reason, int? expectedTargetRevision}) => _repository.setBranchTarget(branchId: branchId, monthKey: monthKey, targetPiastres: targetPiastres, reason: reason, expectedTargetRevision: expectedTargetRevision); }
