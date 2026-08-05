import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:drop/core/enums/sales_submission_status.dart';

part 'daily_sales_submission_entity.freezed.dart';

/// One branch business day's submitted sales fact. Only approved records count.
@freezed
class DailySalesSubmissionEntity with _$DailySalesSubmissionEntity {
  const DailySalesSubmissionEntity._();

  const factory DailySalesSubmissionEntity({
    required String id,
    required String branchId,
    required String monthKey,
    required String businessDateKey,
    @Default('Africa/Cairo') String businessTimeZone,
    @Default(0) int amountPiastres,
    @Default(SalesSubmissionStatus.pending) SalesSubmissionStatus status,
    @Default(1) int revision,
    int? approvedRevision,
    String? submittedById,
    String? submittedByName,
    DateTime? submittedAt,
    String? lastEditedById,
    String? lastEditedByName,
    DateTime? lastEditedAt,
    String? decisionById,
    String? decisionByName,
    String? decisionByRole,
    DateTime? decisionAt,
    String? decisionReason,
    DateTime? createdAt,
    DateTime? updatedAt,
    @Default(1) int schemaVersion,
  }) = _DailySalesSubmissionEntity;

  bool get isApproved => status == SalesSubmissionStatus.approved;
  bool get isPending => status == SalesSubmissionStatus.pending;
  bool get isRejected => status == SalesSubmissionStatus.rejected;

  /// Sent back to the submitting employee to fix and resubmit.
  bool get needsCorrection =>
      status == SalesSubmissionStatus.correctionRequested;

  /// A decided record admin reopen can move back to `pending`. Correction
  /// requests are NOT terminal — they return to `pending` on resubmission.
  bool get isTerminal =>
      status == SalesSubmissionStatus.approved ||
      status == SalesSubmissionStatus.rejected;
}
