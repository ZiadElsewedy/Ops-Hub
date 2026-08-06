import 'package:drop/features/sales/domain/entities/daily_sales_submission_entity.dart';
import 'package:drop/features/sales/domain/entities/sales_month_snapshot.dart';

/// The sales surface intentionally keeps this small union explicit so the
/// app-wide stream can preserve its last loaded snapshot while mutating.
sealed class SalesMonthState {
  const SalesMonthState();
  const factory SalesMonthState.initial() = SalesMonthInitial;
  const factory SalesMonthState.loading() = SalesMonthLoading;

  /// This branch does not run the monthly sales target workflow. The feature
  /// must render as if it does not exist — no card, no pages, no CTA.
  const factory SalesMonthState.disabled() = SalesMonthDisabled;

  const factory SalesMonthState.loaded({
    required SalesMonthSnapshot snapshot,
    required String todayDateKey,
    List<DailySalesSubmissionEntity> ownSubmissions,
    bool submitting,
    String? message,
  }) = SalesMonthLoaded;
  const factory SalesMonthState.error(String message) = SalesMonthError;
}

class SalesMonthInitial extends SalesMonthState {
  const SalesMonthInitial();
}

class SalesMonthLoading extends SalesMonthState {
  const SalesMonthLoading();
}

class SalesMonthDisabled extends SalesMonthState {
  const SalesMonthDisabled();
}

class SalesMonthLoaded extends SalesMonthState {
  const SalesMonthLoaded({
    required this.snapshot,
    required this.todayDateKey,
    this.ownSubmissions = const [],
    this.submitting = false,
    this.message,
  });

  /// Branch-wide month view. Its `submissions` are the branch's **approved**
  /// records only — an employee may not read a peer's pending or rejected day.
  final SalesMonthSnapshot snapshot;

  /// Today's Cairo business day. Resolved by the cubit, never by the widget:
  /// the device's local date is a different day near midnight and across DST.
  final String todayDateKey;

  /// This employee's own records for the month, every status.
  final List<DailySalesSubmissionEntity> ownSubmissions;

  final bool submitting;
  final String? message;

  /// This employee's record for today, or null when they have not closed yet.
  DailySalesSubmissionEntity? get todaySubmission {
    for (final submission in ownSubmissions) {
      if (submission.businessDateKey == todayDateKey) return submission;
    }
    return null;
  }

  /// Today's close belongs to a teammate. Their pending record is invisible to
  /// this employee, but an approved one is not — so this only ever reads true
  /// once the day has been approved.
  bool get todayClosedByTeammate =>
      todaySubmission == null && snapshot.submissionFor(todayDateKey) != null;

  /// Whether this employee may submit today's close right now.
  bool get canSubmitToday =>
      snapshot.hasTarget && todaySubmission == null && !todayClosedByTeammate;

  /// Own records sent back for correction — the only ones the employee can act on.
  List<DailySalesSubmissionEntity> get needsCorrection =>
      ownSubmissions.where((submission) => submission.needsCorrection).toList();
}

class SalesMonthError extends SalesMonthState {
  const SalesMonthError(this.message);
  final String message;
}
