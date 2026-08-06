import 'package:freezed_annotation/freezed_annotation.dart';

part 'branch_sales_month_entity.freezed.dart';

/// The source-of-truth target for one branch's Cairo accounting month.
@freezed
class BranchSalesMonthEntity with _$BranchSalesMonthEntity {
  const BranchSalesMonthEntity._();

  const factory BranchSalesMonthEntity({
    required String id,
    required String branchId,
    required String monthKey,
    @Default('Africa/Cairo') String timeZone,
    @Default(0) int targetPiastres,
    @Default(1) int targetRevision,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? createdById,
    String? createdByName,
    String? createdByRole,
    String? updatedById,
    String? updatedByName,
    String? updatedByRole,
    String? lastChangeReason,
    @Default(1) int schemaVersion,
  }) = _BranchSalesMonthEntity;
}
