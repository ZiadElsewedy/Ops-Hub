import 'package:drop/features/sales/domain/entities/daily_sales_submission_entity.dart';
import 'package:drop/features/sales/domain/entities/sales_month_snapshot.dart';

/// The sales surface intentionally keeps this small union explicit so the
/// app-wide stream can preserve its last loaded snapshot while mutating.
sealed class SalesMonthState {
  const SalesMonthState();
  const factory SalesMonthState.initial() = SalesMonthInitial;
  const factory SalesMonthState.loading() = SalesMonthLoading;
  const factory SalesMonthState.loaded({
    required SalesMonthSnapshot snapshot,
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

class SalesMonthLoaded extends SalesMonthState {
  const SalesMonthLoaded({
    required this.snapshot,
    this.ownSubmissions = const [],
    this.submitting = false,
    this.message,
  });
  final SalesMonthSnapshot snapshot;
  final List<DailySalesSubmissionEntity> ownSubmissions;
  final bool submitting;
  final String? message;
}

class SalesMonthError extends SalesMonthState {
  const SalesMonthError(this.message);
  final String message;
}
