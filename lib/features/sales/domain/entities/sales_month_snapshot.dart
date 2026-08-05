import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:drop/core/enums/sales_submission_status.dart';
import 'package:drop/features/sales/domain/entities/branch_sales_month_entity.dart';
import 'package:drop/features/sales/domain/entities/daily_sales_submission_entity.dart';
import 'package:drop/features/sales/domain/sales_calculator.dart' as calculator;

part 'sales_month_snapshot.freezed.dart';

/// An in-memory composition of a month's target and daily ledger entries.
@freezed
class SalesMonthSnapshot with _$SalesMonthSnapshot {
  const SalesMonthSnapshot._();

  const factory SalesMonthSnapshot({
    BranchSalesMonthEntity? target,
    @Default(<DailySalesSubmissionEntity>[])
    List<DailySalesSubmissionEntity> submissions,
  }) = _SalesMonthSnapshot;

  bool get hasTarget => target != null;
  int get approvedTotalPiastres => calculator.sumApprovedPiastres(submissions);
  int get remainingPiastres => target == null
      ? 0
      : calculator.remainingPiastres(
          target!.targetPiastres,
          approvedTotalPiastres,
        );
  double get progressRatioRaw => target == null
      ? 0
      : calculator.progressRatioRaw(
          target!.targetPiastres,
          approvedTotalPiastres,
        );
  double get progressRatioCapped => target == null
      ? 0
      : calculator.progressRatioCapped(
          target!.targetPiastres,
          approvedTotalPiastres,
        );

  List<DailySalesSubmissionEntity> get pending => submissions
      .where((s) => s.status == SalesSubmissionStatus.pending)
      .toList();
  List<DailySalesSubmissionEntity> get approved => submissions
      .where((s) => s.status == SalesSubmissionStatus.approved)
      .toList();
  List<DailySalesSubmissionEntity> get rejected => submissions
      .where((s) => s.status == SalesSubmissionStatus.rejected)
      .toList();
  List<DailySalesSubmissionEntity> get correctionRequested => submissions
      .where((s) => s.status == SalesSubmissionStatus.correctionRequested)
      .toList();
}
